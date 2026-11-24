#!/usr/bin/env bash
# RNF-24 - Mensajes fragmentados y solicitudes secuenciales.
# TC-055: los buffers son por conexion. Un cliente que deja un mensaje a medias
# no bloquea a otro ni contamina su solicitud, y al completar su mensaje recibe
# su propia respuesta.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45861
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
CONF_DIR="$HOME/.config/hermes"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-055.md"
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

# AC1: A deja su mensaje a medias; B se atiende completo aunque A siga abierto.
python3 - "$PUERTO" <<'PY'
import json, socket, sys, time

puerto = int(sys.argv[1])
a = socket.create_connection(("127.0.0.1", puerto), timeout=10)
# Mensaje deliberadamente incompleto: falta '}}\n'.
a.sendall(b'{"version": 1, "request_id": "tc055-a", "operation": "ping", "params":')
time.sleep(0.4)

inicio = time.monotonic()
b = socket.create_connection(("127.0.0.1", puerto), timeout=10)
b.sendall((json.dumps({"version": 1, "request_id": "tc055-b",
                       "operation": "ping", "params": {}}) + "\n").encode())
datos = b""
while b"\n" not in datos:
    trozo = b.recv(4096)
    if not trozo:
        raise SystemExit("FAIL: el servidor cerro la conexion B sin responder")
    datos += trozo
espera = time.monotonic() - inicio
respuesta = json.loads(datos.split(b"\n")[0])
b.close()
if respuesta.get("ok") is not True or respuesta.get("request_id") != "tc055-b":
    raise SystemExit("FAIL: B no recibio su propia respuesta: %r" % respuesta)
if espera > 2.0:
    raise SystemExit("FAIL: B espero %.2f s; el mensaje a medias de A bloqueo el servicio" % espera)
print("  B atendido en %.2f s mientras A tenia un mensaje a medias" % espera)

# A completa su mensaje y debe recibir su respuesta, sin rastro de la de B.
a.sendall(b'{}}\n')
a.settimeout(10)
datos = b""
while b"\n" not in datos:
    trozo = a.recv(4096)
    if not trozo:
        raise SystemExit("FAIL: el servidor cerro A sin completar su solicitud")
    datos += trozo
a.close()
respuesta_a = json.loads(datos.split(b"\n")[0])
if respuesta_a.get("ok") is not True or respuesta_a.get("request_id") != "tc055-a":
    raise SystemExit("FAIL: A recibio una respuesta ajena: %r" % respuesta_a)
print("  A completo su mensaje y recibio: " + json.dumps(respuesta_a, ensure_ascii=False))
PY
echo "PASS V1/AC1: cada conexion conserva su propio mensaje a medias."

# AC2: el servicio sigue atendiendo tras el cruce.
python3 - "$PUERTO" <<'PY'
import json, socket, sys

puerto = int(sys.argv[1])
with socket.create_connection(("127.0.0.1", puerto), timeout=5) as s:
    s.sendall((json.dumps({"version": 1, "request_id": "tc055-ping",
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
echo "PASS V2/AC2: ping posterior correcto."

echo "PASS: RNF-24 TC-055 sin fallos."
