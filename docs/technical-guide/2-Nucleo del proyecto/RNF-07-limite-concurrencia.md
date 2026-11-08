# RNF-07 — Límite de procesos concurrentes

## Descripción

La cola no deberá iniciar más procesos hijo que el límite de concurrencia configurado en `trabajos_maximos`. El requisito es de confiabilidad: sobrepasar el límite degrada la máquina anfitriona, distorsiona las mediciones de rendimiento y puede agotar descriptores o memoria justo cuando el sistema está bajo carga.

> "No ejecutar más procesos que el límite de concurrencia. La cola no deberá iniciar más procesos que el límite de concurrencia."

La garantía se apoya en una decisión estructural, no en una comprobación defensiva: **el número de procesos hijo posibles es el número de hilos trabajadores**, y ese número se fija al iniciar el scheduler. No existe un camino donde un hilo lance dos procesos a la vez ni donde un Job `QUEUED` se ejecute sin que un worker lo haya reservado.

## Categoría

Confiabilidad y control de concurrencia.

## Métrica de aceptación

- El número de Jobs en `RUNNING` no rebasa `trabajos_maximos` en ninguna instantánea consistente de `jobs.json`.
- El número de procesos hijo simultáneos del scheduler no rebasa `trabajos_maximos`.
- Los Jobs en `QUEUED` pueden superar el límite solo hasta los cupos habilitados explícitamente con `max_cola`, y **no cuentan como procesos** porque no han sido lanzados (véase [ADR-017](../../desicions/ADR-017-Cola-Espera.md)).
- Cuando también la capacidad total de admisión (`trabajos_maximos + max_cola`) se agota, la solicitud excedente recibe un rechazo explícito y no crea registro.

## Implementación

**Nivel de ejecución.** `ejecutarScheduler()` crea `trabajosMaximos` hilos y cada `trabajador()` ejecuta un ciclo estricto: reservar → `iniciarProceso()` (`fork` + `execvp`) → `esperarProceso()` (`waitpid`) → repetir. Un worker no puede abrir un segundo proceso mientras el primero no haya sido recolectado, así que el máximo de hijos vivos es el tamaño del pool.

```cpp
for (int i = 0; i < trabajosMaximos; ++i) {
    trabajadores.emplace_back(trabajador);
}
```

**Nivel de admisión.** `crearJob()` calcula la capacidad total y la comprueba dentro de la misma transacción protegida que inserta el registro:

```cpp
const size_t capacidadTotal =
    static_cast<size_t>(trabajosMaximos) + static_cast<size_t>(maxCola);
...
if (trabajosActivos >= capacidadTotal) {
    colaLlena = true;
    return false;
}
```

**Nivel de almacenamiento.** `modificarJobsSeguros()` toma `mutexStorage` y `flock(jobs.lock)` antes de leer y escribe con archivo temporal, `fsync` y `rename`. Dos solicitudes concurrentes no pueden evaluar el mismo estado ni reservar el mismo cupo.

**Nivel de reserva.** `reservarTrabajo()` marca `RUNNING` y devuelve `true` a un solo worker por Job; el `flock` del historial hace que la reserva sea exclusiva aunque varios workers sondeen a la vez.

## Verificación

- [TC-002](../../../verif/test-cases/TC-002.md) mantiene `trabajos_maximos = 3` con `max_cola = 1` y cuatro solicitudes en ráfaga; verifica en una instantánea única que hay exactamente `3` Jobs `RUNNING` —nunca cuatro— y `1` en `QUEUED`. Ejecutada en WSL: `[ PASS ]` en dos corridas consecutivas.
- [TC-023](../../../verif/test-cases/TC-023.md) presenta ocho solicitudes concurrentes con capacidad `2`; valida que solo se admite el espacio disponible, que los rechazos no crean registros, que cada rechazo deja un evento `WARN` con `capacidad` y `trabajos_activos`, y que un Job terminal libera capacidad. Resultado persistido en [results_TC-023.md](../../../verif/results/results_TC-023.md).
- [TC-024](../../../verif/scripts/TC-024.sh) somete al scheduler a estrés y comprueba que, al finalizar, no quedan procesos hijos ni descriptores residuales.

```bash
bash verif/scripts/TC-002.sh
bash verif/scripts/TC-023.sh
```

## Módulos o componentes afectados

- `scheduler`: pool de workers y ejecución de procesos hijo; es el que impone el techo real.
- `job`: admisión y conteo de Jobs activos y en espera.
- `config`: lectura de `trabajos_maximos` y `max_cola`.
- `storage`: serialización de las modificaciones al historial.
- [TC-002](../../../verif/scripts/TC-002.sh) y [TC-023](../../../verif/scripts/TC-023.sh): límite de concurrencia y rechazo por capacidad.

## Restricciones

El límite aplica a procesos hijo administrados como Jobs por Hermes; un proceso que un Job lance por su cuenta queda fuera del conteo, aunque hereda el grupo de procesos para poder terminarlo en el apagado. Los cambios de configuración se aplican cuando se inicia el scheduler, no modifican el pool activo en caliente. Un daemon iniciado con un valor antiguo seguirá ejecutando ese valor hasta que se reinicie con `hermes clean scheduler`; por eso la matriz de trazabilidad y las pruebas usan siempre un `HOME` temporal limpio.
