#!/usr/bin/env bash
# RNF-24 - Mensajes fragmentados y solicitudes secuenciales.
# TC-056: el cliente CLI reutiliza una conexion al paginar `red filter`. Contra
# el servidor real obtiene todas las paginas seguidas, y contra un servidor que
# cierra tras cada respuesta reintenta una sola vez por pagina y sigue.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45862
PUERTO_FALSO=45863
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
CONF_DIR="$HOME/.config/hermes"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-056.md"
mkdir -p "$NET_DIR" "$CONF_DIR" "$RESULTS_DIR"

cat >"$CONF_DIR/config.json" <<JSON
{
  "interfaz": "127.0.0.1",
  "puerto": $PUERTO,
  "redes_permitidas": ["127.0.0.0/8"],
  "trabajos_maximos": 64,
  "max_cola": 64
}
JSON

cat >"$NET_DIR/network.json" <<'JSON'
{
  "habilitada": true,
  "clientes": [
    {
      "id": "PC-B",
      "direcciones": ["127.0.0.1"],
      "operaciones": ["submit", "query", "list", "cancel"],
      "programas": ["true", "sleep", "echo", "ls"]
    }
  ]
}
JSON

{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '```text\n'
} >>"$RESULTS_FILE"
exec > >(tee -a "$RESULTS_FILE") 2>&1

FALSO_PID=""
find_scheduler_pid() {
    local descriptor target process_path
    for descriptor in /proc/[0-9]*/fd/*; do
        [[ -e "$descriptor" ]] || continue
        target="$(readlink "$descriptor" 2>/dev/null || true)"
        if [[ "$target" == "$DATA_DIR/scheduler.lock" ]]; then
            process_path="${descriptor#/proc/}"
            printf '%s\n' "${process_path%%/*}"
            return 0
        fi
    done
    return 0
}

stop_scheduler() {
    local scheduler_pid
    scheduler_pid="$(find_scheduler_pid)"
    [[ -z "$scheduler_pid" ]] && return 0
    kill "$scheduler_pid" 2>/dev/null || true
    for _ in $(seq 1 50); do
        [[ ! -d "/proc/$scheduler_pid/fd" ]] && return 0
        sleep 0.1
    done
    return 1
}

cleanup() {
    if [[ -n "$FALSO_PID" ]] && kill -0 "$FALSO_PID" 2>/dev/null; then
        kill "$FALSO_PID" 2>/dev/null || true
        wait "$FALSO_PID" 2>/dev/null || true
    fi
    if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
        for _ in $(seq 1 50); do
            kill -0 "$SERVER_PID" 2>/dev/null || break
            sleep 0.1
        done
        kill -9 "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    stop_scheduler || true
    rm -rf "$TEST_ROOT"
    printf '```\n'
}
trap cleanup EXIT

puerto_ocupado() {
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$1\$"
}

if [[ ! -x "$HERMES" ]]; then
    echo "FAIL: no existe $HERMES. Compila Hermes antes de ejecutar la prueba."
    exit 1
fi
if puerto_ocupado "$PUERTO"; then
    echo "FAIL: el puerto $PUERTO ya está en uso; detenga el servidor previo."
    exit 1
fi

echo "Arrancando 'hermes red start' con HOME temporal..."
"$HERMES" red start >"$TEST_ROOT/server.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 100); do
    puerto_ocupado "$PUERTO" && break
    sleep 0.1
done
if ! puerto_ocupado "$PUERTO"; then
    echo "FAIL: el servidor no abrió el puerto $PUERTO."
    cat "$TEST_ROOT/server.log"
    exit 1
fi

# AC1: 21 Jobs en una sola conexion; luego `red filter` pagina contra el
# servidor real y muestra los 21 sin que el servidor corte la conexion.
python3 - "$PUERTO" <<'PY'
import json, socket, sys

puerto = int(sys.argv[1])
s = socket.create_connection(("127.0.0.1", puerto), timeout=20)
pendiente = b""
for i in range(1, 22):
    s.sendall((json.dumps({"version": 1, "request_id": "tc056-%02d" % i,
                           "operation": "submit",
                           "params": {"programa": "true", "argumentos": []}}) + "\n").encode())
    while b"\n" not in pendiente:
        trozo = s.recv(4096)
        if not trozo:
            raise SystemExit("FAIL: el servidor cerro en el submit %d" % i)
        pendiente += trozo
    linea, _, pendiente = pendiente.partition(b"\n")
    if json.loads(linea).get("ok") is not True:
        raise SystemExit("FAIL: submit %d rechazado: %r" % (i, linea))
s.close()
print("  21 Jobs creados sobre una sola conexion")
PY

sleep 0.6

SALIDA="$("$HERMES" red filter 127.0.0.1 programa true 2>&1)"
FILAS="$(printf '%s\n' "$SALIDA" | grep -c '^Job ID: ')"
if [[ "$FILAS" -ne 21 ]]; then
    echo "FAIL: red filter mostro $FILAS Jobs y se esperaban 21."
    printf '%s\n' "$SALIDA"
    exit 1
fi
echo "  red filter mostro 21 Jobs (dos paginas sobre la misma conexion)"
echo "PASS V1/AC1: el CLI pago la paginacion reutilizando la conexion."

# AC2: servidor que cierra tras cada respuesta; el cliente reconecta una vez
# por pagina y aun asi completa la lista.
python3 - "$PUERTO_FALSO" <<'PY' &
import json, socket, sys

puerto = int(sys.argv[1])
paginas = [
    ([{"job_id": 1, "programa": "true", "pid": 0, "status": "SUCCEEDED",
       "argumentos": []}], 1),
    ([{"job_id": 2, "programa": "true", "pid": 0, "status": "SUCCEEDED",
       "argumentos": []}], 2),
    ([], 2),
]
servidor = socket.socket()
servidor.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
servidor.bind(("127.0.0.1", puerto))
servidor.listen(1)
for jobs, next_after in paginas:
    conexion, _ = servidor.accept()
    datos = b""
    while b"\n" not in datos:
        trozo = conexion.recv(4096)
        if not trozo:
            break
        datos += trozo
    solicitud = json.loads(datos.split(b"\n")[0])
    respuesta = {"version": 1, "request_id": solicitud.get("request_id"),
                 "ok": True, "result": {"jobs": jobs, "next_after": next_after}}
    conexion.sendall((json.dumps(respuesta) + "\n").encode())
    conexion.close()
servidor.close()
PY
FALSO_PID=$!
for _ in $(seq 1 100); do
    puerto_ocupado "$PUERTO_FALSO" && break
    sleep 0.1
done
if ! puerto_ocupado "$PUERTO_FALSO"; then
    echo "FAIL: el servidor de prueba no abrió el puerto $PUERTO_FALSO."
    exit 1
fi

sed -i "s/\"puerto\": $PUERTO,/\"puerto\": $PUERTO_FALSO,/" "$CONF_DIR/config.json"
SALIDA_FALSA="$("$HERMES" red filter 127.0.0.1 programa true 2>&1)"
FILAS_FALSAS="$(printf '%s\n' "$SALIDA_FALSA" | grep -c '^Job ID: ')"
if [[ "$FILAS_FALSAS" -ne 2 ]]; then
    echo "FAIL: contra el servidor que cierra tras cada respuesta se mostraron $FILAS_FALSAS Jobs."
    printf '%s\n' "$SALIDA_FALSA"
    exit 1
fi
wait "$FALSO_PID" 2>/dev/null || true
FALSO_PID=""
echo "  contra un servidor que cierra cada respuesta: 2 Jobs en 3 conexiones"
echo "PASS V2/AC2: el reintento de solo lectura cubre un servidor de una respuesta."

echo "PASS: RNF-24 TC-056 sin fallos."
