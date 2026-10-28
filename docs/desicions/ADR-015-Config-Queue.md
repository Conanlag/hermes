# ADR-015: Configuración de concurrencia y relación con la cola

## Contexto

Hermes persiste los Jobs en `jobs.json` y los procesa mediante workers del scheduler. La cantidad de workers determina cuántos Jobs pueden ejecutarse a la vez; no determina la capacidad de la cola ni la cantidad total de registros que se conservan. Este ADR complementa ADR-008 al distinguir la concurrencia configurada del límite de cola tratado allí.

El valor de concurrencia se configura mediante `trabajos_maximos` en `$HOME/.local/share/hermes/data/config.json`. Como el scheduler se ejecuta en segundo plano, editar el archivo no modifica los workers de un daemon existente. También se necesita una manera segura y sencilla de reiniciar el scheduler para aplicar la configuración nueva.

## Decisión

1. `trabajos_maximos` define la cantidad de workers del scheduler y, por tanto, el máximo de Jobs que Hermes puede ejecutar concurrentemente.
2. El valor se carga al iniciar el scheduler. El valor predeterminado es `5`; los valores permitidos son de `1` a `64`. Si el archivo no puede leerse, el JSON no es válido, falta la clave o su tipo no es entero, se usa el valor predeterminado. Los valores enteros fuera del rango se ajustan al límite más cercano.
3. La cola permanece separada de la concurrencia: los Jobs aceptados se guardan en `jobs.json` y los que no han sido reservados permanecen en `QUEUED`. Los workers reservan Jobs pendientes siguiendo el orden del arreglo persistido.
4. No se aplica una modificación de configuración en caliente. El usuario puede ejecutar `hermes clean scheduler`; el próximo comando que requiera el scheduler lo inicia de nuevo y carga el valor vigente.
5. El cierre ordenado detiene y registra como `INTERRUPTED` los Jobs que estaban activos; los Jobs `QUEUED` se conservan y pueden continuar cuando se inicie el scheduler nuevamente. El comando no borra `scheduler.lock` ni el historial.

## Justificación

| Justificación     | La configuración explícita permite ajustar la concurrencia sin recompilar. Mantener separado el número de workers de la cola evita confundir capacidad de ejecución con persistencia de Jobs. Un reinicio ordenado reutiliza los mecanismos de cierre, recuperación y bloqueo ya implementados. |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | Mantener el número de workers fijo en código; recargar la configuración en caliente; reiniciar el proceso con una señal externa o borrar manualmente `scheduler.lock`. |
| Consecuencias     | Los cambios se aplican al iniciar el scheduler, no inmediatamente al escribir `config.json`. `hermes clean scheduler` simplifica ese ciclo y conserva los Jobs pendientes. Los Jobs activos se interrumpen de forma explícita en lugar de dejar estados `RUNNING` sin supervisor. |
| Riesgos           | Un valor alto puede aumentar el consumo de recursos; por eso se limita a 64. Reiniciar mientras hay Jobs activos los interrumpe, lo cual debe comunicarse al usuario. |
| Evidencia técnica | `config.cpp` carga y valida `trabajos_maximos`; `main.cpp` inyecta el valor al scheduler; `scheduler.cpp` crea esa cantidad de workers y mantiene `scheduler.lock`. `clean scheduler` solicita `SIGTERM` y espera la liberación del lock. Se verificó con un `HOME` temporal que un límite de 1 deja el siguiente Job en `QUEUED`, que el apagado marca el activo como `INTERRUPTED` y que un Job posterior se procesa tras el reinicio. |