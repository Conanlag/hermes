# ADR-006: Creación de procesos

## Contexto

Hermes debe permitir al usuario enviar un programa junto con sus argumentos y obtener un identificador único que permita identificar posteriormente el trabajo solicitado.

El sistema recibe el comando, almacena el programa y sus argumentos dentro de una estructura `Job`, genera un identificador único y persiste la información en `$HOME/.local/share/hermes/data/jobs.json`. En el repositorio, `src/hermes/data` es un enlace simbólico al directorio de datos del usuario.

La creación de un Job constituye la base para posteriormente implementar la ejecución de procesos, el control de estados, la concurrencia y la cancelación.

## Decisión

Se utilizará una estructura `Job` para representar cada trabajo solicitado a Hermes.

La estructura contendrá la información necesaria para identificar el trabajo y conservar los datos enviados por el usuario:

```cpp
struct Job {

    unsigned int job_id;

    string programa;

    vector<string> argumentos;

    Status status;

};
```

La creación del Job se realizará mediante la función:

```cpp
Job crearJob(
    const string& programa,
    const vector<string>& argumentos
);
```

La función recibirá únicamente el programa y sus argumentos. El identificador será generado internamente a partir de los Jobs almacenados previamente y el estado inicial será asignado automáticamente como `QUEUED`. 

El flujo de creación será:

```text
Usuario
   │
   │ hermes job <programa> [argumentos]
   ▼
main.cpp
   │
   │ crearJob()
   ▼
job.cpp
   │
   ├── Leer jobs.json
   ├── Obtener siguiente ID
   ├── Crear Job
   ├── Asignar programa
   ├── Asignar argumentos
   ├── Asignar estado QUEUED
   └── Guardar Job
          │
          ▼
     $HOME/.local/share/hermes/data/jobs.json
```

El identificador se obtendrá recorriendo los Jobs existentes y buscando el ID más alto. El siguiente Job utilizará el valor siguiente. Por ejemplo, si existen los IDs `1` y `5`, el nuevo Job recibirá el ID `6`. 

La información del Job se almacena en `$HOME/.local/share/hermes/data/jobs.json`, permitiendo conservar los trabajos después de finalizar la ejecución del programa Hermes. Desde el repositorio, el mismo archivo se puede consultar en `src/hermes/data/jobs.json` mediante el enlace simbólico.

La ejecución real del programa queda fuera del alcance de esta implementación. En esta etapa, Hermes solamente recibe, identifica y almacena el Job.

| Justificación     | Utilizar una estructura `Job` permite encapsular la información asociada a cada trabajo y separar la creación de Jobs de la ejecución de procesos. El ID se genera a partir de la información persistida, evitando utilizar un archivo independiente exclusivamente para controlar los identificadores. |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | Ejecutar directamente el programa recibido desde `main.cpp` sin crear una estructura `Job`, o Mantener la información del Job únicamente en memoria: crear el Job y asignarle un identificador durante la ejecución de Hermes, sin persistirlo en jobs.json. 3. Separar la generación del ID en un archivo independiente: utilizar un archivo dedicado como data/job_id para almacenar y administrar el siguiente identificador.                                                                                                                                 |
| Consecuencias     | Hermes puede recibir comandos con argumentos, generar identificadores únicos y conservar los Jobs entre diferentes ejecuciones del programa. La ejecución del programa y el control completo de su ciclo de vida quedan pendientes para etapas posteriores.                                             |
| Riesgos           | Si `jobs.json` se elimina o se encuentra corrupto, Hermes puede perder el historial necesario para determinar el siguiente identificador. Además, buscar el ID recorriendo todos los Jobs puede resultar menos eficiente cuando exista una cantidad muy grande de registros.                            |
| Evidencia técnica | `crearJob()` lee `data/jobs.json`, determina el siguiente identificador, crea el objeto `Job`, almacena el programa y sus argumentos, agrega el registro al arreglo JSON y vuelve a escribir el archivo. El módulo no ejecuta el programa recibido.                                                     |

---

## Actualización — RF-13: identidad de proceso y cierre ordenado (RNF-30)

La ejecución de Jobs, el control de estados y la cancelación ya están implementados en hitos posteriores. El RF-13 añadió las garantías necesarias para no dejar procesos huérfanos ni filas `RUNNING` mentirosas.

**Identidad persistida.** `guardarPid` persiste `boot_id` (`/proc/sys/kernel/random/boot_id`), `pid_inicio` (campo 22 de `/proc/<pid>/stat`) y `sid`. Un PID solo se considera propio si coinciden `boot_id`, `starttime` y `pgrp == pid`; el `sid` permite reconocer a los miembros del grupo cuando el líder ya no existe.

**Creación del proceso.** `iniciarProceso` usa `fork` + `setpgid(0,0)` + `prctl(PR_SET_PDEATHSIG, SIGKILL)` + `dup2` + `execvp`, en lugar de `posix_spawnp`, porque este último no permite fijar `PDEATHSIG`. El hijo relee `getppid()` tras `prctl` para cerrar la carrera padre-muerto-antes-de-`prctl`. El `errno` de `exec` se reporta por un pipe auxiliar, conservando el mapeo `ENOENT → 127`.

**Descriptores heredados.** El hijo marca `FD_CLOEXEC` en los descriptores 3–1023 antes del `exec`: el demonio es multihilo y otro worker puede tener `jobs.json` abierto en el momento del `fork`. Los locks (`scheduler.lock`, `jobs.lock`) se abren con `O_CLOEXEC`. El rango cubre los descriptores habituales; uno por encima de 1023 no se cubre.

**Cierre ordenado.** Los handlers de `SIGTERM`/`SIGINT` solo escriben un `volatile sig_atomic_t`; no toman locks ni hacen I/O. Un coordinador de hilo único cierra la puerta de arranque (`mutexArranque`), marca los Jobs activos como interrumpidos, señaliza sus grupos (TERM→5 s→KILL), espera a que los workers desregistren y persiste `INTERRUPTED` con `motivo=apagado`. `SA_RESTART` evita que el `EINTR` del apagado haga fallar `read()`/`waitpid()`.

**Grupo sin líder.** `estadoGrupoProceso(pgid, sid)` recorre `/proc`, exige `pgrp` y `session` coincidentes e ignora zombies. Si el líder murió y quedan descendientes, la recuperación termina el grupo completo; si `/proc` no permite verificar, no señaliza y deja `proceso_terminado=false` con `ERROR`.

**Rechazado:** `cgroups v2` (`cgroup.kill`) sería la garantía absoluta frente a Jobs que se daemonizan con `setsid`, pero exige permisos y no aporta frente a los casos cubiertos por el grupo de procesos.

**Evidencia:** TC-022 (a) cierre ordenado, (b) `SIGKILL` con `PDEATHSIG`, (c) no señaliza PIDs ajenos, (h) grupo sin líder con nietos, y auditoría F1 de descriptores. `implementacion-RF-13.md` §2.5 y `docs/ai-usage/23-RF-13-recuperacion-tras-reinicio.md` registran el diseño y la implementación.
