# RNF-27 — Consistencia de transiciones de estado concurrentes

## Descripción

Las transiciones de estado deberán permanecer consistentes ante solicitudes concurrentes. No se admitirán estados imposibles, regresiones desde estados terminales ni resultados persistidos contradictorios con la ejecución del Job.

## Categoría

Confiabilidad y concurrencia.

## Métrica de aceptación

- Cada Job sigue únicamente una secuencia válida: `QUEUED → RUNNING → SUCCEEDED`, `QUEUED → RUNNING → FAILED`, `QUEUED → RUNNING → CANCELED` o `QUEUED → CANCELED`.
- Los estados terminales no regresan a `QUEUED` ni a `RUNNING`.
- Ante solicitudes concurrentes de cancelación, el estado persistido final es coherente y `jobs.json` sigue siendo JSON válido.
- Los metadatos del resultado final, incluidos código de salida y tiempo de terminación, están presentes.

## Verificación

El caso de integración/concurrencia [TC-021](../../../verif/test-cases/TC-021.md) crea Jobs `sleep 30` concurrentemente y envía tres solicitudes de cancelación por Job. Un monitor observa las transiciones en `jobs.json`; al final, el script valida la secuencia permitida, los estados terminales y la validez del JSON.

Ejecución:

```bash
make -C src/hermes
bash verif/scripts/TC-021.sh
```

Puede indicarse el número de Jobs como argumento, por ejemplo `bash verif/scripts/TC-021.sh 25`.

## Evidencia

Las ejecuciones satisfactorias registradas incluyen 10 Jobs con 30 solicitudes concurrentes y 25 Jobs con 75 solicitudes concurrentes; no observaron regresiones y todos terminaron `CANCELED`. Una corrida inicial reportó un defecto en el analizador de traza de la prueba, que fue corregido; las corridas posteriores pasaron. Véanse [results_TC-021.md](../../../verif/results/results_TC-021.md) y el script [TC-021.sh](../../../verif/scripts/TC-021.sh).

## Módulos o componentes afectados

- `scheduler`: reserva de Jobs, ejecución, cancelación y persistencia de transiciones.
- `storage`: serialización de actualizaciones concurrentes del historial.
- `cancel`: coordinación de solicitudes de cancelación.
- `verif/scripts/TC-021.sh`: observación y validación de secuencias de estado.

## Restricciones tecnológicas o de arquitectura

Las transiciones de `jobs.json` se coordinan a través de la capa de almacenamiento, que serializa el ciclo de lectura y modificación. La prueba utiliza `/proc` para localizar y detener el scheduler aislado y usa un `HOME` temporal para no afectar datos reales.
