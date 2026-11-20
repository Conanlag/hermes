#!/usr/bin/env bash
# RF-28 - Coherencia de estado tras desconexion.
# TC-037: un mensaje parcial cortado antes del salto de linea no produjo ningun
# efecto (jobs.json intacto) y queda documentado como SIN_EFECTO, siempre y sin
# ventana de 60 s, porque la solicitud ya habia empezado a recibirse.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
PUERTO=45832
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
CONF_DIR="$HOME/.config/hermes"
JOBS="$DATA_DIR/jobs.json"
EVENTOS="$DATA_DIR/events.jsonl"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-037.md"
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
        echo "FAIL: el servicio terminó tras la desconexión."
        cat "$TEST_ROOT/server.log"
        exit 1
    fi
}

ESTADO_ANTES="ausente"
if [[ -f "$JOBS" ]]; then
    ESTADO_ANTES="$(sha256sum "$JOBS" | awk '{print $1}')"
fi
echo "Estado de jobs.json antes: $ESTADO_ANTES"

# Tres mensajes parciales cortados antes del salto de línea.
python3 - "$PUERTO" <<'PY'
import socket, sys
puerto = int(sys.argv[1])
for intento in range(1, 4):
    s = socket.create_connection(("127.0.0.1", puerto), timeout=5)
    s.sendall(('{"version": 1, "request_id": "tc037-%d", "operation": "submit"' % intento).encode())
    s.shutdown(socket.SHUT_WR)
    s.settimeout(5)
    try:
        while s.recv(4096):
            pass
    except OSError:
        pass
    s.close()
PY
comprobar_servicio_vivo
sleep 0.3

# AC1: sin efecto, jobs.json no cambió ni un byte.
ESTADO_DESPUES="ausente"
if [[ -f "$JOBS" ]]; then
    ESTADO_DESPUES="$(sha256sum "$JOBS" | awk '{print $1}')"
fi
if [[ "$ESTADO_ANTES" != "$ESTADO_DESPUES" ]]; then
    echo "FAIL: jobs.json cambió tras mensajes parciales (${ESTADO_ANTES} -> ${ESTADO_DESPUES})."
    exit 1
fi
echo "PASS V1/AC1: jobs.json intacto; el mensaje incompleto no tuvo efecto."

# AC2: tres solicitudes iniciadas, tres registros SIN_EFECTO (sin ventana).
python3 - "$EVENTOS" <<'PY'
import json, os, sys
ruta = sys.argv[1]
lineas = []
if os.path.exists(ruta):
    with open(ruta, encoding="utf-8") as archivo:
        for linea in archivo:
            linea = linea.strip()
            if linea:
                lineas.append(json.loads(linea))
interrumpidas = [e for e in lineas if e.get("message") == "Solicitud interrumpida"]
if len(interrumpidas) != 3:
    raise SystemExit("FAIL: se esperaban 3 registros SIN_EFECTO y hay %d" % len(interrumpidas))
for entrada in interrumpidas:
    contexto = entrada.get("context", {})
    if contexto.get("resultado") != "SIN_EFECTO":
        raise SystemExit("FAIL: desenlace inesperado: " + repr(contexto.get("resultado")))
    if contexto.get("motivo") != "FIN_SIN_MENSAJE":
        raise SystemExit("FAIL: motivo inesperado: " + repr(contexto.get("motivo")))
    if not contexto.get("bytes_recibidos"):
        raise SystemExit("FAIL: no se documentaron los bytes recibidos")
    if "job_id" in contexto:
        raise SystemExit("FAIL: un mensaje parcial no puede tener job_id")
ruido = [e for e in lineas if e.get("message") == "Cliente desconectado"]
if ruido:
    raise SystemExit("FAIL: una solicitud iniciada quedó reducida a ruido previo al protocolo")
print("  registros: " + json.dumps(interrumpidas[-1], ensure_ascii=False))
PY
echo "PASS V2/AC2: tres solicitudes iniciadas, tres registros SIN_EFECTO sin ventana."

# AC3: el servicio sigue atendiendo.
python3 - "$PUERTO" <<'PY'
import json, socket, sys
puerto = int(sys.argv[1])
with socket.create_connection(("127.0.0.1", puerto), timeout=5) as s:
    s.sendall((json.dumps({"version": 1, "request_id": "tc037-ping", "operation": "ping", "params": {}}) + "\n").encode())
    datos = b""
    while b"\n" not in datos:
        trozo = s.recv(4096)
        if not trozo:
            raise SystemExit("FAIL: el servidor cerró sin responder el ping")
        datos += trozo
if not json.loads(datos.split(b"\n")[0]).get("ok"):
    raise SystemExit("FAIL: ping posterior falló")
PY
echo "PASS V3/AC3: ping posterior correcto; el servicio sigue atendiendo."
echo "PASS: RF-28 TC-037 sin fallos."
