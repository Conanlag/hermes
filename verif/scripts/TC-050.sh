#!/usr/bin/env bash
# RNF-24 - Mensajes fragmentados y solicitudes secuenciales.
# TC-050: dos solicitudes validas encadenadas en un solo write se atienden
# ambas, en orden FIFO, y cada una produce su propio efecto.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45856
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
CONF_DIR="$HOME/.config/hermes"
JOBS="$DATA_DIR/jobs.json"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-050.md"
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

# AC1: ping y submit encadenados en un unico write, ambos en la misma conexion.
python3 - "$PUERTO" <<'PY'
import json, socket, sys

puerto = int(sys.argv[1])
primero = {"version": 1, "request_id": "tc050-uno", "operation": "ping", "params": {}}
segundo = {"version": 1, "request_id": "tc050-dos", "operation": "submit",
           "params": {"programa": "true", "argumentos": []}}
carga = (json.dumps(primero) + "\n" + json.dumps(segundo) + "\n").encode()

with socket.create_connection(("127.0.0.1", puerto), timeout=10) as s:
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
primera, segunda = json.loads(lineas[0]), json.loads(lineas[1])
if primera.get("request_id") != "tc050-uno" or primera.get("result", {}).get("message") != "pong":
    raise SystemExit("FAIL: la primera respuesta no es el ping: " + repr(primera))
if segunda.get("request_id") != "tc050-dos" or segunda.get("ok") is not True:
    raise SystemExit("FAIL: la segunda respuesta no es el submit: " + repr(segunda))
print("  respuesta 1: " + json.dumps(primera, ensure_ascii=False))
print("  respuesta 2: " + json.dumps(segunda, ensure_ascii=False))
PY
echo "PASS V1/AC1: las dos solicitudes encadenadas se atendieron en orden FIFO."

sleep 0.5

# AC2: solo el submit creo estado; el ping no.
python3 - "$JOBS" <<'PY'
import json, os, sys

ruta = sys.argv[1]
if not os.path.exists(ruta):
    raise SystemExit("FAIL: no se creó jobs.json")
with open(ruta, encoding="utf-8") as archivo:
    jobs = json.load(archivo)
if len(jobs) != 1:
    raise SystemExit("FAIL: se esperaba 1 Job y hay %d: %r" % (len(jobs), jobs))
if jobs[0].get("request_id") != "red-tcp-PC-B-tc050-dos":
    raise SystemExit("FAIL: el Job no corresponde al segundo sobre: %r" % jobs[0])
print("  jobs.json: 1 Job, request_id %s" % jobs[0].get("request_id"))
PY
echo "PASS V2/AC2: el segundo sobre creo su Job y el ping no dejo estado."

# AC3: la conexion quedo sincronizada; otra solicitud posterior responde.
python3 - "$PUERTO" <<'PY'
import json, socket, sys

puerto = int(sys.argv[1])
with socket.create_connection(("127.0.0.1", puerto), timeout=5) as s:
    s.sendall((json.dumps({"version": 1, "request_id": "tc050-tres",
                           "operation": "ping", "params": {}}) + "\n").encode())
    datos = b""
    while b"\n" not in datos:
        trozo = s.recv(4096)
        if not trozo:
            raise SystemExit("FAIL: el servidor cerro sin responder")
        datos += trozo
if json.loads(datos.split(b"\n")[0]).get("ok") is not True:
    raise SystemExit("FAIL: ping posterior fallido")
PY
echo "PASS V3/AC3: el servicio sigue atendiendo tras la rafaga."

echo "PASS: RNF-24 TC-050 sin fallos."
