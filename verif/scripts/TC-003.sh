#!/bin/bash
# TC-003: Estados y tiempos (RF-06, RF-07)
# Uso: bash verif/scripts/TC-003.sh
# Evidencia: verif/results/tc003.log

echo "=== Ejecutando TC-003 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || exit 1

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc003.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

rm -f data/jobs.json

# Paso 1: compilación
make clean && make > /dev/null
echo "Paso 1 OK (compilación limpia)"

# Paso 2: éxito
./hermes job true > /tmp/h_a.txt
A=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_a.txt)
sleep 1
ST_A=$(./hermes filter id "$A" | grep 'Estado:' | awk '{print $2}')
[ "$ST_A" = "SUCCEEDED" ] && echo "Paso 2 OK (job $A -> SUCCEEDED)" || echo "Paso 2 FAIL"

# Paso 3: fallo
./hermes job false > /tmp/h_b.txt
B=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_b.txt)
sleep 1
ST_B=$(./hermes filter id "$B" | grep 'Estado:' | awk '{print $2}')
[ "$ST_B" = "FAILED" ] && echo "Paso 3 OK (job $B -> FAILED)" || echo "Paso 3 FAIL"

# Paso 4: cancelación
./hermes job sleep 30 > /tmp/h_c.txt
C=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_c.txt)
sleep 1
./hermes cancel "$C" > /dev/null
sleep 1
ST_C=$(./hermes filter id "$C" | grep 'Estado:' | awk '{print $2}')
[ "$ST_C" = "CANCELED" ] && echo "Paso 4 OK (job $C -> CANCELED)" || echo "Paso 4 FAIL"

# Paso 5: QUEUED (El que debe fallar por el Hito 1)
./hermes job sleep 30 > /tmp/h_q.txt
Q=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_q.txt)
ST_Q=$(./hermes filter id "$Q" | grep 'Estado:' | awk '{print $2}')
if [ "$ST_Q" = "QUEUED" ]; then
    echo "Paso 5 OK (QUEUED observado)"
else
    echo "Paso 5 FAIL (estado inicial exigido: QUEUED, real observado: $ST_Q)"
fi
./hermes cancel "$Q" > /dev/null 2>&1

# Paso 6: Verificación en JSON (Tiempos y códigos)
python3 -c "
import json, sys
try:
    jobs = {str(j['job_id']): j for j in json.load(open('data/jobs.json'))}
    a, b, c = '$A', '$B', '$C'
    assert jobs[a]['codigo_salida'] == 0, 'Job A codigo != 0'
    assert jobs[b]['codigo_salida'] != 0, 'Job B codigo == 0'
    assert jobs[c]['codigo_salida'] == -15, 'Job C codigo != -15'
    for k in (a,b,c):
        t1, t2, t3 = jobs[k]['tiempo_recepcion'], jobs[k]['tiempo_inicio'], jobs[k]['tiempo_terminacion']
        assert t1 <= t2 <= t3, f'Tiempos mal ordenados en {k}'
    print('Paso 6 OK (códigos y tiempos validados en JSON)')
except Exception as e:
    print('Paso 6 FAIL:', e)
    sys.exit(1)
"

# Cierre y Veredicto
echo "[FAIL] TC-003 (No se observa estado inicial QUEUED por desfase de alcance en Hito 1)"
exit 1