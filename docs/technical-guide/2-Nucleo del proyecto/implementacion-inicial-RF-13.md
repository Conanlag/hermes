# Implementación del RF-13 — Recuperación después de reinicio

**Estado:** diseño aprobado; **Cortes 1, 1.1, 2 y 3 implementados y verificados**
**Fecha:** 2026-10-26 (actualizado tras la implementación del Corte 3)
**Alcance:** auditoría del RF-12, diseño del RF-13 y seguimiento de su implementación
**Requisitos no funcionales objetivo:** RNF-10, RNF-11, RNF-30, RNF-31

> Documento de registro. Las secciones 1 y 2 conservan el diseño original; el avance se marca con `[COMPLETADO]`, `[PARCIAL]` y `[PENDIENTE]`. La fase de diseño no modificó código fuente: la implementación de los Cortes 1, 1.1, 2 y 3 se registra en `docs/ai-usage/23-RF-13-recuperacion-tras-reinicio.md`.

**Leyenda:** `[COMPLETADO]` implementado y verificado · `[PARCIAL]` una parte implementada · `[PENDIENTE]` sin implementar.

---

## 1. Fase 1 — Auditoría del RF-12

### 1.1 Módulos revisados

`scheduler.cpp`, `storage.cpp`, `status.h/.cpp`, `process.cpp`, `job.cpp`, `cancel.cpp`, `main.cpp`, `clean.cpp`, `filter.cpp`, `validator.cpp`, `event_log.cpp`, `TC-016.sh`, `RF-06.status.md`, `RF-14`, `ADR-005`, `ADR-006`, `ADR-010` y la matriz de trazabilidad.

### 1.2 Veredicto

La base del RF-12 **es sólida en su idea central** (lectura-modificación-escritura bajo `flock` y reemplazo por `rename`), pero **no es suficiente para el RF-13**. Presenta tres tipos de problemas:

1. Un defecto **crítico que hoy impide que la recuperación llegue a ejecutarse**.
2. Un problema de **durabilidad** de la persistencia.
3. Varios problemas de **atomicidad lógica** del binomio Job ↔ proceso.

### 1.3 Hallazgos con evidencia

| # | Severidad | Hallazgo | Evidencia | RNF afectado |
|---|-----------|----------|-----------|--------------|
| F1 | **Crítico** | `scheduler.lock` se abre **sin `O_CLOEXEC`** y el demonio conserva el descriptor. Los Jobs hijos lo heredan al hacer `exec` y, como `flock` pertenece a la *open file description*, un huérfano mantiene el lock después de que el demonio muere. El siguiente `hermes` no obtiene el lock, **no arranca scheduler y la recuperación nunca corre**. | `scheduler.cpp:387-391` (`open` sin flag), `406-431` (lock heredado), `process.cpp:23-115` (spawn sin cierre de descriptores ajenos) | RNF-10, RNF-30 |
| F2 | **Crítico** | `recuperarTrabajosInterrumpidos()` reescribe `RUNNING → FAILED` sin comprobar si el PID vive ni terminarlo. Un proceso real queda huérfano y además se reporta un fallo que nunca ocurrió. | `scheduler.cpp:240-266` | RNF-30, RNF-31 |
| F3 | **Alto** | `reservarTrabajo()` persiste `RUNNING` con `pid = 0` **antes** de crear el proceso; el PID se guarda en una **segunda** transacción. Entre ambas el disco afirma una ejecución que aún no existe y, si el demonio cae en ese intervalo, el hijo puede existir sin PID persistido. | `scheduler.cpp:72-74` y `86-125` | RNF-11, RNF-31 |
| F4 | **Alto** | `guardarPid()` **ignora el resultado** de `modificarJobsSeguros`. Si la escritura falla (ENOSPC, lock), el proceso sigue corriendo sin PID persistido: huérfano no reconciliable. | `scheduler.cpp:89-111` | RNF-30 |
| F5 | **Alto** | Si `modificarJobsSeguros` lanza dentro de `reservarTrabajo`, el `catch` del trabajador llama a `registrarFallo()` con un `trabajo.id` ya rellenado, pudiendo convertir en `FAILED` un Job que en disco sigue `QUEUED`. | `scheduler.cpp:44-84`, `323-345` | RNF-31 |
| F6 | **Alto** | No existe identidad de proceso: solo `pid`. Un PID reciclado por el sistema puede hacer que la recuperación mate un proceso ajeno o que no mate el propio. | `scheduler.cpp:100`, `job.cpp:221` | RNF-10, RNF-30 |
| F7 | **Medio** | `guardarAtomico()` no hace `fsync` del temporal ni del directorio. El `rename` es atómico frente a *crash* del proceso, pero **no durable** frente a corte de energía (puede quedar `jobs.json` vacío o reaparecer el anterior). | `storage.cpp:70-97` | RNF-11 |
| F8 | **Medio** | No hay recuperación ante `jobs.json` corrupto ni archivo `.bak`; un `parse_error` deja el sistema inoperante. Los `.tmp.*` de ejecuciones muertas nunca se limpian. | `storage.cpp:53-68` | RNF-11 |
| F9 | **Medio** | `statusDesdeTexto()` mapea **cualquier estado desconocido a `QUEUED`**. Un `INTERRUPTED` leído por una ruta antigua se reportaría como pendiente. | `status.cpp:48` | RNF-31 |
| F10 | **Medio** | `filter` lee `jobs.json` directamente, sin `flock` ni el módulo `storage`, y duplica parseo y valores por defecto. | `filter.cpp:64-151` | RNF-11 (contrato) |
| F11 | **Medio** | El demonio no maneja `SIGTERM`/`SIGINT`: no existe cierre ordenado. Al matarlo, los hijos sobreviven y nadie los reclasifica. | `scheduler.cpp:370-381`, `461` | RNF-30 |
| F12 | **Bajo** | `hermes clean data` se ejecuta **antes** de iniciar scheduler, así que no dispara recuperación y queda bloqueado indefinidamente por filas `RUNNING` obsoletas. | `main.cpp:48-55`, `clean.cpp:21` | RNF-10, operación |
| F13 | **Bajo** | `tiempo_inicio` se sella en la reserva, no en el arranque real del proceso. | `scheduler.cpp:74` | RF-07 |

### 1.4 ¿Se guarda el estado completo y los metadatos de forma segura?

| Transición | ¿Atómica? | ¿Durable? | ¿Completa? |
|---|---|---|---|
| `QUEUED` | Sí (`rename`) | **No** (falta `fsync`) | Sí |
| `RUNNING` (reserva) | Sí | No | **No**: `pid=0`, `tiempo_inicio` prematuro, sin identidad |
| `RUNNING` + PID | **No**: segunda escritura, resultado ignorado | No | **No**: sin `starttime` ni `boot_id` |
| `SUCCEEDED` / `FAILED` / `CANCELED` | Sí | No | Sí (salvo `motivo` inexistente) |

**Conclusión:** el RF-12 cumple “nunca dejar un archivo a medio escribir” a nivel de *bytes*, pero no cumple RNF-11 en sentido estricto (durabilidad y estado lógico completo) y no entrega la información que el RF-13 necesita para decidir sin mentir.

**No hay que reescribir el modelo; hay que endurecer `storage` y cerrar F1–F6 antes de tocar la recuperación.**

---

## 2. Fase 2 — Diseño del RF-13

### 2.1 Nuevo estado `INTERRUPTED`

**Estado:** `[COMPLETADO]` — estado, fail-closed, filtro, ayuda, `motivo=apagado` (Corte 3) y actualización de `RF-06.status.md`.

Se añade al final del `enum class` (no altera los valores existentes):

```text
QUEUED → RUNNING → { SUCCEEDED, FAILED, CANCELED, INTERRUPTED }
```

Reglas:

- **`INTERRUPTED` es terminal.** Significa: “el servicio dejó de supervisar este Job; su resultado real es desconocido”. Nunca se reintenta automáticamente.
- **No es `FAILED`**: `FAILED` afirma que *el programa* terminó mal. `INTERRUPTED` afirma que *Hermes* dejó de observarlo. Esa es la distinción que exige el RNF-31.
- **No es `CANCELED`**, aunque el apagado lo provoque: `CANCELED` es una acción del usuario, no del ciclo de vida del servicio. Si existía `cancel_requested`, se conserva como evidencia y se refleja en `motivo`.
- Metadatos del estado:
  - `codigo_salida = -1`
  - `tiempo_terminacion` = instante de la recuperación o del cierre
  - `mensaje_error` legible para el usuario
  - campo máquina nuevo `motivo`, con el dominio:
    `apagado`, `caida`, `sin_pid`, `sin_identidad`, `pid_reutilizado`, `estado_desconocido`
- **Fail-closed:** un `status` desconocido deja de mapearse a `QUEUED`. Se trata como `INTERRUPTED` con `motivo = estado_desconocido`; así nunca se reporta como pendiente ni se reejecuta algo que no se entiende.
- **Superficie afectada:** `status.h/.cpp`, `validator.cpp:301-350` (filtro `INTERRUPTED`), `help.cpp:26`, `Job` / `obtenerJobPorId`, `RF-06.status.md`, matriz de trazabilidad y `TC-016`.

### 2.2 Endurecimiento previo de la persistencia (RNF-11)

**Estado:** `[COMPLETADO]` — metadatos aditivos, corrección de F4, escritura durable, `.bak`, limpieza de `.tmp`, fallback de lectura y guard F5 implementados en el Corte 2.

Antes de implementar la recuperación, `storage` debe garantizar:

1. **Escritura atómica y durable:** temporal único (`O_CREAT|O_EXCL`, nombre con PID + contador) → bucle de `write()` → **`fsync` del archivo** → `rename` → **`fsync` del directorio**.
2. **Última versión buena:** `link(jobs.json, jobs.json.bak)` antes del `rename` (atómico, sin ventana de archivo ausente). Lectura con cadena `jobs.json → .bak → error explícito`; nunca inventar un arreglo vacío en silencio.
3. **Limpieza:** al arrancar y bajo `jobs.lock`, borrar los `jobs.json.tmp.*` huérfanos.
4. **Metadatos nuevos por Job** (aditivos, compatibles con filas antiguas):
   - `pid_inicio` (*starttime* leído de `/proc`)
   - `boot_id`
   - `motivo`
   - `proceso_terminado`
   - `recuperado_en`
   - Sin envoltura versionada: `jobs.json` es un arreglo y migrarlo queda fuera de alcance.
5. **Corrección de F4/F5:** una escritura fallida del PID **obliga a terminar el hijo** y a no dejar `RUNNING`; `registrarFallo` solo actúa si la reserva devolvió `true` y la fila sigue `RUNNING`.

> El `Makefile` **no requiere cambios**: `SRC = $(shell find src -type f -name '*.cpp')` ya incorpora cualquier módulo nuevo.

Detalles de la implementación del Corte 2:

- **Nunca se pisa un respaldo válido con uno corrupto.** `jobs.json.bak` se refresca con `link(jobs.json, jobs.json.bak)` solo si `jobs.json` parsea como arreglo. Si el archivo principal está corrupto, la escritura sigue adelante y el respaldo anterior se conserva.
- **Auto-reparación en la lectura.** Cuando `leerSinBloqueo()` cae a `.bak`, reescribe `jobs.json` con el arreglo recuperado dentro de la misma transacción (el `jobs.lock` ya está tomado). Si la reparación falla, la lectura igual devuelve el respaldo.
- **Limpieza acotada.** `limpiarTemporalesDeJobs()` borra únicamente `jobs.json.tmp.*` bajo `jobs.lock`; un fallo al borrar un temporal concreto no aborta el arranque, pero un fallo al inspeccionar el directorio sí. El nombre temporal usa PID + contador atómico y se crea con `O_EXCL`.

### 2.3 Flujo exacto de arranque

**Estado:** `[COMPLETADO]` — pasos 1, 2, 3, 4 y 5 completados, incluida la reutilización de los pasos 1–4 en `clean data` (F12, Corte 3).

Decisión de diseño: **la recuperación ocurre en el proceso CLI que demuestra que no hay daemon vivo, antes del `fork`**, no dentro del hijo. Así es síncrona respecto al comando y no existe ventana en la que un `filter status RUNNING` observe filas mentirosas.

```text
CLI: hermes <comando>
 │
 ├─ 1. abrir scheduler.lock (O_CLOEXEC) + flock(EX|NB)
 │      ├─ ocupado  → hay daemon vivo → NO recuperar → continuar comando
 │      └─ obtenido → somos el único supervisor posible
 │
 ├─ 2. sonda de capacidad: /proc/self/stat + boot_id legibles
 │      └─ falla → log ERROR + abortar (no se puede garantizar RNF-10/30)
 │
 ├─ 3. limpiar jobs.json.tmp.* bajo jobs.lock
 │
 ├─ 4. recuperarTrabajosInterrumpidos() bajo jobs.lock (una sola RMW)
 │      ├─ clasificar cada fila (ver 2.4)
 │      ├─ verificar y terminar huérfanos verificados (ver 2.5)
 │      └─ persistir INTERRUPTED + evidencia
 │      └─ si falla → log ERROR + abortar (nunca arrancar sobre estado dudoso)
 │
 ├─ 5. fork()
 │      ├─ padre: cierra descriptor, retorna al comando (job/cancel/filter)
 │      └─ hijo: setsid, stdio→/dev/null, handlers de señal, workers
```

Reutilización (F12, Corte 3): los pasos 1–4 se ejecutan también desde `clean data`. El comando toma `scheduler.lock` con RAII (`BloqueoScheduler`); si el lock está libre, ejecuta `verificarCapacidadDeRecuperacion()`, `limpiarTemporalesDeJobs()` y `recuperarTrabajosInterrumpidos()` antes de decidir si hay trabajos activos. Así `clean data` no se bloquea para siempre por una fila `RUNNING` obsoleta y nunca arranca el daemon: si el lock está ocupado, hay un daemon vivo y la operación se rechaza como antes. `verificarCapacidadDeRecuperacion()` vive en `recovery.cpp`/`recovery.h` y se invoca calificada (`hermes::`) desde `clean.cpp` y `scheduler.cpp`.

### 2.4 Clasificación en la recuperación (RNF-31)

**Estado:** `[COMPLETADO]` — las filas de la tabla están implementadas; `sin_pid` tiene prueba dedicada en TC-022 (i).

| Estado persistido | Acción | Resultado |
|---|---|---|
| `QUEUED` | ninguna; lo tomarán los workers | sigue `QUEUED` (pendiente real) |
| `SUCCEEDED` / `FAILED` / `CANCELED` / `INTERRUPTED` | ninguna | intacto (terminado) |
| `RUNNING`, `pid ≤ 0` | no hay PID verificable; no se mata nada | `INTERRUPTED`, `motivo=sin_pid`, `proceso_terminado=false` |
| `RUNNING`, `pid > 0`, identidad **coincide** | verificar y terminar (2.5) | `INTERRUPTED`, `motivo=caida`, `proceso_terminado=true/false` |
| `RUNNING`, `pid > 0`, identidad **no coincide** (el PID vive, pero es ajeno) | **no enviar señal** | `INTERRUPTED`, `motivo=pid_reutilizado`, `proceso_terminado=true` |
| `RUNNING`, `pid > 0`, líder ausente, `sid` guardado y grupo `-pgid` vivo con ese `sid` | terminar el grupo completo (2.5) | `INTERRUPTED`, `motivo=caida`, `proceso_terminado=true/false` |
| `RUNNING`, `pid > 0`, líder ausente, sin `sid` o sin miembros del grupo | no hay grupo propio verificable; no se señaliza | `INTERRUPTED`, `motivo=caida`; fila antigua: `proceso_terminado=true` (limitación de compatibilidad) |
| `RUNNING`, `pid > 0`, líder ausente y `/proc` no permite verificar el grupo | **no enviar señal**; registrar ERROR | `INTERRUPTED`, `motivo=caida`, `proceso_terminado=false` |
| `RUNNING`, sin `pid_inicio` / `boot_id` (fila antigua) | no verificable → no matar | `INTERRUPTED`, `motivo=sin_identidad`, `proceso_terminado=false` |
| `status` desconocido | no ejecutar, no mostrar como pendiente | `INTERRUPTED`, `motivo=estado_desconocido`, `proceso_terminado=false` |

La recuperación es **idempotente** y **no muta antes del efecto**: primero actúa sobre el proceso, después persiste. Si el proceso muere entre ambos pasos, el siguiente arranque repite la clasificación sin daño.

### 2.5 Manejo de huérfanos (RNF-30)

**Estado:** `[COMPLETADO]` — verificación de identidad, protocolo de terminación, grupo sin líder (Corte 1.1), prevención en origen, cierre ordenado y registro en memoria (Corte 3).

#### Verificación de identidad

Un proceso es “nuestro” solo si se cumplen las tres condiciones:

1. `boot_id` actual == `boot_id` guardado (descarta reutilización tras reinicio).
2. `starttime` (campo 22 de `/proc/<pid>/stat`) == `pid_inicio` guardado (descarta reutilización dentro del mismo arranque).
3. `pgrp` del proceso == PID guardado (confirma que el grupo que se va a señalar es el suyo).

Detalle de implementación: en `/proc/<pid>/stat` el campo `comm` puede contener espacios y paréntesis; se parsea tomando la subcadena **posterior al último `)`**, nunca por *split* ingenuo.

El `sid` no sustituye estas tres condiciones: es el identificador adicional que permite reconocer a los miembros del grupo cuando el líder ya no existe (Corte 1.1).

#### Protocolo de terminación (por lote, no por Job)

```text
para cada huérfano verificado: kill(-pgid, SIGTERM)
esperar UNA ventana de gracia (5 s, igual que escalarCancelacionProceso)
para cada uno que siga vivo:   kill(-pgid, SIGKILL)
esperar desaparición (estado 'Z' cuenta como muerto; init lo recoge)
persistir INTERRUPTED + { motivo, proceso_terminado, pid, pid_inicio }
```

Se paraleliza la espera para que N huérfanos cuesten ~5 s y no N×5 s. Un `proceso_terminado=false` se registra como **ERROR** en la bitácora: RNF-10 se mantiene (nunca `RUNNING`) y RNF-30 queda como excepción explícita y auditable, no silenciosa.

#### Grupo sin líder (Corte 1.1)

`PDEATHSIG` solo alcanza al hijo directo. Si el líder muere y deja descendientes en su grupo, la comprobación por PID no basta: el líder ausente haría creer que no queda nada. Por eso `guardarPid` persiste también el `sid` de la sesión privada del demonio (campo aditivo, compatible con filas antiguas).

Cuando el líder ya no existe, `recovery` consulta `estadoGrupoProceso(pgid, sid)`:

- recorre `/proc`, exige `pgrp == pgid` y `session == sid`, e ignora zombies;
- `Vivo` → señala el grupo completo con TERM→5 s→KILL;
- `Inexistente` → no hay nada que terminar;
- `NoVerificable` (por ejemplo, `/proc` ilegible) → **no señaliza** y deja `proceso_terminado=false` con ERROR.

La misma comprobación de grupo se usa durante la terminación de un líder verificado: el líder puede morir antes que sus nietos y el bucle no debe confundir “líder muerto” con “grupo terminado”. Las filas antiguas sin `sid` no se pueden verificar de esta forma y conservan el comportamiento conservador: `caida`/`proceso_terminado=true` sin señalizar el grupo.

#### Prevención en origen (imprescindible, no opcional)

- **`O_CLOEXEC`** en `scheduler.lock`, `jobs.lock` y cualquier descriptor del demonio (corrige F1; sin esto todo lo anterior es inalcanzable). Además, el hijo de `iniciarProceso` marca `FD_CLOEXEC` en los descriptores 3–1023 antes del `exec`: el demonio es multihilo y otro worker puede tener `jobs.json` abierto en el momento del `fork`. El rango cubre los locks y `jobs.json`; un descriptor por encima de 1023 no se cubre y obligaría a ampliar el rango si se eleva `RLIMIT_NOFILE`.
- El hijo se crea en **su propio grupo de procesos** (`setpgid(0,0)`) para poder señalar al grupo completo, incluidos nietos.
- **`prctl(PR_SET_PDEATHSIG, SIGKILL)`** en el hijo antes del `exec`, con relectura inmediata de `getppid()` para cerrar la carrera padre-muerto-antes-de-`prctl`. Esto cierra el agujero de F3 (`pid=0`): aunque el demonio muera entre el spawn y el guardado del PID, el hijo muere con él.
  - Consecuencia: `posix_spawnp` no permite fijar `PDEATHSIG`, por lo que `iniciarProceso` migra a `fork` + `setpgid` + `prctl` + `dup2` + `execvp`, reportando el `errno` de `exec` por un pipe auxiliar (conserva el mapeo ENOENT→127 y cumple lo que ya declara el ADR-010).
- **Cierre ordenado:** handlers de `SIGTERM`/`SIGINT` que solo fijan un flag (`sig_atomic_t`); un coordinador de apagado señala los grupos del registro en memoria, los workers hacen `waitpid` y salen, y **un único escritor** marca `INTERRUPTED` con `motivo=apagado` para los Jobs que seguían activos. Si el demonio recibe `SIGKILL`, no hay cierre ordenado: `PDEATHSIG` mata a los hijos y la recuperación del siguiente arranque reconcilia.
- **Rechazado por ahora:** cgroups v2 (`cgroup.kill`) sería la garantía absoluta frente a *daemonización* de los jobs, pero exige permisos y no aporta frente a los casos que cubre el grupo de procesos. Queda documentado como endurecimiento opcional.

#### Registro en memoria

`mutexActivos` + `map<unsigned int, TrabajoActivo>` + `condition_variable cvActivos`. Cada entrada guarda `pid`, `pgid`, `sid`, `grupoVerificado`, `interrumpido` y `procesoTerminado`; no se persiste.

La ventana reserva→`spawn`→registro la protege `mutexArranque`, que el worker toma antes de comprobar `apagadoSolicitado`. El coordinador toma ese mismo mutex para cerrar la puerta: cuando lo obtiene, ningún worker puede estar a mitad de arranque y los que despierten después ven el flag y no inician otro Job. `SA_RESTART` en `sigaction` evita que el `EINTR` del apagado haga fallar `read()`/`waitpid()`.

El handler de `SIGTERM`/`SIGINT` solo escribe `volatile sig_atomic_t banderaApagado`; no toma locks ni hace I/O. El coordinador (hilo único) hace el resto: marca `interrumpido` en el registro, señaliza los grupos, espera hasta 5 s a que los workers desregistren, y solo él persiste `INTERRUPTED`/`motivo=apagado` para las filas que siguen `RUNNING`. Un worker que desregistra con `interrumpido=true` no llama `finalizarTrabajo`, para no competir por la escritura del estado final. Las filas terminales nunca se pisan: la persistencia de apagado exige `status == "RUNNING"`.

> **Hallazgo posterior (Corte 1.1, cerrado).** Si el líder muere por `PDEATHSIG` y deja descendientes en su grupo, la recuperación anterior veía el PID ausente, marcaba `proceso_terminado=true` y **no señalaba el grupo**, porque la identidad se verificaba solo sobre el líder. Se reprodujo el 2026-10-26 con `hermes job sh -c 'sleep 300 & wait'`: tras `SIGKILL` al demonio, el `sleep` sobrevivía y la fila quedaba `INTERRUPTED`/`caida`/`proceso_terminado=true`. El Corte 1.1 persistió el `sid`, añadió `estadoGrupoProceso(pgid, sid)` y el caso (h) de TC-022; la fila ya refleja la terminación real y no queda ningún miembro del grupo.

### 2.6 Archivos, pruebas y documentación

| Archivo | Cambio | Estado |
|---|---|---|
| `include/status.h`, `src/status/status.cpp` | `INTERRUPTED`; `statusDesdeTexto` deja de asumir `QUEUED` | `[COMPLETADO]` |
| `include/storage.h`, `src/storage/storage.cpp` | `fsync` de archivo y directorio, `.bak`, limpieza de `.tmp`, fallback de lectura con auto-reparación | `[COMPLETADO]` — temporal único con `O_EXCL`, `fsync` de archivo y directorio, `.bak` con `link`, `limpiarTemporalesDeJobs()` y cadena `jobs.json → .bak → error` |
| `include/process.h`, `src/process/process.cpp` | identidad (`boot_id` + `starttime` + `sid`), `fork/exec` con `setpgid` + `PDEATHSIG`, terminación de grupo y cierre de descriptores heredados | `[COMPLETADO]` |
| `include/recovery.h`, `src/recovery/recovery.cpp` | **módulo nuevo**: clasificación, terminación de huérfanos, grupo sin líder por `sid`, persistencia de `INTERRUPTED` | `[COMPLETADO]` |
| `include/scheduler.h`, `src/scheduler/scheduler.cpp` | recuperación antes del `fork`, `O_CLOEXEC`, persistencia de `sid`, limpieza de `.tmp`, guard F5, registro de activos, handlers, apagado | `[COMPLETADO]` — recuperación, `O_CLOEXEC`, `sid`, limpieza, guard F5, registro de activos y cierre ordenado |
| `src/job/job.cpp`, `src/validator/validator.cpp`, `src/help/help.cpp` | metadatos nuevos, filtro/estado `INTERRUPTED`, ayuda | `[COMPLETADO]` — `job.cpp` no requirió cambios; los metadatos los escribe `recovery` |
| `src/clean/clean.cpp` | recuperación previa si no hay daemon | `[COMPLETADO]` — `BloqueoScheduler` + sonda + limpieza de `.tmp` + recuperación antes de decidir si hay trabajos activos (F12) |
| `verif/scripts/TC-022.sh` (nuevo) | RF-13 | `[COMPLETADO]` — (a)–(i) y auditoría F1 |
| `verif/scripts/TC-016.sh` | pasa de esperar `FAILED` a `INTERRUPTED` | `[COMPLETADO]` |
| `docs/.../RF-13*.md`, `RF-06.status.md`, `ADR-005`, `ADR-006`, `verif/verification-plan/traceability-matrix.md` | trazabilidad RNF-10/11/30/31 | `[COMPLETADO]` — este documento, AI-usage 23, `RF-06.status.md`, ADR-005/006 y la matriz actualizados |

#### Pruebas mínimas de TC-022

- `[COMPLETADO]` (a) `SIGTERM` al demonio con un Job activo: el coordinador termina el grupo y persiste `INTERRUPTED` con `motivo=apagado`, `proceso_terminado=true`, `codigo_salida=-1` y mensaje de apagado; el hijo no sobrevive. La prueba además dispara la recuperación del siguiente arranque y verifica que no reescribe el cierre ordenado (idempotencia).
- `[COMPLETADO]` (b) `SIGKILL` al demonio con un job `sleep` → el hijo muere por `PDEATHSIG` y tras reiniciar no queda ningún `RUNNING`.
- `[COMPLETADO]` (c) Fila `RUNNING` fabricada con el PID vivo de un proceso ajeno (por ejemplo, el shell de la prueba) → **no se mata** y queda `INTERRUPTED` con `pid_reutilizado`.
- `[COMPLETADO]` (d) `QUEUED` sigue pendiente y se ejecuta.
- `[COMPLETADO]` (e) Estados terminales intactos.
- `[COMPLETADO]` (f) `jobs.json` sigue parseando tras `kill -9` durante escrituras, `jobs.json.bak` existe y parsea, el arranque elimina los `jobs.json.tmp.*` huérfanos y, con `jobs.json` corrupto, la lectura cae al respaldo y repara el archivo principal.
- `[COMPLETADO]` (g) `clean data` tras una caída: con una fila `RUNNING` obsoleta, el comando recupera antes de borrar, deja el historial vacío y no arranca el scheduler.
- `[COMPLETADO]` (h) Job con nietos (`sh -c 'sleep 300 & wait'`): el líder muere por `PDEATHSIG`, el nieto sobrevive, recovery termina el grupo sin líder usando el `sid` persistido y `proceso_terminado` refleja la realidad. La corrida también audita que el Job no herede descriptores del demonio (F1).
- `[COMPLETADO]` (i) Caso adicional para el motivo `sin_pid`, que el diseño no numera: una fila `RUNNING` con `pid=0` queda `INTERRUPTED` con `motivo=sin_pid`, `proceso_terminado=false` y `codigo_salida=-1`; el mensaje explica que no había un PID verificable y no se afirma una terminación que no ocurrió.

### 2.7 Orden de implementación recomendado

1. `[COMPLETADO]` `storage` durable + `.bak` + limpieza (RNF-11), sin cambiar comportamiento visible. **Corte 2.**
2. `[COMPLETADO]` `status` / `validator` / `help` / TC-016 y docs (`RF-06.status.md`).
3. `[COMPLETADO]` `process`: identidad, grupo y `PDEATHSIG`; `O_CLOEXEC` y corrección de F1/F4.
4. `[COMPLETADO]` `recovery` + integración en arranque, incluido el grupo sin líder del Corte 1.1 y `clean data`.
5. `[COMPLETADO]` Apagado ordenado y registro de activos. **Corte 3.**
6. `[COMPLETADO]` TC-022 (a)–(i) y auditoría F1; documentación actualizada.

### 2.8 Riesgos asumidos

- El paso 3 toca el lanzamiento de procesos y es el de mayor riesgo de regresión; se mitiga con la suite existente TC-003, TC-005, TC-008, TC-019 y TC-021.
- La espera de gracia añade hasta ~5 s al primer comando tras una caída, y solo si había huérfanos.
- El paso 1 modifica el formato de escritura, pero no el esquema de lectura: las filas antiguas siguen siendo válidas.
- **Nietos tras `PDEATHSIG`:** cerrado en el Corte 1.1 para filas con `sid`: si el líder muere y queda un grupo con la misma sesión, se termina y `proceso_terminado` refleja el resultado. Limitaciones: las filas antiguas sin `sid` conservan el comportamiento conservador y un grupo no verificable deja `proceso_terminado=false` con ERROR.
- **Descriptores heredados:** el demonio es multihilo; un worker puede bifurcar mientras otro tiene `jobs.json` abierto. El hijo marca `FD_CLOEXEC` en los descriptores 3–1023 antes de `exec` para que ningún Job herede el archivo ni el lock (F1). El rango cubre los descriptores del demonio; uno por encima de 1023 no se cubre y obligaría a ampliar el rango si se eleva `RLIMIT_NOFILE`.
- **Costo del respaldo:** `jobs.json.bak` es un enlace duro en el mismo directorio, así que no duplica los datos ni puede fallar por cruzar sistemas de archivos. Cada escritura valida `jobs.json` una vez más antes de refrescarlo; el archivo es pequeño y las escrituras son poco frecuentes frente a la ejecución de los Jobs.
- **Ventana mínima del respaldo:** el refresco hace `unlink` y luego `link`; si el proceso muere entre ambos, `jobs.json` sigue intacto y el siguiente arranque vuelve a crear el respaldo. No existe un instante sin archivo principal.

---

## 3. Trazabilidad requisito → mecanismo → verificación

| Requisito | Mecanismo de diseño | Verificación |
|---|---|---|
| RNF-10 | Recuperación síncrona antes del `fork` bajo `scheduler.lock`; `INTERRUPTED` terminal; ningún `RUNNING` sobrevive al arranque | TC-022 (b), (c), (h) + `filter status RUNNING` vacío |
| RNF-11 | `fsync` de archivo y directorio, `.bak` con `link`, `.tmp` con `O_EXCL`, limpieza al arrancar, fallback de lectura con auto-reparación | TC-022 (f) y (g) |
| RNF-30 | Identidad `boot_id`+`starttime`+`pgrp`, `sid` para grupos sin líder, terminación de grupo TERM→KILL, `PDEATHSIG`, cierre ordenado | TC-022 (a), (b), (c), (h) |
| RNF-31 | `INTERRUPTED` con `motivo`; clasificación explícita de `QUEUED`/terminales/`RUNNING`; fail-closed ante estado desconocido | TC-022 (d), (e), (i) + TC-016 actualizado |

**Estado de la verificación (2026-10-26):** RNF-10 cubierto por TC-022 (b), (c) y (h); RNF-11 cubierto por TC-022 (f) y (g) —durabilidad, respaldo, limpieza, fallback y `clean data` tras caída—; RNF-30 cubierto por (a), (b), (c) y (h) —incluido el cierre ordenado—; RNF-31 cubierto por (d), (e), (i) y TC-016.

---

## 4. Supuestos sujetos a aprobación

1. `PDEATHSIG = SIGKILL` (prioriza RNF-30 sobre el *cleanup* del job).
2. Ventana de gracia de 5 s, alineada con `escalarCancelacionProceso`.
3. `INTERRUPTED` siempre para filas `RUNNING` durante la recuperación (nunca `CANCELED`), conservando `cancel_requested` como evidencia.

## 5. Estado de implementación y siguiente acción

**Cortes 1 y 1.1 — implementados y verificados.** Evidencia: `docs/ai-usage/23-RF-13-recuperacion-tras-reinicio.md` y `verif/results/` (TC-003, TC-005, TC-008, TC-016, TC-019, TC-021 y TC-022). TC-022 pasa (a)–(e), (h) y la auditoría F1; TC-016/019/021/005/008 pasan en serie. TC-003 conserva su único fallo previo: el Paso 5 no observa `QUEUED` porque el Job pasa a `RUNNING` (desfase del Hito 1, ajeno a este corte).

**Corte 1.1 — cierre del hueco de nietos.** `guardarPid` persiste el `sid` de la sesión privada del demonio; `estadoGrupoProceso(pgid, sid)` reconoce a los miembros del grupo sin líder; `recovery` termina el grupo con TERM→5 s→KILL y calcula `proceso_terminado` real. TC-022 (h) reproduce el hueco con `hermes job sh -c 'sleep 300 & wait'` y verifica que no queda ningún miembro. Durante la prueba se descubrió una fuga residual de F1: el demonio multihilo podía bifurcar mientras otro worker tenía `jobs.json` abierto, y el hijo heredaba el descriptor; el hijo ahora marca `FD_CLOEXEC` en los descriptores 3–1023 antes de `exec` (el rango cubre los locks y `jobs.json`; por encima de 1023 queda la limitación documentada en TC-022).

**Corte 2 — persistencia durable y guard F5.** `storage.cpp` escribe con temporal único (`O_CREAT|O_EXCL|O_CLOEXEC`, PID + contador atómico), bucle de `write()`, `fsync` del archivo, `rename` y `fsync` del directorio. Antes del `rename` refresca `jobs.json.bak` con `link()` —atómico y sin copia de bytes—, y **solo si `jobs.json` parsea como arreglo**, para no destruir el único respaldo bueno con un archivo corrupto. La lectura prueba `jobs.json → .bak → error explícito`; si cae al respaldo, reescribe `jobs.json` en la misma transacción (auto-reparación) y deja un `WARN` en el log de eventos. `limpiarTemporalesDeJobs()` borra `jobs.json.tmp.*` al arrancar bajo `jobs.lock`, en el paso 3 del flujo. F5 se corrige en dos capas: `reservarTrabajo` no publica `trabajo.id` hasta que la reserva se persistió, y `registrarFallo` solo modifica una fila que sigue `RUNNING`.

Evidencia del Corte 2: `make -C src/hermes` compila limpio con `-Wall -Wextra`; TC-022 pasa (a)–(f), (h), (i) y la auditoría F1; TC-016, TC-019, TC-021, TC-005 y TC-008 pasan en serie. TC-003 conserva únicamente su fallo previo del Paso 5 (`QUEUED` observado como `RUNNING`, desfase del Hito 1 ajeno a este corte). No se modificó el `Makefile` ni se hizo commit.

**Corte 3 — cierre ordenado, registro de activos y `clean data`.** Los handlers de `SIGTERM`/`SIGINT` solo escriben `volatile sig_atomic_t banderaApagado`; un coordinador (hilo único) toma `mutexArranque` para cerrar la puerta de arranque, marca `interrumpido` en el registro, señaliza los grupos con una ventana TERM de 5 s y luego KILL, espera hasta 5 s a que los workers desregistren y persiste `INTERRUPTED` con `motivo=apagado`. Solo señaliza el grupo si `identidad.pgrp == pid`; si no, usa `kill(pid, sig)`. El worker desregistra tras `waitpid` y, si el coordinador lo marcó interrumpido, no llama `finalizarTrabajo`; el coordinador es el único escritor del estado final y exige `status == "RUNNING"` para no pisar filas terminales. `clean data` toma `scheduler.lock` con RAII y, si no hay daemon, ejecuta sonda + limpieza de `.tmp` + recuperación antes de decidir si hay trabajos activos, sin arrancar el scheduler. `verificarCapacidadDeRecuperacion()` se movió a `recovery.cpp`/`recovery.h`.

Evidencia del Corte 3: `make -C src/hermes` compila limpio con `-Wall -Wextra`; TC-022 pasa (a)–(i) y la auditoría F1 —incluidos `motivo=apagado`, idempotencia del cierre y `clean data` tras caída—; TC-016, TC-019, TC-021, TC-005 y TC-008 pasan en serie. TC-003 conserva únicamente su fallo previo del Paso 5 (`QUEUED` observado como `RUNNING`, desfase del Hito 1 ajeno a este corte). No se modificó el `Makefile` ni se hizo commit.

**Trazabilidad transversal:** `RF-06.status.md` documenta el sexto estado, el campo `motivo` y las transiciones de apagado/caída; `ADR-005` registra la persistencia durable y el respaldo; `ADR-006` registra `PDEATHSIG`, el grupo de procesos y el cierre ordenado; `verif/verification-plan/traceability-matrix.md` registra RF-13, RNF-10, RNF-11, RNF-30 y RNF-31 como PASS con TC-022 y TC-016.

**Siguiente acción:** ninguna dentro del RF-13. Criterio de cierre cumplido: ningún `RUNNING` sobrevive a un arranque; ningún huérfano directo ni descendiente del grupo queda vivo; `proceso_terminado` refleja la realidad; `jobs.json` sobrevive a `kill -9` y siempre parsea. Queda pendiente la autorización del usuario para commitear.
