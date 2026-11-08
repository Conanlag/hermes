#!/bin/bash
# TC-002: Integración bajo estrés del límite de concurrencia y la cola
# Requisitos: RF-03, RF-05, RNF-04, RNF-07
# Uso (WSL): bash verif/scripts/TC-002.sh   (desde la raíz del repo)
# Evidencia: verif/results/tc002.log

echo "=== Ejecutando TC-002 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || { echo "[ FAIL ] TC-002 (no se pudo entrar a src/hermes)"; exit 1; }

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc002.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
DATA="$DATA_DIR/jobs.json"
CONFIG_FILE="$DATA_DIR/config.json"
LOCK="$DATA_DIR/scheduler.lock"

# Límite de concurrencia (workers) y cupos de espera (QUEUED).
LIMITE=3
COLA=1
SOLICITUDES=$((LIMITE + COLA))
DURACION=10

find_scheduler_pid() {
    local descriptor target process_path
    for descriptor in /proc/[0-9]*/fd/*; do
        [[ -e "$descriptor" ]] || continue
        target="$(readlink "$descriptor" 2>/dev/null || true)"
        if [[ "$target" == "$LOCK" ]]; then
            process_path="${descriptor#/proc/}"
            printf '%s\n' "${process_path%%/*}"
            return 0
        fi
    done
    return 0
}

cleanup() {
    local scheduler_pid
    scheduler_pid="$(find_scheduler_pid)"
    if [[ -n "$scheduler_pid" ]]; then
        kill "$scheduler_pid" 2>/dev/null || true
        for _ in $(seq 1 30); do
            kill -0 "$scheduler_pid" 2>/dev/null || break
            sleep 0.1
        done
        kill -9 "$scheduler_pid" 2>/dev/null || true
    fi
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

FALLOS=0

fallar() {
    echo "[ FAIL ] $1"
    FALLOS=1
}

# Resumen del historial: "<total> <running> <queued>"; "ERROR" si no se puede leer.
leer_estado() {
    python3 - "$DATA" <<'PYEOF'
import collections
import json
import sys

try:
    with open(sys.argv[1], "r") as archivo:
        jobs = json.load(archivo)
except Exception:
    print("ERROR")
    sys.exit(0)

conteo = collections.Counter(j.get("status") for j in jobs)
print(len(jobs), conteo.get("RUNNING", 0), conteo.get("QUEUED", 0))
PYEOF
}

# Paso 1: compilación limpia
make clean && make
if [ $? -ne 0 ]; then
    echo "[ FAIL ] TC-002 (compilación)"
    exit 1
fi
echo "Paso 1 OK (compilación limpia y ejecutable actualizado)"

# Paso 2: forzar la configuración del escenario
mkdir -p "$DATA_DIR"
cat <<EOF > "$CONFIG_FILE"
{
  "trabajos_maximos": $LIMITE,
  "max_cola": $COLA
}
EOF
echo "Paso 2 OK (trabajos_maximos=$LIMITE, max_cola=$COLA)"

# Paso 3: ráfaga de solicitudes de larga duración (4 para 3 workers)
SALIDAS="$TEST_HOME/salidas"
mkdir -p "$SALIDAS"
PIDS=()
for i in $(seq 1 "$SOLICITUDES"); do
    ./hermes job sleep "$DURACION" > "$SALIDAS/job-$i.txt" 2>&1 &
    PIDS+=("$!")
done

ADMITIDAS=0
IDS=()
for i in $(seq 1 "$SOLICITUDES"); do
    if wait "${PIDS[$((i - 1))]}"; then
        ADMITIDAS=$((ADMITIDAS + 1))
    else
        echo "  solicitud $i rechazada: $(cat "$SALIDAS/job-$i.txt")"
    fi
    id="$(grep -oP 'job ID: \K[0-9]+' "$SALIDAS/job-$i.txt" | head -n 1)"
    [[ -n "$id" ]] && IDS+=("$id")
done

if [ "$ADMITIDAS" -eq "$SOLICITUDES" ] && [ "${#IDS[@]}" -eq "$SOLICITUDES" ]; then
    echo "Paso 3 OK ($ADMITIDAS/$SOLICITUDES solicitudes admitidas: ${IDS[*]})"
else
    fallar "solo se admitieron $ADMITIDAS de $SOLICITUDES solicitudes (se esperaba la cola de espera, no un rechazo)"
fi

# Paso 4: auditoría inmediata del límite (RNF-04 y RNF-07).
# Se espera de forma acotada a que el pool ocupe sus workers; en cuanto el
# tercer Job entra en RUNNING el estado es estable porque los Jobs duran 10 s.
ESTADO=""
for _ in $(seq 1 100); do
    ESTADO="$(leer_estado)"
    read -r TOTAL_JOBS RUNNING QUEUED <<< "$ESTADO"
    [[ "$RUNNING" =~ ^[0-9]+$ ]] || { sleep 0.1; continue; }
    [ "$RUNNING" -ge "$LIMITE" ] && break
    sleep 0.1
done
read -r TOTAL_JOBS RUNNING QUEUED <<< "$ESTADO"
[[ "$TOTAL_JOBS" =~ ^[0-9]+$ ]] || TOTAL_JOBS=0
[[ "$RUNNING" =~ ^[0-9]+$ ]] || RUNNING=0
[[ "$QUEUED" =~ ^[0-9]+$ ]] || QUEUED=0

if [ "$TOTAL_JOBS" = "$SOLICITUDES" ]; then
    echo "Paso 4 OK ($TOTAL_JOBS Jobs persistidos)"
else
    fallar "se esperaban $SOLICITUDES Jobs persistidos y hay ${TOTAL_JOBS:-0}"
fi

if [ "$RUNNING" -eq "$LIMITE" ]; then
    echo "Paso 5 OK ($RUNNING Jobs RUNNING con límite $LIMITE)"
else
    fallar "se esperaban exactamente $LIMITE Jobs RUNNING y hay ${RUNNING:-0}"
fi

# Paso 6: el excedente quedó retenido en cola (RF-03)
if [ "$QUEUED" -eq "$COLA" ]; then
    echo "Paso 6 OK ($QUEUED Job QUEUED retenido)"
else
    fallar "se esperaba exactamente $COLA Job QUEUED y hay ${QUEUED:-0}"
fi

QUEUED_ID="$(python3 - "$DATA" <<'PYEOF'
import json
import sys

jobs = json.load(open(sys.argv[1]))
for job in jobs:
    if job.get("status") == "QUEUED":
        print(job.get("job_id"))
        break
PYEOF
)"

if [ -z "$QUEUED_ID" ]; then
    fallar "no se pudo identificar el Job en espera"
else
    echo "Paso 6.1 (auditoría del Job $QUEUED_ID):"
    PYTHON_RES="$(python3 - "$DATA" "$QUEUED_ID" <<'PYEOF'
import json
import sys

data_file = sys.argv[1]
target_id = int(sys.argv[2])

try:
    with open(data_file, "r") as archivo:
        jobs = json.load(archivo)
except Exception as error:
    print(f"ERROR_JSON:{error}")
    sys.exit(1)

job = next((item for item in jobs if item.get("job_id") == target_id), None)
if not job:
    print("JOB_NOT_FOUND")
    sys.exit(1)

fallo = False


def comprobar(condicion, ok, error):
    global fallo
    if condicion:
        print(f"  OK ({ok})")
    else:
        print(f"  FAIL ({error})")
        fallo = True


comprobar(
    isinstance(job.get("job_id"), int) and job.get("job_id") == target_id,
    f"job_id = {target_id} (numérico)",
    f"job_id = {job.get('job_id')}",
)
comprobar(
    job.get("programa") == "sleep",
    "programa = sleep (cadena)",
    f"programa = {job.get('programa')}",
)
argumentos = [str(valor) for valor in job.get("argumentos", [])]
comprobar(
    isinstance(job.get("argumentos"), list) and "10" in argumentos,
    "argumentos contiene 10",
    f"argumentos: {job.get('argumentos')}",
)
comprobar(
    job.get("status") == "QUEUED",
    "status = QUEUED (cadena)",
    f"status = {job.get('status')}",
)
comprobar(
    isinstance(job.get("pid"), int) and job.get("pid") == 0,
    "pid = 0 (numérico)",
    f"pid = {job.get('pid')}",
)
comprobar(
    isinstance(job.get("codigo_salida"), int) and job.get("codigo_salida") == -1,
    "codigo_salida = -1 (numérico)",
    f"codigo_salida = {job.get('codigo_salida')}",
)
comprobar(
    job.get("cancel_requested") is False,
    "cancel_requested = false (booleano)",
    f"cancel_requested = {job.get('cancel_requested')}",
)

sys.exit(1 if fallo else 0)
PYEOF
)"
    echo "$PYTHON_RES"
    echo "$PYTHON_RES" | grep -q "FAIL" && fallar "la estructura del Job en espera no es la esperada"
fi

# Paso 7: auditoría pospuesta (resolución de la cola)
echo "Paso 7 (esperando ${DURACION}+1 s a que el Job en espera se resuelva)..."
sleep $((DURACION + 1))

ESTADO_FINAL="$(python3 - "$DATA" "$QUEUED_ID" <<'PYEOF'
import json
import sys

data_file = sys.argv[1]
job_id = sys.argv[2]

jobs = json.load(open(data_file))
job = next((item for item in jobs if str(item.get("job_id")) == job_id), None)
print(job.get("status") if job else "NOT_FOUND")
PYEOF
)"

if [ "$ESTADO_FINAL" = "RUNNING" ] || [ "$ESTADO_FINAL" = "SUCCEEDED" ]; then
    echo "Paso 7 OK (el Job $QUEUED_ID pasó de QUEUED a $ESTADO_FINAL)"
else
    fallar "el Job $QUEUED_ID sigue en estado $ESTADO_FINAL (se esperaba RUNNING o SUCCEEDED)"
fi

if [ "$FALLOS" -eq 0 ]; then
    echo "[ PASS ] TC-002"
    exit 0
fi

echo "[ FAIL ] TC-002"
exit 1
