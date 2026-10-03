#!/bin/bash
# TC-001: Enviar trabajo válido (RF-01, RF-02)
# Uso (WSL): bash verif/scripts/TC-001.sh   (desde la raíz del repo)
# Evidencia: verif/results/tc001.log
# Requiere: Linux/WSL con g++ y make.

echo "=== Ejecutando TC-001 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || { echo "[FAIL] TC-001 (no se pudo entrar a src/hermes)"; exit 1; }

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc001.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

FALLOS=0

# Paso 1: compilación limpia
make clean && make
if [ $? -ne 0 ]; then
    echo "[FAIL] TC-001 (compilación)"
    exit 1
fi
echo "Compilación OK"

# Respaldo persistente de jobs.json
if [ -f data/jobs.json ]; then
    cp data/jobs.json "$REPO/verif/results/jobs_tc001_backup.json"
fi

# Paso 2: trabajo válido
OUT=$(./hermes job echo hola 2>&1)
RC=$?
N=$(echo "$OUT" | grep -oP 'job ID: \K[0-9]+')
if [ $RC -eq 0 ] && [ -n "$N" ]; then
    echo "Paso 2 OK (job ID: $N)"
else
    echo "Paso 2 FAIL (salida: $OUT, código: $RC)"
    FALLOS=1
fi

# Paso 3: persistencia
FILTRO=$(./hermes filter id "$N" 2>&1)
if echo "$FILTRO" | grep -q "Programa:" && echo "$FILTRO" | grep -q "hola"; then
    echo "Paso 3 OK (persistido con metadatos)"
else
    echo "Paso 3 FAIL"
    FALLOS=1
fi

# Paso 4: unicidad
OUT2=$(./hermes job echo hola 2>&1)
N2=$(echo "$OUT2" | grep -oP 'job ID: \K[0-9]+')
if [ -n "$N2" ] && [ "$N2" -gt "$N" ]; then
    echo "Paso 4 OK (ID $N2 > $N)"
else
    echo "Paso 4 FAIL (IDs: $N, $N2)"
    FALLOS=1
fi

# Paso 5: entrada vacía
SALIDA=$(./hermes job "" 2>&1)
if [ $? -eq 1 ] && echo "$SALIDA" | grep -qi "vacio\|uso"; then
    echo "Paso 5 OK (vacía rechazada, código 1)"
else
    echo "Paso 5 FAIL"
    FALLOS=1
fi

# Paso 6: mal formada
SALIDA=$(./hermes filter id abc 2>&1)
if [ $? -eq 1 ] && echo "$SALIDA" | grep -qi "mal formado"; then
    echo "Paso 6 OK (mal formada rechazada, código 1)"
else
    echo "Paso 6 FAIL"
    FALLOS=1
fi

# Paso 7: no autorizada
SALIDA=$(./hermes foo 2>&1)
if [ $? -eq 1 ] && echo "$SALIDA" | grep -qi "no reconocido"; then
    echo "Paso 7 OK (no autorizada rechazada, código 1)"
else
    echo "Paso 7 FAIL"
    FALLOS=1
fi

# Restaurar respaldo
if [ -f "$REPO/verif/results/jobs_tc001_backup.json" ]; then
    cp "$REPO/verif/results/jobs_tc001_backup.json" data/jobs.json
fi

if [ $FALLOS -eq 0 ]; then
    echo "[PASS] TC-001"
    exit 0
else
    echo "[FAIL] TC-001"
    exit 1
fi
