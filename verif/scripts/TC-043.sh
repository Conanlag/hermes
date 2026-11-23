#!/usr/bin/env bash
# RNF-15 - Los registros no deben exponer secretos.
# TC-043: una asignacion sensible en los argumentos de un Job se redacta en la
# bitacora, pero el valor real se conserva para la ejecucion y en jobs.json.
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
RESULTS_FILE="$RESULTS_DIR/results_TC-043.md"
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

echo "== Job con asignaciones sensibles =="
"$HERMES" job true --password=rf15secreto1 --api-key=rf15secreto2
sleep 0.3

# AC1: la bitacora redacta el valor y conserva el nombre de la clave.
python3 - "$EVENTOS" <<'PY'
import json, os, sys

ruta = sys.argv[1]
texto = open(ruta, encoding="utf-8").read() if os.path.exists(ruta) else ""
for secreto in ("rf15secreto1", "rf15secreto2"):
    if secreto in texto:
        raise SystemExit("FAIL: la bitacora expone %s" % secreto)

eventos = [json.loads(l) for l in texto.splitlines() if l.strip()]
recibidos = [e for e in eventos if e.get("message") == "Job recibido"]
if len(recibidos) != 1:
    raise SystemExit("FAIL: se esperaba un evento 'Job recibido' y hay %d" % len(recibidos))

contexto = recibidos[0].get("context", {})
if contexto.get("argumentos") != ["--password=[REDACTED]", "--api-key=[REDACTED]"]:
    raise SystemExit("FAIL: argumentos redactados incorrectos: " + repr(contexto.get("argumentos")))
if contexto.get("programa") != "true":
    raise SystemExit("FAIL: el programa cambio: " + repr(contexto.get("programa")))
if recibidos[0].get("job_id") != "1":
    raise SystemExit("FAIL: se perdio la correlacion job_id")
print("  argumentos en bitacora: " + repr(contexto["argumentos"]))
PY
echo "PASS V1/AC1: las asignaciones sensibles se redactan en events.jsonl."

# AC2: la ejecucion no se altera; jobs.json conserva el valor real.
python3 - "$JOBS" <<'PY'
import json, sys

datos = json.load(open(sys.argv[1], encoding="utf-8"))
trabajos = datos if isinstance(datos, list) else datos.get("jobs", [])
if len(trabajos) != 1:
    raise SystemExit("FAIL: se esperaba un Job persistido")
argumentos = trabajos[0].get("argumentos", [])
if argumentos != ["--password=rf15secreto1", "--api-key=rf15secreto2"]:
    raise SystemExit("FAIL: jobs.json altero los argumentos: " + repr(argumentos))
print("  argumentos persistidos: " + repr(argumentos))
PY
echo "PASS V2/AC2: jobs.json conserva los argumentos reales del Job."
echo "PASS: RNF-15 TC-043 sin fallos."
