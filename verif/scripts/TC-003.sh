#!/bin/bash
# TC-003: Estados y tiempos (RF-06, RF-07)
# Uso: bash verif/scripts/TC-003.sh
# Evidencia: verif/results/tc003.log
#
# La prueba usa un HOME temporal y limpia el demonio al terminar, igual que
# TC-019, TC-021 y TC-022. Así no depende del symlink src/hermes/data ni de
# los datos reales del usuario.

echo "=== Ejecutando TC-003 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || exit 1

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc003.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"

DATA="$HOME/.local/share/hermes/data/jobs.json"
LOCK="$HOME/.local/share/hermes/data/scheduler.lock"
FALLOS=0

find_scheduler_pid() {
    local descriptor target process_path
    for descriptor in /proc/[0-9]*/fd/*; do
        [[ -e "$descriptor" ]] || continue
        target="$(readlink "$descriptor" 2>/dev/null || true)"
        if [[ "$target" == "$LOCK" ]]; then
            process_path="${descriptor#/proc/}"
            printf '%s\n' "${process_path%%/*}"
            return 0
        fi
    done
    return 0
}

cleanup() {
    local pid
    pid="$(find_scheduler_pid)"
    if [[ -n "$pid" ]]; then
        kill -TERM "$pid" 2>/dev/null || true
        for _ in $(seq 1 50); do
            [[ -z "$(find_scheduler_pid)" ]] && break
            sleep 0.1
        done
    fi
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

# Paso 1: compilación
make clean > /dev/null
if ! make > /dev/null; then
    echo "Paso 1 FAIL (no compiló)"
    echo "[FAIL] TC-003 (fallo de compilación)"
    exit 1
fi
echo "Paso 1 OK (compilación limpia)"

# Paso 2: éxito
./hermes job true > "$TEST_ROOT/h_a.txt"
A=$(grep -oP 'job ID: \K[0-9]+' "$TEST_ROOT/h_a.txt")
sleep 1
ST_A=$(./hermes filter id "$A" | grep 'Estado:' | awk '{print $2}')
if [ "$ST_A" = "SUCCEEDED" ]; then
    echo "Paso 2 OK (job $A -> SUCCEEDED)"
else
    echo "Paso 2 FAIL (estado observado: $ST_A)"
    FALLOS=$((FALLOS + 1))
fi

# Paso 3: fallo
./hermes job false > "$TEST_ROOT/h_b.txt"
B=$(grep -oP 'job ID: \K[0-9]+' "$TEST_ROOT/h_b.txt")
sleep 1
ST_B=$(./hermes filter id "$B" | grep 'Estado:' | awk '{print $2}')
if [ "$ST_B" = "FAILED" ]; then
    echo "Paso 3 OK (job $B -> FAILED)"
else
    echo "Paso 3 FAIL (estado observado: $ST_B)"
    FALLOS=$((FALLOS + 1))
fi

# Paso 4: cancelación
./hermes job sleep 30 > "$TEST_ROOT/h_c.txt"
C=$(grep -oP 'job ID: \K[0-9]+' "$TEST_ROOT/h_c.txt")
sleep 1
./hermes cancel "$C" > /dev/null
sleep 1
ST_C=$(./hermes filter id "$C" | grep 'Estado:' | awk '{print $2}')
if [ "$ST_C" = "CANCELED" ]; then
    echo "Paso 4 OK (job $C -> CANCELED)"
else
    echo "Paso 4 FAIL (estado observado: $ST_C)"
    FALLOS=$((FALLOS + 1))
fi

# Precondición (RF-03): el planificador atiende con 5 trabajadores
# (NUM_TRABAJADORES en scheduler.cpp). Se ocupan los 5 con "sleep 30" para
# que el job del Paso 5 no encuentre hueco y permanezca en cola.
for _ in 1 2 3 4 5; do
    ./hermes job sleep 30 > /dev/null
done
for _ in $(seq 1 50); do
    RUNNING=$(grep -c '"status": "RUNNING"' "$DATA" 2>/dev/null || true)
    [ "${RUNNING:-0}" -ge 5 ] && break
    sleep 0.1
done
if [ "${RUNNING:-0}" -ge 5 ]; then
    echo "Precondición OK (5 trabajadores en RUNNING)"
else
    echo "Precondición FAIL (solo ${RUNNING:-0} de 5 en RUNNING)"
    FALLOS=$((FALLOS + 1))
fi

# Paso 5: QUEUED (sin worker libre: la cola retiene el job)
./hermes job sleep 30 > "$TEST_ROOT/h_q.txt"
Q=$(grep -oP 'job ID: \K[0-9]+' "$TEST_ROOT/h_q.txt")
ST_Q=$(./hermes filter id "$Q" | grep 'Estado:' | awk '{print $2}')
if [ "$ST_Q" = "QUEUED" ]; then
    echo "Paso 5 OK (QUEUED observado)"
else
    echo "Paso 5 FAIL (estado inicial exigido: QUEUED, real observado: $ST_Q)"
    FALLOS=$((FALLOS + 1))
fi
./hermes cancel "$Q" > /dev/null 2>&1

# Paso 6: Verificación en JSON (Tiempos y códigos)
if ! python3 -c '
import json, sys

path, a, b, c = sys.argv[1:5]

try:
    jobs = {str(j["job_id"]): j for j in json.load(open(path))}
    assert jobs[a]["codigo_salida"] == 0, "Job A codigo != 0"
    assert jobs[b]["codigo_salida"] != 0, "Job B codigo == 0"
    assert jobs[c]["codigo_salida"] == -15, "Job C codigo != -15"
    for k in (a, b, c):
        t1 = jobs[k]["tiempo_recepcion"]
        t2 = jobs[k]["tiempo_inicio"]
        t3 = jobs[k]["tiempo_terminacion"]
        assert t1 <= t2 <= t3, f"Tiempos mal ordenados en {k}"
    print("Paso 6 OK (códigos y tiempos validados en JSON)")
except Exception as e:
    print("Paso 6 FAIL:", e)
    sys.exit(1)
' "$DATA" "$A" "$B" "$C"; then
    FALLOS=$((FALLOS + 1))
fi

# Cierre y Veredicto
if (( FALLOS == 0 )); then
    echo "[PASS] TC-003"
    exit 0
fi

echo "[FAIL] TC-003 ($FALLOS paso(s) fallido(s))"
exit 1
