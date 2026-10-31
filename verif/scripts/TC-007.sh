#!/bin/bash
# TC-007: Reinicio y recuperación (Robustez)
# RF-12, RF-13, RNF-10, RNF-11
# Uso: bash verif/scripts/TC-007.sh
# Evidencia: verif/results/tc007.log

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc007.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "=== Ejecutando TC-007 ==="
echo "[INFO] Fecha/Hora: $(date)"
echo "[INFO] Directorio raíz: ${REPO}"

cd "$REPO/src/hermes" || exit 1

# Aislamiento: HOME temporal por prueba para proteger datos reales
TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"
DATA_DIR="${HOME}/.local/share/hermes/data"
mkdir -p "${DATA_DIR}"
JOBS_FILE="${DATA_DIR}/jobs.json"
EVENTS_FILE="${DATA_DIR}/events.jsonl"
LOCK_FILE="${DATA_DIR}/scheduler.lock"

cleanup() {
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

# Paso 1: Compilar
echo "[INFO] Compilando proyecto..."
make clean && make > /dev/null
echo "[INFO] Compilación limpia OK."

HERMES_BIN="./hermes"
if [ ! -x "${HERMES_BIN}" ]; then
    echo "[FAIL] No se encontró binario ejecutable 'hermes'."
    exit 1
fi

# Paso 2: Encolar trabajo de larga duración
echo "[INFO] Encolando job de larga duración: sleep 60"
OUT="$("${HERMES_BIN}" job sleep 60 2>&1)"
echo "$OUT"

JOB_ID=$(echo "$OUT" | grep -oP 'job ID: \K[0-9]+')
if [ -z "$JOB_ID" ]; then
    echo "[FAIL] No se pudo extraer Job ID."
    exit 1
fi

# Esperamos a que el proceso y el scheduler se establezcan (Fase RUNNING)
sleep 2

# Extraer el PID del demonio supervisor desde scheduler.lock
if [ ! -f "$LOCK_FILE" ]; then
    echo "[FAIL] No se generó scheduler.lock, daemon no inició correctamente."
    exit 1
fi

SCHEDULER_PID=$(cat "$LOCK_FILE" | tr -d -c '0-9')

if [ -z "$SCHEDULER_PID" ]; then
    echo "[FAIL] No se pudo obtener el PID del scheduler."
    exit 1
fi

echo "[INFO] Scheduler PID obtenido: $SCHEDULER_PID"

# Verificamos estado previo a la caída
PRE_STATUS=$("${HERMES_BIN}" filter id "$JOB_ID" 2>&1)
if echo "$PRE_STATUS" | grep -q "Estado: RUNNING"; then
    echo "[INFO] Verificado: El Job $JOB_ID está RUNNING."
else
    echo "[FAIL] El Job no está en estado RUNNING antes de la caída."
    echo "$PRE_STATUS"
    exit 1
fi

# Paso 3: Simular caída abrupta del scheduler (RF-13, RNF-10)
echo "[INFO] Inyectando SIGKILL (caída abrupta) al scheduler PID: $SCHEDULER_PID"
kill -9 "$SCHEDULER_PID" 2>/dev/null || true

# Esperar para simular tiempo de inactividad
sleep 3

# Paso 4: Forzar el módulo de recuperación (RF-12, RF-13)
# Al ejecutar cualquier comando (ej. listar RUNNING), Hermes intentará adquirir el lock y disparará
# hermes::recuperarTrabajosInterrumpidos() antes de arrancar.
echo "[INFO] Forzando rutina de recuperación consultando procesos RUNNING..."
RUNNING_JOBS=$("${HERMES_BIN}" filter status RUNNING 2>&1)
echo "$RUNNING_JOBS"

if echo "$RUNNING_JOBS" | grep -qi -E "no se encontraron|0 trabajos"; then
    echo "[OK] (RNF-10) Ningún proceso huérfano es reportado como RUNNING."
elif [ -z "$RUNNING_JOBS" ]; then
    echo "[OK] (RNF-10) Ningún proceso huérfano es reportado como RUNNING (salida vacía)."
else
    echo "[FAIL] (RNF-10) El sistema sigue reportando procesos RUNNING falsos."
    exit 1
fi

# Paso 5: Consultar el estado final reconciliado en el historial (RF-12)
echo "[INFO] Consultando estado final en historial persistido..."
POST_STATUS=$("${HERMES_BIN}" filter id "$JOB_ID" 2>&1)
echo "$POST_STATUS"

if echo "$POST_STATUS" | grep -q "Estado: INTERRUPTED" && echo "$POST_STATUS" | grep -q "Codigo de salida: -1" && echo "$POST_STATUS" | grep -q "reinicio o caída"; then
    echo "[OK] (RF-12/RF-13) El historial conservó los metadatos y transicionó coherentemente a INTERRUPTED."
else
    echo "[FAIL] (RF-12) El historial no refleja el estado INTERRUPTED esperado o falta el motivo."
    exit 1
fi

# Paso 6: Verificación de persistencia y estructura JSON estricta (RNF-11)
echo "[INFO] Validando atomicidad y estructura estricta en jobs.json (RNF-11)..."
python3 - "$JOBS_FILE" "$JOB_ID" <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1], 'r') as f:
        data = json.load(f)
    
    # Validamos que siga siendo un JSON array
    if not isinstance(data, list):
        print("[FAIL] jobs.json se corrompió y dejó de ser un array válido.")
        sys.exit(1)
        
    job = next((j for j in data if str(j.get('job_id')) == sys.argv[2]), None)
    
    if not job:
        print("[FAIL] Job no encontrado en jobs.json")
        sys.exit(1)
        
    if job.get('status') != 'INTERRUPTED':
        print(f"[FAIL] Estado JSON no es INTERRUPTED: {job.get('status')}")
        sys.exit(1)
        
    if job.get('codigo_salida') != -1:
        print(f"[FAIL] Código de salida JSON no es -1: {job.get('codigo_salida')}")
        sys.exit(1)
        
    # Verificar que las banderas forenses de RF-13 están presentes
    if not job.get('motivo'):
        print("[FAIL] Falta el campo forense 'motivo' en el JSON.")
        sys.exit(1)
        
    print("[OK] (RNF-11) jobs.json mantiene estructura válida, sin corrupciones y atómicamente escrito.")
except Exception as e:
    print(f"[FAIL] Estructura JSON corrupta tras caída: {e}")
    sys.exit(1)
PYEOF

if [ $? -ne 0 ]; then exit 1; fi

echo "[PASS] TC-007"
exit 0