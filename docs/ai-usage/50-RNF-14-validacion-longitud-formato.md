# Uso de inteligencia artificial

# 50. RNF-14 — Validación de longitud y formato de mensajes de red

## Objetivo

Implementar RNF-14, un requisito no funcional transversal: todo mensaje que cruza el socket debe tener longitud y formato validados, en el servidor y en el cliente. A diferencia de RF-22 o RF-28, que se concentraban en un módulo, aquí el trabajo se reparte entre seis archivos que no comparten un ciclo de vida: `network_protocol.h`, `protocol.cpp`, `server.cpp`, `remote.cpp`, `client.cpp` y `validator.cpp`.

La auditoría previa era obligatoria. El requisito habla de "todos los mensajes", y sin un inventario exacto de puntos de entrada y salida es fácil endurecer el servidor y dejar el cliente ciego, o al revés.

---

## Prompt 1

```text
Actúa como arquitecto técnico supervisor (gentle-orchestrator). Tu objetivo es auditar el
subsistema de red existente y completar la implementación del requisito no funcional RNF-14 —
Validación de longitud y formato de mensajes: El sistema deberá validar longitudes y formato de
todos los mensajes de red.

Fase 1: Auditoría transversal de longitudes y formato (Servidor y Cliente)
... Revisa las constantes de longitud (MAX_MENSAJE_RED = 16384 y el límite de respuesta 262144
hoy duplicado como número mágico).
... Verifica la validación de codificación UTF-8, profundidad máxima de JSON (32 niveles),
detección de bytes nulos embebidos, validación de tipos y rangos del sobre...
... src/hermes/src/network/server.cpp: framing por delimitador, acumulación en bloques de 4096,
corte al superar el límite y delimitador más allá del límite...
... Verifica que si un cliente envía bytes adicionales o un segundo mensaje tras el primer salto
de línea, se procese estrictamente un único mensaje...
... src/hermes/src/network/remote.cpp: todas las operaciones validen forma del objeto params,
cantidad exacta de claves permitidas, tipos, rangos y ausencia de caracteres nulos...
... src/hermes/src/network/client.cpp: longitud máxima de la petición antes de enviar y
validación de las respuestas (262144, delimitador, bytes nulos, JSON, version == 1, coherencia
ok/result/error, y compatibilidad con request_id null en errores de framing)...

Fase 2: Implementación y endurecimiento para RNF-14
... Centralización de invariantes de protocolo (network_protocol.h)...
... Validación estricta de longitud y framing en ambos extremos...
... Validación exhaustiva de formato y resolución de errores de protocolo...
... Corrige la incompatibilidad entre errorProtocolo() (request_id null) y la validación de
respuesta del cliente para que errores reales como MESSAGE_TOO_LARGE, INVALID_JSON,
REQUEST_TIMEOUT o RESPONSE_TOO_LARGE se reporten con su diagnóstico correcto...
... Observabilidad segura de rechazos con log_event_system, sin excepciones y con limitación de
frecuencia...
... Mantiene compatibilidad total con el protocolo JSON version 1 y delimitador de salto de línea,
preservando intactas las garantías de atomicidad de storage.cpp y scheduler.cpp.

Presenta tu plan y pide mi autorización para la implementación.
```

---

## Resultado 1

La auditoría se delegó a un explorador de solo lectura con mandato de citar `ruta:línea` en cada afirmación. Devolvió un inventario de veintidós puntos y, con él, dos defectos que el requisito no anticipaba:

1. **`client.cpp` no podía leer ningún error de protocolo.** `errorProtocolo()` emite siempre `"request_id": null`, y el cliente hacía `recibida.value("request_id", std::string{})`; con la clave presente y nula, `value()` invoca `get<std::string>()` y lanza `type_error.302`. El resultado era que `MESSAGE_TOO_LARGE`, `INVALID_JSON`, `REQUEST_TIMEOUT` y `RESPONSE_TOO_LARGE` nunca llegaban al usuario con su código.
2. **El filtro `list` aceptaba `\u0000`.** `submit` filtraba NUL en `programa` y en cada argumento, pero la ruta de filtro solo pasaba por `validarPrograma()`, que únicamente rechaza vacío. El mismo valor era válido por un camino e inválido por otro.

El plan propuso cuatro constantes con nombre, un autómata UTF-8 compartido, tres códigos nuevos (`NUL_BYTE`, `INVALID_UTF8`, `TOO_DEEP`), rechazo de claves desconocidas en el sobre y una validación completa de la respuesta en el cliente. También explicitó un conflicto con RF-28: la ventana de 60 s pedida para los rechazos no podía aplicarse a solicitudes procesadas, así que se acotó a los rechazos de protocolo, dejando intacto el registro de desenlaces de negocio.

---

## Prompt 2

```text
si
```

---

## Resultado 2

La implementación se delegó a un escritor único con superficies de edición explícitas (siete archivos) y verificación obligatoria: compilación limpia con `-Wall -Wextra` y regresión TC-030…TC-038. Volvió con estado `completado`, cero advertencias y nueve scripts en `PASS`.

La verificación del orquestador no se limitó a aceptar el informe. Se recompiló desde cero con `make -B` y se leyeron las regiones modificadas de `protocol.cpp`, `server.cpp`, `client.cpp` y `validator.cpp`. Después se escribieron cuatro casos nuevos y se ejecutaron. **TC-041 falló en su primera corrida**, y el fallo era real:

```text
Hermes Red: Respuesta inválida del servidor: [json.exception.parse_error.101]
parse error at line 1, column 2: syntax error while parsing object key ...
```

El escritor había envuelto `json::parse` en `try/catch`, pero el mensaje propagaba `detalle.what()`, es decir, el texto interno de `nlohmann::json`. La excepción ya no escapaba como excepción, pero su diagnóstico crudo sí llegaba al usuario: exactamente la mitad del problema que RNF-14 pedía eliminar. Se corrigió con un mensaje propio —`"Respuesta inválida del servidor: JSON mal formado"`—, se recompiló y se reejecutó la batería completa.

---

# Modificaciones

**Estado de la resolución:** **[Modificado]** — el diseño y la implementación fueron correctos en casi su totalidad, pero el cliente seguía filtrando el texto interno de la librería de JSON, descubierto por una prueba que no existía cuando el escritor terminó.

**Revisión realizada:** tres niveles de verificación, en este orden. Primero, auditoría independiente de solo lectura antes de diseñar. Segundo, compilación forzada desde cero (`make -B`) para descartar que el "sin advertencias" del escritor dependiera de objetos ya compilados. Tercero, pruebas nuevas diseñadas para atacar exactamente los casos que el informe declaraba resueltos: si el cliente "ya no muestra excepciones crudas", una prueba debe buscar la cadena `json.exception` en su salida. La prueba encontró lo que la inspección visual no habría encontrado.

También se verificaron a mano dos decisiones del escritor que no estaban en la especificación: marcar `formatoInvalido` en **todos** los rechazos de sobre (no solo en los tres nuevos) para que la tabla de la ventana no quedara medio muerta, y responder `request_id: null` cuando un sobre trae un identificador válido más una clave desconocida, porque la comprobación de claves precede a la confianza en el identificador. Ambas son coherentes y quedaron documentadas.

**Cambios aplicados:**

1. `client.cpp`: el `catch` de `json::parse` ya no concatena `detalle.what()`; emite `"Respuesta inválida del servidor: JSON mal formado"`.
2. `network_protocol.h`: cuatro constantes con nombre y campo `DetalleSolicitud::formatoInvalido`.
3. `validator.cpp` / `validator.h`: `utf8Valido()` (autómata estricto con control de sobrecarga y surrogates) y `validarTextoRed()` (NUL, C0, DEL, UTF-8); mensaje de `validarRequestId` corregido para mencionar `:`.
4. `protocol.cpp`: orden tamaño → NUL → UTF-8 → parseo con `ProfundidadExcesiva` → raíz → claves superiores → sobre; `TOO_DEEP`, `NUL_BYTE`, `INVALID_UTF8` como códigos propios; `operation` acotada a 32 bytes.
5. `server.cpp`: limitador fijo de 60 s por código, `registrarRechazo()` dentro de `try/catch (...)`, evento `Mensaje rechazado` y retorno temprano en `registrar()` para no duplicar.
6. `remote.cpp`: `validarTextoRed()` sobre `programa`, `argumentos`, `tipo` y `valor`; eliminados los `find('\0')` redundantes.
7. `client.cpp`: validación completa de la respuesta (tamaño, delimitador, NUL, parseo, versión, `request_id` nulo o coincidente, `ok` booleano, `result` objeto y `error` no vacío).

**Prueba agregada:** `TC-039` (diez formatos inválidos con su código y ventana por código), `TC-040` (cliente contra `request_id: null`), `TC-041` (siete respuestas mal formadas), `TC-042` (dos sobres en un `write`). Las cuatro en `PASS`, más la regresión TC-030…TC-038, trece scripts en total. La batería se ejecuta en WSL Ubuntu con puertos propios (`45850`–`45853`) y `HOME` temporal.

---

## Implementación de feature

El requisito se resuelve con una asimetría deliberada: el servidor valida el mensaje **crudo** antes de interpretarlo, y el cliente valida la respuesta **estructurada** después de parsearla. No es un capricho: el servidor recibe bytes de un par no confiable y debe decidir si merecen llegar al parser; el cliente recibe un sobre de un servidor en el que confía para responder, pero no para definir el formato.

```text
petición:  bytes -> NUL -> UTF-8 -> longitud -> JSON -> sobre -> despacho
respuesta: bytes -> longitud -> '\n' -> NUL -> JSON -> sobre -> uso
```

El punto donde ambas cadenas se encuentran es `errorProtocolo()`: emite `request_id: null` y hasta RNF-14 el cliente no podía interpretarlo. Ese único detalle convertía todos los errores de protocolo en ruido.

| Capa | Qué garantiza |
|---|---|
| `network_protocol.h` | Un solo lugar define los límites; ningún literal duplicado |
| `protocol.cpp` | Un código distinto por defecto distinto, sin ambigüedad |
| `server.cpp` | Corte exacto en el límite y registro del rechazo en el momento en que ocurre |
| `remote.cpp` | Texto seguro en cada campo de cada operación |
| `client.cpp` | No envía fuera de límite y no acepta una respuesta incoherente |
| `validator.cpp` | Un único criterio de UTF-8 y controles para ambos extremos |

---

## Modificación de archivo

**`include/network_protocol.h`** — invariantes únicos:

```cpp
constexpr unsigned MAX_MENSAJE_RED = 16384;        // payload máximo de petición
constexpr unsigned MAX_RESPUESTA_RED = 262144;     // payload máximo de respuesta
constexpr int MAX_PROFUNDIDAD_JSON = 32;           // anidamiento máximo aceptado
constexpr unsigned MAX_OPERACION_RED = 32;         // longitud máxima de "operation"
```

**`src/network/protocol.cpp`** — el rechazo crudo precede al parser:

```cpp
if (mensaje.size() > MAX_MENSAJE_RED) return rechazo("MESSAGE_TOO_LARGE");
if (mensaje.find('\0') != std::string::npos) return rechazo("NUL_BYTE");
if (!utf8Valido(mensaje)) return rechazo("INVALID_UTF8");
try {
    solicitud = json::parse(mensaje, [](int profundidad, json::parse_event_t, json&) {
        if (profundidad > MAX_PROFUNDIDAD_JSON) throw ProfundidadExcesiva{};
        return true;
    });
} catch (const ProfundidadExcesiva&) {
    return rechazo("TOO_DEEP");
} catch (const std::exception&) {
    return rechazo("INVALID_JSON");
}
```

**`src/network/server.cpp`** — ventana fija por código:

```cpp
static constexpr std::array<const char*, 12> CODIGOS{{
    "MESSAGE_TOO_LARGE", "NUL_BYTE", "INVALID_UTF8", "TOO_DEEP", "INVALID_JSON",
    "INVALID_REQUEST", "INVALID_REQUEST_ID", "INVALID_VERSION", "UNSUPPORTED_VERSION",
    "INVALID_OPERATION", "INVALID_PARAMS", "UNKNOWN_OPERATION"
}};
if (usado[indice] && ahora - ultimo[indice] < std::chrono::seconds(60)) return false;
```

**`src/network/client.cpp`** — el sobre de error de protocolo:

```cpp
const bool idNulo = recibida["request_id"].is_null();
if (!idNulo && !recibida["request_id"].is_string()) throw invalida("request_id con tipo no válido");
if (!idNulo && recibida["request_id"].get<std::string>() != id) throw invalida("request_id no coincide");
if (idNulo && aceptada) throw invalida("sobre de error con ok verdadero");
```

**`src/validator/validator.cpp`** — autómata con control de sobrecarga y surrogates:

```cpp
if (byte >= 0xE0 && byte <= 0xEF) {
    continuaciones = 2;
    if (byte == 0xE0) primerMinimo = 0xA0;  // evita sobrecarga
    if (byte == 0xED) primerMaximo = 0x9F;  // evita surrogates
}
```

---

## Implementación final

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
  registros 'Mensaje rechazado': 10 de 10 códigos, sin duplicados
PASS: RNF-14 TC-039 sin fallos.

$ bash verif/scripts/TC-040.sh
  cliente -> MESSAGE_TOO_LARGE
  cliente -> REQUEST_TIMEOUT
  cliente -> RESPONSE_TOO_LARGE
PASS V2/AC2: ninguna excepción cruda de JSON llega al usuario.
PASS: RNF-14 TC-040 sin fallos.

$ bash verif/scripts/TC-041.sh
  json_roto        -> Hermes Red: Respuesta inválida del servidor: JSON mal formado
PASS V1/AC1: las siete respuestas inválidas se rechazan con diagnóstico claro.
PASS: RNF-14 TC-041 sin fallos.

$ bash verif/scripts/TC-042.sh
  jobs.json: 1 Job, sin rastro del segundo mensaje
PASS: RNF-14 TC-042 sin fallos.
```

Regresión: TC-030 a TC-038 en `PASS` con el binario nuevo. Trece scripts, cero fallos.

---

## Aprendizaje

**Una prueba que busque la cadena prohibida vale más que una revisión que la dé por ausente.** El escritor "envolvió el parseo en un `try/catch`", y eso es cierto. Pero seguía concatenando `detalle.what()`, de modo que el usuario recibía `[json.exception.parse_error.101]`. La prueba no preguntaba "¿hay un try/catch?"; preguntaba "¿aparece `json.exception` en la salida?". Esa diferencia es la que encontró el defecto.

**Un `try/catch` correcto puede dejar pasar exactamente el problema que lo motivó.** Es la trampa del arreglo superficial: la excepción ya no se propaga, pero su mensaje sí. Cuando el requisito habla de lo que ve el usuario, la frontera no es el `throw`, es el texto final.

**Los requisitos transversales obligan a auditar antes de tocar.** El defecto del `list` con `\u0000` no estaba en la superficie del requisito: estaba en una asimetría entre dos rutas que validan el mismo valor de forma distinta. Sin inventario previo, la implementación habría endurecido `protocol.cpp` y dejado `remote.cpp` como estaba.

**Sobre Prompt Engineering.** El prompt del usuario fue largo y enumerativo, con dos fases explícitas. Eso funcionó porque cada punto nombraba archivo y comportamiento esperado, no intención general ("mejorar la seguridad de la red"). Cuando el requisito enumera, conviene responder con un inventario y no con una narrativa: la auditoría citó `ruta:línea` en las veintidós respuestas, y esa granularidad es lo que permitió convertir el plan en superficies de edición exactas para el escritor.
