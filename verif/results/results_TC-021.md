=== Ejecutando TC-021 ===
RF-30: escalamiento forzoso tras una cancelación normal ignorada por SIGTERM
Salida de hermes job:
job ID: 1
PID: 45890
Código de salida de hermes job: 0
ID del trabajo: 1
Salida de hermes cancel:
[34mCancelación solicitada para el Job: 1[0m
Código de salida de hermes cancel: 0
Duración de hermes cancel (segundos): 5
Estado final:
Job ID: 1
PID: 45890
Programa: bash
Estado: CANCELED
Codigo de salida: -9
Recepcion: 2026-10-30 22:16:34
Inicio: 2026-10-30 22:16:34
Terminacion: 2026-10-30 22:16:40
Argumentos: -c trap "" TERM; while :; do sleep 1; done 
Código de salida de la consulta final: 0
El trabajo ignoró SIGTERM y terminó por escalamiento forzoso después del periodo de gracia.
[PASS] TC-021
