# RNF-08: Una solicitud inválida no termina el servicio

El servidor procesa mensajes JSON terminados en salto de línea (`\n`) sobre una
conexión TCP. TCP puede fragmentar un mensaje; el servidor acumula sus bytes
hasta recibir el delimitador. Una misma conexión puede transportar varias
solicitudes secuenciales: cada mensaje completo se atiende en orden FIFO y la
conexión permanece abierta mientras el flujo esté sincronizado. Un rechazo de
protocolo responde con su código y cierra la conexión; una conexión inactiva más
de tres segundos se cierra con `REQUEST_TIMEOUT`.

## Solicitud de diagnóstico

```json
{"version":1,"request_id":"prueba-1","operation":"ping","params":{}}
```

Respuesta:

```json
{"version":1,"request_id":"prueba-1","ok":true,"result":{"message":"pong"}}
```

`version` debe ser el entero 1. `request_id` debe contener de 1 a 128 caracteres
ASCII entre letras, dígitos, punto, dos puntos, guion y guion bajo, usando el
mismo validador que `hermes job --request-id`. `operation` debe ser una cadena
y `params` un objeto. Para `ping`, `params` debe estar vacío.

El identificador se devuelve cuando es válido; si falta o es inválido, la
respuesta usa `request_id: null`. La validación se hace antes de convertir
valores numéricos, incluidos enteros JSON mayores que un entero de C++.

## Errores

| Situación | Código |
| --- | --- |
| JSON inválido, codificación inválida o profundidad superior a 32 | `INVALID_JSON` |
| El JSON no es un objeto | `INVALID_REQUEST` |
| Identificador ausente o inválido | `INVALID_REQUEST_ID` |
| Versión ausente o de tipo incorrecto | `INVALID_VERSION` |
| Versión entera diferente de 1 | `UNSUPPORTED_VERSION` |
| Operación ausente o de tipo incorrecto | `INVALID_OPERATION` |
| Operación desconocida | `UNKNOWN_OPERATION` |
| Parámetros ausentes, de tipo incorrecto o no admitidos por ping | `INVALID_PARAMS` |
| Operación de trabajos sin autorización (`submit`, `query`, `list`, `cancel`) | `UNAUTHORIZED` |
| Mensaje mayor de 16 384 bytes, sin contar el delimitador | `MESSAGE_TOO_LARGE` |
| Fin del flujo de entrada antes del delimitador | `INCOMPLETE_MESSAGE` |
| No se completa el mensaje en tres segundos de inactividad (el plazo se reanuda con cada fragmento) | `REQUEST_TIMEOUT` |

Ejemplo:

```json
{"version":1,"request_id":null,"ok":false,"error":"INVALID_JSON"}
```

## Aislamiento de clientes

Los sockets son no bloqueantes y se atienden mediante `poll()`. Se admiten hasta
32 clientes activos, independientemente de la concurrencia del scheduler. Las
conexiones excedentes se cierran. La lectura tiene un plazo de tres segundos de
inactividad: se reanuda con cada fragmento recibido y con cada respuesta
entregada, así que enviar bytes lentamente no lo extiende, pero un mensaje
fragmentado que avanza tampoco se corta a mitad. La respuesta dispone de otros
tres segundos para enviarse; las escrituras parciales se completan mientras
quede plazo. El almacenamiento de entrada está acotado al límite del mensaje
más un bloque de lectura de 4096 bytes, y el límite se evalúa por mensaje, no
por el total acumulado en la conexión.

Un fin de flujo con el delimitador ya consumido y ninguna respuesta pendiente es
un cierre normal y no produce sobre de error. Si quedaron bytes sin delimitador,
el servidor responde `INCOMPLETE_MESSAGE` antes de cerrar.

Un error de lectura, escritura o desconexión cierra únicamente el cliente
correspondiente. `MSG_NOSIGNAL` evita terminar el proceso por escribir sobre una
conexión cerrada. El cierre del servicio por Ctrl+C o SIGTERM libera todos los
sockets. La entrega del error depende de que el cliente mantenga abierta su
recepción y de que la conexión permita completar la escritura.

El filtro de RF-20 se aplica antes del protocolo: los orígenes no autorizados
se cierran sin respuesta. Sin activar RF-18, las operaciones de trabajos
permanecen rechazadas. [RF-18](RF-18.operaciones-remotas.md) incorpora TCP sin certificados,
autorización por IP de origen y deduplicación para los trabajos admitidos. La recuperación de
sesiones de control sigue pendiente. `request_id` correlaciona las respuestas.

## Prueba manual desde otro equipo

Con la interfaz LAN y el origen autorizados en config.json, iniciar el servidor:

```sh
./hermes red start
```

Desde otro equipo, reemplazar la IP del ejemplo por la del servidor:

```sh
printf '%s\n' '{"version":1,"request_id":"prueba-1","operation":"ping","params":{}}' | nc 192.168.1.20 45820
printf '%s\n' 'JSON incorrecto' | nc 192.168.1.20 45820
```

La primera solicitud devuelve `pong` y la segunda `INVALID_JSON`. Repetir la
primera para confirmar que el servicio continúa disponible.

## Verificación automatizada

```sh
make -C src/hermes hermes
bash verif/scripts/TC-030.sh   # RF-22: conexión, fragmentos y desconexión
bash verif/scripts/TC-049.sh   # RNF-24: mensaje fragmentado más de 3 s
bash verif/scripts/TC-052.sh   # RNF-24: cierre ordenado frente a mensaje truncado
```

Los scripts usan `HOME` y configuración temporales. La batería de red
(`TC-030`…`TC-056`) cubre las validaciones de mensajes, límites de tamaño y
profundidad, recepción fragmentada, varias solicitudes por conexión, cliente
lento concurrente, fin de entrada, desconexiones abruptas, recuperación
posterior, cierre con SIGTERM y rechazo de origen por RF-20.
