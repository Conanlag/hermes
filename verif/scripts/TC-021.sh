#!/usr/bin/env bash
set -uo pipefail

TC_ID="TC-021"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
HERMES="${PROJECT_ROOT}/src/hermes/hermes"
TEST_ROOT="$(mktemp -d)"
TEST_HOME="${TEST_ROOT}/home"
DATA="${TEST_HOME}/.local/share/hermes/data/jobs.json"
LOCK="${TEST_HOME}/.local/share/hermes/data/scheduler.lock"
cd "$PROJECT_ROOT" || {
    echo "[FAIL] ${TC_ID}: no se pudo acceder a la raíz del proyecto"
    exit 1
}

RESULTS_DIR="verif/results"
LOG_FILE="${RESULTS_DIR}/results_TC-021.md"
mkdir -p "$RESULTS_DIR"

# Conserva en el log toda la salida estándar y de error de la prueba.
exec > >(tee "$LOG_FILE") 2>&1

JOB_ID=""

fail() {
    echo "[FAIL] ${TC_ID}: $*"
    exit 1
}

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
    local scheduler_pid status
    if [[ -n "$JOB_ID" && -f "$DATA" ]]; then
        status="$("$HERMES" filter id "$JOB_ID" 2>/dev/null | sed -n 's/^Estado: //p' | head -n 1)"
        if [[ "$status" == "QUEUED" || "$status" == "RUNNING" ]]; then
            "$HERMES" cancel "$JOB_ID" >/dev/null 2>&1 || true
        fi
    fi
    scheduler_pid="$(find_scheduler_pid)"
    if [[ -n "$scheduler_pid" ]]; then
        kill "$scheduler_pid" 2>/dev/null || true
    fi
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

echo "=== Ejecutando ${TC_ID} ==="
echo "RF-30: escalamiento forzoso tras una cancelación normal ignorada por SIGTERM"

[[ -x "$HERMES" ]] || fail "no existe el ejecutable ${HERMES}; compila Hermes antes de ejecutar la prueba"
mkdir -p "$TEST_HOME"
export HOME="$TEST_HOME"

# El shell ignora SIGTERM. El bucle mantiene vivo el trabajo aunque
# un proceso sleep hijo reciba la señal.
submit_output="$("$HERMES" job bash -c 'trap "" TERM; while :; do sleep 1; done' 2>&1)"
submit_rc=$?
printf 'Salida de hermes job:\n%s\n' "$submit_output"
echo "Código de salida de hermes job: ${submit_rc}"
(( submit_rc == 0 )) || fail "hermes job devolvió ${submit_rc}"

JOB_ID="$(printf '%s\n' "$submit_output" | tr -d '\r' | sed -n 's/^job ID:[[:space:]]*//p' | head -n 1)"
[[ "$JOB_ID" =~ ^[0-9]+$ ]] || fail "no se pudo extraer un ID de Job válido de la línea 'job ID:'"
echo "ID del trabajo: ${JOB_ID}"

cancel_started=$SECONDS
cancel_output="$("$HERMES" cancel "$JOB_ID" 2>&1)"
cancel_rc=$?
cancel_elapsed=$((SECONDS - cancel_started))
printf 'Salida de hermes cancel:\n%s\n' "$cancel_output"
echo "Código de salida de hermes cancel: ${cancel_rc}"
echo "Duración de hermes cancel (segundos): ${cancel_elapsed}"
(( cancel_rc == 0 )) || fail "hermes cancel devolvió ${cancel_rc}"
(( cancel_elapsed >= 5 )) || fail "la cancelación terminó antes del periodo de gracia de 5 segundos"

final_output=""
final_rc=1
for _ in $(seq 1 50); do
    final_output="$("$HERMES" filter id "$JOB_ID" 2>&1)"
    final_rc=$?
    if (( final_rc == 0 )) && grep -q '^Estado: CANCELED$' <<<"$final_output"; then
        break
    fi
    sleep 0.1
done
printf 'Estado final:\n%s\n' "$final_output"
echo "Código de salida de la consulta final: ${final_rc}"

if (( final_rc == 0 )) &&
   grep -q '^Estado: CANCELED$' <<<"$final_output" &&
   grep -q '^Codigo de salida: -9$' <<<"$final_output"; then
    echo "El trabajo ignoró SIGTERM y terminó por escalamiento forzoso después del periodo de gracia."
    echo "[PASS] ${TC_ID}"
    exit 0
else
    fail "se esperaba estado CANCELED con código -9 tras el periodo de gracia, o falló la consulta final"
fi