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

# Aislamiento: HOME temporal por prueba. Hermes resuelve sus datos con
# $HOME (data_paths.h), asi que cada test usa su propia carpeta y no toca
# los datos reales ni depende del symlink src/hermes/data.
TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"
DATA="$HOME/.local/share/hermes/data/jobs.json"
LOCK="$HOME/.local/share/hermes/data/scheduler.lock"
OUTPUT_DIR="$TEST_HOME/output"
mkdir -p "$OUTPUT_DIR"

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

rm -f "$DATA"

# Paso 1: Compilar
make clean && make > /dev/null
echo "Paso 1 OK (compilación limpia)"

# Configurar la admisión antes del primer Job para que el límite temporal
# permita conservar los 100 Jobs usados en la medición de RNF-05.
./hermes configmax 64

# Crear datos de prueba usando redirección para evitar SIGPIPE
./hermes job true > "$OUTPUT_DIR/h_a.txt"
A=$(grep -oP 'job ID: \K[0-9]+' "$OUTPUT_DIR/h_a.txt")
sleep 1
./hermes job false > "$OUTPUT_DIR/h_b.txt"
B=$(grep -oP 'job ID: \K[0-9]+' "$OUTPUT_DIR/h_b.txt")
sleep 1
./hermes job sleep 30 > "$OUTPUT_DIR/h_c.txt"
C=$(grep -oP 'job ID: \K[0-9]+' "$OUTPUT_DIR/h_c.txt")
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

# Paso 7: Rendimiento de consulta con 100 Jobs persistidos
for i in {1..100}; do
    JOB_OUTPUT="$OUTPUT_DIR/echo-$i.txt"
    if ! ./hermes job echo hola > "$JOB_OUTPUT" 2>&1; then
        echo "Paso 7 FAIL (no se pudo crear el Job echo $i)"
        cat "$JOB_OUTPUT"
        exit 1
    fi

    JOB_ID="$(sed -n 's/^job ID: *//p' "$JOB_OUTPUT" | head -n 1)"
    if [[ ! "$JOB_ID" =~ ^[0-9]+$ ]]; then
        echo "Paso 7 FAIL (ID inválido para el Job echo $i)"
        cat "$JOB_OUTPUT"
        exit 1
    fi

    JOB_STATUS=""
    for _ in $(seq 1 50); do
        JOB_STATUS="$(./hermes filter id "$JOB_ID" 2>/dev/null | sed -n 's/^Estado: //p' | head -n 1)"
        [[ "$JOB_STATUS" == "SUCCEEDED" ]] && break
        sleep 0.1
    done
    if [[ "$JOB_STATUS" != "SUCCEEDED" ]]; then
        echo "Paso 7 FAIL (Job echo $JOB_ID no terminó correctamente; estado: '$JOB_STATUS')"
        exit 1
    fi
done

TIMEFORMAT='%R'
{ time ./hermes filter programa echo > "$OUTPUT_DIR/filter-echo.txt"; } \
    2>"$OUTPUT_DIR/filter-echo.time"
FILTER_SECONDS="$(tail -n 1 "$OUTPUT_DIR/filter-echo.time")"
MATCHES="$(grep -c '^Job ID:' "$OUTPUT_DIR/filter-echo.txt" || true)"
echo "Consulta de programa echo: ${MATCHES} Jobs en ${FILTER_SECONDS} segundos"

if [[ "$MATCHES" -lt 100 ]]; then
    echo "Paso 7 FAIL (se esperaban al menos 100 Jobs echo; se encontraron $MATCHES)"
    exit 1
fi

if ! awk -v elapsed="$FILTER_SECONDS" 'BEGIN { exit !(elapsed < 1.0) }'; then
    echo "Paso 7 FAIL (la consulta tardó ${FILTER_SECONDS}s; el límite es menor que 1.0s)"
    exit 1
fi
echo "Paso 7 OK (RNF-05: consulta de 100 Jobs en menos de 1.0s)"

# Veredicto final
echo "[PASS] TC-004"
exit 0