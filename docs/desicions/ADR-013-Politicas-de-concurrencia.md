# ADR-013: Políticas de concurrencia

## Contexto

Hermes permite que varios workers del scheduler ejecuten Jobs y que distintos procesos —por ejemplo, el CLI y el daemon— consulten o modifiquen los mismos archivos. Sin coordinación, dos workers podrían reservar el mismo Job, las escrituras podrían perder actualizaciones y un apagado podría competir con el inicio de nuevos procesos.

## Decisión

1. El scheduler usa un pool acotado de workers; su cantidad se carga desde `trabajos_maximos`, según [ADR-015](ADR-015-Config-Queue.md). Los Jobs pendientes se reservan en el orden persistido.
2. La reserva y transición de `QUEUED` a `RUNNING` se realizan mediante la modificación protegida de almacenamiento, de modo que un Job no sea reclamado simultáneamente por más de un worker.
3. Todas las lecturas y modificaciones de `jobs.json` pasan por la capa de almacenamiento, que combina `mutexStorage` para concurrencia dentro del proceso y `flock` sobre `jobs.lock` entre procesos.
4. Solo un scheduler puede supervisar Jobs a la vez: el daemon conserva el bloqueo de `scheduler.lock` durante su vida. Los procesos hijos no heredan ese descriptor.
5. El scheduler coordina el apagado con una puerta de inicio, un registro protegido de procesos activos y una condición de espera. Al recibir `SIGTERM` o `SIGINT`, evita nuevas reservas, termina los procesos activos y persiste sus estados antes de finalizar.

## Justificación

| Justificación     | Los bloqueos de almacenamiento protegen la consistencia del estado compartido; el bloqueo del scheduler evita supervisores duplicados. El pool limita la ejecución simultánea y la coordinación del apagado evita iniciar trabajos durante el cierre. |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | Procesar un solo Job a la vez; permitir que cada worker escriba directamente el JSON; usar únicamente mutexes locales; ejecutar varios daemons sobre el mismo historial. |
| Consecuencias     | Puede haber varios Jobs en ejecución, pero la persistencia se serializa. El número de workers limita la concurrencia de ejecución, no la cantidad total de Jobs en cola. El cierre ordenado puede interrumpir trabajos activos. |
| Riesgos           | Un bloqueo retenido por un proceso que no termina puede retrasar operaciones. Un valor de concurrencia elevado aumenta el consumo de recursos; el rango de configuración se limita según ADR-015. |
| Evidencia técnica | [scheduler.cpp](../../src/hermes/src/scheduler/scheduler.cpp) implementa los workers, la reserva, los bloqueos y el coordinador de apagado; [storage.cpp](../../src/hermes/src/storage/storage.cpp) serializa las operaciones de datos; [clean.cpp](../../src/hermes/src/clean/clean.cpp) coordina la limpieza con `scheduler.lock`. La cantidad de workers se documenta en [ADR-015](ADR-015-Config-Queue.md). |