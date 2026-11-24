#!/usr/bin/env bash
# RNF-24 - Mensajes fragmentados y solicitudes secuenciales.
# TC-054: el plazo de 3 s se renueva por solicitud pero sigue vigente entre
# ellas: una conexion que responde una solicitud y luego queda inactiva mas de
# 3 s se cierra con REQUEST_TIMEOUT, sin heredar el plazo de la primera.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45860
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
CONF_DIR="$HOME/.config/hermes"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-054.md"
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

# AC1: primera solicitud atendida, luego 4 s de inactividad -> REQUEST_TIMEOUT.
python3 - "$PUERTO" <<'PY'
import json, socket, sys, time

puerto = int(sys.argv[1])
s = socket.create_connection(("127.0.0.1", puerto), timeout=10)
s.sendall((json.dumps({"version": 1, "request_id": "tc054-uno",
                       "operation": "ping", "params": {}}) + "\n").encode())
datos = b""
while b"\n" not in datos:
    trozo = s.recv(4096)
    if not trozo:
        raise SystemExit("FAIL: el servidor cerro sin responder la primera solicitud")
    datos += trozo
if json.loads(datos.split(b"\n")[0]).get("ok") is not True:
    raise SystemExit("FAIL: la primera solicitud no fue aceptada: %r" % datos)

inicio = time.monotonic()
time.sleep(4.0)
s.settimeout(5)
resto = b""
try:
    while True:
        trozo = s.recv(4096)
        if not trozo:
            break
        resto += trozo
except OSError:
    pass
transcurrido = time.monotonic() - inicio
s.close()
if b"REQUEST_TIMEOUT" not in resto:
    raise SystemExit("FAIL: la inactividad no produjo REQUEST_TIMEOUT: %r" % resto)
print("  primera respuesta: pong; tras %.1f s de inactividad: %s"
      % (transcurrido, resto.decode("utf-8", "replace").strip()))
PY
echo "PASS V1/AC1: el plazo se renovo por solicitud y vencio durante la inactividad."

# AC2: el cierre por inactividad documenta el desenlace de la solicitud
# atendida (RF-28) con motivo TIMEOUT_LECTURA; no inventa ruido de desconexion.
python3 - "$DATA_DIR/events.jsonl" <<'PY'
import json, os, sys

ruta = sys.argv[1]
if not os.path.exists(ruta):
    raise SystemExit("FAIL: no existe events.jsonl")
timeouts, ruido = [], []
with open(ruta, encoding="utf-8") as archivo:
    for linea in archivo:
        linea = linea.strip()
        if not linea:
            continue
        entrada = json.loads(linea)
        contexto = entrada.get("context", {})
        if entrada.get("message") == "Solicitud interrumpida" and \
                contexto.get("motivo") == "TIMEOUT_LECTURA":
            timeouts.append(entrada)
        if entrada.get("message") == "Cliente desconectado" and \
                contexto.get("motivo") == "TIMEOUT_LECTURA":
            ruido.append(entrada)
if len(timeouts) != 1:
    raise SystemExit("FAIL: se esperaba 1 solicitud documentada por timeout y hay %d: %r"
                     % (len(timeouts), timeouts))
contexto = timeouts[0].get("context", {})
if contexto.get("resultado") != "ACEPTADA" or contexto.get("request_id") != "tc054-uno":
    raise SystemExit("FAIL: el desenlace documentado no corresponde al ping aceptado: %r" % contexto)
if ruido:
    raise SystemExit("FAIL: una solicitud atendida se documento como desconexion previa: %r" % ruido[0])
print("  bitacora: " + json.dumps(timeouts[0], ensure_ascii=False))
PY
echo "PASS V2/AC2: la inactividad documenta TIMEOUT_LECTURA sobre la solicitud aceptada."

# AC3: el servicio sigue atendiendo a otros clientes.
python3 - "$PUERTO" <<'PY'
import json, socket, sys

puerto = int(sys.argv[1])
with socket.create_connection(("127.0.0.1", puerto), timeout=5) as s:
    s.sendall((json.dumps({"version": 1, "request_id": "tc054-ping",
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
echo "PASS V3/AC3: ping posterior correcto."

echo "PASS: RNF-24 TC-054 sin fallos."
