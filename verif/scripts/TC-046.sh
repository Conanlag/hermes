#!/usr/bin/env bash
# RNF-15 - Los registros no deben exponer secretos.
# TC-046: un config.json mal formado se reporta sin copiar su contenido ni el
# texto interno del parser JSON.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
CONF_DIR="$HOME/.config/hermes"
DATA_DIR="$HOME/.local/share/hermes/data"
EVENTOS="$DATA_DIR/events.jsonl"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-046.md"
mkdir -p "$CONF_DIR" "$DATA_DIR" "$RESULTS_DIR"

cat >"$CONF_DIR/config.json" <<'JSON'
{"trabajos_maximos": 3, "comentario": "rf15secreto7"
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

echo "== Carga de config.json corrupto =="
# 'red job' lee config.json antes de conectar; la conexion falla porque el
# puerto vuelve al valor por defecto, pero la advertencia ya quedo registrada.
"$HERMES" red job 127.0.0.1 true >/dev/null 2>&1 || true
sleep 0.2

# AC1: la advertencia cita el archivo y una causa controlada, sin contenido.
python3 - "$EVENTOS" <<'PY'
import json, os, sys

ruta = sys.argv[1]
texto = open(ruta, encoding="utf-8").read() if os.path.exists(ruta) else ""
if "rf15secreto7" in texto:
    raise SystemExit("FAIL: la bitacora copio el contenido de config.json")
if "[json." in texto or "parse error" in texto:
    raise SystemExit("FAIL: la bitacora copio el texto del parser JSON")

eventos = [json.loads(l) for l in texto.splitlines() if l.strip()]
avisos = [e for e in eventos if e.get("message", "").startswith("Error al parsear config.json")]
if len(avisos) != 1:
    raise SystemExit("FAIL: se esperaba una advertencia de parseo y hay %d" % len(avisos))
contexto = avisos[0].get("context", {})
if contexto.get("detalle") != "JSON mal formado":
    raise SystemExit("FAIL: detalle inesperado: " + repr(contexto.get("detalle")))
if not contexto.get("archivo"):
    raise SystemExit("FAIL: la advertencia no identifica el archivo")
print("  advertencia: " + json.dumps(contexto, ensure_ascii=False))
PY
echo "PASS V1/AC1: la advertencia de config.json no expone su contenido."

# AC2: la actualizacion falla con un mensaje controlado.
SALIDA="$("$HERMES" configmax 6 2>&1)" && ESTADO=0 || ESTADO=$?
if [[ $ESTADO -eq 0 ]]; then
    echo "FAIL: configmax acepto un config.json corrupto."
    echo "$SALIDA"
    exit 1
fi
printf '%s\n' "$SALIDA"
if [[ "$SALIDA" != *"No se pudo interpretar config.json: JSON mal formado"* ]]; then
    echo "FAIL: mensaje de error inesperado."
    exit 1
fi
if [[ "$SALIDA" == *"rf15secreto7"* || "$SALIDA" == *"[json."* ]]; then
    echo "FAIL: el error de configuracion expone contenido del archivo."
    exit 1
fi
echo "PASS V2/AC2: la actualizacion falla con un mensaje controlado."
echo "PASS: RNF-15 TC-046 sin fallos."
