# RNF-04 — Concurrencia mínima de trabajos

## Descripción

Con el límite configurado en `3`, Hermes debe sostener al menos tres trabajos simultáneos durante una prueba controlada. El requisito no pide "hasta tres", sino que el sistema **aproveche** la capacidad que se le configuró: un scheduler que ejecutara de uno en uno cumpliría el techo pero incumpliría la expectativa de paralelismo.

> "Al menos 3 trabajos simultáneos. Con el límite configurado en 3, el sistema deberá mantener al menos 3 trabajos simultáneos durante una prueba controlada."

## Categoría

Rendimiento y escalabilidad.

## Métrica de aceptación

- `trabajos_maximos` está configurado en `3` antes de iniciar el scheduler.
- Existe al menos un Job admisible por encima del límite de concurrencia (`max_cola >= 1`), para que la ráfaga no se rechace antes de llegar a la cola.
- Tres trabajos de larga duración alcanzan simultáneamente el estado `RUNNING` en una misma instantánea de `jobs.json`.
- La capacidad mínima se observa en una ejecución aislada, sin depender de trabajos de pruebas anteriores.

## Implementación

`ejecutarScheduler(int trabajosMaximos)` crea **exactamente** `trabajosMaximos` hilos y los mantiene vivos hasta el apagado (`scheduler.cpp`). Cada hilo reserva un Job `QUEUED`, lanza su proceso hijo y se bloquea en `waitpid` hasta que termina; al volver, toma el siguiente. Como el número de hilos es fijo y cada uno atiende un solo proceso, la concurrencia alcanzable es igual al número configurado, sin necesidad de semáforos adicionales.

```cpp
vector<thread> trabajadores;
trabajadores.reserve(trabajosMaximos);
for (int i = 0; i < trabajosMaximos; ++i) {
    trabajadores.emplace_back(trabajador);
}
```

El límite se lee de `config.json` en `cargarConfiguracion()` y se propaga desde `main.cpp` al arrancar el demonio. El requisito de `max_cola >= 1` no es un adorno: con la capacidad total de admisión igual al número de workers, la ráfaga de cuatro solicitudes se rechazaría en la cuarta y no habría forma de observar la cola ni la concurrencia plena.

El cambio de configuración no ajusta workers de un scheduler que ya está activo. Se aplica al iniciar uno nuevo; `hermes clean scheduler` permite detener el actual para que el siguiente arranque lea el valor actualizado.

## Verificación

El caso de integración [TC-002](../../../verif/test-cases/TC-002.md) configura `trabajos_maximos = 3` y `max_cola = 1`, lanza cuatro `./hermes job sleep 10` en ráfaga y comprueba, en una única lectura de `jobs.json`, que existen exactamente tres Jobs `RUNNING` y uno `QUEUED`:

```bash
bash verif/scripts/TC-002.sh
```

```text
Paso 5 OK (3 Jobs RUNNING con límite 3)
Paso 6 OK (1 Job QUEUED retenido)
[ PASS ] TC-002
```

Se ejecutó en WSL (Ubuntu, g++ 15.2.0) dos veces consecutivas con resultado `[ PASS ]`.

> Nota de trazabilidad: la versión anterior de este documento atribuía la observación de tres Jobs simultáneos a `TC-024`. Esa prueba opera con `trabajos_maximos = 10` y su alcance es la liberación de recursos (RNF-33), no el mínimo de concurrencia; la evidencia correcta es `TC-002`.

## Módulos o componentes afectados

- `config`: lectura y persistencia de `trabajos_maximos` y `max_cola`.
- `scheduler`: creación del número configurado de workers y reserva de Jobs.
- `job`: admisión de trabajos dentro de la capacidad total.
- [TC-002](../../../verif/scripts/TC-002.sh): comprobación de tres Jobs simultáneos con límite `3`.

## Restricciones

La garantía se refiere a trabajos hijo admitidos por Hermes en un scheduler iniciado con el límite configurado. No implica que un cambio de configuración se aplique en caliente a un scheduler existente, ni que el sistema alcance la concurrencia mínima cuando las solicitudes se envían espaciadas en el tiempo: el requisito habla de una ráfaga sostenida, no de una garantía de ocupación permanente del pool.
