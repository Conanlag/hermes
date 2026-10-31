#!/bin/bash
# TC-017: Cancelaciones concurrentes (Robustez)
# RF-26, RNF-27
# Uso: bash verif/scripts/TC-017.sh
# Evidencia: verif/results/tc017.log

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc017.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "=== Ejecutando TC-017 ==="
echo "[INFO] Fecha/Hora: $(date)"
echo "[INFO] Directorio raíz: ${REPO}"

cd "$REPO/src/hermes" || exit 1

# Aislamiento: HOME temporal por prueba (idéntico a TC-004)
TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"
DATA_DIR="${HOME}/.local/share/hermes/data"
mkdir -p "${DATA_DIR}"
JOBS_FILE="${DATA_DIR}/jobs.json"
echo "[]" > "${JOBS_FILE}"
echo "[INFO] jobs.json inicializado en entorno aislado."

cleanup() {
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

# Paso 1: Compilar
make clean && make > /dev/null
echo "[INFO] Compilación limpia OK."

HERMES_BIN="./hermes"
if [ ! -x "${HERMES_BIN}" ]; then
    echo "[FAIL] No se encontró binario ejecutable 'hermes'."
    exit 1
fi

# Encolar job de larga duración
echo "[INFO] Encolando job de larga duración: sleep 60"
"${HERMES_BIN}" job sleep 60 > /tmp/send_job.log 2>&1
cat /tmp/send_job.log

sleep 2

# Obtener Job ID de forma robusta
JOB_ID="$(python3 - "$JOBS_FILE" <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1], 'r') as f:
        data = json.load(f)
    if isinstance(data, list) and data:
        print(data[-1].get('job_id', ''))
    else:
        print('')
except Exception:
    print('')
PYEOF
)"

if [ -z "${JOB_ID}" ]; then
    echo "[FAIL] No se pudo obtener Job ID."
    exit 1
fi

echo "[INFO] Job ID obtenido: ${JOB_ID}"
sleep 1

echo "[INFO] Estado previo a cancelaciones concurrentes:"
"${HERMES_BIN}" filter id "${JOB_ID}" 2>&1 || true

# 5 cancelaciones concurrentes
echo "[INFO] Lanzando 5 CANCELACIONES CONCURRENTES sobre Job ${JOB_ID}..."
for i in {1..5}; do
    "${HERMES_BIN}" cancel "${JOB_ID}" > "$REPO/verif/results/cancel_client_${i}.log" 2>&1 &
    PIDS[$i]=$!
done

echo "[INFO] Esperando finalización de todas las cancelaciones..."
for pid in "${PIDS[@]}"; do
    wait "$pid"
done
echo "[INFO] Todas las cancelaciones finalizadas."
sleep 3

# Validar respuestas de los clientes
echo "[INFO] Validando respuestas de los clientes..."
for i in {1..5}; do
    if grep -q -E "(Cancelación solicitada|ya ha sido cancelado|ya se encuentra|no encontrado|estado: CANCELED)" "$REPO/verif/results/cancel_client_${i}.log"; then
        echo "  - Cliente $i: Respuesta coherente recibida."
    else
        echo "[FAIL] El Cliente $i no recibió una respuesta coherente."
        cat "$REPO/verif/results/cancel_client_${i}.log"
        exit 1
    fi
done

echo "[INFO] Consultando estado final:"
"${HERMES_BIN}" filter id "${JOB_ID}" 2>&1

# Validación JSON final
echo "[INFO] Validando integridad y coherencia..."
python3 - "$JOBS_FILE" "$JOB_ID" <<'PYEOF'
import json, sys

jobs_path = sys.argv[1]
job_id = sys.argv[2]

try:
    with open(jobs_path, 'r') as f:
        data = json.load(f)
    print("[VALID] jobs.json es JSON válido")
except Exception as e:
    print(f"[FAIL] jobs.json NO es JSON válido: {e}")
    sys.exit(1)

target = None
for j in data:
    if str(j.get('job_id')) == str(job_id):
        target = j
        break

if target is None:
    print(f"[FAIL] No se encontró el Job con ID {job_id}")
    sys.exit(1)

status = target.get('status')
cancel_req = target.get('cancel_requested')

if status == 'CANCELED':
    if cancel_req is True:
        print("[OK] cancel_requested=True")
    print("[PASS-VALIDATION] Coherencia, serialización e integridad OK")
    sys.exit(0)
else:
    print(f"[FAIL] Estado inválido: {status}")
    sys.exit(1)
PYEOF

VAL_RC=$?
if [ ${VAL_RC} -ne 0 ]; then
    echo "[FAIL] TC-017 - Validación fallida (código ${VAL_RC})"
    exit 1
fi

echo "[PASS] TC-017"
exit 0