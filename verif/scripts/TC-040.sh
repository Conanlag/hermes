#!/usr/bin/env bash
# RNF-14 - Validacion de longitud y formato de mensajes de red.
# TC-040: el cliente interpreta los sobres de error de protocolo (request_id
# nulo, que emite errorProtocolo()) y reporta el codigo real en lugar de una
# excepcion cruda de JSON.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45851
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
CONF_DIR="$HOME/.config/hermes"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-040.md"
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
import socket, sys

puerto = int(sys.argv[1])
codigos = sys.argv[3:]
listo = sys.argv[2]

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as servidor:
    servidor.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    servidor.bind(("127.0.0.1", puerto))
    servidor.listen(4)
    with open(listo, "w", encoding="utf-8") as marca:
        marca.write("listo")
    for codigo in codigos:
        conexion, _ = servidor.accept()
        with conexion:
            datos = b""
            while b"\n" not in datos:
                trozo = conexion.recv(4096)
                if not trozo:
                    break
                datos += trozo
            # Sobre exacto de errorProtocolo(): request_id nulo.
            respuesta = ('{"version":1,"request_id":null,"ok":false,"error":"%s"}\n' % codigo)
            conexion.sendall(respuesta.encode())
PY

CODIGOS=(MESSAGE_TOO_LARGE REQUEST_TIMEOUT RESPONSE_TOO_LARGE)
python3 "$TEST_ROOT/servidor_falso.py" "$PUERTO" "$TEST_ROOT/listo" "${CODIGOS[@]}" &
SERVIDOR_PID=$!
for _ in $(seq 1 100); do
    [[ -f "$TEST_ROOT/listo" ]] && break
    sleep 0.1
done
if [[ ! -f "$TEST_ROOT/listo" ]]; then
    echo "FAIL: el servidor falso no arrancó en el puerto $PUERTO."
    exit 1
fi

# AC1: cada sobre de error de protocolo llega al usuario con su codigo real.
CLIENTE_LOG="$TEST_ROOT/cliente.log"
: >"$CLIENTE_LOG"
for codigo in "${CODIGOS[@]}"; do
    estado=0
    salida="$("$HERMES" red job 127.0.0.1 true 2>&1)" || estado=$?
    printf '%s\n' "$salida" >>"$CLIENTE_LOG"
    if [[ "$estado" -eq 0 ]]; then
        echo "FAIL: el cliente devolvió éxito ante un error de protocolo ($codigo)."
        exit 1
    fi
    if [[ "$salida" != *"$codigo"* ]]; then
        echo "FAIL: el cliente no reportó el código $codigo."
        echo "  salida: $salida"
        exit 1
    fi
    echo "  cliente -> $salida"
done
echo "PASS V1/AC1: los tres errores de protocolo se reportan con su código real."

# AC2: nunca se filtra una excepción cruda de JSON al usuario.
if grep -qE 'json\.exception|type_error' "$CLIENTE_LOG"; then
    echo "FAIL: se filtró una excepción cruda de JSON al usuario."
    cat "$CLIENTE_LOG"
    exit 1
fi
echo "PASS V2/AC2: ninguna excepción cruda de JSON llega al usuario."
echo "PASS: RNF-14 TC-040 sin fallos."
