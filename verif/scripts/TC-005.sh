#!/bin/bash
# TC-005: Solicitar cancelación de proceso en ejecución (RF-10)
# Uso: bash verif/scripts/TC-005.sh
# Evidencia: verif/results/tc005.log

echo "=== Ejecutando TC-005 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || exit 1

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc005.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

# Limpieza inicial
rm -f data/jobs.json

# Paso 1: Compilación
make clean && make > /dev/null
echo "Paso 1 OK (compilación limpia)"

# Paso 2: Crear objetivo (R) y testigo (T) usando redirección segura
./hermes job sleep 30 > /tmp/h_r.txt
R=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_r.txt)

./hermes job echo testigo > /tmp/h_t.txt
T=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_t.txt)

# Paso 3: Confirmar ejecución (El objetivo debe estar RUNNING)
sleep 1
ST_R=$(./hermes filter id "$R" | grep 'Estado:' | awk '{print $2}')
if [ "$ST_R" = "RUNNING" ]; then
    echo "Paso 3 OK (Objetivo $R confirmado en RUNNING)"
else
    echo "Paso 3 FAIL (Estado actual: $ST_R. Posible muerte prematura)"
    exit 1
fi

# Paso 4: Solicitar cancelación
SALIDA_CANC=$(./hermes cancel "$R" 2>&1)
if echo "$SALIDA_CANC" | grep -qi "Cancelación solicitada"; then
    echo "Paso 4 OK (Solicitud aceptada para $R)"
else
    echo "Paso 4 FAIL (Salida real: '$SALIDA_CANC')"
    exit 1
fi

# Paso 5: Reflejar resultado (CANCELED y -15)
sleep 2
SALIDA_R=$(./hermes filter id "$R")
if echo "$SALIDA_R" | grep -q "Estado: CANCELED" && echo "$SALIDA_R" | grep -q -- "-15"; then
    echo "Paso 5 OK (Refleja CANCELED y código de salida -15)"
else
    echo "Paso 5 FAIL (Salida real: '$SALIDA_R')"
    exit 1
fi

# Paso 6: Aislamiento (El testigo T debe seguir SUCCEEDED)
SALIDA_T=$(./hermes filter id "$T")
if echo "$SALIDA_T" | grep -q "Estado: SUCCEEDED"; then
    echo "Paso 6 OK (Testigo $T intacto en SUCCEEDED)"
else
    echo "Paso 6 FAIL (El testigo se alteró, salida: '$SALIDA_T')"
    exit 1
fi

# Paso 7: Rechazos con causa
SALIDA_INEX=$(./hermes cancel 999999 2>&1)
SALIDA_TERM=$(./hermes cancel "$T" 2>&1)

if echo "$SALIDA_INEX" | grep -qi "No existe" && echo "$SALIDA_TERM" | grep -qi "no se puede cancelar"; then
    echo "Paso 7 OK (Rechazos manejados correctamente)"
else
    echo "Paso 7 FAIL (Inex: '$SALIDA_INEX' | Term: '$SALIDA_TERM')"
    exit 1
fi

# Veredicto final
echo "[PASS] TC-005"
exit 0