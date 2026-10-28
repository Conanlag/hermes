# RNF-06 — Capacidad y conservación de metadatos de Jobs

## Descripción

Hermes deberá soportar al menos 500 registros de trabajos sin perder sus identificadores, argumentos, estados, marcas de tiempo ni resultados. La cantidad de workers limita la ejecución concurrente, pero no la cantidad de registros persistidos.

## Categoría

Escalabilidad y confiabilidad.

## Métrica de aceptación

- `jobs.json` conserva al menos 500 Jobs como un arreglo JSON válido.
- Cada registro conserva un `job_id` único y los campos de metadatos requeridos.
- Los argumentos mantienen su tipo de arreglo y los trabajos terminados conservan tiempos de inicio y terminación y código de salida.
- Una consulta posterior puede recuperar los registros sin alterar el historial.

## Verificación

El caso de integración [TC-018](../../../verif/test-cases/TC-018.md) comprueba un fixture de 519 Jobs: valida IDs únicos, estructura JSON, metadatos y resultados; consulta los Jobs `echo`; y verifica que Hermes no modifique el fixture.

Como prueba manual de escritura en un `HOME` de prueba, el siguiente lote agrega 400 Jobs:

```bash
for i in {1..400}; do
    hermes job echo "HOLA MUNDO $i"
done
```

El lote debe ejecutarse cuando ya existan al menos 100 registros en ese entorno (o ajustarse para crear un total de 500). Después se puede crear un Job identificable y consultar sus registros:

```bash
time hermes job sleep 30
time hermes filter programa sleep
```

El comando `hermes job sleep 30` registra un Job y normalmente devuelve antes de que termine el proceso. La consulta por programa permite encontrarlo mientras está `RUNNING`; no debe confundirse el tiempo de esa consulta con la duración de `sleep`.

## Evidencia

Las ejecuciones de TC-018 validaron que los 519 Jobs del fixture conservaran IDs, metadatos y resultados. La evidencia está en [results_TC-018.md](../../../verif/results/results_TC-018.md). El fixture original está en `verif/json_test/TC-18/jobs.json`; la prueba lo copia a un directorio temporal y comprueba que no se altere.

## Módulos o componentes afectados

- `job`: creación de registros y asignación de identificadores.
- `storage`: persistencia y lectura del arreglo de Jobs.
- `filter`: consulta de registros persistidos.
- `verif/scripts/TC-018.sh`: validación del fixture y sus metadatos.

## Restricciones tecnológicas o de arquitectura

El scheduler usa una cantidad acotada de workers configurada por separado de la capacidad del historial. Ejecutar el lote manual agrega datos persistentes al `HOME` indicado; debe usarse un entorno aislado para evitar mezclar los Jobs de prueba con datos de usuario.
