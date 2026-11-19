#!/usr/bin/env bash
# RF-22 / AC4 - T-11.
# V7: 100 ciclos de conexión/desconexión no deben dejar descriptores abiertos
# ni archivos temporales de persistencia en el proceso servidor.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45820
CICLOS="${1:-100}"
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-032.md"
mkdir -p "$NET_DIR" "$RESULTS_DIR"

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

if [[ ! "$CICLOS" =~ ^[0-9]+$ ]] || (( CICLOS < 10 )); then
    echo "FAIL: indica al menos 10 ciclos (uso: bash verif/scripts/TC-032.sh [ciclos])."
    exit 1
fi
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

contar_fds() {
    find "/proc/$SERVER_PID/fd" -mindepth 1 -maxdepth 1 -type l 2>/dev/null | wc -l
}

sleep 0.5
BASE_FDS="$(contar_fds)"
echo "Línea base del servidor: FDs=$BASE_FDS"

python3 - "$PUERTO" "$CICLOS" <<'PY'
import json, socket, struct, sys, time
puerto = int(sys.argv[1])
ciclos = int(sys.argv[2])
for indice in range(ciclos):
    modo = indice % 3
    try:
        s = socket.create_connection(("127.0.0.1", puerto), timeout=5)
        if modo == 0:
            s.close()
            continue
        if modo == 1:
            s.sendall((json.dumps({"version": 1, "request_id": "v7-%d" % indice,
                                   "operation": "ping", "params": {}}) + "\n").encode())
            s.settimeout(5)
            datos = b""
            while b"\n" not in datos:
                trozo = s.recv(4096)
                if not trozo:
                    break
                datos += trozo
            s.close()
            continue
        s.sendall(b'{"version":1,"request_id":"v7-parcial"')
        s.shutdown(socket.SHUT_WR)
        s.settimeout(5)
        while s.recv(4096):
            pass
        s.close()
    except OSError:
        pass
PY

sleep 1
AFTER_FDS="$(contar_fds)"
echo "Después de $CICLOS ciclos: FDs=$AFTER_FDS"

if [[ "$AFTER_FDS" != "$BASE_FDS" ]]; then
    echo "FAIL: el servidor no recuperó su cantidad inicial de descriptores (AC4)."
    ls -l "/proc/$SERVER_PID/fd"
    exit 1
fi
if compgen -G "$DATA_DIR/jobs.json.tmp.*" >/dev/null; then
    echo "FAIL: quedaron archivos temporales de persistencia."
    exit 1
fi
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "FAIL: el servicio terminó durante los ciclos (AC1)."
    exit 1
fi

echo "PASS V7: sin fuga de descriptores tras $CICLOS ciclos de conexión/desconexión."
echo "PASS: RF-22 T-11 (V7) sin fallos."
