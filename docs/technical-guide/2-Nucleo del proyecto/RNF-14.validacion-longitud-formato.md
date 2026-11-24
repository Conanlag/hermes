# RNF-14 — Validación de longitud y formato de todos los mensajes de red

## Descripción

RNF-14 es un requisito transversal: no describe una operación, sino una propiedad que deben cumplir **todos** los mensajes que cruzan el socket, en ambas direcciones. Antes de este requisito el servidor ya rechazaba lo evidente —un mensaje de más de 16384 bytes, un JSON que no parseaba—, pero lo hacía de forma desigual: el límite de respuesta vivía duplicado como el literal `262144` en dos archivos, la profundidad máxima se confundía con un JSON roto, ningún punto comprobaba UTF-8 ni bytes nulos de forma explícita, y el cliente no podía siquiera leer los errores de protocolo que el servidor emitía.

El cambio tiene dos mitades que se sostienen mutuamente. En el servidor, cada defecto de formato recibe un código propio y determinista, y el rechazo se documenta en la bitácora en el momento en que se produce. En el cliente, la respuesta entrante se valida con la misma severidad: longitud, delimitador, bytes nulos, JSON, versión y coherencia entre `ok`, `result` y `error`. Sin la segunda mitad, la primera sería inútil: un servidor que responde `MESSAGE_TOO_LARGE` a un cliente que aborta con `type_error.302` no ha diagnosticado nada.

El eje del requisito es que **un mensaje inválido nunca se confunda con otro tipo de inválido**. Saber que el rechazo fue por longitud, por UTF-8 corrupto, por anidamiento excesivo o por una clave prohibida es lo que convierte el rechazo en información utilizable.

---

## Objetivo

> El sistema deberá validar longitudes y formato de todos los mensajes de red.

**Consideraciones actuales:**

- **Sí hace:** aplica límites únicos y con nombre a petición (`16384`) y respuesta (`262144`); valida el mensaje crudo antes de interpretarlo (bytes nulos, UTF-8, longitud); limita el anidamiento JSON a 32 niveles con un código propio; rechaza claves desconocidas en el nivel superior del sobre; acota la longitud de `operation`; valida texto de red (NUL, controles C0, DEL y UTF-8) en `programa`, `argumentos`, `tipo` y `valor`; y valida en el cliente longitud, delimitador, NUL, JSON, versión y coherencia del sobre.
- **No hace:** no repara el mensaje ni intenta interpretarlo parcialmente; no aplica topes de longitud por campo de texto más allá del total del mensaje y los 128 de `request_id`; no implementa un canal de negociación de versión —`version: 1` sigue siendo obligatoria—; y no cambia el framing delimitado por `\n` —cuántas solicitudes caben en una conexión es competencia de RNF-24, no de este requisito—.
- **No cambia:** el sobre JSON (`version`, `request_id`, `ok`, `error`, `result`), el delimitador `\n`, los códigos de error existentes ni el esquema persistido de trabajos.

---

## Estructura del módulo

```text
src/hermes/
├── include/
│   ├── network_protocol.h      # Invariantes únicos del protocolo
│   └── validator.h             # utf8Valido + validarTextoRed
└── src/
    ├── network/
    │   ├── protocol.cpp        # Rechazo determinista del sobre
    │   ├── server.cpp          # Framing, longitud y registro del rechazo
    │   ├── client.cpp          # Validación de la petición y la respuesta
    │   └── remote.cpp          # Texto seguro en cada operación
    └── validator/
        └── validator.cpp       # Autómata UTF-8 y controles
```

| Archivo / directorio | Responsabilidad |
|---|---|
| `include/network_protocol.h` | Declara los cuatro invariantes numéricos del protocolo y el campo `formatoInvalido` del desenlace. |
| `include/validator.h` | Expone `utf8Valido()` y `validarTextoRed()` para que servidor y cliente compartan un único criterio de texto válido. |
| `src/network/protocol.cpp` | Rechaza el mensaje crudo y el sobre con un código por defecto, antes de cualquier despacho. |
| `src/network/server.cpp` | Corta en el límite de entrada, decide qué se registra y con qué frecuencia. |
| `src/network/client.cpp` | No envía una petición fuera de límite y no acepta una respuesta incoherente. |
| `src/network/remote.cpp` | Aplica `validarTextoRed()` a cada campo de texto de cada operación. |
| `src/validator/validator.cpp` | Autómata UTF-8 estricto y detección de controles. |

---

## Definición de los códigos de rechazo

Todos son constantes generadas por el servidor, nunca texto del cliente.

| Código | Disparador | `request_id` en la respuesta |
|---|---|---|
| `MESSAGE_TOO_LARGE` | Mensaje o línea de más de `MAX_MENSAJE_RED` | `null` |
| `NUL_BYTE` | Byte `0x00` en cualquier posición del mensaje | `null` |
| `INVALID_UTF8` | Secuencia UTF-8 inválida en el mensaje | `null` |
| `TOO_DEEP` | Anidamiento JSON mayor que `MAX_PROFUNDIDAD_JSON` | `null` |
| `INVALID_JSON` | JSON no parseable | `null` |
| `INVALID_REQUEST` | Raíz no objeto, o clave desconocida en el nivel superior | `null` |
| `INVALID_REQUEST_ID` | `request_id` ausente, no string o fuera de `[A-Za-z0-9._:-]` | `null` si no se pudo leer |
| `INVALID_VERSION` / `UNSUPPORTED_VERSION` | `version` ausente o distinta de `1` | el del cliente |
| `INVALID_OPERATION` | `operation` ausente, no string, vacía o de más de 32 bytes | el del cliente |
| `INVALID_PARAMS` | `params` ausente, no objeto, o no vacío en `ping` | el del cliente |
| `UNKNOWN_OPERATION` | Operación válida sintácticamente pero no despachable | el del cliente |
| `RESPONSE_TOO_LARGE` | La respuesta serializada excede `MAX_RESPUESTA_RED` | el del cliente |

La distinción importa en dos sentidos. Primero, `TOO_DEEP` deja de confundirse con `INVALID_JSON`: un ataque de anidamiento y un mensaje truncado son problemas distintos. Segundo, solo los rechazos de **protocolo** marcan `formatoInvalido`; un `UNAUTHORIZED`, un `NOT_FOUND` o un `RESPONSE_TOO_LARGE` siguen siendo desenlaces de negocio y conservan el registro de RF-28 como `Solicitud interrumpida`.

---

## Implementación de `.h`

```cpp
constexpr unsigned MAX_MENSAJE_RED = 16384;        // payload máximo de petición
constexpr unsigned MAX_RESPUESTA_RED = 262144;     // payload máximo de respuesta
constexpr int MAX_PROFUNDIDAD_JSON = 32;           // anidamiento máximo aceptado
constexpr unsigned MAX_OPERACION_RED = 32;         // longitud máxima de "operation"
```

`DetalleSolicitud` gana un booleano que separa las dos familias de rechazo:

```cpp
struct DetalleSolicitud {
    bool procesada = false;
    bool aceptada = false;
    bool formatoInvalido = false;  // rechazo de protocolo, no llegó al despachador
    std::string requestId;
    std::string operacion;
    std::string error;
    unsigned jobId = 0;
};
```

No se declara un `enum` de códigos porque el código viaja como cadena hasta el sobre JSON y hasta la bitácora; un `enum` obligaría a mantener dos representaciones sincronizadas. Las constantes, en cambio, sí son tipos con nombre: son la única fuente de verdad y eliminan los literales duplicados.

---

## Implementación de `.cpp`

### `src/network/protocol.cpp` — orden del rechazo

El intérprete valida primero el mensaje crudo, sin parser de por medio:

1. `mensaje.size() > MAX_MENSAJE_RED` → `MESSAGE_TOO_LARGE`.
2. `mensaje.find('\0')` → `NUL_BYTE`. Va antes que la comprobación de UTF-8 porque `0x00` es UTF-8 válido y se perdería.
3. `utf8Valido(mensaje)` → `INVALID_UTF8`.
4. `json::parse` con callback de profundidad. El callback lanza `ProfundidadExcesiva`, un tipo propio capturado **antes** del `catch` genérico, de modo que el exceso de anidamiento responde `TOO_DEEP` y no `INVALID_JSON`.
5. Raíz no objeto → `INVALID_REQUEST`; recorrido de claves del nivel superior fuera de `{version, request_id, operation, params}` → `INVALID_REQUEST`.
6. El orden existente del sobre se conserva: `request_id`, `version`, `operation` (ahora también acotada a 32 bytes), `params`, `ping`, despacho remoto.

Dos lambdas separan los rechazos según lo que se puede afirmar del cliente:

```cpp
// Rechazo previo a disponer de un request_id válido.
auto rechazo = [&](const char* codigo) {
    detalle.procesada = true;
    detalle.formatoInvalido = true;
    detalle.error = codigo;
    return errorProtocolo(codigo);   // request_id: null
};
// Rechazo con request_id ya interpretado y validado.
auto rechazoConId = [&](const char* codigo) {
    detalle.formatoInvalido = true;
    return responder(codigo);        // request_id: el del cliente
};
```

La consecuencia deliberada: si un mensaje trae un `request_id` válido pero además una clave desconocida, la respuesta cita `null`. Cuando el sobre entero es dudoso, el identificador del cliente tampoco es confiable.

`errorProtocolo()` no se toca: sigue emitiendo `{"version":1,"request_id":null,"ok":false,"error":<codigo>}`. Lo que cambia es que ahora hay un cliente capaz de leerlo.

### `src/network/server.cpp` — framing y registro

El bucle conserva el buffer de 4096 y las dos condiciones de longitud, que cubren los dos caminos reales:

```cpp
if ((fin == std::string::npos && cliente.entrada.size() > MAX_MENSAJE_RED) ||
    (fin != std::string::npos && fin > MAX_MENSAJE_RED)) {
    cliente.detalle.procesada = true;
    cliente.detalle.formatoInvalido = true;
    cliente.detalle.error = "MESSAGE_TOO_LARGE";
    registrarRechazo(cliente, static_cast<unsigned>(cliente.entrada.size()));
    responder(cliente, errorProtocolo("MESSAGE_TOO_LARGE"));
}
```

El primer caso corta antes de encontrar el delimitador; el segundo, cuando el delimitador aparece más allá del límite. Ambos producen el mismo código y el mismo registro.

**Nota de vigencia:** RNF-24 trasladó estas comprobaciones a un bucle que atiende varios mensajes por conexión y las expresó por mensaje (`fin > MAX_MENSAJE_RED`) en lugar de por búfer total. La decisión que documenta este apartado —código único, registro en el rechazo y cierre del descriptor— no cambió.

El registro ocurre **en el rechazo**, no al cerrar la conexión, porque en ese instante el diagnóstico ya existe y el cliente puede desaparecer antes de que la conexión se clasifique:

```cpp
auto registrarRechazo = [](const Cliente& cliente, unsigned bytes) noexcept {
    try {
        if (!rechazoPermitido(cliente.detalle.error)) return;
        nlohmann::json contexto{
            {"ip", cliente.ip}, {"identidad", cliente.identidad},
            {"codigo", cliente.detalle.error}, {"bytes_recibidos", bytes},
            {"motivo", textoMotivo(cliente.motivo)}
        };
        (void)EventLog::log_event_system(EventLevel::WARN, "Mensaje rechazado", contexto);
    } catch (...) {
        // El registro nunca puede tumbar el hilo de red.
    }
};
```

La ventana de 60 s es una tabla fija de doce códigos, con un sello de tiempo por código. El primero de cada código siempre se registra; los siguientes esperan su minuto. Un código ausente de la tabla se registra siempre, porque lo genera el servidor y no puede usarse para saturar la bitácora.

`registrar()` (RF-28) retorna de inmediato si `formatoInvalido` está activo, para no documentar dos veces el mismo rechazo. Los desenlaces de negocio no se ven afectados: su `formatoInvalido` es `false` y siguen apareciendo como `Solicitud interrumpida`.

**Bytes posteriores al primer `\n`:** cuando RNF-14 se implementó se descartaban con la conexión, porque el protocolo era de un mensaje por conexión. **RNF-24 sustituyó ese comportamiento**: los bytes posteriores al delimitador quedan en el búfer como solicitud siguiente y se validan de forma independiente, con las mismas reglas de este documento. La garantía de RNF-14 se mantiene intacta —ningún sobre se procesa sin validar—; lo que cambia es dónde termina la conexión. El rechazo de formato sigue cerrando el descriptor tras responder, para que el flujo no quede desincronizado.

### `src/network/client.cpp` — la mitad que faltaba

El envío valida el payload sin el delimitador:

```cpp
const auto carga = json({...}).dump();
if (carga.size() > MAX_MENSAJE_RED)
    throw std::invalid_argument("Solicitud demasiado grande: excede el máximo de la red");
```

La recepción valida, en este orden: tamaño contra `MAX_RESPUESTA_RED`; presencia de `\n`; byte nulo en el cuerpo; parseo JSON en `try/catch` con mensaje propio; y coherencia del sobre:

```cpp
if (!recibida.contains("version") || !recibida["version"].is_number_integer() ||
    recibida["version"] != 1) throw invalida("version ausente o distinta de 1");
if (!recibida.contains("request_id")) throw invalida("falta request_id");
// Un request_id nulo solo lo emite errorProtocolo(): es un sobre de error.
const bool idNulo = recibida["request_id"].is_null();
if (!idNulo && !recibida["request_id"].is_string()) throw invalida("request_id con tipo no válido");
if (!idNulo && recibida["request_id"].get<std::string>() != id) throw invalida("request_id no coincide");
if (!recibida.contains("ok") || !recibida["ok"].is_boolean()) throw invalida("ok ausente o no booleano");
const bool aceptada = recibida["ok"].get<bool>();
if (idNulo && aceptada) throw invalida("sobre de error con ok verdadero");
if (aceptada) {
    if (!recibida.contains("result") || !recibida["result"].is_object())
        throw invalida("result ausente o no es objeto");
} else if (!recibida.contains("error") || !recibida["error"].is_string() ||
           recibida["error"].get<std::string>().empty()) {
    throw invalida("error ausente o vacío");
}
```

El caso `idNulo` es la corrección central. El código anterior hacía `recibida.value("request_id", std::string{})`, y `value()` con una clave presente y `null` llama a `get<std::string>()`: `type_error.302`. El resultado era que **ningún** error de protocolo llegaba al usuario con su diagnóstico.

### `src/network/remote.cpp` y `src/validator/validator.cpp` — texto seguro

`utf8Valido()` es un autómata estricto: rechaza secuencias truncadas, continuaciones aisladas, `0xC0`/`0xC1`, `0xF5`-`0xFF`, sobrecarga en `E0`/`F0` y surrogates en `ED A0-BF`. `validarTextoRed()` añade el rechazo de `0x00`, de todo control C0 —incluidos `\t`, `\n` y `\r`— y de `0x7F`.

Se aplica a `programa`, a cada elemento de `argumentos`, y a `tipo` y `valor` del filtro. Esto cierra una inconsistencia real: `submit` ya rechazaba `\0` en `programa`, pero el filtro `list` con `tipo: "programa"` lo aceptaba, porque solo pasaba por `validarPrograma()`, que únicamente rechaza vacío.

---

## Integración con otros Requisitos Funcionales

- **RF-28 — Estado coherente ante desconexión.** RNF-14 añade un segundo evento, `Mensaje rechazado`, y evita que el rechazo de formato se duplique como `Solicitud interrumpida`. Los desenlaces de negocio conservan intacta su semántica.
- **RF-22 — Desconexión del cliente.** No se altera el framing, el cierre por motivo ni la frontera de excepción por cliente.
- **RF-14 — Bitácora de eventos.** Se reutiliza `EventLevel::WARN` con la estructura `message` + `context`; no se añaden niveles ni formatos.
- **RF-23 / RF-25 — Límites y cola.** El rechazo por longitud es anterior al despacho: un mensaje excesivo nunca llega a evaluar cupo ni cola.

---

## Ejemplo de funcionamiento

### Un rechazo por cada defecto

```text
$ bash verif/scripts/TC-039.sh
  json roto              -> INVALID_JSON
  byte nulo              -> NUL_BYTE
  utf-8 invalido         -> INVALID_UTF8
  profundidad 40         -> TOO_DEEP
  clave superior extra   -> INVALID_REQUEST
  operacion 40 bytes     -> INVALID_OPERATION
  params de ping         -> INVALID_PARAMS
  16392 bytes            -> MESSAGE_TOO_LARGE
  request_id invalido    -> INVALID_REQUEST_ID
  operacion desconocida  -> UNKNOWN_OPERATION
  byte nulo (repeticion) -> NUL_BYTE
```

El undécimo mensaje es idéntico al segundo: el cliente recibe su código, pero la ventana impide un segundo evento.

### La línea literal de la bitácora

```json
{"context": {"bytes_recibidos": 69, "codigo": "UNKNOWN_OPERATION", "identidad": "tcp-PC-B",
"ip": "127.0.0.1", "motivo": "CIERRE_NORMAL"}, "job_id": null, "level": "WARN",
"message": "Mensaje rechazado", "ts": "2026-11-19 21:20:20"}
```

`motivo` vale `CIERRE_NORMAL` porque en el instante del rechazo la conexión todavía no se ha clasificado. Es el valor real, no un hueco: el rechazo describe el mensaje, no el cierre.

### El cliente ante un sobre de error

```text
$ hermes red job 127.0.0.1 true
Hermes Red: MESSAGE_TOO_LARGE
```

Antes de RNF-14 esa misma respuesta producía `Hermes Red: [json.exception.type_error.302] type must be string, but is null`.

### El cliente ante una respuesta mal formada

```text
  sin_delimitador  -> Hermes Red: El servidor cerró o rechazó la conexión
  excesiva         -> Hermes Red: Respuesta demasiado grande: excede el máximo de la red
  nulo             -> Hermes Red: Respuesta inválida del servidor: contiene un byte nulo
  version          -> Hermes Red: Respuesta inválida del servidor: version ausente o distinta de 1
  sin_result       -> Hermes Red: Respuesta inválida del servidor: result ausente o no es objeto
  sin_error        -> Hermes Red: Respuesta inválida del servidor: error ausente o vacío
  json_roto        -> Hermes Red: Respuesta inválida del servidor: JSON mal formado
```

---

## Verificación

Cuatro casos automatizados nuevos, ejecutados el 2026-11-19 en WSL Ubuntu. Todos en `PASS`.

| Caso | Escenario | Resultado observado |
|---|---|---|
| **TC-039** | Diez formatos inválidos + repetición de uno | Los diez códigos propios; `10` eventos para `10` códigos; ningún duplicado como `Solicitud interrumpida`; `ping` posterior correcto |
| **TC-040** | Cliente contra tres sobres con `request_id: null` | `MESSAGE_TOO_LARGE`, `REQUEST_TIMEOUT` y `RESPONSE_TOO_LARGE` reportados con su código; sin `json.exception` |
| **TC-041** | Cliente contra siete respuestas mal formadas | Las siete rechazadas con diagnóstico propio; sin `json.exception`, `type_error` ni `[json` |
| **TC-042** | Sobre válido y sobre inválido en un solo `write` | El válido responde y crea `1` Job; el inválido responde `UNSUPPORTED_VERSION` y no deja rastro (caso reescrito por RNF-24, que ya no descarta el segundo mensaje) |

**Regresión.** TC-030 a TC-038 (RF-22 y RF-28) se reejecutaron y siguen en `PASS`, trece scripts en total. Compilación completa con `g++ -Wall -Wextra -std=c++17` sin advertencias.

Scripts en `verif/scripts/TC-039.sh`…`TC-042.sh`; evidencia en `verif/results/results_TC-039.md`…`results_TC-042.md`; descripciones en `verif/test-cases/TC-039.md`…`TC-042.md`; fila RNF-14 de `verif/verification-plan/traceability-matrix.md` en `PASS`.

---

## Riesgo residual

**R3 — la ventana de 60 s oculta repeticiones de un mismo código.** El registro de rechazos comparte la filosofía de RF-22: amortiguar el ruido sin perder el primer diagnóstico. Un emisor que insista en un mismo defecto deja un evento por minuto, de modo que un conteo exacto de intentos no es posible desde la bitácora. El volumen queda acotado por el cupo de conexiones y el plazo de lectura, y la alternativa —registrar cada rechazo— convierte un flood de mensajes malformados en un flood de `fsync`. Si en el futuro se necesita el conteo exacto, la salida no es quitar la ventana, sino agregar contadores por código en un registro periódico.

---

## Historial

| Fecha | Cambio |
|---|---|
| 2026-11-19 | Implementación de RNF-14: invariantes únicos, rechazo determinista de formato y longitud, validación del texto de red, validación completa del cliente, registro acotado de rechazos y casos TC-039…TC-042 |
