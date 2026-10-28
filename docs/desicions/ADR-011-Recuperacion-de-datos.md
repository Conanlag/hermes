# ADR-011: Recuperación de datos y trabajos interrumpidos

## Contexto

Hermes conserva los Jobs en `jobs.json` y puede dejar de supervisarlos si el scheduler o el equipo termina inesperadamente. Al reiniciar, una fila `RUNNING` no permite saber si el programa concluyó; reencolarla podría ejecutar dos veces una operación con efectos externos. Además, una escritura interrumpida puede dejar inválido el archivo principal.

La recuperación debe distinguir los Jobs pendientes, los terminados y los que perdieron supervisor; evitar señalar procesos ajenos por reutilización de PID; y preservar la información válida ante corrupción del archivo.

## Decisión

1. Antes de recuperar, Hermes obtiene exclusividad sobre `scheduler.lock`; no modifica Jobs mientras otro scheduler activo los supervisa.
2. Al iniciar, verifica la capacidad de leer la identidad de proceso, limpia temporales huérfanos y valida `jobs.json`. Si el archivo principal no es válido y `jobs.json.bak` sí lo es, lo restaura y registra una advertencia.
3. Las filas `QUEUED` y los estados terminales conocidos se conservan. Las filas `RUNNING` sin supervisor y los estados desconocidos se clasifican como `INTERRUPTED`; este estado es terminal y no se reejecuta automáticamente.
4. Antes de enviar señales a un proceso huérfano, comprueba su identidad con los datos persistidos —incluidos `boot_id`, tiempo de inicio y grupo/sesión cuando están disponibles— para no actuar sobre un PID reutilizado. Termina el grupo verificado con `SIGTERM` y, tras una ventana de gracia, `SIGKILL`.
5. Persiste el resultado después de la actuación sobre el proceso. Registra el motivo, si el proceso terminó y la hora de recuperación. Si no puede verificar el proceso, no lo señaliza ni afirma que terminó.

## Justificación

| Justificación     | La recuperación fail-closed evita repetir trabajos cuyo resultado real se desconoce y evita conservar filas `RUNNING` sin supervisor. El respaldo permite restaurar el estado válido anterior si `jobs.json` se corrompe. |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | Reencolar automáticamente los Jobs `RUNNING`; confiar solo en el PID; descartar el archivo inválido y continuar con una cola vacía; exigir restauración manual del respaldo. |
| Consecuencias     | Un Job interrumpido requiere decisión humana para volver a ejecutarse. La verificación de identidad reduce el riesgo de señalizar procesos no relacionados. El inicio puede tardar mientras se terminan procesos huérfanos. |
| Riesgos           | Si ambos archivos (`jobs.json` y `jobs.json.bak`) son inválidos o no se puede verificar un proceso, la recuperación no puede reconstruir el resultado real. Las filas antiguas sin identidad completa tienen garantías limitadas para detectar descendientes. |
| Evidencia técnica | [recovery.cpp](../../src/hermes/src/recovery/recovery.cpp) clasifica Jobs y verifica procesos; [storage.cpp](../../src/hermes/src/storage/storage.cpp) valida y restaura desde el respaldo; [scheduler.cpp](../../src/hermes/src/scheduler/scheduler.cpp) ejecuta la recuperación bajo `scheduler.lock`. Los contratos están en [recovery.h](../../src/hermes/include/recovery.h) y [storage.h](../../src/hermes/include/storage.h); el flujo está descrito en [RF-13](../technical-guide/2-Nucleo%20del%20proyecto/RF-13.recuperacion-tras-reinicio.md). |