# RNF-07 — Límite de procesos concurrentes

## Descripción

La cola no deberá iniciar más procesos hijo que el límite de concurrencia configurado en `trabajos_maximos`.

> "No ejecutar más procesos que el límite de concurrencia. La cola no deberá iniciar más procesos que el límite de concurrencia."

## Categoría

Confiabilidad y control de concurrencia.

## Métrica de aceptación

- El número de Jobs activos (`QUEUED` y `RUNNING`) no rebasa `trabajos_maximos`.
- El scheduler no ejecuta más procesos hijo simultáneos que workers configurados.
- Una solicitud excedente recibe un rechazo explícito y no crea otro Job.

## Implementación

`crearJob()` cuenta los Jobs `QUEUED` y `RUNNING` dentro de la modificación protegida del historial. Cuando el total alcanza `trabajosMaximos`, no agrega el registro y devuelve un error de capacidad. El scheduler crea exactamente `trabajosMaximos` workers, por lo que su pool también limita cuántos procesos hijo puede supervisar simultáneamente.

La reserva de capacidad se serializa con la actualización de `jobs.json`; solicitudes concurrentes no pueden reservar el mismo espacio ni exceder el límite.

## Verificación

- [TC-024](../../../verif/test-cases/TC-024.md) observa tres Jobs `RUNNING` con límite `3` e intenta enviar un cuarto, que debe ser rechazado.
- [TC-023](../../../verif/test-cases/TC-023.md) presenta solicitudes concurrentes con capacidad `2`; valida que solo se admite el espacio disponible, que los rechazos no crean registros y que se libera capacidad al terminar un Job.

Ambas pruebas pasaron el 2026-10-30; véanse [results_TC-024.md](../../../verif/results/results_TC-024.md) y [results_TC-023.md](../../../verif/results/results_TC-023.md).

## Módulos o componentes afectados

- `job`: admisión y conteo de Jobs activos.
- `storage`: serialización de las modificaciones al historial.
- `scheduler`: pool de workers y ejecución de procesos hijo.
- [TC-023](../../../verif/scripts/TC-023.sh) y [TC-024](../../../verif/scripts/TC-024.sh): pruebas de límite y concurrencia.

## Restricciones

El límite aplica a procesos hijo administrados como Jobs por Hermes. Los cambios de configuración se aplican cuando se inicia el scheduler, no modifican el pool activo en caliente.
