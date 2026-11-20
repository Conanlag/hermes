# Uso de inteligencia artificial

# 48. RF-28 — Estado coherente y desenlace documentado ante desconexión del cliente

## Objetivo

Implementar RF-28 sobre la base ya entregada por RF-22: cuando un cliente se desconecta durante una solicitud, el servicio debe conservar un estado coherente y dejar constancia explícita de si la operación fue aceptada, rechazada o quedó sin efecto. Se buscaba además acotar la ventana de avisos de 60 s al ruido previo al protocolo, sin silenciar nunca una solicitud que ya había empezado a procesarse.

---

## Prompt 1

```text
Actúa como arquitecto técnico supervisor (gentle-orchestrator). Tu objetivo es auditar el estado actual del código tras RF-22 e implementar el requisito RF-28 — Estado coherente ante desconexión: Si un cliente se desconecta durante una solicitud, el servicio deberá conservar un estado coherente y documentar si la operación fue aceptada, rechazada o quedó sin efecto.

Fase 1: Auditoría de la implementación vigente de RF-22
... server.cpp: struct Cliente, ciclo POLLIN -> procesarSolicitudRed() -> POLLOUT ...
... network_protocol.h, protocol.cpp y remote.cpp: qué información estructurada se conoce al finalizar ...
... job.cpp y cancel.cpp: confirmar que el estado persistido se conserva íntegro ...

Fase 2: Implementación de RF-28
... estado de tramitación por conexión (sin_efecto / aceptada / rechazada) con metadatos ...
... coherencia: sin_efecto no altera jobs.json; aceptada se conserva; rechazada no cambia nada ...
... documentación explícita en EventLog sin lanzar excepciones ...
... ajustar la ventana de 60 s para que aplique solo a ruido previo al protocolo ...
... compatibilidad total con el protocolo JSON vigente y atomicidad de storage/scheduler ...

Despues de presentarme tu plan pide mi autorizacion, si te autorizo comienza a implementar.
```

---

## Resultado 1

La auditoría concluyó que la coherencia de estado **ya existía** y que el RF pedía hacerla observable, no repararla: `responder()` solo arma `POLLOUT` después de que `crearJob()` o `cancelarJobDetallado()` terminaron su transacción atómica, así que un corte posterior no puede perder nada. Se identificaron tres huecos reales:

1. `procesarSolicitudRed()` devuelve un `std::string` opaco; el `ok`/`error`/`job_id` muere dentro de `protocol.cpp`.
2. `registrar()` aplica `avisoPermitido()` sin distinguir ruido de una solicitud procesada.
3. `registrar()` vive fuera del `try` por cliente: la construcción del objeto JSON puede lanzar `bad_alloc` y tumbar el servicio.

El plan propuesto fue: un tipo `DetalleSolicitud` en `network_protocol.h`, una sobrecarga `procesarSolicitudRedDetallada()` que conserva la firma pública, el campo en `struct Cliente`, una política de registro en dos ramas y cuatro casos de prueba nuevos (TC-035 a TC-038) con regresión TC-030…TC-034. Se dimensionó en ~150 líneas, casi todas en `server.cpp` y `protocol.cpp`.

---

## Prompt 2

```text
si autorizo, comienza solo con la implementacion y despues cuando sea correcta realizaras Documento final de RF-28 y registro ai-usage
```

---

## Resultado 2

Se implementó el plan y la compilación con `make -C src/hermes hermes` pasó bajo `-Wall -Wextra` sin advertencias. TC-035 (`submit` aceptado + `RST`) pasó en el primer intento, con `resultado: ACEPTADA`, `job_id: 1` y el Job en estado terminal.

TC-036 (`cancel` rechazado + `RST`) **falló**: no aparecía ninguna entrada `Solicitud interrumpida`. El diagnóstico señaló que la causa era de orden de eventos, no de política de registro: cuando el `RST` llegaba junto al último byte, `poll()` devolvía `POLLIN | POLLERR` y el bucle clasificaba `POLLERR` **antes** de leer, cerrando la conexión con `ErrorSocket` y sin detalle. En TC-035 la carrera se resolvió al revés por azar.

La corrección consistió en invertir ese orden: leer primero los bytes ya recibidos, procesar la línea si estaba completa y clasificar el cierre después. También se ajustó `recv` para que un fallo en una conexión marcada con `POLLERR` se catalogue como `ERROR_SOCKET` y no como `ERROR_LECTURA`.

Además se revisó la política de la ventana. El requerimiento dice que debe aplicar solo a "conexiones rechazadas por red o cortes antes de recibir datos"; la primera versión la aplicaba a cualquier cierre sin procesar, incluido un mensaje parcial. Se corrigió a la letra del RF: la ventana cubre únicamente `bytes_recibidos == 0`, y todo lo demás se documenta siempre.

---

# Modificaciones

**Estado de la resolución:** [Modificado] — el diseño era correcto, pero la primera implementación tenía un defecto de orden en el bucle de `poll()` que perdía el desenlace de solicitudes completas, y una lectura más laxa que la del requerimiento en el alcance de la ventana de 60 s.

**Revisión realizada:** Se auditó el orden real de operaciones antes de escribir código, lo que permitió descartar la hipótesis de "el estado se corrompe" y concentrar el trabajo en la propagación del desenlace. Después de la primera implementación se ejecutaron los cuatro casos nuevos; TC-036 expuso el defecto de orden y obligó a revisar la secuencia del bucle, no solo la lógica de registro. También se releyó el texto del RF para comprobar el alcance exacto de la ventana.

**Cambios aplicados:**

1. `poll()`: la lectura se intenta antes de clasificar `POLLERR`/`POLLHUP`; el cierre se clasifica después con su motivo real.
2. `recv` con error en conexión marcada: `ERROR_SOCKET` en lugar de `ERROR_LECTURA`.
3. Política de la ventana: solo `!procesada && bytes == 0`; un mensaje parcial con datos se documenta como `SIN_EFECTO` sin ventana.
4. `regex` de TC-033: su escenario original (cinco conexiones que enviaban `{` y cerraban) pasó a documentarse como `SIN_EFECTO` por diseño; el caso mide la ventana con conexiones que no envían bytes.
5. Los cinco scripts de RF-22 y los cuatro de RF-28 recibieron puerto propio y `config.json` en su `HOME` temporal, para que la batería se ejecute con un `hermes red start` activo en el puerto predeterminado.

**Prueba agregada:** `TC-035.sh` (aceptada + `RST`), `TC-036.sh` (rechazada + `RST`), `TC-037.sh` (tres mensajes parciales + `FIN`), `TC-038.sh` (20 procesadas con respuesta perdida), más la regresión completa `TC-030.sh`…`TC-034.sh`. Todas ejecutadas en WSL Ubuntu: nueve scripts en `PASS`, `TC-038` repetido cuatro veces con el mismo desenlace (`20 de 20` registros).

---

## Implementación de feature

El desenlace de cada solicitud viaja ahora desde el intérprete de protocolo hasta el cierre de la conexión en una estructura propia:

```cpp
struct DetalleSolicitud {
    bool procesada = false;
    bool aceptada = false;
    std::string requestId;
    std::string operacion;
    std::string error;
    unsigned jobId = 0;   // 0 = no aplica
};
```

`procesarSolicitudRedDetallada()` rellena esos campos en cada punto de salida y `procesarSolicitudRed()` queda como envoltorio, de modo que ninguna firma pública cambia. En el servidor, `struct Cliente` guarda el detalle y `registrar()` decide qué se escribe:

| Condición | Evento |
|---|---|
| cierre normal tras entregar la respuesta | ninguno |
| sin procesar y sin bytes recibidos | `Cliente desconectado` (ventana de 60 s) |
| cualquier otro cierre anómalo | `Solicitud interrumpida` con `ACEPTADA`, `RECHAZADA` o `SIN_EFECTO` |

Todo el registro está envuelto en `try { ... } catch (...) {}`, porque la construcción del JSON puede lanzar y la bitácora nunca debe tumbar el hilo de red.

---

## Modificación de archivo

**`src/hermes/include/network_protocol.h`** — tipo de desenlace y sobrecarga:

```cpp
struct DetalleSolicitud { bool procesada = false; bool aceptada = false;
    std::string requestId, operacion, error; unsigned jobId = 0; };

std::string procesarSolicitudRedDetallada(const std::string& mensaje,
    const std::string& identidad, const PermisosRemotos* permisos,
    DetalleSolicitud& detalle);
```

**`src/hermes/src/network/protocol.cpp`** — el desenlace se marca en cada salida:

```cpp
detalle.procesada = true;
detalle.aceptada = resultado.value("ok", false);
if (!detalle.aceptada) {
    detalle.error = resultado.value("error", std::string{});
    if (solicitud["params"].contains("job_id") && solicitud["params"]["job_id"].is_number_integer())
        detalle.jobId = solicitud["params"]["job_id"].get<unsigned>();
} else if (resultado.contains("result") && resultado["result"].is_object() &&
           resultado["result"].contains("job_id") &&
           resultado["result"]["job_id"].is_number_integer()) {
    detalle.jobId = resultado["result"]["job_id"].get<unsigned>();
}
```

**`src/hermes/src/network/server.cpp`** — lectura antes de clasificar el cierre:

```cpp
const bool errorTerminal = (evento & (POLLERR | POLLNVAL)) != 0;
const bool colgado = (evento & POLLHUP) != 0;
if (cliente.salida.empty() &&
    (evento & (cliente.esperado | POLLHUP | POLLERR))) {
    // recv; si hay '\n', procesarSolicitudRedDetallada y responder()
}
if (!cliente.cerrado && errorTerminal) { cliente.motivo = Motivo::ErrorSocket; cliente.cerrado = true; continue; }
if (!cliente.cerrado && colgado && !cliente.salida.empty()) { cliente.motivo = Motivo::ErrorEscritura; cliente.cerrado = true; continue; }
```

---

# Implementación final

```text
$ bash verif/scripts/TC-035.sh
PASS V1: submit aceptado persistido íntegro tras el corte y en estado terminal.
  bitácora: {"context": {"bytes_recibidos": 117, "identidad": "tcp-PC-B", "ip": "127.0.0.1",
  "job_id": 1, "motivo": "ERROR_SOCKET", "operacion": "submit", "request_id": "tc035-corte",
  "resultado": "ACEPTADA"}, "job_id": null, "level": "WARN", "message": "Solicitud interrumpida",
  "ts": "2026-11-19 20:41:15"}
PASS V2/AC2: bitácora coherente con el estado aplicado.
PASS V3/AC3: ping posterior correcto; el servicio sigue atendiendo.
PASS: RF-28 TC-035 sin fallos.

$ bash verif/scripts/TC-036.sh
PASS V1: jobs.json idéntico; la operación rechazada no alteró el estado.
  bitácora: {... "error": "NOT_CANCELABLE", "operacion": "cancel", "resultado": "RECHAZADA" ...}
PASS V2/AC2: rechazo documentado como RECHAZADA con NOT_CANCELABLE y job_id.
PASS V3/AC3: ping posterior correcto y Job base intacto.
PASS: RF-28 TC-036 sin fallos.

$ bash verif/scripts/TC-038.sh
  registros de solicitud interrumpida: 20 de 20 conexiones
PASS V1/AC1: 20 solicitudes procesadas, 20 registros; la ventana no aplica.
PASS V2/AC2: ping posterior correcto; el servicio sigue atendiendo.
PASS: RF-28 TC-038 sin fallos.
```

Regresión: `TC-030` a `TC-034` reejecutados en `PASS` con el binario nuevo, incluido `TC-033` ya ajustado a su nuevo escenario.

---

# Aprendizaje

La lección central no fue de C++ sino de orden de operaciones: un `poll()` que clasifica el error antes de drenar el búfer pierde datos que ya estaban en el socket, y el fallo es **no determinista**, porque depende de si el `RST` llega antes o después de la siguiente iteración. TC-035 pasó y TC-036 falló con el mismo código; sin dos escenarios distintos ese defecto habría llegado a producción como un "a veces no se registra".

La segunda lección es de disciplina con el requerimiento: la primera versión ampliaba la ventana de 60 s a cualquier cierre sin procesar. Sonaba razonable como defensa contra el abuso, pero contradecía la letra del RF —"cortes antes de recibir datos"— y habría dejado sin documentar solicitudes que sí empezaron. Cuando el texto es explícito, se implementa el texto y el riesgo se documenta aparte (R2), no se compensa en silencio con una decisión propia.

Finalmente, la ventana de 60 s y el `fsync` por evento son mecanismos que se estorban: si el registro es caro, la tentación es agrupar más casos bajo la ventana. RF-28 demuestra el límite correcto: la ventana amortigua ruido sin información, y el costo de documentar una solicitud real se paga siempre.
