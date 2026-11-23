# RF-22 — Desconexión del cliente sin afectar al servicio

> **Estado del documento:** implementación completa y verificada el 2026-11-18.
> **Línea base auditada:** `main` con el subsistema de red de `4efb296` (ver `CONTEXTO-RED-ACTUAL.md`).
> **Alcance:** auditoría, diseño e implementación de RF-22 con cinco casos de prueba automatizados
> (`TC-030`…`TC-034`), todos en `PASS`.
>
> Este documento cumple dos funciones:
> 1. Es el documento de requisito que faltaba de RF-22 (matriz de trazabilidad `:27` está vacía).
> 2. Es el plan de implementación con la lista de tareas y su estado.

---

## 0. Requisito

**RF-22 — Desconexión del cliente sin afectar al servicio:** el sistema deberá manejar desconexiones
del cliente sin terminar el servicio ni corromper trabajos.

### 0.1 Advertencia documental

Antes de esta auditoría **RF-22 no tenía especificación**:

| Artefacto | Estado encontrado |
| --- | --- |
| `verif/verification-plan/traceability-matrix.md:27` | Fila `RF-22` vacía, estado `Pendiente` |
| `docs/technical-guide/2-Nucleo del proyecto/RF-22*.md` | No existía |
| `project-managment/cronograma.md:29` | Solo agrupa "RF-18 a RF-22, RF-28" |

Los criterios de aceptación de §0.2 se derivaron del enunciado y de
`RNF-08.solicitudes-invalidas.md:52-66` (*Aislamiento de clientes*). Fueron aprobados junto con el
diseño. Si la rúbrica oficial difiere, se revisa únicamente esta sección.

### 0.2 Criterios de aceptación

| ID | Criterio |
| --- | --- |
| **AC1** | Una desconexión del cliente (FIN, RST, aborto, timeout) **nunca termina el proceso servidor**. Ningún dato proveniente de un cliente puede provocar la salida del servicio. |
| **AC2** | Una desconexión **no corrompe** `jobs.json`: no quedan Jobs a medias, no se pierde un Job ya aceptado y no se duplica. |
| **AC3** | Un Job ya aceptado **sigue su ciclo de vida hasta estado terminal** aunque el cliente se desconecte; su desenlace se consulta después por `job_id`. |
| **AC4** | **No se fugan descriptores** de archivo ni sockets por cliente desconectado: cada cliente libera exactamente su descriptor. |
| **AC5** | La desconexión de un cliente **no afecta a otros clientes ni bloquea el bucle de eventos**. |
| **AC6** | El cupo de clientes **se recupera** y el servicio sigue aceptando conexiones nuevas tras desconexiones masivas. |
| **AC7** | Las desconexiones anómalas **quedan registradas** en la bitácora, sin que un fallo de E/S pueda afectar al servicio. *(Recomendado por RNF-22 / RF-14; no exigido literalmente por el enunciado de RF-22.)* |

### 0.3 Escenarios obligatorios

1. FIN prematuro sin `'\n'` (mensaje incompleto).
2. RST a mitad de lectura.
3. RST a mitad de escritura de la respuesta.
4. Corte durante la ejecución de `submit`.
5. Corte durante la ejecución de `cancel`.
6. Cliente lento que no completa el mensaje en 3 s.
7. Múltiples desconexiones simultáneas (saturación del cupo de 32).

---

## 1. Auditoría del código existente

### 1.1 Mecanismos ya correctos — no se tocan

| Mecanismo | Evidencia |
| --- | --- |
| `SIGPIPE` ignorado a nivel de proceso | `server.cpp:46-53` |
| `MSG_NOSIGNAL` en cada `send` | `server.cpp:152` |
| Error de `recv`/`send` solo cierra ese cliente | `server.cpp:146-147`, `156-157` |
| `EINTR`/`EAGAIN`/`EWOULDBLOCK`/`ECONNABORTED` tolerados en `poll` y `accept4` | `server.cpp:118-121`, `171-174` |
| `Descriptor` RAII + `unique_ptr` + transferencia `conexion.valor = -1` | `server.cpp:25-32`, `102`, `169-181` |
| Escrituras parciales con contador `enviado` | `server.cpp:149-157` |
| Plazo absoluto de 3 s de lectura, no renovable por bytes | `server.cpp:101` |
| Persistencia independiente del socket (`flock` + `mutex` + `tmp→fsync→rename→fsync(dir)`) | `storage.cpp:352-364`, `242-343` |
| `cancel` atómico y acotado al propietario | `cancel.cpp:20-54` |
| `ejecutarOperacionRemota` captura toda excepción de dominio | `remote.cpp:212-216` |
| Scheduler en **otro proceso** (`fork`) | `scheduler.cpp:1352`, `1287` |
| `EventLog` no lanza nunca (captura todo, devuelve `bool`) | `event_log.cpp:244-256`, `277-289` |

### 1.2 Brechas verificadas en fuente (estado previo a RF-22; cerradas por §3)

#### B1 — La única frontera de excepción está fuera del bucle

`server.cpp:143` llama `procesarSolicitudRed(...)` dentro del `for` de clientes; el `try` está en
`server.cpp:194`, fuera del `while`. Cualquier excepción propagada ahí ejecuta `return 1`: **el servicio
termina**.

Vector realista: `resultado.dump()` (`protocol.cpp:49`) lanza `json::type_error` con UTF-8 inválido.

No lo dispara una desconexión, pero es la única vía por la que un cliente puede tumbar el proceso y
contradice el invariante que AC1 exige.

**Impacto:** AC1. **Severidad:** alta.

#### B2 — Un cliente muerto retiene su slot hasta ~6 s

- `accept` fija `limite = T+3s` (`server.cpp:101`).
- Al vencer con `salida` vacía, `responder(REQUEST_TIMEOUT)` **renueva** `limite = T+6s`
  (`server.cpp:127`, `159-162`) y espera `POLLOUT` para entregar el error a un peer que ya no lee.
- A los 6 s se cierra.

32 conexiones abandonadas dejan el cupo completo durante ~6 s. El rechazo de nuevos clientes
(`server.cpp:178`) es **silencioso**.

**Impacto:** AC2 (parcial), AC5, AC6. **Severidad:** alta.

#### B3 — Se responde a quien ya colgó

`recv() == 0` → `responder(INCOMPLETE_MESSAGE)` (`server.cpp:144-145`). Es correcto para *half-close*
(el peer sigue leyendo), inútil para cierre total. Además, ese error **nunca se muestra**: `errorProtocolo()`
emite `request_id: null` (`protocol.cpp:9`) y el cliente exige coincidencia (`client.cpp:178`), por lo que
lo traduce como *Respuesta inválida del servidor* (deuda D2 de `CONTEXTO-RED-ACTUAL.md`).

Conclusión: no tiene sentido retener un slot para entregar un mensaje que el cliente oficial no interpreta.

**Impacto:** AC5, AC6. **Severidad:** media.

#### B4 — `responder()` no reinicia `enviado`

`server.cpp:124-128` asigna `salida` pero conserva `enviado`. Si se encolara una segunda respuesta sobre
el mismo cliente, `send` arrancaría en `salida.data() + enviado` → lectura fuera de rango y respuesta
corrupta.

Hoy es inalcanzable (solo se encola una respuesta por cliente), pero es un invariante no codificado.

**Impacto:** AC2, AC4. **Severidad:** baja hoy, latente.

#### B5 — `esperarInicioJob()` bloquea el hilo de `poll()` hasta 1 s por `submit`

`remote.cpp:163` → `job.cpp:306-313`: 50 iteraciones × 20 ms releyendo `jobs.json`. Es head-of-line
blocking: con 32 `submit` concurrentes el bucle queda ocupado ~32 s sin atender desconexiones ni timeouts
de nadie.

**Impacto:** AC5. **Severidad:** alta.

#### B6 — `flock(LOCK_EX)` bloqueante y sin plazo en el hilo de red

`storage.cpp:43` y `event_log.cpp:195` se invocan desde el hilo de `poll` (vía `crearJob` y `log_event`).
Si el daemon u otro proceso se atasca con `jobs.lock`, **el servicio se cuelga indefinidamente**.

**Impacto:** AC5. **Severidad:** media (fuera de alcance de este cambio; ver §4).

#### B7 — RST con datos en buffer descarta la solicitud sin procesar ni registrar

`server.cpp:132` cierra ante `POLLERR` **antes** de leer. Si el cliente envió un `submit` completo y
abortó con RST, el kernel descarta el buffer y **no se crea Job**. Estado consistente, pérdida silenciosa.

**Impacto:** AC2, AC7. **Severidad:** baja.

#### B8 — Cero observabilidad en el módulo de red

Búsqueda en `src/hermes/src/network/`: **ninguna** referencia a `EventLog` ni `log_event`. No queda rastro
de conexiones rechazadas, exceso de cupo, timeouts ni desconexiones.

**Impacto:** AC7. **Severidad:** media.

### 1.3 Respuesta a los escenarios de §0.3

| Escenario | Comportamiento actual | Veredicto |
| --- | --- | --- |
| FIN sin `'\n'` | `responder(INCOMPLETE_MESSAGE)` por `POLLOUT`. *Half-close*: se entrega y cierra limpio. Cierre total: `send` falla → cierra ese cliente | Correcto en aislamiento; costoso (B2/B3) |
| RST a mitad de lectura | `poll` marca `POLLERR` → cierre inmediato (`server.cpp:132`), sin fuga | Correcto; solicitud descartada (B7) |
| RST a mitad de escritura | `send` devuelve -1 → `cerrado` (`server.cpp:156-157`) | Correcto; el Job persistido sigue vivo |
| Corte durante `submit` | El Job ya está en `jobs.json` antes de tocar el socket; el scheduler es otro proceso | **No bloquea ni corrompe**; solo se pierde la respuesta |
| Corte durante `cancel` | `cancelarJobDetallado` es atómico bajo `jobs.lock` | Sin corrupción; el cliente no sabe si se aplicó (ver §4, R3) |
| Cliente lento | Plazo absoluto de 3 s desde `accept` | Correcto; retención extra por B2 |
| Desconexiones masivas | Cupo de 32 agotado hasta ~6 s y rechazo silencioso | **Degradado** (B2, B8) |

---

## 2. Matriz de cumplimiento (estado final)

| AC | Estado | Evidencia | Comentario |
| --- | --- | --- | --- |
| **AC1** | **Cumple** | `server.cpp:203-270` (frontera por cliente); `TC-030.sh`, `TC-031.sh`, `TC-032.sh` | Ninguna excepción de cliente escapa al bucle; toda desconexión se contiene y se registra |
| **AC2** | **Cumple** | `job.cpp:102-195`; `storage.cpp:242-343,352-364`; `TC-030.sh` | Escritura atómica; el socket no participa en la transacción. La pérdida por RST con datos (B7) queda registrada |
| **AC3** | **Cumple** | `job.cpp:174-194`; `scheduler.cpp:1287,1352`; `TC-030.sh`, `TC-034.sh` | Garantía arquitectónica: el daemon vive en otro proceso y los Jobs alcanzan estado terminal |
| **AC4** | **Cumple** | `server.cpp:25-32,302-304,273-274`; `TC-032.sh` | RAII correcto; 100 ciclos sin variación de descriptores (5 → 5) |
| **AC5** | **Cumple** | `remote.cpp:160-166` (sin espera); `server.cpp:186-194` (cortesía de un intento); `TC-031.sh`, `TC-034.sh` | `ping` en 57 ms tras 40 desconexiones; admisión en 21 ms |
| **AC6** | **Cumple** | `server.cpp:186-194,250-257`; `TC-031.sh` | El slot se libera en el mismo ciclo de `poll`; cliente lento expulsado a los 3.0 s |
| **AC7** | **Cumple** | `server.cpp:60-117,195-202,288-300`; `TC-033.sh` | Desconexiones anómalas y conexiones rechazadas registradas; un aviso por motivo cada 60 s |

**Veredicto global:** RF-22 se cumple en sus siete criterios. El servicio no termina ni se bloquea por
una desconexión, los trabajos no se corrompen y la desconexión anómala deja evidencia acotada.

**Riesgo residual declarado:** R1 (`flock` bloqueante sin plazo en `storage.cpp:43` y
`event_log.cpp:195`) sigue fuera de alcance por `CONTEXTO-RED-ACTUAL.md §7.9`.

---

## 3. Diseño aprobado

Principio rector: **el hilo de `poll()` nunca espera por un cliente, ni por el scheduler, ni por la entrega
de un mensaje de cortesía.** Todo lo que hoy espera pasa a "mejor esfuerzo, un intento, y cierro".

**Estado: los seis cambios están implementados y verificados** por `TC-030`…`TC-034`.

### 3.1 `src/hermes/src/network/server.cpp` — `iniciarServidorRed()`

#### Cambio 1 — Frontera de excepción por cliente (B1 / AC1)

Envolver el cuerpo del bucle por cliente (`server.cpp:131-162`) en `try/catch(...)`:

- `catch` → `EventLog::log_event_system(ERROR, "Error interno al procesar cliente", {{"error", e.what()}})`
- `cliente.cerrado = true; continue;`
- El `try` exterior (`server.cpp:194`) queda solo para fallos de infraestructura (config, `socket`, `bind`,
  `listen`, `poll`, socket de escucha).

**Garantía:** ningún dato de un cliente puede terminar el proceso.

#### Cambio 2 — `responder()` reinicia `enviado` (B4)

`server.cpp:124-128` → añadir `cliente.enviado = 0;`.

**Garantía:** elimina la lectura fuera de rango latente al reutilizar el buffer de salida.

#### Cambio 3 — Helper `despedida()`: error de cortesía de un solo intento (B2 / B3 / AC5 / AC6)

```cpp
cliente.salida = errorProtocolo(codigo);
cliente.enviado = 0;
send(cliente.socket.valor, salida.data(), salida.size(), MSG_NOSIGNAL); // socket ya es O_NONBLOCK
cliente.cerrado = true;   // SIEMPRE, haya enviado o no
```

Se usa en lugar de `responder()` en los puntos donde hoy se espera `POLLOUT` por un peer que probablemente
ya no está:

- `recv() == 0` → `INCOMPLETE_MESSAGE` (`server.cpp:144-145`).
- Vencimiento del plazo de lectura con `salida` vacía → `REQUEST_TIMEOUT` (`server.cpp:160`).
- `POLLHUP` sin `salida` → cierre directo, sin intento, si el socket no admite escritura.

**Garantía:** el slot se libera en el mismo ciclo de `poll`. La retención máxima baja de ~6 s a ~3 s + una
syscall. La semántica de RNF-08 se preserva: *half-close* sigue recibiendo el error; cierre total no
(imposible por definición).

#### Cambio 4 — Cierre explícito en `POLLERR`/`POLLNVAL`/`POLLHUP` (B7)

Ya ocurre en `server.cpp:132`; se añade registro con motivo `ERROR_SOCKET`/`PEER_CERRADO`. Sin cambio de
comportamiento.

#### Cambio 5 — `ip` en `Cliente` y bitácora acotada (B8 / AC7)

- `struct Cliente` recibe `std::string ip`, rellenada en `server.cpp:176-180`.
- Eventos nuevos con `log_event_system` (que **no lanza**):
  - `Conexión rechazada` (WARN) — origen fuera de `redes_permitidas` o cupo 32 agotado (`server.cpp:178`),
    con `{ip, motivo}`.
  - `Cliente desconectado` (WARN) — solo cierres anómalos: `TIMEOUT_LECTURA`, `TIMEOUT_ESCRITURA`,
    `ERROR_LECTURA`, `ERROR_ESCRITURA`, `FIN_SIN_MENSAJE`, `ERROR_INTERNO`. Nunca en el cierre normal tras
    respuesta completa.
  - `Error interno al procesar cliente` (ERROR) — Cambio 1.
- **Control de frecuencia obligatorio:** `std::array<Reloj::time_point, 6>` indexado por motivo, ventana
  de 60 s. Memoria acotada (6 entradas, sin mapa por IP).

**Justificación del límite:** `EventLog` hace `open+flock+write+fsync+close` por evento
(`event_log.cpp:185-223`); sin límite, un escaneo de puertos se convierte en DoS por `fsync`.

**Garantía ante fallos de E/S:** `log_event_system` captura todo y devuelve `bool`
(`event_log.cpp:259-290`); un disco lleno degrada la bitácora, nunca el servicio.

### 3.2 `src/hermes/src/network/remote.cpp` — `ejecutarOperacionRemota()`, rama `submit`

#### Cambio 6 — Eliminar `esperarInicioJob(job);` (línea 163) (B5 / AC5)

La respuesta se construye con el Job ya persistido: `status = QUEUED`, `pid = 0`.

Por qué es seguro y compatible:

- `jsonDesdeJob()` (`presentation.cpp:62-68`) ya emite `pid: 0`; el ejemplo normativo de RF-18 muestra
  exactamente `pid: 0`.
- El cliente imprime `"PID: pendiente (en cola)"` cuando `pid == 0` (`presentation.cpp:29-31`); no cambia
  el formato ni el código de salida.
- `mostrarAdmisionJob` sigue reportando `duplicated` igual (esa rama ya salía antes: `job.cpp:307`).
- RF-18 ya documenta que `red job` **no espera la finalización**; el resultado se consulta con `filter id`.

**Consecuencia observable única:** un `submit` cuyo programa falle al arrancar ya no reporta `FAILED` en la
misma respuesta; se ve con `filter id`. Es cambio de UX, no de protocolo.

`job.cpp` **no se toca**: `esperarInicioJob` sigue existiendo y usándose en el CLI local.

### 3.3 `src/hermes/src/network/protocol.cpp`

**Sin cambios de contrato.** El único punto que puede lanzar (`dump()` en `:49`) queda contenido por la
frontera de `server.cpp` (Cambio 1). Se cierra la conexión sin respuesta y se registra `ERROR_INTERNO`,
comportamiento ya previsto por `RNF-08:65-66`.

### 3.4 Archivos que NO se tocan

| Archivo | Motivo |
| --- | --- |
| `storage.cpp` | Atomicidad y `flock` son la base de la idempotencia y de la recuperación; `CONTEXTO-RED-ACTUAL.md §7.9` lo prohíbe sin decisión explícita. B6 se documenta como riesgo residual |
| `scheduler.cpp` / `process.cpp` | La ejecución ya es independiente del socket (daemon en otro proceso). No tocarlos es la garantía más fuerte de AC3 |
| `job.cpp` | Solo pierde un llamador, no comportamiento |
| `cancel.cpp` | Ya es atómico y acotado al propietario (`:20-54`) |
| `event_log.cpp` / `.h` | La API actual ya satisface el requisito (nunca lanza). Cambiar el `fsync` rompería durabilidad compartida con el scheduler |
| `client.cpp` | No participa en el lado servidor. Su rechazo de `request_id: null` (D2) es deuda aparte |
| `Makefile` | No hay archivos fuente nuevos |

### 3.5 Compatibilidad

- Protocolo JSON intacto: `version: 1`, delimitador `'\n'`, mismos códigos de error, mismas formas de
  `result`.
- Ningún cambio de esquema persistido en `jobs.json`.
- Ninguna garantía de atomicidad (`storage.cpp`) ni de concurrencia (`scheduler.cpp`) alterada.
- Único cambio visible: `red job` puede devolver `pid: 0` / `"PID: pendiente (en cola)"`.

---

## 4. Riesgos y alternativas

| Opción | Trade-off | Decisión |
| --- | --- | --- |
| **A. Elegida:** error de cortesía de un intento + cierre inmediato; sin espera del scheduler | Cambio pequeño, sin estado nuevo, elimina el 100 % del bloqueo por cliente | **Aprobada** |
| **B. Respuesta diferida:** estado `ESPERANDO_PID` por cliente y reintento no bloqueante en cada `poll` | Conserva el PID en la respuesta, pero añade máquina de estados, temporizadores por cliente y hasta 32 × 10 lecturas de `jobs.json` por segundo | Rechazada: complejidad desproporcionada; el cliente ya tolera `pid: 0` |
| **C. `epoll` + pool de hilos** | Escala más, pero rompe el modelo de un solo hilo que hoy da orden y simplicidad, y multiplica los puntos de bloqueo de `flock` | Rechazada: fuera de alcance |
| **D. Mantener `esperarInicioJob`** | UX ligeramente mejor en el `submit` | Rechazada: viola AC5 de forma medible |

### Riesgos aceptados y declarados

| ID | Riesgo | Mitigación |
| --- | --- | --- |
| **R1** | **B6:** `flock` bloqueante puede colgar el hilo de red si otro proceso se atasca. Fuera de alcance por §7.9 | Cambio posterior y separado: `LOCK_EX｜LOCK_NB` con reintento y plazo en `storage.cpp`, con decisión explícita |
| **R2** | Pérdida silenciosa en RST con datos (B7): inherente a TCP | Ahora queda **registrada** (Cambio 5); es lo máximo sin cambiar el modelo "un mensaje por conexión" |
| **R3** | `cancel` remoto no es idempotente por `request_id`: si se pierde la respuesta, el cliente no sabe si se aplicó | No es corrupción; se documenta, no se codifica |
| **R4** | Coste de `fsync` en bitácora dentro del bucle | Ventana de 60 s por motivo (Cambio 5) |

---

## 5. Verificación ejecutada

Casos automatizados en `verif/scripts/`, ejecutados el 2026-11-18 en WSL Ubuntu. Todos en `PASS`.

| ID | Caso | Script | Resultado observado |
| --- | --- | --- | --- |
| **V1** | `submit` + `shutdown(SHUT_WR)` inmediato | `TC-030.sh` | Servicio vivo; `jobs.json` válido; Job en estado terminal |
| **V2** | `submit` + `SO_LINGER{1,0}` (RST) inmediato | `TC-030.sh` | Servicio vivo; sin Jobs parciales |
| **V3** | `SIGKILL` del cliente con mensaje parcial | `TC-030.sh` | Servicio vivo; sin Jobs parciales |
| **V4** | 40 conexiones que envían 1 byte y cierran | `TC-031.sh` | `ping` posterior en 57 ms (< 2000 ms) |
| **V5** | Mensaje parcial y cliente colgado | `TC-031.sh` | `REQUEST_TIMEOUT` y expulsión en 3.0 s; cupo recuperado |
| **V6** | Desconexión durante `list` (RST al enviar) | `TC-031.sh` | Servicio vivo; siguiente `ping` correcto |
| **V7** | 100 ciclos de conexión/desconexión | `TC-032.sh` | Descriptores 5 → 5; sin `jobs.json.tmp.*` |
| **V8** | Bitácora de desconexiones anómalas | `TC-033.sh` | 1 aviso para 5 desconexiones; sin ruido en cierres normales |
| **V9** | UX de `red job` | `TC-034.sh` | `PID: pendiente (en cola)` en 21 ms; duplicado detectado; Job `SUCCEEDED` |
| **V10** | `make -C src/hermes` | Manual | Compila con `-Wall -Wextra` sin advertencias |

Entorno: `HOME` temporal con `mktemp -d`, `network.json` que autoriza `127.0.0.1`, servidor en segundo
plano, cierre con `SIGTERM` y parada del scheduler por el descriptor de `scheduler.lock`. Linux/WSL
exclusivamente.

---

## 6. Lista de tareas y estado

**Regla de marcado:** una tarea pasa a `Hecho` únicamente con **evidencia observada** (comando ejecutado y
su resultado) anotada en la columna `Evidencia`. Marcarla sin evidencia es una violación del plan.

**Estado global: 16 / 16 tareas completadas.** Todas con evidencia observada el 2026-11-18.

| # | Tarea | Archivo / función | Cubre | Estado | Evidencia |
| --- | --- | --- | --- | --- | --- |
| **T-00** | Documento de desarrollo RF-22 con auditoría, matriz, diseño y plan | `DESARROLLO-RF-22.desconexion-cliente.md` | — | **Hecho** | Este archivo |
| **T-01** | Frontera de excepción por cliente | `server.cpp` · bucle de clientes | B1, AC1 | **Hecho** | `server.cpp:203-270`; `TC-030.sh` |
| **T-02** | `responder()` reinicia `enviado` | `server.cpp` · `responder()` | B4, AC2, AC4 | **Hecho** | `server.cpp:176-181` |
| **T-03** | Helper `despedida()` de un solo intento | `server.cpp` · usos en `recv()==0` y timeout | B2, B3, AC5, AC6 | **Hecho** | `server.cpp:186-194,232,252`; `TC-031.sh` |
| **T-04** | Cierre explícito `POLLERR`/`POLLNVAL`/`POLLHUP` con motivo | `server.cpp` · bucle de clientes | B7, AC1 | **Hecho** | `server.cpp:209-219` |
| **T-05** | `ip` como miembro de `Cliente` | `server.cpp` · `struct Cliente` y `accept` | B8, AC7 | **Hecho** | `server.cpp:155,304` |
| **T-06** | Bitácora de rechazo / desconexión anómala / error interno con ventana de 60 s | `server.cpp` · `avisoPermitido` y `registrar` | B8, AC7 | **Hecho** | `server.cpp:60-117,195-202,288-300`; `TC-033.sh` |
| **T-07** | Eliminar `esperarInicioJob(job)` de la rama `submit` | `remote.cpp` · `ejecutarOperacionRemota()` | B5, AC5 | **Hecho** | `remote.cpp:160-166`; `TC-034.sh` |
| **T-08** | Compilar sin advertencias nuevas | `make -C src/hermes` | V10 | **Hecho** | `g++ -Wall -Wextra` sin avisos |
| **T-09** | Pruebas de desconexión V1–V3 | `verif/scripts/TC-030.sh` + `verif/test-cases/TC-030.md` | AC1, AC2, AC3 | **Hecho** | `results_TC-030.md` [PASS] |
| **T-10** | Pruebas de cupo y bloqueo V4–V6 | `verif/scripts/TC-031.sh` + `verif/test-cases/TC-031.md` | AC5, AC6 | **Hecho** | `results_TC-031.md` [PASS] |
| **T-11** | Prueba de fuga de descriptores V7 | `verif/scripts/TC-032.sh` + `verif/test-cases/TC-032.md` | AC4 | **Hecho** | `results_TC-032.md` [PASS] |
| **T-12** | Verificación de bitácora V8 | `verif/scripts/TC-033.sh` + `verif/test-cases/TC-033.md` | AC7 | **Hecho** | `results_TC-033.md` [PASS] |
| **T-13** | Verificación de UX de `red job` V9 | `verif/scripts/TC-034.sh` + `verif/test-cases/TC-034.md` | Compatibilidad | **Hecho** | `results_TC-034.md` [PASS] |
| **T-14** | Fila RF-22 en la matriz de trazabilidad | `verif/verification-plan/traceability-matrix.md:27` | Trazabilidad | **Hecho** | Fila `RF-22` → `PASS` con TC-030…TC-034 |
| **T-15** | Actualizar deuda técnica y §5.5 de la línea base | `CONTEXTO-RED-ACTUAL.md` (D3, D4, §5.5) | Documentación | **Hecho** | D3 resuelto, D4 parcial, §5.5 reescrito |

### 6.1 Orden de ejecución

```
T-01 → T-02 → T-03 → T-04 → T-05 → T-06 → T-07 → T-08
     → T-09 → T-10 → T-11 → T-12 → T-13 → T-14 → T-15
```

Cada tarea de código se cierra con su propia comprobación; T-08 es el cierre de la fase de código y
T-09…T-13 la fase de verificación.

### 6.2 Criterio de cierre (cumplido)

RF-22 se declara implementado porque T-01…T-15 están en `Hecho` con evidencia, la matriz de §2 está en
`Cumple` para AC1–AC7 y V1–V10 se ejecutaron sin fallos en WSL.

Separatamente, el riesgo residual R1 (`flock` bloqueante sin plazo en `storage.cpp:43` y
`event_log.cpp:195`) requiere una decisión explícita por `CONTEXTO-RED-ACTUAL.md §7.9` y no forma parte
de este cambio.

---

## 7. Bitácora del documento

| Fecha | Cambio |
| --- | --- |
| 2026-11-18 | Creación. Auditoría de solo lectura, matriz de cumplimiento, diseño aprobado y lista de tareas. Ningún archivo de `src/` modificado; ninguna prueba creada. |
| 2026-11-18 | Implementación de los Cambios 1–6 (`server.cpp`, `remote.cpp`), compilación sin advertencias y cinco casos de prueba `TC-030`…`TC-034` en `PASS`. Matriz AC1–AC7 en `Cumple`; T-14 y T-15 actualizados. |
