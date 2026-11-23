#!/usr/bin/env bash
# RNF-15 - Los registros no deben exponer secretos.
# TC-047: los errores de network.json citan la clave y la regla incumplida,
# nunca el valor de configuracion ni fragmentos del archivo.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45854
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
CONF_DIR="$HOME/.config/hermes"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
EVENTOS="$DATA_DIR/events.jsonl"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-047.md"
mkdir -p "$CONF_DIR" "$NET_DIR" "$DATA_DIR" "$RESULTS_DIR"

cat >"$CONF_DIR/config.json" <<JSON
{
  "interfaz": "127.0.0.1",
  "puerto": $PUERTO,
  "redes_permitidas": ["127.0.0.0/8"]
}
JSON

{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '```text\n'
} >>"$RESULTS_FILE"
exec > >(tee -a "$RESULTS_FILE") 2>&1

cleanup() {
    rm -rf "$TEST_ROOT"
    printf '```\n'
}
trap cleanup EXIT

if [[ ! -x "$HERMES" ]]; then
    echo "FAIL: no existe $HERMES. Compila Hermes antes de ejecutar la prueba."
    exit 1
fi

comprobar() {
    local etiqueta="$1"
    local esperado="$2"
    local prohibido="$3"
    local salida estado
    salida="$("$HERMES" red start 2>&1)" && estado=0 || estado=$?
    printf '%s\n' "$salida"
    if [[ $estado -eq 0 ]]; then
        echo "FAIL ($etiqueta): red start acepto una configuracion invalida."
        exit 1
    fi
    if [[ "$salida" != *"$esperado"* ]]; then
        echo "FAIL ($etiqueta): no se cito '$esperado'."
        exit 1
    fi
    if [[ "$salida" == *"$prohibido"* ]]; then
        echo "FAIL ($etiqueta): el diagnostico expone el valor sensible."
        exit 1
    fi
    if [[ "$salida" == *"json.exception"* || "$salida" == *"parse error"* ]]; then
        echo "FAIL ($etiqueta): el diagnostico expone el parser JSON."
        exit 1
    fi
    echo "  $etiqueta -> cito la regla y no el valor"
}

echo "== network.json con tls =="
cat >"$NET_DIR/network.json" <<'JSON'
{
  "habilitada": true,
  "tls": "rf15secreto8",
  "clientes": []
}
JSON
comprobar "tls" "tls" "rf15secreto8"
echo "PASS V1/AC1: la clave tls se cita sin su valor."

echo "== network.json con sha256 por cliente =="
cat >"$NET_DIR/network.json" <<'JSON'
{
  "habilitada": true,
  "clientes": [
    {
      "id": "PC-B",
      "sha256": "rf15secreto9",
      "direcciones": ["127.0.0.1"],
      "operaciones": ["ping"],
      "programas": ["true"]
    }
  ]
}
JSON
comprobar "sha256" "sha256" "rf15secreto9"
echo "PASS V2/AC2: la clave sha256 se cita sin su valor."

echo "== network.json con ambito_trabajos invalido =="
cat >"$NET_DIR/network.json" <<'JSON'
{
  "habilitada": true,
  "clientes": [
    {
      "id": "PC-B",
      "ambito_trabajos": "rf15 secreto10",
      "direcciones": ["127.0.0.1"],
      "operaciones": ["ping"],
      "programas": ["true"]
    }
  ]
}
JSON
comprobar "ambito" "mbito de trabajos" "rf15 secreto10"
echo "PASS V3/AC3: el ambito invalido se reporta sin su valor."

echo "== network.json con JSON corrupto =="
cat >"$NET_DIR/network.json" <<'JSON'
{"habilitada": true, "clientes": [{"id": "rf15secreto11"
JSON
comprobar "json" "network.json no es un JSON válido" "rf15secreto11"
echo "PASS V4/AC4: el JSON corrupto se reporta sin fragmentos del archivo."

if [[ -f "$EVENTOS" ]] && grep -q -e 'rf15secreto8' -e 'rf15secreto9' -e 'rf15secreto10' -e 'rf15secreto11' "$EVENTOS"; then
    echo "FAIL: la bitacora expone un valor de network.json."
    exit 1
fi
echo "PASS V5/AC5: la bitacora no contiene valores de network.json."
echo "PASS: RNF-15 TC-047 sin fallos."
