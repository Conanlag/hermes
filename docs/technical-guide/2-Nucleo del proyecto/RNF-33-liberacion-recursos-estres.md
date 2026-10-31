# RNF-33 — Liberación de recursos después de pruebas de estrés

## Descripción

Al concluir una carga de estrés, Hermes deberá liberar la memoria retenida por el scheduler, los procesos hijos, los descriptores de archivos y los sockets utilizados, así como los archivos temporales de persistencia.

## Categoría

Confiabilidad y gestión de recursos.

## Métrica de aceptación

La prueba compara el scheduler antes y después de ejecutar los Jobs:

- El RSS posterior no excede la línea base en más de `8192 KiB`.
- La cantidad de descriptores y sockets vuelve a coincidir con la línea base.
- No quedan procesos hijos ni archivos `jobs.json.tmp.*`.
- Al detener el scheduler, el proceso termina y libera sus descriptores.
- Para demostrar liberación de sockets usados durante el estrés, la prueba debe ejercitar una ruta que realmente los abra y cierre.

## Verificación

El caso de estrés [TC-024](../../../verif/test-cases/TC-024.md) ejecuta por defecto 100 Jobs `true`, en lotes concurrentes de hasta 10, espera a que terminen y compara RSS, descriptores, sockets, procesos hijos y temporales. Puede probarse otro volumen, por ejemplo:

```bash
make -C src/hermes
bash verif/scripts/TC-024.sh 500
```

La prueba usa un `HOME` temporal y limpia los datos al finalizar.

## Evidencia y cobertura

La ejecución más reciente de TC-024 reporta RSS de `3596 KiB` en la línea base y `7696 KiB` después del estrés (incremento de `4100 KiB`), sin procesos hijos ni sockets abiertos y con los mismos cinco descriptores antes y después. El scheduler liberó sus descriptores al detenerse. Las ejecuciones históricas y la evidencia más reciente están en [results_TC-024.md](../../../verif/results/results_TC-024.md).

**Estado: cobertura parcial.** Hermes no implementa actualmente una ruta que use sockets. TC-024 comprueba que no haya descriptores de socket abiertos al final, pero no estresa ni demuestra el ciclo de vida de sockets que nunca fueron abiertos por el servicio. RNF-33 requiere una prueba adicional cuando Hermes incorpore esa funcionalidad.

## Módulos o componentes afectados

- `scheduler`: ciclo de vida de workers, procesos hijos y descriptores.
- `process`: creación y recolección de procesos.
- `storage`: cierre de archivos y limpieza de temporales.
- `verif/scripts/TC-024.sh`: medición de memoria, descriptores, sockets, hijos y temporales.

## Restricciones tecnológicas o de arquitectura

La inspección de memoria, descriptores, sockets y procesos depende de Linux y `/proc`. La tolerancia de memoria es la definida por el caso automatizado; el uso de sockets permanece sin validar mientras no exista una ruta funcional que los utilice.
