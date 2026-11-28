
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

## Ejecucion: 2026-11-27 20:23:28 -0600

- Modo: local
- Cliente: PC-B
- Commit: b70d4b4
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Carga por via (local/TCP): 100
- Arbol: con cambios locales

```text
ENTORNO: [Errno 1] Operation not permitted
Resultado: 2

Codigo de salida TC-024: 2
```

## Ejecucion: 2026-11-27 20:23:45 -0600

- Modo: local
- Cliente: PC-B
- Commit: b70d4b4
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Carga por via (local/TCP): 100
- Arbol: con cambios locales

```text
Destino: 127.0.0.1:43355; servidor PID=9808; scheduler PID=9809; config={"interfaz": "127.0.0.1", "puerto": 43355, "redes_permitidas": ["127.0.0.0/8"], "trabajos_maximos": 10, "max_cola": 10}
FAIL: AssertionError: Recursos no regresaron a reposo: None
Ultimas lineas servidor:
Hermes Red escuchando en 127.0.0.1:43355 (primer plano; Ctrl+C para detener)
Resultado: 1

Codigo de salida TC-024: 1
```

## Ejecucion: 2026-11-27 20:24:59 -0600

- Modo: local
- Cliente: PC-B
- Commit: b70d4b4
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Carga por via (local/TCP): 100
- Arbol: con cambios locales

```text
Destino: 127.0.0.1:46057; servidor PID=9932; scheduler PID=9933; config={"interfaz": "127.0.0.1", "puerto": 46057, "redes_permitidas": ["127.0.0.0/8"], "trabajos_maximos": 10, "max_cola": 10}
Linea base: {"servidor": {"rss": 5248, "fds": 5, "sockets": 1, "children": 0, "service_children": 1}, "scheduler": {"rss": 3968, "fds": 4, "sockets": 0, "children": 0, "service_children": 0}}
PASS V1/AC1: servidor/scheduler reales, calentamiento local/TCP y linea base estable
FAIL: AssertionError: hermes ('red', 'job', '127.0.0.1', 'true'): codigo 1:  [31mNo se pudo crear el Job: Error interno al procesar la solicitud[0m

Ultimas lineas servidor:
Hermes Red escuchando en 127.0.0.1:46057 (primer plano; Ctrl+C para detener)
Resultado: 1

Codigo de salida TC-024: 1
```

## Ejecucion: 2026-11-27 20:25:24 -0600

- Modo: local
- Cliente: PC-B
- Commit: b70d4b4
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Carga por via (local/TCP): 100
- Arbol: con cambios locales

```text
Destino: 127.0.0.1:37429; servidor PID=10198; scheduler PID=10199; config={"interfaz": "127.0.0.1", "puerto": 37429, "redes_permitidas": ["127.0.0.0/8"], "trabajos_maximos": 10, "max_cola": 10}
Linea base: {"servidor": {"rss": 5376, "fds": 5, "sockets": 1, "children": 0, "service_children": 1}, "scheduler": {"rss": 4232, "fds": 4, "sockets": 0, "children": 0, "service_children": 0}}
PASS V1/AC1: servidor/scheduler reales, calentamiento local/TCP y linea base estable
FAIL: AssertionError: hermes ('red', 'job', '127.0.0.1', 'true'): codigo 1:  [31mNo se pudo crear el Job: Error interno al procesar la solicitud[0m

Ultimos ERROR registrados: [{"context": {"detalle": "La cola está llena (20/20 trabajos activos). Intente de nuevo cuando haya espacio."}, "job_id": null, "level": "ERROR", "message": "Error interno al procesar solicitud remota", "ts": "2026-11-27 20:25:28"}, {"context": {"detalle": "La cola está llena (20/20 trabajos activos). Intente de nuevo cuando haya espacio."}, "job_id": null, "level": "ERROR", "message": "Error interno al procesar solicitud remota", "ts": "2026-11-27 20:25:28"}, {"context": {"detalle": "La cola está llena (20/20 trabajos activos). Intente de nuevo cuando haya espacio."}, "job_id": null, "level": "ERROR", "message": "Error interno al procesar solicitud remota", "ts": "2026-11-27 20:25:28"}, {"context": {"detalle": "La cola está llena (20/20 trabajos activos). Intente de nuevo cuando haya espacio."}, "job_id": null, "level": "ERROR", "message": "Error interno al procesar solicitud remota", "ts": "2026-11-27 20:25:28"}, {"context": {"detalle": "La cola está llena (20/20 trabajos activos). Intente de nuevo cuando haya espacio."}, "job_id": null, "level": "ERROR", "message": "Error interno al procesar solicitud remota", "ts": "2026-11-27 20:25:28"}, {"context": {"detalle": "La cola está llena (20/20 trabajos activos). Intente de nuevo cuando haya espacio."}, "job_id": null, "level": "ERROR", "message": "Error interno al procesar solicitud remota", "ts": "2026-11-27 20:25:28"}, {"context": {"detalle": "La cola está llena (20/20 trabajos activos). Intente de nuevo cuando haya espacio."}, "job_id": null, "level": "ERROR", "message": "Error interno al procesar solicitud remota", "ts": "2026-11-27 20:25:28"}]
Ultimas lineas servidor:
Hermes Red escuchando en 127.0.0.1:37429 (primer plano; Ctrl+C para detener)
Resultado: 1

Codigo de salida TC-024: 1
```

## Ejecucion: 2026-11-27 20:25:48 -0600

- Modo: local
- Cliente: PC-B
- Commit: b70d4b4
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Carga por via (local/TCP): 100
- Arbol: con cambios locales

```text
Destino: 127.0.0.1:42461; servidor PID=10439; scheduler PID=10440; config={"interfaz": "127.0.0.1", "puerto": 42461, "redes_permitidas": ["127.0.0.0/8"], "trabajos_maximos": 10, "max_cola": 10}
Linea base: {"servidor": {"rss": 5376, "fds": 5, "sockets": 1, "children": 0, "service_children": 1}, "scheduler": {"rss": 4100, "fds": 4, "sockets": 0, "children": 0, "service_children": 0}}
PASS V1/AC1: servidor/scheduler reales, calentamiento local/TCP y linea base estable
Ronda 1: 50 Jobs locales + 50 TCP; pico servidor={"rss": 5760, "fds": 21, "sockets": 17, "children": 0, "service_children": 1}
Reposo ronda 1: {"servidor": {"rss": 5760, "fds": 5, "sockets": 1, "children": 0, "service_children": 1}, "scheduler": {"rss": 8836, "fds": 4, "sockets": 0, "children": 0, "service_children": 0}}
  servidor: delta RSS=384 KiB; tolerancia=8192 KiB
  scheduler: delta RSS=4736 KiB; tolerancia=8192 KiB
PASS V2/AC2: ronda 1: Jobs completados; sockets/FDs regresan a base; sin hijos ni temporales; RSS dentro de tolerancia
Ronda 2: 50 Jobs locales + 50 TCP; pico servidor={"rss": 6144, "fds": 21, "sockets": 17, "children": 0, "service_children": 1}
Reposo ronda 2: {"servidor": {"rss": 6144, "fds": 5, "sockets": 1, "children": 0, "service_children": 1}, "scheduler": {"rss": 12156, "fds": 4, "sockets": 0, "children": 0, "service_children": 0}}
  servidor: delta RSS=768 KiB; tolerancia=8192 KiB
  scheduler: delta RSS=8056 KiB; tolerancia=8192 KiB
PASS V3/AC3: ronda 2: Jobs completados; sockets/FDs regresan a base; sin hijos ni temporales; RSS dentro de tolerancia
Jobs finales: 202; locales=101; TCP=101; todos SUCCEEDED/0
PASS V4/AC4: persistencia/bitacora integras y servidor sigue respondiendo despues de la carga
PASS V5/AC5: SIGTERM cierra clientes abiertos y escucha, wait recoge servidor y puerto vuelve a enlazarse
PASS V6/AC6: scheduler sin descriptores, ningun proceso propio ni puerto abierto; temporales eliminados al salir
PASS: RNF-33 TC-024 sin fallos.
Resultado: 0

Codigo de salida TC-024: 0
```

## Ejecucion: 2026-11-27 20:30:37 -0600

- Modo: local
- Cliente: PC-B
- Commit: b70d4b4
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Carga por via (local/TCP): 100
- Arbol: con cambios locales

```text
Destino: 127.0.0.1:43885; servidor PID=11218; scheduler PID=11219; config={"interfaz": "127.0.0.1", "puerto": 43885, "redes_permitidas": ["127.0.0.0/8"], "trabajos_maximos": 10, "max_cola": 10}
Linea base: {"servidor": {"rss": 5248, "fds": 5, "sockets": 1, "children": 0, "service_children": 1}, "scheduler": {"rss": 4108, "fds": 4, "sockets": 0, "children": 0, "service_children": 0}}
PASS V1/AC1: servidor/scheduler reales, calentamiento local/TCP y linea base estable
Ronda 1: 50 Jobs locales + 50 TCP; pico servidor={"rss": 5632, "fds": 21, "sockets": 17, "children": 0, "service_children": 1}
Reposo ronda 1: {"servidor": {"rss": 5632, "fds": 5, "sockets": 1, "children": 0, "service_children": 1}, "scheduler": {"rss": 8844, "fds": 4, "sockets": 0, "children": 0, "service_children": 0}}
  servidor: delta RSS=384 KiB; tolerancia=8192 KiB
  scheduler: delta RSS=4736 KiB; tolerancia=8192 KiB
PASS V2/AC2: ronda 1: Jobs completados; sockets/FDs regresan a base; sin hijos ni temporales; RSS dentro de tolerancia
Ronda 2: 50 Jobs locales + 50 TCP; pico servidor={"rss": 6016, "fds": 21, "sockets": 17, "children": 0, "service_children": 1}
Reposo ronda 2: {"servidor": {"rss": 6016, "fds": 5, "sockets": 1, "children": 0, "service_children": 1}, "scheduler": {"rss": 11860, "fds": 4, "sockets": 0, "children": 0, "service_children": 0}}
  servidor: delta RSS=768 KiB; tolerancia=8192 KiB
  scheduler: delta RSS=7752 KiB; tolerancia=8192 KiB
PASS V3/AC3: ronda 2: Jobs completados; sockets/FDs regresan a base; sin hijos ni temporales; RSS dentro de tolerancia
Jobs finales: 202; locales=101; TCP=101; todos SUCCEEDED/0
PASS V4/AC4: persistencia/bitacora integras y servidor sigue respondiendo despues de la carga
PASS V5/AC5: SIGTERM cierra clientes abiertos y escucha, wait recoge servidor y puerto vuelve a enlazarse
PASS V6/AC6: scheduler sin descriptores, ningun proceso propio ni puerto abierto; temporales eliminados al salir
PASS: RNF-33 TC-024 sin fallos.
Resultado: 0

Codigo de salida TC-024: 0
```
