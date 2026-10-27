#!/bin/bash
# TC-002: Validar estructura de cola inicial (RF-03)
# Uso (WSL): bash verif/scripts/TC-002.sh   (desde la raíz del repo)
# Evidencia: verif/results/tc002.log
# Requiere: Linux/WSL con g++ y make.

echo "=== Ejecutando TC-002 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || { echo "[FAIL] TC-002 (no se pudo entrar a src/hermes)"; exit 1; }

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc002.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

# Aislamiento: HOME temporal por prueba. Hermes resuelve sus datos con
# $HOME (data_paths.h), asi que cada test usa su propia carpeta y no toca
# los datos reales ni depende del symlink src/hermes/data.
TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"
DATA="$HOME/.local/share/hermes/data/jobs.json"
LOCK="$HOME/.local/share/hermes/data/scheduler.lock"

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
    local scheduler_pid
    scheduler_pid="$(find_scheduler_pid)"
    if [[ -n "$scheduler_pid" ]]; then
        kill "$scheduler_pid" 2>/dev/null || true
        for _ in $(seq 1 20); do
            kill -0 "$scheduler_pid" 2>/dev/null || break
            sleep 0.1
        done
    fi
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

FALLOS=0

# Paso 1 del TC: compilar
make clean && make
if [ $? -ne 0 ]; then
    echo "[FAIL] TC-002 (compilación)"
    exit 1
fi
echo "Paso 1 OK (compilación limpia)"

# Precondición (RF-03): el planificador atiende con 5 trabajadores
# (NUM_TRABAJADORES en scheduler.cpp). Se ocupan los 5 con "sleep 30" para
# que el trabajo del Paso 3 no encuentre hueco y permanezca en cola.
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
    FALLOS=1
fi

# Paso 2 del TC: anotar último job_id (M; 0 si no hay archivo)
M=$(grep -oP '"job_id": \K[0-9]+' "$DATA" 2>/dev/null | sort -n | tail -1)
[ -z "$M" ] && M=0
echo "Paso 2 OK (último job_id M=$M)"

# Paso 3 del TC: crear trabajo y anotar N
OUT=$(./hermes job sleep 30 2>&1)
RC=$?
N=$(echo "$OUT" | grep -oP 'job ID: \K[0-9]+')
if [ $RC -eq 0 ] && [ -n "$N" ]; then
    echo "Paso 3 OK (job ID: $N, código 0)"
else
    echo "Paso 3 FAIL (salida: $OUT, código: $RC)"
    FALLOS=1
fi

# Paso 4 del TC: unicidad y orden N = M + 1
if [ -n "$N" ] && [ "$N" -eq $((M + 1)) ]; then
    echo "Paso 4 OK (N=$N = M+1)"
else
    echo "Paso 4 FAIL (M=$M, N=$N)"
    FALLOS=1
fi

# Pasos 5-6 del TC: bloque de la entrada N y sus 7 campos con tipos.
# jobs.json usa dump(4): cada entrada cierra con "    }".
# Se usa $0 ~ para buscar el patrón exacto en la línea actual
BLOQ=$(awk -v n="\"job_id\": $N," '
/^[ \t]*\{/ { buf = $0; in_obj = 1; next }
in_obj { buf = buf "\n" $0 }
/^[ \t]*\}/ { if (buf ~ n) { print buf; exit }; in_obj = 0 }
' "$DATA")
revisar() {
    if echo "$BLOQ" | grep -q "$1"; then
        echo "  OK ($2)"
    else
        echo "  FAIL ($2)"
        FALLOS=1
    fi
}
echo "Paso 5 (entrada $N campo por campo):"
revisar "\"job_id\": $N" "job_id = $N (numérico)"
revisar '"programa": "sleep"' 'programa = sleep (cadena)'
revisar '"30"' 'argumentos contiene 30'
revisar '"status": "QUEUED"' 'status = QUEUED (cadena)'
revisar '"pid": 0' 'pid = 0 (numérico)'
revisar '"codigo_salida": -1' 'codigo_salida = -1 (numérico)'
revisar '"cancel_requested": false' 'cancel_requested = false (booleano)'
echo "Paso 6 OK (los patrones exigen tipos: números sin comillas, cadenas con comillas, booleano literal)"

if [ $FALLOS -eq 0 ]; then
    echo "[PASS] TC-002"
    exit 0
else
    echo "[FAIL] TC-002"
    exit 1
fi