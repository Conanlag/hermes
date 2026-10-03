#!/bin/bash
# TC-006: Capturar stdout/stderr separados y código de salida (RF-11, RF-07 parcial Fase 1)
# Uso (WSL): bash verif/scripts/TC-006.sh   (desde la raíz del repo)
# Evidencia: verif/results/tc006.log
# Requiere: Linux/WSL con g++, make y python3.

echo "=== Ejecutando TC-006 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || { echo "[FAIL] TC-006 (no se pudo entrar a src/hermes)"; exit 1; }

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc006.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

FALLOS=0

# Paso 1: compilación limpia
make clean && make
if [ $? -ne 0 ]; then
    echo "[FAIL] TC-006 (compilación)"
    exit 1
fi
echo "Compilación OK"

# Respaldo persistente
if [ -f data/jobs.json ]; then
    cp data/jobs.json "$REPO/verif/results/jobs_tc006_backup.json"
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

# Paso 2: solo stdout
O=$(./hermes job echo hola 2>'err_o.txt' | tee 'out_o.txt' | grep -oP 'job ID: \K[0-9]+')
ERR_O=$(cat err_o.txt)
if [ -n "$O" ] && esperar_estado "$O" "SUCCEEDED" 10 && grep -q "hola" out_o.txt && [ -z "$ERR_O" ]; then
    echo "Paso 2 OK (stdout con hola, stderr vacío)"
else
    echo "Paso 2 FAIL"
    FALLOS=1
fi
rm -f out_o.txt err_o.txt

# Paso 3: solo stderr
E=$(./hermes job ls /ruta_inexistente_xyz 2>err_e.txt | grep -oP 'job ID: \K[0-9]+')
sleep 3
ERR_E=$(cat err_e.txt 2>/dev/null)
FILT_E=$(./hermes filter id "$E" 2>/dev/null)
if [ -n "$E" ] && echo "$FILT_E" | grep -q "FAILED" && [ -n "$ERR_E" ]; then
    echo "Paso 3 OK (stderr con error, FAILED)"
else
    echo "Paso 3 FAIL"
    FALLOS=1
fi
rm -f err_e.txt

# Paso 4: mixto con código 3
M=$(./hermes job sh -c "echo salida-ok; echo fallo-ok >&2; exit 3" 2>err_m.txt | tee out_m.txt | grep -oP 'job ID: \K[0-9]+')
sleep 3
ERR_M=$(cat err_m.txt 2>/dev/null)
OUT_M=$(cat out_m.txt 2>/dev/null)
FILT_M=$(./hermes filter id "$M" 2>/dev/null)
if [ -n "$M" ] && echo "$FILT_M" | grep -q "FAILED" && echo "$OUT_M" | grep -q "salida-ok" && echo "$ERR_M" | grep -q "fallo-ok"; then
    echo "Paso 4 OK (canales separados)"
else
    echo "Paso 4 FAIL"
    FALLOS=1
fi
rm -f out_m.txt err_m.txt

# Paso 5: códigos persistidos (tiempos fuera de alcance Fase 1)
python3 - "$O" "$E" "$M" <<'EOF'
import json, sys
o, e, m = sys.argv[1], sys.argv[2], sys.argv[3]
jobs = {str(j.get('job_id')): j for j in json.load(open('data/jobs.json'))}
ok = True
def check(cond, msg):
    global ok
    if not cond:
        print('Paso 5 FAIL (' + msg + ')')
        ok = False
check(jobs[o]['codigo_salida'] == 0, 'echo sin codigo 0')
check(jobs[e]['codigo_salida'] != 0, 'ls sin codigo != 0')
check(jobs[m]['codigo_salida'] == 3, 'mixto sin codigo 3')
if ok:
    print('Paso 5 OK (códigos 0/no-0/3 persistidos)')
    sys.exit(0)
sys.exit(1)
EOF
[ $? -ne 0 ] && FALLOS=1

# Restaurar respaldo
if [ -f "$REPO/verif/results/jobs_tc006_backup.json" ]; then
    cp "$REPO/verif/results/jobs_tc006_backup.json" data/jobs.json
fi

if [ $FALLOS -eq 0 ]; then
    echo "[PASS] TC-006"
    exit 0
else
    echo "[FAIL] TC-006"
    exit 1
fi
