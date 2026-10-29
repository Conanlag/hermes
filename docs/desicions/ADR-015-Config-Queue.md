# ADR-015: Configuración de concurrencia y relación con la cola

## Contexto

Hermes persiste los Jobs en `jobs.json` y los procesa mediante workers del scheduler. La cantidad de workers determina cuántos Jobs pueden ejecutarse a la vez. A partir de RF-25, el mismo valor también limita la cantidad total de Jobs activos aceptados (`QUEUED` + `RUNNING`), pero no limita los registros terminales que se conservan.

El valor de concurrencia se configura mediante `trabajos_maximos` en `$HOME/.local/share/hermes/data/config.json`. El comando `hermes configmax <N>` ofrece una forma validada y segura de cambiarlo. Como el scheduler se ejecuta en segundo plano, actualizar el valor no modifica los workers de un daemon existente.

## Decisión

1. `trabajos_maximos` define la cantidad de workers del scheduler y también la capacidad máxima de Jobs activos que Hermes acepta. La capacidad de admisión incluye los Jobs `QUEUED` y `RUNNING`; los estados terminales quedan fuera.
2. El valor predeterminado es `5`; los valores permitidos son de `1` a `64`. Si el archivo no puede leerse, el JSON no es válido, falta la clave o su tipo no es entero, se usa el valor predeterminado. Los valores enteros fuera del rango se ajustan al límite más cercano. El número de workers se carga al iniciar el scheduler; el límite de admisión se vuelve a leer en cada invocación CLI.
3. La admisión se comprueba dentro de la modificación bloqueada de `jobs.json`. Si el número de Jobs activos ya alcanzó `trabajos_maximos`, la solicitud nueva se rechaza sin crear un registro. Un `request_id` repetido con el mismo contenido recupera el registro existente antes de aplicar el límite.
4. `hermes configmax <N>` actualiza el archivo de configuración sin iniciar ni reiniciar el scheduler. No se aplica una modificación de configuración en caliente. Para actualizar los workers activos, el usuario puede ejecutar `hermes clean scheduler`; el próximo comando que requiera el scheduler lo inicia de nuevo y carga el valor vigente. El cierre ordenado interrumpe los Jobs que estén ejecutándose.
5. El cierre ordenado detiene y registra como `INTERRUPTED` los Jobs que estaban activos; los Jobs `QUEUED` se conservan y pueden continuar cuando se inicie el scheduler nuevamente. El comando no borra `scheduler.lock` ni el historial.

## Justificación

| Justificación     | La configuración explícita permite ajustar concurrencia y admisión sin recompilar. Reutilizar un único límite evita dos capacidades configurables que puedan contradecirse. Un reinicio ordenado reutiliza los mecanismos de cierre, recuperación y bloqueo ya implementados. |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Alternativas      | Mantener el número de workers fijo en código; recargar la configuración en caliente; reiniciar el proceso con una señal externa o borrar manualmente `scheduler.lock`. |
| Consecuencias     | El número de workers cambia al iniciar el scheduler; el límite de admisión se toma de la configuración que carga cada invocación CLI. `hermes clean scheduler` permite aplicar el nuevo número de workers y conserva los Jobs pendientes. Los Jobs activos se interrumpen de forma explícita en lugar de dejar estados `RUNNING` sin supervisor. |
| Riesgos           | Un valor alto puede aumentar el consumo de recursos; por eso se limita a 64. Reiniciar mientras hay Jobs activos los interrumpe, lo cual debe comunicarse al usuario. |
| Evidencia técnica | `config.cpp` carga el valor; `config_update.cpp` lo valida y guarda atómicamente; `configmax` lo despacha desde `main.cpp`; `scheduler.cpp` crea esa cantidad de workers. TC-024 comprueba la persistencia, la validación del rango y el máximo de dos Jobs simultáneos. |