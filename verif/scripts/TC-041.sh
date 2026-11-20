#!/usr/bin/env bash
# RNF-14 - Validacion de longitud y formato de mensajes de red.
# TC-041: el cliente rechaza con un mensaje claro toda respuesta mal formada
# (sin delimitador, excesiva, con NUL, version distinta, sobre incoherente o
# JSON roto) sin filtrar excepciones crudas.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45852
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
CONF_DIR="$HOME/.config/hermes"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-041.md"
mkdir -p "$CONF_DIR" "$RESULTS_DIR"

cat >"$CONF_DIR/config.json" <<JSON
{
  "interfaz": "127.0.0.1",
  "puerto": $PUERTO,
  "redes_permitidas": ["127.0.0.0/8"],
  "trabajos_maximos": 4,
  "max_cola": 5
}
JSON

{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '```text\n'
} >>"$RESULTS_FILE"
exec > >(tee -a "$RESULTS_FILE") 2>&1

SERVIDOR_PID=""
cleanup() {
    if [[ -n "$SERVIDOR_PID" ]] && kill -0 "$SERVIDOR_PID" 2>/dev/null; then
        kill "$SERVIDOR_PID" 2>/dev/null || true
        wait "$SERVIDOR_PID" 2>/dev/null || true
    fi
    rm -rf "$TEST_ROOT"
    printf '```\n'
}
trap cleanup EXIT

if [[ ! -x "$HERMES" ]]; then
    echo "FAIL: no existe $HERMES. Compila Hermes antes de ejecutar la prueba."
    exit 1
fi

cat >"$TEST_ROOT/servidor_falso.py" <<'PY'
import json, socket, sys

puerto = int(sys.argv[1])
listo = sys.argv[2]
escenarios = sys.argv[3:]


def respuesta(escenario, rid):
    if escenario == "sin_delimitador":
        return json.dumps({"version": 1, "request_id": rid, "ok": True, "result": {}}).encode()
    if escenario == "excesiva":
        return b"x" * 262200
    if escenario == "nulo":
        return ('{"version":1,"request_id":"%s","ok":true,"result":{}}\x00\n' % rid).encode()
    if escenario == "version":
        return ('{"version":2,"request_id":"%s","ok":true,"result":{}}\n' % rid).encode()
    if escenario == "sin_result":
        return ('{"version":1,"request_id":"%s","ok":true}\n' % rid).encode()
    if escenario == "sin_error":
        return ('{"version":1,"request_id":"%s","ok":false}\n' % rid).encode()
    if escenario == "json_roto":
        return b"{esto no es json}\n"
    raise SystemExit("escenario desconocido: " + escenario)


with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as servidor:
    servidor.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    servidor.bind(("127.0.0.1", puerto))
    servidor.listen(8)
    with open(listo, "w", encoding="utf-8") as marca:
        marca.write("listo")
    for escenario in escenarios:
        conexion, _ = servidor.accept()
        with conexion:
            datos = b""
            while b"\n" not in datos:
                trozo = conexion.recv(4096)
                if not trozo:
                    break
                datos += trozo
            try:
                rid = json.loads(datos.split(b"\n")[0]).get("request_id", "")
            except Exception:
                rid = ""
            conexion.sendall(respuesta(escenario, rid))
PY

ESCENARIOS=(sin_delimitador excesiva nulo version sin_result sin_error json_roto)
ESPERADO=(
    "cerró o rechazó la conexión"
    "Respuesta demasiado grande"
    "byte nulo"
    "version ausente o distinta de 1"
    "result ausente o no es objeto"
    "error ausente o vacío"
    "Respuesta inválida del servidor"
)

python3 "$TEST_ROOT/servidor_falso.py" "$PUERTO" "$TEST_ROOT/listo" "${ESCENARIOS[@]}" &
SERVIDOR_PID=$!
for _ in $(seq 1 100); do
    [[ -f "$TEST_ROOT/listo" ]] && break
    sleep 0.1
done
if [[ ! -f "$TEST_ROOT/listo" ]]; then
    echo "FAIL: el servidor falso no arrancó en el puerto $PUERTO."
    exit 1
fi

CLIENTE_LOG="$TEST_ROOT/cliente.log"
: >"$CLIENTE_LOG"

# AC1: cada respuesta mal formada produce un mensaje claro y un fallo del CLI.
for indice in "${!ESCENARIOS[@]}"; do
    escenario="${ESCENARIOS[$indice]}"
    esperado="${ESPERADO[$indice]}"
    estado=0
    salida="$("$HERMES" red job 127.0.0.1 true 2>&1)" || estado=$?
    printf '%s\n' "$salida" >>"$CLIENTE_LOG"
    if [[ "$estado" -eq 0 ]]; then
        echo "FAIL ($escenario): el cliente aceptó una respuesta inválida."
        exit 1
    fi
    if [[ "$salida" != *"$esperado"* ]]; then
        echo "FAIL ($escenario): se esperaba '$esperado'."
        echo "  salida: $salida"
        exit 1
    fi
    printf '  %-16s -> %s\n' "$escenario" "$salida"
done
echo "PASS V1/AC1: las siete respuestas inválidas se rechazan con diagnóstico claro."

# AC2: ninguna excepción cruda de JSON llega al usuario.
if grep -qE 'json\.exception|type_error|\[json' "$CLIENTE_LOG"; then
    echo "FAIL: se filtró una excepción cruda de JSON al usuario."
    cat "$CLIENTE_LOG"
    exit 1
fi
echo "PASS V2/AC2: ninguna excepción cruda de JSON llega al usuario."
echo "PASS: RNF-14 TC-041 sin fallos."
