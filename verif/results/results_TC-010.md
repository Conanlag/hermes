
## Ejecucion: 2026-11-27 16:35:22 -0600

- Commit: 31cbaf2
- Arbol: con cambios locales

```text
FAIL: PermissionError: [Errno 1] Operation not permitted
Resultado: 1

Codigo de salida TC-010: 1
```

## Ejecucion: 2026-11-27 16:35:27 -0600

- Commit: 31cbaf2
- Arbol: con cambios locales

```text
Modo: local
Destino solicitado: 127.0.0.1:33921
Cliente (etiqueta): PC-B
Ejecucion: tc010-e4ab77f35dd448bd84691040ae4f7f02
Destino efectivo: 127.0.0.1:45045
PASS V1/AC1: configuracion aislada y ping JSON correlacionado
$ hermes red job 127.0.0.1 --request-id tc010-e4ab77f35dd448bd84691040ae4f7f02-remoto-true true
job ID: 1
PID: pendiente (en cola)
$ hermes red filter 127.0.0.1 id 1
Job ID: 1
PID: 19335
Programa: true
Estado: SUCCEEDED
Codigo de salida: 0
Recepcion: 2026-11-27 16:35:27
Inicio: 2026-11-27 16:35:27
Terminacion: 2026-11-27 16:35:27
Argumentos:
PASS V2/AC2: true -> SUCCEEDED, codigo 0
$ hermes red job 127.0.0.1 --request-id tc010-e4ab77f35dd448bd84691040ae4f7f02-remoto-false false
job ID: 2
PID: pendiente (en cola)
$ hermes red filter 127.0.0.1 id 2
Job ID: 2
PID: 19338
Programa: false
Estado: FAILED
Codigo de salida: 1
Recepcion: 2026-11-27 16:35:27
Inicio: 2026-11-27 16:35:28
Terminacion: 2026-11-27 16:35:28
Mensaje de error: El proceso terminó con código de error 1
Argumentos:
PASS V3/AC3: false -> FAILED, codigo 1
$ hermes red job 127.0.0.1 --request-id tc010-e4ab77f35dd448bd84691040ae4f7f02-remoto-sleep sleep 120
job ID: 3
PID: pendiente (en cola)
$ hermes red filter 127.0.0.1 id 3
Job ID: 3
PID: 19341
Programa: sleep
Estado: RUNNING
Codigo de salida: -1
Recepcion: 2026-11-27 16:35:28
Inicio: 2026-11-27 16:35:28
Terminacion: 
Argumentos: 120
$ hermes red filter 127.0.0.1 status RUNNING
Job ID: 3
Programa: "sleep"
PID: 19341
Estado: "RUNNING"
Argumentos: "120" 
------------------------
$ hermes red filter 127.0.0.1 programa sleep
Job ID: 3
Programa: "sleep"
PID: 19341
Estado: "RUNNING"
Argumentos: "120" 
------------------------
PASS V4/AC4: RUNNING y filtros por id, estado y programa
$ hermes red job 127.0.0.1 --request-id tc010-e4ab77f35dd448bd84691040ae4f7f02-remoto-sleep sleep 120
job ID: 3
[34mSolicitud duplicada; se reutiliza el Job existente.[0m
$ hermes red job 127.0.0.1 --request-id tc010-e4ab77f35dd448bd84691040ae4f7f02-remoto-sleep sleep 119
[31mNo se pudo crear el Job: Error interno al procesar la solicitud[0m
FAIL: AssertionError: Conflicto de request_id sin codigo esperado
$ hermes red cancel 127.0.0.1 3
[34mCancelación solicitada para el Job: 3[0m
$ hermes clean scheduler
[34mScheduler detenido correctamente.[0m
PASS V12/AC12: cierre ordenado, scheduler detenido, puerto y procesos liberados
Resultado: 1

Codigo de salida TC-010: 1
```

## Ejecucion: 2026-11-27 16:35:49 -0600

- Commit: 31cbaf2
- Arbol: con cambios locales

```text
Modo: local
Destino solicitado: 127.0.0.1:54797
Cliente (etiqueta): PC-B
Ejecucion: tc010-86408e38519940e28fd4dce3daaeebd8
Destino efectivo: 127.0.0.1:41707
PASS V1/AC1: configuracion aislada y ping JSON correlacionado
$ hermes red job 127.0.0.1 --request-id tc010-86408e38519940e28fd4dce3daaeebd8-remoto-true true
job ID: 1
PID: pendiente (en cola)
$ hermes red filter 127.0.0.1 id 1
Job ID: 1
PID: 19458
Programa: true
Estado: SUCCEEDED
Codigo de salida: 0
Recepcion: 2026-11-27 16:35:49
Inicio: 2026-11-27 16:35:49
Terminacion: 2026-11-27 16:35:49
Argumentos:
PASS V2/AC2: true -> SUCCEEDED, codigo 0
$ hermes red job 127.0.0.1 --request-id tc010-86408e38519940e28fd4dce3daaeebd8-remoto-false false
job ID: 2
PID: pendiente (en cola)
$ hermes red filter 127.0.0.1 id 2
Job ID: 2
PID: 19461
Programa: false
Estado: FAILED
Codigo de salida: 1
Recepcion: 2026-11-27 16:35:49
Inicio: 2026-11-27 16:35:49
Terminacion: 2026-11-27 16:35:49
Mensaje de error: El proceso terminó con código de error 1
Argumentos:
PASS V3/AC3: false -> FAILED, codigo 1
$ hermes red job 127.0.0.1 --request-id tc010-86408e38519940e28fd4dce3daaeebd8-remoto-sleep sleep 120
job ID: 3
PID: pendiente (en cola)
$ hermes red filter 127.0.0.1 id 3
Job ID: 3
PID: 19464
Programa: sleep
Estado: RUNNING
Codigo de salida: -1
Recepcion: 2026-11-27 16:35:49
Inicio: 2026-11-27 16:35:50
Terminacion: 
Argumentos: 120
$ hermes red filter 127.0.0.1 status RUNNING
Job ID: 3
Programa: "sleep"
PID: 19464
Estado: "RUNNING"
Argumentos: "120" 
------------------------
$ hermes red filter 127.0.0.1 programa sleep
Job ID: 3
Programa: "sleep"
PID: 19464
Estado: "RUNNING"
Argumentos: "120" 
------------------------
PASS V4/AC4: RUNNING y filtros por id, estado y programa
$ hermes red job 127.0.0.1 --request-id tc010-86408e38519940e28fd4dce3daaeebd8-remoto-sleep sleep 120
job ID: 3
[34mSolicitud duplicada; se reutiliza el Job existente.[0m
$ hermes red job 127.0.0.1 --request-id tc010-86408e38519940e28fd4dce3daaeebd8-remoto-sleep sleep 119
[31mNo se pudo crear el Job: Error interno al procesar la solicitud[0m
  Rechazo JSON: {"error": "JOB_OPERATION_FAILED", "message": "Error interno al procesar la solicitud", "ok": false, "request_id": "tc010-86408e38519940e28fd4dce3daaeebd8-remoto-sleep", "version": 1}
PASS V5/AC5: duplicado reutiliza ID; argumentos distintos rechazados
$ hermes red cancel 127.0.0.1 3
[34mCancelación solicitada para el Job: 3[0m
$ hermes red filter 127.0.0.1 id 3
Job ID: 3
PID: 19464
Programa: sleep
Estado: CANCELED
Codigo de salida: -15
Recepcion: 2026-11-27 16:35:49
Inicio: 2026-11-27 16:35:50
Terminacion: 2026-11-27 16:35:50
Argumentos: 120
$ hermes red cancel 127.0.0.1 3
[31mEl Job no se puede cancelar (estado: CANCELED). Solo QUEUED o RUNNING.[0m
  Rechazo JSON: {"error": "NOT_CANCELABLE", "message": "El Job no se puede cancelar (estado: CANCELED). Solo QUEUED o RUNNING.", "ok": false, "request_id": "tc010-86408e38519940e28fd4dce3daaeebd8-3f3506b6", "version": 1}
PASS V6/AC6: cancelacion RUNNING confirmada y rechazo terminal
$ hermes job --request-id tc010-86408e38519940e28fd4dce3daaeebd8-local-true true
job ID: 1
PID: 19483
$ hermes filter id 1
Job ID: 1
PID: 19483
Programa: true
Estado: SUCCEEDED
Codigo de salida: 0
Recepcion: 2026-11-27 16:35:50
Inicio: 2026-11-27 16:35:50
Terminacion: 2026-11-27 16:35:50
Argumentos:
$ hermes job --request-id tc010-86408e38519940e28fd4dce3daaeebd8-local-false false
job ID: 2
[31mEl proceso terminó con código de error 1[0m
$ hermes filter id 2
Job ID: 2
PID: 19486
Programa: false
Estado: FAILED
Codigo de salida: 1
Recepcion: 2026-11-27 16:35:50
Inicio: 2026-11-27 16:35:50
Terminacion: 2026-11-27 16:35:50
Mensaje de error: El proceso terminó con código de error 1
Argumentos:
$ hermes job --request-id tc010-86408e38519940e28fd4dce3daaeebd8-local-sleep sleep 120
job ID: 3
PID: 19489
$ hermes filter id 3
Job ID: 3
PID: 19489
Programa: sleep
Estado: RUNNING
Codigo de salida: -1
Recepcion: 2026-11-27 16:35:50
Inicio: 2026-11-27 16:35:50
Terminacion: 
Argumentos: 120
$ hermes filter status RUNNING
Job ID: 3
Programa: "sleep"
PID: 19489
Estado: "RUNNING"
Argumentos: "120" 
------------------------
$ hermes filter programa sleep
Job ID: 3
Programa: "sleep"
PID: 19489
Estado: "RUNNING"
Argumentos: "120" 
------------------------
$ hermes job --request-id tc010-86408e38519940e28fd4dce3daaeebd8-local-sleep sleep 120
job ID: 3
[34mSolicitud duplicada; se reutiliza el Job existente.[0m
$ hermes job --request-id tc010-86408e38519940e28fd4dce3daaeebd8-local-sleep sleep 119
[31mNo se pudo crear el Job: El identificador de solicitud ya fue usado con otro programa o argumentos[0m
$ hermes cancel 3
[34mCancelación solicitada para el Job: 3[0m
$ hermes filter id 3
Job ID: 3
PID: 19489
Programa: sleep
Estado: CANCELED
Codigo de salida: -15
Recepcion: 2026-11-27 16:35:50
Inicio: 2026-11-27 16:35:50
Terminacion: 2026-11-27 16:35:50
Argumentos: 120
$ hermes cancel 3
[31mEl Job no se puede cancelar (estado: CANCELED). Solo QUEUED o RUNNING.[0m
PASS V7/AC7: equivalencia de resultados, filtros, duplicados y cancelacion
$ hermes red job 127.0.0.1 --request-id tc010-86408e38519940e28fd4dce3daaeebd8-block-True sleep 120
job ID: 4
PID: pendiente (en cola)
$ hermes red job 127.0.0.1 --request-id tc010-86408e38519940e28fd4dce3daaeebd8-queue-True sleep 120
job ID: 5
PID: pendiente (en cola)
$ hermes red cancel 127.0.0.1 5
[34mJob cancelado: 5[0m
$ hermes red cancel 127.0.0.1 4
[34mCancelación solicitada para el Job: 4[0m
$ hermes job --request-id tc010-86408e38519940e28fd4dce3daaeebd8-block-False sleep 120
job ID: 4
PID: 19504
$ hermes job --request-id tc010-86408e38519940e28fd4dce3daaeebd8-queue-False sleep 120
job ID: 5
PID: pendiente (en cola)
$ hermes cancel 5
[34mJob cancelado: 5[0m
$ hermes cancel 4
[34mCancelación solicitada para el Job: 4[0m
PASS V8/AC8: cancelacion QUEUED local y remota sin ejecucion
PASS V9/AC9: jobs.json integro, propiedad, unicidad y eventos correlacionados
$ hermes red start
No se pudo iniciar o mantener Hermes Red: Cada dirección de cliente debe ser una IPv4 unicast individual válida
$ hermes red job 203.0.113.1 true
Hermes Red: No se pudo conectar a un servidor LAN/VPN
PASS V10/AC10: destinos publicos rechazados; interfaz invalida solo usa loopback
SKIP: AC11 recorrido entre equipos LAN/VPN (modo local)
$ hermes clean scheduler
[34mScheduler detenido correctamente.[0m
$ hermes clean scheduler
[34mScheduler detenido correctamente.[0m
PASS V12/AC12: cierre ordenado, scheduler detenido, puerto y procesos liberados
PASS PARCIAL: RF-18 RF-19 RNF-26 TC-010; combinar evidencias local y LAN/VPN para cerrar el caso.
Resultado: 3

Codigo de salida TC-010: 3
```
