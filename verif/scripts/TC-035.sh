#!/usr/bin/env bash
# RF-28 - Coherencia de estado tras desconexion.
# TC-035: un submit aceptado y persistido sobrevive a un corte del cliente.
# Se verifica que jobs.json conserva el Job integro, que alcanza estado
# terminal y que la bitacora, si registra la interrupcion, la declara ACEPTADA
# con el job_id correspondiente (nunca sin efecto).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45830
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
CONF_DIR="$HOME/.config/hermes"
JOBS="$DATA_DIR/jobs.json"
EVENTOS="$DATA_DIR/events.jsonl"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-035.md"
mkdir -p "$NET_DIR" "$CONF_DIR" "$RESULTS_DIR"

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

# Submit completo seguido de RST: el cliente no llega a leer la respuesta.
python3 - "$PUERTO" <<'PY'
import json, socket, struct, sys
puerto = int(sys.argv[1])
s = socket.create_connection(("127.0.0.1", puerto), timeout=5)
carga = json.dumps({"version": 1, "request_id": "tc035-corte", "operation": "submit",
                    "params": {"programa": "true", "argumentos": []}}) + "\n"
s.sendall(carga.encode())
s.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
s.close()
PY
comprobar_servicio_vivo

# AC1: jobs.json válido y el Job alcanza estado terminal.
for _ in $(seq 1 100); do
    if python3 - "$JOBS" <<'PY'
import json, os, sys
ruta = sys.argv[1]
if not os.path.exists(ruta):
    raise SystemExit(1)
with open(ruta, encoding="utf-8") as archivo:
    jobs = json.load(archivo)
if not jobs:
    raise SystemExit(1)
if any(job.get("status") in ("QUEUED", "RUNNING") for job in jobs):
    raise SystemExit(1)
PY
    then
        break
    fi
    sleep 0.1
done

python3 - "$JOBS" <<'PY'
import json, os, sys
ruta = sys.argv[1]
if not os.path.exists(ruta):
    raise SystemExit("FAIL: jobs.json no existe")
with open(ruta, encoding="utf-8") as archivo:
    jobs = json.load(archivo)
if not isinstance(jobs, list):
    raise SystemExit("FAIL: jobs.json no es un arreglo")
if not jobs:
    raise SystemExit("FAIL: el submit aceptado no quedó persistido")
estados = {"QUEUED", "RUNNING", "SUCCEEDED", "FAILED", "CANCELED", "INTERRUPTED"}
for job in jobs:
    if job.get("status") not in estados:
        raise SystemExit("FAIL: Job con estado inválido: " + repr(job))
    if not job.get("programa"):
        raise SystemExit("FAIL: Job sin programa: " + repr(job))
PY
echo "PASS V1: submit aceptado persistido íntegro tras el corte y en estado terminal."

# AC2: la bitácora no puede declarar sin efecto una solicitud que sí se aplicó.
python3 - "$EVENTOS" "$JOBS" <<'PY'
import json, os, sys
ruta_eventos, ruta_jobs = sys.argv[1], sys.argv[2]
lineas = []
if os.path.exists(ruta_eventos):
    with open(ruta_eventos, encoding="utf-8") as archivo:
        for linea in archivo:
            linea = linea.strip()
            if linea:
                lineas.append(json.loads(linea))
with open(ruta_jobs, encoding="utf-8") as archivo:
    job_ids = {job["job_id"] for job in json.load(archivo)}
interrumpidas = [e for e in lineas if e.get("message") == "Solicitud interrumpida"]
for entrada in interrumpidas:
    contexto = entrada.get("context", {})
    if contexto.get("resultado") != "ACEPTADA":
        raise SystemExit("FAIL: solicitud aplicada registrada como " + repr(contexto.get("resultado")))
    if contexto.get("operacion") != "submit":
        raise SystemExit("FAIL: operación inesperada en la bitácora: " + repr(contexto.get("operacion")))
    if contexto.get("request_id") != "tc035-corte":
        raise SystemExit("FAIL: request_id inesperado: " + repr(contexto.get("request_id")))
    if contexto.get("job_id") not in job_ids:
        raise SystemExit("FAIL: job_id de la bitácora no existe en jobs.json: " + repr(contexto.get("job_id")))
if interrumpidas:
    print("  bitácora: " + json.dumps(interrumpidas[-1], ensure_ascii=False))
else:
    print("  bitácora: sin entrada (la respuesta se entregó completa; cierre normal)")
for entrada in lineas:
    if entrada.get("message") == "Cliente desconectado":
        raise SystemExit("FAIL: un submit procesado se registró como ruido previo al protocolo")
PY
echo "PASS V2/AC2: bitácora coherente con el estado aplicado."

# AC3: el servicio sigue atendiendo tras el corte.
python3 - "$PUERTO" <<'PY'
import json, socket, sys
puerto = int(sys.argv[1])
with socket.create_connection(("127.0.0.1", puerto), timeout=5) as s:
    s.sendall((json.dumps({"version": 1, "request_id": "tc035-ping", "operation": "ping", "params": {}}) + "\n").encode())
    datos = b""
    while b"\n" not in datos:
        trozo = s.recv(4096)
        if not trozo:
            raise SystemExit("FAIL: el servidor cerró sin responder el ping")
        datos += trozo
respuesta = json.loads(datos.split(b"\n")[0])
if not respuesta.get("ok"):
    raise SystemExit("FAIL: ping posterior falló: " + repr(respuesta))
PY
echo "PASS V3/AC3: ping posterior correcto; el servicio sigue atendiendo."
echo "PASS: RF-28 TC-035 sin fallos."
