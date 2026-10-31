# RNF-10 — No reportar Jobs `RUNNING` tras reinicio si se perdió su supervisión

## Descripción

Después de un reinicio, Hermes no deberá reportar como `RUNNING` un proceso que ya no controla.

> "No reportar RUNNING después de reinicio si ya no existe el proceso. Tras reinicio, el sistema no deberá reportar como RUNNING un proceso que ya no controla."

## Categoría

Confiabilidad y recuperación.

## Métrica de aceptación

- Después de recuperar un historial tras una caída del daemon, no quedan Jobs obsoletos en `RUNNING`.
- Un Job cuya ejecución quedó interrumpida se registra como `INTERRUPTED`, no como exitoso ni como todavía activo.
- Los Jobs que aún están `QUEUED` y los estados terminales válidos se conservan.

## Implementación

Durante el arranque del scheduler, `recuperarTrabajosInterrumpidos()` inspecciona el historial. Solo los Jobs `RUNNING` requieren reconciliación; los pendientes y terminales se mantienen. Si falta un PID o su identidad no corresponde al proceso supervisado, el Job se marca `INTERRUPTED`, con código de salida `-1`, motivo y diagnóstico. La recuperación verifica la identidad del proceso para no señalizar procesos ajenos.

## Verificación

El caso de integración [TC-022](../../../verif/test-cases/TC-022.md) comprueba la caída abrupta con `SIGKILL` (b), la conservación de un proceso ajeno (c) y la limpieza del grupo descendiente sin líder (h). La prueba también valida otros escenarios de reconciliación. Las ejecuciones PASS están registradas en [results_TC-022.md](../../../verif/results/results_TC-022.md).

## Módulos o componentes afectados

- `recovery`: clasificación y reconciliación de Jobs `RUNNING`.
- `scheduler`: ejecución de la recuperación durante el arranque.
- `storage`: actualización protegida del historial.
- [TC-022](../../../verif/scripts/TC-022.sh): prueba de recuperación tras caída.

## Restricciones

La señalización de un proceso requiere identidad verificable. Si Hermes no puede demostrar que un proceso le pertenece, no lo señaliza; registra la limitación y evita afirmar una terminación que no pudo comprobar.
