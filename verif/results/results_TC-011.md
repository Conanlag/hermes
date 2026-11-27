
## Ejecucion: 2026-11-27 17:38:48 -0600

- Modo: local
- Commit: 792623f
- Arbol: con cambios locales

```text
ENTORNO: [Errno 1] Operation not permitted
Resultado: 2

Codigo de salida TC-011: 2
```

## Ejecucion: 2026-11-27 17:39:02 -0600

- Modo: local
- Commit: 792623f
- Arbol: con cambios locales

```text
Escenario: predeterminados; destino 127.0.0.1:42765; config={"puerto": 42765, "trabajos_maximos": 1, "max_cola": 1}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.2: {'ok': True, 'request_id': 'tc011-127.0.0.2', 'result': {'message': 'pong'}, 'version': 1}
PASS V1/AC1: interfaz predeterminada loopback y regla 127/8, con puerto aislado
Escenario: ip-exacta; destino 127.0.0.1:54051; config={"puerto": 54051, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.2: cierre sin respuesta y ORIGEN_RECHAZADO
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: ip-exacta; destino 127.0.0.1:51461; config={"puerto": 51461, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1/32"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.2: cierre sin respuesta y ORIGEN_RECHAZADO
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
PASS V2/AC2: IP individual y /32 equivalentes; rechazo no termina el servicio
Escenario: cidr-normalizado; destino 127.0.0.1:48245; config={"puerto": 48245, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.5/30"]}
  origen 127.0.0.5: {'ok': True, 'request_id': 'tc011-127.0.0.5', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.1: cierre sin respuesta y ORIGEN_RECHAZADO
  origen 127.0.0.5: {'ok': True, 'request_id': 'tc011-127.0.0.5', 'result': {'message': 'pong'}, 'version': 1}
PASS V3/AC3: CIDR normaliza bits de host y aplica pertenencia
Escenario: lista-deniega; destino 127.0.0.1:49525; config={"puerto": 49525, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": []}
  origen 127.0.0.1: cierre sin respuesta y ORIGEN_RECHAZADO
Escenario: lista-deniega; destino 127.0.0.1:47195; config={"puerto": 47195, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["10.0.0.0/8"]}
  origen 127.0.0.1: cierre sin respuesta y ORIGEN_RECHAZADO
PASS V4/AC4: lista vacia deniega todo; lista explicita reemplaza el valor local
Escenario: espacio-valido; destino 127.0.0.1:38577; config={"puerto": 38577, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "10.0.0.0/8"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:48909; config={"puerto": 48909, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "172.16.0.0/12"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:56635; config={"puerto": 56635, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "192.168.0.0/16"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:44219; config={"puerto": 44219, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "100.64.0.0/10"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:42631; config={"puerto": 42631, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "10.2.3.4/24"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:55451; config={"puerto": 55451, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "172.31.255.255/32"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:58537; config={"puerto": 58537, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "192.168.255.255"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:36909; config={"puerto": 36909, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "100.127.255.255/32"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
PASS V5/AC5: 8 reglas privadas/VPN validas aceptadas por el servidor
Escenario: reglas-invalidas; destino 127.0.0.1:36181; config={"puerto": 36181, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "127.0.0.0/33"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:52503; config={"puerto": 52503, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "127.0.0.0/-1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:36221; config={"puerto": 36221, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "localhost"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:42243; config={"puerto": 42243, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "::1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:32815; config={"puerto": 32815, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "127.0.0.1\u0000"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:38825; config={"puerto": 38825, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "0.0.0.0/0"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:46513; config={"puerto": 46513, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "0.1.2.3"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:45843; config={"puerto": 45843, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "203.0.113.1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:38201; config={"puerto": 38201, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "203.0.113.0/24"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:57763; config={"puerto": 57763, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "169.254.1.1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:55025; config={"puerto": 55025, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "224.0.0.1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:35541; config={"puerto": 35541, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "255.255.255.255"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:55197; config={"puerto": 55197, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "10.0.0.0/7"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:53999; config={"puerto": 53999, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "172.16.0.0/11"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:43885; config={"puerto": 43885, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "100.63.255.255"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:33631; config={"puerto": 33631, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "100.128.0.1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:51791; config={"puerto": 51791, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", 42]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:53495; config={"puerto": 53495, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": null}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:50763; config={"puerto": 50763, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": "127.0.0.1"}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:32883; config={"puerto": 32883, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": {"red": "127/8"}}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
PASS V6/AC6: 20 listas invalidas abortan antes de escuchar, sin aceptar parcialmente
Escenario: fallback-seguro; destino 127.0.0.1:51029; config={"puerto": 51029, "trabajos_maximos": 1, "max_cola": 1, "interfaz": "0.0.0.0"}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: fallback-seguro; destino 127.0.0.1:41061; config={"puerto": 41061, "trabajos_maximos": 1, "max_cola": 1, "interfaz": "203.0.113.1"}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: fallback-seguro; destino 127.0.0.1:34169; config={"puerto": 34169, "trabajos_maximos": 1, "max_cola": 1, "interfaz": "::1"}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: fallback-seguro; destino 127.0.0.1:52435; config={"puerto": 52435, "trabajos_maximos": 1, "max_cola": 1, "interfaz": "localhost"}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
PASS V7/AC7: interfaz invalida o comodin vuelve solo a 127.0.0.1
Escenario: reinicio; destino 127.0.0.1:52959; config={"puerto": 52959, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.1: cierre sin respuesta y ORIGEN_RECHAZADO
PASS V8/AC8: las reglas cambian al reiniciar, no a mitad de la ejecucion
Escenario: puerto-ocupado; destino 127.0.0.1:54025; config={"puerto": 54025, "trabajos_maximos": 1, "max_cola": 1}
Escenario: interfaz-no-local; destino 127.0.0.1:39853; config={"puerto": 39853, "trabajos_maximos": 1, "max_cola": 1, "interfaz": "10.254.254.254"}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: No se pudo escuchar en la interfaz y puerto configurados: Cannot assign requested address
PASS V9/AC9: puerto ocupado y direccion privada no local fallan sin fallback de bind
Escenario: red-no-es-permiso; destino 127.0.0.1:47237; config={"puerto": 47237, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.1: {'error': 'UNAUTHORIZED', 'ok': False, 'request_id': 'tc011-127.0.0.1', 'version': 1}
PASS V10/AC10: origen permitido sin registro recibe pong pero no puede crear trabajos
PASS V11/AC11: SIGTERM, wait, eventos de parada, schedulers y puertos liberados; sin huerfanos
PASS: RF-20 RNF-12 RNF-13 TC-011 sin fallos.
Resultado: 0

Codigo de salida TC-011: 0
```

## Ejecucion: 2026-11-27 17:41:25 -0600

- Modo: local
- Commit: 792623f
- Arbol: con cambios locales

```text
Escenario: predeterminados; destino 127.0.0.1:57997; config={"puerto": 57997, "trabajos_maximos": 1, "max_cola": 1}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.2: {'ok': True, 'request_id': 'tc011-127.0.0.2', 'result': {'message': 'pong'}, 'version': 1}
PASS V1/AC1: interfaz predeterminada loopback y regla 127/8, con puerto aislado
Escenario: ip-exacta; destino 127.0.0.1:41503; config={"puerto": 41503, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.2: cierre sin respuesta y ORIGEN_RECHAZADO
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: ip-exacta; destino 127.0.0.1:34191; config={"puerto": 34191, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1/32"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.2: cierre sin respuesta y ORIGEN_RECHAZADO
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
PASS V2/AC2: IP individual y /32 equivalentes; rechazo no termina el servicio
Escenario: cidr-normalizado; destino 127.0.0.1:55943; config={"puerto": 55943, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.5/30"]}
  origen 127.0.0.5: {'ok': True, 'request_id': 'tc011-127.0.0.5', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.1: cierre sin respuesta y ORIGEN_RECHAZADO
  origen 127.0.0.5: {'ok': True, 'request_id': 'tc011-127.0.0.5', 'result': {'message': 'pong'}, 'version': 1}
PASS V3/AC3: CIDR normaliza bits de host y aplica pertenencia
Escenario: lista-deniega; destino 127.0.0.1:46495; config={"puerto": 46495, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": []}
  origen 127.0.0.1: cierre sin respuesta y ORIGEN_RECHAZADO
Escenario: lista-deniega; destino 127.0.0.1:36007; config={"puerto": 36007, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["10.0.0.0/8"]}
  origen 127.0.0.1: cierre sin respuesta y ORIGEN_RECHAZADO
PASS V4/AC4: lista vacia deniega todo; lista explicita reemplaza el valor local
Escenario: espacio-valido; destino 127.0.0.1:56031; config={"puerto": 56031, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "10.0.0.0/8"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:42163; config={"puerto": 42163, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "172.16.0.0/12"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:37923; config={"puerto": 37923, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "192.168.0.0/16"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:35657; config={"puerto": 35657, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "100.64.0.0/10"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:41859; config={"puerto": 41859, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "10.2.3.4/24"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:56579; config={"puerto": 56579, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "172.31.255.255/32"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:47635; config={"puerto": 47635, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "192.168.255.255"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:54055; config={"puerto": 54055, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "100.127.255.255/32"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
PASS V5/AC5: 8 reglas privadas/VPN validas aceptadas por el servidor
Escenario: reglas-invalidas; destino 127.0.0.1:44199; config={"puerto": 44199, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "127.0.0.0/33"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:54453; config={"puerto": 54453, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "127.0.0.0/-1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:59033; config={"puerto": 59033, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "localhost"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:45139; config={"puerto": 45139, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "::1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:39789; config={"puerto": 39789, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "127.0.0.1\u0000"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:33191; config={"puerto": 33191, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "0.0.0.0/0"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:58453; config={"puerto": 58453, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "0.1.2.3"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:55701; config={"puerto": 55701, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "203.0.113.1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:46765; config={"puerto": 46765, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "203.0.113.0/24"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:47025; config={"puerto": 47025, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "169.254.1.1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:60745; config={"puerto": 60745, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "224.0.0.1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:33849; config={"puerto": 33849, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "255.255.255.255"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:54623; config={"puerto": 54623, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "10.0.0.0/7"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:49223; config={"puerto": 49223, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "172.16.0.0/11"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:35113; config={"puerto": 35113, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "100.63.255.255"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:60945; config={"puerto": 60945, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "100.128.0.1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:55621; config={"puerto": 55621, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", 42]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:46603; config={"puerto": 46603, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": null}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:60485; config={"puerto": 60485, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": "127.0.0.1"}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:48825; config={"puerto": 48825, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": {"red": "127/8"}}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
PASS V6/AC6: 20 listas invalidas abortan antes de escuchar, sin aceptar parcialmente
Escenario: fallback-seguro; destino 127.0.0.1:32971; config={"puerto": 32971, "trabajos_maximos": 1, "max_cola": 1, "interfaz": "0.0.0.0"}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: fallback-seguro; destino 127.0.0.1:53527; config={"puerto": 53527, "trabajos_maximos": 1, "max_cola": 1, "interfaz": "203.0.113.1"}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: fallback-seguro; destino 127.0.0.1:33019; config={"puerto": 33019, "trabajos_maximos": 1, "max_cola": 1, "interfaz": "::1"}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: fallback-seguro; destino 127.0.0.1:37951; config={"puerto": 37951, "trabajos_maximos": 1, "max_cola": 1, "interfaz": "localhost"}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
PASS V7/AC7: interfaz invalida o comodin vuelve solo a 127.0.0.1
Escenario: reinicio; destino 127.0.0.1:58597; config={"puerto": 58597, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.1: cierre sin respuesta y ORIGEN_RECHAZADO
PASS V8/AC8: las reglas cambian al reiniciar, no a mitad de la ejecucion
Escenario: puerto-ocupado; destino 127.0.0.1:58149; config={"puerto": 58149, "trabajos_maximos": 1, "max_cola": 1}
Escenario: interfaz-no-local; destino 127.0.0.1:52235; config={"puerto": 52235, "trabajos_maximos": 1, "max_cola": 1, "interfaz": "10.254.254.254"}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: No se pudo escuchar en la interfaz y puerto configurados: Cannot assign requested address
PASS V9/AC9: puerto ocupado y direccion privada no local fallan sin fallback de bind
Escenario: red-no-es-permiso; destino 127.0.0.1:42617; config={"puerto": 42617, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.1: {'error': 'UNAUTHORIZED', 'ok': False, 'request_id': 'tc011-127.0.0.1', 'version': 1}
PASS V10/AC10: origen permitido sin registro recibe pong pero no puede crear trabajos
PASS V11/AC11: SIGTERM, wait, eventos de parada, schedulers y puertos liberados; sin huerfanos
PASS: RF-20 RNF-12 RNF-13 TC-011 sin fallos.
Resultado: 0

Codigo de salida TC-011: 0
```

## Ejecucion: 2026-11-27 17:42:11 -0600

- Modo: local
- Commit: 792623f
- Arbol: con cambios locales

```text
Escenario: predeterminados; destino 127.0.0.1:40313; config={"puerto": 40313, "trabajos_maximos": 1, "max_cola": 1}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.2: {'ok': True, 'request_id': 'tc011-127.0.0.2', 'result': {'message': 'pong'}, 'version': 1}
PASS V1/AC1: interfaz predeterminada loopback y regla 127/8, con puerto aislado
Escenario: ip-exacta; destino 127.0.0.1:60829; config={"puerto": 60829, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.2: cierre sin respuesta y ORIGEN_RECHAZADO
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: ip-exacta; destino 127.0.0.1:34217; config={"puerto": 34217, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1/32"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.2: cierre sin respuesta y ORIGEN_RECHAZADO
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
PASS V2/AC2: IP individual y /32 equivalentes; rechazo no termina el servicio
Escenario: cidr-normalizado; destino 127.0.0.1:55069; config={"puerto": 55069, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.5/30"]}
  origen 127.0.0.5: {'ok': True, 'request_id': 'tc011-127.0.0.5', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.1: cierre sin respuesta y ORIGEN_RECHAZADO
  origen 127.0.0.5: {'ok': True, 'request_id': 'tc011-127.0.0.5', 'result': {'message': 'pong'}, 'version': 1}
PASS V3/AC3: CIDR normaliza bits de host y aplica pertenencia
Escenario: lista-deniega; destino 127.0.0.1:56297; config={"puerto": 56297, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": []}
  origen 127.0.0.1: cierre sin respuesta y ORIGEN_RECHAZADO
Escenario: lista-deniega; destino 127.0.0.1:47283; config={"puerto": 47283, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["10.0.0.0/8"]}
  origen 127.0.0.1: cierre sin respuesta y ORIGEN_RECHAZADO
PASS V4/AC4: lista vacia deniega todo; lista explicita reemplaza el valor local
Escenario: espacio-valido; destino 127.0.0.1:48343; config={"puerto": 48343, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "10.0.0.0/8"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:44715; config={"puerto": 44715, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "172.16.0.0/12"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:45051; config={"puerto": 45051, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "192.168.0.0/16"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:54069; config={"puerto": 54069, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "100.64.0.0/10"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:50481; config={"puerto": 50481, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "10.2.3.4/24"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:41819; config={"puerto": 41819, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "172.31.255.255/32"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:54029; config={"puerto": 54029, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "192.168.255.255"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: espacio-valido; destino 127.0.0.1:44959; config={"puerto": 44959, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "100.127.255.255/32"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
PASS V5/AC5: 8 reglas privadas/VPN validas aceptadas por el servidor
Escenario: reglas-invalidas; destino 127.0.0.1:54343; config={"puerto": 54343, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "127.0.0.0/33"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:48963; config={"puerto": 48963, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "127.0.0.0/-1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:53493; config={"puerto": 53493, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "localhost"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:40307; config={"puerto": 40307, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "::1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:53313; config={"puerto": 53313, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "127.0.0.1\u0000"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:47299; config={"puerto": 47299, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "0.0.0.0/0"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:44087; config={"puerto": 44087, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "0.1.2.3"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:39525; config={"puerto": 39525, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "203.0.113.1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:46533; config={"puerto": 46533, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "203.0.113.0/24"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:47141; config={"puerto": 47141, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "169.254.1.1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:54437; config={"puerto": 54437, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "224.0.0.1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:37831; config={"puerto": 37831, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "255.255.255.255"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:53469; config={"puerto": 53469, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "10.0.0.0/7"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:52687; config={"puerto": 52687, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "172.16.0.0/11"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:52859; config={"puerto": 52859, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "100.63.255.255"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:45867; config={"puerto": 45867, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", "100.128.0.1"]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:49519; config={"puerto": 49519, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1", 42]}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:52113; config={"puerto": 52113, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": null}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:52835; config={"puerto": 52835, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": "127.0.0.1"}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
Escenario: reglas-invalidas; destino 127.0.0.1:42623; config={"puerto": 42623, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": {"red": "127/8"}}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: redes_permitidas inválida; corrija config.json antes de iniciar
PASS V6/AC6: 20 listas invalidas abortan antes de escuchar, sin aceptar parcialmente
Escenario: fallback-seguro; destino 127.0.0.1:49777; config={"puerto": 49777, "trabajos_maximos": 1, "max_cola": 1, "interfaz": "0.0.0.0"}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: fallback-seguro; destino 127.0.0.1:35069; config={"puerto": 35069, "trabajos_maximos": 1, "max_cola": 1, "interfaz": "203.0.113.1"}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: fallback-seguro; destino 127.0.0.1:44779; config={"puerto": 44779, "trabajos_maximos": 1, "max_cola": 1, "interfaz": "::1"}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
Escenario: fallback-seguro; destino 127.0.0.1:47869; config={"puerto": 47869, "trabajos_maximos": 1, "max_cola": 1, "interfaz": "localhost"}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
PASS V7/AC7: interfaz invalida o comodin vuelve solo a 127.0.0.1
Escenario: reinicio; destino 127.0.0.1:48415; config={"puerto": 48415, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.1: cierre sin respuesta y ORIGEN_RECHAZADO
PASS V8/AC8: las reglas cambian al reiniciar, no a mitad de la ejecucion
Escenario: puerto-ocupado; destino 127.0.0.1:57401; config={"puerto": 57401, "trabajos_maximos": 1, "max_cola": 1}
Escenario: interfaz-no-local; destino 127.0.0.1:47317; config={"puerto": 47317, "trabajos_maximos": 1, "max_cola": 1, "interfaz": "10.254.254.254"}
  rechazo arranque: No se pudo iniciar o mantener Hermes Red: No se pudo escuchar en la interfaz y puerto configurados: Cannot assign requested address
PASS V9/AC9: puerto ocupado y direccion privada no local fallan sin fallback de bind
Escenario: red-no-es-permiso; destino 127.0.0.1:42489; config={"puerto": 42489, "trabajos_maximos": 1, "max_cola": 1, "redes_permitidas": ["127.0.0.1"]}
  origen 127.0.0.1: {'ok': True, 'request_id': 'tc011-127.0.0.1', 'result': {'message': 'pong'}, 'version': 1}
  origen 127.0.0.1: {'error': 'UNAUTHORIZED', 'ok': False, 'request_id': 'tc011-127.0.0.1', 'version': 1}
PASS V10/AC10: origen permitido sin registro recibe pong pero no puede crear trabajos
PASS V11/AC11: SIGTERM, wait, eventos de parada, schedulers y puertos liberados; sin huerfanos
PASS: RF-20 RNF-12 RNF-13 TC-011 sin fallos.
Resultado: 0

Codigo de salida TC-011: 0
```
