#!/bin/bash
# TC-006: Capturar stdout/stderr separados y código de salida (RF-11, RF-07)
# Uso: bash verif/scripts/TC-006.sh
# Evidencia: verif/results/tc006.log

echo "=== Ejecutando TC-006 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || exit 1

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc006.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

rm -f data/jobs.json

# Paso 1: Compilación
make clean && make > /dev/null
echo "Paso 1 OK (compilación limpia)"

# Paso 2: Caso stdout puro
./hermes job echo hola > /tmp/h_o.txt
O=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_o.txt)
sleep 2

ST_O=$(./hermes filter id "$O" 2>&1)
if echo "$ST_O" | grep -q "Estado: SUCCEEDED" && echo "$ST_O" | grep -q "Codigo de salida: 0" && echo "$ST_O" | grep -q "hola"; then
    echo "Paso 2 OK (echo hola -> SUCCEEDED, código 0 y texto visible en consulta)"
else
    echo "Paso 2 FAIL (Salida: $ST_O)"
    exit 1
fi

# Paso 3: Caso stderr puro
./hermes job ls /ruta_inexistente_xyz > /tmp/h_e.txt
E=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_e.txt)
sleep 2

ST_E=$(./hermes filter id "$E" 2>&1)
if echo "$ST_E" | grep -q "Estado: FAILED" && ! echo "$ST_E" | grep -q "Codigo de salida: 0"; then
    echo "Paso 3 OK (ls inexistente -> FAILED, código distinto de 0 y error capturado)"
else
    echo "Paso 3 FAIL (Salida: $ST_E)"
    exit 1
fi

# Paso 4: Caso mixto (stdout, stderr y código personalizado)
./hermes job sh -c 'echo salida-ok; echo fallo-ok >&2; exit 3' > /tmp/h_m.txt
M=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_m.txt)
sleep 2

ST_M=$(./hermes filter id "$M" 2>&1)
if echo "$ST_M" | grep -q "Estado: FAILED" && echo "$ST_M" | grep -q "Codigo de salida: 3" && echo "$ST_M" | grep -q "salida-ok" && echo "$ST_M" | grep -q "fallo-ok"; then
    echo "Paso 4 OK (Comando mixto -> FAILED, código 3 y ambos canales capturados)"
else
    echo "Paso 4 FAIL (Salida: $ST_M)"
    exit 1
fi

# Paso 5: Persistencia en JSON
if grep -q '"codigo_salida": 0' data/jobs.json && grep -q '"codigo_salida": 3' data/jobs.json; then
    echo "Paso 5 OK (Códigos de salida persistidos correctamente en jobs.json)"
else
    echo "Paso 5 FAIL (No se detectaron los códigos en el JSON)"
    exit 1
fi

# Veredicto final
echo "[PASS] TC-006"
exit 0