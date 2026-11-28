
## Ejecucion: 2026-11-27 20:02:47 -0600

- Modo: local
- Destino: scheduler propio, sin TCP
- Commit: b70d4b4
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol: con cambios locales

```text
Escenario: cola-real; trabajos_maximos=1; max_cola=1
  hermes job sleep 120 -> 0: job ID: 1
PID: 27
  hermes job sleep 120 -> 0: job ID: 2
PID: pendiente (en cola)
PASS V1/AC1: cola real con 1 worker y 1 cupo; Jobs 1=RUNNING y 2=QUEUED sin PID
  hermes cancel 2 -> 0: Job cancelado: 2
FAIL: AssertionError: Falta evento CANCELADO_EN_COLA
  hermes clean scheduler -> 0: Scheduler detenido correctamente.
Resultado: 1

Codigo de salida TC-005: 1
```

## Ejecucion: 2026-11-27 20:03:38 -0600

- Modo: local
- Destino: scheduler propio, sin TCP
- Commit: b70d4b4
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol: con cambios locales

```text
Escenario: cola-real; trabajos_maximos=1; max_cola=1
  hermes job sleep 120 -> 0: job ID: 1
PID: 22
  hermes job sleep 120 -> 0: job ID: 2
PID: pendiente (en cola)
PASS V1/AC1: cola real con 1 worker y 1 cupo; Jobs 1=RUNNING y 2=QUEUED sin PID
  hermes cancel 2 -> 0: Job cancelado: 2
PASS V2/AC2: QUEUED -> CANCELED/-1 sin iniciar proceso; bloqueador intacto y evento de cola
  hermes cancel 1 -> 0: Cancelación solicitada para el Job: 1
Escenario: ejecucion-real; trabajos_maximos=2; max_cola=1
  hermes job sleep 120 -> 0: job ID: 1
PID: 31
  hermes job sleep 120 -> 0: job ID: 2
PID: 33
  hermes cancel 1 -> 0: Cancelación solicitada para el Job: 1
  hermes filter id 1 -> 0: Job ID: 1
PID: 31
Programa: sleep
Estado: CANCELED
Codigo de salida: -15
Recepcion: 2026-11-27 20:03:39
Inicio: 2026-11-27 20:03:39
Terminacion: 2026-11-27 20:03:40
Argumentos: 120
PASS V3/AC3: RUNNING -> solicitud registrada -> CANCELED/-15; proceso 31 terminado
  hermes job true -> 0: job ID: 3
PID: 37
  hermes job false -> 1: job ID: 4
El proceso terminó con código de error 1
FAIL: AssertionError: Codigo 1; esperado 0: job ID: 4
El proceso terminó con código de error 1

  hermes clean scheduler -> 0: Scheduler detenido correctamente.
  hermes clean scheduler -> 0: Scheduler detenido correctamente.
Resultado: 1

Codigo de salida TC-005: 1
```

## Ejecucion: 2026-11-27 20:03:54 -0600

- Modo: local
- Destino: scheduler propio, sin TCP
- Commit: b70d4b4
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol: con cambios locales

```text
Escenario: cola-real; trabajos_maximos=1; max_cola=1
  hermes job sleep 120 -> 0: job ID: 1
PID: 22
  hermes job sleep 120 -> 0: job ID: 2
PID: pendiente (en cola)
PASS V1/AC1: cola real con 1 worker y 1 cupo; Jobs 1=RUNNING y 2=QUEUED sin PID
  hermes cancel 2 -> 0: Job cancelado: 2
PASS V2/AC2: QUEUED -> CANCELED/-1 sin iniciar proceso; bloqueador intacto y evento de cola
  hermes cancel 1 -> 0: Cancelación solicitada para el Job: 1
Escenario: ejecucion-real; trabajos_maximos=2; max_cola=1
  hermes job sleep 120 -> 0: job ID: 1
PID: 31
  hermes job sleep 120 -> 0: job ID: 2
PID: 33
  hermes cancel 1 -> 0: Cancelación solicitada para el Job: 1
  hermes filter id 1 -> 0: Job ID: 1
PID: 31
Programa: sleep
Estado: CANCELED
Codigo de salida: -15
Recepcion: 2026-11-27 20:03:55
Inicio: 2026-11-27 20:03:55
Terminacion: 2026-11-27 20:03:56
Argumentos: 120
PASS V3/AC3: RUNNING -> solicitud registrada -> CANCELED/-15; proceso 31 terminado
  hermes job true -> 0: job ID: 3
PID: 37
  hermes job false -> 1: job ID: 4
El proceso terminó con código de error 1
PASS V4/AC4: testigo RUNNING intacto y scheduler continua ejecutando trabajos posteriores
  hermes cancel 1 -> 1: El Job no se puede cancelar (estado: CANCELED). Solo QUEUED o RUNNING.
  hermes cancel 3 -> 1: El Job no se puede cancelar (estado: SUCCEEDED). Solo QUEUED o RUNNING.
  hermes cancel 4 -> 1: El Job no se puede cancelar (estado: FAILED). Solo QUEUED o RUNNING.
  hermes cancel 104 -> 1: No existe el Job ID: 104
  hermes cancel 0 -> 1: ID mal formado: debe ser mayor a 0.
  hermes cancel -1 -> 1: ID mal formado: -1. Debe ser un numero entero positivo.
  hermes cancel abc -> 1: ID mal formado: abc. Debe ser un numero entero positivo.
  hermes cancel -> 1: Uso: hermes cancel <id>
PASS V5/AC5: CANCELED/SUCCEEDED/FAILED, ID inexistente y argumentos invalidos: codigo 1 sin alterar Jobs
PASS V6/AC6: persistencia integra, solicitud y cancelacion correlacionadas por job_id, rechazo registrado
  hermes clean scheduler -> 0: Scheduler detenido correctamente.
  hermes clean scheduler -> 0: Scheduler detenido correctamente.
PASS V7/AC7: schedulers propios detenidos, sin procesos supervivientes; temporales eliminados al salir
PASS: RF-10 TC-005 sin fallos.
Resultado: 0

Codigo de salida TC-005: 0
```

## Ejecucion: 2026-11-27 20:16:33 -0600

- Modo: local
- Destino: scheduler propio, sin TCP
- Commit: b70d4b4
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol: con cambios locales

```text
Escenario: cola-real; trabajos_maximos=1; max_cola=1
  hermes job sleep 120 -> 0: job ID: 1
PID: 9440
  hermes job sleep 120 -> 0: job ID: 2
PID: pendiente (en cola)
PASS V1/AC1: cola real con 1 worker y 1 cupo; Jobs 1=RUNNING y 2=QUEUED sin PID
  hermes cancel 2 -> 0: Job cancelado: 2
PASS V2/AC2: QUEUED -> CANCELED/-1 sin iniciar proceso; bloqueador intacto y evento de cola
  hermes cancel 1 -> 0: Cancelación solicitada para el Job: 1
Escenario: ejecucion-real; trabajos_maximos=2; max_cola=1
  hermes job sleep 120 -> 0: job ID: 1
PID: 9466
  hermes job sleep 120 -> 0: job ID: 2
PID: 9468
  hermes cancel 1 -> 0: Cancelación solicitada para el Job: 1
  hermes filter id 1 -> 0: Job ID: 1
PID: 9466
Programa: sleep
Estado: CANCELED
Codigo de salida: -15
Recepcion: 2026-11-27 20:16:34
Inicio: 2026-11-27 20:16:34
Terminacion: 2026-11-27 20:16:35
Argumentos: 120
PASS V3/AC3: RUNNING -> solicitud registrada -> CANCELED/-15; proceso 9466 terminado
  hermes job true -> 0: job ID: 3
PID: 9473
  hermes job false -> 1: job ID: 4
El proceso terminó con código de error 1
PASS V4/AC4: testigo RUNNING intacto y scheduler continua ejecutando trabajos posteriores
  hermes cancel 1 -> 1: El Job no se puede cancelar (estado: CANCELED). Solo QUEUED o RUNNING.
  hermes cancel 3 -> 1: El Job no se puede cancelar (estado: SUCCEEDED). Solo QUEUED o RUNNING.
  hermes cancel 4 -> 1: El Job no se puede cancelar (estado: FAILED). Solo QUEUED o RUNNING.
  hermes cancel 104 -> 1: No existe el Job ID: 104
  hermes cancel 0 -> 1: ID mal formado: debe ser mayor a 0.
  hermes cancel -1 -> 1: ID mal formado: -1. Debe ser un numero entero positivo.
  hermes cancel abc -> 1: ID mal formado: abc. Debe ser un numero entero positivo.
  hermes cancel -> 1: Uso: hermes cancel <id>
PASS V5/AC5: CANCELED/SUCCEEDED/FAILED, ID inexistente y argumentos invalidos: codigo 1 sin alterar Jobs
PASS V6/AC6: persistencia integra, solicitud y cancelacion correlacionadas por job_id, rechazo registrado
  hermes clean scheduler -> 0: Scheduler detenido correctamente.
  hermes clean scheduler -> 0: Scheduler detenido correctamente.
PASS V7/AC7: schedulers propios detenidos, sin procesos supervivientes; temporales eliminados al salir
PASS: RF-10 TC-005 sin fallos.
Resultado: 0

Codigo de salida TC-005: 0
```

## Ejecucion: 2026-11-27 20:29:49 -0600

- Modo: local
- Destino: scheduler propio, sin TCP
- Commit: b70d4b4
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol: con cambios locales

```text
Escenario: cola-real; trabajos_maximos=1; max_cola=1
  hermes job sleep 120 -> 0: job ID: 1
PID: 11092
  hermes job sleep 120 -> 0: job ID: 2
PID: pendiente (en cola)
PASS V1/AC1: cola real con 1 worker y 1 cupo; Jobs 1=RUNNING y 2=QUEUED sin PID
  hermes cancel 2 -> 0: Job cancelado: 2
PASS V2/AC2: QUEUED -> CANCELED/-1 sin iniciar proceso; bloqueador intacto y evento de cola
  hermes cancel 1 -> 0: Cancelación solicitada para el Job: 1
Escenario: ejecucion-real; trabajos_maximos=2; max_cola=1
  hermes job sleep 120 -> 0: job ID: 1
PID: 11101
  hermes job sleep 120 -> 0: job ID: 2
PID: 11116
  hermes cancel 1 -> 0: Cancelación solicitada para el Job: 1
  hermes filter id 1 -> 0: Job ID: 1
PID: 11101
Programa: sleep
Estado: CANCELED
Codigo de salida: -15
Recepcion: 2026-11-27 20:29:50
Inicio: 2026-11-27 20:29:50
Terminacion: 2026-11-27 20:29:50
Argumentos: 120
PASS V3/AC3: RUNNING -> solicitud registrada -> CANCELED/-15; proceso 11101 terminado
  hermes job true -> 0: job ID: 3
PID: 11120
  hermes job false -> 1: job ID: 4
El proceso terminó con código de error 1
PASS V4/AC4: testigo RUNNING intacto y scheduler continua ejecutando trabajos posteriores
  hermes cancel 1 -> 1: El Job no se puede cancelar (estado: CANCELED). Solo QUEUED o RUNNING.
  hermes cancel 3 -> 1: El Job no se puede cancelar (estado: SUCCEEDED). Solo QUEUED o RUNNING.
  hermes cancel 4 -> 1: El Job no se puede cancelar (estado: FAILED). Solo QUEUED o RUNNING.
  hermes cancel 104 -> 1: No existe el Job ID: 104
  hermes cancel 0 -> 1: ID mal formado: debe ser mayor a 0.
  hermes cancel -1 -> 1: ID mal formado: -1. Debe ser un numero entero positivo.
  hermes cancel abc -> 1: ID mal formado: abc. Debe ser un numero entero positivo.
  hermes cancel -> 1: Uso: hermes cancel <id>
PASS V5/AC5: CANCELED/SUCCEEDED/FAILED, ID inexistente y argumentos invalidos: codigo 1 sin alterar Jobs
PASS V6/AC6: persistencia integra, solicitud y cancelacion correlacionadas por job_id, rechazo registrado
  hermes clean scheduler -> 0: Scheduler detenido correctamente.
  hermes clean scheduler -> 0: Scheduler detenido correctamente.
PASS V7/AC7: schedulers propios detenidos, sin procesos supervivientes; temporales eliminados al salir
PASS: RF-10 TC-005 sin fallos.
Resultado: 0

Codigo de salida TC-005: 0
```
