#!/usr/bin/env bash
# RNF-15 - Los registros no deben exponer secretos.
# TC-044: una bandera sensible con su valor separado (y la forma corta -p)
# redacta el elemento siguiente en el arreglo de argumentos.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
EVENTOS="$DATA_DIR/events.jsonl"
JOBS="$DATA_DIR/jobs.json"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-044.md"
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

echo "== Job con banderas sensibles separadas =="
"$HERMES" job true -p rf15secreto3 --token rf15secreto4 --secret rf15secreto5
sleep 0.3

# AC1: cada valor que sigue a una bandera sensible se redacta.
python3 - "$EVENTOS" <<'PY'
import json, os, sys

ruta = sys.argv[1]
texto = open(ruta, encoding="utf-8").read() if os.path.exists(ruta) else ""
for secreto in ("rf15secreto3", "rf15secreto4", "rf15secreto5"):
    if secreto in texto:
        raise SystemExit("FAIL: la bitacora expone %s" % secreto)

eventos = [json.loads(l) for l in texto.splitlines() if l.strip()]
recibidos = [e for e in eventos if e.get("message") == "Job recibido"]
if len(recibidos) != 1:
    raise SystemExit("FAIL: se esperaba un evento 'Job recibido' y hay %d" % len(recibidos))

esperado = ["-p", "[REDACTED]", "--token", "[REDACTED]", "--secret", "[REDACTED]"]
argumentos = recibidos[0].get("context", {}).get("argumentos")
if argumentos != esperado:
    raise SystemExit("FAIL: se esperaba %r y llego %r" % (esperado, argumentos))
print("  argumentos en bitacora: " + repr(argumentos))
PY
echo "PASS V1/AC1: el valor posterior a una bandera sensible se redacta."

# AC2: la bandera y el orden se conservan; el resto del arreglo no se toca.
python3 - "$JOBS" <<'PY'
import json, sys

datos = json.load(open(sys.argv[1], encoding="utf-8"))
trabajos = datos if isinstance(datos, list) else datos.get("jobs", [])
if len(trabajos) != 1:
    raise SystemExit("FAIL: se esperaba un Job persistido")
argumentos = trabajos[0].get("argumentos", [])
esperado = ["-p", "rf15secreto3", "--token", "rf15secreto4", "--secret", "rf15secreto5"]
if argumentos != esperado:
    raise SystemExit("FAIL: jobs.json altero los argumentos: " + repr(argumentos))
print("  argumentos persistidos: " + repr(argumentos))
PY
echo "PASS V2/AC2: la ejecucion conserva los valores reales."
echo "PASS: RNF-15 TC-044 sin fallos."
