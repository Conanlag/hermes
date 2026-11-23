#!/usr/bin/env bash
# RNF-15 - Los registros no deben exponer secretos.
# TC-045: un request_id rechazado no se copia a la bitacora; solo su longitud.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
EVENTOS="$DATA_DIR/events.jsonl"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-045.md"
mkdir -p "$RESULTS_DIR"

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
    return 0
}

cleanup() {
    stop_scheduler || true
    rm -rf "$TEST_ROOT"
    printf '```\n'
}
trap cleanup EXIT

if [[ ! -x "$HERMES" ]]; then
    echo "FAIL: no existe $HERMES. Compila Hermes antes de ejecutar la prueba."
    exit 1
fi

LARGO="$(printf 'a%.0s' $(seq 1 140))"

echo "== request_id con caracteres invalidos =="
if "$HERMES" job --request-id "rf15 secreto6" true; then
    echo "FAIL: se acepto un request_id con espacios."
    exit 1
fi
echo "  rechazado con codigo distinto de cero"

echo "== request_id demasiado largo =="
if "$HERMES" job --request-id "$LARGO" true; then
    echo "FAIL: se acepto un request_id de 140 caracteres."
    exit 1
fi
echo "  rechazado con codigo distinto de cero"

echo "== request_id valido =="
"$HERMES" job --request-id rf15-ok-1 true
sleep 0.3

# AC1: ningun valor rechazado aparece en la bitacora.
python3 - "$EVENTOS" "rf15 secreto6" "$LARGO" <<'PY'
import json, os, sys

ruta, invalido, largo = sys.argv[1], sys.argv[2], sys.argv[3]
texto = open(ruta, encoding="utf-8").read() if os.path.exists(ruta) else ""
if invalido in texto:
    raise SystemExit("FAIL: la bitacora copio el request_id rechazado")
if largo in texto:
    raise SystemExit("FAIL: la bitacora copio un request_id de 140 caracteres")

eventos = [json.loads(l) for l in texto.splitlines() if l.strip()]
rechazos = [e for e in eventos if e.get("message") == "Rechazo de Validación"]
longitudes = sorted(e.get("context", {}).get("longitud_intentada") for e in rechazos)
esperadas = sorted([len(invalido), len(largo)])
if longitudes != esperadas:
    raise SystemExit("FAIL: longitudes registradas %r (se esperaban %r)" % (longitudes, esperadas))
for entrada in rechazos:
    contexto = entrada.get("context", {})
    if "request_id_intentado" in contexto:
        raise SystemExit("FAIL: el rechazo sigue registrando el valor crudo")
    if not contexto.get("motivo_del_rechazo"):
        raise SystemExit("FAIL: el rechazo no explica el motivo")
print("  rechazos registrados: " + repr(longitudes))
PY
echo "PASS V1/AC1: el request_id rechazado no se copia; solo su longitud y el motivo."

# AC2: un identificador valido conserva la correlacion exigida por RNF-22.
python3 - "$EVENTOS" <<'PY'
import json, os, sys

ruta = sys.argv[1]
eventos = [json.loads(l) for l in open(ruta, encoding="utf-8") if l.strip()]
con_id = [e for e in eventos if e.get("context", {}).get("request_id") == "rf15-ok-1"]
if len(con_id) < 3:
    raise SystemExit("FAIL: la correlacion request_id se perdio (%d eventos)" % len(con_id))
print("  eventos con request_id valido: %d" % len(con_id))
PY
echo "PASS V2/AC2: un request_id valido mantiene la correlacion."
echo "PASS: RNF-15 TC-045 sin fallos."
