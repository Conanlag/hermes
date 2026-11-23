#!/usr/bin/env bash
# RF-22 / AC7 - T-12.
# V8: el ruido previo al protocolo (conexiones cerradas sin enviar datos) queda
# en la bitácora con un máximo de un aviso por motivo cada 60 s, y un ping
# normal no genera ruido. RF-28 acotó la ventana a ese caso: una solicitud que
# ya empezó a recibirse se documenta siempre (TC-035 a TC-038).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45843
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
EVENTS="$DATA_DIR/events.jsonl"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-033.md"
mkdir -p "$NET_DIR" "$RESULTS_DIR"
CONF_DIR="$HOME/.config/hermes"
mkdir -p "$CONF_DIR"

# Puerto propio: la prueba no debe chocar con un servidor en marcha del usuario.
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

contar() {
    local patron="$1"
    if [[ ! -f "$EVENTS" ]]; then
        printf '0\n'
        return 0
    fi
    grep -c "$patron" "$EVENTS" || true
}

# Cinco cortes antes de recibir datos: ruido previo al protocolo. RF-28 deja
# fuera de la ventana toda solicitud que ya empezó a recibirse, así que este
# caso usa conexiones que se cierran sin enviar un solo byte.
python3 - "$PUERTO" <<'PY'
import socket, sys
puerto = int(sys.argv[1])
for _ in range(5):
    s = socket.create_connection(("127.0.0.1", puerto), timeout=5)
    s.close()
PY
sleep 0.5

AVISOS="$(contar 'Cliente desconectado')"
MOTIVOS="$(contar 'FIN_SIN_MENSAJE')"
echo "Avisos 'Cliente desconectado' tras 5 desconexiones: $AVISOS (motivo FIN_SIN_MENSAJE: $MOTIVOS)"

if [[ "$AVISOS" -lt 1 ]]; then
    echo "FAIL: la desconexión anómala no quedó registrada (AC7)."
    exit 1
fi
if [[ "$AVISOS" -gt 1 || "$MOTIVOS" -gt 1 ]]; then
    echo "FAIL: la ventana de 60 s no limitó los avisos repetidos."
    exit 1
fi

# Un ping normal no debe añadir avisos.
python3 - "$PUERTO" <<'PY'
import json, socket, sys
puerto = int(sys.argv[1])
with socket.create_connection(("127.0.0.1", puerto), timeout=5) as s:
    s.sendall((json.dumps({"version": 1, "request_id": "v8-ping", "operation": "ping", "params": {}}) + "\n").encode())
    datos = b""
    while b"\n" not in datos:
        trozo = s.recv(4096)
        if not trozo:
            raise SystemExit("ping sin respuesta")
        datos += trozo
PY
sleep 0.3
DESPUES="$(contar 'Cliente desconectado')"
if [[ "$DESPUES" != "$AVISOS" ]]; then
    echo "FAIL: un cierre normal generó avisos en la bitácora."
    exit 1
fi

if [[ "$(contar 'ERROR_INTERNO')" -gt 0 ]]; then
    echo "FAIL: la bitácora registró errores internos durante la prueba."
    exit 1
fi

echo "PASS V8: desconexión anómala registrada una sola vez y sin ruido en cierres normales."
echo "PASS: RF-22 T-12 (V8) sin fallos."
