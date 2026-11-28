
## Ejecucion: 2026-11-27 19:04:39 -0600

- Modo: local
- Cliente: PC-B
- Commit: 81fa439
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol: con cambios locales

```text
Auxiliar de configuracion compilado con -Wall -Wextra: sin advertencias
Escenario: inicializacion
PASS V1/AC1: inicializacion idempotente, valores predeterminados y bloqueo
Escenario: xdg-relativo
Escenario: migracion
PASS V2/AC2: prioridad XDG absoluto, fallback relativo, migracion y prioridad del archivo nuevo
Escenario: datos-personalizados
PASS V3/AC3: datos personalizados sin mover historial; configuracion y red en sus rutas propias
Escenario: validacion
  puerto=-1; efectivo=45820; API=validada
  puerto=0; efectivo=45820; API=validada
  puerto=1; efectivo=45820; API=validada
  puerto=80; efectivo=45820; API=validada
  puerto=1023; efectivo=45820; API=validada
  puerto=1024; efectivo=1024; API=validada
  puerto=45820; efectivo=45820; API=validada
  puerto=65535; efectivo=65535; API=validada
  puerto=65536; efectivo=45820; API=validada
  puerto=2147483647; efectivo=45820; API=validada
  puerto=18446744073709551615; efectivo=45820; API=tipo fuera de API int
  puerto='1024'; efectivo=45820; API=tipo fuera de API int
  puerto=None; efectivo=45820; API=tipo fuera de API int
  puerto=1.5; efectivo=45820; API=tipo fuera de API int
FAIL: AssertionError: Limites de concurrencia/cola incorrectos
Resultado: 1

Codigo de salida TC-013: 1
```

## Ejecucion: 2026-11-27 19:05:41 -0600

- Modo: local
- Cliente: PC-B
- Commit: 81fa439
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol: con cambios locales

```text
Auxiliar de configuracion compilado con -Wall -Wextra: sin advertencias
Escenario: inicializacion
PASS V1/AC1: inicializacion idempotente, valores predeterminados y bloqueo
Escenario: xdg-relativo
Escenario: migracion
PASS V2/AC2: prioridad XDG absoluto, fallback relativo, migracion y prioridad del archivo nuevo
Escenario: datos-personalizados
PASS V3/AC3: datos personalizados sin mover historial; configuracion y red en sus rutas propias
Escenario: validacion
  puerto=-1; efectivo=45820; API=validada
  puerto=0; efectivo=45820; API=validada
  puerto=1; efectivo=45820; API=validada
  puerto=80; efectivo=45820; API=validada
  puerto=1023; efectivo=45820; API=validada
  puerto=1024; efectivo=1024; API=validada
  puerto=45820; efectivo=45820; API=validada
  puerto=65535; efectivo=65535; API=validada
  puerto=65536; efectivo=45820; API=validada
  puerto=2147483647; efectivo=45820; API=validada
  puerto=18446744073709551615; efectivo=45820; API=tipo fuera de API int
  puerto='1024'; efectivo=45820; API=tipo fuera de API int
  puerto=None; efectivo=45820; API=tipo fuera de API int
  puerto=1.5; efectivo=45820; API=tipo fuera de API int
FAIL V4/AC4: AC4: entrada {'trabajos_maximos': 18446744073709551615, 'max_cola': 18446744073709551615}; esperado (64, 256); observado (1, 0)
Escenario: salud-inactiva
PASS V5/AC5: salud texto/JSON, registros obsoletos e inactividad sin iniciar scheduler
ENTORNO: [Errno 1] Operation not permitted
DEFECTO: AC4: entrada {'trabajos_maximos': 18446744073709551615, 'max_cola': 18446744073709551615}; esperado (64, 256); observado (1, 0)
Resultado: 2

Codigo de salida TC-013: 2
```

## Ejecucion: 2026-11-27 19:05:58 -0600

- Modo: local
- Cliente: PC-B
- Commit: 81fa439
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol: con cambios locales

```text
Auxiliar de configuracion compilado con -Wall -Wextra: sin advertencias
Escenario: inicializacion
PASS V1/AC1: inicializacion idempotente, valores predeterminados y bloqueo
Escenario: xdg-relativo
Escenario: migracion
PASS V2/AC2: prioridad XDG absoluto, fallback relativo, migracion y prioridad del archivo nuevo
Escenario: datos-personalizados
PASS V3/AC3: datos personalizados sin mover historial; configuracion y red en sus rutas propias
Escenario: validacion
  puerto=-1; efectivo=45820; API=validada
  puerto=0; efectivo=45820; API=validada
  puerto=1; efectivo=45820; API=validada
  puerto=80; efectivo=45820; API=validada
  puerto=1023; efectivo=45820; API=validada
  puerto=1024; efectivo=1024; API=validada
  puerto=45820; efectivo=45820; API=validada
  puerto=65535; efectivo=65535; API=validada
  puerto=65536; efectivo=45820; API=validada
  puerto=2147483647; efectivo=45820; API=validada
  puerto=18446744073709551615; efectivo=45820; API=tipo fuera de API int
  puerto='1024'; efectivo=45820; API=tipo fuera de API int
  puerto=None; efectivo=45820; API=tipo fuera de API int
  puerto=1.5; efectivo=45820; API=tipo fuera de API int
FAIL V4/AC4: AC4: entrada {'trabajos_maximos': 18446744073709551615, 'max_cola': 18446744073709551615}; esperado (64, 256); observado (1, 0)
Escenario: salud-inactiva
PASS V5/AC5: salud texto/JSON, registros obsoletos e inactividad sin iniciar scheduler
Escenario: servicios-reales
  Destino: 127.0.0.1:46951; config={"interfaz": "127.0.0.1", "puerto": 46951, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.0/8"]}
PASS V6/AC6: scheduler activo y conteos reales 1 RUNNING + 1 QUEUED, trabajos local y remoto
Escenario: puerto-ajeno
PASS V7/AC7: health coincide con escucha ss y pong; puerto de otro programa no activa Hermes Red
  Destino: 127.0.0.1:36771; config={"interfaz": "127.0.0.1", "puerto": 36771, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.0/8"]}
PASS V8/AC8: escucha actual y proxima configuracion separadas; interfaz/puerto aplicados tras reinicio
PASS V9/AC9: segundo servidor rechazado; SIGTERM libera puerto; SIGKILL no hereda actividad TCP al scheduler
Escenario: errores-historicos
PASS V10/AC10: ultimos 10 ERROR sin ventana temporal, orden inverso, campos seguros y controles escapados; FAILED no es ERROR
Escenario: fuentes-incompletas
PASS V11/AC11: RUNNING obsoleto sin mutacion; respaldo, corrupcion, JSONL parcial/invalido y fuentes inaccesibles
PASS V12/AC12: argumentos invalidos rechazados; servidores recogidos, schedulers detenidos, sin escuchas ni huerfanos
DEFECTO: AC4: entrada {'trabajos_maximos': 18446744073709551615, 'max_cola': 18446744073709551615}; esperado (64, 256); observado (1, 0)
Resultado: 1

Codigo de salida TC-013: 1
```

## Ejecucion: 2026-11-27 19:07:10 -0600

- Modo: local
- Cliente: PC-B
- Commit: 81fa439
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol: con cambios locales

```text
Auxiliar de configuracion compilado con -Wall -Wextra: sin advertencias
Escenario: inicializacion
PASS V1/AC1: inicializacion idempotente, valores predeterminados y bloqueo
Escenario: xdg-relativo
Escenario: migracion
PASS V2/AC2: prioridad XDG absoluto, fallback relativo, migracion y prioridad del archivo nuevo
Escenario: datos-personalizados
PASS V3/AC3: datos personalizados sin mover historial; configuracion y red en sus rutas propias
Escenario: validacion
  puerto=-1; efectivo=45820; API=validada
  puerto=0; efectivo=45820; API=validada
  puerto=1; efectivo=45820; API=validada
  puerto=80; efectivo=45820; API=validada
  puerto=1023; efectivo=45820; API=validada
  puerto=1024; efectivo=1024; API=validada
  puerto=45820; efectivo=45820; API=validada
  puerto=65535; efectivo=65535; API=validada
  puerto=65536; efectivo=45820; API=validada
  puerto=2147483647; efectivo=45820; API=validada
  puerto=18446744073709551615; efectivo=45820; API=tipo fuera de API int
  puerto='1024'; efectivo=45820; API=tipo fuera de API int
  puerto=None; efectivo=45820; API=tipo fuera de API int
  puerto=1.5; efectivo=45820; API=tipo fuera de API int
FAIL V4/AC4: AC4: entrada {'trabajos_maximos': 18446744073709551615, 'max_cola': 18446744073709551615}; esperado (64, 256); observado (1, 0)
Escenario: salud-inactiva
PASS V5/AC5: salud texto/JSON, registros obsoletos e inactividad sin iniciar scheduler
Escenario: servicios-reales
  Destino: 127.0.0.1:45866; config={"interfaz": "127.0.0.1", "puerto": 45866, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.0/8"]}
PASS V6/AC6: scheduler activo y conteos reales 1 RUNNING + 1 QUEUED, trabajos local y remoto
Escenario: puerto-ajeno
PASS V7/AC7: health coincide con escucha ss y pong; puerto de otro programa no activa Hermes Red
  Destino: 127.0.0.1:48505; config={"interfaz": "127.0.0.1", "puerto": 48505, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.0/8"]}
PASS V8/AC8: escucha actual y proxima configuracion separadas; interfaz/puerto aplicados tras reinicio
PASS V9/AC9: segundo servidor rechazado; SIGTERM libera puerto; SIGKILL no hereda actividad TCP al scheduler
Escenario: errores-historicos
PASS V10/AC10: ultimos 10 ERROR sin ventana temporal, orden inverso, campos seguros y controles escapados; FAILED no es ERROR
Escenario: fuentes-incompletas
PASS V11/AC11: RUNNING obsoleto sin mutacion; respaldo, corrupcion, JSONL parcial/invalido y fuentes inaccesibles
PASS V12/AC12: argumentos invalidos rechazados; servidores recogidos, schedulers detenidos, sin escuchas ni huerfanos
DEFECTO: AC4: entrada {'trabajos_maximos': 18446744073709551615, 'max_cola': 18446744073709551615}; esperado (64, 256); observado (1, 0)
Resultado: 1

Codigo de salida TC-013: 1
```

## Ejecucion: 2026-11-27 19:49:21 -0600

- Modo: local
- Cliente: PC-B
- Commit: 81fa439
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol: con cambios locales

```text
Auxiliar de configuracion compilado con -Wall -Wextra: sin advertencias
Escenario: inicializacion
PASS V1/AC1: inicializacion idempotente, valores predeterminados y bloqueo
Escenario: xdg-relativo
Escenario: migracion
PASS V2/AC2: prioridad XDG absoluto, fallback relativo, migracion y prioridad del archivo nuevo
Escenario: datos-personalizados
PASS V3/AC3: datos personalizados sin mover historial; configuracion y red en sus rutas propias
Escenario: validacion
  puerto=-1; efectivo=45820; API=validada
  puerto=0; efectivo=45820; API=validada
  puerto=1; efectivo=45820; API=validada
  puerto=80; efectivo=45820; API=validada
  puerto=1023; efectivo=45820; API=validada
  puerto=1024; efectivo=1024; API=validada
  puerto=45820; efectivo=45820; API=validada
  puerto=65535; efectivo=65535; API=validada
  puerto=65536; efectivo=45820; API=validada
  puerto=2147483647; efectivo=45820; API=validada
  puerto=18446744073709551615; efectivo=45820; API=tipo fuera de API int
  puerto='1024'; efectivo=45820; API=tipo fuera de API int
  puerto=None; efectivo=45820; API=tipo fuera de API int
  puerto=1.5; efectivo=45820; API=tipo fuera de API int
FAIL V4/AC4: AC4: entrada {'trabajos_maximos': 18446744073709551615, 'max_cola': 18446744073709551615}; esperado (64, 256); observado (1, 0)
Escenario: salud-inactiva
PASS V5/AC5: salud texto/JSON, registros obsoletos e inactividad sin iniciar scheduler
Escenario: servicios-reales
  Destino: 127.0.0.1:50775; config={"interfaz": "127.0.0.1", "puerto": 50775, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.0/8"]}
PASS V6/AC6: scheduler activo y conteos reales 1 RUNNING + 1 QUEUED, trabajos local y remoto
Escenario: puerto-ajeno
PASS V7/AC7: health coincide con escucha ss y pong; puerto de otro programa no activa Hermes Red
  Destino: 127.0.0.1:40597; config={"interfaz": "127.0.0.1", "puerto": 40597, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.0/8"]}
PASS V8/AC8: escucha actual y proxima configuracion separadas; interfaz/puerto aplicados tras reinicio
PASS V9/AC9: segundo servidor rechazado; SIGTERM libera puerto; SIGKILL no hereda actividad TCP al scheduler
Escenario: errores-historicos
PASS V10/AC10: ultimos 10 ERROR sin ventana temporal, orden inverso, campos seguros y controles escapados; FAILED no es ERROR
Escenario: fuentes-incompletas
PASS V11/AC11: RUNNING obsoleto sin mutacion; respaldo, corrupcion, JSONL parcial/invalido y fuentes inaccesibles
PASS V12/AC12: argumentos invalidos rechazados; servidores recogidos, schedulers detenidos, sin escuchas ni huerfanos
DEFECTO: AC4: entrada {'trabajos_maximos': 18446744073709551615, 'max_cola': 18446744073709551615}; esperado (64, 256); observado (1, 0)
Resultado: 1

Codigo de salida TC-013: 1
```

## Ejecucion: 2026-11-27 19:55:34 -0600

- Modo: local
- Cliente: PC-B
- Commit: 81fa439
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol: con cambios locales

```text
Auxiliar de configuracion compilado con -Wall -Wextra: sin advertencias
Escenario: inicializacion
PASS V1/AC1: inicializacion idempotente, valores predeterminados y bloqueo
Escenario: xdg-relativo
Escenario: migracion
PASS V2/AC2: prioridad XDG absoluto, fallback relativo, migracion y prioridad del archivo nuevo
Escenario: datos-personalizados
PASS V3/AC3: datos personalizados sin mover historial; configuracion y red en sus rutas propias
Escenario: validacion
  puerto=-1; efectivo=45820; API=validada
  puerto=0; efectivo=45820; API=validada
  puerto=1; efectivo=45820; API=validada
  puerto=80; efectivo=45820; API=validada
  puerto=1023; efectivo=45820; API=validada
  puerto=1024; efectivo=1024; API=validada
  puerto=45820; efectivo=45820; API=validada
  puerto=65535; efectivo=65535; API=validada
  puerto=65536; efectivo=45820; API=validada
  puerto=2147483647; efectivo=45820; API=validada
  puerto=18446744073709551615; efectivo=45820; API=tipo fuera de API int
  puerto='1024'; efectivo=45820; API=tipo fuera de API int
  puerto=None; efectivo=45820; API=tipo fuera de API int
  puerto=1.5; efectivo=45820; API=tipo fuera de API int
FAIL V4/AC4: AC4: entrada {'trabajos_maximos': 18446744073709551615, 'max_cola': 18446744073709551615}; esperado (64, 256); observado (1, 0)
Escenario: salud-inactiva
PASS V5/AC5: salud texto/JSON, registros obsoletos e inactividad sin iniciar scheduler
Escenario: servicios-reales
  Destino: 127.0.0.1:43665; config={"interfaz": "127.0.0.1", "puerto": 43665, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.0/8"]}
PASS V6/AC6: scheduler activo y conteos reales 1 RUNNING + 1 QUEUED, trabajos local y remoto
Escenario: puerto-ajeno
PASS V7/AC7: health coincide con escucha ss y pong; puerto de otro programa no activa Hermes Red
  Destino: 127.0.0.1:32779; config={"interfaz": "127.0.0.1", "puerto": 32779, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.0/8"]}
PASS V8/AC8: escucha actual y proxima configuracion separadas; interfaz/puerto aplicados tras reinicio
PASS V9/AC9: segundo servidor rechazado; SIGTERM libera puerto; SIGKILL no hereda actividad TCP al scheduler
Escenario: errores-historicos
PASS V10/AC10: ultimos 10 ERROR sin ventana temporal, orden inverso, campos seguros y controles escapados; FAILED no es ERROR
Escenario: fuentes-incompletas
PASS V11/AC11: RUNNING obsoleto sin mutacion; respaldo, corrupcion, JSONL parcial/invalido y fuentes inaccesibles
PASS V12/AC12: argumentos invalidos rechazados; servidores recogidos, schedulers detenidos, sin escuchas ni huerfanos
DEFECTO: AC4: entrada {'trabajos_maximos': 18446744073709551615, 'max_cola': 18446744073709551615}; esperado (64, 256); observado (1, 0)
Resultado: 1

Codigo de salida TC-013: 1
```

## Ejecucion: 2026-11-27 19:56:45 -0600

- Modo: local
- Cliente: PC-B
- Commit: 81fa439
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol: con cambios locales

```text
Auxiliar de configuracion compilado con -Wall -Wextra: sin advertencias
Escenario: inicializacion
PASS V1/AC1: inicializacion idempotente, valores predeterminados y bloqueo
Escenario: xdg-relativo
Escenario: migracion
PASS V2/AC2: prioridad XDG absoluto, fallback relativo, migracion y prioridad del archivo nuevo
Escenario: datos-personalizados
PASS V3/AC3: datos personalizados sin mover historial; configuracion y red en sus rutas propias
Escenario: validacion
  puerto=-1; efectivo=45820; API=validada
  puerto=0; efectivo=45820; API=validada
  puerto=1; efectivo=45820; API=validada
  puerto=80; efectivo=45820; API=validada
  puerto=1023; efectivo=45820; API=validada
  puerto=1024; efectivo=1024; API=validada
  puerto=45820; efectivo=45820; API=validada
  puerto=65535; efectivo=65535; API=validada
  puerto=65536; efectivo=45820; API=validada
  puerto=2147483647; efectivo=45820; API=validada
  puerto=18446744073709551615; efectivo=45820; API=tipo fuera de API int
  puerto='1024'; efectivo=45820; API=tipo fuera de API int
  puerto=None; efectivo=45820; API=tipo fuera de API int
  puerto=1.5; efectivo=45820; API=tipo fuera de API int
  capacidad={'trabajos_maximos': -1, 'max_cola': -1}; esperado=(1, 0); observado=(1, 0)
  capacidad={'trabajos_maximos': 1, 'max_cola': 0}; esperado=(1, 0); observado=(1, 0)
  capacidad={'trabajos_maximos': 64, 'max_cola': 256}; esperado=(64, 256); observado=(64, 256)
  capacidad={'trabajos_maximos': 65, 'max_cola': 257}; esperado=(64, 256); observado=(64, 256)
  capacidad={'trabajos_maximos': 'x', 'max_cola': None}; esperado=(5, 0); observado=(5, 0)
PASS V4/AC4: limites, tipos, enteros grandes, JSON corrupto, API estricta sin escritura parcial y configmax
Escenario: salud-inactiva
PASS V5/AC5: salud texto/JSON, registros obsoletos e inactividad sin iniciar scheduler
Escenario: servicios-reales
  Destino: 127.0.0.1:60141; config={"interfaz": "127.0.0.1", "puerto": 60141, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.0/8"]}
PASS V6/AC6: scheduler activo y conteos reales 1 RUNNING + 1 QUEUED, trabajos local y remoto
Escenario: puerto-ajeno
PASS V7/AC7: health coincide con escucha ss y pong; puerto de otro programa no activa Hermes Red
  Destino: 127.0.0.1:58929; config={"interfaz": "127.0.0.1", "puerto": 58929, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.0/8"]}
PASS V8/AC8: escucha actual y proxima configuracion separadas; interfaz/puerto aplicados tras reinicio
PASS V9/AC9: segundo servidor rechazado; SIGTERM libera puerto; SIGKILL no hereda actividad TCP al scheduler
Escenario: errores-historicos
PASS V10/AC10: ultimos 10 ERROR sin ventana temporal, orden inverso, campos seguros y controles escapados; FAILED no es ERROR
Escenario: fuentes-incompletas
PASS V11/AC11: RUNNING obsoleto sin mutacion; respaldo, corrupcion, JSONL parcial/invalido y fuentes inaccesibles
PASS V12/AC12: argumentos invalidos rechazados; servidores recogidos, schedulers detenidos, sin escuchas ni huerfanos
PASS: RF-16 RF-24 TC-013 sin fallos.
Resultado: 0

Codigo de salida TC-013: 0
```

## Ejecucion: 2026-11-27 19:58:14 -0600

- Modo: local
- Cliente: PC-B
- Commit: 81fa439
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol: con cambios locales

```text
Auxiliar de configuracion compilado con -Wall -Wextra: sin advertencias
Escenario: inicializacion
PASS V1/AC1: inicializacion idempotente, valores predeterminados y bloqueo
Escenario: xdg-relativo
Escenario: migracion
PASS V2/AC2: prioridad XDG absoluto, fallback relativo, migracion y prioridad del archivo nuevo
Escenario: datos-personalizados
PASS V3/AC3: datos personalizados sin mover historial; configuracion y red en sus rutas propias
Escenario: validacion
  puerto=-1; efectivo=45820; API=validada
  puerto=0; efectivo=45820; API=validada
  puerto=1; efectivo=45820; API=validada
  puerto=80; efectivo=45820; API=validada
  puerto=1023; efectivo=45820; API=validada
  puerto=1024; efectivo=1024; API=validada
  puerto=45820; efectivo=45820; API=validada
  puerto=65535; efectivo=65535; API=validada
  puerto=65536; efectivo=45820; API=validada
  puerto=2147483647; efectivo=45820; API=validada
  puerto=18446744073709551615; efectivo=45820; API=tipo fuera de API int
  puerto='1024'; efectivo=45820; API=tipo fuera de API int
  puerto=None; efectivo=45820; API=tipo fuera de API int
  puerto=1.5; efectivo=45820; API=tipo fuera de API int
  capacidad={'trabajos_maximos': -1, 'max_cola': -1}; esperado=(1, 0); observado=(1, 0)
  capacidad={'trabajos_maximos': 1, 'max_cola': 0}; esperado=(1, 0); observado=(1, 0)
  capacidad={'trabajos_maximos': 64, 'max_cola': 256}; esperado=(64, 256); observado=(64, 256)
  capacidad={'trabajos_maximos': 65, 'max_cola': 257}; esperado=(64, 256); observado=(64, 256)
  capacidad={'trabajos_maximos': 'x', 'max_cola': None}; esperado=(5, 0); observado=(5, 0)
PASS V4/AC4: limites, tipos, enteros grandes, JSON corrupto, API estricta sin escritura parcial y configmax
Escenario: salud-inactiva
PASS V5/AC5: salud texto/JSON, registros obsoletos e inactividad sin iniciar scheduler
Escenario: servicios-reales
  Destino: 127.0.0.1:50083; config={"interfaz": "127.0.0.1", "puerto": 50083, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.0/8"]}
PASS V6/AC6: scheduler activo y conteos reales 1 RUNNING + 1 QUEUED, trabajos local y remoto
Escenario: puerto-ajeno
PASS V7/AC7: health coincide con escucha ss y pong; puerto de otro programa no activa Hermes Red
  Destino: 127.0.0.1:44419; config={"interfaz": "127.0.0.1", "puerto": 44419, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.0/8"]}
PASS V8/AC8: escucha actual y proxima configuracion separadas; interfaz/puerto aplicados tras reinicio
PASS V9/AC9: segundo servidor rechazado; SIGTERM libera puerto; SIGKILL no hereda actividad TCP al scheduler
Escenario: errores-historicos
PASS V10/AC10: ultimos 10 ERROR sin ventana temporal, orden inverso, campos seguros y controles escapados; FAILED no es ERROR
Escenario: fuentes-incompletas
PASS V11/AC11: RUNNING obsoleto sin mutacion; respaldo, corrupcion, JSONL parcial/invalido y fuentes inaccesibles
PASS V12/AC12: argumentos invalidos rechazados; servidores recogidos, schedulers detenidos, sin escuchas ni huerfanos
PASS: RF-16 RF-24 TC-013 sin fallos.
Resultado: 0

Codigo de salida TC-013: 0
```
