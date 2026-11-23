#!/usr/bin/env bash
# RNF-15 - Los registros no deben exponer secretos.
# TC-048: un jobs.json corrupto detectado al arrancar el scheduler se reporta
# con una causa controlada, sin fragmentos del archivo ni texto del parser.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
EVENTOS="$DATA_DIR/events.jsonl"
JOBS="$DATA_DIR/jobs.json"
RESPALDO="$DATA_DIR/jobs.json.bak"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-048.md"
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

echo "== Preparacion de jobs.json y su respaldo corruptos =="
"$HERMES" status >/dev/null 2>&1 || true
printf '{"job_id": 1, "secreto": "rf15secreto12"' >"$JOBS"
cp "$JOBS" "$RESPALDO"

echo "== Arranque del scheduler con estado corrupto =="
SALIDA="$("$HERMES" filter list 2>&1)" && ESTADO=0 || ESTADO=$?
printf '%s\n' "$SALIDA"
if [[ $ESTADO -eq 0 ]]; then
    echo "FAIL: el arranque no se detuvo ante un estado irrecuperable."
    exit 1
fi

# AC1: la bitacora clasifica la causa sin copiar el archivo ni el parser.
python3 - "$EVENTOS" <<'PY'
import json, os, sys

ruta = sys.argv[1]
texto = open(ruta, encoding="utf-8").read() if os.path.exists(ruta) else ""
if "rf15secreto12" in texto:
    raise SystemExit("FAIL: la bitacora copio el contenido de jobs.json")
if "[json." in texto or "parse error" in texto or "syntax error" in texto:
    raise SystemExit("FAIL: la bitacora copio el texto del parser JSON")

eventos = [json.loads(l) for l in texto.splitlines() if l.strip()]
daemon = [e for e in eventos if e.get("message") == "Error interno del daemon"]
if not daemon:
    raise SystemExit("FAIL: no se registro el error del daemon")
detalle = daemon[0].get("context", {}).get("detalle")
if detalle != "excepcion de formato JSON (detalle omitido)":
    raise SystemExit("FAIL: detalle inesperado: " + repr(detalle))
print("  detalle registrado: " + repr(detalle))
PY
echo "PASS V1/AC1: el error de arranque no expone jobs.json ni el parser."

# AC2: el operador recibe un mensaje controlado por stderr.
if [[ "$SALIDA" == *"rf15secreto12"* || "$SALIDA" == *"json.exception"* ]]; then
    echo "FAIL: el diagnostico de consola expone contenido del archivo."
    exit 1
fi
if [[ "$SALIDA" != *"No se pudo iniciar el scheduler"* ]]; then
    echo "FAIL: mensaje de consola inesperado."
    exit 1
fi
echo "PASS V2/AC2: la consola informa el fallo con un mensaje controlado."
echo "PASS: RNF-15 TC-048 sin fallos."
