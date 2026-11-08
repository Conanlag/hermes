
## Ejecucion: 2026-11-07 19:18:58 -0600

```text
[34mMáximo de trabajos simultáneos configurado en 10. El cambio de workers se aplica al iniciar el scheduler.[0m
[33mPara aplicarlo ahora, ejecute 'hermes clean scheduler'; los trabajos en ejecución serán interrumpidos.[0m
job ID: 1
PID: 5108
Línea base scheduler: RSS=4324KB, FDs=5, sockets=0
Después del estrés: RSS=8296KB, FDs=7, sockets=0, procesos hijos=0
FAIL: el scheduler no recuperó su cantidad inicial de descriptores.
```

## Ejecucion: 2026-11-07 19:19:23 -0600

```text
[34mMáximo de trabajos simultáneos configurado en 10. El cambio de workers se aplica al iniciar el scheduler.[0m
[33mPara aplicarlo ahora, ejecute 'hermes clean scheduler'; los trabajos en ejecución serán interrumpidos.[0m
job ID: 1
PID: 5552
Línea base scheduler: RSS=4296KB, FDs=5, sockets=0
Después del estrés: RSS=8036KB, FDs=5, sockets=0, procesos hijos=0
PASS parcial: memoria dentro de tolerancia; procesos, FDs y archivos temporales liberados.
Límite: Hermes no implementa sockets actualmente; se verificó que no quedaron sockets abiertos, pero no se estresó su ciclo de vida.
Scheduler detenido y sus descriptores liberados.
RNF-33 queda pendiente de cobertura activa de sockets.
```

## Ejecucion: 2026-11-07 19:24:02 -0600

```text
[34mMáximo de trabajos simultáneos configurado en 10. El cambio de workers se aplica al iniciar el scheduler.[0m
[33mPara aplicarlo ahora, ejecute 'hermes clean scheduler'; los trabajos en ejecución serán interrumpidos.[0m
job ID: 1
PID: 7459
Línea base scheduler: RSS=4180KB, FDs=5, sockets=0
Después del estrés: RSS=7876KB, FDs=5, sockets=0, procesos hijos=0
PASS parcial: memoria dentro de tolerancia; procesos, FDs y archivos temporales liberados.
Límite: Hermes no implementa sockets actualmente; se verificó que no quedaron sockets abiertos, pero no se estresó su ciclo de vida.
Scheduler detenido y sus descriptores liberados.
RNF-33 queda pendiente de cobertura activa de sockets.
```
