#!/bin/bash
# TC-002: Validar estructura de cola inicial (RF-03)
# Uso (WSL): bash verif/scripts/TC-002.sh   (desde la raíz del repo)
# Evidencia: verif/results/tc002.log

echo "=== Ejecutando TC-002 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || { echo "[FAIL] TC-002 (no se pudo entrar a src/hermes)"; exit 1; }

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

# Configurar límite amplio
mkdir -p "$DATA_DIR"
cat <<EOF > "$CONFIG_FILE"
{
  "trabajos_maximos": 10
}
EOF

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
        for _ in $(seq 1 20); do
            kill -0 "$scheduler_pid" 2>/dev/null || break
            sleep 0.1
        done
    fi
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

FALLOS=0

# Paso 1: Compilar
make clean && make
if [ $? -ne 0 ]; then
    echo "[FAIL] TC-002 (compilación)"
    exit 1
fi
echo "Paso 1 OK (compilación limpia)"

# Paso 2: Ocupar los 5 workers con trabajos de larga duración
for _ in $(seq 1 5); do
    ./hermes job sleep 120 > /dev/null
done

# Esperar activamente a que los 5 estén en RUNNING
RUNNING=0
for _ in $(seq 1 50); do
    RUNNING=$(python3 -c "
import json
try:
    with open('$DATA') as f:
        data = json.load(f)
        print(sum(1 for j in data if j.get('status') == 'RUNNING'))
except:
    print(0)
")
    [ "${RUNNING:-0}" -ge 5 ] && break
    sleep 0.1
done

if [ "${RUNNING:-0}" -ge 5 ]; then
    echo "Precondición OK (5 trabajadores ocupados en RUNNING)"
else
    echo "Precondición FAIL (solo ${RUNNING:-0} de 5 en RUNNING)"
    exit 1
fi

# Anotar último job_id M
M=$(python3 -c "
import json
try:
    with open('$DATA') as f:
        data = json.load(f)
        print(max(j.get('job_id', 0) for j in data) if data else 0)
except:
    print(0)
")
[ -z "$M" ] && M=0
echo "Paso 2 OK (último job_id M=$M)"

# APAGAR EL SCHEDULER: Detenemos el demonio para evitar que tome el siguiente trabajo 
# y lo pase a RUNNING antes de que podamos auditar su estado QUEUED inicial.
SCHEDULER_PID="$(find_scheduler_pid)"
if [[ -n "$SCHEDULER_PID" ]]; then
    kill -9 "$SCHEDULER_PID" 2>/dev/null || true
    sleep 0.3
fi

# Paso 3: Crear el sexto trabajo con el scheduler inactivo.
# Como el scheduler está apagado, el job se quedará guardado estáticamente en jobs.json como QUEUED.
OUT=$(./hermes job sleep 30 2>&1)
RC=$?
N=$(echo "$OUT" | grep -oP 'job ID: \K[0-9]+')
if [ $RC -eq 0 ] && [ -n "$N" ]; then
    echo "Paso 3 OK (job ID: $N, código 0)"
else
    echo "Paso 3 FAIL (salida: $OUT, código: $RC)"
    FALLOS=1
fi

# Paso 4: Unicidad y orden N = M + 1
if [ -n "$N" ] && [ "$N" -eq $((M + 1)) ]; then
    echo "Paso 4 OK (N=$N = M+1)"
else
    echo "Paso 4 FAIL (M=$M, N=$N)"
    FALLOS=1
fi

# Paso 5 y 6: Validación estricta con Python del estado QUEUED y pid 0
echo "Paso 5 (entrada $N campo por campo):"
PYTHON_RES=$(python3 - "$DATA" "$N" <<'PYEOF'
import json, sys
data_file = sys.argv[1]
target_id = int(sys.argv[2])

try:
    with open(data_file, 'r') as f:
        jobs = json.load(f)
except Exception as e:
    print(f"ERROR_JSON:{e}")
    sys.exit(1)

job = next((j for j in jobs if j.get('job_id') == target_id), None)
if not job:
    print("JOB_NOT_FOUND")
    sys.exit(1)

fail = False

# job_id
if job.get('job_id') == target_id and isinstance(job.get('job_id'), int):
    print(f"  OK (job_id = {target_id} (numérico))")
else:
    print(f"  FAIL (job_id = {job.get('job_id')})")
    fail = True

# programa
if job.get('programa') == "sleep" and isinstance(job.get('programa'), str):
    print("  OK (programa = sleep (cadena))")
else:
    print(f"  FAIL (programa = {job.get('programa')})")
    fail = True

# argumentos
args = job.get('argumentos', [])
if isinstance(args, list) and "30" in [str(x) for x in args]:
    print("  OK (argumentos contiene 30)")
else:
    print(f"  FAIL (argumentos: {args})")
    fail = True

# status
if job.get('status') == "QUEUED" and isinstance(job.get('status'), str):
    print("  OK (status = QUEUED (cadena))")
else:
    print(f"  FAIL (status = {job.get('status')})")
    fail = True

# pid
if job.get('pid') == 0 and isinstance(job.get('pid'), int):
    print("  OK (pid = 0 (numérico))")
else:
    print(f"  FAIL (pid = {job.get('pid')})")
    fail = True

# codigo_salida
if job.get('codigo_salida') == -1 and isinstance(job.get('codigo_salida'), int):
    print("  OK (codigo_salida = -1 (numérico))")
else:
    print(f"  FAIL (codigo_salida = {job.get('codigo_salida')})")
    fail = True

# cancel_requested
if job.get('cancel_requested') is False:
    print("  OK (cancel_requested = false (booleano))")
else:
    print(f"  FAIL (cancel_requested = {job.get('cancel_requested')})")
    fail = True

sys.exit(1 if fail else 0)
PYEOF
)

echo "$PYTHON_RES"
if echo "$PYTHON_RES" | grep -q "FAIL"; then
    FALLOS=1
fi

echo "Paso 6 OK (los patrones exigen tipos: números sin comillas, cadenas con comillas, booleano literal)"

if [ $FALLOS -eq 0 ]; then
    echo "[PASS] TC-002"
    exit 0
else
    echo "[FAIL] TC-002"
    exit 1
fi