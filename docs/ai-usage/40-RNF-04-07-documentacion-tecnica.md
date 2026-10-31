# Uso de inteligencia artificial

# 40. Documentación técnica de RNF-04 y RNF-07

## Objetivo

Documentar la concurrencia mínima de tres Jobs (RNF-04) y el límite de procesos concurrentes (RNF-07), contrastando los enunciados con el código del scheduler y la evidencia automatizada.

## Resultado

- Se documentó RNF-04 en `docs/technical-guide/2-Nucleo del proyecto/RNF-04-concurrencia-minima.md`.
- Se documentó RNF-07 en `docs/technical-guide/2-Nucleo del proyecto/RNF-07-limite-concurrencia.md`.
- Se amplió TC-024 para observar tres Jobs `RUNNING` a la vez con límite `3`, y comprobar el rechazo de un cuarto.
- Se registró su ejecución PASS en `verif/results/results_TC-024.md`; TC-023 también pasó y respalda la admisión concurrente y el rechazo por capacidad.

## Verificación

`make -C src/hermes` terminó correctamente sin requerir recompilación. TC-023 y TC-024 terminaron con código `0`. La matriz de trazabilidad se actualizó con estos resultados.
