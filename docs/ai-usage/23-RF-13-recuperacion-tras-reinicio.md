# Uso de inteligencia artificial

# 23. RF-13 Recuperación tras reinicio — Cortes 1, 1.1, 2 y 3

## Objetivo

Implementar el "Corte 1 — desbloquear y no mentir" del documento `docs/technical-guide/2-Nucleo del proyecto/implementacion-RF-13.md`: hacer que Hermes deje de afirmar estados que no puede sostener después de un reinicio o de la caída del demonio.

El alcance acordado fue: auditoría de `O_CLOEXEC` (F1), estado terminal `INTERRUPTED` con clasificación fail-closed, identidad de proceso (`boot_id` + starttime de `/proc/<pid>/stat` + `pgrp`), lanzamiento con `fork`/`setpgid`/`PR_SET_PDEATHSIG`, módulo nuevo `recovery`, recuperación síncrona antes del `fork` bajo `scheduler.lock`, actualización de TC-016 y creación de TC-022 con los casos (a)–(e). Quedaron fuera, por definición del corte: `fsync`/`.bak`/limpieza de `.tmp` (Corte 2), handlers de apagado y `motivo=apagado` (Corte 3) y la recuperación previa en `clean data` (F12).

Restricciones: no cambiar el esquema de `jobs.json` salvo campos aditivos, no tocar el `Makefile`, conservar identificadores en español y no hacer commit sin autorización.

---

## Prompt 1

```text
[Alcance acordado en la sesión; se reconstruye porque el texto literal no se conservó.]

Implementar el "Corte 1 — desbloquear y no mentir" de docs/technical-guide/2-Nucleo del proyecto/implementacion-RF-13.md:

1. Auditar y corregir O_CLOEXEC (F1): scheduler.lock, jobs.lock y descriptores del demonio que los Jobs no deben heredar.
2. Agregar INTERRUPTED terminal en status, validator y help; statusDesdeTexto no debe asumir QUEUED ante un valor desconocido.
3. Identidad de proceso: boot_id, starttime (/proc/<pid>/stat) y pgrp; setpgid(0,0), PR_SET_PDEATHSIG=SIGKILL con relectura de getppid; terminación de grupo TERM -> 5 s -> KILL.
4. Crear el módulo recovery (.h/.cpp) con la clasificación de la tabla 2.4.
5. Integrar la recuperación en el scheduler antes del fork y bajo scheduler.lock.
6. Actualizar TC-016 de FAILED a INTERRUPTED.
7. Crear verif/scripts/TC-022.sh con los casos (a)-(e).

No implementar fsync/.bak/.tmp (Corte 2), ni handlers de apagado (Corte 3), ni clean data (F12). Compilar con make -C src/hermes y ejecutar cada script en serie en WSL. Entregar reporte con archivos tocados, justificación, resultados observados y cobertura de la tabla 2.4. No hacer commit.
```

---

## Resultado 1

La IA leyó el documento de RF-13, auditó los módulos existentes y propuso el siguiente conjunto de cambios, que después se implementó:

- **`status`:** se agregó `INTERRUPTED` al final del `enum class` para no alterar los valores existentes; `statusDesdeTexto` pasó de mapear cualquier valor desconocido a `QUEUED` a devolver `INTERRUPTED` (fail-closed). Se agregó `statusEsTextoConocido` para que la recuperación distinga "texto desconocido" de "RUNNING".
- **`process`:** se agregó `IdentidadProceso` (`bootId`, `pidInicio`, `pgrp`), lectura de `/proc/<pid>/stat` tomando la subcadena posterior al último `)`, `identidadCoincide` con las tres condiciones, `procesoVivo` (zombie `Z`/`X` cuenta como muerto), `senalizarGrupoProceso` y `terminarGrupoProceso`. `iniciarProceso` migró de `posix_spawnp` a `fork` + `setpgid(0,0)` + `prctl(PR_SET_PDEATHSIG, SIGKILL)` + `getppid()` + `dup2` + `execvp`, reportando el `errno` de `exec` por un pipe auxiliar `O_CLOEXEC`.
- **`recovery` (nuevo):** clasificación de la tabla 2.4, terminación de huérfanos por lote con una sola ventana de gracia de 5 s, persistencia de `INTERRUPTED` con `motivo`, `proceso_terminado` y `recuperado_en`, y ERROR explícito solo para huérfanos verificados que resistieron la terminación.
- **`scheduler`:** `O_CLOEXEC` al abrir `scheduler.lock`; sonda de capacidad (`/proc/self/stat` + `boot_id`); recuperación antes del `fork` y solo si se obtuvo el lock (nunca con daemon vivo); `guardarPid` devuelve `bool` y persiste `boot_id`/`pid_inicio`; si no logra persistir, termina el proceso recién creado.
- **`storage` y `event_log`:** `O_CLOEXEC` en `jobs.lock` y en el descriptor de la bitácora.
- **`validator` y `help`:** `INTERRUPTED` aceptado por el filtro y documentado en la ayuda.
- **Pruebas:** TC-016 actualizado a `INTERRUPTED`/`motivo=sin_identidad`; TC-022 nuevo con (a)–(e) y auditoría F1.

La compilación con `make -C src/hermes` terminó limpia con `-Wall -Wextra`. La primera corrida completa de la suite produjo: TC-003 FAIL por el Paso 5 (comportamiento previo del Hito 1), TC-005/008/016/019/021/022 PASS.

---

## Prompt 2

```text
arregla tu el .sh del TC-003
```

---

## Resultado 2

La IA reescribió `verif/scripts/TC-003.sh` para que la prueba dejara de depender del symlink `src/hermes/data` y de los datos reales del usuario:

- `HOME` temporal con `mktemp -d` y lectura de `$HOME/.local/share/hermes/data/jobs.json`.
- Archivos temporales de la prueba dentro de ese directorio, no en `/tmp`.
- `trap cleanup EXIT` que localiza el demonio por el `scheduler.lock` temporal, lo termina con `SIGTERM` y borra el directorio.
- Veredicto derivado de un contador `FALLOS` en lugar de un `[FAIL]` hardcodeado.

Durante la verificación se detectó y corrigió un error de precedencia de bash introducido por la IA: `if ! make clean && make` se evalúa como `(! make clean) && make`, por lo que `make clean` borraba el binario y `make` nunca se ejecutaba. Se separó en `make clean` y `if ! make`.

También se restauró `src/hermes/data` con `git checkout --`. Dato relevante: el repositorio lo registra como symlink (modo `120000`, destino `/home/leo/...`), pero este checkout tiene `core.symlinks=false` y lo materializa como archivo de texto. Al aislar TC-003, la prueba ya no depende de esa rareza del entorno.

Resultado observado: Pasos 1–4 y 6 OK; Paso 5 FAIL porque el Job pasa a `RUNNING` antes de poder observarse `QUEUED`. Se decidió **no** ablandar la expectativa: el fallo es el desfase de alcance del Hito 1, no un defecto del script.

---

## Prompt 3

```text
muy bien ahora usa el skill ".atl\crear_ai_usage.md" para registrar TODO lo que hiciste para la futura implementacion del "docs\technical-guide\2-Nucleo del proyecto\implementacion-RF-13.md"
```

---

## Resultado 3

Se generó este registro con base en la plantilla de `.atl/crear_ai_usage.md`, incluyendo decisiones, errores detectados, evidencia de las pruebas y pendientes para los Cortes 2 y 3.

---

# Modificaciones

**Estado de la resolución:** Modificado por deficiencia.

**Revisión realizada:**

La implementación compiló limpia, pero la verificación en WSL expuso deficiencias reales que obligaron a corregir el código generado por la IA:

1. **Corrupción de `jobs.json` en las pruebas.** TC-016 y TC-022 reescribían el JSON con `JSON::PP` sin `->utf8`. El mensaje de recuperación contiene "caída" y el reencodeo producía el byte crudo `0xED`, invalidando el archivo. Se corrigió a `JSON::PP->new->utf8->canonical->pretty->encode`.
2. **Terminación de grupo sin identidad verificada en F4.** La primera versión de `guardarPid` señalaba el grupo del proceso recién creado sin comprobar que `pgrp == pid`. Se endureció: el grupo solo se señala si la identidad leída lo confirma; en caso contrario se mata únicamente el PID exacto.
3. **Dependencia del entorno en TC-003.** La IA primero "reparó" el symlink `src/hermes/data` apuntándolo a `/home/user`. Era un parche local que no debía commitearse; el desarrollador exigió la solución correcta (aislar la prueba con `HOME` temporal), que además eliminó la dependencia del symlink.
4. **Error de precedencia en bash.** El nuevo TC-003 usaba `if ! make clean && make`, que nunca recompilaba. Se detectó al ejecutar la prueba (no existía `./hermes`) y se corrigió.
5. **TC-016 desactualizado.** Esperaba `FAILED` para una fila `RUNNING` no verificable; el comportamiento correcto del RF-13 es `INTERRUPTED` con `motivo=sin_identidad`.

Lo que estuvo bien desde el inicio: la clasificación de la tabla 2.4, la recuperación antes del `fork` bajo el lock, la identidad triple antes de señalar y la prevención con `PDEATHSIG`.

**Cambios aplicados:**

- `src/hermes/include/status.h` y `src/hermes/src/status/status.cpp`: `INTERRUPTED`, `statusEsTextoConocido`, `statusDesdeTexto` fail-closed.
- `src/hermes/include/process.h` y `src/hermes/src/process/process.cpp`: identidad, `fork`/`setpgid`/`PDEATHSIG`, pipes `O_CLOEXEC`, terminación de grupo.
- `src/hermes/include/recovery.h` y `src/hermes/src/recovery/recovery.cpp` (nuevos): clasificación, terminación de huérfanos y persistencia.
- `src/hermes/src/scheduler/scheduler.cpp`: lock con `O_CLOEXEC`, sonda de capacidad, recuperación antes del `fork`, `guardarPid` con identidad y manejo F4.
- `src/hermes/src/storage/storage.cpp` y `src/hermes/src/event_log.cpp`: `O_CLOEXEC`.
- `src/hermes/src/validator/validator.cpp` y `src/hermes/src/help/help.cpp`: `INTERRUPTED` en el dominio y la ayuda.
- `verif/scripts/TC-016.sh` y `verif/test-cases/TC-016.md`: expectativa `INTERRUPTED` y escritura JSON con `->utf8`.
- `verif/scripts/TC-022.sh` y `verif/test-cases/TC-022.md` (nuevos): casos (a)–(e), auditoría F1 y límites documentados.
- `verif/scripts/TC-003.sh`: aislamiento con `HOME` temporal, limpieza del demonio y veredicto derivado.
- `src/hermes/data`: restaurado a su estado de git; sin cambio propio del RF-13.

**Prueba agregada:**

Se ejecutó la suite en serie dentro de WSL (TC-003/005/008 hacen `make clean && make`; en paralelo producen "Text file busy"):

| Script | Resultado |
|---|---|
| TC-003 | FAIL — Paso 5 exige `QUEUED` y observa `RUNNING` (previo al corte) |
| TC-005 | PASS |
| TC-008 | PASS |
| TC-016 | PASS — `INTERRUPTED`/`sin_identidad` |
| TC-019 | PASS — 10 iteraciones, 0 fallos |
| TC-021 | PASS — 10 Jobs, 30 solicitudes concurrentes |
| TC-022 | PASS — (a)–(e) + auditoría F1 |

Evidencia en `verif/results/tc003.log`, `tc005.log`, `tc008.log`, `results_TC-016.md`, `results_TC-019.md`, `results_TC-021.md` y `results_TC-022.md`. TC-022 comprobó explícitamente que un proceso ajeno no se señaliza, que el Job no hereda `scheduler.lock`/`jobs.lock`/archivos de datos, que `pgrp == pid` y que la identidad persistida coincide con `/proc`.

---

## Implementación de feature

### 1. Estado `INTERRUPTED` terminal y fail-closed

Se agregó al final del `enum class` para no alterar los valores ya persistidos. `INTERRUPTED` significa "Hermes dejó de supervisar el Job; su resultado real es desconocido": no es `FAILED` (el programa no falló) ni `CANCELED` (no fue una acción del usuario). Un `status` desconocido ya no se reporta como pendiente ni se reejecuta: se reclasifica como `INTERRUPTED` con `motivo=estado_desconocido`.

### 2. Identidad de proceso y lanzamiento seguro

Un proceso es "nuestro" solo si coinciden `boot_id`, starttime y `pgrp == pid`. El hijo se crea en su propio grupo para poder señalar también a los nietos, y con `PDEATHSIG=SIGKILL` para que no sobreviva al demonio. La relectura de `getppid()` cierra la carrera "padre muerto antes de `prctl`". El `errno` de `exec` viaja por un pipe auxiliar para conservar el mapeo ENOENT→127.

### 3. Módulo `recovery`

Clasifica cada fila de `jobs.json` según la tabla 2.4, actúa sobre los procesos verificados antes de persistir y usa una sola ventana de gracia de 5 s para todo el lote. Si un huérfano verificado resiste, se registra `proceso_terminado=false` y un ERROR explícito: RNF-10 se mantiene (nunca `RUNNING`) y RNF-30 queda como excepción auditable.

### 4. Recuperación antes del `fork`

El CLI abre `scheduler.lock` con `O_CLOEXEC` y prueba `flock`. Si el lock está ocupado, hay daemon vivo y no se recupera. Si se obtiene, se ejecuta la sonda de capacidad y la recuperación en el propio CLI, de forma síncrona, antes de crear el demonio. Así ningún `filter` puede observar filas `RUNNING` sin dueño.

### 5. Prevención en origen: F1 y F4

`O_CLOEXEC` en `scheduler.lock`, `jobs.lock`, la bitácora y los pipes evita que un Job herede el descriptor y mantenga el `flock` tras la muerte del demonio. `guardarPid` ahora devuelve `bool` y, si no logra persistir, termina el proceso recién creado para no dejar un huérfano no reconciliable.

### 6. Pruebas

TC-016 cambió de `FAILED` a `INTERRUPTED`. TC-022 cubre (a) muerte del demonio con Job activo, (b) `SIGKILL` y PDEATHSIG, (c) PID ajeno que no debe señalarse, (d) `QUEUED` que se conserva y ejecuta, (e) terminales intactos y estado desconocido fail-closed, además de la auditoría F1. TC-003 se aisló con `HOME` temporal.

---

## Modificación de archivo

`src/hermes/include/status.h`

```cpp
enum class Status {
      QUEUED,
      RUNNING,
      SUCCEEDED,
      FAILED,
      CANCELED,
      INTERRUPTED
};
```

`src/hermes/src/status/status.cpp`

```cpp
// Fail-closed: un estado que no entendemos no puede reportarse como
// pendiente ni reejecutarse. Se trata como interrumpido.
return Status::INTERRUPTED;
```

`src/hermes/src/process/process.cpp`

```cpp
if (pid == 0) {
    close(aux[0]);
    close(pipefd[0]);

    setpgid(0, 0);
    prctl(PR_SET_PDEATHSIG, SIGKILL);

    if (getppid() != padre) {
        _exit(127);
    }

    // ...

    execvp(programa.c_str(), argv.data());
    const int error = errno;
    (void)!write(aux[1], &error, sizeof(error));
    _exit(127);
}
```

`src/hermes/src/recovery/recovery.cpp`

```cpp
if (!statusConocido) {
    clasificacion.motivo = "estado_desconocido";
    // ...
    continue;
}

if (textoStatus != "RUNNING") {
    continue;
}

if (!leerPid(item, pid) || pid <= 0) {
    clasificacion.motivo = "sin_pid";
    // ...
    continue;
}

if (!leerIdentidadGuardada(item, pidInicio, bootId)) {
    clasificacion.motivo = "sin_identidad";
    // ...
    continue;
}

if (!procesoVivo(clasificacion.pid)) {
    clasificacion.motivo = "caida";
    clasificacion.procesoTerminado = true;
    // ...
    continue;
}

if (!identidadCoincide(clasificacion.pid, bootId, pidInicio)) {
    // Regla dura: si la identidad no coincide, no se envía señal.
    clasificacion.motivo = "pid_reutilizado";
    clasificacion.procesoTerminado = true;
    // ...
    continue;
}

clasificacion.motivo = "caida";
clasificacion.requiereTerminacion = true;
```

`src/hermes/src/scheduler/scheduler.cpp`

```cpp
if (flock(descriptor, LOCK_EX | LOCK_NB) == -1) {
    close(descriptor);
    return;
}

try {
    verificarCapacidadDeRecuperacion();
    hermes::recuperarTrabajosInterrumpidos();
} catch (const exception& e) {
    // ...
    throw runtime_error(
        "No se pudo recuperar el estado antes de iniciar el scheduler"
    );
}

pid_t pid = fork();
```

```cpp
if (!guardado) {
    if (hayIdentidad && identidad.pgrp == pid) {
        terminarGrupoProceso(pid);
    } else {
        kill(pid, SIGKILL);
    }

    return false;
}
```

`verif/scripts/TC-003.sh`

```bash
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"

DATA="$HOME/.local/share/hermes/data/jobs.json"
LOCK="$HOME/.local/share/hermes/data/scheduler.lock"
FALLOS=0

# ...

trap cleanup EXIT
```

---

# Implementación final

Compilación:

```text
$ make -C src/hermes
g++ -Wall -Wextra -std=c++17 -Iinclude src/... src/recovery/recovery.cpp ... -pthread -o hermes
```

TC-022 (extracto):

```text
OK: (a) el hijo murió al morir el demonio (PDEATHSIG).
OK: (a) fila INTERRUPTED (motivo=caida, proceso_terminado=true), sin huérfano.
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.
OK: (c) el proceso ajeno 22253 sigue vivo: no se señaló un PID no verificado.
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (F1) el Job no heredó scheduler.lock, jobs.lock ni archivos de datos.
OK: (F1) el Job corre en su propio grupo (pgrp=pid).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

PASS: TC-022 cubrió (a) sin huérfanos, (b) sin RUNNING tras SIGKILL,
(c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos
y estado desconocido fail-closed; además, los Jobs no heredan locks.
```

TC-003 (extracto):

```text
Paso 1 OK (compilación limpia)
Paso 2 OK (job 1 -> SUCCEEDED)
Paso 3 OK (job 2 -> FAILED)
Paso 4 OK (job 3 -> CANCELED)
Paso 5 FAIL (estado inicial exigido: QUEUED, real observado: RUNNING)
Paso 6 OK (códigos y tiempos validados en JSON)
[FAIL] TC-003 (1 paso(s) fallido(s))
```

Pendientes para la implementación futura (Cortes 2 y 3):

1. `storage`: `fsync` de archivo y directorio, `jobs.json.bak`, limpieza de `.tmp.*` y fallback de lectura (RNF-11, TC-022 (f)).
2. Guard de F5 en `registrarFallo`: actuar solo si la reserva devolvió `true` y la fila sigue `RUNNING`.
3. Handlers de `SIGTERM`/`SIGINT`, registro de activos en memoria y cierre ordenado con `motivo=apagado` (TC-022 (a) todavía no lo ejerce).
4. Recuperación previa en `clean data` (F12, TC-022 (g)).
5. Fila `RUNNING` con `pid <= 0` (`motivo=sin_pid`): caso de la tabla 2.4 aún sin prueba dedicada.
6. Actualizar `RF-06.status.md`, ADR-005/006 y la matriz de trazabilidad.

---

# Aprendizaje

- **La identidad es la que autoriza la señal.** Un PID no basta: `boot_id` + starttime + `pgrp` son la diferencia entre reconciliar un huérfano y matar un proceso ajeno. La regla "si no coincide, no se señaliza" debe quedar por encima de cualquier intento de limpieza.
- **Prevenir es mejor que reconciliar.** `PDEATHSIG` cierra la ventana en la que el demonio muere y el hijo queda vivo; la recuperación es la red de seguridad, no el mecanismo principal.
- **`O_CLOEXEC` no es cosmético.** `flock` pertenece a la open file description; un descriptor heredado por un Job mantiene el lock y bloquea la recuperación del siguiente arranque.
- **Fail-closed en estados.** Mapear un valor desconocido a `QUEUED` es afirmar algo que no se sabe y puede reejecutar trabajo. `INTERRUPTED` es la respuesta honesta.
- **Las pruebas también tienen bugs.** El reencodeo con `JSON::PP` sin `->utf8` corrompía `jobs.json`, y `if ! make clean && make` nunca recompilaba. Ambos errores pasaron la revisión visual y solo aparecieron al ejecutar.
- **Aislar el entorno de prueba.** Depender de un symlink absoluto commiteado (y de `core.symlinks=false`) hace que la prueba mida la máquina, no el código. `HOME` temporal + limpieza del demonio es el patrón correcto.
- **No ablandar una prueba para ponerla en verde.** TC-003 sigue fallando en el Paso 5 porque el producto no muestra `QUEUED`; cambiar la expectativa habría ocultado el desfase del Hito 1.
- **La durabilidad es una deuda explícita.** La recuperación escribe `RUNNING → INTERRUPTED`; sin `fsync` ni `.bak`, un corte de energía puede perder esa escritura. Es el riesgo residual que debe cerrar el Corte 2, no un defecto del Corte 1.

---

# 23.1. Seguimiento del Corte 1 — marcas de avance y hallazgo de nietos

**Estado:** el hallazgo de nietos descrito aquí se cerró en 23.2; esta sección conserva la evidencia de la sonda que lo reprodujo.

## Objetivo

Marcar en `implementacion-RF-13.md` el avance real del Corte 1 y analizar lo implementado para determinar la siguiente acción del plan. La revisión debía ser crítica: no bastaba con palomear pasos, había que comprobar que las afirmaciones del diseño seguían siendo ciertas contra el código y el comportamiento observado.

---

## Prompt 4

```text
muy bien, ahora en "docs\technical-guide\2-Nucleo del proyecto\implementacion-RF-13.md" marca lo que ya completaste y despues analiza todo lo que haz hecho para determinar la siguiente accion a realizar de acuerdo al plan
```

---

## Resultado 4

Se actualizó el documento con la leyenda `[COMPLETADO]`/`[PARCIAL]`/`[PENDIENTE]`, el estado por subsección (§2.1–§2.5), una columna de estado en la tabla §2.6, marcas en los casos (a)–(h) de TC-022, el orden de §2.7 y una sección §5 con la siguiente acción.

Al contrastar el diseño con el código se confirmó que F5 seguía abierto (`registrarFallo` marca `FAILED` sin comprobar que la fila siga `RUNNING`) y se detectó un hueco no cubierto: si el líder muere por `PDEATHSIG` y deja descendientes en su grupo, la recuperación ve el PID ausente, no señala el grupo y persiste `proceso_terminado=true`. Se reprodujo con `hermes job sh -c 'sleep 300 & wait'`: tras `SIGKILL` al demonio, el `sleep` sobrevivió y la fila quedó `INTERRUPTED`/`caida`/`proceso_terminado=true`.

La causa es que la identidad se verifica sobre el líder (`boot_id` + starttime + `pgrp`); cuando el líder ya no existe no hay con qué comparar y el código opta por no señalizar. La consecuencia es una violación de RNF-30: el estado afirma que el proceso terminó cuando un descendiente sigue vivo. Se propuso el Corte 1.1: persistir el `sid` (campo aditivo) y, si el líder falta, terminar el grupo `-pgid` solo cuando sus miembros compartan ese `sid`, más el caso (h) de TC-022.

---

# Modificaciones (seguimiento)

**Estado de la resolución:** Modificado por deficiencia.

**Revisión realizada:** El Corte 1 se había declarado cerrado con TC-022 (a)–(e), pero (a) solo probaba la muerte de un Job que era el propio líder (`sleep`), no de un Job con nietos. La afirmación del diseño "PDEATHSIG mata a los hijos" era correcta solo para el hijo directo. La IA no lo cuestionó al cerrar el corte; la prueba empírica lo desmintió.

**Cambios aplicados:** Se corrigió el documento de RF-13 (estados honestos, hallazgo en §2.5 y §2.8, §5 con Corte 1.1), se ajustó la descripción de `recuperarSiNoHayDaemon()` para reflejar que `clean data` todavía no lo invoca y se dejó constancia de que RNF-30 queda `[PARCIAL]` hasta cerrar el caso (h).

**Prueba agregada:** Sonda en WSL con `HOME` temporal: `hermes job sh -c 'sleep 300 & wait'`, espera de `RUNNING`, `SIGKILL` al demonio localizado por el `scheduler.lock`, lectura de `/proc` y de `jobs.json` antes y después de la recuperación. Resultado: el líder desaparece, el `sleep` sigue en el grupo y la fila queda `INTERRUPTED`/`caida`/`proceso_terminado=true`.

---

## Implementación final (evidencia de la sonda)

```text
job_id: 1 leader: 24063 estado: RUNNING
pgid: 24063 == leader: True
miembros antes: [(24063, 'S', 'sh -c sleep 300 & wait'), (24066, 'R', 'sleep 300')]
demonio: 24059
leader vivo tras SIGKILL: False
miembros tras muerte del demonio: [(24066, 'S', 'sleep 300')]
fila tras recuperación: {'status': 'INTERRUPTED', 'motivo': 'caida', 'proceso_terminado': True}
miembros tras recuperación: [(24066, 'S', 'sleep 300')]
```

---

## Aprendizaje

- **"Sin huérfanos" hay que probarlo con nietos.** Un Job que es el propio líder no ejercita el caso que el grupo pretende resolver. La prueba (a) era demasiado fácil.
- **`PDEATHSIG` es por proceso, no por árbol.** Solo el hijo directo recibe la señal; los descendientes sobreviven y conservan el `pgid`. La recuperación debe poder reconocer el grupo sin el líder.
- **Un campo booleano es una promesa.** `proceso_terminado=true` con un proceso vivo es el mismo tipo de mentira que el RF-13 quería eliminar; si no se puede verificar, el valor debe ser `false` y el caso debe registrarse como excepción.
- **Revisar el plan contra el código, no contra el checklist.** El hallazgo apareció al contrastar la afirmación del diseño con lo que realmente hacía `recovery`, no al leer el código por encima.

---

# 23.2. Corte 1.1 — grupo sin líder y cierre de la fuga F1

## Objetivo

Cerrar el hueco detectado en 23.1: si el líder de un Job muere por `PDEATHSIG` y deja descendientes en su grupo, la recuperación debe terminar el grupo completo y calcular `proceso_terminado` con evidencia real, no afirmar una terminación que no ocurrió. El alcance se limitó al Corte 1.1: persistir el `sid`, reconocer el grupo sin líder, añadir TC-022 (h) y corregir la fuga de descriptores que la propia prueba expuso. No se adelantó el Corte 2 (`fsync`/`.bak`/`.tmp`) ni el Corte 3 (handlers de apagado y `motivo=apagado`).

Restricciones: `sid` como campo aditivo, filas antiguas compatibles, no tocar el `Makefile`, compilar con `make -C src/hermes`, pruebas en serie desde WSL y registrar la interacción en este documento.

---

## Prompt 5

```text
si
```

En respuesta a la propuesta del Corte 1.1 al final de 23.1.

---

## Resultado 5

Se implementó el Corte 1.1 y se verificó con TC-022 (h). El `sid` de la sesión privada del demonio se persiste junto con `boot_id`/`pid_inicio`; `estadoGrupoProceso(pgid, sid)` recorre `/proc` y reconoce únicamente a los miembros que comparten grupo y sesión, ignorando zombies. Si el líder ya no existe y el grupo sigue vivo, `recovery` aplica TERM→5 s→KILL y calcula `proceso_terminado` según el resultado. Las filas antiguas sin `sid` conservan el comportamiento conservador anterior.

La verificación también encontró una fuga residual de F1: el demonio es multihilo y otro worker podía tener `jobs.json` abierto en el momento del `fork`, por lo que el hijo heredaba el descriptor y el Job lo conservaba tras `exec`. El hijo ahora marca `FD_CLOEXEC` en los descriptores 3–1023 antes de `exec`.

---

# Modificaciones (Corte 1.1)

**Estado de la resolución:** Modificado por deficiencia.

**Revisión realizada:** La primera versión del Corte 1.1 compiló y reprodujo el hueco, pero la verificación crítica encontró dos problemas que no podían aceptarse:

1. **`/proc` no verificable tratado como una respuesta.** La primera versión no distinguía con suficiente claridad entre "no hay miembros del grupo" y "no se pudo comprobar". Eso podía convertir una negativa a verificar en una afirmación de terminación. Se corrigió con un estado explícito de tres valores: `Inexistente`, `Vivo` y `NoVerificable`. En `NoVerificable` no se señaliza el grupo, se deja `proceso_terminado=false` y se registra `ERROR`.
2. **Fuga residual de F1 en el `fork` multihilo.** TC-022 (h) falló de forma reproducible con un descriptor heredado (`/proc/<pid>/fd/8 -> .../jobs.json (deleted)`). La auditoría F1 del Corte 1 comprobaba los locks, pero no cubría el caso en que otro worker abre `jobs.json` justo antes de que el hilo lanzador bifurque. El hijo marca `FD_CLOEXEC` en los descriptores 3–1023 antes del `exec`; los descriptores 0, 1 y 2 se conservan. El rango cubre el límite blando habitual y los descriptores del demonio; un descriptor por encima de 1023 no se cubre y obligaría a ampliar el rango si se eleva `RLIMIT_NOFILE`.

**Cambios aplicados:**

- `src/hermes/include/process.h`: `IdentidadProceso.sid`, `EstadoGrupoProceso` y `estadoGrupoProceso(pgid, sid)`.
- `src/hermes/src/process/process.cpp`: lectura del campo 6 de `/proc/<pid>/stat` (sesión), escaneo de `/proc` con filtro de zombies y cierre de descriptores 3–1023 en el hijo.
- `src/hermes/src/scheduler/scheduler.cpp`: `guardarPid` persiste `sid` como campo aditivo.
- `src/hermes/src/recovery/recovery.cpp`: lee `sid`, detecta el grupo sin líder con `boot_id` coincidente, termina con TERM→5 s→KILL, calcula `proceso_terminado` real y conserva filas antiguas sin `sid`.
- `verif/scripts/TC-022.sh`: caso (h), helpers `campo_proc`, `hijos_de` y `miembros_grupo`, limpieza del grupo.
- `verif/test-cases/TC-022.md` y `docs/technical-guide/2-Nucleo del proyecto/implementacion-RF-13.md`: alcance, fila (h), limitaciones, estado y siguiente acción.
- `Makefile`: sin cambios.

**Prueba agregada:** TC-022 (h) crea un Job con `hermes job sh -c 'sleep 300 & wait'`, espera `RUNNING`, envía `SIGKILL` al demonio y comprueba: el líder y el nieto comparten grupo y sesión; el líder muere; el nieto sobrevive (hueco reproducido); tras recuperar, no queda ningún miembro vivo y la fila queda `INTERRUPTED` con `motivo=caida` y `proceso_terminado=true`.

---

## Implementación final (evidencia de TC-022)

Compilación:

```text
$ make -C src/hermes
g++ -Wall -Wextra -std=c++17 ... -o hermes
```

TC-022 (extracto de la última corrida):

```text
== (h) nietos que sobreviven a PDEATHSIG: el grupo sin líder se termina ==
job ID: 10
PID: 37332
OK: (h) el líder y su nieto comparten grupo y sesión privada (sid=37326).
OK: (h) el líder murió y el nieto 37333 sobrevivió (hueco reproducido).
OK: (h) no queda ningún miembro vivo del grupo (proceso_terminado real).

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
OK: (F1) el Job 37599 no heredó scheduler.lock, jobs.lock ni archivos de datos.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=37599).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

PASS: TC-022 cubrió (a) sin huérfanos, (b) sin RUNNING tras SIGKILL,
(c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos
y estado desconocido fail-closed, (h) grupo sin líder terminado por sid;
además, los Jobs no heredan locks.
```

TC-022 pasó completo en tres corridas exitosas; la última se ejecutó después de la compilación final. Suite relacionada en serie: TC-016 PASS, TC-019 PASS, TC-021 PASS, TC-005 PASS, TC-008 PASS. TC-003 conserva su único fallo previo: el Paso 5 no observa `QUEUED` porque el Job pasa a `RUNNING` (desfase del Hito 1, ajeno a este corte).

---

## Aprendizaje

- **`PDEATHSIG` es por proceso, no por árbol.** El líder puede morir y dejar nietos vivos; la recuperación debe reconocer el grupo, no solo el PID.
- **El `sid` es la identidad del grupo cuando falta el líder.** Es estable mientras existan miembros de la sesión y, al ser un campo aditivo, no rompe las filas antiguas; las que no lo tienen quedan explícitamente fuera de la verificación de grupo.
- **"No verificable" no es "inexistente".** Un fallo de `/proc` no autoriza a afirmar que el grupo terminó. El estado de tres valores y el `ERROR` con `proceso_terminado=false` son la respuesta honesta.
- **`O_CLOEXEC` en los archivos propios no basta en un demonio multihilo.** Otro hilo puede abrir un descriptor entre el `fork` y el `exec`; marcar `FD_CLOEXEC` en los descriptores 3–1023 del hijo es la barrera que no depende del orden de los hilos.
- **La prueba encontró una fuga que la revisión visual no vio.** TC-022 (h) no solo validó el `sid`: también destapó un descriptor heredado de `jobs.json` que la auditoría F1 anterior no cubría. La verificación empírica sigue siendo parte del diseño.
- **No se adelantó el Corte 2.** El hueco de nietos era una violación de RNF-30 del mismo tipo que el Corte 1 combatía, pero la durabilidad (`fsync`/`.bak`/`.tmp`) y el cierre ordenado siguen siendo deudas separadas y explícitas.

---

# 23.3. Corte 2 — persistencia durable y guard F5

## Objetivo

Implementar el Corte 2 del RF-13: que `jobs.json` sobreviva a una muerte violenta o a un corte de energía sin quedar ilegible, que exista un respaldo válido, que los temporales huérfanos se limpien al arrancar y que el guard F5 impida marcar `FAILED` una fila que nunca llegó a reservarse. El alcance excluyó explícitamente los handlers de apagado, `motivo=apagado`, la recuperación previa en `clean data`, TC-022 (a) completa y TC-022 (g): todo eso pertenece al Corte 3.

Restricciones respetadas: no se tocó el `Makefile`, no se hizo commit, los identificadores nuevos quedaron en español, la compilación se hizo con `make -C src/hermes` y las pruebas se ejecutaron en serie desde WSL.

---

## Prompt 6

```text
continua con el siguiente paso del plan
```

En respuesta a la propuesta del Corte 2 al final de 23.2.

---

## Resultado 6

`storage.cpp` dejó de escribir con `ofstream` directo sobre `jobs.json`. Ahora crea un temporal único con `O_CREAT|O_EXCL|O_CLOEXEC` (PID + contador atómico), escribe en bucle con `write()`, hace `fsync` del archivo, cierra, refresca `jobs.json.bak` con `link()`, hace `rename()` y finalmente `fsync` del directorio. La cadena de lectura es `jobs.json → jobs.json.bak → error explícito`; si cae al respaldo, reescribe `jobs.json` en la misma transacción bajo `jobs.lock` y registra un `WARN`. `limpiarTemporalesDeJobs()` elimina los `jobs.json.tmp.*` huérfanos al arrancar, como paso 3 del flujo.

F5 se corrigió en dos capas: `reservarTrabajo` ya no publica `trabajo.id` hasta que la reserva se persistió, y `registrarFallo` solo modifica una fila que sigue en `RUNNING`. TC-022 incorporó el caso (f) —`kill -9` en plena ráfaga, respaldo, limpieza y fallback con reparación— y el caso (i) para `sin_pid`.

---

# Modificaciones (Corte 2)

**Estado de la resolución:** Modificado por deficiencia.

**Revisión realizada:** La primera versión no se aceptó tal cual. La verificación encontró tres problemas:

1. **Error de compilación por asumir un namespace.** Se llamó `hermes::limpiarTemporalesDeJobs()` desde `scheduler.cpp`, pero las funciones de `storage.h` son globales; solo `data_paths` y `event_log` viven en `hermes`. El compilador lo rechazó y se corrigió quitando el calificador, pero el error demuestra que la revisión visual del contrato entre módulos no sustituye a compilar.
2. **Fallback sin reparación y riesgo de envenenar el respaldo.** La primera versión leía `.bak` y devolvía el arreglo, pero dejaba `jobs.json` corrupto. Eso mantenía un fallback permanente y, peor, la siguiente escritura podía refrescar `.bak` desde el archivo principal corrupto, destruyendo la única copia buena. Se corrigió en dos puntos: `actualizarRespaldo()` omite el refresco si `jobs.json` no parsea, y la lectura desde `.bak` reescribe `jobs.json` dentro de la misma transacción.
3. **`write()` sin progreso.** El bucle de escritura no contemplaba que `write()` devolviera `0`; en un archivo regular no debería ocurrir, pero sin guardia el bucle podía no avanzar. Se añadió un fallo explícito.

**Cambios aplicados:**

- `src/hermes/include/storage.h`: declaración y contrato de `limpiarTemporalesDeJobs()`.
- `src/hermes/src/storage/storage.cpp`: temporal único, bucle de `write()`, `fsync` de archivo y directorio, `.bak` con `link` condicionado a que el principal parsee, limpieza de `.tmp`, cadena de lectura con auto-reparación y error explícito si ambos archivos fallan.
- `src/hermes/src/scheduler/scheduler.cpp`: publicación tardía de `trabajo.id` en `reservarTrabajo`, guard `RUNNING` en `registrarFallo`, llamada a `limpiarTemporalesDeJobs()` en el arranque y `<utility>` para `std::move`.
- `verif/scripts/TC-022.sh`: casos (f) e (i), helpers `siguiente_id` y `parsea_arreglo`, variable `RESPALDO`, cabecera y mensaje PASS actualizados.
- `verif/test-cases/TC-022.md`, `docs/technical-guide/2-Nucleo del proyecto/implementacion-RF-13.md` y este documento: alcance, estado, filas (f)/(i), limitaciones y siguiente acción.
- `Makefile`: sin cambios.

**Prueba agregada:** TC-022 (f) lanza 40 Jobs mientras el demonio escribe, le envía `SIGKILL` a mitad de la ráfaga y exige que `jobs.json` y `jobs.json.bak` parseen como arreglo. Después inyecta un `jobs.json.tmp.999999.7` con un PID que no puede pertenecer a un proceso vivo, arranca el scheduler y verifica que el temporal desapareció. Por último corrompe `jobs.json` a propósito y comprueba que la lectura cae al respaldo, conserva una fila terminal conocida y repara el archivo principal. TC-022 (i) fabrica una fila `RUNNING` con `pid=0` y exige `INTERRUPTED` con `motivo=sin_pid`, `proceso_terminado=false`, `codigo_salida=-1` y un mensaje que explique la ausencia de PID verificable.

---

## Implementación final (evidencia de TC-022)

Compilación limpia con `-Wall -Wextra`, sin warnings:

```text
$ make -C src/hermes
g++ -Wall -Wextra -std=c++17 ... -o hermes
```

TC-022 (extracto de la última corrida, `verif/results/results_TC-022.md`):

```text
== (f) SIGKILL en plena ráfaga de escrituras: jobs.json parsea y no quedan temporales ==
OK: (f) jobs.json parsea como arreglo tras el SIGKILL en escrituras.
OK: (f) jobs.json.bak existe y parsea como arreglo.
OK: (f) el arranque eliminó el jobs.json.tmp.* huérfano.
OK: (f) jobs.json sigue parseando después de la recuperación.
OK: (f) con jobs.json corrupto se leyó jobs.json.bak y se conservó la fila 5.
OK: (f) jobs.json se reparó desde jobs.json.bak.

== (i) fila RUNNING con pid=0: motivo=sin_pid ==
OK: (i) sin_pid queda INTERRUPTED sin afirmar una terminación que no ocurrió.

PASS: TC-022 cubrió (a) sin huérfanos, (b) sin RUNNING tras SIGKILL,
(c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos
y estado desconocido fail-closed, (f) jobs.json y .bak parsean y los .tmp
se limpian tras SIGKILL en escrituras, (h) grupo sin líder terminado por sid,
(i) sin_pid sin afirmar terminación; además, los Jobs no heredan locks.
```

Suite relacionada en serie: TC-016 PASS, TC-019 PASS, TC-021 PASS, TC-005 PASS, TC-008 PASS. TC-003 conserva su único fallo previo: el Paso 5 no observa `QUEUED` porque el Job pasa a `RUNNING` (desfase del Hito 1, ajeno a este corte). No se modificó el `Makefile` ni se creó commit.

---

## Aprendizaje

- **`rename()` es atómico, no durable.** Sin `fsync` del archivo antes y del directorio después, un corte de energía puede dejar el contenido nuevo sin la entrada de directorio, o la entrada anterior. La atomicidad protege del proceso muerto; el `fsync` protege del hardware.
- **Un respaldo solo sirve si nunca se sobrescribe con basura.** Refrescar `.bak` sin validar el principal convierte la recuperación en una forma lenta de perder ambas copias. Validar antes de refrescar es la diferencia entre un respaldo y un segundo archivo corrupto.
- **Leer del respaldo sin reparar deja el sistema en deuda permanente.** La auto-reparación bajo el mismo `jobs.lock` cierra el ciclo: el fallback es un evento, no un modo de operación.
- **F5 se corrige en el origen y en el destino.** Publicar `trabajo.id` solo después de persistir evita que el `catch` del worker actúe sobre una reserva inexistente; el guard `RUNNING` en `registrarFallo` evita que un camino futuro repita el error.
- **La limpieza se prueba de forma determinista, no por suerte.** Matar al demonio "a mitad de escritura" es probabilístico; inyectar un temporal con un PID imposible convierte la comprobación en una aserción reproducible.
- **El compilador es parte de la revisión de contratos.** El error de namespace no era un detalle de estilo: era una suposición sobre la arquitectura de módulos que solo la compilación desmintió.

---

# 23.4. Corte 3 — cierre ordenado, registro de activos y `clean data`

## Objetivo

Cerrar el RF-13 con el Corte 3: que un `SIGTERM`/`SIGINT` al demonio no deje Jobs `RUNNING` ni huérfanos, que el estado final lo escriba un único actor con `motivo=apagado`, y que `clean data` recupere una caída antes de borrar sin arrancar el scheduler (F12). El alcance excluyó cualquier cambio de esquema, el `Makefile` y los cortes ya cerrados.

Restricciones respetadas: no se tocó el `Makefile`, no se hizo commit, los identificadores nuevos quedaron en español, la compilación se hizo con `make -C src/hermes` y las pruebas se ejecutaron en serie desde WSL.

---

## Prompt 7

```text
continua con el siguiente paso del plan
```

En respuesta a la propuesta del Corte 3 al final de 23.3.

---

## Resultado 7

La IA implementó el cierre ordenado en `scheduler.cpp`:

- **Handlers:** `sigaction` con `SA_RESTART`; `SIGTERM`/`SIGINT` solo escriben `volatile sig_atomic_t banderaApagado`. No toman locks ni hacen I/O.
- **Registro de activos:** `mutexActivos` + `map<unsigned int, TrabajoActivo>` + `cvActivos`. Cada entrada guarda `pid`, `pgid`, `sid`, `grupoVerificado`, `interrumpido` y `procesoTerminado`.
- **Puerta de arranque:** `mutexArranque` cubre reservar→`spawn`→registrar. El worker lo toma antes de comprobar el flag; el coordinador lo toma para cerrar la puerta antes de recorrer el registro.
- **Coordinador:** marca los activos como interrumpidos, señaliza los grupos (TERM→una ventana de 5 s→KILL→hasta 5 s), espera a que los workers desregistren con `cvActivos` y persiste `INTERRUPTED`/`motivo=apagado` solo sobre filas que siguen `RUNNING`.
- **Señalización segura:** solo se envía al grupo si `identidad.pgrp == pid`; en caso contrario, `kill(pid, sig)`.
- **Un solo escritor:** el worker que desregistra con `interrumpido=true` no llama `finalizarTrabajo`.
- **`clean data`:** `BloqueoScheduler` (RAII sobre `scheduler.lock`); si el lock está libre, `verificarCapacidadDeRecuperacion()` + `limpiarTemporalesDeJobs()` + `recuperarTrabajosInterrumpidos()` antes de decidir si hay trabajos activos. Si hay daemon, se rechaza como antes.
- **Movimiento de función:** `verificarCapacidadDeRecuperacion()` pasó de `scheduler.cpp` a `recovery.cpp`/`recovery.h` para reutilizarla desde `clean data`.

---

# Modificaciones (Corte 3)

**Estado de la resolución:** Modificado por deficiencia.

**Revisión realizada:**

La primera versión no compiló y la verificación manual expuso dos problemas de estructura:

1. **Error de compilación por namespace.** Al mover `verificarCapacidadDeRecuperacion()` a `recovery.h` (namespace `hermes`), las llamadas desde `clean.cpp` y `scheduler.cpp` quedaron sin calificar y el compilador las rechazó. Se corrigió con `hermes::verificarCapacidadDeRecuperacion()` en ambos archivos. Otra vez: la revisión visual del contrato entre módulos no sustituye a compilar.
2. **`try`/`catch` mal estructurado en `trabajador()`.** El primer `try` cubría reserva→`spawn`→registro y se cerraba antes del bucle de lectura; los `catch` del final quedaban sin un `try` abierto y el archivo no compilaba. Se resolvió envolviendo lectura→`waitpid`→desregistro→`finalizarTrabajo` en un segundo `try`, y añadiendo en sus `catch` la limpieza del proceso registrado (`kill`, `waitpid`, desregistro y `procesoRegistrado=false`) para no dejar un hijo vivo si la lectura o la espera lanzan.
3. **Riesgo de doble escritura del estado final.** Si el worker llamaba `finalizarTrabajo` después de que el coordinador hubiera marcado `INTERRUPTED`, podía pisar la fila. Se separó la responsabilidad: el worker no finaliza si desregistra con `interrumpido=true`; el coordinador exige `status == "RUNNING"` antes de persistir.
4. **Riesgo de arranque tardío.** Si un worker comprobaba el flag antes de que el coordinador lo fijara, podía iniciar otro Job durante el apagado. `mutexArranque` se toma antes de cerrar la puerta y el coordinador lo adquiere antes de recorrer el registro, de modo que ningún worker queda a mitad de la ventana reservar→`spawn`→registrar.

**Cambios aplicados:**

- `src/hermes/src/scheduler/scheduler.cpp`: handlers, registro de activos, coordinador de apagado, persistencia de `INTERRUPTED`/`apagado`, worker con puerta de arranque y desregistro, `ejecutarScheduler()` con coordinador, llamada calificada a `hermes::verificarCapacidadDeRecuperacion()`.
- `src/hermes/src/clean/clean.cpp`: `BloqueoScheduler` y recuperación previa cuando no hay daemon.
- `src/hermes/src/recovery/recovery.cpp` e `include/recovery.h`: `verificarCapacidadDeRecuperacion()` movida desde `scheduler.cpp`.
- `verif/scripts/TC-022.sh`: caso (a) reescrito para `motivo=apagado` e idempotencia; caso (g) nuevo para `clean data`; helper `cantidad_filas()`; cabecera y línea PASS actualizadas.
- `verif/test-cases/TC-022.md`: casos (a)/(g), resultado esperado y limitaciones de los tiempos de gracia.
- `docs/technical-guide/2-Nucleo del proyecto/implementacion-RF-13.md`, `RF-06.status.md`, `ADR-005-Persistencia.md`, `ADR-006-Procesos.md` y este documento: cierre del corte y trazabilidad.
- `Makefile`: sin cambios.

**Prueba agregada:** TC-022 (a) envía `SIGTERM` al demonio con un Job `sleep` activo, espera a que se libere `scheduler.lock`, exige `INTERRUPTED` con `motivo=apagado`, `proceso_terminado=true`, `codigo_salida=-1` y mensaje de apagado, comprueba que el hijo no sobrevive y que una recuperación posterior no altera la fila. TC-022 (g) arranca un Job, mata el demonio con `SIGKILL`, comprueba que la fila queda `RUNNING`, ejecuta `clean data`, exige código `0`, historial vacío (`[]`) y ningún daemon arrancado.

---

## Implementación final (evidencia de TC-022)

Compilación limpia con `-Wall -Wextra`, sin warnings:

```text
$ make -C src/hermes
g++ -Wall -Wextra -std=c++17 ... -o hermes
```

Cierre ordenado observado en la prueba manual (extracto de `jobs.json`):

```json
{
    "job_id": 1,
    "status": "INTERRUPTED",
    "motivo": "apagado",
    "proceso_terminado": true,
    "codigo_salida": -1,
    "mensaje_error": "Trabajo interrumpido por el apagado ordenado del scheduler. No se reejecutó automáticamente."
}
```

`clean data` tras `SIGKILL`: `rc=0`, `jobs.json` queda `[]` y no queda ningún proceso con `scheduler.lock` abierto.

TC-022 completo:

```text
PASS: TC-022 cubrió (a) apagado ordenado con motivo=apagado y sin huérfanos,
(b) sin RUNNING tras SIGKILL, (c) no mata PIDs ajenos, (d) QUEUED se ejecuta,
(e) terminales intactos y estado desconocido fail-closed, (f) jobs.json y .bak
parsean y los .tmp se limpian tras SIGKILL en escrituras, (g) clean data recupera
una caída antes de borrar y no arranca daemon, (h) grupo sin líder terminado por
sid, (i) sin_pid sin afirmar terminación; además, los Jobs no heredan locks.
```

Suite relacionada en serie: TC-016 PASS, TC-019 PASS, TC-021 PASS, TC-005 PASS, TC-008 PASS. TC-003 conserva su único fallo previo: el Paso 5 no observa `QUEUED` porque el Job pasa a `RUNNING` (desfase del Hito 1, ajeno a este corte). No se modificó el `Makefile` ni se creó commit.

---

## Aprendizaje

- **Un handler de señal no es un lugar para trabajar.** Solo puede escribir un flag atómico; cualquier lock o I/O desde el handler puede bloquearse o corromper estado. El trabajo real pertenece a un hilo normal que observa el flag.
- **El orden de los locks define la corrección.** Tomar `mutexArranque` antes de cerrar la puerta elimina la ventana en la que un worker ve el flag viejo y arranca otro Job. Si el orden se invierte, el apagado "casi siempre" funciona, que es la peor clase de correcto.
- **Un solo escritor del estado final evita carreras de último minuto.** El worker que desregistra no compite con el coordinador; el coordinador además exige `RUNNING` para no pisar una fila que ya terminó.
- **Recuperar antes de limpiar no es opcional.** Sin la recuperación previa, `clean data` se bloqueaba para siempre con una fila `RUNNING` obsoleta. Reutilizar los pasos 1–4 de arranque bajo el mismo lock cierra F12 sin duplicar lógica.
- **Las ventanas de gracia se pagan en tiempo de apagado.** Dos esperas de 5 s (TERM y KILL) son el peor caso; el diseño las acepta porque el apagado es infrecuente y la alternativa es matar sin dar tiempo al Job.
- **Compilar después de mover una función entre módulos.** Mover `verificarCapacidadDeRecuperacion()` cambió su namespace y las llamadas debían seguirlo; el error no era de estilo, era un contrato de módulo roto.
