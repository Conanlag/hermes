#!/bin/bash
# TC-016: Saturación de cola y rechazo explícito (Robustez)
# RF-25, RNF-29
# Uso: bash verif/scripts/TC-016.sh
# Evidencia: verif/results/tc016.log

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc016.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "=== Ejecutando TC-016 ==="
echo "[INFO] Fecha/Hora: $(date)"
echo "[INFO] Directorio raíz: ${REPO}"

cd "$REPO/src/hermes" || exit 1

# Aislamiento: HOME temporal por prueba para proteger datos reales
TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"
DATA_DIR="${HOME}/.local/share/hermes/data"
mkdir -p "${DATA_DIR}"
JOBS_FILE="${DATA_DIR}/jobs.json"
CONFIG_FILE="${DATA_DIR}/config.json"

cleanup() {
    # Matamos todos los sleep y al scheduler si quedaron vivos en el entorno temporal
    pkill -f "sleep 60" 2>/dev/null || true
    pkill -f "hermes.*scheduler" 2>/dev/null || true
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

# Paso 1: Configurar el entorno (Límite de cola = 5)
echo "[INFO] Configurando capacidad de la cola en config.json (Límite: 5)..."
cat <<EOF > "$CONFIG_FILE"
{
  "trabajos_maximos": 5
}
EOF

# Paso 2: Compilar
echo "[INFO] Compilando proyecto..."
make clean && make > /dev/null
echo "[INFO] Compilación limpia OK."

HERMES_BIN="./hermes"
if [ ! -x "${HERMES_BIN}" ]; then
    echo "[FAIL] No se encontró binario ejecutable 'hermes'."
    exit 1
fi

# Paso 3: Saturar la cola con 5 trabajos de larga duración
echo "[INFO] Encolando 5 trabajos consecutivos para saturar la capacidad..."
for i in {1..5}; do
    OUT="$("${HERMES_BIN}" job sleep 60 2>&1)"
    if echo "$OUT" | grep -q "job ID:"; then
        echo "  - Trabajo $i encolado exitosamente."
    else
        echo "[FAIL] Error prematuro al encolar el trabajo $i."
        echo "Salida: $OUT"
        exit 1
    fi
done

# Damos un instante para que el scheduler asiente los trabajos
sleep 1

# Paso 4: Inyectar sobrecarga (Sexto trabajo)
echo "[INFO] Intentando encolar el sexto trabajo (Debe ser rechazado)..."
OVERLOAD_OUT=$("${HERMES_BIN}" job echo "Soy el sexto" 2>&1)
OVERLOAD_RC=$?

echo "[INFO] Código de salida de la sexta petición: $OVERLOAD_RC"
echo "[INFO] Salida en CLI de la sexta petición:"
echo "$OVERLOAD_OUT"

# Validación CLI (RF-25, RNF-29)
if [ $OVERLOAD_RC -eq 0 ]; then
    echo "[FAIL] La sexta petición devolvió un código de éxito (0). Se esperaba un error."
    exit 1
fi

if echo "$OVERLOAD_OUT" | grep -qi -E "límite|rechazad|llena|capacidad|excedid"; then
    echo "[OK] El sistema rechazó la petición con un mensaje coherente en CLI."
else
    echo "[FAIL] La sexta petición falló, pero no mostró un mensaje de rechazo explícito."
    exit 1
fi

# Paso 5: Verificación de estabilidad y estado intacto (RNF-29)
echo "[INFO] Verificando estabilidad del sistema tras el desbordamiento..."
STABILITY_CHECK=$("${HERMES_BIN}" filter status RUNNING 2>&1)
if echo "$STABILITY_CHECK" | grep -q "Job ID: 5"; then
    echo "[OK] Los primeros 5 trabajos siguen bajo supervisión y el sistema no colapsó."
else
    echo "[FAIL] El sistema perdió el control de los trabajos tras el rechazo."
    exit 1
fi

# Paso 6: Conteo matemático estricto en JSON (RNF-29)
echo "[INFO] Validando matemáticamente el límite de la cola en jobs.json..."
python3 - "$JOBS_FILE" <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1], 'r') as f:
        data = json.load(f)
    
    total_trabajos = len(data)
    print(f"[INFO] Trabajos registrados en jobs.json: {total_trabajos}")
    
    if total_trabajos != 5:
        print(f"[FAIL] El archivo jobs.json contiene {total_trabajos} trabajos en lugar de los 5 permitidos.")
        sys.exit(1)
        
    print("[OK] (RNF-29) Límite de persistencia respetado matemáticamente. El sexto trabajo jamás se registró.")
except Exception as e:
    print(f"[FAIL] Error leyendo jobs.json: {e}")
    sys.exit(1)
PYEOF

if [ $? -ne 0 ]; then exit 1; fi

echo "[PASS] TC-016"
exit 0