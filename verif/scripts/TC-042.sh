#!/usr/bin/env bash
# RNF-14 - Validacion de longitud y formato de mensajes de red.
# TC-042: dos mensajes en un solo envio se validan de forma independiente: el
# valido se procesa y el invalido se rechaza con su codigo. RNF-24 cambio el
# transporte (varias solicitudes por conexion), no la validacion: un segundo
# sobre no puede colarse sin validar ni crear estado.
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

# AC1: sobre valido + sobre invalido (version 2) en un solo write.
python3 - "$PUERTO" <<'PY'
import json, socket, sys

puerto = int(sys.argv[1])
primero = {"version": 1, "request_id": "tc042-primero", "operation": "submit",
           "params": {"programa": "true", "argumentos": []}}
segundo = {"version": 2, "request_id": "tc042-segundo", "operation": "submit",
           "params": {"programa": "true", "argumentos": []}}
carga = (json.dumps(primero) + "\n" + json.dumps(segundo) + "\n").encode()

with socket.create_connection(("127.0.0.1", puerto), timeout=5) as s:
    s.sendall(carga)
    datos = b""
    while datos.count(b"\n") < 2:
        trozo = s.recv(4096)
        if not trozo:
            break
        datos += trozo
    lineas = [l for l in datos.split(b"\n") if l.strip()]

if len(lineas) != 2:
    raise SystemExit("FAIL: se esperaban 2 respuestas y llegaron %d: %r" % (len(lineas), datos))

primera = json.loads(lineas[0])
if primera.get("ok") is not True or primera.get("request_id") != "tc042-primero":
    raise SystemExit("FAIL: el primer mensaje no fue aceptado: " + repr(primera))

segunda = json.loads(lineas[1])
if segunda.get("ok") is not False or segunda.get("error") != "UNSUPPORTED_VERSION":
    raise SystemExit("FAIL: el segundo mensaje no fue rechazado por version: " + repr(segunda))
print("  respuesta 1: " + json.dumps(primera, ensure_ascii=False))
print("  respuesta 2: " + json.dumps(segunda, ensure_ascii=False))
PY
echo "PASS V1/AC1: el valido se atendio y el invalido se rechazo con su codigo."

sleep 0.5

# AC2: el segundo mensaje no creo estado; solo hay un Job.
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
    raise SystemExit("FAIL: el segundo mensaje del envio creo estado")
print("  jobs.json: %d Job, sin rastro del segundo mensaje" % len(jobs))
PY
echo "PASS V2/AC2: el mensaje invalido se rechazo sin crear estado."

# AC3: el rechazo cerro esa conexion y el servicio sigue atendiendo.
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
            raise SystemExit("FAIL: el servidor cerro sin responder el ping")
        datos += trozo
if json.loads(datos.split(b"\n")[0]).get("ok") is not True:
    raise SystemExit("FAIL: ping posterior fallido")
PY
echo "PASS V3/AC3: ping posterior correcto; el servicio sigue atendiendo."

echo "PASS: RNF-14 TC-042 sin fallos."
