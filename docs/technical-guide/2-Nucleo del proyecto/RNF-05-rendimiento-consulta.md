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

El caso de integración [TC-018](../../../verif/test-cases/TC-018.md) compila Hermes, copia el fixture a un `HOME` temporal y mide con `time` de Bash `hermes filter programa echo`. Comprueba que se devuelvan al menos 100 coincidencias, que la duración sea menor a un segundo y que el fixture no cambie.

La secuencia manual equivalente, en un entorno de prueba con Jobs `echo` ya almacenados, es:

```bash
time hermes filter programa echo
```

`time hermes job echo` permite observar el tiempo de recepción de un Job, pero no mide la latencia de consulta y por sí solo no demuestra este requisito.

## Evidencia

En las ejecuciones registradas de TC-018, la consulta con 519 registros tardó `0.060 s`, `0.049 s` y `0.046 s`; todas cumplieron el umbral. Los resultados se conservan en [results_TC-018.md](../../../verif/results/results_TC-018.md).

## Módulos o componentes afectados

- `filter`: lectura y presentación de los Jobs consultados.
- `storage`: lectura segura de `jobs.json`.
- `verif/scripts/TC-018.sh`: medición del tiempo y validación de resultados.

## Restricciones tecnológicas o de arquitectura

La medición depende del hardware, la carga del equipo y el almacenamiento. La prueba usa un `HOME` temporal para no medir ni modificar el historial personal. La referencia de aceptación es el entorno de prueba y no una garantía de latencia idéntica en cualquier equipo.
