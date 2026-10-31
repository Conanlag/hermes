# RNF-04 — Concurrencia mínima de trabajos

## Descripción

Con el límite de concurrencia configurado en `3`, Hermes deberá mantener al menos tres trabajos simultáneos durante una prueba controlada.

> "Al menos 3 trabajos simultáneos. Con el límite configurado en 3, el sistema deberá mantener al menos 3 trabajos simultáneos durante una prueba controlada."

## Categoría

Rendimiento y escalabilidad.

## Métrica de aceptación

- `trabajos_maximos` está configurado en `3` antes de iniciar el scheduler.
- Tres trabajos de larga duración alcanzan simultáneamente el estado `RUNNING`.
- La capacidad mínima se observa en una ejecución aislada, sin depender de trabajos de pruebas anteriores.

## Implementación

`hermes configmax 3` persiste el valor en `config.json`. El CLI carga esa configuración al iniciar el scheduler. `ejecutarScheduler()` reserva y crea tres workers cuando recibe ese límite; cada worker puede ejecutar un proceso hijo.

El cambio de configuración no ajusta workers de un scheduler que ya está activo. Se aplica al iniciar uno nuevo; `hermes clean scheduler` permite detener el actual para que el siguiente arranque lea el valor actualizado.

## Verificación

El caso de integración [TC-024](../../../verif/test-cases/TC-024.md) configura el máximo en `3`, lanza tres procesos `sleep`, y comprueba que los tres Jobs estén `RUNNING` en la misma observación. La prueba se ejecutó correctamente el 2026-10-30; el resultado persistido está en [results_TC-024.md](../../../verif/results/results_TC-024.md).

## Módulos o componentes afectados

- `config`: lectura y persistencia de `trabajos_maximos`.
- `scheduler`: creación del número configurado de workers.
- `job`: admisión de trabajos dentro de la capacidad activa.
- [TC-024](../../../verif/scripts/TC-024.sh): comprobación de tres Jobs simultáneos.

## Restricciones

La garantía se refiere a trabajos hijo admitidos por Hermes en un scheduler iniciado con el límite configurado. No implica que un cambio de configuración se aplique en caliente a un scheduler existente.
