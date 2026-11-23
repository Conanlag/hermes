#!/usr/bin/env bash
# RF-28 - Coherencia de estado tras desconexion.
# TC-036: una operacion rechazada (NOT_CANCELABLE) cuyo cliente corta antes de
# leer la respuesta no altera jobs.json y queda documentada como RECHAZADA con
# su codigo de error. Nunca puede registrarse como ACEPTADA.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45831
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
CONF_DIR="$HOME/.config/hermes"
JOBS="$DATA_DIR/jobs.json"
EVENTOS="$DATA_DIR/events.jsonl"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-036.md"
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

comprobar_servicio_vivo() {
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "FAIL: el servicio terminó tras la desconexión."
        cat "$TEST_ROOT/server.log"
        exit 1
    fi
}

# Job en estado terminal: ya no es cancelable.
python3 - "$PUERTO" <<'PY'
import json, socket, sys
puerto = int(sys.argv[1])
with socket.create_connection(("127.0.0.1", puerto), timeout=5) as s:
    s.sendall((json.dumps({"version": 1, "request_id": "tc036-base", "operation": "submit",
                           "params": {"programa": "true", "argumentos": []}}) + "\n").encode())
    datos = b""
    while b"\n" not in datos:
        trozo = s.recv(4096)
        if not trozo:
            raise SystemExit("FAIL: el servidor cerró sin confirmar el submit")
        datos += trozo
    respuesta = json.loads(datos.split(b"\n")[0])
if not respuesta.get("ok"):
    raise SystemExit("FAIL: el submit previo no fue aceptado: " + repr(respuesta))
PY

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
        break
    fi
    sleep 0.1
done

JOB_ID="$(python3 - "$JOBS" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as archivo:
    jobs = json.load(archivo)
print(jobs[-1]["job_id"])
PY
)"
ANTES="$(sha256sum "$JOBS" | awk '{print $1}')"
echo "Job base en estado terminal: $JOB_ID"

# Cancelación rechazada con corte inmediato del cliente tras enviar.
python3 - "$PUERTO" "$JOB_ID" <<'PY'
import json, socket, struct, sys
puerto, job_id = int(sys.argv[1]), int(sys.argv[2])
s = socket.create_connection(("127.0.0.1", puerto), timeout=5)
carga = json.dumps({"version": 1, "request_id": "tc036-rechazo", "operation": "cancel",
                    "params": {"job_id": job_id}}) + "\n"
s.sendall(carga.encode())
s.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
s.close()
PY
comprobar_servicio_vivo
sleep 0.3

# AC1: jobs.json no cambió ni un byte: la operación rechazada no tuvo efecto.
DESPUES="$(sha256sum "$JOBS" | awk '{print $1}')"
if [[ "$ANTES" != "$DESPUES" ]]; then
    echo "FAIL: jobs.json cambió tras una cancelación rechazada."
    exit 1
fi
echo "PASS V1: jobs.json idéntico; la operación rechazada no alteró el estado."

# AC2: la bitácora declara RECHAZADA con código y job_id, nunca ACEPTADA.
python3 - "$EVENTOS" "$JOB_ID" <<'PY'
import json, os, sys
ruta, job_id = sys.argv[1], int(sys.argv[2])
lineas = []
if os.path.exists(ruta):
    with open(ruta, encoding="utf-8") as archivo:
        for linea in archivo:
            linea = linea.strip()
            if linea:
                lineas.append(json.loads(linea))
interrumpidas = [e for e in lineas if e.get("message") == "Solicitud interrumpida"]
for entrada in interrumpidas:
    contexto = entrada.get("context", {})
    if contexto.get("resultado") != "RECHAZADA":
        raise SystemExit("FAIL: rechazo registrado como " + repr(contexto.get("resultado")))
    if contexto.get("error") != "NOT_CANCELABLE":
        raise SystemExit("FAIL: código de error inesperado: " + repr(contexto.get("error")))
    if contexto.get("operacion") != "cancel":
        raise SystemExit("FAIL: operación inesperada: " + repr(contexto.get("operacion")))
    if contexto.get("job_id") != job_id:
        raise SystemExit("FAIL: job_id inesperado: " + repr(contexto.get("job_id")))
if not interrumpidas:
    raise SystemExit("FAIL: el rechazo interrumpido no quedó documentado")
print("  bitácora: " + json.dumps(interrumpidas[-1], ensure_ascii=False))
PY
echo "PASS V2/AC2: rechazo documentado como RECHAZADA con NOT_CANCELABLE y job_id."

# AC3: el servicio sigue atendiendo y el Job original sigue terminal.
python3 - "$PUERTO" "$JOBS" <<'PY'
import json, socket, sys
puerto, ruta = int(sys.argv[1]), sys.argv[2]
with socket.create_connection(("127.0.0.1", puerto), timeout=5) as s:
    s.sendall((json.dumps({"version": 1, "request_id": "tc036-ping", "operation": "ping", "params": {}}) + "\n").encode())
    datos = b""
    while b"\n" not in datos:
        trozo = s.recv(4096)
        if not trozo:
            raise SystemExit("FAIL: el servidor cerró sin responder el ping")
        datos += trozo
if not json.loads(datos.split(b"\n")[0]).get("ok"):
    raise SystemExit("FAIL: ping posterior falló")
with open(ruta, encoding="utf-8") as archivo:
    jobs = json.load(archivo)
if jobs[-1]["status"] not in ("SUCCEEDED", "FAILED"):
    raise SystemExit("FAIL: el Job base no conservó su estado terminal: " + repr(jobs[-1]))
PY
echo "PASS V3/AC3: ping posterior correcto y Job base intacto."
echo "PASS: RF-28 TC-036 sin fallos."
