
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

## Ejecucion: 2026-11-27 17:02:01 -0600

- Commit: b4467ed
- Arbol: con cambios locales
- Procedencia: salida compartida por el usuario en esta conversación; confirmó su ejecución desde PC B hacia PC A.
- Topología comunicada: PC B Windows `192.168.1.81` / WSL `172.23.236.91` → Windows A `192.168.1.83:45820` → WSL A `172.25.70.19:45820`; gateway/origen esperado hacia WSL A `172.25.64.1`.
- Formato: se restituyeron las cercas Markdown y se retiraron espacios al final de línea; las marcas de color se conservan tal como fueron compartidas.

```text
Modo: remoto
Destino solicitado: 192.168.1.83:45820
Cliente (etiqueta): PC-B
Ejecucion: tc010-bf1ad1e02e934178af47705a1b0818b0
PASS V1/AC1: configuracion aislada y ping JSON correlacionado
$ hermes red job 192.168.1.83 --request-id tc010-bf1ad1e02e934178af47705a1b0818b0-remoto-true true
job ID: 166
PID: pendiente (en cola)
$ hermes red filter 192.168.1.83 id 166
Job ID: 166
PID: 24525
Programa: true
Estado: SUCCEEDED
Codigo de salida: 0
Recepcion: 2026-11-27 17:02:01
Inicio: 2026-11-27 17:02:01
Terminacion: 2026-11-27 17:02:01
Argumentos:
PASS V2/AC2: true -> SUCCEEDED, codigo 0
$ hermes red job 192.168.1.83 --request-id tc010-bf1ad1e02e934178af47705a1b0818b0-remoto-false false
job ID: 167
PID: pendiente (en cola)
$ hermes red filter 192.168.1.83 id 167
Job ID: 167
PID: 24532
Programa: false
Estado: FAILED
Codigo de salida: 1
Recepcion: 2026-11-27 17:02:01
Inicio: 2026-11-27 17:02:02
Terminacion: 2026-11-27 17:02:02
Mensaje de error: El proceso terminó con código de error 1
Argumentos:
PASS V3/AC3: false -> FAILED, codigo 1
$ hermes red job 192.168.1.83 --request-id tc010-bf1ad1e02e934178af47705a1b0818b0-remoto-sleep sleep 120
job ID: 168
PID: pendiente (en cola)
$ hermes red filter 192.168.1.83 id 168
Job ID: 168
PID: 24533
Programa: sleep
Estado: RUNNING
Codigo de salida: -1
Recepcion: 2026-11-27 17:02:02
Inicio: 2026-11-27 17:02:02
Terminacion:
Argumentos: 120
$ hermes red filter 192.168.1.83 status RUNNING
Job ID: 168
Programa: "sleep"
PID: 24533
Estado: "RUNNING"
Argumentos: "120"
------------------------
$ hermes red filter 192.168.1.83 programa sleep
Job ID: 139
Programa: "sleep"
PID: 19962
Estado: "SUCCEEDED"
Argumentos: "120"
------------------------
Job ID: 140
Programa: "sleep"
PID: 20313
Estado: "CANCELED"
Argumentos: "120"
------------------------
Job ID: 141
Programa: "sleep"
PID: 20419
Estado: "SUCCEEDED"
Argumentos: "120"
------------------------
Job ID: 142
Programa: "sleep"
PID: 20426
Estado: "SUCCEEDED"
Argumentos: "120"
------------------------
Job ID: 143
Programa: "sleep"
PID: 20435
Estado: "SUCCEEDED"
Argumentos: "120"
------------------------
Job ID: 144
Programa: "sleep"
PID: 20436
Estado: "SUCCEEDED"
Argumentos: "120"
------------------------
Job ID: 145
Programa: "sleep"
PID: 20444
Estado: "SUCCEEDED"
Argumentos: "120"
------------------------
Job ID: 146
Programa: "sleep"
PID: 20445
Estado: "SUCCEEDED"
Argumentos: "120"
------------------------
Job ID: 147
Programa: "sleep"
PID: 20446
Estado: "SUCCEEDED"
Argumentos: "120"
------------------------
Job ID: 148
Programa: "sleep"
PID: 20453
Estado: "SUCCEEDED"
Argumentos: "120"
------------------------
Job ID: 149
Programa: "sleep"
PID: 20454
Estado: "CANCELED"
Argumentos: "120"
------------------------
Job ID: 150
Programa: "sleep"
PID: 20492
Estado: "SUCCEEDED"
Argumentos: "120"
------------------------
Job ID: 151
Programa: "sleep"
PID: 10066
Estado: "SUCCEEDED"
Argumentos: "120"
------------------------
Job ID: 152
Programa: "sleep"
PID: 11076
Estado: "SUCCEEDED"
Argumentos: "120"
------------------------
Job ID: 155
Programa: "sleep"
PID: 11669
Estado: "SUCCEEDED"
Argumentos: "120"
------------------------
Job ID: 159
Programa: "sleep"
PID: 21048
Estado: "SUCCEEDED"
Argumentos: "30"
------------------------
Job ID: 161
Programa: "sleep"
PID: 21754
Estado: "CANCELED"
Argumentos: "120"
------------------------
Job ID: 165
Programa: "sleep"
PID: 24089
Estado: "SUCCEEDED"
Argumentos: "30"
------------------------
Job ID: 168
Programa: "sleep"
PID: 24533
Estado: "RUNNING"
Argumentos: "120"
------------------------
PASS V4/AC4: RUNNING y filtros por id, estado y programa
$ hermes red job 192.168.1.83 --request-id tc010-bf1ad1e02e934178af47705a1b0818b0-remoto-sleep sleep 120
job ID: 168
[34mSolicitud duplicada; se reutiliza el Job existente.[0m
$ hermes red job 192.168.1.83 --request-id tc010-bf1ad1e02e934178af47705a1b0818b0-remoto-sleep sleep 119
[31mNo se pudo crear el Job: Error interno al procesar la solicitud[0m
  Rechazo JSON: {"error": "JOB_OPERATION_FAILED", "message": "Error interno al procesar la solicitud", "ok": false, "request_id": "tc010-bf1ad1e02e934178af47705a1b0818b0-remoto-sleep", "version": 1}
PASS V5/AC5: duplicado reutiliza ID; argumentos distintos rechazados
$ hermes red cancel 192.168.1.83 168
[34mCancelación solicitada para el Job: 168[0m
$ hermes red filter 192.168.1.83 id 168
Job ID: 168
PID: 24533
Programa: sleep
Estado: CANCELED
Codigo de salida: -15
Recepcion: 2026-11-27 17:02:02
Inicio: 2026-11-27 17:02:02
Terminacion: 2026-11-27 17:02:02
Argumentos: 120
$ hermes red cancel 192.168.1.83 168
[31mEl Job no se puede cancelar (estado: CANCELED). Solo QUEUED o RUNNING.[0m
  Rechazo JSON: {"error": "NOT_CANCELABLE", "message": "El Job no se puede cancelar (estado: CANCELED). Solo QUEUED o RUNNING.", "ok": false, "request_id": "tc010-bf1ad1e02e934178af47705a1b0818b0-b8e0f4de", "version": 1}
PASS V6/AC6: cancelacion RUNNING confirmada y rechazo terminal
PASS V11/AC11: flujo desde el cliente al destino LAN/VPN indicado por el operador
AVISO: conservar topologia PC B -> PC A; el script no certifica que sean equipos distintos
SKIP: AC7 requiere controlar/inspeccionar servidor propio (modo remoto)
SKIP: AC8 requiere controlar/inspeccionar servidor propio (modo remoto)
SKIP: AC9 requiere controlar/inspeccionar servidor propio (modo remoto)
SKIP: AC10 requiere controlar/inspeccionar servidor propio (modo remoto)
SKIP: AC12 requiere controlar/inspeccionar servidor propio (modo remoto)
PASS PARCIAL: RF-18 RF-19 RNF-26 TC-010; combinar evidencias local y LAN/VPN para cerrar el caso.
Resultado: 3

Codigo de salida TC-010: 3
```

## Revisión conjunta y cierre — 2026-11-27

**Resultado del caso TC-010: PASS, por cobertura conjunta local y LAN.** Esta
conclusión es una revisión de las dos ejecuciones; sus códigos originales 3
se conservan, al igual que los intentos fallidos anteriores.

| Criterios | Evidencia local, 16:35:49 | Evidencia de PC B, 17:02:01 | Cobertura conjunta |
|---|---|---|---|
| AC1–AC6 | PASS | PASS | PASS |
| AC7–AC10 | PASS | SKIP por modo | PASS |
| AC11 | SKIP por modo | PASS; origen PC B confirmado por el usuario | PASS LAN |
| AC12 | PASS | SKIP por modo | PASS |

La ejecución LAN acredita `true` → SUCCEEDED/0 (166), `false` → FAILED/1 (167),
y `sleep 120` → RUNNING → CANCELED/-15 (168). Los filtros incluyen el ID 168,
el duplicado reutiliza ese ID y los conflictos/estados terminales se rechazan
con `JOB_OPERATION_FAILED` y `NOT_CANCELABLE`, respectivamente. El listado de
`sleep` incluye historial previo; el caso comprueba la presencia del trabajo
propio y no exige que sea la única coincidencia.

Las bases Git registradas son `31cbaf2` (local, cambios locales) y `b4467ed`
(PC B, cambios locales). La comparación `git diff 31cbaf2 b4467ed -- src/hermes`
no presenta diferencias en producción. Los registros con árbol modificado no
aportan un hash del binario ni una copia de los cambios locales de B; no se
afirma identidad binaria verificable. La procedencia remota se sustenta en la
salida aportada y en la confirmación del usuario, sin acceso directo a PC B.

El cierre cubre la alternativa **LAN privada**. No se ejecutó una variante
VPN ni se auditaron desde el script las reglas de Windows o la IP efectiva
observada por el proxy; la topología de preparación fue comunicada por el
usuario. No se modificó producción ni se repitieron los trabajos de B para
realizar esta revisión documental.
