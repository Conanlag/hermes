# ADR-009: Gestión de la cola en memoria

## Contexto

Hermes necesita administrar los Jobs que se encuentran pendientes de ejecución. Debido a que el sistema actualmente no implementa concurrencia, los Jobs deben procesarse de manera secuencial.

Se requiere determinar cómo se almacenarán temporalmente los Jobs pendientes y en qué orden serán procesados.

## Decisión

La cola de Jobs se administrará **en memoria** y utilizará un comportamiento **FIFO (First In, First Out)**.

Los Jobs serán procesados en el mismo orden en que fueron recibidos por Hermes.

Por ejemplo:

```text
Llegada:

Job 1
Job 2
Job 3
Job 4
Job 5
```

Orden de procesamiento:

```text
Job 1 → RUNNING
Job 1 → SUCCEEDED

Job 2 → RUNNING
Job 2 → SUCCEEDED

Job 3 → RUNNING
...
```

Mientras un Job se encuentra en ejecución, los siguientes Jobs permanecen pendientes en la cola.

La cola en memoria representa el estado temporal de los Jobs durante la ejecución de Hermes. La información permanente de los Jobs se mantiene mediante el mecanismo de persistencia definido en el **ADR-005: Implementación de persistencia**.

## Justificación

| Justificación     | La administración en memoria permite implementar una cola sencilla para el procesamiento secuencial de Jobs sin introducir infraestructura adicional. El comportamiento FIFO garantiza que los Jobs sean procesados en el orden en que fueron recibidos. |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | Utilizar una cola persistente en disco o una estructura de base de datos para administrar los Jobs pendientes.                                                                                                                                           |
| Consecuencias     | La cola es sencilla de implementar y permite procesar los Jobs de manera secuencial y predecible.                                                                                                                                                        |
| Riesgos           | Los elementos de la cola en memoria pueden perderse si Hermes termina inesperadamente antes de procesarlos.                                                                                                                                              |
| Evidencia técnica | Los Jobs pendientes se administran en memoria y se procesan secuencialmente siguiendo el orden de llegada (FIFO).                                                                                                                                        |
