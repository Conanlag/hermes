# ADR-008: Capacidad máxima de cola y respuesta ante saturación

## Contexto

Hermes necesita establecer un límite para la cantidad de Jobs que pueden permanecer dentro del sistema de procesamiento.

Para el alcance actual se establece una capacidad máxima de **5 Jobs**. Cuando se alcanza esta capacidad, los nuevos Jobs deben permanecer en estado `QUEUED` hasta que exista espacio disponible.

## Decisión

Se establece una capacidad máxima de **5 Jobs** para la cola de procesamiento.

Cuando se alcanza el límite, los nuevos Jobs permanecerán en estado `QUEUED` y no serán rechazados.

Una vez que un Job termine su ejecución, se liberará un espacio para que el siguiente Job pueda ser procesado.

Ejemplo:

```text
Job 1 → RUNNING
Job 2 → QUEUED
Job 3 → QUEUED
Job 4 → QUEUED
Job 5 → QUEUED
```

Cuando finalice el Job 1:

```text
Job 1 → SUCCEEDED
Job 2 → RUNNING
Job 3 → QUEUED
Job 4 → QUEUED
Job 5 → QUEUED
```

La implementación de concurrencia no forma parte de esta decisión.

## Justificación

| Justificación     | Se establece un límite de 5 Jobs para controlar la cantidad de trabajos pendientes y evitar una acumulación ilimitada dentro del sistema. |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | No establecer un límite o rechazar nuevos Jobs cuando se alcance la capacidad máxima.                                                     |
| Consecuencias     | Los Jobs que lleguen cuando la capacidad esté ocupada permanecerán en estado `QUEUED` hasta que exista espacio disponible.                |
| Riesgos           | Los Jobs pueden permanecer en `QUEUED` durante periodos prolongados si los procesos anteriores tardan en finalizar.                       |
| Evidencia técnica | Hermes utiliza una capacidad máxima de 5 Jobs y mantiene los Jobs adicionales en estado `QUEUED` cuando se alcanza dicho límite.          |
