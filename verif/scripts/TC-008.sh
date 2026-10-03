#!/bin/bash
# TC-008: Aislamiento de fallos y comandos inválidos locales (RNF-08, RNF-09; parcial Fase 1)
# Uso (WSL): bash verif/scripts/TC-008.sh   (desde la raíz del repo)
# Evidencia: verif/results/tc008.log
# Requiere: Linux/WSL con g++, make y python3.

echo "=== Ejecutando TC-008 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || { echo "[FAIL] TC-008 (no se pudo entrar a src/hermes)"; exit 1; }

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc008.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

FALLOS=0

# Paso 1: compilación limpia
make clean && make
if [ $? -ne 0 ]; then
    echo "[FAIL] TC-008 (compilación)"
    exit 1
fi
echo "Compilación OK"

# Respaldo persistente
if [ -f data/jobs.json ]; then
    cp data/jobs.json "$REPO/verif/results/jobs_tc008_backup.json"
fi

# Testigo sano de control
TG=$(./hermes job echo testigo 2>&1 | grep -oP 'job ID: \K[0-9]+')
sleep 2
echo "Testigo: $TG"

# Paso 2: cuatro inválidas, servicio vivo tras cada una
for CMD in "foo" "filter id abc" 'job ""' "cancel 999999"; do
    # shellcheck disable=SC2086
    SALIDA=$(./hermes $CMD 2>&1)
    if [ $? -eq 1 ] && [ -n "$SALIDA" ]; then
        echo "Paso 2 OK (rechazada: $CMD)"
    else
        echo "Paso 2 FAIL ($CMD)"
        FALLOS=1
    fi
done

# Paso 3: servicio operativo
TP=$(./hermes job echo testigo-post 2>&1 | grep -oP 'job ID: \K[0-9]+')
if [ -n "$TP" ]; then
    echo "Paso 3 OK (servicio vivo, job $TP)"
else
    echo "Paso 3 FAIL (servicio caído)"
    FALLOS=1
fi

# Paso 4: fallo normal aislado
F=$(./hermes job false 2>&1 | grep -oP 'job ID: \K[0-9]+')
sleep 2
EF=$(./hermes filter id "$F" 2>/dev/null | grep -oP 'Estado: "?\K[A-Z]+')
ETG=$(./hermes filter id "$TG" 2>/dev/null | grep -oP 'Estado: "?\K[A-Z]+')
if [ "$EF" = "FAILED" ] && [ "$ETG" = "SUCCEEDED" ]; then
    echo "Paso 4 OK (false FAILED, testigo intacto)"
else
    echo "Paso 4 FAIL ($F=$EF, testigo=$ETG)"
    FALLOS=1
fi

# Paso 5: programa inexistente aislado
X=$(./hermes job programa_que_no_existe_xyz 2>/dev/null | grep -oP 'job ID: \K[0-9]+')
sleep 3
EX=$(./hermes filter id "$X" 2>/dev/null | grep -oP 'Estado: "?\K[A-Z]+')
ETG=$(./hermes filter id "$TG" 2>/dev/null | grep -oP 'Estado: "?\K[A-Z]+')
if [ "$EX" = "FAILED" ] && [ "$ETG" = "SUCCEEDED" ]; then
    echo "Paso 5 OK (inexistente FAILED, testigo intacto)"
else
    echo "Paso 5 FAIL ($X=$EX, testigo=$ETG)"
    FALLOS=1
fi

# Paso 6: señal aislada
S=$(./hermes job sleep 30 2>&1 | grep -oP 'job ID: \K[0-9]+')
sleep 1
./hermes cancel "$S" > /dev/null 2>&1
sleep 2
ES=$(./hermes filter id "$S" 2>/dev/null | grep -oP 'Estado: "?\K[A-Z]+')
ETG=$(./hermes filter id "$TG" 2>/dev/null | grep -oP 'Estado: "?\K[A-Z]+')
if [ "$ES" = "CANCELED" ] && [ "$ETG" = "SUCCEEDED" ]; then
    echo "Paso 6 OK (sleep CANCELED, testigo intacto)"
else
    echo "Paso 6 FAIL ($S=$ES, testigo=$ETG)"
    FALLOS=1
fi

# Restaurar respaldo
if [ -f "$REPO/verif/results/jobs_tc008_backup.json" ]; then
    cp "$REPO/verif/results/jobs_tc008_backup.json" data/jobs.json
fi

if [ $FALLOS -eq 0 ]; then
    echo "[PASS] TC-008"
    exit 0
else
    echo "[FAIL] TC-008"
    exit 1
fi
