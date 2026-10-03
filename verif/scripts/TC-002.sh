#!/bin/bash
# TC-002: Validar estructura de cola inicial (RF-03)
# Uso (WSL): bash verif/scripts/TC-002.sh   (desde la raíz del repo)
# Evidencia: verif/results/tc002.log
# Requiere: Linux/WSL con g++, make y python3.

echo "=== Ejecutando TC-002 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || { echo "[FAIL] TC-002 (no se pudo entrar a src/hermes)"; exit 1; }

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc002.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

FALLOS=0

# Paso 1: compilación limpia
make clean && make
if [ $? -ne 0 ]; then
    echo "[FAIL] TC-002 (compilación)"
    exit 1
fi
echo "Compilación OK"

# Respaldo persistente
if [ -f data/jobs.json ]; then
    cp data/jobs.json "$REPO/verif/results/jobs_tc002_backup.json"
fi

# Paso 2: último job_id conocido
M=$(python3 -c "import json;print(max([j.get('job_id',0) for j in json.load(open('data/jobs.json'))],default=0))" 2>/dev/null || echo 0)
echo "Último ID conocido: $M"

# Paso 3: crear trabajo
OUT=$(./hermes job sleep 30 2>&1)
N=$(echo "$OUT" | grep -oP 'job ID: \K[0-9]+')
if [ -z "$N" ]; then
    echo "Paso 3 FAIL (sin ID en: $OUT)"
    FALLOS=1
else
    echo "Paso 3 OK (job ID: $N)"
fi

# Paso 4: unicidad N = M + 1
if [ -n "$N" ] && [ "$N" -eq $((M + 1)) ]; then
    echo "Paso 4 OK (ID $N = $M + 1)"
else
    echo "Paso 4 FAIL (M=$M, N=$N)"
    FALLOS=1
fi

# Pasos 5-6: estructura y tipos.
# Nota QA: QUEUED dura milisegundos (el supervisor promueve de inmediato),
# así que se valida por estado observado: campos invariantes estrictos
# y campos dependientes de estado según lo encontrado. Un estado terminal
# (SUCCEEDED/FAILED/CANCELED) milisegundos después de crear un `sleep 30`
# es anómalo y se reporta con volcado para diagnóstico.
python3 - "$N" <<'EOF'
import json, sys
n = int(sys.argv[1])
jobs = json.load(open('data/jobs.json'))
for j in jobs:
    if j.get('job_id') == n:
        obj = j
        break
else:
    print('Paso 5 FAIL (ID no encontrado en JSON)')
    sys.exit(1)
print('Estado observado al inspeccionar:', obj.get('status'))
print('Tiempos:', obj.get('tiempo_recepcion'), '|', obj.get('tiempo_inicio'), '|', obj.get('tiempo_terminacion'))
ok = True
def check(cond, msg):
    global ok
    if not cond:
        print('Paso 5 FAIL (' + msg + ')')
        ok = False
# Invariantes: no dependen del estado
check(obj.get('job_id') == n, 'job_id')
check(obj.get('programa') == 'sleep', 'programa')
check(obj.get('argumentos') == ['30'], 'argumentos')
check(obj.get('cancel_requested') is False, 'cancel_requested')
# Dependientes de estado
est = obj.get('status')
if est == 'QUEUED':
    check(obj.get('pid') == 0, 'pid debe ser 0 en QUEUED')
    check(obj.get('codigo_salida') == -1, 'codigo_salida debe ser -1 en QUEUED')
elif est == 'RUNNING':
    check(isinstance(obj.get('pid'), int) and obj.get('pid') > 0, 'pid debe ser > 0 en RUNNING')
else:
    print(f'Paso 5 FAIL (estado terminal {est!r} imposible milisegundos tras crear sleep 30; ver tiempos arriba)')
    ok = False
# Tipos
check(isinstance(obj.get('job_id'), int), 'job_id no entero')
check(isinstance(obj.get('programa'), str), 'programa no cadena')
check(isinstance(obj.get('argumentos'), list), 'argumentos no arreglo')
check(isinstance(obj.get('cancel_requested'), bool), 'cancel_requested no booleano')
if ok:
    print('Pasos 5-6 OK (estructura coherente con estado observado)')
    sys.exit(0)
sys.exit(1)
EOF
[ $? -ne 0 ] && FALLOS=1

# Restaurar respaldo
if [ -f "$REPO/verif/results/jobs_tc002_backup.json" ]; then
    cp "$REPO/verif/results/jobs_tc002_backup.json" data/jobs.json
fi

if [ $FALLOS -eq 0 ]; then
    echo "[PASS] TC-002"
    exit 0
else
    echo "[FAIL] TC-002"
    exit 1
fi
