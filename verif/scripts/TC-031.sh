#!/usr/bin/env bash
# RF-22 / AC5-AC6 - T-10.
# V4: 40 conexiones envían un byte y cierran.
# V5: cliente lento con mensaje parcial: el plazo de lectura lo expulsa.
# V6: desconexión mientras el servidor entrega una respuesta de list.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45820
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
JOBS="$DATA_DIR/jobs.json"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-031.md"
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

comprobar_servicio_vivo() {
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "FAIL: el servicio terminó tras la desconexión (AC1)."
        cat "$TEST_ROOT/server.log"
        exit 1
    fi
}

ping_ok() {
    python3 - "$PUERTO" <<'PY'
import json, socket, sys
puerto = int(sys.argv[1])
with socket.create_connection(("127.0.0.1", puerto), timeout=5) as s:
    s.sendall((json.dumps({"version": 1, "request_id": "verif-ping", "operation": "ping", "params": {}}) + "\n").encode())
    datos = b""
    while b"\n" not in datos:
        trozo = s.recv(4096)
        if not trozo:
            raise SystemExit("el servidor cerró sin responder el ping")
        datos += trozo
respuesta = json.loads(datos.split(b"\n")[0])
if not respuesta.get("ok") or respuesta.get("result", {}).get("message") != "pong":
    raise SystemExit("respuesta de ping inesperada: " + str(respuesta))
PY
}

# V4: 40 conexiones que envían un byte y cierran.
python3 - "$PUERTO" <<'PY'
import socket, sys
puerto = int(sys.argv[1])
for _ in range(40):
    try:
        s = socket.create_connection(("127.0.0.1", puerto), timeout=5)
        s.sendall(b"{")
        s.close()
    except OSError:
        pass
PY
sleep 0.2
comprobar_servicio_vivo
INICIO=$(date +%s%N)
ping_ok
FIN=$(date +%s%N)
MS=$(( (FIN - INICIO) / 1000000 ))
echo "PASS V4: 40 desconexiones y ping posterior en ${MS} ms."
if (( MS > 2000 )); then
    echo "FAIL: el ping superó 2000 ms; el bucle quedó bloqueado (AC5)."
    exit 1
fi

# V5: cliente lento con mensaje parcial; el plazo de lectura lo expulsa.
python3 - "$PUERTO" <<'PY'
import socket, sys, time
puerto = int(sys.argv[1])
s = socket.create_connection(("127.0.0.1", puerto), timeout=10)
s.sendall(b'{"version":1,"request_id":"v5-slow"')
s.settimeout(10)
inicio = time.monotonic()
datos = b""
while True:
    trozo = s.recv(4096)
    if not trozo:
        break
    datos += trozo
transcurrido = time.monotonic() - inicio
if "REQUEST_TIMEOUT" not in datos.decode("utf-8", "replace"):
    raise SystemExit("el servidor no envió REQUEST_TIMEOUT: " + repr(datos))
if transcurrido > 8:
    raise SystemExit("la expulsión del cliente lento tardó demasiado: %.1fs" % transcurrido)
s.close()
print("cliente lento expulsado en %.1fs" % transcurrido)
PY
comprobar_servicio_vivo
ping_ok
echo "PASS V5: cliente lento expulsado y cupo recuperado."

# V6: desconexión con RST mientras el servidor entrega una respuesta de list.
for indice in $(seq 1 12); do
    "$HERMES" red job 127.0.0.1 true >/dev/null 2>&1 || true
done
python3 - "$PUERTO" <<'PY'
import json, socket, struct, sys
puerto = int(sys.argv[1])
s = socket.create_connection(("127.0.0.1", puerto), timeout=5)
s.sendall((json.dumps({"version": 1, "request_id": "v6-list", "operation": "list",
                       "params": {"tipo": "programa", "valor": "true"}}) + "\n").encode())
s.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
s.close()
PY
comprobar_servicio_vivo
ping_ok
echo "PASS V6: desconexión durante una respuesta grande; servicio y bucle intactos."
echo "PASS: RF-22 T-10 (V4-V6) sin fallos."
