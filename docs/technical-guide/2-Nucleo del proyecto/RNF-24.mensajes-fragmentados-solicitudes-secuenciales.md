# RNF-24 — Mensajes fragmentados y múltiples solicitudes secuenciales

## Descripción

RNF-24 exige que el protocolo funcione cuando un mensaje llega partido en varios segmentos y cuando una misma conexión transporta más de una solicitud. Antes de este requisito, el servidor ya acumulaba fragmentos —el bucle buscaba `\n` en un búfer—, pero la promesa era incompleta en los dos extremos del mismo eje: el plazo de lectura era **absoluto** (tres segundos desde `accept`), de modo que un mensaje fragmentado que tardaba más se cortaba a mitad aunque avanzara; y al encontrar el primer delimitador el servidor respondía y cerraba, descartando cualquier byte posterior. El cliente, por su parte, abría una conexión por cada petición y no conservaba bytes sobrantes.

El cambio tiene dos mitades. En el servidor, una conexión pasa a ser una **secuencia de transacciones**: cada mensaje completo se atiende en orden, la respuesta se entrega antes de consumir el siguiente, y la conexión sobrevive mientras el flujo esté sincronizado. En el cliente, una invocación del CLI reutiliza un solo socket mientras encadene solicitudes —hoy, la paginación de `red filter`— y conserva los bytes que lleguen más allá de la respuesta esperada.

El eje del requisito es la **frontera de la transacción**: qué bytes pertenecen a qué solicitud, qué desenlace se documenta de cada una y cuándo la conexión deja de ser confiable. Todo lo demás —el sobre, los códigos de error, los límites, la validación— queda igual.

---

## Objetivo

> El protocolo deberá funcionar con mensajes fragmentados y múltiples solicitudes secuenciales.

**Consideraciones actuales:**

- **Sí hace:** acumula fragmentos hasta el delimitador sin plazo absoluto; atiende varias solicitudes por conexión en orden FIFO, de una en una; conserva los bytes posteriores al delimitador como la solicitud siguiente; renueva el plazo de inactividad con cada fragmento y con cada respuesta entregada; trata el fin de flujo con el búfer sincronizado como cierre normal; mantiene el cierre tras cualquier rechazo de protocolo; y reutiliza una conexión por invocación del cliente con un único reintento transparente para la paginación de solo lectura.
- **No hace:** no multiplexa solicitudes concurrentes dentro de una conexión —son estrictamente secuenciales—, no añade un protocolo de longitud explícita ni un canal de negociación, no reordena ni combina respuestas, y no reintenta `submit` ni `cancel`: una escritura fallida en esas operaciones sigue siendo un error del usuario.
- **No cambia:** el sobre JSON, el delimitador `\n`, los códigos de error, los límites de 16 KiB/256 KiB, el modelo de un solo hilo con `poll()`, el cupo de 32 clientes, la autorización por IP ni el esquema persistido de trabajos.

---

## Estructura del módulo

```text
src/hermes/src/network/
├── server.cpp     # Bucle por cliente: lectura, atención y escritura alternadas
├── client.cpp     # Socket reutilizable, bytes residuales y reintento de solo lectura
├── protocol.cpp   # Sin cambios: valida cada mensaje de forma independiente
└── remote.cpp     # Sin cambios: despacho por operación
```

| Archivo | Responsabilidad |
|---|---|
| `src/network/server.cpp` | Define la transacción, el orden de atención, los plazos y el cierre. Es el único archivo con el bucle de eventos. |
| `src/network/client.cpp` | Mantiene el socket y el búfer residual durante la invocación; reconecta solo si la consulta es paginable y ya obtuvo una respuesta. |
| `src/network/protocol.cpp` | No se tocó: `procesarSolicitudRedDetallada()` es sin estado y valida cada mensaje por separado, que es exactamente lo que RNF-24 necesita. |
| `src/network/remote.cpp` | No se tocó: cada operación recibe ya un mensaje completo. |

Que `protocol.cpp` no cambiara es el resultado más importante del diseño. El validador nunca supo de conexiones: recibe un mensaje y devuelve un sobre. RNF-24 solo tenía que entregarle mensajes completos y en orden. Si hubiera hecho falta modificarlo, la separación entre transporte y protocolo habría sido ficticia.

---

## Modelo de la conexión

Cada cliente avanza por una máquina de tres estados, y el bucle repite mientras haya progreso inmediato:

```text
              ┌──────────── recv() ────────────┐
              ▼                                │
        ┌──────────┐   '\n' completo   ┌───────────────┐
        │  LEER    │ ────────────────► │   ATENDER     │
        └──────────┘                   └───────────────┘
              ▲                                │ respuesta encolada
              │                                ▼
              │                        ┌───────────────┐
              └──── respuesta ────────│   ESCRIBIR    │
                    entregada          └───────────────┘
                                       rechazo → cerrar
```

Las tres reglas que sostienen el modelo:

1. **No se lee mientras hay una respuesta pendiente.** Si `salida` no está vacía, el cliente solo puede escribir. Esto evita que una ráfaga encolada crezca en memoria: mientras el par no lea su respuesta, no se consumen más mensajes.
2. **No se consume el mensaje siguiente hasta entregar el actual.** `atenderPendientes` corta en cuanto `salida` deja de estar vacía. El orden FIFO es, por tanto, una propiedad del bucle, no una convención del llamador.
3. **Solo un rechazo cierra.** Una solicitud aceptada deja la conexión lista para la siguiente; un rechazo de protocolo o de framing responde y cierra, porque el flujo ya no es confiable.

---

## Implementación del servidor

### El estado de la transacción

`struct Cliente` gana dos campos y conserva los anteriores:

```cpp
std::string entrada, salida;
std::size_t enviado = 0;
Reloj::time_point limite;
bool cerrado = false;
bool cerrarTrasEnviar = false;   // RNF-24
std::size_t bytesSolicitud = 0;  // RNF-24
Motivo motivo = Motivo::CierreNormal;
DetalleSolicitud detalle;
```

`bytesSolicitud` existe porque los bytes ya consumidos se descartan de `entrada`. Calcular el desenlace con `entrada.size()` funcionaba cuando solo había un mensaje por conexión; con varias transacciones, el tamaño del búfer ya no describe la solicitud que se está documentando. Se fija al recibir bytes y se reinicia al empezar una transacción nueva.

`cerrarTrasEnviar` separa «responder y cerrar» de «responder y seguir». Antes, el cierre ocurría incondicionalmente al terminar el envío; ahora depende de si la respuesta fue un rechazo.

### Atención de los mensajes pendientes

```cpp
auto atenderPendientes = [&](Cliente& cliente) {
    bool progreso = false;
    while (!cliente.cerrado && cliente.salida.empty()) {
        const auto fin = cliente.entrada.find('\n');
        if (fin == std::string::npos) {
            if (cliente.entrada.size() <= MAX_MENSAJE_RED) break;
            /* MESSAGE_TOO_LARGE, registrarRechazo, cerrarTrasEnviar = true */
            break;
        }
        if (fin > MAX_MENSAJE_RED) { /* MESSAGE_TOO_LARGE igual */ }
        DetalleSolicitud detalle;
        auto respuesta = procesarSolicitudRedDetallada(
            cliente.entrada.substr(0, fin), cliente.identidad, cliente.permisos, detalle);
        cliente.entrada.erase(0, fin + 1);
        cliente.detalle = std::move(detalle);
        const bool rechazada = cliente.detalle.formatoInvalido;
        if (rechazada) registrarRechazo(cliente, cliente.bytesSolicitud);
        responder(cliente, std::move(respuesta));
        cliente.cerrarTrasEnviar = rechazada;
        if (!rechazada && !cliente.entrada.empty()) {
            cliente.detalle = DetalleSolicitud{};
            cliente.bytesSolicitud = cliente.entrada.size();
        }
        progreso = true;
    }
    return progreso;
};
```

Dos decisiones merecen justificación.

**El límite se aplica al mensaje, no al búfer.** RNF-14 comparaba `entrada.size()` contra `MAX_MENSAJE_RED`, lo que era correcto con un mensaje por conexión. Con solicitudes encadenadas, veinte mensajes de 1 KiB superan el tope en total sin que ninguno lo supere por separado. La comprobación pasa a ser `fin > MAX_MENSAJE_RED` —longitud del mensaje delimitado— y `entrada.size() > MAX_MENSAJE_RED` solo cuando no hay delimitador, que es el caso de un mensaje que aún no termina. El invariante de RNF-14 se conserva: ningún mensaje mayor de 16 384 bytes se procesa.

**La transacción se reinicia al consumir.** Si quedaron bytes después del delimitador, el `DetalleSolicitud` se limpia antes de documentar la siguiente. Sin esa limpieza, un `submit` aceptado seguido de un `cancel` interrumpido se documentaría como `ACEPTADA` con el `request_id` del primero. Los bytes posteriores a un rechazo no importan: la conexión se cierra.

### Lectura: el plazo mide inactividad

```cpp
auto leer = [&](Cliente& cliente, bool errorTerminal) {
    char buffer[4096];
    const auto leidos = recv(cliente.socket.valor, buffer, sizeof(buffer), 0);
    if (leidos > 0) {
        if (cliente.entrada.empty()) cliente.detalle = DetalleSolicitud{};
        cliente.entrada.append(buffer, static_cast<std::size_t>(leidos));
        cliente.bytesSolicitud = cliente.entrada.size();
        cliente.limite = Reloj::now() + std::chrono::seconds(3);
        return true;
    }
    if (leidos == 0) {
        if (cliente.entrada.empty() && cliente.detalle.procesada) {
            cliente.cerrado = true;   // FIN con el flujo sincronizado
            return false;
        }
        despedida(cliente, "INCOMPLETE_MESSAGE", Motivo::FinSinMensaje);
        return false;
    }
    /* error de socket o de lectura */
};
```

La renovación del plazo en cada `recv()` con bytes es el cambio que hace posible un mensaje fragmentado largo: un emisor que avanza ya no se corta a los tres segundos de haber conectado, sino a los tres segundos de haberse callado. El plazo sigue protegiendo contra clientes que no avanzan —TC-031 lo verifica— y contra conexiones abandonadas —TC-054—.

El fin de flujo se ramifica en dos desenlaces distintos:

| Situación | Resultado | Motivo registrado |
|---|---|---|
| `recv() == 0`, búfer vacío, última transacción atendida | Cierre normal, sin sobre de error | `CIERRE_NORMAL` (no se registra) |
| `recv() == 0`, quedan bytes sin delimitador | `INCOMPLETE_MESSAGE` y cierre | `FIN_SIN_MENSAJE` |
| `recv() == 0` sin ninguna transacción atendida | `INCOMPLETE_MESSAGE` y cierre | `FIN_SIN_MENSAJE` |

La segunda rama es la que exige RNF-14 y protege TC-037; la primera es la que hace que un cliente que paginó y se despide no genere ruido. Se distingue con `detalle.procesada`, no con `entrada.empty()` a secas: una conexión que envió un mensaje truncado antes de cualquier transacción también tiene `entrada` con datos, y debe conservar `INCOMPLETE_MESSAGE`.

### Escritura: la respuesta habilita la siguiente transacción

```cpp
auto escribir = [&](Cliente& cliente) {
    const auto enviados = send(...);
    if (enviados <= 0) { /* EAGAIN: esperar; otro error: cerrar */ }
    cliente.enviado += static_cast<std::size_t>(enviados);
    if (cliente.enviado < cliente.salida.size()) return false;
    if (cliente.cerrarTrasEnviar) {
        cliente.cerrado = true;
        return true;
    }
    cliente.salida.clear();
    cliente.enviado = 0;
    cliente.esperado = POLLIN;
    cliente.limite = Reloj::now() + std::chrono::seconds(3);
    return true;
};
```

`esperado` vuelve a `POLLIN` al completar la escritura. En el diseño anterior este campo se quedaba en `POLLOUT` para siempre porque el cliente se cerraba acto seguido; con conexiones duraderas, no resetearlo habría dejado al cliente sordo a nuevas solicitudes.

### El bucle alternado

```cpp
bool leido = false;
bool avanzar = true;
while (avanzar && !cliente.cerrado) {
    avanzar = false;
    if (cliente.salida.empty()) {
        if (!leido && (evento & (cliente.esperado | POLLHUP | POLLERR))) {
            leido = true;
            avanzar = leer(cliente, errorTerminal);
        }
        if (!cliente.cerrado && atenderPendientes(cliente)) avanzar = true;
    } else if (evento & cliente.esperado) {
        avanzar = escribir(cliente);
    }
}
```

El bucle existe para no esperar una vuelta de `poll()` entre solicitudes que ya están en el búfer. Si un solo `recv()` trajo dos mensajes completos, el primero se atiende, se responde, se escribe en la misma iteración —cuando el evento lo permite— y el segundo se atiende sin salir del bucle. Cuando una escritura quedaría bloqueada, el bucle termina y `poll()` vuelve a decidir; nunca se hace `send()` en bucle dentro de la misma vuelta.

Un detalle deliberado: `leer` se ejecuta como máximo una vez por cliente e iteración de `poll()`. Mantener una lectura por vuelta conserva el reparto justo entre clientes que ya tenía el servidor; el bucle alternado consume lo **ya recibido**, no vuelve a leer.

### Lo que no cambia en el bucle

- Un solo `recv()` de 4096 por vuelta y cliente.
- `MSG_NOSIGNAL` en cada `send()` y `SIGPIPE` ignorado.
- `accept4()` al final de cada iteración y cupo de 32 clientes.
- `registrar()` se evalúa para cada cliente que se cierra y respeta la clasificación de RF-28.
- Un error interno en un cliente cierra ese cliente y continúa con el resto.

---

## Implementación del cliente

El cliente abría un socket por petición: `getaddrinfo`, `connect`, `send`, `recv`, `close`. Funcionaba porque cada invocación del CLI envía una sola solicitud… hasta que la paginación de `red filter` envía varias. RNF-24 saca el socket del lambda `enviar()` y lo comparte con la invocación:

```cpp
IgnorarPipe ignorar;
Socket socket;          // se cierra al salir de la invocación
std::string residual;   // bytes que llegaron más allá de la respuesta
auto conectar = [&]() { /* getaddrinfo + connect, sin bloqueo */ };
auto transmitir = [&](const std::string& solicitud) {
    /* send completo con espera en POLLOUT ante EAGAIN */
    /* recv acumulado hasta '\n', conservando el resto en `residual` */
};
```

`transmitir` devuelve una respuesta y deja en `residual` todo lo que vino después del delimitador. Con el servidor actual esto no ocurre —una respuesta por transacción—, pero el cliente no puede asumirlo: un servidor que adelante respuestas dejaría el socket desincronizado si se descartaran los bytes sobrantes.

La distinción entre fallo de transporte y respuesta inválida es nueva y necesaria:

```cpp
struct FalloConexion : std::runtime_error { using std::runtime_error::runtime_error; };
```

`esperar()` y `transmitir()` lanzan `FalloConexion`; la validación del sobre sigue lanzando `std::runtime_error`. Solo el primero es reintentable, y solo en una consulta paginable:

```cpp
const bool paginable = operacion == "filter" && tipoFiltro != "id";
...
} catch (const FalloConexion&) {
    if (!paginable || atendidas == 0 || intento > 0) throw;
    close(socket.fd);
    socket.fd = -1;
    residual.clear();
}
```

Las tres condiciones del reintento son un contrato, no una tolerancia:

| Condición | Motivo |
|---|---|
| `paginable` | `submit` y `cancel` no son idempotentes desde el cliente: reintentar podría duplicar una solicitud que el servidor ya procesó. |
| `atendidas > 0` | Si la primera petición falla, el error es real y debe llegar al usuario. El reintento cubre la conexión que un servidor antiguo cerró **después** de responder, no una que nunca respondió. |
| `intento == 0` | Como máximo un reintento por página. Un servidor que cierra cada respuesta funciona; uno que no responde no se martilla. |

El resultado es compatible en ambos sentidos: contra el servidor nuevo, toda la paginación viaja por una conexión; contra un servidor que cierra tras cada respuesta, el cliente reconecta una vez por página y la lista se completa igual.

---

## Integración con otros requisitos

- **RNF-08 — Una solicitud inválida no termina el servicio.** El requisito real es que el fallo de un cliente no afecte al servicio, y eso se conserva: cada cliente tiene su propia frontera de excepción. La frase «un mensaje por conexión» era una descripción del diseño de entonces, no una exigencia; se corrigió en `RNF-08.md` y no se contradice ningún criterio de aceptación.
- **RNF-14 — Validación de longitud y formato.** La validación sigue siendo por mensaje y con los mismos códigos. TC-042 se reescribió: antes afirmaba que el segundo sobre se descartaba; ahora exige que el válido se atienda y el inválido se rechace con su código, sin crear estado. La garantía —ningún sobre sin validar— se mantiene; cambia el destino de la conexión.
- **RF-28 — Estado coherente ante desconexión.** Cada transacción tiene su propio `DetalleSolicitud` y su propio `bytesSolicitud`. El cierre documenta la transacción en curso o la última atendida, nunca una mezcla. TC-052 fija las dos caras del fin de flujo y TC-054 el timeout de inactividad.
- **RNF-15 — Registros sin secretos.** No se añaden campos nuevos a la bitácora; `bytes_recibidos` pasa a describir la transacción, y los casos de RNF-15 siguen en `PASS`.
- **RF-22 — Desconexión del cliente.** Se conservan el cupo, los motivos, la ventana de avisos y la renovación de `limite` al encolar una respuesta.
- **RF-18 — Operaciones remotas.** La paginación de `list` ya existía en el servidor; el cliente ahora puede aprovecharla sin abrir una conexión por página.

---

## Ejemplo de funcionamiento

### Mensaje fragmentado durante casi cinco segundos

```text
$ bash verif/scripts/TC-049.sh
  envio fragmentado en 4.96 s (123 bytes, uno por envio)
  respuesta: {"ok": true, "request_id": "tc049-fragmentado", "result": {...}}
PASS V1/AC1: el mensaje fragmentado durante mas de 3 s se acumulo y se atendio.
```

Un byte cada 40 ms supera el plazo absoluto anterior por casi dos segundos. Con el plazo de inactividad, cada byte lo renueva y el mensaje llega completo.

### Dos solicitudes encadenadas en un solo `write`

```text
$ bash verif/scripts/TC-050.sh
  respuesta 1: {"ok": true, "request_id": "tc050-uno", "result": {"message": "pong"}, ...}
  respuesta 2: {"ok": true, "request_id": "tc050-dos", "result": {... "job_id": 1}, ...}
PASS V1/AC1: las dos solicitudes encadenadas se atendieron en orden FIFO.
```

El `ping` y el `submit` comparten conexión; solo el segundo crea estado.

### Veinte solicitudes sobre una conexión

```text
$ bash verif/scripts/TC-051.sh
  20 solicitudes atendidas en 0.01 s sobre una sola conexion
  FIN posterior a la respuesta: cierre limpio, sin sobre de error
  bitacora: 0 solicitudes interrumpidas, 0 desconexiones anomalas
```

### Cierre ordenado frente a mensaje truncado

```text
$ bash verif/scripts/TC-052.sh
  cierre ordenado: EOF sin datos adicionales
  mensaje truncado: {"error":"INCOMPLETE_MESSAGE","ok":false,"request_id":null,"version":1}
  registro: {"context": {"bytes_recibidos": 66, "motivo": "FIN_SIN_MENSAJE",
            "resultado": "SIN_EFECTO"}, "message": "Solicitud interrumpida", ...}
```

### Un exceso de framing cierra y no procesa lo que venía detrás

```text
$ bash verif/scripts/TC-053.sh
  respuesta: {"error": "MESSAGE_TOO_LARGE", "ok": false, "request_id": null, "version": 1}
  tras el error la conexion cerro sin procesar el sobre encadenado
  jobs.json: 0 Jobs
```

### El plazo sigue midiendo la inactividad

```text
$ bash verif/scripts/TC-054.sh
  primera respuesta: pong; tras 4.0 s de inactividad: {"error":"REQUEST_TIMEOUT", ...}
  bitacora: {"context": {"motivo": "TIMEOUT_LECTURA", "request_id": "tc054-uno",
            "resultado": "ACEPTADA"}, "message": "Solicitud interrumpida", ...}
```

### Cada conexión tiene su propio mensaje a medias

```text
$ bash verif/scripts/TC-055.sh
  B atendido en 0.00 s mientras A tenia un mensaje a medias
  A completo su mensaje y recibio: {"ok": true, "request_id": "tc055-a", ...}
```

### El CLI reutiliza la conexión al paginar

```text
$ bash verif/scripts/TC-056.sh
  21 Jobs creados sobre una sola conexion
  red filter mostro 21 Jobs (dos paginas sobre la misma conexion)
  contra un servidor que cierra cada respuesta: 2 Jobs en 3 conexiones
```

---

## Verificación

Ocho casos automatizados nuevos y uno reescrito, ejecutados el 2026-11-22 y el 2026-11-23 en WSL Ubuntu. Todos en `PASS`.

| Caso | Escenario | Resultado observado |
|---|---|---|
| **TC-042** (reescrito) | Sobre válido y sobre inválido en un solo `write` | El válido crea 1 Job; el inválido responde `UNSUPPORTED_VERSION`; sin rastro del segundo en `jobs.json` |
| **TC-049** | Mensaje byte a byte durante 4,96 s | Se acumula y se atiende; 1 Job; `ping` posterior correcto |
| **TC-050** | `ping` y `submit` encadenados en un `write` | Dos respuestas en orden; solo el `submit` crea estado |
| **TC-051** | 20 solicitudes secuenciales por una conexión | 20 respuestas correctas; FIN posterior en silencio; 0 registros anómalos |
| **TC-052** | FIN tras respuesta completa frente a mensaje truncado | Silencio en el primer caso; `INCOMPLETE_MESSAGE` y `SIN_EFECTO` con 66 bytes en el segundo |
| **TC-053** | 17 000 bytes sin estructura y un sobre válido detrás | `MESSAGE_TOO_LARGE` con `request_id: null`; conexión cerrada; 0 Jobs |
| **TC-054** | Respuesta y luego 4 s de inactividad | `REQUEST_TIMEOUT`; bitácora con `TIMEOUT_LECTURA` sobre la solicitud aceptada |
| **TC-055** | Un cliente con mensaje a medias y otro completo | El segundo se atiende en 0,00 s; el primero recibe su propia respuesta al completar |
| **TC-056** | Paginación del CLI contra servidor nuevo y antiguo | 21 Jobs en dos páginas sobre una conexión; 2 Jobs en 3 conexiones contra el servidor que cierra |

**Regresión.** TC-030 a TC-048 (RF-22, RF-28, RNF-14 y RNF-15) se reejecutaron y siguen en `PASS`: 19 scripts, con TC-042 ya reescrito. Con TC-049…TC-056, la batería de red completa son 27 scripts en `PASS`. Compilación completa con `g++ -Wall -Wextra -std=c++17` sin advertencias.

Scripts en `verif/scripts/TC-042.sh` y `TC-049.sh`…`TC-056.sh`; evidencia en `verif/results/results_TC-042.md` y `results_TC-049.md`…`results_TC-056.md`; descripciones en `verif/test-cases/`; fila RNF-24 de `verif/verification-plan/traceability-matrix.md` en `PASS`.

---

## Riesgos residuales

**R1 — el plazo de inactividad sigue siendo un límite duro de tres segundos.** Un emisor que avanza no se corta, pero uno que se detiene más de tres segundos a mitad de mensaje sí. Es la contrapartida de no tener un plazo absoluto: sin un temporizador de inactividad, una conexión podría retener un cupo indefinidamente. Un cliente que necesite pausas mayores debe enviar el mensaje completo en menos de tres segundos desde su último byte, o reconectar. No hay configuración por servidor para este valor.

**R2 — el cierre tras un rechazo descarta las solicitudes que ya venían detrás.** Si un `write` trae un sobre inválido seguido de uno válido, el válido no se procesa: el flujo deja de ser confiable y el servidor cierra. Es deliberado —procesar bytes posteriores a un rechazo obliga a decidir qué validez tiene el resto del búfer— y está fijado por TC-053. Un cliente que quiera continuar debe abrir otra conexión.

**R3 — el reintento del cliente cubre solo la paginación de solo lectura.** `submit` y `cancel` no reintentan: si la conexión cae después de que el servidor persistió el Job, el cliente informa un fallo aunque el trabajo exista. La mitigación es la idempotencia de RF-28 por `request_id`; el operador debe reenviar con el mismo identificador. No se automatiza porque un reintento ciego de `cancel` podría cancelar un Job distinto si el identificador se generó de nuevo.

**R4 — la conexión no multiplexa.** Las solicitudes de una conexión son estrictamente secuenciales: una respuesta lenta retrasa la siguiente. El diseño evita el bloqueo de cabeza de línea **entre clientes** —cada uno tiene su propio bucle—, no dentro de uno. Para el uso previsto —CLI y paginación— es suficiente; un cliente que necesite paralelismo abre conexiones, con el coste del cupo de 32.

**R5 — `bytes_recibidos` cuenta la transacción, no la conexión.** Un rechazo en una ráfaga documenta solo los bytes del mensaje rechazado; los de las solicitudes posteriores se pierden con el cierre. Es coherente con RF-28, que documenta desenlaces, no tráfico.

---

## Historial

| Fecha | Cambio |
|---|---|
| 2026-11-22 | Implementación de RNF-24: transacciones por conexión en el servidor, plazo de inactividad, cierre ordenado en FIN, límite por mensaje, reutilización de socket en el cliente y reintento acotado de paginación; TC-042 reescrito y TC-049…TC-056 añadidos |
| 2026-11-23 | Corrección de RNF-08, RNF-14 y `CONTEXTO-RED-ACTUAL.md`, que describían el framing anterior; verificación de TC-054 regenerada sin mojibake; registros de uso de IA 54 y 55 |
