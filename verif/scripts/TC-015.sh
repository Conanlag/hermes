#!/bin/bash
# TC-015: Usabilidad documental local (RF-17, RNF-21, RNF-23)
# Uso (WSL): bash verif/scripts/TC-015.sh   (desde la raíz del repo)
# Evidencia: verif/results/tc015.log
# Requiere: Linux/WSL con g++ y make.

echo "=== Ejecutando TC-015 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || { echo "[FAIL] TC-015 (no se pudo entrar a src/hermes)"; exit 1; }

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc015.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

FALLOS=0

# Paso 1: compilación limpia
make clean && make
if [ $? -ne 0 ]; then
    echo "[FAIL] TC-015 (compilación)"
    exit 1
fi
echo "Compilación OK"

# Respaldo persistente
if [ -f data/jobs.json ]; then
    cp data/jobs.json "$REPO/verif/results/jobs_tc015_backup.json"
fi

# Paso 1 (TC): ayuda en stdout con código 0
AYUDA=$(./hermes --help 2>/dev/null)
RC=$?
if [ $RC -eq 0 ] && echo "$AYUDA" | grep -qi "uso" && echo "$AYUDA" | grep -q "job" && echo "$AYUDA" | grep -q "filter" && echo "$AYUDA" | grep -qi "cancel"; then
    echo "Paso 1 OK (--help completo, código 0)"
else
    echo "Paso 1 FAIL"
    FALLOS=1
fi
./hermes --version > /dev/null 2>&1
[ $? -eq 0 ] && echo "Paso 1 OK (--version, código 0)" || { echo "Paso 1 FAIL (--version)"; FALLOS=1; }

# Paso 2: códigos de salida
./hermes job echo hola > /dev/null 2>&1
C_OK=$?
./hermes foo > /dev/null 2>&1
C_ERR=$?
if [ $C_OK -eq 0 ] && [ $C_ERR -eq 1 ]; then
    echo "Paso 2 OK (0 en éxito, 1 en error)"
else
    echo "Paso 2 FAIL ($C_OK/$C_ERR)"
    FALLOS=1
fi

# Paso 3: mensaje con operación + causa + acción
SALIDA=$(./hermes filter id abc 2>&1)
if [ $? -eq 1 ] && echo "$SALIDA" | grep -qi "filter" && echo "$SALIDA" | grep -qi "mal formado" && echo "$SALIDA" | grep -qi "numero"; then
    echo "Paso 3 OK (operación + causa + acción)"
else
    echo "Paso 3 FAIL"
    FALLOS=1
fi

# Paso 4: inexistente con causa
SALIDA=$(./hermes cancel 999999 2>&1)
if [ $? -eq 1 ] && echo "$SALIDA" | grep -qi "no existe"; then
    echo "Paso 4 OK (inexistente con causa, código 1)"
else
    echo "Paso 4 FAIL"
    FALLOS=1
fi

# Paso 5: flujo guiado solo con la guía (instalar → enviar → consultar)
if make install > /dev/null 2>&1; then
    echo "Paso 5 OK (make install)"
else
    echo "Paso 5 FAIL (make install)"
    FALLOS=1
fi
export PATH="$HOME/.local/bin:$PATH"
GID=$(hermes job echo guia 2>&1 | grep -oP 'job ID: \K[0-9]+')
if [ -n "$GID" ] && hermes filter id "$GID" 2>&1 | grep -q "Job ID:"; then
    echo "Paso 5 OK (enviar + consultar vía guía, job $GID)"
else
    echo "Paso 5 FAIL (flujo guiado)"
    FALLOS=1
fi

# Restaurar respaldo
if [ -f "$REPO/verif/results/jobs_tc015_backup.json" ]; then
    cp "$REPO/verif/results/jobs_tc015_backup.json" data/jobs.json
fi

if [ $FALLOS -eq 0 ]; then
    echo "[PASS] TC-015"
    exit 0
else
    echo "[FAIL] TC-015"
    exit 1
fi
