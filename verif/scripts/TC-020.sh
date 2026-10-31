#!/bin/bash
# TC-020: Terminación inesperada del proceso hijo (Robustez)
# RF-29, RNF-30
# Uso: bash verif/scripts/TC-020.sh
# Evidencia: verif/results/tc020.log

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc020.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "=== Ejecutando TC-020 ==="
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

# Paso 2: Inyectar fallo crítico (SIGSEGV)
# Usamos comillas simples para asegurar que $$ sea evaluado por el sub-bash del job y no por este script.
echo "[INFO] Encolando job suicida: bash -c 'kill -SEGV \$\$'"
OUT="$("${HERMES_BIN}" job bash -c 'kill -SEGV $$' 2>&1)"
echo "$OUT"

JOB_ID=$(echo "$OUT" | grep -oP 'job ID: \K[0-9]+')
JOB_PID=$(echo "$OUT" | grep -oP 'PID: \K[0-9]+')

if [ -z "$JOB_ID" ] || [ -z "$JOB_PID" ]; then
    echo "[FAIL] No se pudo extraer Job ID o PID."
    exit 1
fi

echo "[INFO] Job ID: $JOB_ID | PID: $JOB_PID"

# Esperar a que el proceso muera y el scheduler aplique waitpid
sleep 2

# Paso 3: Verificación visual en CLI (RF-29)
echo "[INFO] Verificando salida en CLI..."
CLI_OUT=$("${HERMES_BIN}" filter id "$JOB_ID" 2>&1)
echo "$CLI_OUT"

if echo "$CLI_OUT" | grep -q "Estado: FAILED" && echo "$CLI_OUT" | grep -q "Codigo de salida: -11" && echo "$CLI_OUT" | grep -q "SIGSEGV"; then
    echo "[OK] CLI muestra estado FAILED y diagnóstico SIGSEGV correcto."
else
    echo "[FAIL] La salida CLI no contiene el diagnóstico esperado."
    exit 1
fi

# Paso 4: Verificación estricta en jobs.json (RF-29)
echo "[INFO] Verificando persistencia en jobs.json..."
python3 - "$JOBS_FILE" "$JOB_ID" <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1], 'r') as f: data = json.load(f)
    job = next((j for j in data if str(j.get('job_id')) == sys.argv[2]), None)
    
    if not job:
        print("[FAIL] Job no encontrado en jobs.json")
        sys.exit(1)
    if job.get('status') != 'FAILED':
        print(f"[FAIL] Estado incorrecto: {job.get('status')}")
        sys.exit(1)
    if job.get('codigo_salida') != -11:
        print(f"[FAIL] Código de salida incorrecto: {job.get('codigo_salida')}")
        sys.exit(1)
    if 'SIGSEGV' not in job.get('mensaje_error', ''):
        print(f"[FAIL] Falta diagnóstico SIGSEGV en mensaje_error: {job.get('mensaje_error')}")
        sys.exit(1)
        
    print("[OK] jobs.json validado (estado FAILED, código -11 y mensaje_error presentes).")
except Exception as e:
    print(f"[FAIL] Error en Python: {e}")
    sys.exit(1)
PYEOF

if [ $? -ne 0 ]; then exit 1; fi

# Paso 5: Verificación forense en events.jsonl (RF-29)
echo "[INFO] Verificando auditoría forense en events.jsonl..."
python3 - "$EVENTS_FILE" "$JOB_ID" <<'PYEOF'
import json, sys
try:
    found = False
    with open(sys.argv[1], 'r') as f:
        for line in f:
            if not line.strip(): continue
            evt = json.loads(line)
            
            if str(evt.get('job_id')) == sys.argv[2] and evt.get('level') == 'ERROR':
                ctx = evt.get('context', {})
                if not ctx.get('anomalous_termination'):
                    print("[FAIL] anomalous_termination no es true")
                    sys.exit(1)
                if ctx.get('signal_number') != 11:
                    print(f"[FAIL] signal_number incorrecto: {ctx.get('signal_number')}")
                    sys.exit(1)
                if 'SIGSEGV' not in ctx.get('signal_name', ''):
                    print(f"[FAIL] signal_name incorrecto: {ctx.get('signal_name')}")
                    sys.exit(1)
                found = True
                break
    
    if not found:
        print("[FAIL] Evento ERROR no encontrado en events.jsonl")
        sys.exit(1)
        
    print("[OK] events.jsonl validado (diagnóstico forense registrado exitosamente).")
except Exception as e:
    print(f"[FAIL] Error leyendo events.jsonl: {e}")
    sys.exit(1)
PYEOF

if [ $? -ne 0 ]; then exit 1; fi

# Paso 6: Verificación de zombies y huérfanos a nivel SO (RNF-30)
echo "[INFO] Verificando liberación de recursos (procesos zombies/huérfanos)..."
if kill -0 "$JOB_PID" 2>/dev/null; then
    STAT=$(ps -o stat= -p "$JOB_PID" 2>/dev/null)
    if [[ "$STAT" == *"Z"* ]]; then
        echo "[FAIL] El proceso $JOB_PID quedó como ZOMBIE (<defunct>) en el sistema operativo."
        exit 1
    else
        echo "[FAIL] El proceso $JOB_PID sigue vivo misteriosamente."
        exit 1
    fi
else
    echo "[OK] El proceso $JOB_PID ya no existe en la tabla del S.O. (correctamente cosechado por waitpid)."
fi

echo "[PASS] TC-020"
exit 0