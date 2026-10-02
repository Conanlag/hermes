# ADR-010: Mecanismo de comunicación entre procesos (IPC)

## Contexto

Hermes debe ejecutar trabajos del sistema operativo en Linux y supervisarlos durante su ciclo de vida. Para ello, crea procesos hijos que ejecutan comandos externos y necesita conocer su estado, capturar errores y permitir su cancelación si un Job no puede continuar.

El sistema no requiere comunicación distribuida ni concurrencia compleja entre múltiples máquinas; sin embargo, sí requiere una forma segura y ligera de coordinar la interacción entre el proceso padre y cada proceso hijo. La solución debe ser compatible con la programación de sistemas en Linux y mantener la implementación simple, fiable y fácil de diagnosticar.

## Decisión

Hermes utilizará un mecanismo de IPC basado en `pipes` anónimos, junto con `fork()`, `exec*()` y `waitpid()`, para comunicar el proceso padre con los procesos hijos que ejecutan cada Job.

La implementación seguirá este flujo:

1. El proceso padre crea un hijo mediante `fork()`.
2. El hijo reemplaza su imagen con el comando solicitado usando `execv()` o `execvp()`.
3. El padre crea un `pipe` para capturar el `stderr` del hijo y redirige ese descriptor con `dup2()`.
4. El padre lee el flujo del pipe para registrar errores o mensajes del proceso ejecutado.
5. El padre usa `waitpid()` para sincronizar la finalización del proceso y obtener el código de salida.
6. Si el Job debe cancelarse, Hermes envía `SIGTERM` al PID del proceso hijo.

Este mecanismo es suficiente para la comunicación local dentro del mismo equipo, sin introducir dependencias de red, memoria compartida ni componentes adicionales de infraestructura.

## Justificación

| Justificación     | La comunicación entre procesos mediante pipes es la opción más directa en Linux para coordinar un proceso padre con sus hijos, permitiendo capturar errores, controlar la terminación y sincronizar la ejecución sin introducir complejidad innecesaria. |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | Sockets Unix, FIFOs, memoria compartida o la utilización de archivos temporales para comunicación entre Hermes y los Jobs.                                                                                                                                |
| Consecuencias     | El diseño resulta simple, eficiente y compatible con la API POSIX. Hermes puede ejecutar, supervisar y cancelar Jobs de manera determinista, con una trazabilidad de errores a través del `stderr` del proceso hijo. |
| Riesgos           | Un pipe puede bloquearse si el proceso hijo escribe demasiada salida de error sin que el padre la lea a tiempo. Por eso, la lectura del pipe debe gestionarse de forma continua durante la ejecución del Job. |
| Evidencia técnica | En la API de procesos se definen `iniciarProceso()`, `esperarProceso()` y `terminarProceso()` en [src/hermes/include/process.h](src/hermes/include/process.h). En [src/hermes/src/process/process.cpp](src/hermes/src/process/process.cpp) se crea el `pipe`, se redirige `stderr` con `dup2()` y se gestiona la finalización del hijo. En [src/hermes/src/job/job.cpp](src/hermes/src/job/job.cpp) se utilizan `pipeEscritura` y `pipeStderr` para capturar la salida y los errores del proceso ejecutado. |
