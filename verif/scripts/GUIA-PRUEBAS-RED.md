# Guía base para las pruebas de red de Hermes

> Documento normativo para los scripts `TC-0NN.sh` del subsistema de red. Describe el contrato
> mínimo que debe cumplir todo caso nuevo: modelo de ejecución, ciclo de vida, aislamiento, patrones
> reutilizables y convenciones de evidencia y trazabilidad.
>
> Aplica a los casos nuevos a partir de `TC-057`. Los casos `TC-030` a `TC-056` ya implementan la
> mayor parte de estos patrones, pero conservan dos diferencias históricas: usan puertos fijos y
> devuelven `1` para cualquier error. Esta guía no obliga a reescribirlos; sí obliga a que los casos
> nuevos sigan el contrato completo.

---

## 0. Alcance y reglas generales

**Cubre:** pruebas de integración del subsistema de red: CLI remoto (`red job`, `red filter`,
`red cancel`), protocolo TCP con delimitador `\n`, ciclo de vida del servidor, control de acceso,
límites de mensaje, coherencia de estado ante desconexión, redacción de secretos y comportamiento
del cliente contra servidores reales o falsos.

**No cubre:** pruebas unitarias de `access.cpp` o `protocol.cpp` (para eso existen las pruebas de
compilación y los casos de diseño), rendimiento, cifrado (no existe) ni autenticación
criptográfica (no existe; la identidad es la IP observada).

**Fuentes normativas**, en este orden:

1. `docs/technical-guide/2-Nucleo del proyecto/CONTEXTO-RED-ACTUAL.md` (§1.2, §3, §4, §5, §6.8 y §7.7).
2. `docs/user-guide/red-wsl-pc-a-pc-b.md` (topología real PC-A/PC-B con `netsh interface portproxy`).
3. Las fichas RF/RNF del requisito que se prueba.
4. Los scripts `TC-030` a `TC-056` como referencia de implementación.

**Reglas duras:**

- Una prueba **no modifica `src/`** para pasar. Si revela un defecto, se documenta el defecto y el
  caso queda `FAIL` o `PENDIENTE`; no se ajusta el código de producción dentro del caso.
- Una prueba **no toca el `HOME` real** ni los enlaces `src/hermes/data`, `src/hermes/config` o
  `src/hermes/network` del repositorio. Todo se ejecuta con `HOME` y `XDG_CONFIG_HOME` temporales.
- Una prueba **no mata procesos que no inició**. Nunca usar `pkill -f hermes` ni `killall hermes`.
- Una prueba **no reutiliza un puerto ocupado** ni asume que el puerto por defecto `45820` está libre.
- Una prueba **no deja procesos, sockets ni archivos temporales** al terminar, ni siquiera cuando falla.

---

## 1. Modelo de ejecución dual

Cada caso declara en su cabecera uno de tres modos: `local`, `remoto` o `ambos`. El modo cambia qué
validaciones son legítimas, no la lógica del caso.

### 1.1 Modo local (el script es dueño del servidor)

El script crea un `HOME` temporal, escribe `config.json` y `network.json`, elige un puerto libre,
lanza `hermes red start` en segundo plano, espera activamente a que escuche, ejecuta las
comprobaciones y limpia todo. Es el modo por defecto y el único que permite validar el lado servidor.

Puede y **debe** comprobar:

- `jobs.json` íntegro y con estados válidos.
- `events.jsonl`: desenlaces `ACEPTADA`, `RECHAZADA`, `SIN_EFECTO`, motivos y códigos.
- `/proc/<pid>/fd` para localizar el scheduler por `scheduler.lock`.
- `SIGTERM` al servidor, salida ordenada, cierre de la escucha y liberación del puerto.
- Ausencia de procesos huérfanos que hereden el `HOME` temporal.
- Rechazos de arranque por `config.json` o `network.json` inválidos.
- Control de acceso por IP/CIDR, cupo de 32 clientes y autorización por operación/programa.

### 1.2 Modo remoto (PC-A servidor, PC-B cliente)

El script corre en PC-B (o en cualquier host con el binario) y apunta a un servidor que **no
inicia**. Usa `HERMES_TEST_HOST` y `HERMES_TEST_PORT`. No escribe `network.json`, no lanza
`red start`, no envía señales al servidor y no lee archivos de PC-A.

Puede comprobar:

- Códigos de salida y mensajes del CLI (`red job`, `red filter`, `red cancel`).
- Respuestas JSON sobre un socket propio, framing y tiempos.
- Comportamiento del cliente ante errores de protocolo, respuestas inválidas y cortes.
- Paginación y reintento de solo lectura de `red filter`.

**No puede** comprobar (y debe marcar `SKIP` explícito):

- `/proc`, `SIGTERM`, liberación del puerto, huérfanos o logs del servidor.
- `jobs.json` y `events.jsonl` del servidor, salvo que el operador comparta el sistema de archivos
  de PC-A y el script lo declare en su ficha. En ese caso se documenta como variante, no como modo
  remoto estándar.
- CIDR de origen, cupo de 32 o rechazos de arranque. El origen que observa PC-A es el gateway de
  WSL o el host Windows del `portproxy`, no la IP LAN de PC-B
  (`red-wsl-pc-a-pc-b.md` §1); el script no puede inferirlo y no debe intentarlo.

Una comprobación de servidor omitida por el modo **no es un PASS**. El script imprime
`SKIP: <comprobación> (modo remoto)` y termina con código `3` si alguna comprobación requerida quedó
omitida.

### 1.3 Variables de entorno

| Variable | Obligatoria | Valor por defecto | Efecto |
| --- | --- | --- | --- |
| `HERMES_TEST_HOST` | No | `127.0.0.1` | Destino del cliente y de los sockets crudos. Si no es loopback, activa el modo remoto. |
| `HERMES_TEST_PORT` | Sí en modo remoto | Puerto libre elegido por el script en modo local | Puerto del servidor (local) o del destino (remoto). |
| `HERMES_TEST_CLIENT_ID` | No | `PC-B` | `id` del registro en `clientes[]` en modo local; etiqueta del registro esperado en modo remoto. |

Reglas:

- `HERMES_TEST_HOST` acepta `localhost` o `127.0.0.1` como loopback. Cualquier otra dirección activa
  el modo remoto.
- En modo remoto, el destino debe pasar `reglaRedValida()`: loopback, RFC1918 o `100.64.0.0/10`
  (RNF-26). Una IP pública se rechaza localmente en el cliente y no sirve para la demostración.
- En modo remoto, `HERMES_TEST_PORT` se escribe en el `config.json` temporal porque el CLI **no
  recibe el puerto por argumento**: `client.cpp` lo lee de `cargarConfiguracion().puerto`. Sin ese
  archivo, el cliente usaría `45820` y la prueba apuntaría al puerto equivocado.
- `HERMES_TEST_CLIENT_ID` debe cumplir `validarRequestId()`: 1 a 128 caracteres de
  `[A-Za-z0-9._:-]`. En modo local se escribe literalmente en `clientes[].id`.

Ejemplos:

```bash
# Modo local autocontenido, puerto elegido por el script.
bash verif/scripts/TC-057.sh

# Modo local con puerto reservado y verificado libre.
HERMES_TEST_PORT=45864 bash verif/scripts/TC-057.sh

# Modo remoto: PC-B contra la IP LAN de Windows de PC-A.
HERMES_TEST_HOST=192.168.1.74 HERMES_TEST_PORT=45820 \
  HERMES_TEST_CLIENT_ID=pc-b-via-windows bash verif/scripts/TC-057.sh
```

### 1.4 Matriz de validaciones por modo

| Validación | Local | Remoto | Cómo se obtiene |
| --- | --- | --- | --- |
| Códigos de salida y mensajes del CLI | Sí | Sí | Ejecutar el binario y capturar `stdout`/`stderr` |
| Protocolo crudo (sobres, framing, límites) | Sí | Sí | Socket Python contra `HOST:PUERTO` |
| `jobs.json` íntegro y estados | Sí | No | Leer `$HOME/.local/share/hermes/data/jobs.json` |
| Desenlaces en `events.jsonl` | Sí | No | Leer `$HOME/.local/share/hermes/data/events.jsonl` |
| `/proc`, `SIGTERM`, puerto liberado, huérfanos | Sí | No | PID propio y `/proc` |
| CIDR de origen, cupo de 32, autorización | Sí | No | `config.json`/`network.json` propios |
| Rechazo de arranque por configuración inválida | Sí | No | `red start` termina con código 1 |
| Paginación y reintento del cliente | Sí | Sí | Servidor real o falso, en cualquier host |
| Log de arranque y de parada (`Hermes Red escuchando en`, `Hermes Red detenido`) | Sí | No | `server.log` temporal |

Convención de la ficha: cada criterio de aceptación se etiqueta `[local]`, `[remoto]` o `[ambos]`.
El script decide con esa etiqueta y con el modo detectado.

---

## 2. Ciclo de vida obligatorio del script

### 2.1 Cabecera y metadatos

```bash
#!/usr/bin/env bash
# <RF|RNF>-<NN> - <título corto del requisito>.
# TC-0NN: <qué demuestra, en una frase>.
# Modo: local | remoto | ambos.
set -euo pipefail
umask 077

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
TC="TC-0NN"
EVIDENCIA="$REPO/verif/results/results_${TC}.md"
```

- `set -euo pipefail` es obligatorio: un fallo intermedio no puede quedar silenciado.
- `umask 077` evita que archivos temporales con secretos queden legibles por otros usuarios.
- No usar `cd` global. Resolver rutas absolutas con `REPO`.

### 2.2 Aislamiento: `HOME`, `XDG_CONFIG_HOME` y directorio temporal

```bash
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hermes-${TC}.XXXXXX")"
export HOME="$TEST_ROOT/home"
export XDG_CONFIG_HOME="$TEST_ROOT/xdg"
CONF_DIR="$XDG_CONFIG_HOME/hermes"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
SERVER_LOG="$TEST_ROOT/server.log"
mkdir -p "$CONF_DIR" "$NET_DIR" "$DATA_DIR" "$(dirname "$EVIDENCIA")"
```

Por qué ambos:

- `directorioDatosPredeterminado()` usa `HOME` (`data_paths.h:16-20`). Por eso `jobs.json`,
  `events.jsonl` y `scheduler.lock` quedan bajo `$HOME/.local/share/hermes/data`.
- `rutaConfiguracion()` usa `XDG_CONFIG_HOME` si es absoluto y, si no, `$HOME/.config`
  (`data_paths.h:22-31`). Exportar ambos elimina la dependencia de la configuración del operador.
- `network.json` **siempre** se resuelve desde `HOME`, no desde `XDG_CONFIG_HOME` ni desde
  `directorio_datos` (`directorioRed()`). No intentar moverlo.

Ventaja adicional: el cliente, al arrancar, ejecuta `inicializarConfiguracionRemota()` y crea una
plantilla de `network.json` si falta. Con `HOME` temporal, esa escritura ocurre en el directorio
temporal y no en el `HOME` real de PC-B.

### 2.3 Configuración limpia

En modo local se escriben ambos archivos **antes** de `red start`. Cambiarlos con el servidor en
marcha no tiene efecto: `iniciarServidorRed()` los lee una sola vez al arrancar.

`config.json`:

```bash
escribir_config() {
    local puerto=$1
    cat >"$CONF_DIR/config.json" <<JSON
{
  "interfaz": "127.0.0.1",
  "puerto": $puerto,
  "redes_permitidas": ["127.0.0.0/8"],
  "trabajos_maximos": 8,
  "max_cola": 8
}
JSON
}
```

`network.json` (solo modo local):

```bash
escribir_network() {
    cat >"$NET_DIR/network.json" <<JSON
{
  "habilitada": true,
  "clientes": [
    {
      "id": "$CLIENTE_ID",
      "ambito_trabajos": "tc0nn-local",
      "direcciones": ["127.0.0.1"],
      "operaciones": ["submit", "query", "list", "cancel"],
      "programas": ["true", "false", "sleep", "echo", "ls"]
    }
  ]
}
JSON
}
```

Notas obligatorias:

- `habilitada: true` es lo que arranca el scheduler y habilita las operaciones. Con
  `habilitada: false`, el servidor solo atiende `ping` y toda operación devuelve `UNAUTHORIZED`.
- `interfaz` y `puerto` reales salen de `config.json`, no de `network.json`
  (`servidor.interfaz` y `servidor.puerto` no se leen).
- `ambito_trabajos` es opcional, pero conviene fijarlo: determina el `propietario_remoto`
  (`tcp-<ambito>`) y la clave de deduplicación (`red-tcp-<ambito>-<request_id>`). Si se omite, el
  ámbito es el `id` y la clave queda `red-tcp-<id>-<request_id>`. Fijarlo evita que un cambio de `id`
  rompa las aserciones.
- Se rechazan las claves heredadas `tls` y `sha256`: un `network.json` viejo hace fallar la carga con
  un mensaje que pide registrar clientes por `id` y `direcciones` IPv4. No copiar plantillas antiguas.
- `programas` es literal: `sleep` y `/usr/bin/sleep` son permisos distintos.
- `trabajos_maximos: 8` y `max_cola: 8` son suficientes para la mayoría de casos. Los casos de cupo
  o de respuestas grandes usan `64`/`64`.

### 2.4 Selección segura de puerto

En modo local, el puerto se elige pidiéndole al kernel uno libre, no adivinando:

```bash
elegir_puerto() {
    python3 - <<'PY'
import socket
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.bind(("127.0.0.1", 0))
    print(s.getsockname()[1])
PY
}
```

Reglas:

- Si `HERMES_TEST_PORT` está definida, se usa ese valor y se verifica que esté libre antes de
  arrancar. Es obligatorio en modo remoto y opcional en modo local.
- Para documentación reproducible se puede fijar un puerto del rango reservado `45864` en adelante.
  Ese rango es una convención del proyecto, no una garantía de disponibilidad: siempre se verifica.
- Entre `bind(0)` y el arranque del servidor hay una ventana de carrera. Mitigación: verificar el
  puerto justo antes de arrancar y reintentar con otro puerto hasta tres veces si el servidor no
  llega a escuchar.
- El puerto debe quedar libre al terminar. Si sigue ocupado, la limpieza falla y el script no puede
  terminar en PASS.

```bash
puerto_ocupado() {
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$1\$"
}
```

### 2.5 Arranque y espera activa

Nunca `sleep 2` a ciegas. La señal de disponibilidad es doble: el proceso sigue vivo **y** el log
contiene la línea de escucha **y** el puerto aparece en `LISTEN`.

```bash
esperar_escucha() {
    local puerto=$1
    for _ in $(seq 1 100); do
        kill -0 "$SERVER_PID" 2>/dev/null || return 1
        if grep -q "Hermes Red escuchando en" "$SERVER_LOG" 2>/dev/null &&
           puerto_ocupado "$puerto"; then
            return 0
        fi
        sleep 0.1
    done
    return 1
}
```

- 100 iteraciones de 100 ms equivalen a 10 s de plazo. Si el servidor muere antes, se detecta de
  inmediato y se imprime el log.
- La línea `Hermes Red escuchando en <ip>:<puerto>` la imprime `server.cpp` al completar `bind` y
  `listen`. Es la señal estable; no depender de `ss` a solas, porque otro proceso podría haber
  ocupado el puerto elegido.
- Si el arranque falla, imprimir `tail -n 40 "$SERVER_LOG"` antes de salir.

```bash
arrancar_servidor() {
    local intento
    for intento in 1 2 3; do
        if [[ -z "${HERMES_TEST_PORT:-}" ]]; then
            PUERTO="$(elegir_puerto)"
            escribir_config "$PUERTO"
        fi
        if puerto_ocupado "$PUERTO"; then
            echo "FAIL: el puerto $PUERTO ya está en uso."
            return 1
        fi
        : >"$SERVER_LOG"
        "$HERMES" red start >"$SERVER_LOG" 2>&1 &
        SERVER_PID=$!
        if esperar_escucha "$PUERTO"; then
            SERVIDOR_INICIADO=1
            return 0
        fi
        kill -TERM "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
        SERVER_PID=""
        [[ -n "${HERMES_TEST_PORT:-}" ]] && break
        echo "Reintentando con otro puerto (intento $intento)..."
    done
    echo "FAIL: 'hermes red start' no abrió el puerto $PUERTO."
    tail -n 40 "$SERVER_LOG" 2>/dev/null || true
    return 1
}
```

### 2.6 Limpieza obligatoria: `trap cleanup EXIT`

La limpieza debe ejecutarse también cuando el caso falla, y debe conservar el código de salida
original salvo que la propia limpieza falle.

```bash
SERVER_PID=""
SERVIDOR_INICIADO=""

buscar_scheduler() {
    local descriptor target pid
    for descriptor in /proc/[0-9]*/fd/*; do
        [[ -e "$descriptor" ]] || continue
        target="$(readlink "$descriptor" 2>/dev/null || true)"
        [[ "$target" == "$DATA_DIR/scheduler.lock" ]] || continue
        pid="${descriptor#/proc/}"
        pid="${pid%%/*}"
        [[ "$pid" == "$SERVER_PID" ]] && continue
        printf '%s\n' "$pid"
        return 0
    done
    return 0
}

parar_scheduler() {
    local pid
    pid="$(buscar_scheduler)"
    [[ -n "$pid" ]] || return 0
    kill -TERM "$pid" 2>/dev/null || true
    for _ in $(seq 1 50); do
        [[ -d "/proc/$pid" ]] || return 0
        sleep 0.1
    done
    kill -KILL "$pid" 2>/dev/null || true
    return 0
}

procesos_con_home_temporal() {
    local pid cmd
    for pid in /proc/[0-9]*; do
        [[ -r "$pid/environ" ]] || continue
        tr '\0' '\n' <"$pid/environ" 2>/dev/null | grep -Fqx "HOME=$HOME" || continue
        cmd="$(tr '\0' ' ' <"$pid/cmdline" 2>/dev/null || true)"
        [[ "$cmd" == *hermes* ]] || continue
        printf '%s %s\n' "${pid#/proc/}" "$cmd"
    done
}

cleanup() {
    local estado=$?
    trap - EXIT
    if [[ "${MODO:-local}" == "local" ]]; then
        if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
            kill -TERM "$SERVER_PID" 2>/dev/null || true
            for _ in $(seq 1 50); do
                kill -0 "$SERVER_PID" 2>/dev/null || break
                sleep 0.1
            done
            kill -KILL "$SERVER_PID" 2>/dev/null || true
            wait "$SERVER_PID" 2>/dev/null || true
        fi
        parar_scheduler || true
        # Solo se exige el puerto libre si este script llegó a poseerlo. Un
        # fallo de entorno (puerto ajeno ocupado) debe conservar su código 2.
        if [[ -n "${SERVIDOR_INICIADO:-}" ]] && puerto_ocupado "$PUERTO"; then
            echo "FALLO DE LIMPIEZA: el puerto $PUERTO sigue ocupado."
            estado=1
        fi
        if [[ -n "$(procesos_con_home_temporal)" ]]; then
            echo "FALLO DE LIMPIEZA: quedan procesos con HOME temporal:"
            procesos_con_home_temporal
            estado=1
        fi
    fi
    printf '```\n'
    rm -rf "$TEST_ROOT"
    exit "$estado"
}
trap cleanup EXIT
```

Puntos que no se pueden omitir:

- `kill -TERM`, espera acotada, `kill -KILL` de respaldo y `wait` para cosechar al hijo. Un `kill`
  sin `wait` deja el proceso en estado zombie hasta que el shell termina, pero el puerto puede
  tardar en liberarse.
- El scheduler es un proceso aparte que sobrevive al servidor. Se localiza por el descriptor
  abierto sobre `scheduler.lock`; matarlo por nombre es inseguro (podría ser el servidor del
  operador).
- `SIGTERM` al servidor debe producir la salida ordenada: cierra clientes, cierra la escucha,
  restaura los manejadores e imprime `Hermes Red detenido`. Si el caso lo amerita, se puede
  comprobar esa línea en `server.log` y el evento INFO con `{ "puerto": <n> }`; es una validación
  exclusiva del modo local.
- `printf '```\n'` cierra el bloque de evidencia. No usar `>>"$EVIDENCIA"` después de
  `exec > >(tee -a ...)`: duplicaría la cerca.
- `rm -rf "$TEST_ROOT"` va al final. Si se ejecuta antes de comprobar huérfanos, se pierde la
  evidencia de qué procesos quedaron.

### 2.7 Esqueleto completo de referencia

```bash
#!/usr/bin/env bash
# <RF|RNF>-<NN> - <título corto>.
# TC-0NN: <qué demuestra>.
# Modo: local.
set -euo pipefail
umask 077

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
TC="TC-0NN"
EVIDENCIA="$REPO/verif/results/results_${TC}.md"
HOST="${HERMES_TEST_HOST:-127.0.0.1}"
CLIENTE_ID="${HERMES_TEST_CLIENT_ID:-PC-B}"

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hermes-${TC}.XXXXXX")"
export HOME="$TEST_ROOT/home"
export XDG_CONFIG_HOME="$TEST_ROOT/xdg"
CONF_DIR="$XDG_CONFIG_HOME/hermes"
DATA_DIR="$HOME/.local/share/hermes/data"
NET_DIR="$HOME/.local/share/hermes/network"
JOBS="$DATA_DIR/jobs.json"
EVENTOS="$DATA_DIR/events.jsonl"
SERVER_LOG="$TEST_ROOT/server.log"
mkdir -p "$CONF_DIR" "$NET_DIR" "$DATA_DIR" "$(dirname "$EVIDENCIA")"

MODO="local"
PUERTO="${HERMES_TEST_PORT:-}"
if [[ "$HOST" != "127.0.0.1" && "$HOST" != "localhost" ]]; then
    MODO="remoto"
    : "${HERMES_TEST_PORT:?En modo remoto defina HERMES_TEST_PORT}"
fi

elegir_puerto() { python3 - <<'PY'
import socket
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.bind(("127.0.0.1", 0))
    print(s.getsockname()[1])
PY
}

puerto_ocupado() { ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$1\$"; }

escribir_config() {
    cat >"$CONF_DIR/config.json" <<JSON
{
  "interfaz": "127.0.0.1",
  "puerto": $1,
  "redes_permitidas": ["127.0.0.0/8"],
  "trabajos_maximos": 8,
  "max_cola": 8
}
JSON
}

escribir_network() {
    cat >"$NET_DIR/network.json" <<JSON
{
  "habilitada": true,
  "clientes": [
    {
      "id": "$CLIENTE_ID",
      "ambito_trabajos": "tc0nn-local",
      "direcciones": ["127.0.0.1"],
      "operaciones": ["submit", "query", "list", "cancel"],
      "programas": ["true", "false", "sleep", "echo", "ls"]
    }
  ]
}
JSON
}

if [[ -z "$PUERTO" ]]; then PUERTO="$(elegir_puerto)"; fi
escribir_config "$PUERTO"
[[ "$MODO" == "local" ]] && escribir_network

{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '%s\n' "- Modo: $MODO" "- Destino: $HOST:$PUERTO" "- Cliente: $CLIENTE_ID" \
        "- Commit: $(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo desconocido)"
    printf '\n```text\n'
} >>"$EVIDENCIA"
exec > >(tee -a "$EVIDENCIA") 2>&1

SERVER_PID=""
SERVIDOR_INICIADO=""
# ... buscar_scheduler, parar_scheduler, procesos_con_home_temporal y cleanup del §2.6 ...

esperar_escucha() {
    local puerto=$1
    for _ in $(seq 1 100); do
        kill -0 "$SERVER_PID" 2>/dev/null || return 1
        if grep -q "Hermes Red escuchando en" "$SERVER_LOG" 2>/dev/null &&
           puerto_ocupado "$puerto"; then
            return 0
        fi
        sleep 0.1
    done
    return 1
}

if [[ "$MODO" == "local" ]]; then
    arrancar_servidor || exit 1   # función del §2.5
else
    python3 - "$HOST" "$PUERTO" <<'PY'
import socket, sys
host, puerto = sys.argv[1], int(sys.argv[2])
with socket.create_connection((host, puerto), timeout=5):
    pass
PY
fi

# ... comprobaciones del caso ...

echo "PASS: <REQ> ${TC} sin fallos."
```

En modo remoto, `arrancar_servidor` no se llama y no se escribe `network.json`; el resto del
esqueleto (aislamiento, configuración del puerto, evidencia y limpieza) se mantiene igual.

---

## 3. Patrones reutilizables

### 3.1 Invocación del CLI y códigos de salida

Patrón de captura sin romper `set -e`:

```bash
estado=0
salida="$("$HERMES" red job "$HOST" true 2>&1)" || estado=$?
if [[ "$estado" -ne 0 ]]; then
    echo "FAIL: 'red job' devolvió $estado: $salida"
    exit 1
fi
```

No usar `if ! salida="$(...)"; then estado=$?; fi`: el `!` invierte el estado y `$?` vale 0.

Códigos observados del CLI (`client.cpp`):

| Comando | Situación | Código | Salida esperada |
| --- | --- | --- | --- |
| `red job` | Job creado o reutilizado | 0 | `job ID: <n>` (minúscula) y `PID: ...` o `PID: pendiente (en cola)` |
| `red job` | Duplicado | 0 | `job ID: <n>` + `Solicitud duplicada; se reutiliza el Job existente.` |
| `red job` | Rechazo del servidor, conexión fallida, respuesta inválida | 1 | Código o mensaje de error |
| `red filter <host> id <n>` | Job encontrado | 0 | Bloque `Job ID:` (mayúscula), `Estado:`, etc. |
| `red filter <host> id <n>` | `NOT_FOUND` o `JOB_OPERATION_FAILED` | 0 | `No se encontró el Job ID: <n>` |
| `red filter <host> status\|programa <v>` | Con o sin coincidencias | 0 | Filas o `No se encontraron Jobs...` |
| `red filter` | Error de conexión o protocolo | 1 | Mensaje de error |
| `red cancel <host> <id>` | Cancelación aceptada | 0 | Confirmación de solicitud |
| `red cancel <host> <id>` | `NOT_FOUND`, estado terminal, protocolo o conexión | 1 | `No existe el Job ID: <n>` u otro error |

Reglas de parseo:

- La admisión de `red job` imprime **`job ID:`** en minúscula; el detalle de `red filter` imprime
  **`Job ID:`** en mayúscula. No mezclarlos.
- Parsear con `sed -n 's/^job ID: \([0-9][0-9]*\)$/\1/p'`, no con `awk '{print $3}'`.
- No comparar líneas completas con prefijos de color. Aunque la salida se redirige y normalmente no
  lleva color, los helpers `info()`/`error()` pueden anteponer texto. Buscar subcadenas estables.
- `red filter id` devuelve 0 cuando no encuentra el Job. Un `0` **no** significa que el Job exista:
  hay que comprobar además que la salida contenga `Job ID:`.
- `red cancel` en estado terminal devuelve 1 con `NOT_CANCELABLE` y el estado en el mensaje. Es un
  rechazo esperado, no un fallo del script.

Ejemplo de extracción y consulta:

```bash
estado=0
salida="$("$HERMES" red job "$HOST" --request-id "tc0nn-1" sleep 30 2>&1)" || estado=$?
[[ "$estado" -eq 0 ]] || { echo "FAIL: admisión: $salida"; exit 1; }
JOB_ID="$(printf '%s\n' "$salida" | sed -n 's/^job ID: \([0-9][0-9]*\)$/\1/p')"
[[ -n "$JOB_ID" ]] || { echo "FAIL: no se pudo extraer el Job ID: $salida"; exit 1; }

estado=0
detalle="$("$HERMES" red filter "$HOST" id "$JOB_ID" 2>&1)" || estado=$?
[[ "$estado" -eq 0 ]] || { echo "FAIL: consulta: $detalle"; exit 1; }
ESTADO_JOB="$(printf '%s\n' "$detalle" | sed -n 's/^Estado: //p')"
```

En modo remoto, el host es `HERMES_TEST_HOST`; el puerto lo toma el cliente del `config.json`
temporal escrito en §2.3.

### 3.2 Cliente Python crudo: sobre, framing y respuesta

Cada bloque `python3 - <<'PY'` es un proceso independiente: no comparte funciones ni variables con
otro bloque. Los parámetros se pasan por `argv`.

```python
import json, socket, sys

host, puerto = sys.argv[1], int(sys.argv[2])

def sobre(rid, operacion, params=None):
    return {"version": 1, "request_id": rid, "operation": operacion,
            "params": {} if params is None else params}

def leer_linea(s, pendiente):
    while b"\n" not in pendiente:
        trozo = s.recv(4096)
        if not trozo:
            raise SystemExit("FAIL: el servidor cerró sin responder")
        pendiente += trozo
    linea, _, resto = pendiente.partition(b"\n")
    return json.loads(linea), resto

with socket.create_connection((host, puerto), timeout=5) as s:
    s.sendall((json.dumps(sobre("tc0nn-ping", "ping")) + "\n").encode())
    respuesta, _ = leer_linea(s, b"")

if respuesta.get("ok") is not True or respuesta.get("result", {}).get("message") != "pong":
    raise SystemExit("FAIL: ping inesperado: %r" % (respuesta,))
print("  ping: " + json.dumps(respuesta, ensure_ascii=False))
```

Reglas del protocolo que el cliente de prueba debe respetar:

- Una petición por línea terminada en `\n`; una respuesta por línea terminada en `\n`. No hay
  longitud explícita ni multiplexación. Las respuestas llegan en el mismo orden que las peticiones.
- El sobre válido tiene exactamente `version`, `request_id`, `operation` y `params`. Una clave
  superior extra produce `INVALID_REQUEST`.
- `request_id` debe ser string de 1 a 128 caracteres `[A-Za-z0-9._:-]`.
- Los errores previos a un `request_id` interpretable (`errorProtocolo()`) llevan
  `"request_id": null`: `MESSAGE_TOO_LARGE`, `NUL_BYTE`, `INVALID_UTF8`, `TOO_DEEP`, `INVALID_JSON`,
  `INVALID_REQUEST` y `request_id` ausente o no-string. Desde `validarRequestId` en adelante se usa
  `rechazoConId()`, que **ecoa el id** (`INVALID_REQUEST_ID` por formato, `INVALID_VERSION`,
  `UNSUPPORTED_VERSION`, `INVALID_OPERATION`, `INVALID_PARAMS`, `UNKNOWN_OPERATION`). El cliente
  oficial acepta ambos (`client.cpp:240-249`); un `ok: true` con `request_id: null` es inválido.
- La conexión permanece abierta tras una respuesta aceptada o tras un rechazo **de operación**
  (`UNAUTHORIZED`, `PROGRAM_NOT_ALLOWED`, `NOT_FOUND`, `NOT_CANCELABLE`, `RESPONSE_TOO_LARGE`,
  `JOB_OPERATION_FAILED`, `INVALID_PARAMS` de operación). Se cierra tras un rechazo
  **de protocolo/framing** y tras tres segundos de inactividad.
- Un `\n` dentro de un `sendall` delimita una transacción. Los bytes posteriores al delimitador
  pertenecen a la siguiente y no heredan su desenlace.

Timeouts: 5 s para una transacción local, 20 s para escenarios fragmentados o remotos. El servidor
corta a los 3 s de inactividad, así que un emisor lento debe enviar al menos un byte cada 3 s.

### 3.3 Fragmentación de un mensaje (RNF-24)

Objetivo: demostrar que el servidor acumula hasta el delimitador y que el plazo mide inactividad,
no tiempo total desde `accept`.

```python
import json, socket, sys, time

puerto = int(sys.argv[1])
solicitud = (json.dumps({"version": 1, "request_id": "tc0nn-fragmentado",
                         "operation": "submit",
                         "params": {"programa": "true", "argumentos": []}}) + "\n").encode()

with socket.create_connection(("127.0.0.1", puerto), timeout=20) as s:
    inicio = time.monotonic()
    for byte in solicitud:
        s.sendall(bytes([byte]))
        time.sleep(0.04)
    transcurrido = time.monotonic() - inicio

    pendiente = b""
    while b"\n" not in pendiente:
        trozo = s.recv(4096)
        if not trozo:
            raise SystemExit("FAIL: cierre sin respuesta al mensaje fragmentado")
        pendiente += trozo
    respuesta = json.loads(pendiente.split(b"\n")[0])

if respuesta.get("ok") is not True:
    raise SystemExit("FAIL: mensaje fragmentado rechazado: %r" % (respuesta,))
if transcurrido <= 3.0:
    raise SystemExit("FAIL: el envío no superó los 3 s; no se ejercita el plazo")
print("  envío fragmentado en %.2f s (%d bytes)" % (transcurrido, len(solicitud)))
```

Reglas:

- Enviar byte a byte con una pausa menor que 3 s (40 ms es seguro) y verificar que el total supera
  los 3 s. Un mensaje partido en dos `sendall` sin pausa no prueba la renovación del plazo.
- Fragmentar ASCII (JSON válido) para no introducir bytes UTF-8 inválidos por accidente.
- Tras la respuesta, comprobar que el Job existe exactamente una vez en `jobs.json`.
- No fragmentar un mensaje que ya excede 16 384 bytes: el rechazo por tamaño ocurre antes de
  completar el framing y el resultado esperado sería otro.

### 3.4 Solicitudes secuenciales en una conexión (RNF-24)

Los fragmentos de esta sección suponen que el mismo bloque `python3 -` define los helpers `sobre` y
`leer_linea` de §3.2. Si se copian a un proceso independiente, hay que repetirlos.

Dos variantes válidas:

**Encadenadas en un solo `write`** (prueba que un rechazo no contamina lo anterior y que el orden
se respeta):

```python
primera = ("{\"version\":1,\"request_id\":\"tc0nn-a\",\"operation\":\"ping\",\"params\":{}}\n"
           "{\"version\":1,\"request_id\":\"tc0nn-b\",\"operation\":\"ping\",\"params\":{}}\n")
s.sendall(primera.encode())
pendiente = b""
respuestas = []
while len(respuestas) < 2:
    respuesta, pendiente = leer_linea(s, pendiente)
    respuestas.append(respuesta)
assert [r["request_id"] for r in respuestas] == ["tc0nn-a", "tc0nn-b"]
```

**En bucle sobre la misma conexión** (prueba que la conexión sigue usable tras cada respuesta):

```python
with socket.create_connection((host, puerto), timeout=5) as s:
    pendiente = b""
    for i in range(1, 21):
        s.sendall((json.dumps(sobre("tc0nn-%02d" % i, "submit",
                                    {"programa": "true", "argumentos": []})) + "\n").encode())
        respuesta, pendiente = leer_linea(s, pendiente)
        if respuesta.get("ok") is not True:
            raise SystemExit("FAIL: submit %d rechazado: %r" % (i, respuesta))
```

Reglas:

- Contar las respuestas por líneas, no por `recv()`: un `recv` puede traer varias respuestas o una
  fracción.
- No enviar la siguiente petición mientras haya una respuesta pendiente si el caso quiere modelar
  un cliente estrictamente secuencial. El servidor atiende en FIFO y no multiplexa, pero la prueba
  debe declarar qué modelo usa.
- Un rechazo de protocolo cierra la conexión y descarta los bytes encadenados detrás. Si el caso
  espera dos respuestas, la segunda debe ser válida; si espera un rechazo, no debe asumir que la
  conexión sigue abierta.
- El cliente oficial reutiliza una conexión por invocación y solo reconecta una vez por página en
  `filter` de solo lectura (`client.cpp:195-220`). Para `submit` y `cancel` no hay reintento.

### 3.5 FIN, RST y SIGKILL en distintas fases (RF-22 / RF-28)

Tres formas de cortar, con expectativas distintas:

| Corte | Cuándo | Qué espera el servidor | Desenlace si se interrumpe |
| --- | --- | --- | --- |
| FIN ordenado tras un mensaje completo | Después del `\n`, leyendo la respuesta | Procesa y responde; el cierre queda en `CierreNormal` | Ninguno, **si la respuesta se entregó** |
| FIN tras un mensaje completo sin leer la respuesta | Después del `\n`, cerrando de inmediato | Procesa; el `send` puede fallar con `EPIPE` | `ACEPTADA` con motivo `ERROR_ESCRITURA` |
| FIN con bytes sin `\n` | A mitad de mensaje | Responde `INCOMPLETE_MESSAGE` y cierra | `SIN_EFECTO`, motivo `FIN_SIN_MENSAJE` |
| RST tras un mensaje completo | Después del `\n`, con `SO_LINGER 0` | Procesa; la respuesta se pierde | `ACEPTADA` o `RECHAZADA` según la operación |
| RST a mitad de mensaje | Antes del `\n` | No procesa | `SIN_EFECTO` |
| `SIGKILL` del cliente a mitad de mensaje | Proceso hijo matado | No procesa; detecta el cierre | `SIN_EFECTO` |

FIN ordenado:

```python
s.sendall(carga.encode())
s.shutdown(socket.SHUT_WR)
time.sleep(0.3)
try:
    s.recv(4096)
except OSError:
    pass
s.close()
```

RST:

```python
import struct
s.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
s.close()
```

`SIGKILL` de un cliente a mitad de mensaje:

```python
import os, signal, socket, time
hijo = os.fork()
if hijo == 0:
    s = socket.create_connection(("127.0.0.1", puerto), timeout=5)
    s.sendall(b'{"version":1,"request_id":"tc0nn-parcial","operation":"submit","params":{"programa":"tr')
    time.sleep(30)
    os._exit(0)
time.sleep(0.5)
os.kill(hijo, signal.SIGKILL)
os.waitpid(hijo, 0)
```

Después de cada corte, en modo local:

1. `kill -0 "$SERVER_PID"` para confirmar que el servicio sigue vivo.
2. `ping` para confirmar que atiende.
3. `jobs.json` parseable, como lista, con `job_id` entero, `programa` no vacío y `status` en
   `{QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED, INTERRUPTED}`.
4. `events.jsonl` con el desenlace que corresponde a la tabla anterior.

Tabla de desenlaces (`server.cpp:248-279` y `protocol.cpp`):

| Situación | `resultado` | Evento | Motivo |
| --- | --- | --- | --- |
| Mensaje completo, operación aceptada, corte antes de leer | `ACEPTADA` | `Solicitud interrumpida` | `ERROR_LECTURA`, `ERROR_ESCRITURA`, `ERROR_SOCKET` o `TIMEOUT_LECTURA` según el corte |
| Mensaje completo, operación rechazada por dominio | `RECHAZADA` | `Solicitud interrumpida` | El del corte; incluye `error` y, si aplica, `job_id` |
| Bytes sin `\n` y cierre/timeout | `SIN_EFECTO` | `Solicitud interrumpida` | `FIN_SIN_MENSAJE`, `TIMEOUT_LECTURA`, etc. |
| Rechazo de protocolo/framing (`formatoInvalido`) | No se emite | `Mensaje rechazado` | Ventana de 60 s por código; cierra tras responder |
| Cierre ordenado después de una respuesta completa | No se emite | Ninguno | `CierreNormal` está suprimido |
| Sin bytes y cierre | No se emite si la ventana lo silencia | `Cliente desconectado` | Ventana de 60 s por motivo |

Reglas para no producir falsos negativos:

- `Solicitud interrumpida` se emite **siempre** que la transacción empezó a recibirse, sin ventana.
  No aplica a rechazos de formato (`formatoInvalido`), que ya quedaron documentados como
  `Mensaje rechazado`.
- `Mensaje rechazado` y `Cliente desconectado` sí tienen ventana de 60 s por código/motivo. Si el
  caso repite el mismo motivo, solo el primero deja evento. No asumir un evento por conexión.
- Un cierre normal tras una respuesta completa no deja evento; no fallar por su ausencia.
- No usar `sleep` fijo para esperar el evento: sondear el archivo hasta que aparezca o vencer el
  plazo (por ejemplo, 5 s con `sleep 0.1`).
- `jobs.json` se escribe bajo `jobs.lock`; leerlo con Python y reintentar si está a mitad de
  reemplazo. No parsear con `grep` ni con `jq` que pueda fallar por una escritura concurrente.

Espera activa de un desenlace:

```bash
esperar_desenlace() {
    local resultado=$1 plazo=$2
    for _ in $(seq 1 $((plazo * 10))); do
        if python3 - "$EVENTOS" "$resultado" <<'PY'
import json, os, sys
ruta, esperado = sys.argv[1], sys.argv[2]
if not os.path.exists(ruta):
    raise SystemExit(1)
for linea in open(ruta, encoding="utf-8"):
    linea = linea.strip()
    if not linea:
        continue
    evento = json.loads(linea)
    if evento.get("message") == "Solicitud interrumpida" and \
       evento.get("context", {}).get("resultado") == esperado:
        raise SystemExit(0)
raise SystemExit(1)
PY
        then
            return 0
        fi
        sleep 0.1
    done
    return 1
}
```

### 3.6 Límites y formatos inválidos (RNF-14)

Constantes verificadas:

| Límite | Valor | Origen |
| --- | --- | --- |
| Mensaje de entrada | 16 384 bytes sin el `\n` | `network_protocol.h:6`, `protocol.cpp:39` |
| Respuesta | 262 144 bytes | `network_protocol.h:7`, `protocol.cpp:97` |
| Profundidad JSON | 32 niveles | `protocol.cpp:44-47` |
| Operación | 32 bytes | `protocol.cpp:79` |
| `request_id` | 1-128 de `[A-Za-z0-9._:-]` | `validator.cpp` |
| Clientes concurrentes | 32 | `server.cpp:488` |
| Inactividad de lectura/escritura | 3 s | `server.cpp:359,401` |

Batería mínima de rechazos deterministas:

```python
casos = [
    (b"{no es json}\n", "INVALID_JSON", "JSON roto"),
    (b'{"version":1,"request_id":"a","operation":"ping","params":{}}\x00\n', "NUL_BYTE", "byte nulo"),
    (b'{"version":1,"request_id":"\xff","operation":"ping","params":{}}\n', "INVALID_UTF8", "UTF-8 inválido"),
    (b'{"version":1,"request_id":"a","operation":"ping","params":{},"extra":'
     + b"[" * 40 + b"]" * 40 + b"}\n", "TOO_DEEP", "profundidad 40"),
    (b'{"version":1,"request_id":"a","operation":"ping","params":{},"extra":1}\n',
     "INVALID_REQUEST", "clave superior extra"),
    (b"{" + b"0" * 16390 + b"}\n", "MESSAGE_TOO_LARGE", "16 392 bytes"),
    (b'{"version":2,"request_id":"a","operation":"ping","params":{}}\n',
     "UNSUPPORTED_VERSION", "version 2"),
    (b'{"version":1,"request_id":"bad id","operation":"ping","params":{}}\n',
     "INVALID_REQUEST_ID", "request_id inválido"),
    (b'{"version":1,"request_id":"a","operation":"nope","params":{}}\n',
     "UNKNOWN_OPERATION", "operación desconocida"),
]
```

Cada caso se envía en una conexión nueva (o secuencialmente, sabiendo que el rechazo cierra) y se
exige `ok: false` con el código exacto. Reglas:

- `MESSAGE_TOO_LARGE` se evalúa antes que `NUL_BYTE`, `INVALID_UTF8` y el parseo. Para el caso de
  tamaño, el contenido no importa.
- `NUL_BYTE` se evalúa antes que `INVALID_UTF8` y antes de JSON.
- Los rechazos previos a `validarRequestId` llevan `request_id: null`; a partir de ahí el sobre ecoa
  el id, aunque sea inválido. No exigir `null` de forma indiscriminada.
- Un rechazo de protocolo cierra la conexión después de responder. Un `ping` posterior debe usar
  una conexión nueva.
- El caso de `RESPONSE_TOO_LARGE` no es un rechazo de framing y **no cierra** la conexión. Para
  provocarlo de forma determinista: configurar `trabajos_maximos: 64` y `max_cola: 64`, crear 50
  Jobs con un argumento largo (por ejemplo, 6 000 bytes cada uno) usando `list` con `limit: 50`, de
  modo que la respuesta serializada supere 262 144 bytes. Los argumentos se pasan a `true`, que los
  ignora. Si el entorno no permite crear 50 Jobs, el caso se marca `SKIP`, no `PASS`.
- Para el límite de respuesta del **cliente**, un servidor falso puede enviar una línea de más de
  262 144 bytes; el cliente debe fallar con `Respuesta demasiado grande: excede el máximo de la red`
  y código 1.
- No asumir el comportamiento exacto del borde 16 384/16 385 sin comprobarlo: el servidor evalúa el
  límite por mensaje, no por búfer, y un flujo con varias solicitudes encadenadas puede superar el
  total sin que ninguna lo supere individualmente.

### 3.7 Fuga de secretos (RNF-15)

Patrón:

1. Usar marcadores únicos e irrepetibles: `rf15secreto1`, `rf15secreto2`.
2. Ejecutar una operación que los coloque en argumentos (`--password=...`, `--api-key=...`,
   `--token=...`, `-p ...`).
3. Escanear **todo** el texto que pueda filtrarlos:
   - `events.jsonl`
   - `server.log`
   - la salida combinada del CLI (stdout + stderr)
   - los mensajes de error de arranque por `config.json`/`network.json`/`jobs.json` corruptos
4. Exigir la forma redactada: `--password=[REDACTED]`, `--api-key=[REDACTED]`.
5. Comprobar que `jobs.json` conserva el valor real: la redacción es de bitácora, no de ejecución.

```python
for ruta in (eventos, log_servidor, salida_cli):
    if os.path.exists(ruta) and "rf15secreto1" in open(ruta, encoding="utf-8", errors="replace").read():
        raise SystemExit("FAIL: %s expone el secreto" % ruta)
```

Reglas y riesgos residuales documentados:

- La redacción es por clave y por patrón. `-p` se redacta **siempre**, incluso en casos como
  `mkdir -p /tmp/x` (R1 de RNF-15). No escribir una aserción que espere conservar `-p`.
- La salida de `hermes red setup` por `stdout` queda fuera de la bitácora (R2). No usarla como
  fuente de una prueba de fuga.
- Los errores de parser que solo se imprimen en la terminal del operador (`hermes logs`, `filter`,
  `clean`) no pasan por la redacción central (R4). Una prueba de fuga debe declarar qué fuente
  escanea.
- Un archivo corrupto debe reportarse citando clave y causa, nunca volcando su contenido. Si el
  marcador aparece en el mensaje, es un fallo.
- `hermes red start` escribe en `stderr` los errores de configuración; capturarlos y escanearlos.

### 3.8 Control de acceso por IP/CIDR y cupo (RF-18 / RF-20 / RNF-13)

Todo este bloque es **exclusivo del modo local**: requiere controlar `config.json`, `network.json`
y el origen observado.

Matriz de escenarios:

| # | `redes_permitidas` | `clientes` | Acción | Resultado observable |
| --- | --- | --- | --- | --- |
| 1 | `["127.0.0.0/8"]` | registrado con todas las operaciones | `ping` + `submit true` | `ping` ok; Job creado |
| 2 | `[]` | cualquiera | `ping` desde `127.0.0.1` | Cierre sin respuesta (EOF inmediato); `Conexión rechazada` con motivo `ORIGEN_RECHAZADO` |
| 3 | `["10.0.0.0/8"]` | cualquiera | `ping` desde `127.0.0.1` | Igual que 2 |
| 4 | `["127.0.0.0/8"]` | sin registro para `127.0.0.1` | `ping` y `submit` | `ping` ok; `submit` → `UNAUTHORIZED`; la conexión sigue abierta |
| 5 | `["127.0.0.0/8"]` | registrado solo con `["query"]` | `submit` | `UNAUTHORIZED`; `query` sobre un Job propio funciona |
| 6 | `["127.0.0.0/8"]` | registrado con `programas: ["true"]` | `submit true`, `submit sleep`, `submit /usr/bin/true` | ok, `PROGRAM_NOT_ALLOWED`, `PROGRAM_NOT_ALLOWED` (literal) |
| 7 | `["127.0.0.0/33"]` (inválida) | - | `red start` | La carga registra el evento `redes_permitidas inválida; se deniega el acceso de red`; el arranque se rechaza con código 1 y `stderr` contiene `No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar`. El puerto nunca se abre |
| 8 | `["127.0.0.0/8"]` | 32 conexiones abiertas | 33.ª conexión | Cierre sin respuesta; `Conexión rechazada` con motivo `CUPO_EXCEDIDO`; el servicio sigue atendiendo al liberar cupo |

Detalles de implementación:

- Para el caso 2/3, `create_connection` puede completar el handshake TCP (el `accept` ocurre en el
  servidor) y luego `recv` devuelve `b""` sin JSON. No fallar si el `connect` tuvo éxito; el
  rechazo es el cierre sin respuesta. Esperar el EOF con un timeout corto.
- El evento `Conexión rechazada` tiene ventana de 60 s por motivo. Si el caso repite el mismo
  origen, solo el primer intento deja evento. No exigir un evento por conexión.
- Distinguir dos rechazos que se confunden:
  - Origen fuera de `redes_permitidas` → **cierre sin respuesta** y evento `Conexión rechazada`.
  - Origen permitido pero sin registro → **`ping` funciona**, y las operaciones devuelven
    `UNAUTHORIZED` con la conexión abierta.
- El caso 6 confirma que la comprobación de programa es literal; `sleep` y `/usr/bin/sleep` son
  permisos distintos.
- El caso 7 requiere que el servidor no abra el puerto. Comprobar el código de salida y el mensaje
  en `stderr`/`server.log`, y que `puerto_ocupado` sea falso después.
- El caso 8 mide el cupo de 32 conexiones **simultáneas**. `listen(..., 10)` permite que el
  handshake de la 33.ª se complete en el backlog y luego el servidor la cierre. Para que las 32
  primeras no venzan por inactividad (3 s), enviar un byte sin `\n` a cada una cada ~1 s, o hacer
  la conexión 33 y la lectura en menos de 3 s. La segunda opción es más simple y suficiente en
  WSL; la primera es más robusta en máquinas lentas.
- Una dirección `/32` unicast pública explícita fue aceptada históricamente por `access.cpp`, pero
  RNF-26 la rechaza y alinea la política a loopback, RFC1918 y `100.64.0.0/10`. La prueba debe usar
  solo esos espacios.

Para dos orígenes distintos en un mismo host Linux (propiedad de Jobs por `ambito_trabajos`):

- El servidor debe escuchar en `0.0.0.0`; `config.json` con `"interfaz": "0.0.0.0"`.
- `redes_permitidas: ["127.0.0.0/8"]` y dos clientes: `127.0.0.1` y `127.0.0.2`, con
  `ambito_trabajos` distintos.
- El segundo socket debe hacer `bind(("127.0.0.2", 0))` antes de `connect`; de lo contrario el
  kernel puede elegir `127.0.0.1` como origen.
- Esta variante es específica de Linux y del loopback `/8`. Si el entorno no la soporta, se marca
  `SKIP` y se cubre la separación de ámbitos a nivel de diseño, no con una aserción de red.

### 3.9 Autorización por operación y por programa (RF-18 / RNF-13)

Checklist mínimo de un caso de autorización:

1. Arrancar con un `network.json` que registre el origen y solo el subconjunto a probar.
2. Enviar `ping`: debe funcionar sin identidad y sin permisos.
3. Enviar una operación no incluida en `operaciones`: `UNAUTHORIZED`, conexión abierta, sin Job.
4. Enviar una operación incluida con un programa no incluido en `programas`:
   `PROGRAM_NOT_ALLOWED`, sin Job.
5. Enviar la misma operación con el programa permitido: `ok: true` y Job persistido con
   `propietario_remoto = "tcp-<ambito_trabajos>"` y `tipo_ejecucion = "remote"` en `jobs.json`.
6. Repetir con `habilitada: false`: `ping` funciona, toda operación devuelve `UNAUTHORIZED` y no se
   crea Job.
7. Si el caso prueba deduplicación: dos `submit` con el mismo `request_id`, programa y argumentos
   devuelven el mismo `job_id` con `duplicated: true`; con programa o argumentos distintos,
   `JOB_OPERATION_FAILED` con mensaje. La clave es `red-tcp-<ambito_trabajos>-<request_id>`, donde
   `ambito_trabajos` toma el valor de `id` si se omite.
8. Si el caso prueba propiedad: un Job creado por un ámbito no se ve desde otro (`NOT_FOUND`), y
   `cancel` desde otro ámbito también da `NOT_FOUND`.

No confundir `UNAUTHORIZED` de protocolo (sin identidad/permisos, `protocol.cpp:92`) con
`PROGRAM_NOT_ALLOWED` de operación (`remote.cpp:150-152`). Ambos dejan la conexión abierta, pero el
primero no llega a evaluar `params` de la operación.

### 3.10 Servidor falso para probar al cliente

Para errores que el servidor real no produce de forma controlada (sobre inválido, `request_id`
distinto, respuesta gigante, cierre tras cada respuesta), usar un servidor Python mínimo en un
puerto propio del script.

Requisitos:

- Escuchar en `127.0.0.1` en un puerto libre; escribir un archivo `listo` cuando esté escuchando.
- Atender un número conocido de conexiones y terminar solo.
- Responder exactamente lo que el caso necesita, con `\n` final.
- No reutilizar el puerto del servidor real de la prueba.
- Registrarse en `cleanup` como un PID más (`SERVIDOR_FALSO_PID`) y esperarlo.

```python
import socket, sys
puerto, listo, respuestas = int(sys.argv[1]), sys.argv[2], sys.argv[3:]
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as servidor:
    servidor.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    servidor.bind(("127.0.0.1", puerto))
    servidor.listen(4)
    open(listo, "w", encoding="utf-8").write("listo")
    for respuesta in respuestas:
        conexion, _ = servidor.accept()
        with conexion:
            datos = b""
            while b"\n" not in datos:
                trozo = conexion.recv(4096)
                if not trozo:
                    break
                datos += trozo
            conexion.sendall((respuesta + "\n").encode())
```

El `config.json` temporal debe apuntar al puerto del servidor falso para que el CLI conecte ahí.
En modo remoto no se usa este patrón contra PC-A; el servidor falso es local al script.

### 3.11 Aislamiento entre casos

- Un caso, un puerto. No compartir puerto entre scripts ni entre variantes.
- Un caso, un `HOME`. No reutilizar `TEST_ROOT` entre ejecuciones.
- Un caso, un scheduler. El scheduler se localiza por `scheduler.lock` bajo el `DATA_DIR` temporal;
  si se deja vivo, el siguiente caso puede encontrar un lock ajeno.
- No ejecutar `./hermes` sin argumentos desde el repositorio durante una prueba: ese camino ejecuta
  `actualizarEnlacesDesarrollo()` y puede tocar los enlaces `data`, `config` y `network`.
- No escribir archivos temporales dentro del repositorio. Si un caso necesita un archivo dentro del
  árbol (por ejemplo, para una ruta relativa), usar una ruta ignorada por Git y borrarla en
  `cleanup`.

---

## 4. Entregables y trazabilidad

### 4.1 Nomenclatura

| Artefacto | Ruta | Regla |
| --- | --- | --- |
| Script | `verif/scripts/TC-0NN.sh` | Número correlativo; el siguiente libre es `TC-057` |
| Ficha | `verif/test-cases/TC-0NN.md` | Mismo número que el script |
| Evidencia | `verif/results/results_TC-0NN.md` | Se abre en modo append; una sección por ejecución |
| Índice | `verif/test-cases/test-cases.md` | Párrafo que enlaza el caso y resume qué cubre |
| Matriz | `verif/verification-plan/traceability-matrix.md` | Fila del requisito con caso, evidencia y estado |

No renumerar casos existentes. Un caso nuevo que reemplaza a otro se marca como corrección en la
ficha y en el índice, no se borra el historial.

### 4.2 Ficha `TC-0NN.md`

Estructura obligatoria, tomada de `TC-049.md`:

```markdown
# TC-0NN: <título>

**Requisitos cubiertos:** <RF/RNF>
**Métodos de verificación:** Prueba
**Nivel de prueba:** Funcional y robustez

#### 1. Fase de Diseño (Planificación)
* **Objetivo:** <qué demuestra, en una frase>.
* **Precondiciones:** Linux o WSL con Bash y Python 3; Hermes compilado; `HOME` temporal aislado;
  puerto libre o `HERMES_TEST_PORT`.
* **Entorno y configuración:** `config.json` y `network.json` propios (modo local) o destino
  `HOST:PUERTO` (modo remoto).
* **Datos de entrada:** <sobres, fragmentos, cortes, valores límite>.
* **Pasos reproducibles:**
  1. Compilar con `make -C src/hermes hermes`.
  2. Ejecutar `bash verif/scripts/TC-0NN.sh`.
  3. Revisar el código de salida y `verif/results/results_TC-0NN.md`.
* **Resultado esperado:** <aserción por criterio de aceptación, con la etiqueta de modo>.

#### 2. Fase de Ejecución (Resultados empíricos)
* **Resultado observado:** <fecha, entorno, códigos, valores medidos>.
* **Artefactos de evidencia:** `verif/scripts/TC-0NN.sh`; `verif/results/results_TC-0NN.md`.
* **Estado:** PASS | FAIL | PARCIAL
* **Responsable y versión probada:** [nombre] - [requisito, fecha]
```

Cada criterio de aceptación de la ficha lleva una etiqueta de modo:

- `[local]`: solo se puede validar con el servidor propio.
- `[remoto]`: solo tiene sentido contra PC-A/PC-B.
- `[ambos]`: se valida en los dos modos.

### 4.3 Script `TC-0NN.sh`

Requisitos mínimos:

- Cabecera con requisito, título, qué demuestra y modo.
- `set -euo pipefail` y `umask 077`.
- Aislamiento de `HOME`/`XDG_CONFIG_HOME` y puerto.
- Configuración limpia y `habilitada: true` en modo local.
- Arranque en segundo plano y espera activa.
- `trap cleanup EXIT` con `SIGTERM`, `wait`, scheduler, puerto y huérfanos.
- Una línea `PASS Vn/ACn: <qué se comprobó>` por bloque, y `PASS: <REQ> <TC> sin fallos.` al final.
- Nada de `set +e` permanente ni de `|| true` que oculte fallos, salvo en la limpieza.
- Nada de dependencias nuevas: Bash, Python 3, `ss`, `grep`, `sed`, `awk`, `mktemp`, `/proc`.

### 4.4 Evidencia `verif/results/results_TC-0NN.md`

Formato:

````markdown
## Ejecucion: 2026-11-26 10:00:00 -0600

- Modo: local
- Destino: 127.0.0.1:45912
- Cliente: PC-B
- Commit: 19248d6

```text
Arrancando 'hermes red start' con HOME temporal...
  ...
PASS V1/AC1: ...
PASS: RNF-13 TC-057 sin fallos.
```
````

Reglas:

- El script escribe la cabecera y abre la cerca antes de `exec > >(tee -a ...)`, y cierra la cerca en
  `cleanup`. Así una ejecución fallida no deja un bloque Markdown abierto.
- Una ejecución nueva agrega una sección nueva; no se sobrescribe el historial.
- La evidencia incluye el comando exacto cuando el caso lo requiera (por ejemplo, la variante
  remota), pero nunca rutas absolutas del `HOME` real ni secretos.
- No editar la evidencia a mano para cambiar un FAIL por PASS. Si se repite la ejecución, se agrega
  la nueva sección.

### 4.5 LF, permisos y `.gitattributes`

- El archivo debe tener finales de línea LF. `.gitattributes` ya fija
  `verif/scripts/*.sh text eol=lf`, pero un editor de Windows puede introducir CRLF antes del
  commit. Normalizar con `sed -i 's/\r$//' verif/scripts/TC-0NN.sh` o `dos2unix`.
- El script debe ser ejecutable: `chmod +x verif/scripts/TC-0NN.sh`. Comprobar con
  `git ls-files -s verif/scripts/TC-0NN.sh` (modo `100755`).
- No usar `git -c core.autocrlf=false`: infla el diff y oculta el problema real.
- La guía y la ficha pueden ser Markdown normal; no requieren `chmod`.

### 4.6 Matriz de trazabilidad e índice

En `verif/verification-plan/traceability-matrix.md`, completar la fila del requisito:

- **Método:** `Prueba` (o `Prueba y diseño` si el caso combina ambas).
- **Caso(s):** `TC-0NN` (y los que correspondan).
- **Evidencia:** `verif/scripts/TC-0NN.sh + verif/results/results_TC-0NN.md ([PASS], fecha)`.
- **Resultado:** `PASS`, `PASS PARCIAL`, `FAIL` o `Pendiente`.
- **Defecto/Excepción:** riesgos residuales o `-`.

Solo se marca `PASS` cuando la ejecución autocontenida cubrió **todos** los criterios requeridos y
la evidencia está en el repositorio. Una ejecución solo remota, o con comprobaciones de servidor
omitidas, se registra como `PASS PARCIAL` y no cierra la fila.

En `verif/test-cases/test-cases.md`, agregar un párrafo que:

- enlace `[TC-0NN](./TC-0NN.md)`;
- indique el requisito y el rango de puertos usado;
- diga si el caso usa servidor real, servidor falso o ambos;
- mencione la evidencia generada.

### 4.7 Criterios de resultado

| Código | Significado | Cuándo |
| --- | --- | --- |
| `0` | PASS | Todas las comprobaciones aplicables se ejecutaron y pasaron |
| `1` | FAIL | Una comprobación falló, o la limpieza dejó procesos/sockets |
| `2` | Error de entorno | Binario ausente, puerto ocupado, host inalcanzable, falta `HERMES_TEST_PORT` |
| `3` | PASS parcial | Alguna comprobación requerida se omitió por el modo (`SKIP`) |

Los scripts existentes `TC-030` a `TC-056` usan `1` para cualquier error. No es necesario
retroadaptarlos; a partir de `TC-057` se aplica esta tabla. Un `3` no es un fallo, pero tampoco
cierra la fila de trazabilidad como `PASS`.

---

## 5. Checklist antes de dar un caso por terminado

- [ ] La ficha `TC-0NN.md` existe y todos los criterios tienen etiqueta `[local]`, `[remoto]` o `[ambos]`.
- [ ] El script compila el binario o verifica que existe, y falla con un mensaje claro si no.
- [ ] `HOME`, `XDG_CONFIG_HOME` y el puerto están aislados; no se tocó el `HOME` real.
- [ ] `config.json` y `network.json` son limpios y `habilitada: true` (modo local).
- [ ] El arranque espera activamente la línea de escucha y el puerto, sin `sleep` fijo.
- [ ] `trap cleanup EXIT` detiene el servidor con `SIGTERM`, espera, mata el scheduler si quedó,
      verifica el puerto, verifica huérfanos y borra el temporal.
- [ ] Cada criterio imprime `PASS Vn/ACn: ...`; el caso termina con `PASS: <REQ> <TC> sin fallos.`
- [ ] `verif/results/results_TC-0NN.md` tiene una sección nueva, con la cerca cerrada.
- [ ] El script tiene LF y bit ejecutable.
- [ ] La matriz de trazabilidad y el índice están actualizados con el caso y la evidencia.
- [ ] En modo remoto, las comprobaciones de servidor están marcadas `SKIP` y el código es `3`.
- [ ] No se modificó nada de `src/`.

---

## 6. Anexos

### A. Constantes y límites

| Constante | Valor | Archivo |
| --- | --- | --- |
| `MAX_MENSAJE_RED` | 16 384 | `network_protocol.h` |
| `MAX_RESPUESTA_RED` | 262 144 | `network_protocol.h` |
| `MAX_PROFUNDIDAD_JSON` | 32 | `network_protocol.h` |
| `MAX_OPERACION_RED` | 32 | `network_protocol.h` |
| Clientes concurrentes | 32 | `server.cpp:488` |
| `listen` backlog | 10 | `server.cpp:167` |
| Inactividad de lectura/escritura | 3 s | `server.cpp:174` (constructor), `server.cpp:359,401` (renovación) |
| Plazo del cliente | 10 s | `client.cpp:143` |
| Ventana de aviso por motivo/código | 60 s | `server.cpp` (`avisoPermitido`, `rechazoPermitido`) |

### B. Códigos de error y efecto en la conexión

| Código | Capa | ¿Cierra la conexión? | `resultado` si se interrumpe |
| --- | --- | --- | --- |
| `INVALID_JSON`, `NUL_BYTE`, `INVALID_UTF8`, `TOO_DEEP`, `INVALID_REQUEST`, `INVALID_REQUEST_ID`, `INVALID_VERSION`, `UNSUPPORTED_VERSION`, `INVALID_OPERATION`, `INVALID_PARAMS` (protocolo), `UNKNOWN_OPERATION`, `MESSAGE_TOO_LARGE` | Protocolo/framing | Sí, tras responder | No emite `Solicitud interrumpida`; emite `Mensaje rechazado` |
| `INCOMPLETE_MESSAGE`, `REQUEST_TIMEOUT` | Framing | Sí | `SIN_EFECTO` |
| `UNAUTHORIZED`, `PROGRAM_NOT_ALLOWED`, `NOT_FOUND`, `NOT_CANCELABLE`, `INVALID_PARAMS` (operación), `JOB_OPERATION_FAILED`, `RESPONSE_TOO_LARGE` | Operación | No | `RECHAZADA` |
| `ok: true` | Operación | No | `ACEPTADA` |

Matices:

- `RESPONSE_TOO_LARGE` se produce después de ejecutar la operación y antes de serializar; no cierra
  la conexión, aunque el cliente oficial la trate como error y devuelva 1.
- `REQUEST_TIMEOUT` se emite con `request_id: null` y cierra. Si no hubo bytes, el desenlace es
  `SIN_EFECTO`.
- Un rechazo de formato se registra con ventana de 60 s por código; un rechazo de operación no deja
  evento si la respuesta se entrega normalmente.

### C. Puertos

| Rango | Uso |
| --- | --- |
| `45820` | Puerto por defecto del servidor y de la guía PC-A/PC-B |
| `45830`-`45833` | RF-28 (histórico) |
| `45840`-`45844` | RF-22 (histórico) |
| `45850`-`45863` | RNF-14, RNF-15, RNF-24 (histórico) |
| `45864`+ | Casos nuevos con puerto fijo documentado |
| Efímero | Valor por defecto en modo local; el kernel elige uno libre |

Nunca usar `45820` en un caso autocontenido: el operador puede tener su servidor activo ahí.

### D. Referencias

- `docs/technical-guide/2-Nucleo del proyecto/CONTEXTO-RED-ACTUAL.md`
- `docs/user-guide/red-wsl-pc-a-pc-b.md`
- `docs/technical-guide/2-Nucleo del proyecto/RF-18.operaciones-remotas.md`
- `docs/technical-guide/2-Nucleo del proyecto/RF-19.semantica-local-remota.md`
- `docs/technical-guide/2-Nucleo del proyecto/RF-20.restriccion-redes-direcciones.md`
- `docs/technical-guide/2-Nucleo del proyecto/RF-21.protocolo-delimitado-errores.md`
- `docs/technical-guide/2-Nucleo del proyecto/RF-22.desconexion-cliente.md`
- `docs/technical-guide/2-Nucleo del proyecto/RF-28.estado-coherente-desconexion.md`
- `docs/technical-guide/2-Nucleo del proyecto/RNF-13.acceso-remoto-LAN-VPN.md`
- `docs/technical-guide/2-Nucleo del proyecto/RNF-14.validacion-longitud-formato.md`
- `docs/technical-guide/2-Nucleo del proyecto/RNF-15.registros-sin-secretos.md`
- `docs/technical-guide/2-Nucleo del proyecto/RNF-24.mensajes-fragmentados-solicitudes-secuenciales.md`
- `docs/technical-guide/2-Nucleo del proyecto/RNF-26-demostracion-red-privada.md`
- `verif/scripts/TC-030.sh` a `TC-056.sh`
- `verif/test-cases/test-cases.md`
- `verif/verification-plan/traceability-matrix.md`
