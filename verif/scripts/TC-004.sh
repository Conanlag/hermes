#!/bin/bash
# TC-004: Consultar y listar (RF-08, RF-09)
# Uso (WSL): bash verif/scripts/TC-004.sh   (desde la raíz del repo)
# Evidencia: verif/results/tc004.log
# Requiere: Linux/WSL con g++, make y python3.

echo "=== Ejecutando TC-004 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || { echo "[FAIL] TC-004 (no se pudo entrar a src/hermes)"; exit 1; }

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc004.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

FALLOS=0

# Paso 1: compilación limpia
make clean && make
if [ $? -ne 0 ]; then
    echo "[FAIL] TC-004 (compilación)"
    exit 1
fi
echo "Compilación OK"

# Respaldo persistente
if [ -f data/jobs.json ]; then
    cp data/jobs.json "$REPO/verif/results/jobs_tc004_backup.json"
fi

# Precondición: representantes por estado
S=$(./hermes job true 2>&1 | grep -oP 'job ID: \K[0-9]+')
F=$(./hermes job false 2>&1 | grep -oP 'job ID: \K[0-9]+')
C=$(./hermes job sleep 30 2>&1 | grep -oP 'job ID: \K[0-9]+')
sleep 1
./hermes cancel "$C" > /dev/null 2>&1
sleep 2
echo "Representantes: S=$S F=$F C=$C"

# Paso 2: consulta puntual válida
CONS=$(./hermes filter id "$S" 2>&1)
if [ $? -eq 0 ] && echo "$CONS" | grep -q "Job ID:" && echo "$CONS" | grep -q "Recepcion:" && echo "$CONS" | grep -q "Codigo de salida:"; then
    echo "Paso 2 OK (metadatos + tiempos)"
else
    echo "Paso 2 FAIL"
    FALLOS=1
fi

# Paso 3: inexistente
SALIDA=$(./hermes filter id 999999 2>&1)
if [ $? -eq 1 ] && echo "$SALIDA" | grep -qi "no se encontr"; then
    echo "Paso 3 OK (inexistente, código 1)"
else
    echo "Paso 3 FAIL"
    FALLOS=1
fi

# Paso 4: listado por estado (cada bloque solo su estado)
for EST in SUCCEEDED FAILED CANCELED; do
    BLOQ=$(./hermes filter status "$EST" 2>&1)
    MAL=$(echo "$BLOQ" | grep -oP 'Estado: "?\K[A-Z]+' | grep -v "^${EST}$" || true)
    if [ -z "$MAL" ] && echo "$BLOQ" | grep -q "Job ID:"; then
        echo "Paso 4 OK (status $EST homogéneo)"
    else
        echo "Paso 4 FAIL (status $EST: $MAL)"
        FALLOS=1
    fi
done

# Paso 5: listado por programa
BLOQ=$(./hermes filter programa sleep 2>&1)
MAL=$(echo "$BLOQ" | grep -oP 'Programa: "?\K[a-z_]+' | grep -v "^sleep$" || true)
if [ -z "$MAL" ] && echo "$BLOQ" | grep -q "Job ID:"; then
    echo "Paso 5 OK (programa sleep homogéneo)"
else
    echo "Paso 5 FAIL"
    FALLOS=1
fi

# Paso 6: filtro sin resultados
SALIDA=$(./hermes filter programa nombre_inexistente_xyz 2>&1)
if [ $? -eq 1 ] && echo "$SALIDA" | grep -qi "no se encontraron"; then
    echo "Paso 6 OK (sin resultados, código 1)"
else
    echo "Paso 6 FAIL"
    FALLOS=1
fi

# Restaurar respaldo
if [ -f "$REPO/verif/results/jobs_tc004_backup.json" ]; then
    cp "$REPO/verif/results/jobs_tc004_backup.json" data/jobs.json
fi

if [ $FALLOS -eq 0 ]; then
    echo "[PASS] TC-004"
    exit 0
else
    echo "[FAIL] TC-004"
    exit 1
fi
