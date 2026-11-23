#!/usr/bin/env bash
# RNF-14 - Validacion de longitud y formato de mensajes de red.
# TC-042: dos mensajes en un solo envio se resuelven como uno: solo el primero
# se procesa, el segundo se descarta con la conexion y no crea estado.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45853
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
CONF_DIR="$HOME/.config/hermes"
JOBS="$DATA_DIR/jobs.json"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-042.md"
mkdir -p "$NET_DIR" "$CONF_DIR" "$RESULTS_DIR"

cat >"$CONF_DIR/config.json" <<JSON
{
  "interfaz": "127.0.0.1",
  "puerto": $PUERTO,
  "redes_permitidas": ["127.0.0.0/8"],
  "trabajos_maximos": 4,
  "max_cola": 5
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
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$PUERTO\$"
}

if [[ ! -x "$HERMES" ]]; then
    echo "FAIL: no existe $HERMES. Compila Hermes antes de ejecutar la prueba."
    exit 1
fi
if puerto_ocupado; then
    echo "FAIL: el puerto $PUERTO ya está en uso; detenga el servidor previo."
    exit 1
fi

echo "Arrancando 'hermes red start' con HOME temporal..."
"$HERMES" red start >"$TEST_ROOT/server.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 100); do
    puerto_ocupado && break
    sleep 0.1
done
if ! puerto_ocupado; then
    echo "FAIL: el servidor no abrió el puerto $PUERTO."
    cat "$TEST_ROOT/server.log"
    exit 1
fi

# AC1: dos sobres validos en un solo write; solo el primero recibe respuesta.
python3 - "$PUERTO" <<'PY'
import json, socket, sys

puerto = int(sys.argv[1])
primero = {"version": 1, "request_id": "tc042-primero", "operation": "submit",
           "params": {"programa": "true", "argumentos": []}}
segundo = {"version": 1, "request_id": "tc042-segundo", "operation": "submit",
           "params": {"programa": "true", "argumentos": []}}
carga = (json.dumps(primero) + "\n" + json.dumps(segundo) + "\n").encode()

with socket.create_connection(("127.0.0.1", puerto), timeout=5) as s:
    s.sendall(carga)
    datos = b""
    while b"\n" not in datos:
        trozo = s.recv(4096)
        if not trozo:
            raise SystemExit("FAIL: el servidor cerró sin responder el primer mensaje")
        datos += trozo
    respuesta = json.loads(datos.split(b"\n")[0])

if respuesta.get("ok") is not True:
    raise SystemExit("FAIL: el primer mensaje no fue aceptado: " + repr(respuesta))
if respuesta.get("request_id") != "tc042-primero":
    raise SystemExit("FAIL: la respuesta no corresponde al primer mensaje: " + repr(respuesta))
print("  respuesta del primer mensaje: " + json.dumps(respuesta, ensure_ascii=False))
PY
echo "PASS V1/AC1: solo el primer mensaje del envío recibió respuesta."

sleep 0.5

# AC2: el segundo mensaje no creó estado ni un segundo Job.
python3 - "$JOBS" <<'PY'
import json, os, sys

ruta = sys.argv[1]
if not os.path.exists(ruta):
    raise SystemExit("FAIL: no se creó jobs.json")
with open(ruta, encoding="utf-8") as archivo:
    jobs = json.load(archivo)
if len(jobs) != 1:
    raise SystemExit("FAIL: se esperaba 1 Job y hay %d: %r" % (len(jobs), jobs))
if "tc042-segundo" in json.dumps(jobs):
    raise SystemExit("FAIL: el segundo mensaje del envío creó estado")
print("  jobs.json: %d Job, sin rastro del segundo mensaje" % len(jobs))
PY
echo "PASS V2/AC2: el segundo mensaje se descartó con la conexión; no creó estado."

# AC3: el servicio sigue atendiendo después del descarte.
python3 - "$PUERTO" <<'PY'
import json, socket, sys

puerto = int(sys.argv[1])
with socket.create_connection(("127.0.0.1", puerto), timeout=5) as s:
    s.sendall((json.dumps({"version": 1, "request_id": "tc042-ping",
                           "operation": "ping", "params": {}}) + "\n").encode())
    datos = b""
    while b"\n" not in datos:
        trozo = s.recv(4096)
        if not trozo:
            raise SystemExit("FAIL: el servidor cerró sin responder el ping")
        datos += trozo
if json.loads(datos.split(b"\n")[0]).get("ok") is not True:
    raise SystemExit("FAIL: ping posterior fallido")
PY
echo "PASS V3/AC3: ping posterior correcto; el servicio sigue atendiendo."
echo "PASS: RNF-14 TC-042 sin fallos."
