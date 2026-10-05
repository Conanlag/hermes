#!/bin/bash
# TC-004: Consultar y listar (RF-08, RF-09)
# Uso: bash verif/scripts/TC-004.sh
# Evidencia: verif/results/tc004.log

echo "=== Ejecutando TC-004 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || exit 1

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc004.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

rm -f data/jobs.json

# Paso 1: Compilar
make clean && make > /dev/null
echo "Paso 1 OK (compilación limpia)"

# Crear datos de prueba usando redirección para evitar SIGPIPE
./hermes job true > /tmp/h_a.txt
A=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_a.txt)
sleep 1
./hermes job false > /tmp/h_b.txt
B=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_b.txt)
sleep 1
./hermes job sleep 30 > /tmp/h_c.txt
C=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_c.txt)
sleep 1
./hermes cancel "$C" > /dev/null
sleep 1

# Paso 2: Consulta puntual válida
SALIDA_ID=$(./hermes filter id "$A")
if echo "$SALIDA_ID" | grep -q "Job ID: $A" && echo "$SALIDA_ID" | grep -q "Estado: SUCCEEDED"; then
    echo "Paso 2 OK (Consulta puntual correcta para ID $A)"
else
    echo "Paso 2 FAIL"
    exit 1
fi

# Paso 3: Consulta inexistente (Solo evaluamos el texto impreso)
SALIDA_INEX=$(./hermes filter id 999999 2>&1)
if echo "$SALIDA_INEX" | grep -q "No se encontró el Job ID"; then
    echo "Paso 3 OK (Rechazo correcto de ID inexistente)"
else
    echo "Paso 3 FAIL (Salida: $SALIDA_INEX)"
    exit 1
fi

# Paso 4: Listado por estado
LISTA_SUCC=$(./hermes filter status SUCCEEDED)
LISTA_FAIL=$(./hermes filter status FAILED)
LISTA_CANC=$(./hermes filter status CANCELED)

if echo "$LISTA_SUCC" | grep -q "SUCCEEDED" && echo "$LISTA_FAIL" | grep -q "FAILED" && echo "$LISTA_CANC" | grep -q "CANCELED"; then
    echo "Paso 4 OK (Filtros por estado devuelven los bloques correctos)"
else
    echo "Paso 4 FAIL"
    exit 1
fi

# Paso 5: Listado por programa
LISTA_PROG=$(./hermes filter programa sleep)
if echo "$LISTA_PROG" | grep -q "Programa: \"sleep\""; then
    echo "Paso 5 OK (Filtro por programa devuelve los bloques correctos)"
else
    echo "Paso 5 FAIL"
    exit 1
fi

# Paso 6: Filtro sin resultados (Estricto)
SALIDA_VACIA=$(./hermes filter programa inventado 2>&1)
if echo "$SALIDA_VACIA" | grep -qi "no se encontraron"; then
    echo "Paso 6 OK (Filtro sin resultados manejado correctamente)"
else
    echo "Paso 6 FAIL (Salida real: '$SALIDA_VACIA')"
    exit 1
fi

# Veredicto final
echo "[PASS] TC-004"
exit 0