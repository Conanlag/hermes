#!/usr/bin/env bash
# RF-22 / AC5 + compatibilidad - T-13.
# V9: 'hermes red job' responde sin esperar al scheduler (pid 0), conserva el
# formato de admisión, deduplica por request_id y el Job termina correctamente.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45820
LIMITE_MS=1000
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
JOBS="$DATA_DIR/jobs.json"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-034.md"
mkdir -p "$NET_DIR" "$RESULTS_DIR"

cat >"$NET_DIR/network.json" <<'JSON'
{
  "habilitada": true,
  "clientes": [
    {
      "id": "PC-B",
      "direcciones": ["127.0.0.1"],
      "operaciones": ["submit", "query", "list", "cancel"],
      "programas": ["true", "sleep", "echo", "ls"]
    }
  ]
}
JSON

{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '```text\n'
} >>"$RESULTS_FILE"
exec > >(tee -a "$RESULTS_FILE") 2>&1

find_scheduler_pid() {
    local descriptor target process_path
    for descriptor in /proc/[0-9]*/fd/*; do
        [[ -e "$descriptor" ]] || continue
        target="$(readlink "$descriptor" 2>/dev/null || true)"
        if [[ "$target" == "$DATA_DIR/scheduler.lock" ]]; then
            process_path="${descriptor#/proc/}"
            printf '%s\n' "${process_path%%/*}"
            return 0
        fi
    done
    return 0
}

stop_scheduler() {
    local scheduler_pid
    scheduler_pid="$(find_scheduler_pid)"
    [[ -z "$scheduler_pid" ]] && return 0
    kill "$scheduler_pid" 2>/dev/null || true
    for _ in $(seq 1 50); do
        [[ ! -d "/proc/$scheduler_pid/fd" ]] && return 0
        sleep 0.1
    done
    return 1
}

cleanup() {
    if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
        for _ in $(seq 1 50); do
            kill -0 "$SERVER_PID" 2>/dev/null || break
            sleep 0.1
        done
        kill -9 "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    stop_scheduler || true
    rm -rf "$TEST_ROOT"
    printf '```\n'
}
trap cleanup EXIT

puerto_ocupado() {
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$PUERTO\$"
}

if [[ ! -x "$HERMES" ]]; then
    echo "FAIL: no existe $HERMES. Compila Hermes antes de ejecutar la prueba."
    exit 1
fi
if puerto_ocupado; then
    echo "FAIL: el puerto $PUERTO ya está en uso; detenga el servidor previo."
    exit 1
fi

"$HERMES" red start >"$TEST_ROOT/server.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 100); do
    puerto_ocupado && break
    sleep 0.1
done
if ! puerto_ocupado; then
    echo "FAIL: el servidor no abrió el puerto $PUERTO."
    cat "$TEST_ROOT/server.log"
    exit 1
fi

INICIO=$(date +%s%N)
SALIDA="$("$HERMES" red job 127.0.0.1 true 2>&1)" || {
    echo "FAIL: 'red job' terminó con error:"
    printf '%s\n' "$SALIDA"
    exit 1
}
FIN=$(date +%s%N)
MS=$(( (FIN - INICIO) / 1000000 ))
printf '%s\n' "$SALIDA"

if ! grep -q "job ID: [0-9]\+" <<<"$SALIDA"; then
    echo "FAIL: la respuesta no informa el job ID."
    exit 1
fi
if ! grep -q "PID: pendiente (en cola)" <<<"$SALIDA"; then
    echo "FAIL: la respuesta no usa el formato de admisión sin PID (pid 0)."
    exit 1
fi
echo "PASS V9a: 'red job' respondió en ${MS} ms con el Job en cola."
if (( MS >= LIMITE_MS )); then
    echo "FAIL: 'red job' tardó ${MS} ms; el hilo de red sigue esperando al scheduler (AC5)."
    exit 1
fi

JOB_ID="$(sed -n 's/^job ID: \([0-9]\{1,\}\).*/\1/p' <<<"$SALIDA" | head -n 1)"
if [[ -z "$JOB_ID" ]]; then
    echo "FAIL: no se pudo extraer el job ID."
    exit 1
fi

DUP="$( "$HERMES" red job 127.0.0.1 --request-id "v9-dup" true 2>&1)"
DUP2="$("$HERMES" red job 127.0.0.1 --request-id "v9-dup" true 2>&1)"
printf '%s\n%s\n' "$DUP" "$DUP2"
if ! grep -q "Solicitud duplicada" <<<"$DUP2"; then
    echo "FAIL: la deduplicación por request_id dejó de funcionar."
    exit 1
fi

for _ in $(seq 1 100); do
    ESTADO="$("$HERMES" red filter 127.0.0.1 id "$JOB_ID" 2>&1 | sed -n 's/^Estado: //p')"
    [[ "$ESTADO" == "SUCCEEDED" || "$ESTADO" == "FAILED" ]] && break
    sleep 0.1
done
if [[ "$ESTADO" != "SUCCEEDED" ]]; then
    echo "FAIL: el Job remoto no terminó correctamente (estado: ${ESTADO:-desconocido})."
    exit 1
fi
echo "PASS V9b: deduplicación intacta y Job $JOB_ID en estado $ESTADO."

if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "FAIL: el servicio terminó durante la prueba (AC1)."
    exit 1
fi
echo "PASS: RF-22 T-13 (V9) sin fallos."
