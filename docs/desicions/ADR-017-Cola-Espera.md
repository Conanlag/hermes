# ADR-017: Cola de espera independiente del límite de concurrencia

## Contexto

RF-03 exige que el sistema mantenga una cola cuando no exista capacidad inmediata de ejecución. [ADR-008](ADR-008-Max-Queue.md) y [ADR-015](ADR-015-Config-Queue.md) hicieron que `trabajos_maximos` fijara a la vez el número de workers y la capacidad total de admisión, contando `QUEUED` y `RUNNING` de forma conjunta. Con esa política, el pool consume todos los cupos de admisión, por lo que un Job nunca puede permanecer en `QUEUED`: el excedente se rechaza antes de existir. Ese defecto es el Issue #102 y se materializa en el fallo de `TC-002`.

La corrección no puede ser eliminar el rechazo: RF-23 y RF-25 exigen un rechazo explícito cuando la cola está saturada, y `TC-016`, `TC-023` y `TC-024` lo verifican.

## Decisión

Se separan las dos capacidades:

1. `trabajos_maximos` (de 1 a 64; predeterminado 5) dimensiona únicamente el **pool de workers**, es decir, el máximo de Jobs en `RUNNING`. El scheduler sigue creando exactamente esa cantidad de hilos, así que RNF-07 se mantiene: nunca hay más procesos hijo simultáneos que workers.
2. `max_cola` (de 0 a 256; predeterminado **0**) son los **cupos de espera** en `QUEUED` que se admiten por encima del límite de concurrencia.

La admisión en `crearJob()` rechaza cuando `QUEUED + RUNNING` alcanza la capacidad total `trabajos_maximos + max_cola`. El rechazo conserva el mensaje, el código de salida distinto de cero y el evento `WARN` con `motivo_del_rechazo`, `trabajos_activos`, `capacidad` y `trabajos_en_espera`.

Ejemplo con `trabajos_maximos = 3` y `max_cola = 1`:

```text
Jobs 1–3 → RUNNING
Job 4    → QUEUED  (RF-03)
Solicitud nueva → RECHAZADA (cola llena)
```

El valor por defecto `max_cola = 0` conserva exactamente la política de ADR-008: la capacidad total de admisión sigue siendo `trabajos_maximos` y el excedente se rechaza. La cola de espera es explícita y opt-in.

| Justificación     | Dos capacidades separadas permiten satisfacer RF-03 (cola real) y RF-23/RF-25 (rechazo explícito) sin que una anule a la otra. El default `0` evita romper el comportamiento ya documentado y probado. |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | Cola ilimitada (elimina RF-23/RF-25 y rompe TC-016 y TC-023); derivar la cola de `trabajos_maximos` (con capacidad 2 rompe la expectativa de TC-023 de 1 aceptación y 7 rechazos); mantener ADR-008 (deja RF-03 sin implementación). |
| Consecuencias     | Con `max_cola > 0` el excedente espera en lugar de perderse; el cliente deja de necesitar reintentos. La documentación de configuración debe mencionar ambas llaves.                                      |
| Riesgos           | Un `max_cola` alto retrasa la realimentación al cliente. La cola solo aplica al arrancar el scheduler, igual que `trabajos_maximos` (ADR-015).                                                            |
| Evidencia técnica | `config.h`/`config.cpp` parsean `max_cola` de forma tolerante; `crearJob()` compara contra `trabajosMaximos + maxCola` dentro de la transacción bloqueada; `main.cpp` propaga ambos valores; `actualizarConfiguracion()` valida y persiste una o ambas llaves bajo `config.lock` con escritura atómica; el pool de `scheduler.cpp` no cambia. |

## Relación con otras decisiones

Esta ADR sustituye el punto de admisión de [ADR-008](ADR-008-Max-Queue.md) y el punto 1 de [ADR-015](ADR-015-Config-Queue.md). El rechazo explícito, la idempotencia por `request_id`, la atomicidad de `jobs.json` y la aplicación de cambios de concurrencia solo al reiniciar el scheduler se mantienen vigentes.
