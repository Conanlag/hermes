# Contexto actual del subsistema de red de Hermes

> Documento de referencia técnica (línea base). Describe **lo que el código hace hoy**, no lo que se
> desea que haga. Toda afirmación está respaldada por rutas, estructuras y firmas reales del
> repositorio. Los requisitos se citan con su identificador y las discrepancias se concentran en la
> sección 6.
>
> Estado del arte: la línea base del subsistema es `4efb296` (*feat: implentacion de red*), sobre
> `24fa39f` (RF-20 / RNF-13) y `37060e6` (RNF-12). Este documento se actualizó tras el merge
> `858e3b1` (*Merge branch 'main' into alan*), que integra `703d9c9` (*link simbolico para la red*),
> `816c8a4` (*automatizacion de redes con hermes red setup*) y `66a0180` (*docs: setup*).
>
> Ese merge **no cambió el protocolo de red**: `protocol.cpp`, `client.cpp`, `job.cpp`, `cancel.cpp`,
> `storage.cpp` y `scheduler.cpp` quedaron intactos. Lo que cambió es el comando `red` (nuevo
> subcomando `setup`), el esquema de `network.json` (campos nuevos) y la política de direcciones
> admitidas (solo redes privadas, VPN y loopback).
>
> Alcance de la auditoría: solo lectura sobre `src/` y `verif/`. El único archivo modificado es este
> documento.

---

## 1. Propósito y resumen arquitectónico

### 1.1 Qué es Hermes Red

Hermes Red es la extensión cliente-servidor del JobRunner local. Un proceso Hermes actúa como
**servidor principal** (`hermes red start`) y conserva su scheduler local; otros procesos Hermes
actúan como **clientes** (`hermes red job|filter|cancel <host> ...`) y envían solicitudes por TCP.
El servidor ejecuta los trabajos con **su propio** scheduler y persistencia; el cliente no ejecuta
nada de forma remota.

Desde el merge de `main` existe un tercer punto de entrada: `hermes red setup`
(`setup.cpp`, `main.cpp:57`). Es un **asistente interactivo que se ejecuta en el servidor**, no abre
sockets, no inicia el scheduler y no forma parte del flujo de una petición remota: solo escribe
`config.json` y `network.json` (§4.2). Los clientes siguen siendo `job|filter|cancel` y no necesitan
`setup`.

La decisión de arquitectura está en `docs/desicions/ADR-016-Red-propuesta.md` (cliente-servidor
centralizado, toda operación pasa por PC-A). La entrega efectivamente implementada es la descrita en
`docs/technical-guide/2-Nucleo del proyecto/RF-18.operaciones-remotas.md`: **TCP con mensajes JSON,
sin TLS, sin certificados y con autorización por IP de origen observada**. La parte TLS/UUID/mDNS/
distribución a ejecutores del ADR sigue pendiente y el propio RF-18 lo declara (líneas 12-17).

### 1.2 Topología real

```
  PC-B (cliente)                                   PC-A (servidor)
  ┌──────────────────────────┐                     ┌───────────────────────────────────────┐
  │ hermes red job host ...  │  TCP IPv4 :45820    │ hermes red setup (solo config)        │
  │  - valida localmente     │ ──────────────────► │ hermes red start                      │
  │  - getaddrinfo(AF_INET)  │                     │  - accept4() / poll()                 │
  │  - JSON + '\n'           │                     │  - filtro redes_permitidas            │
  │  - imprime resumen       │ ◄────────────────── │  - identidad por IP observada         │
  │                          │   JSON + '\n'       │  - ámbito de trabajos por registro    │
  └──────────────────────────┘                     │  - procesarSolicitudRed()             │
                                                   │  - ejecutarOperacionRemota()          │
                                                   │  - crearJob() / cancelarJobDetallado()│
                                                   │  - scheduler local + jobs.json        │
                                                   └───────────────────────────────────────┘
```

No existe canal servidor→cliente iniciado por el servidor, ni sesión persistente, ni comunicación
cliente-cliente. Cada operación es **una conexión TCP con un único mensaje**.

En el despliegue real documentado (`docs/user-guide/red-wsl-pc-a-pc-b.md`) el servidor corre dentro
de WSL y Windows actúa de intermediario con `netsh interface portproxy`:

```
PC B (192.168.1.73) ──► Windows A 192.168.1.74:45820 ──portproxy──► WSL A 172.25.70.19:45820
                                     origen observado por Hermes: 172.25.64.1 (gateway de WSL)
```

La consecuencia es estructural: Hermes **no ve la IP LAN del cliente**, sino la del gateway/proxy.
Por eso `redes_permitidas` y `clientes[].direcciones` deben contener `172.25.64.1`, y varios clientes
detrás del mismo proxy son indistinguibles (`red-wsl-pc-a-pc-b.md:23-27`; `RF-18:221-226`).

### 1.3 Flujo completo de una petición remota

Antes de enrutar cualquier comando, `main()` ejecuta `inicializarConfiguracionRemota()`
(`main.cpp:33`), que crea `network.json` si falta (§4.2).

1. `main.cpp:56-59` enruta `red`: `argc == 3 && argv[2] == "setup"` →
   `hermes::configurarRedInteractiva()`; `argc == 3 && argv[2] == "start"` →
   `hermes::iniciarServidorRed()`; en cualquier otro caso → `hermes::ejecutarClienteRed()`.
   `setup` no participa en este flujo.
2. El cliente valida localmente con los mismos validadores del modo local
   (`validarPrograma`, `validarRequestId`, `validarIdTexto`, `validarTipoFiltro`,
   `validarStatusTexto`) en `src/hermes/src/network/client.cpp`.
3. Construye el sobre JSON (`client.cpp:124`), resuelve el host con `getaddrinfo` **solo IPv4**
   (`client.cpp:127-132`), descarta direcciones destino que no pertenezcan a los espacios admitidos
   (`reglaRedValida(ip)`, `client.cpp:139`) y conecta en modo no bloqueante con un plazo global de
   10 s (`client.cpp:135-153`).
4. El servidor acepta (`accept4`, `server.cpp:169-175`), obtiene la IP con `inet_ntop`
   (`server.cpp:176-177`) y aplica el filtro `origenRedPermitido(ip, config.redesPermitidas)`
   (`server.cpp:178`, implementado en `src/hermes/src/network/access.cpp:48-60`).
5. Si el origen está permitido y la red está habilitada, busca el registro en
   `ConfiguracionRemota::identidades` (mapa `IPv4 → id`) y construye la identidad de trabajos con
   `"tcp-" + ambitosTrabajos[id]` (`server.cpp:182-188`). El ámbito (`ambito_trabajos`) puede diferir
   del `id` visible; por defecto es el propio `id` (§4.2).
6. Acumula bytes hasta `'\n'` y delega en `procesarSolicitudRed()`
   (`server.cpp:138-143`, `src/hermes/src/network/protocol.cpp:12-54`).
7. `procesarSolicitudRed()` valida el sobre y, para `submit|query|list|cancel`, exige identidad y
   permisos; luego llama a `ejecutarOperacionRemota()`
   (`src/hermes/src/network/remote.cpp:141-217`).
8. Para `submit`, `crearJob()` persiste el Job en `jobs.json` bajo `jobs.lock` con
   `propietario_remoto` y `tipo_ejecucion: "remote"` (`src/hermes/src/job/job.cpp:102-195`), y
   `esperarInicioJob()` espera hasta 1 s a que el scheduler asigne PID (`job.cpp:306-313`).
9. El scheduler local (`src/hermes/src/scheduler/scheduler.cpp`) toma el Job, lo ejecuta y actualiza
   el estado en `jobs.json`.
10. El servidor responde un objeto JSON con `version`, `request_id`, `ok` y `result`/`error`, y
    **deja la conexión abierta** para la siguiente solicitud (`server.cpp:284-403`). Un rechazo de
    protocolo o tres segundos de inactividad sí la cierran.
11. El cliente valida la respuesta (`client.cpp:177-181`) e imprime con las funciones compartidas de
    presentación (`mostrarAdmisionJob`, `mostrarDetalleJob`, `mostrarResumenJob` en
    `src/hermes/src/job/presentation.cpp`).

### 1.4 Límites explícitos del diseño actual

| Límite | Evidencia |
| --- | --- |
| Sin TLS ni cifrado; el tráfico viaja en claro | `RF-18:12-17`; no hay dependencia OpenSSL en `Makefile` |
| Sin autenticación criptográfica: la identidad es la IP observada | `network_remote.h:13-16`; `server.cpp:182-188` |
| Sin transmisión de `stdout`/`stderr` remotos | `RF-18:145-149`; el Job persistido no guarda salidas (`job.cpp:174-191`) |
| Sin distribución a clientes ejecutores | `RF-18:7-10`; no existe código de reenvío |
| Sin sesiones persistentes ni multiplexación | una invocación = una conexión con N solicitudes secuenciales (`RNF-24`); sin estado entre invocaciones |
| Varias solicitudes por conexión, en orden FIFO; se conservan los bytes tras cada `\n` | `RNF-24`; `server.cpp:284-346` |
| Sin `red status` / `red stop` / daemonización | `RNF-12:9-11` |
| Límite de 16 KiB de entrada y 256 KiB de respuesta | `network_protocol.h:5`; `protocol.cpp:13,50` |
| Solo IPv4 (`AF_INET`) en cliente y servidor | `server.cpp:81`; `client.cpp:127` |
| Máximo 32 clientes TCP concurrentes | `server.cpp:178` |
| Cola de trabajos limitada por `trabajos_maximos + max_cola` | `job.cpp:83-85,167-170` |
| `red setup` es interactivo, solo primer plano y no verifica conectividad real | `setup.cpp:394-441` |
| Toda ejecución de Hermes crea `network.json` si falta, incluso comandos locales | `main.cpp:33`; `remote.cpp:42-84` |
| `servidor`, `equipos` y `clientes[].tipo` no se leen al arrancar; son metadatos del asistente | `remote.cpp:94-139` |

---

## 2. Mapa de archivos y responsabilidades

### 2.1 Módulo de red (`src/hermes/include` + `src/hermes/src/network`)

| Archivo | Responsabilidad | Funciones / tipos clave |
| --- | --- | --- |
| `include/network.h` | Fachada pública del módulo | `int iniciarServidorRed()`; `int configurarRedInteractiva()`; `int ejecutarClienteRed(int argc, char* argv[])` |
| `include/network_access.h` <br> `src/network/access.cpp` | Validación y aplicación de reglas IPv4/CIDR, incluida la excepción /32 unicast | `bool reglaRedValida(const std::string&)`; `bool origenRedPermitido(const std::string&, const std::vector<std::string>&)`; `struct Red { uint32_t base, mascara; }` (anónimo); `leer()`, `contenida()` |
| `include/network_protocol.h` <br> `src/network/protocol.cpp` | Sobre JSON, validación de mensajes y despacho por operación | `constexpr unsigned MAX_MENSAJE_RED = 16384`; `std::string errorProtocolo(const std::string&)`; `std::string procesarSolicitudRed(const std::string&, const std::string& identidad, const PermisosRemotos*)` |
| `include/network_remote.h` <br> `src/network/remote.cpp` | Plantilla, carga y validación de `network.json`, autorización y ejecución de operaciones sobre el dominio local | `struct PermisosRemotos { vector<string> operaciones, programas; }`; `struct ConfiguracionRemota { bool habilitada; map<string,string> identidades; map<string,PermisosRemotos> clientes; map<string,string> ambitosTrabajos; }`; `void inicializarConfiguracionRemota()`; `ConfiguracionRemota cargarConfiguracionRemota()`; `ConfiguracionRemota interpretarConfiguracionRemota(const nlohmann::json&)`; `nlohmann::json ejecutarOperacionRemota(operacion, params, requestId, identidad, permisos)` |
| `src/network/setup.cpp` | Asistente interactivo `red setup`: detección de entorno LAN/WSL, registro de equipos, escritura de `config.json`/`network.json` y generación del script de PowerShell | `int configurarRedInteractiva()`; helpers anónimos `preguntar()`, `confirmar()`, `pedirIP()`, `interfaces()` (`getifaddrs` + `/proc/net/route`), `gateway()`, `usaProxyWindows()` (`wslinfo --networking-mode`), `ejecutar()` (`fork`/`execvp`, sin shell), `guardar()` (mkstemp+fsync+rename), `Lock` (`flock`), `scriptWindows()` |
| `src/network/server.cpp` | Servidor TCP en primer plano: socket, `poll()`, ciclo de vida de clientes, señales | `iniciarServidorRed()`; clases internas `Descriptor` (RAII de `close`), `Senales` (sigaction SIGINT/SIGTERM/SIGPIPE); `struct Cliente` (socket, `esperado`, `identidad`, `permisos`, `entrada`, `salida`, `enviado`, `limite`, `cerrado`); `responder()` |
| `src/network/client.cpp` | CLI remoto: parseo, validaciones, conexión, transporte y presentación | `ejecutarClienteRed()`; helpers anónimos `Socket`, `IgnorarPipe`, `esperar()`, `numero()`, `requestId()` (16 bytes de `getrandom` → hex) |

### 2.2 Integración con el núcleo

| Archivo | Relación con red |
| --- | --- |
| `src/main.cpp` | `inicializarConfiguracionRemota()` al arrancar (`33`); enrutamiento `red setup` / `red start` / cliente (`56-59`); arranque del scheduler **antes** de atender comandos locales (`194`); `--help` no documenta `red` en detalle (eso vive en `help.cpp`) |
| `include/config.h`, `src/config/config.cpp` | `ConfiguracionSistema` aporta `interfaz`, `puerto`, `redesPermitidas`, `reglasRedValidas`; `CambiosConfiguracion` añade `agregarRedesPermitidas` (`config.h:54`); `interfazValida()`, `cargarConfiguracion()` |
| `src/config/config_update.cpp` | Actualización atómica de `interfaz`, `puerto`, `redes_permitidas` y **adición** de reglas con `agregarRedesPermitidas` mediante `CambiosConfiguracion` (validación en `249-262`; escritura y fusión en `298-313`) |
| `include/validator.h`, `src/validator/validator.cpp` | `validarRequestId()` (`117-161`), `validarPrograma()` (`92-115`), `validarIdTexto()` (`212`), `validarTipoFiltro()` (`164-209`), `validarStatusTexto()` (`338-388`) — compartidos por CLI local y remoto |
| `include/job.h`, `src/job/job.cpp` | `crearJob(programa, argumentos, requestId, trabajosMaximos, maxCola, propietarioRemoto)`; deduplicación por `request_id`; `esperarInicioJob()` |
| `include/cancel.h`, `src/cancel/cancel.cpp` | `cancelarJobDetallado(jobId, propietarioRemoto)`; `enum class CodigoCancelacion` |
| `include/storage.h`, `src/storage/storage.cpp` | `leerJobsSeguros()` / `modificarJobsSeguros()`: `flock`, `mutex` intra-proceso y escritura atómica (`tmp + fsync + rename + fsync(dir)`) |
| `include/scheduler.h`, `src/scheduler/scheduler.cpp` | `iniciarSchedulerSiNecesario()` (`1287`); supervisión de procesos; `atenderCancelacionesRemotas()` (`825-850`) |
| `include/event_log.h`, `src/events/event_log.cpp` | Bitácora JSONL; `log_event(job_id, level, message, extra)` y `log_event_system(...)` |
| `include/job_presentation.h`, `src/job/presentation.cpp` | `jsonDesdeJob()`, `jobDesdeJson()`, `mostrarAdmisionJob()`, `mostrarDetalleJob()`, `mostrarResumenJob()` — presentación compartida local/remoto |
| `include/data_paths.h` | `rutaConfiguracion()` (`22-31`), `directorioDatosPredeterminado()` (`16-20`), `rutaDatos()` (`111-117`), `directorioRed()` (`119-121`), `actualizarEnlacesDesarrollo()` (`126-148`, crea los enlaces `data`, `config` y `network`) |
| `src/help/help.cpp` | Ayuda del CLI; `red setup` documentado en `26`, junto a `red start|job|filter|cancel` |
| `src/hermes/Makefile` | `SRC = $(shell find src -type f -name '*.cpp')`: cualquier `.cpp` nuevo se compila sin editar el Makefile; enlaza `-pthread` |
| `src/hermes/examples/network/network.json` | Plantilla funcional con un cliente `prueba-local` sobre `127.0.0.1` |

### 2.3 Grafo de dependencias

```
main.cpp
 ├── network.h ──────────────► server.cpp ──► network_access.h / network_protocol.h
 │                                 │          config.h / scheduler.h
 │                                 └── (usa) remote.cpp vía protocol.cpp
 ├── network.h ──────────────► client.cpp ──► network_access.h / network_protocol.h
 │                                 │          config.h / validator.h / job_presentation.h
 ├── network.h ──────────────► setup.cpp ──► network_remote.h / network_access.h
 │                                          config.h / data_paths.h / validator.h
 └── network_remote.h ───────► remote.cpp (plantilla al arrancar)

protocol.cpp ──► network_remote.h ──► remote.cpp ──► job.h / cancel.h / storage.h
                                                     config.h / data_paths.h / validator.h
                                                     job_presentation.h / timestamp.h
remote.cpp ──(persiste vía)──► job.cpp ──► storage.cpp ──► data_paths.h
job.cpp ──► event_log.cpp
scheduler.cpp ──► storage.cpp / process.cpp / cancel.cpp / event_log.cpp
setup.cpp ──► config_update.cpp (actualizarConfiguracion) / data_paths.h
```

---

## 3. Contrato del protocolo de comunicación

> El merge `858e3b1` **no tocó** `protocol.cpp`, `client.cpp`, `server.cpp:138-165` ni
> `network_protocol.h`. El sobre, los códigos de error, los límites y las operaciones de este
> capítulo son idénticos a la línea base `4efb296`. Lo que cambió fuera del protocolo es el esquema
> de `network.json` (§4.2) y la función compartida `reglaRedValida()` (§4.3 y §4.4).

### 3.1 Transporte y framing

| Propiedad | Valor | Evidencia |
| --- | --- | --- |
| Transporte | TCP sobre IPv4 (`AF_INET`, `SOCK_STREAM`) | `server.cpp:81,86`; `client.cpp:127-128,140` |
| Codificación | JSON UTF-8 (nlohmann/json) | `protocol.cpp:16`; `client.cpp:124,177` |
| Delimitador | `'\n'` al final de cada objeto; varias solicitudes secuenciales por conexión | `server.cpp:284-346`; `RNF-24` |
| Tamaño máximo de entrada | 16 384 bytes por mensaje, sin contar el delimitador | `network_protocol.h:5`; `protocol.cpp:13`; `server.cpp:291-320` |
| Tamaño máximo de respuesta | 262 144 bytes (238 KiB nominales) | `protocol.cpp:50`; cliente rechaza >262144 en `client.cpp:187` |
| Profundidad JSON | máx. 32 niveles → `INVALID_JSON` | `protocol.cpp:16-19` |
| Sockets | no bloqueantes + `SOCK_CLOEXEC`; cliente `MSG_NOSIGNAL`; servidor ignora `SIGPIPE` | `server.cpp:86,150,170`; `client.cpp:148-177`; `server.cpp:46-53` |
| Plazos | 3 s de inactividad en lectura, renovados con cada fragmento y cada respuesta entregada; 3 s para completar la escritura; cliente 10 s por solicitud | `server.cpp:359,401,443-450`; `client.cpp:167-194` |
| Cierre | la conexión sigue abierta tras una respuesta aceptada; cierra tras un rechazo de protocolo o tres segundos de inactividad | `server.cpp:394-397,443-450` |

El servidor acumula bytes hasta encontrar `'\n'`, atiende el mensaje completo y conserva el resto como
la solicitud siguiente. Las solicitudes de una conexión se atienden en orden, de una en una: mientras
hay una respuesta pendiente no se consume el mensaje siguiente, de modo que una ráfaga encolada no
crece en memoria. No hay protocolo de longitud explícita ni multiplexación de respuestas.

### 3.2 Sobre de petición

```json
{
  "version": 1,
  "request_id": "prueba-1",
  "operation": "submit | query | list | cancel | ping",
  "params": { }
}
```

Reglas de validación, en orden (`protocol.cpp:12-53`):

1. `mensaje.size() > MAX_MENSAJE_RED` → `MESSAGE_TOO_LARGE` (con `request_id: null`).
2. JSON inválido, codificación inválida o profundidad > 32 → `INVALID_JSON`.
3. El valor raíz no es objeto → `INVALID_REQUEST`.
4. `request_id` ausente o no string → `INVALID_REQUEST_ID` (con `null`).
5. `request_id` inválido según `validarRequestId()` → `INVALID_REQUEST_ID` (1-128 caracteres de
   `[A-Za-z0-9._:-]`).
6. `version` ausente o no entero → `INVALID_VERSION`; entero ≠ 1 → `UNSUPPORTED_VERSION`.
7. `operation` ausente o no string → `INVALID_OPERATION`.
8. `params` ausente o no objeto → `INVALID_PARAMS`.
9. `ping` exige `params` vacío; responde `pong` sin exigir identidad.
10. `submit|query|list|cancel` exigen identidad y permisos; si faltan → `UNAUTHORIZED`.
11. Cualquier otra cadena → `UNKNOWN_OPERATION`.

### 3.3 Sobre de respuesta

```json
{"version":1,"request_id":"<eco>","ok":true,"result":{ }}
{"version":1,"request_id":"<eco>","ok":false,"error":"CODIGO"}
{"version":1,"request_id":"<eco>","ok":false,"error":"CODIGO","message":"detalle"}
```

`version` y `request_id` los inyecta `procesarSolicitudRed()` después de ejecutar la operación
(`protocol.cpp:47-48`). `errorProtocolo()` (`protocol.cpp:8-10`) se usa para fallos de framing y
siempre emite `"request_id": null`.

### 3.4 Esquema exacto por operación

#### `ping` (diagnóstico, sin permisos)

| Petición | Respuesta |
| --- | --- |
| `{"version":1,"request_id":"p1","operation":"ping","params":{}}` | `{"version":1,"request_id":"p1","ok":true,"result":{"message":"pong"}}` |

Cualquier origen dentro de `redes_permitidas` puede hacer `ping`, aunque no tenga registro de
cliente (`protocol.cpp:39-43`; `RF-18:86-87`).

#### `submit` (`hermes red job`)

| Campo | Tipo | Restricción |
| --- | --- | --- |
| `params.programa` | string | obligatorio; debe coincidir **literalmente** con `permisos.programas` |
| `params.argumentos` | array de strings | obligatorio (puede ser vacío); sin `'\0'` |

`params` debe tener **exactamente 2 claves** (`remote.cpp:146`). Cualquier clave extra o ausente →
`INVALID_PARAMS`.

```json
{"version":1,"request_id":"r-1","operation":"submit",
 "params":{"programa":"sleep","argumentos":["30"]}}
```

```json
{"version":1,"request_id":"r-1","ok":true,
 "result":{"job_id":7,"duplicated":false,
           "job":{"job_id":7,"pid":0,"programa":"sleep","argumentos":["30"],"status":"QUEUED",
                  "codigo_salida":-1,"mensaje_error":"","tiempo_recepcion":"...",
                  "tiempo_inicio":"","tiempo_terminacion":""}}}
```

El `job` de la respuesta se genera con `jsonDesdeJob()` (`presentation.cpp:62-68`). `duplicated`
proviene de `Job::solicitudDuplicada` (`job.cpp:139`) y **no** es un estado persistido.

#### `query` (`hermes red filter <host> id <n>`)

```json
{"version":1,"request_id":"r-2","operation":"query","params":{"job_id":1}}
```

- `params` debe tener exactamente 1 clave y `job_id` entero en `[1, UINT32_MAX]` (`remote.cpp:193`).
- Solo devuelve el Job si `propietario_remoto == identidad` (`remote.cpp:37-39,195-198`).
- Respuesta correcta: `result` es **el objeto Job proyectado**, sin envoltorio `job`.
- Job ajeno o inexistente → `NOT_FOUND`.

#### `list` (`hermes red filter <host> status|programa <valor>`)

```json
{"version":1,"request_id":"r-3","operation":"list",
 "params":{"after":0,"limit":20,"tipo":"status","valor":"RUNNING"}}
```

| Clave | Regla |
| --- | --- |
| `after` | entero `[0, UINT32_MAX]`; opcional (por defecto 0) |
| `limit` | entero `[1, 50]`; opcional (por defecto 20) |
| `tipo` | `"status"` o `"programa"`; si aparece, `valor` es obligatorio |
| `valor` | validado con `validarStatusTexto()` o `validarPrograma()` |

`params` admite como máximo 4 claves y **solo** las cuatro anteriores (`remote.cpp:167-170`).
El resultado es `{"jobs":[ ...proyecciones... ],"next_after":<job_id del último incluido>}`
(`remote.cpp:182-191`). El recorrido salta `job_id <= after`, filtra por propietario y por el campo
`tipo`, y corta al alcanzar `limit`. El cliente itera páginas mientras `jobs` no esté vacío y exige
que `next_after` avance (`client.cpp:214-227`); si no avanza lanza *Cursor de respuesta inválido*.

La proyección (`remote.cpp:30-36`) expone solo:
`job_id, pid, status, programa, argumentos, tiempo_recepcion, tiempo_inicio, tiempo_terminacion,
codigo_salida, mensaje_error, cancel_requested`.
No expone `request_id`, `propietario_remoto`, `tipo_ejecucion`, `pid_inicio`, `sid` ni salidas.

#### `cancel` (`hermes red cancel <host> <id>`)

```json
{"version":1,"request_id":"r-4","operation":"cancel","params":{"job_id":1}}
```

Respuestas (`remote.cpp:200-210`):

| Situación | `result` / `error` |
| --- | --- |
| Job en `QUEUED` del mismo dueño | `{"job_id":1,"cancel_requested":true,"cancel_code":"CANCELADO"}` |
| Job en `RUNNING` del mismo dueño | `{"job_id":1,"cancel_requested":true,"cancel_code":"SOLICITUD_REGISTRADA"}` |
| No existe o es de otro dueño | `error:"NOT_FOUND"` |
| Estado terminal | `error:"NOT_CANCELABLE"` + `message` con el estado |

### 3.5 Idempotencia (`request_id`)

La deduplicación se implementa en `crearJob()` (`job.cpp:98-151`), no en el protocolo:

- El servidor construye la clave persistida como
  `"red-" + identidad + "-" + requestId` (`remote.cpp:160-162`), donde `identidad` es
  `"tcp-" + <ambito_trabajos del registro>` (`server.cpp:185`). Por defecto el ámbito coincide con el
  `id` de `network.json`, pero `setup` conserva el identificador anterior al renombrar un registro
  (§4.2). El ámbito de deduplicación es **ámbito de trabajos + request_id**.
- Consecuencia del merge: el historial pertenece al **ámbito**, no al `id` visible. El parser rechaza
  dos registros con el mismo `ambito_trabajos` (`remote.cpp:115-117`), así que dos registros distintos
  nunca comparten historial; un solo registro puede conservarlo al cambiar su `id` visible.
- La búsqueda ocurre dentro de `modificarJobsSeguros()` (bloqueo exclusivo de `jobs.lock`), de modo
  que dos `submit` concurrentes con la misma clave producen un solo Job.
- Coincidencia exacta de `request_id`, `propietario_remoto`, `programa` y `argumentos` → se devuelve
  el Job existente con `duplicated: true` y sin cambiar su estado.
- Misma clave con programa/argumentos distintos → `runtime_error` que `remote.cpp:212-215` convierte
  en `JOB_OPERATION_FAILED` con `message`.
- La garantía dura mientras el registro permanezca en `jobs.json`; `hermes clean data` elimina Jobs
  finalizados y con ellos la clave.
- Sin `--request-id`, el cliente genera 16 bytes aleatorios (`getrandom`) y los serializa en hex
  (`client.cpp:57-70`), por lo que cada invocación crea una solicitud nueva.

### 3.6 Errores y rechazos

#### Capa de protocolo (siempre `ok:false`)

| Código | Disparador |
| --- | --- |
| `INVALID_JSON` | JSON mal formado, codificación inválida o profundidad > 32 |
| `INVALID_REQUEST` | La raíz no es objeto |
| `INVALID_REQUEST_ID` | `request_id` ausente, no string o no válido |
| `INVALID_VERSION` | `version` ausente o no entero |
| `UNSUPPORTED_VERSION` | `version != 1` |
| `INVALID_OPERATION` | `operation` ausente o no string |
| `INVALID_PARAMS` | `params` ausente/no objeto, `ping` con parámetros, o parámetros no admitidos |
| `UNKNOWN_OPERATION` | Operación no reconocida |
| `UNAUTHORIZED` | Operación de trabajos sin identidad registrada o sin permiso de operación |
| `MESSAGE_TOO_LARGE` | > 16 384 bytes sin delimitador, o delimitador más allá de ese límite |
| `INCOMPLETE_MESSAGE` | El cliente cierra (FIN) antes del `'\n'` |
| `REQUEST_TIMEOUT` | No se completa el mensaje en 3 s desde `accept` |
| `RESPONSE_TOO_LARGE` | La respuesta serializada supera 262 144 bytes |

#### Capa de operación (dentro de `result`/`error`)

| Código | Disparador |
| --- | --- |
| `UNAUTHORIZED` | La operación no está en `permisos.operaciones` (`remote.cpp:143`) |
| `PROGRAM_NOT_ALLOWED` | `programa` no válido, contiene `'\0'` o no está en `permisos.programas` (`remote.cpp:150-152`) |
| `INVALID_PARAMS` | Forma/tipos/rangos incorrectos en `submit`, `list`, `query` o `cancel` |
| `NOT_FOUND` | Job inexistente o de otro propietario |
| `NOT_CANCELABLE` | Estado terminal (`SUCCEEDED`, `FAILED`, `CANCELED`, `INTERRUPTED`) |
| `JOB_OPERATION_FAILED` | Excepción del dominio (cola llena, fallo de almacenamiento, clave duplicada con otro contenido) con `message` |
| `UNKNOWN_OPERATION` | Defensa interna si llega una operación no contemplada |

#### Presentación de errores en el cliente

`client.cpp:186-200` traduce algunos códigos a mensajes humanos y **devuelve 1**:

- `filter id` + `NOT_FOUND`/`JOB_OPERATION_FAILED` → `No se encontró el Job ID: N`, **retorna 0**.
- `filter` (status/programa) + `JOB_OPERATION_FAILED` → `Error al leer jobs: ...`, **retorna 0**.
- `cancel` + `NOT_FOUND` → `No existe el Job ID: N`.
- `job` + `JOB_OPERATION_FAILED` → `No se pudo crear el Job: <message>`.
- Cualquier otro caso → `message` si existe; si no, el código literal (por eso `UNAUTHORIZED` y
  `PROGRAM_NOT_ALLOWED` se muestran como el código en inglés).

**Defecto observado:** las respuestas de `errorProtocolo()` llevan `request_id: null`
(`protocol.cpp:9`), pero el cliente exige `request_id == id` (`client.cpp:178`). Por tanto
`MESSAGE_TOO_LARGE`, `INCOMPLETE_MESSAGE` y `REQUEST_TIMEOUT` nunca llegan a mostrarse: el cliente
termina con `Hermes Red: Respuesta inválida del servidor` y código 1.

---

## 4. Configuración, control de acceso y seguridad

### 4.1 `config.json` (RF-16 / RF-20)

Ubicación: `~/.config/hermes/config.json` o `$XDG_CONFIG_HOME/hermes/config.json` si es absoluto
(`data_paths.h:22-31`). Campos relevantes para red:

| Clave | Tipo | Rango / validación | Default |
| --- | --- | --- | --- |
| `interfaz` | string | IPv4 literal (`inet_pton`), sin `'\0'` (`config.cpp:16-20`) | `127.0.0.1` |
| `puerto` | entero | `[1024, 65535]` (`config.cpp`, `config_update.cpp`) | `45820` |
| `redes_permitidas` | array de strings | cada regla válida según `reglaRedValida()` | `["127.0.0.0/8"]` |

Comportamiento ante configuración inválida (`config.cpp:27-131`):

- `interfaz` inválida → WARN y se conserva `127.0.0.1`.
- `puerto` inválido → WARN y se conserva `45820` (los enteros de concurrencia/cola sí se ajustan a
  sus límites; `puerto` no se ajusta).
- `redes_permitidas` no-array, con elemento no-string o con regla inválida → WARN, se **vacía** la
  lista y `reglasRedValidas = false`. El servidor entonces **no arranca**:
  `redes_permitidas inválida; corrija config.json antes de iniciar` (`server.cpp:73-74`).
- Lista vacía (`[]`) es válida y **deniega todos** los orígenes.

La API `actualizarConfiguracion()` (`CambiosConfiguracion`) valida `interfaz`, `puerto` y
`redes_permitidas` antes de escribir atómicamente (`config_update.cpp:249-262,298-313`). El merge
añadió `CambiosConfiguracion::agregarRedesPermitidas` (`config.h:54`): una lista de orígenes que se
**fusiona** con `redes_permitidas` conservando las reglas existentes, bajo el mismo `config.lock`
(`config_update.cpp:301-313`). Si la clave no existe, parte de `["127.0.0.0/8"]`; si es un array con
reglas inválidas, lanza error en lugar de reescribirla.

`red setup` es el **único consumidor CLI** de esa API: fija `interfaz` y agrega un origen. Sigue sin
haber un subcomando para fijar `puerto` o reemplazar `redes_permitidas` directamente, y `configmax`
solo cubre concurrencia y cola. Fuera de `setup`, estas claves se editan a mano y se reinicia el
servicio.

### 4.2 `network.json` (RF-18)

Ruta resuelta: `$HOME/.local/share/hermes/network/network.json`, calculada por `directorioRed()`
(`data_paths.h:119-121` = `directorioDatosPredeterminado().parent_path() / "network"`), consumida en
`remote.cpp:88` y `setup.cpp:261`. Es **independiente** de `directorio_datos`: aunque se configure otro
directorio de datos, la ruta se deriva siempre del directorio por defecto
(`$HOME/.local/share/hermes`). El RF-18 lo declara explícitamente.

**Inicialización automática (nuevo).** `inicializarConfiguracionRemota()` (`remote.cpp:42-84`) se
ejecuta en **cada** arranque de Hermes (`main.cpp:33`) y crea el archivo si falta:

- Directorio `~/.local/share/hermes/network` y plantilla con `habilitada: false`.
- Un registro `prueba-local` sobre `127.0.0.1`, operaciones `submit/query/list/cancel` y los
  programas `true`, `false`, `sleep`, `echo`, `ls`, `yes`, `time`, `bash` y sus rutas absolutas.
- Publicación atómica: `mkstemp` + `write` + `fsync` + `link()`; si otro proceso ya creó el archivo,
  `EEXIST` se ignora y **no se reemplaza** (`remote.cpp:74-78`).
- Si ya existe, no se lee ni se modifica en esta fase.

Consecuencias: un despliegue recién instalado nunca queda "sin `network.json`"; como la plantilla trae
`habilitada: false`, el servidor sigue atendiendo solo `ping` hasta que se edite o se ejecute `setup`.

**Enlace de desarrollo.** `actualizarEnlacesDesarrollo()` crea el enlace hermano `src/hermes/network`
→ `directorioRed()` (`data_paths.h:147`), igual que `data` y `config`. Solo se ejecuta cuando
`argc == 1` (`main.cpp:35`). El enlace está versionado en Git con un destino absoluto de otra máquina
(`/home/leo/.local/share/hermes/network`); cada copia lo reemplaza si es un symlink y falla si en su
lugar hay un archivo o directorio real (`data_paths.h:134-144`).

Esquema actual, con los campos que escribe `red setup`:

```json
{
  "habilitada": true,
  "servidor": {
    "id": "PC-A", "modo": "wsl-nat", "ip_windows": "10.204.218.198",
    "interfaz": "172.25.70.19", "gateway_wsl": "172.25.64.1", "puerto": 45820
  },
  "clientes": [
    {
      "id": "gateway-PC-A",
      "tipo": "gateway",
      "ambito_trabajos": "pc-b-via-windows",
      "direcciones": ["172.25.64.1"],
      "operaciones": ["submit", "query", "list", "cancel"],
      "programas": ["sleep", "true", "/usr/bin/sleep"]
    }
  ],
  "equipos": [
    { "id": "PC-B", "ip_lan": "200.39.175.139", "acceso": "gateway-PC-A",
      "regla_firewall": "Hermes-45820-PC-B" }
  ]
}
```

Validación completa antes de abrir el puerto (`interpretarConfiguracionRemota()`,
`remote.cpp:94-139`, invocada por `cargarConfiguracionRemota()` en `86-95`):

| Elemento | Regla | Error |
| --- | --- | --- |
| Archivo ausente | `habilitada = false`, sin error (la plantilla ya lo crea antes) | — |
| `habilitada` | obligatoria y booleana | `network.json requiere habilitada booleana` |
| `habilitada: false` | termina la carga; el servidor solo atiende `ping` | — |
| `tls` presente | rechazo explícito de configuración antigua | `Quite tls de network.json ...` |
| `clientes` | debe ser array | `clientes debe ser una lista` |
| `sha256` en un cliente | rechazo de configuración antigua | `Los clientes ahora requieren id y direcciones IPv4, no sha256` |
| `id` | válido según `validarRequestId()` (1-128 de `[A-Za-z0-9._:-]`) | `ID de cliente inválido` |
| `ambito_trabajos` | opcional; por defecto `id`; válido según `validarRequestId()`; **único** entre registros | `Ámbito de trabajos inválido`; `Dos registros no pueden compartir un ámbito de trabajos` |
| `direcciones` | array no vacío; cada elemento IPv4 individual (`interfazValida` + `reglaRedValida`) | `Cada dirección de cliente debe ser una IPv4 unicast individual válida` |
| IP repetida entre clientes | `emplace` falla | `Una IPv4 no puede pertenecer a varios registros de cliente` |
| `operaciones` | subconjunto de `submit|query|list|cancel` | `Permiso de operación desconocido` |
| `programas` | cada uno validado con `validarPrograma()` y sin `'\0'` | `Los programas permitidos deben ser nombres o rutas válidos` |
| `id` repetido | `emplace` falla | `Identidad de cliente duplicada` |

Cualquier excepción aborta `iniciarServidorRed()` **antes** de crear el socket y antes de arrancar el
scheduler (`server.cpp:71-79`).

**Claves que no se interpretan.** `servidor`, `equipos` y `clientes[].tipo` los escribe `setup`, pero
`interpretarConfiguracionRemota()` no los lee, no los valida y no los usa para autorizar ni para
escuchar. En particular:

- La interfaz y el puerto reales salen de `config.json`, no de `servidor.interfaz`/`servidor.puerto`
  (el asistente escribe ambos para mantenerlos coherentes).
- `equipos` es bookkeeping del firewall por equipo; no agrega identidades ni autenticación, y nada
  comprueba que `acceso` apunte a un `clientes[].id` existente ni que `ip_lan` sea válida.
- `tipo: "gateway"` es informativo: el parser no distingue gateways de clientes directos.

Limitación relevante de la validación: `validarPrograma()` solo comprueba que la cadena no esté
vacía (`validator.cpp:92-115`). Por eso `programas` acepta cualquier cadena no vacía sin `'\0'`;
la exigencia de "nombre o ruta literal válida" no se verifica más allá de eso.

### 4.3 Espacios de direcciones admitidos (RNF-13)

`access.cpp:33-46` acepta una regla si está **íntegramente contenida** en uno de:

- `127.0.0.0/8` (loopback)
- `10.0.0.0/8`
- `172.16.0.0/12`
- `192.168.0.0/16`
- `100.64.0.0/10` (espacio compartido CGNAT usado por algunas VPN)

**Excepción /32 unicast (nueva).** Si ninguna contención aplica, `reglaRedValida()` aún acepta una
dirección **individual** (`/32`, con o sin prefijo explícito) cuando cumple
`access.cpp:42-45`:

- `base >= 1.0.0.0` (excluye `0.0.0.0/8`),
- `base < 224.0.0.0` (excluye multicast y reservado `224/4` y superiores),
- fuera de `169.254.0.0/16` (link-local).

Esto habilita autorizar una IP de LAN no privada, por ejemplo `200.39.175.140` o
`200.39.175.140/32`, sin abrir `200.39.175.0/24`. Se aplica tanto a `config.redes_permitidas`
como a `network.json` `clientes[].direcciones`. No es una decisión neutral de seguridad: amplía la
superficie autorizable a cualquier host público concreto. RNF-26 y RNF-13 fueron alineados
para rechazar esas excepciones y mantener solo redes privadas, VPN y loopback.

`leer()` normaliza los bits de host en subredes (`192.168.1.25/24 → 192.168.1.0/24`), admite IP sin
prefijo como `/32` y rechaza prefijos fuera de `[0, 32]`, IPv6, hostnames y `'\0'`. `contenida()`
implementa la contención de subred comparando máscaras y bases.

### 4.4 Orden exacto de evaluación de seguridad

```
1. bind(interfaz, puerto)                    server.cpp:91    → error si la interfaz no es local
2. accept4()                                 server.cpp:169   → IP de origen del par TCP real
3. inet_ntop(origen)                         server.cpp:176-177
4. origenRedPermitido(ip, redes_permitidas)  server.cpp:178   → si falla: cierre SIN respuesta
5. cupo: clientes.size() < 32                server.cpp:178   → si se excede: cierre SIN respuesta
6. identidad = "tcp-" + ambitosTrabajos[identidades[ip]]               server.cpp:182-188 → si no hay: sin permisos
7. procesarSolicitudRed(..., identidad, permisos)
   7a. framing y forma del sobre             protocol.cpp:13-37
   7b. ping (permitido sin identidad)        protocol.cpp:39-43
   7c. operación de trabajos exige identidad protocol.cpp:44-45 → UNAUTHORIZED
   7d. permiso de operación                  remote.cpp:143    → UNAUTHORIZED
   7e. validación de params por operación     remote.cpp:146-210
   7f. nombre literal de programa            remote.cpp:150-152 → PROGRAM_NOT_ALLOWED
8. ejecución sobre el dominio local          remote.cpp:160-211
```

Propiedades y no-propiedades:

- El filtro de red se aplica **antes** del protocolo: un origen no autorizado no recibe ni siquiera
  `INVALID_JSON` (`RNF-08:68-69`).
- La identidad **nunca** se toma del JSON; el protocolo no tiene campo de identidad
  (`network_remote.h:13`).
- La comprobación de programa es **literal**: `sleep` y `/usr/bin/sleep` son permisos distintos
  (`remote.cpp:150-152`; `RF-18:94-99`).
- No hay autenticación, firma ni cifrado: quien pueda falsificar el origen TCP o compartir la IP
  (NAT) hereda los permisos del registro (`RF-18:88-92`).
- `0.0.0.0` como `interfaz` escucha en todas las IPv4, pero no amplía `redes_permitidas`
  (`RF-20:34-35`).
- El cliente solo conecta a destinos que pasen `reglaRedValida()` (`client.cpp:139`). RNF-26 restringe
  esa función a loopback, RFC1918 y `100.64.0.0/10`; una dirección pública no se usa para la demostración.
- WSL/Windows: el `portproxy` sustituye la conexión, así que el origen observado es el gateway de
  WSL o la IP del host Windows, no la IP LAN del cliente. Las reglas deben autorizar **ese** origen
  observado (`RF-18`; `docs/user-guide/red-wsl-pc-a-pc-b.md`). Varios equipos detrás de ese proxy
  siguen compartiendo un único registro de `clientes`; `setup` los separa en `equipos` solo para
  el firewall, no para la autorización de Hermes.

---

## 5. Concurrencia, ciclo de vida de sockets y observabilidad

### 5.1 Modelo del servidor

- **Un solo hilo**, bucle `poll()` con timeout de 100 ms (`server.cpp:112-117`).
- FDs: escucha + hasta 32 clientes (`server.cpp:178`). `listen(..., 10)` de backlog
  (`server.cpp:93`).
- `socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0)` y `SO_REUSEADDR`
  (`server.cpp:86-90`). No se configura `TCP_NODELAY`, `SO_KEEPALIVE` ni `SO_REUSEPORT`.
- `accept4(..., SOCK_CLOEXEC | SOCK_NONBLOCK)`; `EINTR`, `EAGAIN`, `EWOULDBLOCK` y `ECONNABORTED` se
  ignoran (`server.cpp:169-175`).
- Cada cliente es un `struct Cliente` con `esperado` (`POLLIN`/`POLLOUT`), buffers `entrada`/`salida`,
  contador `enviado`, `limite` temporal, bandera `cerrado`, `cerrarTrasEnviar` y `bytesSolicitud`
  (`server.cpp:173-195`).
- La respuesta se encola con el lambda `responder()` y se envía por partes respetando escrituras
  parciales (`server.cpp:209-214,379-403`). Al completar una respuesta aceptada, `esperado` vuelve a
  `POLLIN` y la conexión queda lista para el mensaje siguiente.
- Un cliente se elimina del vector cuando un rechazo termina su respuesta, al detectar error/cierre,
  al vencer el plazo o al completar un FIN ordenado (`server.cpp:394-397,443-450`).

Máquina de estados por cliente:

```
accept → (POLLIN) recv → acumular fragmentos → '\n' encontrado → procesarSolicitudRed → responder()
       → (POLLOUT) send* → entregada → POLLIN → siguiente mensaje (bucle)
       → rechazo de protocolo/framing → send* → cerrado → close
       → timeout de inactividad sin datos → responder(REQUEST_TIMEOUT) → cerrado
       → recv == 0 con búfer vacío y transacción atendida → cerrado (silencioso)
       → recv == 0 con bytes sin delimitador → responder(INCOMPLETE_MESSAGE) → cerrado
```

### 5.2 Plazos y resistencia a clientes lentos

- `limite` se renueva a `now + 3 s` con cada `recv()` que devuelve bytes y con cada respuesta
  entregada (`server.cpp:359,401`). Es un plazo de **inactividad**, no absoluto: un emisor lento que
  avanza no lo extiende más allá de tres segundos desde su último byte, pero un mensaje fragmentado
  que progresa nunca se corta a mitad.
- Al encolar una respuesta, `limite` se renueva a `now + 3 s` para la escritura (`server.cpp:213`).
- El almacenamiento de entrada está acotado: se añade como máximo un bloque de 4096 bytes por
  lectura y el límite se evalúa por mensaje (`server.cpp:291-320`), por lo que `entrada` puede superar
  16 384 en hasta un bloque antes de emitir `MESSAGE_TOO_LARGE`.
- Un error de lectura/escritura afecta solo al cliente correspondiente; `MSG_NOSIGNAL` y la
  ignorancia de `SIGPIPE` evitan terminar el proceso.

### 5.3 Señales y cierre ordenado

`Senales` (`server.cpp:34-62`) instala `sigaction` para `SIGINT` y `SIGTERM` con un handler que solo
escribe la bandera `volatile std::sig_atomic_t detener` (`server.cpp:22-23`), e ignora `SIGPIPE`.
Al salir del bucle:

- se destruyen los `unique_ptr<Cliente>` y sus `Descriptor` → `close()` de cada socket;
- se destruye el `Descriptor` del socket de escucha → libera el puerto;
- se restauran los handlers previos;
- se imprime `Hermes Red detenido` y se retorna 0 (`server.cpp:191-193`).

Cualquier excepción (config inválida, `bind`, `listen`, `poll`, error del socket de escucha) se captura
en `server.cpp:194-197`, se informa por `stderr` y se retorna 1.

### 5.4 Scheduler y ejecución

- El servidor arranca el scheduler **solo** si `network.json` está habilitado, y lo hace **antes** de
  crear el socket (`server.cpp:76-79`). El comentario justifica el orden: el daemon no debe heredar
  conexiones TCP.
- `iniciarSchedulerSiNecesario()` (`scheduler.cpp:1287`) garantiza instancia única con
  `flock(scheduler.lock, LOCK_EX | LOCK_NB)`; si otro scheduler ya lo posee, no arranca otro.
- `submit` ejecuta `crearJob()` y luego `esperarInicioJob()`: hasta 50 iteraciones de 20 ms (≈1 s)
  releyendo `jobs.json` hasta que haya PID o el Job falle (`job.cpp:306-313`). Es una espera
  **bloqueante dentro del hilo de `poll()`**.
- La cancelación remota no envía señales desde el hilo de red: `cancelarJobDetallado()` con
  `propietarioRemoto` no vacío se salta `escalarCancelacionProceso` (`cancel.cpp:85`) y solo marca
  `cancel_requested`. El supervisor, cada 200 ms, aplica `SIGTERM` y 5 s después `SIGKILL`
  (`scheduler.cpp:825-850,858`).
- `forest`/`process.cpp` es quien ejecuta y recolecta los hijos; el scheduler actualiza `jobs.json`
  con transiciones y eventos.

### 5.5 Observabilidad

Hasta RF-22 **no existía ninguna llamada a `EventLog` dentro de `src/hermes/src/network/*.cpp`**. Desde
RF-22 el servidor registra, con `log_event_system` (API que nunca lanza):

- `Conexión rechazada` (WARN): origen fuera de `redes_permitidas` o cupo de 32 agotado, con `{ip, motivo}`.
- `Cliente desconectado` (WARN): solo cierres anómalos (`FIN_SIN_MENSAJE`, `TIMEOUT_LECTURA`,
  `TIMEOUT_ESCRITURA`, `ERROR_LECTURA`, `ERROR_ESCRITURA`, `ERROR_SOCKET`, `ERROR_INTERNO`), con
  `{ip, motivo, bytes_recibidos}`.
- `Error interno al procesar cliente` (ERROR): excepción contenida por la frontera por cliente.

Para no degradar el bucle con el `fsync` de `EventLog`, cada motivo se registra **como máximo una vez
cada 60 s** y los cierres normales tras entregar la respuesta no generan eventos. Sigue sin registrarse
la apertura de conexiones aceptadas, el origen aceptado, los rechazos `UNAUTHORIZED` /
`PROGRAM_NOT_ALLOWED` / `INVALID_*` ni la creación de la plantilla por `red setup`. Tampoco
`inicializarConfiguracionRemota()` registra nada: no queda rastro de cuándo se creó la plantilla, qué
interfaz escribió `red setup` ni qué origen agregó a `redes_permitidas`. Las consecuencias vigentes:

- No se registra la apertura de conexiones, el origen aceptado, el origen rechazado por
  `redes_permitidas`, el exceso de cupo (32), ni los rechazos `UNAUTHORIZED` /
  `PROGRAM_NOT_ALLOWED` / `INVALID_*`.
- La trazabilidad disponible es **indirecta**, a nivel de Job:
  - `Job recibido` (INFO) con `programa`, `argumentos` y `request_id` **namespaced**
    (`job.cpp:227-234`);
  - `Solicitud duplicada reutilizada` (DEBUG) (`job.cpp:236`);
  - `Cancelación` con `{"accion":"CANCELADO_EN_COLA"}` (`cancel.cpp:72-74`);
  - transiciones del scheduler (`Transición a RUNNING/SUCCEEDED/FAILED`, `Cancelación exitosa`).
- `propietario_remoto` (`tcp-<ambito_trabajos>`) y `tipo_ejecucion: "remote"` viven solo en
  `jobs.json` (`job.cpp:185-188`), no en eventos de sistema. Desde el merge, el sufijo es el ámbito
  y puede no coincidir con el `id` visible del registro (`server.cpp:185`).
- Por tanto, un intento no autorizado **no deja rastro** en `events.jsonl`. Es la carencia de
  observabilidad más relevante para auditoría de seguridad.

---

## 6. Análisis de brechas (specs vs. código real) y deuda técnica

### 6.1 ADR-016

| Decisión del ADR | Estado real | Evidencia |
| --- | --- | --- |
| Arquitectura centralizada; todo pasa por PC-A | **Cumple** (no hay canal cliente-cliente) | `network.h`; un solo servidor escucha |
| PC-A administra conexiones y autoriza | **Parcial**: autoriza por IP, sin sesión administrada | `server.cpp:166-189` |
| Determinación de equipo ejecutor y distribución | **No implementado** | `RF-18:7-10`; sin código de reenvío |
| Comunicación bidireccional y resultados al solicitante | **No implementado**; el servidor solo responde a la petición | `RNF-08:5-6` |
| Identidad persistente por UUID, independiente de IP | **No implementado**: la identidad es `ambito_trabajos` de `network.json` mapeado a IP | `network_remote.h:13-16`; `server.cpp:185` |
| Separación servidor / gateway / equipos | **Parcial y solo de bookkeeping**: `setup` escribe `servidor` y `equipos`, pero la autorización sigue siendo IP→registro y nada valida esas claves | `setup.cpp:369-392`; `remote.cpp:94-139` |
| DHCP: actualizar `direcciones` conservando `id` | **Cumple como procedimiento manual** | `RF-18:89-92` |
| Descubrimiento automático mDNS/DNS-SD | **No implementado** | solo `getaddrinfo` manual (`client.cpp:131`) |
| TLS y autenticación criptográfica | **No implementado por decisión explícita** | `RF-18:12-17` |
| `INTERRUPTED` ante pérdida de conexión | **No aplica**: el Job vive en el servidor; una desconexión del cliente no lo interrumpe | `RF-18:181-183` |
| Scheduler local por equipo | **Cumple** (solo el servidor ejecuta) | `server.cpp:76-79` |

### 6.2 RF-16

| Requisito | Estado | Observación |
| --- | --- | --- |
| `config.json` en `~/.config/hermes` con XDG | Cumple | `data_paths.h:22-31` |
| `interfaz`, `puerto` con defaults y validación | Cumple | `config.cpp:96-101` |
| Valores inválidos → default + advertencia | Cumple, con matiz: `puerto` no se ajusta al límite, se descarta la clave | `config.cpp:81-96` |
| `CambiosConfiguracion` permite actualizar directorio, interfaz y puerto | Cumple en API; ahora también agrega `redes_permitidas` | `config_update.cpp:249-262`; `config.h:54` |
| CLI para actualizar esas claves | **Parcialmente resuelta**: `red setup` fija `interfaz` y agrega un origen; no hay CLI para `puerto` ni para reemplazar `redes_permitidas` | `setup.cpp:413-417`; `help.cpp:26` |

### 6.3 RF-18

| Requisito | Estado | Observación |
| --- | --- | --- |
| TCP + JSON sin TLS/certificados | Cumple | `RF-18:12-17` |
| `network.json` en `~/.local/share/hermes/network/` | Cumple; ruta centralizada en `directorioRed()` | `data_paths.h:119-121`; `remote.cpp:88` |
| Plantilla automática si falta el archivo | Cumple (nuevo) | `remote.cpp:42-84`; `main.cpp:33` |
| Enlace de desarrollo `src/hermes/network` | Cumple (nuevo) | `data_paths.h:147` |
| Sin `network.json`/`habilitada:false` → solo `ping` | Cumple; en la práctica la plantilla siempre existe y `habilitada:false` gobierna | `remote.cpp:99-101`; `protocol.cpp:44-45` |
| Validación completa antes de scheduler/puerto | Cumple | `server.cpp:72-79` |
| `id` 1-128 con reglas de `request_id` | Cumple | `remote.cpp:111-112` |
| `ambito_trabajos` opcional, válido y único | Cumple (nuevo) | `remote.cpp:113-117` |
| `direcciones` IPv4 unicast individuales | Cumple, con la política ampliada de §4.3 | `remote.cpp:118-125` |
| Operaciones como subconjunto | Cumple | `remote.cpp:126-131` |
| Programas "nombres o rutas literales válidos" | **Parcial**: `validarPrograma()` solo descarta cadena vacía | `validator.cpp:92-115` |
| `submit` con `propietario_remoto` y `tipo_ejecucion` | Cumple | `job.cpp:185-188` |
| Deduplicación por ámbito + `request_id` | Cumple | `remote.cpp:160-162`; `job.cpp:102-151` |
| `query`/`list`/`cancel` limitados al propietario | Cumple | `remote.cpp:37-39,195-198,202` |
| `list` 1-50 por página, paginación interna | Cumple, pero el cliente nunca envía `limit` (usa 20) | `client.cpp:124`; `remote.cpp:182-191` |
| `NOT_FOUND`/`NOT_CANCELABLE`/`PROGRAM_NOT_ALLOWED`/`UNAUTHORIZED` | Cumple | `remote.cpp:143,150-152,196-198,200-210` |
| `message` en los rechazos | **Parcial**: solo `JOB_OPERATION_FAILED` y `NOT_CANCELABLE` incluyen `message`; `UNAUTHORIZED`/`PROGRAM_NOT_ALLOWED` no | `remote.cpp:24,205,213-214` |
| `filter id` sin coincidencia → 0 | Cumple | `client.cpp:188-191` |
| No transmisión de `stdout` | Cumple | `RF-18:145-149` |
| Sin sesión de control a ejecutor | Cumple (no existe) | `RF-18:181-183` |
| Migración de `tls`/`sha256` | Cumple | `remote.cpp:104-110` |
| Asistente `red setup`: registra equipo y prepara LAN/WSL | Cumple (nuevo) | `setup.cpp:251-447`; `main.cpp:57`; `help.cpp:26` |
| `setup` conserva registros, permisos y respaldos | Cumple, con límites: los dos archivos no son atómicos entre sí y no verifica conectividad | `setup.cpp:406-421,442-445` |
| `servidor`/`equipos` validados al arrancar | **Brecha**: se escriben pero el parser no los lee | `remote.cpp:94-139` |
| Pruebas `python3 src/hermes/tests/network_remote.py` e `invalid.py` | **Brecha documental**: `src/hermes/tests/` no existe ni está versionado | `git ls-files src/hermes`; ver §6.10 |

### 6.4 RF-19

| Requisito | Estado | Observación |
| --- | --- | --- |
| Operaciones locales y remotas comparten el dominio de Jobs | Cumple | `crearJob()` en `job.cpp:60-188` es usado por el CLI local y por `ejecutarOperacionRemota()` |
| Consultas locales y remotas presentan el mismo estado | Cumple | `leerJobsSeguros()`, `jobDesdeJson()` y `jsonDesdeJob()` mantienen el mismo modelo |
| Cancelación local y remota aplica la misma máquina de estados | Cumple | `cancelarJobDetallado()` recibe el propietario remoto solo como filtro; QUEUED, RUNNING y estados terminales se interpretan igual |
| Deduplicación conserva la semántica de solicitud repetida | Cumple | TC-034 verifica una respuesta duplicada que reutiliza el Job existente |
| Evidencia | Cumple | TC-034 con admisión remota, deduplicación y consulta; TC-001, TC-004 y TC-005 cubren la semántica local |

La documentación detallada se conserva en [RF-19: semántica local/remota](RF-19.semantica-local-remota.md).

### 6.5 RF-21

| Requisito | Estado | Observación |
| --- | --- | --- |
| Delimitación de mensajes | Cumple | Un mensaje JSON se delimita con `\n`; el servidor interpreta solo el primer mensaje completo |
| Identificación de errores | Cumple | El servidor devuelve códigos deterministas en el sobre `{"ok":false,"error":"..."}` |
| Lecturas parciales | Cumple | `recv()` acumula los fragmentos hasta encontrar `\n` o vencer el plazo |
| Escrituras parciales | Cumple | Los bucles de envío avanzan con el contador `enviado` hasta transmitir toda la solicitud o respuesta |
| Validación de longitud y formato | Cumple | Límites de petición/respuesta, UTF-8, NUL, profundidad y clave superior se validan antes del despacho |
| Evidencia | Cumple | TC-031 cubre mensajes lentos; TC-039 formatos inválidos; TC-040/41 errores de respuesta; TC-042 un envío con dos mensajes |

La documentación detallada se conserva en [RF-21: protocolo delimitado y manejo de errores](RF-21.protocolo-delimitado-errores.md).

### 6.6 RF-20

| Requisito | Estado | Observación |
| --- | --- | --- |
| Reglas aplicadas a la IP de `accept4()` antes de responder | Cumple | `server.cpp:167-178` |
| Conexión no autorizada se cierra sin respuesta; el servicio continúa | Cumple | `server.cpp:178-179` |
| IP individual = `/32`; CIDR normalizado | Cumple | `access.cpp:8-25` |
| Sin clave → solo `127.0.0.0/8` | Cumple | `config.h:26` |
| Lista vacía deniega todo | Cumple | `access.cpp:54-59` (bucle sin reglas → `false`) |
| Lista inválida → falla antes de abrir el puerto | Cumple | `config.cpp:107-126`; `server.cpp:73-74` |
| Una regla inválida invalida toda la lista | Cumple | `access.cpp:52-53` |
| IP pública individual explícita (`/32`) | Rechazada por RNF-26 | `access.cpp:33-48`; RNF-26 |
| Pruebas | **Brecha**: RF-20 sigue declarando que no hay TC de red | `RF-20`; ver §6.10 |

### 6.7 RNF-08

| Requisito | Estado | Observación |
| --- | --- | --- |
| Mensajes JSON delimitados por `\n`, varias solicitudes secuenciales por conexión | Cumple | `server.cpp:284-346`; `RNF-24` |
| Acumulación de fragmentos TCP sin plazo absoluto | Cumple | `server.cpp:347-361` |
| FIN ordenado silencioso; `INCOMPLETE_MESSAGE` solo con bytes pendientes | Cumple | `server.cpp:362-372` |
| Cierre tras un rechazo de protocolo o tres segundos de inactividad | Cumple | `server.cpp:394-397,443-450` |
| `version` entero 1, `request_id` 1-128, `operation` string, `params` objeto | Cumple | `protocol.cpp:24-37` |
| `request_id: null` cuando falta o es inválido | Cumple | `protocol.cpp:8-10,24-27` |
| Validación antes de convertir enteros | Cumple (`from_chars`, `is_number_integer`) | `protocol.cpp:31-32`; `client.cpp:49-56` |
| Tabla de errores completa | Cumple | `protocol.cpp:13-53`; §3.6 |
| ≤32 clientes, excedente cerrado | Cumple | `server.cpp:178` |
| Plazo de 3 s de lectura, renovado por fragmento y por respuesta | Cumple | `server.cpp:359,401,443-450` |
| 3 s para completar la escritura | Cumple | `server.cpp:213,443-450` |
| Entrada acotada a límite + 4096, evaluada por mensaje | Cumple, con el matiz del bloque completo | `server.cpp:291-320` |
| Error de un cliente no afecta a otros | Cumple | `server.cpp:132,146-147,156-157` |
| `MSG_NOSIGNAL` / `SIGPIPE` | Cumple | `server.cpp:46-53,150`; `client.cpp:27-36,159` |
| Ctrl+C/SIGTERM libera sockets | Cumple | `server.cpp:95-96,191-193` |
| Filtro RF-20 antes del protocolo | Cumple | `server.cpp:178` |

### 6.8 RNF-12

| Requisito | Estado | Observación |
| --- | --- | --- |
| Default `127.0.0.1:45820` | Cumple | `config.h:24-25` |
| Interfaz inválida → `127.0.0.1`, sin fallback a `0.0.0.0` | Cumple | `config.cpp:97-101` |
| Dirección no local o puerto ocupado → error y salida 1 | Cumple | `server.cpp:91-92,194-197` |
| Ctrl+C/SIGTERM cierran la escucha | Cumple | `server.cpp:34-62,112,191-193` |
| Sin `red status`/`red stop`/daemonización | Cumple (no existen) | `main.cpp:56-59`; `help.cpp:26-32` |
| **"El comando no inicia el scheduler"** | **Contradicho**: con `network.json` habilitado, `red start` arranca el scheduler | `server.cpp:76-79` vs. `RNF-12:9` |

El punto anterior no es un defecto de código: es **documentación desactualizada**. RF-18 exige que el
servidor procese trabajos con su scheduler local, por lo que RNF-12 quedó obsoleto en esa frase.

### 6.9 RNF-13

| Requisito | Estado | Evidencia |
| --- | --- | --- |
| Subredes contenidas en loopback/RFC1918/`100.64.0.0/10` | Cumple | `access.cpp:36-41` |
| IP unicast pública explícita fuera de esos espacios (`/32`) | Rechazada por RNF-26 | `access.cpp:33-48`; RNF-26 |
| Normalización de bits de host en subredes | Cumple (`access.cpp:22-23`) |
| Rechazo de DNS, IPv6, prefijos fuera de rango, `0.0.0.0/0` | Cumple (`access.cpp:8-25`) |
| Rechazo de `0.0.0.0/8`, `224/4` y superiores, `169.254.0.0/16` | Cumple (`access.cpp:44-45`) |
| Default solo loopback | Cumple (`config.h:26`) |
| `0.0.0.0` no amplía autorización | Cumple (filtro independiente) |
| Verificación `src/hermes/tests/network_access.sh` | **Brecha documental**: el archivo no existe (ver §6.10) |

### 6.10 Cobertura de verificación existente: estado real

**Hallazgo principal: el subsistema de red no tiene ni una sola prueba automatizada.** La búsqueda en
`verif/` de `red`, `network.json`, `redes_permitidas`, `UNAUTHORIZED`, `PROGRAM_NOT_ALLOWED`,
`interfaz` o `puerto` no produce coincidencias dentro de `verif/` (solo aparecen en `docs/` y `src/`).
El merge `858e3b1` **no modificó `verif/`**: `git diff e52c51f..HEAD --stat -- verif/` está vacío. Las
más de 1 000 líneas nuevas de `setup.cpp` y su documentación no tienen ningún caso de prueba.

Estado en la matriz de trazabilidad (`verif/verification-plan/traceability-matrix.md`):

| Requisito | Fila | Estado declarado |
| --- | --- | --- |
| RF-16 | `:21` | `Pendiente` (descripción, caso, script y evidencia vacíos) |
| RF-18 | `:23` | `Pendiente` |
| RF-20 | `:25` | `Pendiente` |
| RNF-08 | `:42` | `PASS` con `TC-008`, pero acotado a **local**: *"Solicitud invalida no termina el servicio (local; desconexion en Fase 2)"* |
| RNF-12 | `:46` | `Pendiente` |
| RNF-13 | `:47` | `Pendiente` |

Qué cubren realmente `TC-016` … `TC-024` (todas contra el CLI local, `jobs.json` y `/proc`):

| Caso | Título | Cobertura efectiva | Req. |
| --- | --- | --- | --- |
| TC-016 | Saturación de cola y rechazo explícito | `trabajos_maximos: 5`, sexto `job` rechazado, estado íntegro | RF-25, RNF-29 |
| TC-017 | Cancelaciones concurrentes (robustez) | 5 `cancel` en paralelo sobre el mismo Job; JSON válido | RF-26, RNF-27 |
| TC-018 | Tratamiento idempotente de solicitudes duplicadas | 8 `job --request-id rf27-concurrent` → un único Job; conflicto rechazado | RF-27 |
| TC-019 | Cancelaciones concurrentes coherentes | N rondas de 2 `cancel` simultáneos → `CANCELED`, JSON re-parseado | RF-26 |
| TC-020 | Terminación inesperada del proceso hijo | `kill -SEGV $$` → `FAILED`, `codigo_salida = -11`, sin zombis | RF-29, RNF-30 |
| TC-021 | Escalamiento de cancelación | Job que ignora `SIGTERM` → gracia 5 s → `SIGKILL` (`-9`) | RF-30 |
| TC-022 | Interrupción durante persistencia y recuperación | 9 escenarios de crash/recovery, `.bak`, `pid` reutilizado, desconocidos | RNF-28/31/10/11/30 |
| TC-023 | Rechazo explícito cuando la cola está llena | `trabajos_maximos: 2`, 8 submits → 1 aceptado / 7 rechazados, eventos WARN | RF-23, RF-25 |
| TC-024 | Liberación de recursos tras estrés | RSS/FD/socket/hijos/temporales tras 100 Jobs | RNF-33 (parcial) |

Ninguno invoca `hermes red start`, `red job`, `red filter` ni `red cancel`; ninguno abre un socket TCP
de Hermes.

Escenarios de red **sin cobertura**: bind de `interfaz`/`puerto` y fallo con puerto ocupado; default
loopback y ausencia de fallback a `0.0.0.0`; `redes_permitidas` (CIDR, lista vacía, lista inválida,
origen no autorizado); espacios RNF-13 (públicas, IPv6, DNS, prefijos inválidos); `network.json`
(estructura, duplicados, `tls`/`sha256`, `habilitada:false`); `UNAUTHORIZED` y `PROGRAM_NOT_ALLOWED`;
framing (`INVALID_JSON`, `MESSAGE_TOO_LARGE`, `INCOMPLETE_MESSAGE`, `REQUEST_TIMEOUT`,
`UNSUPPORTED_VERSION`); clientes concurrentes y cupo de 32; `query`/`list`/`cancel` remotos y
aislamiento entre propietarios; deduplicación remota; NAT/portproxy; cierre con `SIGTERM` del
servidor; creación de la plantilla `network.json` y no reemplazo si ya existe; `red setup` en modo
directo y WSL NAT; validación de `ambito_trabajos` (duplicado, inválido, ausente); conservación de
respaldos; rechazo de `network.json` cambiado durante la interacción; y la excepción /32 con sus
exclusiones (`0/8`, `224/4`, `169.254/16`).

**Brecha documental confirmada:** RF-16, RF-18, RNF-08, RNF-12 y RNF-13 mandan ejecutar
`src/hermes/tests/network_remote.py`, `network_invalid.py`, `network_access.sh` y `rf16.sh`. Ese
directorio **no existe** en el árbol de trabajo y `git ls-files src/hermes` no versiona ningún
archivo bajo `src/hermes/tests/`; solo `.gitattributes` declara `src/hermes/tests/*.sh text eol=lf`,
lo que sugiere que existió y se perdió. Seguir esas instrucciones al pie de la letra no reproduce
ninguna verificación.

Otras inconsistencias de la matriz: `TC-025` se menciona en `verif/test-cases/test-cases.md:5` pero
no existe; `TC-009` … `TC-013` no existen; la fila RNF-33 (`:62`) cita como evidencia
`TC-020.sh`/`results_TC-020.md` en lugar de `TC-024`; RF-27 aparece asignado a TC-017 en `:32` y a
TC-018 en `TC-018.md:3`.

Convenciones del arnés existente (`verif/scripts/README.md` y los nueve scripts):

- **Bash puro, Linux/WSL exclusivamente.** Dependen de `/proc`, `setsid`, `pkill`, `timeout`,
  `grep -oP`, `mapfile`, `compgen -G` y `ps -o stat=`. No ejecutables desde PowerShell.
- `REPO="$(cd "$(dirname "$0")/../.." && pwd)"`; binario `src/hermes/hermes`; `HOME` temporal con
  `mktemp -d` y `trap cleanup EXIT`.
- Salida 0 = PASS, 1 = FAIL; evidencia en `verif/results/` (unos casos truncan `.log`, otros añaden
  bloques Markdown).
- `.gitattributes` fuerza `eol=lf` en `verif/scripts/*.sh`.

### 6.11 Deuda técnica priorizada

| # | Hallazgo | Impacto | Evidencia |
| --- | --- | --- | --- |
| D1 | **Cero pruebas automatizadas del subsistema de red**; la matriz marca RF-16/18/20 y RNF-12/13 como `Pendiente` | Cualquier cambio en red es una regresión silenciosa | `verif/verification-plan/traceability-matrix.md:21,23,25,46,47`; §6.10 |
| D2 | `errorProtocolo()` devuelve `request_id: null` y el cliente exige que coincida, así que `MESSAGE_TOO_LARGE`, `INCOMPLETE_MESSAGE` y `REQUEST_TIMEOUT` se muestran como *Respuesta inválida del servidor* | Diagnóstico engañoso; se pierde el código real | `protocol.cpp:9`; `client.cpp:178` |
| D3 | ~~`esperarInicioJob()` duerme hasta 1 s dentro del hilo de `poll()`~~ **Resuelto en RF-22**: la rama `submit` ya no espera al scheduler y responde con `pid: 0` | Bloqueo de cabeza de línea eliminado; `esperarInicioJob` sigue usándose solo en el CLI local | `remote.cpp:160-166`; `verif/scripts/TC-029.sh` |
| D4 | ~~Cero `EventLog` en el módulo de red~~ **Parcialmente resuelto en RF-22**: se registran desconexiones anómalas, conexiones rechazadas y errores internos con ventana de 60 s; faltan `UNAUTHORIZED` / `PROGRAM_NOT_ALLOWED` / `INVALID_*` | Hay evidencia forense de desconexiones y rechazos de red; los rechazos de autorización siguen sin rastro | `server.cpp:105-117,195-202,288-300`; `verif/scripts/TC-028.sh` |
| D5 | `request_id` persistido es `red-tcp-<ambito>-<request_id>`; el valor original del cliente no aparece en `jobs.json` y el ámbito puede diferir del `id` visible | RNF-22 exige correlación directa solicitud↔job; ahora además el operador debe conocer el `ambito_trabajos`, no solo el registro | `remote.cpp:160-162`; `server.cpp:185`; `job.cpp:189-191` |
| D6 | `UNAUTHORIZED` y `PROGRAM_NOT_ALLOWED` no llevan `message` | El CLI muestra el código en inglés como texto de error | `remote.cpp:24,143,152`; `client.cpp:199` |
| D7 | `validarPrograma()` solo rechaza cadena vacía | `programas` de `network.json` acepta casi cualquier cadena; "ruta válida" no se verifica | `validator.cpp:92-115` |
| D8 | Números mágicos duplicados: `262144` en `protocol.cpp:50` y `client.cpp:175`; `3 s` y `32` dispersos | Riesgo de divergencia al cambiar límites | `protocol.cpp`; `client.cpp`; `server.cpp` |
| D9 | Un solo hilo y sin `TCP_NODELAY`/`SO_KEEPALIVE` | Latencia extra y sin detección temprana de pares muertos | `server.cpp:86-93` |
| D10 | Solo IPv4 en cliente y servidor | Sin soporte IPv6 aunque la red lo requiera | `client.cpp:127`; `server.cpp:81` |
| D11 | RNF-12 afirma que `red start` no inicia el scheduler | Contradice la implementación vigente y confunde al operador | `RNF-12:9` vs. `server.cpp:76-79` |
| D12 | Documentación de pruebas apunta a `src/hermes/tests/`, inexistente | Verificación no reproducible siguiendo la doc; el merge actualizó RF-18/RF-20/RNF-13 pero **mantuvo** esas rutas | §6.10 |
| D13 | Toda ejecución de Hermes crea el directorio de red y `network.json`, incluso comandos locales o `red job`; y el cliente sigue creando `jobs.json`/`events.jsonl` | Efecto lateral en equipos cliente y fallo de arranque si `~/.local/share/hermes/network` no es escribible | `main.cpp:33`; `remote.cpp:42-84`; `data_paths.h:111-117` |
| D14 | Sin límite de frecuencia ni de conexiones por origen; el único control es el cupo total de 32 | Un solo origen autorizado puede agotar los cupos | `server.cpp:178` |
| D15 | Errores de `network.json` incompleto provienen de `nlohmann::json` (`at()`/`get`) | Mensajes internos poco accionables para el operador | `remote.cpp:106-136` |
| D16 | ~~Una conexión por operación, sin reutilización~~ **Resuelto en RNF-24**: una invocación del cliente abre un socket y lo reutiliza mientras encadene solicitudes; la paginación de `filter` viaja sobre una sola conexión | El handshake por página desaparece contra el servidor actual; el reintento único solo cubre la paginación de solo lectura | `client.cpp:128-220,260-303`; `verif/scripts/TC-056.sh` |
| D17 | `red setup` escribe `config.json` y `network.json` sin transacción conjunta; si falla el segundo, el primero queda aplicado | Estado incoherente que exige reparación manual; el asistente solo avisa en `stderr` | `setup.cpp:413-420,442-445` |
| D18 | `servidor`, `equipos` y `clientes[].tipo` se escriben pero nunca se validan ni se usan al arrancar | Deriva silenciosa: `servidor.interfaz` puede no coincidir con `config.interfaz`, `equipos[].acceso` puede apuntar a un registro inexistente | `remote.cpp:94-139`; `setup.cpp:369-392` |
| D19 | El enlace `src/hermes/network` está versionado con el destino absoluto de otra máquina (`/home/leo/...`) y solo se repara con `argc == 1` | Clones nuevos ven un enlace roto hasta ejecutar `./hermes` sin argumentos; si hay un directorio real, el arranque falla | `src/hermes/network`; `data_paths.h:134-148`; `main.cpp:35` |
| D20 | `red setup` solo se enruta con `argc == 3`; `red setup <algo>` cae al cliente y aborta con un error de uso; además exige `reglasRedValidas` y un `network.json` legible | Diagnóstico confuso para el operador y dependencia implícita del arranque previo | `main.cpp:57`; `setup.cpp:259-265` |
| D21 | ~~La excepción /32 amplía la superficie autorizable a cualquier host público concreto y el cliente también conecta a él~~ **Corregido por RNF-26** | Se elimina la excepción pública; solo se aceptan loopback, RFC1918 y `100.64.0.0/10` | `access.cpp:33-48`; `client.cpp:139`; RNF-26 |

### 6.12 Casos borde no cubiertos por el diseño actual

- **NAT/portproxy**: varios equipos tras la misma IP observada comparten registro, identidad y
  permisos (`RF-18`). `setup` los separa en `equipos` solo para el firewall de Windows; Hermes sigue
  sin distinguirlos y el ámbito de trabajos es común por diseño.
- **Cambio de IP por DHCP**: obliga a editar `network.json` y reiniciar el servicio; no hay
  recarga en caliente (`remote.cpp:86-139` se evalúa una sola vez al arrancar).
- **Cliente que aborta tras enviar `submit`**: el Job ya quedó persistido; no hay compensación ni
  consulta posterior por `request_id` en la CLI (solo por `job_id`).
- **Respuesta mayor a 256 KiB** (p. ej. `list` de Jobs con argumentos muy largos): el servidor
  devuelve `RESPONSE_TOO_LARGE` y el cliente, al no requerir `request_id` en ese camino, lo trata
  como respuesta inválida (D2).
- **Interfaz `0.0.0.0`**: expone el puerto en todas las interfaces; la protección real depende solo
  de `redes_permitidas` y del firewall externo.
- **Programas intérprete** (`bash`, `time`): autorizar el intérprete autoriza cualquier código que
  ejecute; no hay sandbox ni reglas por argumento (`RF-18:97-99,300-314`).
- **`request_id` invisible para el operador**: el cliente nunca imprime el identificador (ni el
  generado ni el de `--request-id`); `mostrarAdmisionJob()` solo muestra `job ID` y `PID`
  (`presentation.cpp:19-31`). Un reintento idempotente exige que el usuario recuerde el valor que
  envió.
- **Puerto del cliente**: el cliente usa el `puerto` de **su propio** `config.json`
  (`client.cpp:130`), no un flag. Si el cliente tiene otro puerto configurado, la conexión apunta a
  un destino distinto del esperado, sin mensaje específico.
- **Errores de conexión sin código de protocolo**: rechazo de conexión, timeout de 10 s o respuesta
  no conforme producen mensajes locales (`No se pudo conectar a un servidor LAN/VPN`,
  `Tiempo de conexión o respuesta agotado`, `Respuesta inválida del servidor`) y salida 1; el
  servidor no participa en ese diagnóstico (`client.cpp:37-48,131-135,154,174,180`).
- **`hermes red start` no sobrevive a un reinicio**: no hay autostart ni daemonización
  (`RF-18:294-295`; `RNF-12:9-11`).
- **Cambios de configuración en caliente**: imposibles; `interfaz`, `puerto` y `network.json` se leen
  al arrancar y exigen reiniciar el servicio (`RF-20:33-35`; `remote.cpp:86-139`).
- **Borrar `ambito_trabajos` para "renombrar"**: el registro cambia de identidad y deja de ver los
  Jobs anteriores; además la plantilla y los ejemplos no lo documentan en el propio JSON
  (`remote.cpp:113-117`). Es la forma más fácil de perder historial por error.
- **`red setup` no comprueba conectividad**: valida formato, escribe archivos y, en WSL NAT, comprueba
  que el proxy escuche; no prueba que PC-B llegue, que el firewall externo permita el puerto ni que
  un trabajo remoto termine (`setup.cpp:394-440`).
- **`red setup` en un host sin `network.json` previo**: depende de que `inicializarConfiguracionRemota()`
  ya lo haya creado; si el archivo existe pero está corrupto, el asistente aborta sin escribirlo
  (`setup.cpp:261-265`).
- **`red setup` con una `redes_permitidas` inválida**: aborta antes de pedir datos
  (`setup.cpp:260`), porque `cargarConfiguracion()` la habría vaciado y marcado `reglasRedValidas:false`.

---

## 7. Guía de impacto para cambios futuros

Checklist por tipo de cambio. Marcar cada archivo que deba actualizarse **antes** de tocar código.

### 7.1 Nueva operación remota (p. ej. `status`, `logs`, `clean`)

| Capa | Archivo | Acción |
| --- | --- | --- |
| Protocolo | `src/hermes/src/network/protocol.cpp` | Añadir a la lista de operaciones autorizadas (`44`); decidir si requiere identidad |
| Permisos | `src/hermes/src/network/remote.cpp:126-131` | Ampliar el conjunto válido de `operaciones` |
| Despacho | `src/hermes/src/network/remote.cpp:141-211` | Implementar la rama y su validación de `params` |
| Contrato | `src/hermes/include/network_remote.h` | Si cambia la firma o aparecen tipos nuevos |
| CLI | `src/hermes/src/network/client.cpp:85-122` | Parseo, validación local y mapeo al nombre de operación |
| Enrutado CLI | `src/hermes/src/main.cpp:56-59` | Solo si cambia el subcomando de nivel superior |
| Ayuda | `src/hermes/src/help/help.cpp` | Documentar el comando |
| Config | `src/hermes/examples/network/network.json` | Añadir la operación a los ejemplos |
| Docs | `RF-18`, `RNF-08`, este documento | Tabla de operaciones y errores |
| Verificación | `verif/test-cases/TC-0xx.md`, `verif/scripts/TC-0xx.sh`, `verif/verification-plan/traceability-matrix.md`, `verif/results/` | Caso nuevo + script + fila de trazabilidad |

### 7.2 Cambio en el protocolo (campos, límites, versionado)

| Archivo | Qué revisar |
| --- | --- |
| `include/network_protocol.h` | `MAX_MENSAJE_RED`, `MAX_RESPUESTA_RED` |
| `src/network/protocol.cpp` | Validación del sobre, `version`, `errorProtocolo`, límite de respuesta |
| `src/network/client.cpp` | Espejo exacto: construcción del sobre (`124`), recepción con búfer residual y límite del cliente (`167-195`), reintento de paginación (`197-220`) |
| `src/network/server.cpp` | Framing por mensaje, límite evaluado por solicitud, orden FIFO entre lecturas y respuestas, plazo de inactividad y cierre tras rechazo (`288-403,443-450`) |
| `RNF-08` | Tabla de errores, framing, límites |
| `RNF-24` | Varias solicitudes por conexión, fragmentación, cierre ordenado |
| `RF-18` | Tabla `operation/params` y errores |
| `verif/` | Casos negativos: mensaje incompleto, demasiado grande, timeout, versión no soportada; y los de RNF-24: fragmentado lento, secuencia larga, exceso de framing |

Regla práctica: **todo límite numérico debe declararse una sola vez** (idealmente en
`network_protocol.h`) y consumirse desde cliente y servidor. Hoy `262144` está duplicado.

El merge `858e3b1` no modificó esta capa. **RNF-24 sí la modificó**: `server.cpp` y `client.cpp`
pasaron de una transacción por conexión a varias secuenciales. `network_protocol.h` y
`protocol.cpp` siguen intactos porque el validador es sin estado y recibe cada mensaje por separado.

### 7.3 Nueva regla de autorización o de direcciones

| Archivo | Acción |
| --- | --- |
| `include/network_access.h` / `src/network/access.cpp` | Espacios admitidos, contención, normalización |
| `include/config.h` / `src/config/config.cpp` | Si aparece una clave nueva o cambia el default |
| `src/config/config_update.cpp:249-262,298-313` | Validación y persistencia atómicas; `agregarRedesPermitidas` fusiona sin borrar reglas |
| `src/network/remote.cpp:118-125` | Si la regla afecta `direcciones` de clientes |
| `src/network/setup.cpp:60-66,276-278` | `pedirIP()` y la comprobación de que la IP pertenece al equipo; `reglaRedValida()` decide qué se ofrece |
| `RF-20`, `RNF-13` | Política y espacios (la excepción /32 está aquí) |
| `docs/user-guide/red-wsl-pc-a-pc-b.md` | Procedimiento operativo y tabla de diagnóstico |
| `verif/` | Pruebas de límites (públicas, CIDR fuera de espacio, `0.0.0.0/0`, lista inválida) |

### 7.4 Nuevos campos persistidos del Job

| Archivo | Punto exacto |
| --- | --- |
| `src/job/job.cpp:174-194` | Creación del `item` persistido |
| `src/job/job.cpp:102-147` | Comparación de duplicados (si el campo participa en la idempotencia) |
| `src/job/presentation.cpp:5-18` | `jobDesdeJson()` |
| `src/job/presentation.cpp:62-68` | `jsonDesdeJob()` |
| `src/network/remote.cpp:30-36` | `proyectar()`: decidir si el campo se expone por red |
| `src/scheduler/scheduler.cpp` | Transiciones, recuperación y `atenderCancelacionesRemotas()` |
| `RF-18`, `RNF-22` | Contrato visible y correlación |

Cuidado: `proyectar()` es una **lista blanca**; un campo nuevo no se publica por red hasta añadirlo
explícitamente.

### 7.5 Cambios en cancelación remota

| Archivo | Punto exacto |
| --- | --- |
| `src/network/remote.cpp:200-210` | Mapeo `CodigoCancelacion → código de protocolo` |
| `src/cancel/cancel.cpp:12-111` | Transiciones y comprobación atómica de propietario |
| `src/scheduler/scheduler.cpp:825-850` | Escalado `SIGTERM → SIGKILL` cada 200 ms |
| `src/network/client.cpp:196-211` | Mensajes y códigos de salida |
| `RF-18`, `RF-26`, `RF-30` | Semántica documentada |
| `verif/` | Casos de cancelación en cola, en ejecución, ajena y terminal |

### 7.6 Nuevo subcomando o cambio de CLI

| Archivo | Acción |
| --- | --- |
| `src/main.cpp:56-59` | Enrutado y validación de argumentos; recordar que el subcomando solo se reconoce con `argc == 3` |
| `src/network/client.cpp` | Uso (`76`), parseo y mensajes |
| `src/network.h` | Firma si cambia el contrato (hoy `iniciarServidorRed`, `configurarRedInteractiva`, `ejecutarClienteRed`) |
| `src/help/help.cpp:26-32` | Texto de ayuda y ejemplos |
| `RF-18` | Tabla Local/Remoto |
| `verif/` | Caso funcional + comparación con el CLI local |

### 7.7 Checklist de compilación y verificación

```sh
make -C src/hermes          # find src -name '*.cpp' incluye archivos nuevos
```

- Cualquier `.cpp` nuevo bajo `src/hermes/src/` se compila automáticamente (`Makefile:7`); toda
  cabecera nueva debe estar en `src/hermes/include/` para entrar en `-Iinclude` y en la dependencia
  `$(wildcard include/*.h)`.
- No hay paso `init`: el primer arranque crea `~/.local/share/hermes/network/network.json` y el enlace
  `src/hermes/network` (§4.2). `setup.cpp` entra por el mismo `find`, sin tocar el `Makefile`.
- Si se añade una dependencia externa, actualizar `Makefile` (`CXXFLAGS`, `LDFLAGS`).
- Actualizar `verif/verification-plan/traceability-matrix.md` con el requisito ↔ caso ↔ estado.
- Si el cambio altera comportamiento observable del CLI remoto, añadir el caso a
  `verif/test-cases/` **y** el script a `verif/scripts/` con su entrada en `verif/results/`.

Restricciones del arnés de pruebas (ver §6.10):

- Los scripts son **bash puro y solo Linux/WSL** (`/proc`, `setsid`, `pkill`, `pcregrep`/`grep -P`,
  `compgen`). No se ejecutan desde PowerShell; usar WSL.
- Patrón obligatorio: `REPO="$(cd "$(dirname "$0")/../.." && pwd)"`, `HOME` temporal con `mktemp -d`,
  `trap cleanup EXIT`, localización del scheduler por `/proc/*/fd` apuntando a `scheduler.lock`.
- `.gitattributes` fija `eol=lf`; si un clon de Windows introduce CRLF, ejecutar
  `dos2unix verif/scripts/*.sh`.
- **No existe hoy ningún TC de red que reutilizar**: el primer cambio en el módulo debe crear los
  scripts desde cero (`verif/scripts/TC-0NN.sh`) y registrar las filas `RF-16`, `RF-18`, `RF-20`,
  `RNF-08`, `RNF-12` y `RNF-13` de la matriz, hoy en `Pendiente`.
- Para pruebas de red reales hacen falta dos procesos y un puerto libre: el patrón viable es levantar
  `hermes red start` en background con `HOME` temporal, esperar `Hermes Red escuchando en ...`, y
  cerrarlo con `SIGTERM` verificando que el puerto queda libre.


### 7.8 Cambios en el asistente `red setup` o en el esquema de `network.json`

| Archivo | Qué revisar |
| --- | --- |
| `src/network/setup.cpp:251-447` | Flujo de preguntas, detección WSL (`usaProxyWindows`), generación de PowerShell, confirmaciones |
| `src/network/remote.cpp:42-84` | Plantilla inicial; cualquier clave nueva debe añadirse aquí y en `examples/network/network.json` |
| `src/network/remote.cpp:94-139` | `interpretarConfiguracionRemota()`: única validación que se aplica al arrancar. Toda clave nueva que deba validarse va aquí |
| `src/network/server.cpp:185` | Resolución `identidades[ip] → ambitosTrabajos`; si cambia el ámbito, cambia el propietario de los Jobs |
| `src/hermes/include/network_remote.h` | `ConfiguracionRemota` y firmas públicas |
| `docs/user-guide/red-setup.md` | Flujo, ejemplos y límites del asistente |
| `RF-18`, `RF-20`, `RNF-13` | Contrato y política de direcciones |
| `verif/` | No existe ningún caso de `setup`; el primero debe cubrir modo directo, WSL NAT, `ambito_trabajos` duplicado y archivo cambiado durante la interacción |

Regla práctica: `servidor` y `equipos` son **metadatos sin validación**. Si en el futuro deben influir
en la autorización o en el bind, hay que añadirlos a `interpretarConfiguracionRemota()` y a
`iniciarServidorRed()`; hoy no se leen.

### 7.9 Archivos que **no** deben tocarse sin decisión explícita

- `src/hermes/src/storage/storage.cpp`: atomicidad y bloqueo son la base de la idempotencia y de la
  recuperación; cualquier cambio afecta a red y a local por igual.
- `src/hermes/src/scheduler/scheduler.cpp`: el modelo de supervisión y el escalado de señales está
  coordinado con `cancel.cpp` y con `atenderCancelacionesRemotas()`.
- `src/hermes/src/process/process.cpp`: entrega de señales y recolección de hijos.
- `src/hermes/Makefile`: solo si cambian dependencias o flags.

---

## Anexo A. Referencias rápidas

| Tema | Documento |
| --- | --- |
| Arquitectura propuesta | `docs/desicions/ADR-016-Red-propuesta.md` |
| Configuración de escucha | `docs/technical-guide/2-Nucleo del proyecto/RF-16.configuracion-de-interfaz.md` |
| Operaciones remotas | `docs/technical-guide/2-Nucleo del proyecto/RF-18.operaciones-remotas.md` |
| Restricción de redes | `docs/technical-guide/2-Nucleo del proyecto/RF-20.restriccion-redes-direcciones.md` |
| Solicitudes inválidas | `docs/technical-guide/2-Nucleo del proyecto/RNF-08.solicitudes-invalidas.md` |
| No escuchar públicamente | `docs/technical-guide/2-Nucleo del proyecto/RNF-12.no-escuchar-publicamente.md` |
| LAN/VPN | `docs/technical-guide/2-Nucleo del proyecto/RNF-13.acceso-remoto-LAN-VPN.md` |
| Idempotencia | `docs/technical-guide/2-Nucleo del proyecto/RF-27.solicitudes-idempotentes.md` |
| Correlación logs | `docs/technical-guide/2-Nucleo del proyecto/RNF-22-correlacion-solicitudes-trabajos-logs.md` |
| Operación WSL/Windows | `docs/user-guide/red-wsl-pc-a-pc-b.md` |
| Asistente de configuración | `docs/user-guide/red-setup.md` |
| Plantilla de permisos | `src/hermes/examples/network/network.json` |

## Anexo B. Invocaciones y diagnóstico documentados

Invocaciones del CLI remoto (`RF-18:112-117`; `red-wsl-pc-a-pc-b.md:320-357`):

```sh
./hermes red setup                                  # asistente en PC-A: registra equipo y LAN/WSL
./hermes red start                                  # servidor, primer plano, en PC-A
./hermes red job  192.168.1.74 sleep 120
./hermes red job  192.168.1.74 --request-id prueba.red-001 sleep 30
./hermes red job  192.168.1.74 echo Hola
./hermes red job  192.168.1.74 bash -c 'sleep 2 & sleep 3 & wait'
./hermes red filter 192.168.1.74 id 7
./hermes red filter 192.168.1.74 status RUNNING
./hermes red filter 192.168.1.74 programa sleep
./hermes red cancel 192.168.1.74 7
```

`red setup` (documentado en `red-setup.md`) escribe `config.json` y `network.json`, habilita la red y,
en WSL NAT, genera `setup-windows-<id>.ps1`. No inicia el servidor ni verifica conectividad. El nombre
del subcomando solo se reconoce con `argc == 3`: `red setup extra` cae al cliente.

`red job` no espera la finalización; el resultado se consulta con `red filter <host> id <ID>`.

Preparación del entorno Windows/WSL (no forma parte de Hermes; `red-wsl-pc-a-pc-b.md:155-212`):

```powershell
netsh interface portproxy add v4tov4 listenaddress=192.168.1.74 listenport=45820 `
      connectaddress=172.25.70.19 connectport=45820
netsh interface portproxy show v4tov4

New-NetFirewallRule -Name "Hermes-PC-B-45820" -DisplayName "Hermes PC B 45820" `
      -Direction Inbound -Action Allow -Protocol TCP -LocalPort 45820 `
      -LocalAddress 192.168.1.74 -RemoteAddress 192.168.1.73
```

Comprobaciones por tramo: `ss -ltnp 'sport = :45820'` en WSL; `Test-NetConnection <ip> -Port 45820`
desde Windows y desde PC-B; `Get-Service iphlpsvc`; `Get-NetTCPConnection -LocalPort 45820`.
Un TCP exitoso no demuestra autorización de operaciones: hay que ejecutar además un `red job` real
(`red-wsl-pc-a-pc-b.md:264-313`).

Síntomas documentados (`red-wsl-pc-a-pc-b.md:500-513`):

| Síntoma | Causa habitual |
| --- | --- |
| `UNAUTHORIZED` | Servidor sin `network.json`, origen sin registro o sin permiso de operación |
| `PROGRAM_NOT_ALLOWED` | El nombre literal no está en `programas` (o falta la ruta exacta) |
| `NOT_FOUND` / ID no encontrado | Job inexistente o de otro propietario |
| Conexión cerrada sin respuesta | Origen fuera de `redes_permitidas` o cupo de 32 agotado |
| TCP False hacia la IP LAN de A | Regla de firewall con `RemoteAddress` incorrecta, o `portproxy`/`iphlpsvc` sin atender |

Tras reiniciar PC-A puede requerirse `Restart-Service iphlpsvc` (PowerShell administrador) y volver a
ejecutar `hermes red start` (`RF-18:262-295`).
