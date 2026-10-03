#!/bin/bash
# TC-005: Solicitar cancelación de proceso en ejecución (RF-10, parcial Fase 1)
# Uso (WSL): bash verif/scripts/TC-005.sh   (desde la raíz del repo)
# Evidencia: verif/results/tc005.log
# Requiere: Linux/WSL con g++, make y python3.

echo "=== Ejecutando TC-005 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || { echo "[FAIL] TC-005 (no se pudo entrar a src/hermes)"; exit 1; }

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc005.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

FALLOS=0

# Paso 1: compilación limpia
make clean && make
if [ $? -ne 0 ]; then
    echo "[FAIL] TC-005 (compilación)"
    exit 1
fi
echo "Compilación OK"

# Respaldo persistente
if [ -f data/jobs.json ]; then
    cp data/jobs.json "$REPO/verif/results/jobs_tc005_backup.json"
fi

esperar_estado() {
    local ID=$1 ESP=$2 T=$3 i=0
    while [ $i -lt "$T" ]; do
        if ./hermes filter id "$ID" 2>/dev/null | grep -q "Estado: .*${ESP}"; then
            return 0
        fi
        sleep 1
        i=$((i + 1))
    done
    return 1
}

# Paso 2: objetivo y testigo
R=$(./hermes job sleep 30 2>&1 | grep -oP 'job ID: \K[0-9]+')
T=$(./hermes job echo testigo 2>&1 | grep -oP 'job ID: \K[0-9]+')
if [ -n "$R" ] && [ -n "$T" ]; then
    echo "Paso 2 OK (R=$R, T=$T)"
else
    echo "Paso 2 FAIL (R=$R, T=$T)"
    FALLOS=1
fi

# Paso 3: confirmar RUNNING
if esperar_estado "$R" "RUNNING" 10; then
    echo "Paso 3 OK ($R RUNNING)"
else
    echo "Paso 3 FAIL ($R no llegó a RUNNING)"
    FALLOS=1
fi

# Paso 4: solicitar cancelación
SALIDA=$(./hermes cancel "$R" 2>&1)
if [ $? -eq 0 ] && echo "$SALIDA" | grep -qi "solicitada"; then
    echo "Paso 4 OK (solicitud aceptada, código 0)"
else
    echo "Paso 4 FAIL ($SALIDA)"
    FALLOS=1
fi

# Paso 5: reflejar CANCELED/-15
if esperar_estado "$R" "CANCELED" 10; then
    COD=$(python3 -c "import json;print([j['codigo_salida'] for j in json.load(open('data/jobs.json')) if j.get('job_id')==$R][0])")
    if [ "$COD" = "-15" ]; then
        echo "Paso 5 OK ($R CANCELED/-15)"
    else
        echo "Paso 5 FAIL (codigo: $COD, esperado -15)"
        FALLOS=1
    fi
else
    echo "Paso 5 FAIL ($R no llegó a CANCELED)"
    FALLOS=1
fi

# Paso 6: testigo intacto
EST_T=$(./hermes filter id "$T" 2>/dev/null | grep -oP 'Estado: "?\K[A-Z]+')
if [ "$EST_T" = "SUCCEEDED" ]; then
    echo "Paso 6 OK (testigo $T SUCCEEDED intacto)"
else
    echo "Paso 6 FAIL (testigo: $EST_T)"
    FALLOS=1
fi

# Paso 7: rechazos con causa
SALIDA=$(./hermes cancel 999999 2>&1)
OK1=1; [ $? -eq 1 ] && echo "$SALIDA" | grep -qi "no existe" && OK1=0
SALIDA=$(./hermes cancel "$T" 2>&1)
OK2=1; [ $? -eq 1 ] && echo "$SALIDA" | grep -qi "no se puede cancelar" && OK2=0
if [ $OK1 -eq 0 ] && [ $OK2 -eq 0 ]; then
    echo "Paso 7 OK (inexistente + terminado rechazados con causa)"
else
    echo "Paso 7 FAIL"
    FALLOS=1
fi

# Restaurar respaldo
if [ -f "$REPO/verif/results/jobs_tc005_backup.json" ]; then
    cp "$REPO/verif/results/jobs_tc005_backup.json" data/jobs.json
fi

if [ $FALLOS -eq 0 ]; then
    echo "[PASS] TC-005"
    exit 0
else
    echo "[FAIL] TC-005"
    exit 1
fi
