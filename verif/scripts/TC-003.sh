#!/bin/bash
# TC-003: Estados y tiempos (RF-06, RF-07)
# Uso (WSL): bash verif/scripts/TC-003.sh   (desde la raíz del repo)
# Evidencia: verif/results/tc003.log
# Requiere: Linux/WSL con g++, make y python3.

echo "=== Ejecutando TC-003 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || { echo "[FAIL] TC-003 (no se pudo entrar a src/hermes)"; exit 1; }

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc003.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

FALLOS=0

# Paso 1: compilación limpia
make clean && make
if [ $? -ne 0 ]; then
    echo "[FAIL] TC-003 (compilación)"
    exit 1
fi
echo "Compilación OK"

# Respaldo persistente
if [ -f data/jobs.json ]; then
    cp data/jobs.json "$REPO/verif/results/jobs_tc003_backup.json"
fi

esperar_estado() {
    # $1=id $2=estado_esperado $3=timeout_s
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

# Paso 2: éxito
A=$(./hermes job true 2>&1 | grep -oP 'job ID: \K[0-9]+')
[ -n "$A" ] && esperar_estado "$A" "SUCCEEDED" 10
if [ -n "$A" ] && esperar_estado "$A" "SUCCEEDED" 1; then
    echo "Paso 2 OK (job $A SUCCEEDED)"
else
    echo "Paso 2 FAIL (job true no llegó a SUCCEEDED)"
    FALLOS=1
fi

# Paso 3: fallo
B=$(./hermes job false 2>&1 | grep -oP 'job ID: \K[0-9]+')
if [ -n "$B" ] && esperar_estado "$B" "FAILED" 10; then
    echo "Paso 3 OK (job $B FAILED)"
else
    echo "Paso 3 FAIL (job false no llegó a FAILED)"
    FALLOS=1
fi

# Paso 4: cancelación
C=$(./hermes job sleep 30 2>&1 | grep -oP 'job ID: \K[0-9]+')
sleep 1
./hermes cancel "$C" > /dev/null 2>&1
if [ -n "$C" ] && esperar_estado "$C" "CANCELED" 10; then
    echo "Paso 4 OK (job $C CANCELED)"
else
    echo "Paso 4 FAIL (sleep no llegó a CANCELED)"
    FALLOS=1
fi

# Paso 5: cinco estados representados
Q=$(./hermes job sleep 30 2>&1 | grep -oP 'job ID: \K[0-9]+')
EST_Q=$(./hermes filter id "$Q" 2>/dev/null | grep -oP 'Estado: \K[A-Z]+')
if [ "$EST_Q" = "QUEUED" ] || [ "$EST_Q" = "RUNNING" ]; then
    echo "Paso 5 OK (QUEUED/RUNNING observado: $EST_Q; SUCCEEDED/FAILED/CANCELED en pasos 2-4)"
else
    echo "Paso 5 FAIL (estado inicial: $EST_Q)"
    FALLOS=1
fi
./hermes cancel "$Q" > /dev/null 2>&1

# Paso 6: códigos y tiempos
python3 - "$A" "$B" "$C" <<'EOF'
import json, re, sys
a, b, c = sys.argv[1], sys.argv[2], sys.argv[3]
jobs = {str(j.get('job_id')): j for j in json.load(open('data/jobs.json'))}
ok = True
def check(cond, msg):
    global ok
    if not cond:
        print('Paso 6 FAIL (' + msg + ')')
        ok = False
check(jobs[a]['status'] == 'SUCCEEDED' and jobs[a]['codigo_salida'] == 0, 'éxito sin codigo 0')
check(jobs[b]['status'] == 'FAILED' and jobs[b]['codigo_salida'] != 0, 'fallo sin codigo != 0')
check(jobs[c]['status'] == 'CANCELED', 'cancelado sin CANCELED')
fmt = re.compile(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$')
for k in (a, b, c):
    for campo in ('tiempo_recepcion', 'tiempo_inicio', 'tiempo_terminacion'):
        check(bool(fmt.match(jobs[k].get(campo, ''))), f'tiempo {campo} ausente/mal formato en {k}')
    check(jobs[k]['tiempo_recepcion'] <= jobs[k]['tiempo_inicio'] <= jobs[k]['tiempo_terminacion'], f'orden temporal roto en {k}')
if ok:
    print('Paso 6 OK (códigos y tiempos coherentes)')
    sys.exit(0)
sys.exit(1)
EOF
[ $? -ne 0 ] && FALLOS=1

# Restaurar respaldo
if [ -f "$REPO/verif/results/jobs_tc003_backup.json" ]; then
    cp "$REPO/verif/results/jobs_tc003_backup.json" data/jobs.json
fi

if [ $FALLOS -eq 0 ]; then
    echo "[PASS] TC-003"
    exit 0
else
    echo "[FAIL] TC-003"
    exit 1
fi
