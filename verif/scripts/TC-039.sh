#!/usr/bin/env bash
# RNF-14 - Validacion de longitud y formato de mensajes de red.
# TC-039: el servidor responde con un codigo determinista ante cada formato
# invalido (JSON, UTF-8, NUL, profundidad, sobre, operacion, params y longitud)
# y documenta cada rechazo una sola vez, con la ventana de 60 s por codigo.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45850
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
CONF_DIR="$HOME/.config/hermes"
EVENTOS="$DATA_DIR/events.jsonl"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-039.md"
mkdir -p "$NET_DIR" "$CONF_DIR" "$RESULTS_DIR"

cat >"$CONF_DIR/config.json" <<JSON
{
  "interfaz": "127.0.0.1",
  "puerto": $PUERTO,
  "redes_permitidas": ["127.0.0.0/8"],
  "trabajos_maximos": 4,
  "max_cola": 5
}
JSON

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

echo "Arrancando 'hermes red start' con HOME temporal..."
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

comprobar_servicio_vivo() {
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "FAIL: el servicio terminó durante los rechazos."
        cat "$TEST_ROOT/server.log"
        exit 1
    fi
}

# AC1: cada formato invalido recibe su codigo propio, nunca uno generico.
python3 - "$PUERTO" <<'PY'
import json, socket, sys

puerto = int(sys.argv[1])


def enviar(carga):
    with socket.create_connection(("127.0.0.1", puerto), timeout=5) as s:
        s.sendall(carga)
        datos = b""
        while b"\n" not in datos:
            trozo = s.recv(4096)
            if not trozo:
                raise SystemExit("FAIL: el servidor cerró sin responder")
            datos += trozo
    return json.loads(datos.split(b"\n")[0])


def esperar(carga, codigo, etiqueta):
    respuesta = enviar(carga)
    if respuesta.get("ok") is not False or respuesta.get("error") != codigo:
        raise SystemExit("FAIL %s: se esperaba %s y llegó %r" % (etiqueta, codigo, respuesta))
    print("  %-22s -> %s" % (etiqueta, codigo))


sobre = lambda rid, op, params=None: json.dumps({
    "version": 1, "request_id": rid, "operation": op,
    "params": {} if params is None else params}).encode() + b"\n"

esperar(b"{no es json}\n", "INVALID_JSON", "json roto")
esperar(b'{"version":1,"request_id":"a","operation":"ping","params":{}}\x00\n',
        "NUL_BYTE", "byte nulo")
esperar(b'{"version":1,"request_id":"\xff","operation":"ping","params":{}}\n',
        "INVALID_UTF8", "utf-8 invalido")
esperar(b'{"version":1,"request_id":"a","operation":"ping","params":{},"extra":'
        + b"[" * 40 + b"]" * 40 + b"}\n", "TOO_DEEP", "profundidad 40")
esperar(b'{"version":1,"request_id":"a","operation":"ping","params":{},"extra":1}\n',
        "INVALID_REQUEST", "clave superior extra")
esperar(sobre("a", "x" * 40), "INVALID_OPERATION", "operacion 40 bytes")
esperar(sobre("a", "ping", {"x": 1}), "INVALID_PARAMS", "params de ping")
esperar(b"{" + b"0" * 16390 + b"}\n", "MESSAGE_TOO_LARGE", "16392 bytes")
esperar(sobre("bad id", "ping"), "INVALID_REQUEST_ID", "request_id invalido")
esperar(sobre("a", "nope"), "UNKNOWN_OPERATION", "operacion desconocida")
esperar(json.dumps({
    "version": 2,
    "request_id": "a",
    "operation": "ping",
    "params": {}
}).encode() + b"\n", "UNSUPPORTED_VERSION", "version 2")

# La ventana de 60 s se aplica por codigo: un segundo NUL_BYTE sigue
# respondiendo con su codigo real, pero no debe añadir otro evento.
esperar(b'{"version":1,"request_id":"b","operation":"ping","params":{}}\x00\n',
        "NUL_BYTE", "byte nulo (repeticion)")
PY
comprobar_servicio_vivo
sleep 0.3
echo "PASS V1/AC1: once formatos invalidos rechazados con su codigo propio."

# AC2: cada codigo se documenta exactamente una vez, con IP y bytes recibidos.
python3 - "$EVENTOS" <<'PY'
import json, os, sys

ruta = sys.argv[1]
eventos = []
if os.path.exists(ruta):
    with open(ruta, encoding="utf-8") as archivo:
        for linea in archivo:
            linea = linea.strip()
            if linea:
                eventos.append(json.loads(linea))

rechazos = [e for e in eventos if e.get("message") == "Mensaje rechazado"]
codigos = [e.get("context", {}).get("codigo") for e in rechazos]
esperados = ["MESSAGE_TOO_LARGE", "NUL_BYTE", "INVALID_UTF8", "TOO_DEEP", "INVALID_JSON",
             "INVALID_REQUEST", "INVALID_REQUEST_ID", "INVALID_OPERATION",
             "INVALID_PARAMS", "UNKNOWN_OPERATION", "UNSUPPORTED_VERSION"]

for codigo in esperados:
    if codigos.count(codigo) != 1:
        raise SystemExit("FAIL: %s registrado %d veces (se esperaba 1)"
                         % (codigo, codigos.count(codigo)))

for entrada in rechazos:
    contexto = entrada.get("context", {})
    if not contexto.get("ip"):
        raise SystemExit("FAIL: rechazo sin IP de origen: " + repr(entrada))
    if not isinstance(contexto.get("bytes_recibidos"), int) or contexto["bytes_recibidos"] < 1:
        raise SystemExit("FAIL: rechazo sin bytes recibidos: " + repr(entrada))
    if not contexto.get("motivo"):
        raise SystemExit("FAIL: rechazo sin motivo: " + repr(entrada))

interrumpidas = [e for e in eventos if e.get("message") == "Solicitud interrumpida"]
if interrumpidas:
    raise SystemExit("FAIL: el rechazo de formato se duplicó como Solicitud interrumpida")

print("  registros 'Mensaje rechazado': %d de %d códigos, sin duplicados"
      % (len(rechazos), len(esperados)))
print("  ejemplo: " + json.dumps(rechazos[-1], ensure_ascii=False))
PY
echo "PASS V2/AC2: un evento por código, con IP, motivo y bytes recibidos."

# AC3: el servicio sigue atendiendo solicitudes validas.
python3 - "$PUERTO" <<'PY'
import json, socket, sys

puerto = int(sys.argv[1])
with socket.create_connection(("127.0.0.1", puerto), timeout=5) as s:
    s.sendall((json.dumps({"version": 1, "request_id": "tc039-ping",
                           "operation": "ping", "params": {}}) + "\n").encode())
    datos = b""
    while b"\n" not in datos:
        trozo = s.recv(4096)
        if not trozo:
            raise SystemExit("FAIL: el servidor cerró sin responder el ping")
        datos += trozo
respuesta = json.loads(datos.split(b"\n")[0])
if respuesta.get("ok") is not True or respuesta.get("request_id") != "tc039-ping":
    raise SystemExit("FAIL: ping posterior incorrecto: " + repr(respuesta))
PY
echo "PASS V3/AC3: ping posterior correcto; el servicio sigue atendiendo."
echo "PASS: RNF-14 TC-039 sin fallos."
