# Uso de inteligencia artificial

# 54. RNF-24 — Mensajes fragmentados y múltiples solicitudes secuenciales

## Objetivo

Implementar RNF-24 —«El protocolo deberá funcionar con mensajes fragmentados y múltiples solicitudes secuenciales»— en un transporte que hasta entonces prometía dos cosas incompatibles con el requisito: un plazo de lectura absoluto de tres segundos desde `accept`, y el cierre de la conexión al encontrar el primer delimitador, descartando cualquier byte posterior. La segunda mitad vivía en el cliente, que abría un socket por petición y no conservaba bytes sobrantes.

El requisito toca los dos extremos del mismo eje —qué es una transacción y cuándo termina la conexión—, así que la auditoría previa era obligatoria. Sin un inventario exacto del bucle de `poll()`, del cliente y de los casos que ya fijaban el comportamiento anterior, era fácil cambiar el servidor y romper RF-28, o reutilizar el socket y duplicar un `submit`.

---

## Prompt 1

```text
Actúa como arquitecto técnico supervisor. Audita el subsistema de red y completa RNF-24:
El protocolo deberá funcionar con mensajes fragmentados y múltiples solicitudes secuenciales.

Fase 1: auditoría
... src/hermes/src/network/server.cpp: cómo se acumulan los fragmentos, cuándo se fija y se
renueva `limite`, qué ocurre con los bytes posteriores al primer `\n`, cuándo se cierra el
descriptor y qué se registra al cerrar.
... src/hermes/src/network/client.cpp: cuántos sockets abre una invocación, si conserva bytes
sobrantes y cómo afecta la paginación de `red filter`.
... src/hermes/src/network/protocol.cpp: ¿necesita cambios si el servidor entrega varios
mensajes completos por conexión?
... Lee verif/scripts/TC-031.sh, TC-035.sh, TC-037.sh, TC-038.sh y TC-042.sh: qué comportamiento
ya está fijado y no puede romperse.

Fase 2: propuesta
Diseña el cambio con decisiones explícitas sobre el plazo de lectura, el cierre tras rechazo,
el desenlace registrado de cada transacción y el reintento del cliente. Presenta el plan, las
decisiones y los riesgos; pide autorización antes de escribir código.

Compatibilidad total con protocol version 1 y delimitador `\n`. No rompas RF-28, RNF-14 ni RNF-15.
```

---

## Resultado 1

La auditoría se delegó a un explorador de solo lectura con obligación de citar `ruta:línea`. Devolvió tres brechas y una conclusión que ahorró trabajo:

1. **El plazo era absoluto.** `limite` se fijaba al aceptar y no se renovaba con cada byte, así que un mensaje fragmentado durante más de tres segundos se cortaba a mitad aunque avanzara. El comentario del código lo declaraba intencional («un emisor lento no puede extenderlo»), lo que confirmaba que era una decisión de diseño y no un descuido.
2. **El primer delimitador cerraba todo.** `responder()` armaba `POLLOUT` y, al terminar el envío, marcaba el cliente como cerrado. Los bytes posteriores se descartaban con el descriptor.
3. **El cliente no reutilizaba nada.** `enviar()` resolvía `getaddrinfo`, `connect`, `send`, `recv` y `close` en una sola función, sin búfer residual. La paginación de `red filter` abría una conexión por página.
4. **`protocol.cpp` no necesitaba cambios.** `procesarSolicitudRedDetallada()` es sin estado: recibe un mensaje y devuelve un sobre. RNF-24 solo debía entregarle mensajes completos y en orden.

El plan propuso cinco decisiones: reescribir TC-042 en lugar de borrarlo; cerrar tras cualquier rechazo y mantener abierta la conexión tras una solicitud aceptada; convertir el plazo en tres segundos de inactividad; reutilizar un socket por invocación con un único reintento para la paginación de solo lectura; y drenar la respuesta antes de cerrar para que un `MESSAGE_TOO_LARGE` no se pierda.

La revisión previa destapó una trampa: la limpieza «obvia» —reiniciar `DetalleSolicitud` en cuanto se completa una escritura— habría roto RF-28. `TC-035` y `TC-038` exigen que la última solicitud aceptada se documente como `ACEPTADA` cuando la conexión cae después. Se leyó `TC-038.sh:144-173` para confirmarlo, y el reinicio se limitó a los bytes que quedan en el búfer al empezar la transacción siguiente.

---

## Prompt 2

```text
Autorizado, implementa (Recomendado)
```

---

## Resultado 2

La implementación se dividió en dos escrituras secuenciales, servidor y cliente, con compilación limpia exigida en cada paso.

**Servidor.** `struct Cliente` ganó `cerrarTrasEnviar` —separa «responder y cerrar» de «responder y seguir»— y `bytesSolicitud`, porque los bytes consumidos se descartan de `entrada` y `entrada.size()` ya no describe la transacción que se documenta. El bucle por cliente alterna lectura, atención y escritura mientras haya progreso inmediato:

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

`atenderPendientes()` corta en cuanto `salida` deja de estar vacía, así que el orden FIFO es una propiedad del bucle y no una convención del llamador. El límite se evalúa por mensaje —`fin > MAX_MENSAJE_RED`— y no por el total acumulado; con solicitudes encadenadas, veinte mensajes de 1 KiB habrían superado el tope sin que ninguno lo superara. `leer()` renueva `limite` con cada `recv()` que devuelve bytes, y `escribir()` lo renueva y devuelve `esperado` a `POLLIN` al completar la respuesta.

**Cliente.** `Socket`, `residual`, `conectar()` y `transmitir()` salieron de `enviar()` y pasaron a vivir en la invocación. `transmitir()` acumula hasta el delimitador y conserva el resto en `residual`. La distinción entre fallo de transporte y respuesta inválida se materializó en `struct FalloConexion`, y el reintento quedó condicionado:

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

Las tres condiciones son un contrato: `paginable` porque `submit` y `cancel` no son idempotentes desde el cliente; `atendidas > 0` porque el reintento cubre la conexión que un servidor antiguo cerró **después** de responder; `intento == 0` porque un servidor que no responde no se martilla.

**Pruebas.** TC-042 se reescribió: ahora exige que el sobre válido se atienda y el inválido se rechace con su código. Se añadieron TC-049 a TC-056 para fragmentación lenta, encadenamiento en un `write`, secuencia de veinte solicitudes, FIN ordenado frente a mensaje truncado, exceso de framing con sobre válido detrás, plazo de inactividad, dos clientes con búferes independientes y paginación del CLI contra servidor nuevo y antiguo.

---

# Modificaciones

**Estado de la resolución:** **[Aceptado]** — el diseño y la implementación fueron correctos, compilaron sin advertencias y las veintisiete pruebas pasaron. La única corrección aplicada fue cosmética: la salida de `TC-054` incluía un acento que rompía la codificación de la evidencia y se sustituyó por texto ASCII.

**Revisión realizada:** tres niveles. Primero, auditoría independiente antes de escribir, con lectura explícita de los casos que fijaban el comportamiento anterior —`TC-031`, `TC-035`, `TC-037`, `TC-038`, `TC-042`— en lugar de asumir qué protegían. Segundo, compilación forzada desde cero con `make -B` y `-Wall -Wextra` para descartar que el «sin advertencias» dependiera de objetos ya compilados. Tercero, ejecución de la batería completa de red: TC-030 a TC-056, veintisiete scripts, con `HOME` aislado y puertos propios.

La revisión no se limitó a mirar el resultado verde. Se verificó que TC-054 afirmara `Solicitud interrumpida`, `TIMEOUT_LECTURA` y `ACEPTADA`, y **no** `Cliente desconectado`: con el bucle nuevo, `detalle.procesada` sigue siendo verdadero tras la respuesta, y una aserción copiada del comportamiento anterior habría fijado lo contrario de lo que RF-28 documenta. También se comprobó que `avisoPermitido()` —un aviso por motivo cada sesenta segundos— no silenciara el registro que el caso busca.

**Cambios aplicados:**

1. `server.cpp`: `Cliente` con `cerrarTrasEnviar` y `bytesSolicitud`; lambdas `atenderPendientes`, `leer` y `escribir`; bucle alternado por cliente; `entrada.erase(0, fin + 1)`; límite por mensaje; limpieza de `DetalleSolicitud` solo al empezar la transacción siguiente; `registrar()` con `bytesSolicitud`.
2. `server.cpp`: `leer()` distingue el FIN con búfer vacío y última transacción atendida —cierre silencioso— del FIN con bytes sin delimitador —`INCOMPLETE_MESSAGE` y `FinSinMensaje`.
3. `client.cpp`: `Socket`, `residual`, `conectar()` y `transmitir()` extraídos de `enviar()`; `FalloConexion`; reintento único para `filter` paginable con al menos una respuesta atendida.
4. `verif/scripts/TC-042.sh` reescrito y `TC-049.sh`…`TC-056.sh` añadidos, con puertos `45853` y `45855`–`45863`.
5. `verif/scripts/TC-054.sh`: texto de salida sin acentos y corrida regenerada.
6. `protocol.cpp`, `remote.cpp`, `network_protocol.h`: sin cambios.

**Prueba agregada:** TC-049 a TC-056, más TC-042 reescrito. La batería de red completa —TC-030…TC-056, veintisiete scripts— en `PASS` el 2026-11-22 y el 2026-11-23, con compilación limpia.

---

## Implementación de feature

El requisito se resuelve con una idea: **la conexión deja de ser la transacción**. Una conexión es una secuencia; la transacción es el par mensaje-respuesta, y su frontera son el delimitador y la respuesta entregada.

```text
accept → LEER (acumula, renueva plazo)
       → '\n' completo → ATENDER (valida, encola respuesta)
       → ESCRIBIR (entrega completa) → LEER
       → rechazo de protocolo → ESCRIBIR → cerrar
       → 3 s sin bytes → REQUEST_TIMEOUT → cerrar
       → FIN con búfer vacío → cerrar en silencio
```

Tres reglas sostienen el modelo: no se lee mientras hay una respuesta pendiente —una ráfaga encolada no crece en memoria—; no se consume el mensaje siguiente hasta entregar el actual —el orden FIFO es del bucle—; y solo un rechazo cierra, porque solo un rechazo deja el flujo sin confiar.

| Capa | Qué garantiza |
|---|---|
| `server.cpp` | Varias transacciones por conexión, plazo de inactividad, cierre ordenado y cierre efectivo tras rechazo |
| `client.cpp` | Un socket por invocación, búfer residual y reintento acotado a la paginación de solo lectura |
| `protocol.cpp` | Sin cambios: valida cada mensaje de forma independiente |
| `remote.cpp` | Sin cambios: cada operación recibe un mensaje completo |

---

## Modificación de archivo

**`src/network/server.cpp`** — el estado de la transacción:

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

**`src/network/server.cpp`** — atención FIFO con límite por mensaje:

```cpp
auto atenderPendientes = [&](Cliente& cliente) {
    bool progreso = false;
    while (!cliente.cerrado && cliente.salida.empty()) {
        const auto fin = cliente.entrada.find('\n');
        if (fin == std::string::npos) {
            if (cliente.entrada.size() <= MAX_MENSAJE_RED) break;
            /* MESSAGE_TOO_LARGE */
            break;
        }
        if (fin > MAX_MENSAJE_RED) { /* MESSAGE_TOO_LARGE */ }
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

**`src/network/server.cpp`** — el plazo mide inactividad y el FIN se ramifica:

```cpp
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
```

**`src/network/client.cpp`** — socket y búfer residual por invocación:

```cpp
IgnorarPipe ignorar;
Socket socket;          // se cierra al salir de la invocación
std::string residual;   // bytes que llegaron más allá de la respuesta
auto conectar = [&]() { /* getaddrinfo + connect */ };
auto transmitir = [&](const std::string& solicitud) {
    /* send completo con espera en POLLOUT ante EAGAIN */
    /* recv acumulado hasta '\n', conservando el resto en `residual` */
};
```

---

## Implementación final

```text
$ make -B -C src/hermes hermes
g++ -Wall -Wextra -std=c++17 -Iinclude ... -pthread -o hermes
(cero advertencias)

$ bash verif/scripts/TC-049.sh
  envio fragmentado en 4.96 s (123 bytes, uno por envio)
PASS V1/AC1: el mensaje fragmentado durante mas de 3 s se acumulo y se atendio.

$ bash verif/scripts/TC-050.sh
PASS V1/AC1: las dos solicitudes encadenadas se atendieron en orden FIFO.

$ bash verif/scripts/TC-051.sh
  20 solicitudes atendidas en 0.01 s sobre una sola conexion
  bitacora: 0 solicitudes interrumpidas, 0 desconexiones anomalas

$ bash verif/scripts/TC-053.sh
  respuesta: {"error": "MESSAGE_TOO_LARGE", "ok": false, "request_id": null, "version": 1}
  tras el error la conexion cerro sin procesar el sobre encadenado

$ bash verif/scripts/TC-056.sh
  21 Jobs creados sobre una sola conexion
  red filter mostro 21 Jobs (dos paginas sobre la misma conexion)
  contra un servidor que cierra cada respuesta: 2 Jobs en 3 conexiones
```

Batería completa: TC-030 a TC-056, veintisiete scripts en `PASS`.

---

## Aprendizaje

**El arreglo obvio puede ser el bug.** Reiniciar `DetalleSolicitud` al completar cada escritura es la limpieza natural de un bucle de transacciones, y es exactamente lo que rompe RF-28: la solicitud que la bitácora debe documentar como `ACEPTADA` cuando la conexión muere después. Lo resolvió leer `TC-038.sh`, no razonar sobre el código. Las pruebas existentes son especificación ejecutable, y consultarlas antes de escribir cuesta menos que descubrirlo en regresión.

**El plazo absoluto era una decisión, no un descuido.** Estaba justificado con un comentario. Cuando un comportamiento documentado contradice un requisito nuevo, el trabajo no es parchearlo en silencio: es nombrar cuál gana y corregir el documento que afirmaba lo contrario. Por eso RNF-08, RNF-14 y el contexto se editaron en la misma tanda.

**Un límite por búfer deja de ser un límite por mensaje en cuanto hay varios.** `entrada.size() > MAX_MENSAJE_RED` era correcto con una transacción por conexión y se vuelve absurdo con veinte solicitudes pequeñas. Mover la comprobación a `fin > MAX_MENSAJE_RED` no cambió el invariante —ningún mensaje procesado supera 16 384— pero sí su expresión, y esa diferencia es la que un lector futuro necesita entender.

**Sobre Prompt Engineering.** El prompt pedía dos cosas que hicieron la diferencia: leer los casos que ya fijaban el comportamiento y declarar los riesgos antes de escribir. La auditoría citó `ruta:línea` en cada afirmación, y eso permitió convertirla en superficies de edición exactas. Cuando un requisito toca el transporte, pedir «qué está fijado y no puede romperse» da más valor que pedir «cómo lo implementarías».
