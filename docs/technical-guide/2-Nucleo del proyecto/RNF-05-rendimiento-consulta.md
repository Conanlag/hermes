# RNF-05 — Rendimiento de consulta de estado

## Descripción

La consulta de estado de los Jobs deberá responder en menos de un segundo para al menos 100 trabajos almacenados en el entorno de prueba. Se mide el tiempo de respuesta del comando de consulta, no el tiempo que tarda un Job externo en ejecutarse.

## Categoría

Rendimiento.

## Métrica de aceptación

- Con 100 o más Jobs almacenados, la consulta devuelve sus resultados en menos de `1.0 s`.
- La consulta no modifica el historial persistido.
- La prueba automatizada usa un fixture de 519 Jobs, por lo que también ejercita un volumen mayor al mínimo.

## Verificación

El caso de sistema [TC-004](../../../verif/test-cases/TC-004.md) compila Hermes, configura 64 como límite de admisión en un `HOME` temporal, crea 100 Jobs `echo hola`, espera a que todos terminen y mide con `time` de Bash `hermes filter programa echo`. Comprueba que se devuelvan al menos 100 coincidencias y que la duración sea menor a un segundo.

La secuencia manual equivalente, en un entorno de prueba aislado, es:

```bash
for i in {1..100}; do hermes job echo hola; done
time hermes filter programa echo
```

La salida de `hermes filter programa echo` debe incluir al menos 100 Jobs. La prueba mide únicamente la duración de esa consulta, no el tiempo que tardan en ejecutarse los Jobs.

## Evidencia

La ejecución de TC-004 del 2026-10-30 consultó 100 Jobs en `0.013 s`, por debajo del umbral de `1.0 s`. La evidencia se conserva en [tc004.log](../../../verif/results/tc004.log). Las mediciones anteriores con un fixture de 519 registros están archivadas en [results_TC-018.md](../../../verif/results/results_TC-018.md); la trazabilidad vigente de RNF-05 corresponde a TC-004.

## Módulos o componentes afectados

- `filter`: lectura y presentación de los Jobs consultados.
- `storage`: lectura segura de `jobs.json`.
- `verif/scripts/TC-004.sh`: creación de 100 Jobs y medición de la consulta.

## Restricciones tecnológicas o de arquitectura

La medición depende del hardware, la carga del equipo y el almacenamiento. La prueba usa un `HOME` temporal para no medir ni modificar el historial personal. La referencia de aceptación es el entorno de prueba y no una garantía de latencia idéntica en cualquier equipo.
