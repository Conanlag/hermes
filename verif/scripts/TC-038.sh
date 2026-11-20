#!/usr/bin/env bash
# RF-28 - Coherencia de estado tras desconexion.
# TC-038: N solicitudes ya procesadas cuya respuesta se pierde dejan N registros.
# Es el contraste exacto con TC-033: la ventana de 60 s amortigua el ruido previo
# al protocolo, nunca el desenlace de operaciones que sí se tramitaron.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45833
N=20
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
CONF_DIR="$HOME/.config/hermes"
EVENTOS="$DATA_DIR/events.jsonl"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-038.md"
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
        echo "FAIL: el servicio terminó tras las desconexiones."
        cat "$TEST_ROOT/server.log"
        exit 1
    fi
}

# N solicitudes procesadas (ping) con RST inmediato: la respuesta se pierde.
python3 - "$PUERTO" "$N" <<'PY'
import json, socket, struct, sys
puerto, total = int(sys.argv[1]), int(sys.argv[2])
for intento in range(1, total + 1):
    s = socket.create_connection(("127.0.0.1", puerto), timeout=5)
    carga = json.dumps({"version": 1, "request_id": "tc038-%02d" % intento,
                        "operation": "ping", "params": {}}) + "\n"
    s.sendall(carga.encode())
    s.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
    s.close()
PY
comprobar_servicio_vivo
sleep 0.5

# AC1: una entrada por solicitud procesada, todas ACEPTADA, sin ventana.
python3 - "$EVENTOS" "$N" <<'PY'
import json, os, sys
ruta, total = sys.argv[1], int(sys.argv[2])
lineas = []
if os.path.exists(ruta):
    with open(ruta, encoding="utf-8") as archivo:
        for linea in archivo:
            linea = linea.strip()
            if linea:
                lineas.append(json.loads(linea))
interrumpidas = [e for e in lineas if e.get("message") == "Solicitud interrumpida"]
print("  registros de solicitud interrumpida: %d de %d conexiones" % (len(interrumpidas), total))
if len(interrumpidas) != total:
    raise SystemExit("FAIL: la ventana de 60 s silenció solicitudes ya procesadas (%d de %d)"
                     % (len(interrumpidas), total))
for entrada in interrumpidas:
    contexto = entrada.get("context", {})
    if contexto.get("resultado") != "ACEPTADA":
        raise SystemExit("FAIL: desenlace inesperado: " + repr(contexto.get("resultado")))
    if contexto.get("operacion") != "ping":
        raise SystemExit("FAIL: operación inesperada: " + repr(contexto.get("operacion")))
    if not str(contexto.get("request_id", "")).startswith("tc038-"):
        raise SystemExit("FAIL: request_id inesperado: " + repr(contexto.get("request_id")))
ruido = [e for e in lineas if e.get("message") == "Cliente desconectado"]
if ruido:
    raise SystemExit("FAIL: una respuesta perdida se registró como ruido previo al protocolo")
print("  muestra: " + json.dumps(interrumpidas[-1], ensure_ascii=False))
PY
echo "PASS V1/AC1: $N solicitudes procesadas, $N registros; la ventana no aplica."

# AC2: el servicio sigue atendiendo.
python3 - "$PUERTO" <<'PY'
import json, socket, sys
puerto = int(sys.argv[1])
with socket.create_connection(("127.0.0.1", puerto), timeout=5) as s:
    s.sendall((json.dumps({"version": 1, "request_id": "tc038-ping", "operation": "ping", "params": {}}) + "\n").encode())
    datos = b""
    while b"\n" not in datos:
        trozo = s.recv(4096)
        if not trozo:
            raise SystemExit("FAIL: el servidor cerró sin responder el ping")
        datos += trozo
if not json.loads(datos.split(b"\n")[0]).get("ok"):
    raise SystemExit("FAIL: ping posterior falló")
PY
echo "PASS V2/AC2: ping posterior correcto; el servicio sigue atendiendo."
echo "PASS: RF-28 TC-038 sin fallos."
