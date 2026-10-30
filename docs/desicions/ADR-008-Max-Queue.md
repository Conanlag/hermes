# ADR-008: Capacidad máxima de cola y respuesta ante saturación

## Contexto

Hermes necesita establecer un límite para la cantidad de Jobs que pueden permanecer dentro del sistema de procesamiento.

La capacidad máxima se configura con `trabajos_maximos` en `config.json` (predeterminado: **5**, rango: **1–64**). Para este límite se cuentan los Jobs en `QUEUED` y `RUNNING`; los registros terminales no ocupan capacidad.

## Decisión

`trabajos_maximos` establece tanto el número de workers como la capacidad total de Jobs activos aceptados. La admisión cuenta `QUEUED` y `RUNNING` de forma conjunta.

Cuando se alcanza el límite, una solicitud nueva se rechaza inmediatamente con un mensaje explícito y código de salida distinto de cero. No se crea un registro para la solicitud rechazada. La comprobación y el registro se realizan bajo el mismo bloqueo de almacenamiento, por lo que solicitudes concurrentes no pueden sobrepasar el límite.

Cuando un Job pasa a un estado terminal, libera capacidad para solicitudes posteriores. Una repetición con el mismo `request_id` y el mismo programa/argumentos devuelve el Job ya existente, incluso si la cola está llena; no consume capacidad adicional.

Ejemplo:

```text
Capacidad: 5
Jobs 1–5 → QUEUED o RUNNING (5 activos en total)
Solicitud nueva → RECHAZADA (cola llena)
```

Cuando finalice el Job 1:

```text
Job 1 → SUCCEEDED
Quedan 4 Jobs activos; una solicitud nueva → aceptada
```

El límite de admisión usa la configuración existente de workers para evitar introducir dos capacidades configurables que puedan contradecirse. El número de workers determina cuántos Jobs pueden ejecutarse a la vez; `trabajos_maximos` también acota los trabajos admitidos, incluidos los que esperan.

## Justificación

| Justificación     | El límite evita acumulación ilimitada y el rechazo explícito permite al cliente reintentar sin mantener una solicitud bloqueada. |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | No establecer un límite; aceptar trabajos ilimitadamente; esperar hasta que haya espacio.                                             |
| Consecuencias     | Los solicitantes reciben un error explícito al llenarse la capacidad; una finalización permite aceptar solicitudes posteriores.      |
| Riesgos           | El cliente debe interpretar el rechazo y decidir cuándo reintentar.                                                                   |
| Evidencia técnica | La admisión cuenta trabajos `QUEUED` y `RUNNING` dentro de la transacción protegida de almacenamiento y rechaza sin añadir una fila.   |
