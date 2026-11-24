#!/usr/bin/env bash
# RNF-24 - Mensajes fragmentados y solicitudes secuenciales.
# TC-052: distingue el cierre ordenado del cliente tras una respuesta completa
# (silencio, sin INCOMPLETE_MESSAGE) del mensaje truncado con bytes pendientes
# (INCOMPLETE_MESSAGE y desenlace SIN_EFECTO en la bitacora).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45858
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
CONF_DIR="$HOME/.config/hermes"
EVENTOS="$DATA_DIR/events.jsonl"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-052.md"
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

# AC1: solicitud completa, respuesta leida y FIN ordenado del cliente.
python3 - "$PUERTO" <<'PY'
import json, socket, sys

puerto = int(sys.argv[1])
s = socket.create_connection(("127.0.0.1", puerto), timeout=10)
s.sendall((json.dumps({"version": 1, "request_id": "tc052-ordenado",
                       "operation": "ping", "params": {}}) + "\n").encode())
datos = b""
while b"\n" not in datos:
    trozo = s.recv(4096)
    if not trozo:
        raise SystemExit("FAIL: el servidor cerro sin responder el ping")
    datos += trozo
if json.loads(datos.split(b"\n")[0]).get("ok") is not True:
    raise SystemExit("FAIL: ping fallido")
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
s.close()
if resto:
    raise SystemExit("FAIL: el cierre ordenado recibio un sobre extra: %r" % resto)
print("  cierre ordenado: EOF sin datos adicionales")
PY
echo "PASS V1/AC1: el FIN tras la respuesta cierra sin INCOMPLETE_MESSAGE."

sleep 0.3

# AC2: el cierre ordenado no deja registros anomalos.
python3 - "$EVENTOS" <<'PY'
import json, os, sys

ruta = sys.argv[1]
if not os.path.exists(ruta):
    raise SystemExit("FAIL: no existe events.jsonl")
anomalos = []
with open(ruta, encoding="utf-8") as archivo:
    for linea in archivo:
        linea = linea.strip()
        if not linea:
            continue
        entrada = json.loads(linea)
        if entrada.get("message") in ("Solicitud interrumpida", "Cliente desconectado"):
            anomalos.append(entrada)
if anomalos:
    raise SystemExit("FAIL: el cierre ordenado dejo %d registros: %r"
                     % (len(anomalos), anomalos[0]))
print("  bitacora: sin registros de cierre anomalo")
PY
echo "PASS V2/AC2: el cierre ordenado no registra desconexion anomala."

# AC3: mensaje truncado (bytes sin delimitador y FIN) sigue siendo incompleto.
python3 - "$PUERTO" <<'PY'
import json, socket, sys

puerto = int(sys.argv[1])
s = socket.create_connection(("127.0.0.1", puerto), timeout=10)
s.sendall(b'{"version": 1, "request_id": "tc052-truncado", "operation": "ping"')
s.shutdown(socket.SHUT_WR)
s.settimeout(5)
datos = b""
try:
    while True:
        trozo = s.recv(4096)
        if not trozo:
            break
        datos += trozo
except OSError:
    pass
s.close()
if b"INCOMPLETE_MESSAGE" not in datos:
    raise SystemExit("FAIL: el mensaje truncado no recibio INCOMPLETE_MESSAGE: %r" % datos)
print("  mensaje truncado: " + datos.decode("utf-8", "replace").strip())
PY
echo "PASS V3/AC3: el mensaje truncado conserva INCOMPLETE_MESSAGE."

sleep 0.3

# AC4: el truncado queda documentado como SIN_EFECTO con sus bytes.
python3 - "$EVENTOS" <<'PY'
import json, os, sys

ruta = sys.argv[1]
if not os.path.exists(ruta):
    raise SystemExit("FAIL: no existe events.jsonl")
interrumpidas = []
with open(ruta, encoding="utf-8") as archivo:
    for linea in archivo:
        linea = linea.strip()
        if not linea:
            continue
        entrada = json.loads(linea)
        if entrada.get("message") == "Solicitud interrumpida":
            interrumpidas.append(entrada)
if len(interrumpidas) != 1:
    raise SystemExit("FAIL: se esperaba 1 registro de solicitud interrumpida y hay %d: %r"
                     % (len(interrumpidas), interrumpidas))
contexto = interrumpidas[0].get("context", {})
if contexto.get("motivo") != "FIN_SIN_MENSAJE":
    raise SystemExit("FAIL: motivo inesperado: %r" % contexto.get("motivo"))
if contexto.get("resultado") != "SIN_EFECTO":
    raise SystemExit("FAIL: desenlace inesperado: %r" % contexto.get("resultado"))
if not contexto.get("bytes_recibidos"):
    raise SystemExit("FAIL: no se documentaron los bytes recibidos")
print("  registro: " + json.dumps(interrumpidas[0], ensure_ascii=False))
PY
echo "PASS V4/AC4: el mensaje truncado se documenta como SIN_EFECTO con sus bytes."

echo "PASS: RNF-24 TC-052 sin fallos."
