#!/usr/bin/env bash
# RNF-24 - Mensajes fragmentados y solicitudes secuenciales.
# TC-051: veinte solicitudes secuenciales sobre una misma conexion, con la
# respuesta leida entre cada una. El plazo se renueva por solicitud y ninguna
# queda cortada por el limite de la primera.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45857
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
CONF_DIR="$HOME/.config/hermes"
EVENTOS="$DATA_DIR/events.jsonl"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-051.md"
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

# AC1: 20 solicitudes secuenciales por la misma conexion.
python3 - "$PUERTO" <<'PY'
import json, socket, sys, time

puerto = int(sys.argv[1])
total = 20

with socket.create_connection(("127.0.0.1", puerto), timeout=10) as s:
    inicio = time.monotonic()
    pendiente = b""
    for i in range(1, total + 1):
        rid = "tc051-%02d" % i
        s.sendall((json.dumps({"version": 1, "request_id": rid,
                               "operation": "ping", "params": {}}) + "\n").encode())
        while b"\n" not in pendiente:
            trozo = s.recv(4096)
            if not trozo:
                raise SystemExit("FAIL: la conexion se cerro en la solicitud %d" % i)
            pendiente += trozo
        linea, _, pendiente = pendiente.partition(b"\n")
        respuesta = json.loads(linea)
        if respuesta.get("ok") is not True or respuesta.get("request_id") != rid:
            raise SystemExit("FAIL: respuesta %d incorrecta: %r" % (i, respuesta))
    transcurrido = time.monotonic() - inicio
    print("  %d solicitudes atendidas en %.2f s sobre una sola conexion" % (total, transcurrido))
PY
echo "PASS V1/AC1: veinte solicitudes secuenciales atendidas sin cerrar la conexion."

# AC2: tras la ultima respuesta, el FIN del cliente cierra en silencio.
python3 - "$PUERTO" <<'PY'
import json, socket, sys

puerto = int(sys.argv[1])
s = socket.create_connection(("127.0.0.1", puerto), timeout=10)
s.sendall((json.dumps({"version": 1, "request_id": "tc051-fin",
                       "operation": "ping", "params": {}}) + "\n").encode())
datos = b""
while b"\n" not in datos:
    trozo = s.recv(4096)
    if not trozo:
        raise SystemExit("FAIL: el servidor cerro sin responder el ping final")
    datos += trozo
s.shutdown(socket.SHUT_WR)
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
if resto:
    raise SystemExit("FAIL: el servidor respondio algo tras el FIN: %r" % resto)
s.close()
print("  FIN posterior a la respuesta: cierre limpio, sin sobre de error")
PY
echo "PASS V2/AC2: el FIN del cliente tras la respuesta no genera sobre de error."

sleep 0.3

# AC3: ninguna solicitud del ciclo quedo documentada como interrumpida.
python3 - "$EVENTOS" <<'PY'
import json, os, sys

ruta = sys.argv[1]
if not os.path.exists(ruta):
    raise SystemExit("FAIL: no existe events.jsonl")
interrumpidas, ruido = [], []
with open(ruta, encoding="utf-8") as archivo:
    for linea in archivo:
        linea = linea.strip()
        if not linea:
            continue
        entrada = json.loads(linea)
        if entrada.get("message") == "Solicitud interrumpida":
            interrumpidas.append(entrada)
        if entrada.get("message") == "Cliente desconectado":
            ruido.append(entrada)
if interrumpidas:
    raise SystemExit("FAIL: %d solicitudes se documentaron como interrumpidas: %r"
                     % (len(interrumpidas), interrumpidas[0]))
if ruido:
    raise SystemExit("FAIL: el cierre ordenado quedo como ruido de desconexion: %r" % ruido[0])
print("  bitacora: 0 solicitudes interrumpidas, 0 desconexiones anomalas")
PY
echo "PASS V3/AC3: la bitacora no registra cierres anomalos."

echo "PASS: RNF-24 TC-051 sin fallos."
