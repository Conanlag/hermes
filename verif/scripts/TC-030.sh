#!/usr/bin/env bash
# RF-22 / AC1-AC4 - T-09.
# V1: submit seguido de FIN (shutdown SHUT_WR).
# V2: submit seguido de RST (SO_LINGER 0).
# V3: cliente aniquilado con SIGKILL en medio de un mensaje parcial.
# En los tres casos el servicio debe seguir vivo, aceptar un ping posterior,
# mantener jobs.json válido y llevar los Jobs aceptados a estado terminal.
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
RESULTS_FILE="$RESULTS_DIR/results_TC-030.md"
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

validar_jobs() {
    python3 - "$JOBS" <<'PY'
import json, os, sys
ruta = sys.argv[1]
if not os.path.exists(ruta):
    raise SystemExit(0)
with open(ruta, encoding="utf-8") as archivo:
    jobs = json.load(archivo)
if not isinstance(jobs, list):
    raise SystemExit("jobs.json no es un arreglo")
estados = {"QUEUED", "RUNNING", "SUCCEEDED", "FAILED", "CANCELED", "INTERRUPTED"}
for job in jobs:
    if not isinstance(job.get("job_id"), int) or job["job_id"] < 1:
        raise SystemExit("Job sin job_id válido: " + repr(job))
    if not isinstance(job.get("programa"), str) or not job["programa"]:
        raise SystemExit("Job sin programa: " + repr(job))
    if job.get("status") not in estados:
        raise SystemExit("Job con estado inválido: " + repr(job))
PY
}

esperar_terminales() {
    for _ in $(seq 1 100); do
        if python3 - "$JOBS" <<'PY'
import json, os, sys
ruta = sys.argv[1]
if not os.path.exists(ruta):
    raise SystemExit(1)
with open(ruta, encoding="utf-8") as archivo:
    jobs = json.load(archivo)
if jobs and all(job.get("status") not in ("QUEUED", "RUNNING") for job in jobs):
    raise SystemExit(0)
raise SystemExit(1)
PY
        then
            return 0
        fi
        sleep 0.1
    done
    echo "FAIL: los Jobs aceptados no alcanzaron estado terminal (AC3)."
    return 1
}

# V1: FIN después de un submit completo.
python3 - "$PUERTO" <<'PY'
import json, socket, sys, time
puerto = int(sys.argv[1])
s = socket.create_connection(("127.0.0.1", puerto), timeout=5)
carga = json.dumps({"version": 1, "request_id": "v1-fin", "operation": "submit",
                    "params": {"programa": "true", "argumentos": []}}) + "\n"
s.sendall(carga.encode())
s.shutdown(socket.SHUT_WR)
time.sleep(0.3)
try:
    s.recv(4096)
except OSError:
    pass
s.close()
PY
comprobar_servicio_vivo
ping_ok
validar_jobs
echo "PASS V1: FIN tras submit; servicio vivo y jobs.json consistente."

# V2: RST después de un submit completo.
python3 - "$PUERTO" <<'PY'
import json, socket, struct, sys
puerto = int(sys.argv[1])
s = socket.create_connection(("127.0.0.1", puerto), timeout=5)
carga = json.dumps({"version": 1, "request_id": "v2-rst", "operation": "submit",
                    "params": {"programa": "true", "argumentos": []}}) + "\n"
s.sendall(carga.encode())
s.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
s.close()
PY
comprobar_servicio_vivo
ping_ok
validar_jobs
echo "PASS V2: RST tras submit; servicio vivo y sin Jobs parciales."

# V3: SIGKILL del cliente mientras el mensaje está incompleto.
python3 - "$PUERTO" <<'PY'
import os, signal, socket, sys, time
puerto = int(sys.argv[1])
hijo = os.fork()
if hijo == 0:
    s = socket.create_connection(("127.0.0.1", puerto), timeout=5)
    s.sendall(b'{"version":1,"request_id":"v3-partial","operation":"submit","params":{"programa":"tr')
    time.sleep(30)
    os._exit(0)
time.sleep(0.5)
os.kill(hijo, signal.SIGKILL)
os.waitpid(hijo, 0)
PY
comprobar_servicio_vivo
ping_ok
validar_jobs
echo "PASS V3: SIGKILL con mensaje parcial; servicio vivo y sin Jobs parciales."

esperar_terminales
echo "PASS V4/AC3: los Jobs aceptados alcanzaron estado terminal."
echo "PASS: RF-22 T-09 (V1-V3) sin fallos."
