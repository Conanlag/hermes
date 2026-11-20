
## Ejecucion: 2026-11-19 20:38:29 -0600

```text
Arrancando 'hermes red start' con HOME temporal...
Job base en estado terminal: 1
PASS V1: jobs.json idéntico; la operación rechazada no alteró el estado.
FAIL: el rechazo interrumpido no quedó documentado
```

## Ejecucion: 2026-11-19 20:41:16 -0600

```text
Arrancando 'hermes red start' con HOME temporal...
Job base en estado terminal: 1
PASS V1: jobs.json idéntico; la operación rechazada no alteró el estado.
  bitácora: {"context": {"bytes_recibidos": 94, "error": "NOT_CANCELABLE", "identidad": "tcp-PC-B", "ip": "127.0.0.1", "job_id": 1, "motivo": "ERROR_SOCKET", "operacion": "cancel", "request_id": "tc036-rechazo", "resultado": "RECHAZADA"}, "job_id": null, "level": "WARN", "message": "Solicitud interrumpida", "ts": "2026-11-19 20:41:16"}
PASS V2/AC2: rechazo documentado como RECHAZADA con NOT_CANCELABLE y job_id.
PASS V3/AC3: ping posterior correcto y Job base intacto.
PASS: RF-28 TC-036 sin fallos.
```

## Ejecucion: 2026-11-19 20:43:49 -0600

```text
Arrancando 'hermes red start' con HOME temporal...
Job base en estado terminal: 1
PASS V1: jobs.json idéntico; la operación rechazada no alteró el estado.
  bitácora: {"context": {"bytes_recibidos": 94, "error": "NOT_CANCELABLE", "identidad": "tcp-PC-B", "ip": "127.0.0.1", "job_id": 1, "motivo": "ERROR_SOCKET", "operacion": "cancel", "request_id": "tc036-rechazo", "resultado": "RECHAZADA"}, "job_id": null, "level": "WARN", "message": "Solicitud interrumpida", "ts": "2026-11-19 20:43:50"}
PASS V2/AC2: rechazo documentado como RECHAZADA con NOT_CANCELABLE y job_id.
PASS V3/AC3: ping posterior correcto y Job base intacto.
PASS: RF-28 TC-036 sin fallos.
```
