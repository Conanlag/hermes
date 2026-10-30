# RF-14 — Bitácora de eventos y errores

## Descripción

El sistema Hermes necesita trazabilidad operativa sobre el ciclo de vida de los trabajos y sobre los eventos relevantes del propio daemon. Esta necesidad se cubre con la **Bitácora de eventos y errores**: un archivo de registro persistente que documenta, de forma cronológica, las transiciones de estado, las acciones del usuario, las validaciones fallidas y los errores internos, siempre asociadas a una marca temporal y a un identificador de trabajo.

La bitácora se almacena en formato **JSON Lines (JSONL)**: cada línea representa un evento independiente como un objeto JSON. Esto permite escrituras *append-only* eficientes, bajo consumo de memoria y un análisis posterior sencillo (línea por línea), sin necesidad de reescribir todo el archivo. La ubicación del archivo se resuelve dinámicamente con la infraestructura existente de `data_paths.h`, ubicándose en el **mismo directorio que `jobs.json`** (`~/.local/share/hermes/data/`).

---

## Objetivo

> *"Producir una bitácora de eventos operativos y errores con marca temporal e identificador de trabajo, en formato JSON Lines, guardada dinámicamente en el mismo directorio que jobs.json, registrando el ciclo de vida de los trabajos y los puntos críticos del sistema, manteniendo siempre la llave `job_id` en cada línea."*

**Consideraciones actuales:**

- **Lo que hace:** Registra `Job recibido`, `Transición a RUNNING` (con PID del proceso hijo), `Transición a SUCCEEDED`/`Transición a FAILED` (con `exit_code`/`signal_number` cuando aplica), `Cancelación solicitada` (desde CLI), `Cancelación exitosa` (ejecutada por el daemon), `Petición inválida` (cancelación sobre trabajos ya finalizados), `Rechazo de Validación` (comandos/parámetros inválidos) y `Solicitud rechazada: cola llena` (capacidad de trabajos activos excedida, RF-23/RF-25). También registra `Error interno del daemon` con `errno`/detalle en fallos críticos.
- **Lo que NO hace:** No genera una bitácora global de todo el sistema ajena al ciclo de vida de trabajos. No reemplaza `stderr` ni los mensajes del CLI. No implementa rotación/compresión, búsqueda, filtrado ni purga del archivo. No registra todos los errores menores del código base (solo los puntos críticos acordados). No persiste históricos complejos fuera del formato JSONL *append-only*.

---

## Estructura del módulo

```text
src/hermes/
├── include/
│   ├── data_paths.h
│   ├── event_log.h
│   ├── job.h
│   ├── timestamp.h
│   └── nlohmann/json.hpp
└── src/
    ├── event_log.cpp
    ├── main.cpp
    ├── cancel/cancel.cpp
    ├── job/job.cpp
    ├── scheduler/scheduler.cpp
    └── validator/validator.cpp
```

| Archivo / directorio | Responsabilidad |
|---|---|
| `include/event_log.h` | Declaración del enumerado `EventLevel` (`DEBUG`, `INFO`, `WARN`, `ERROR`) y de la clase `EventLog` con `log_event` (para trabajos con `job_id` explícito) y `log_event_system` (para eventos pre-creación/globales con `job_id: null`). |
| `src/event_log.cpp` | Implementación del logger. Genera la entrada JSON con `ts`, `job_id`, `level`, `message` y `context` opcional. Realiza escritura directa con descriptores POSIX (`open/write`), protegida con `flock(LOCK_EX)`, escritura atómica por línea y `fsync`. |
| `include/data_paths.h` | Añade inicialización de `events.jsonl` vacío junto a `jobs.json`, `config.json` y `jobs.lock`. Provee `rutaEventsLog()` reutilizando `rutaDatos()`. |
| `src/job/job.cpp` | Registra `"Job recibido"` al crear el trabajo. Mantiene integración con los eventos del ciclo de vida cuando aplica. |
| `src/scheduler/scheduler.cpp` | Núcleo del ciclo de vida. Registra `"Transición a RUNNING"` con PID, `"Transición a SUCCEEDED/FAILED/Cancelación exitosa"`, `"Error interno del daemon"` con `errno`/detalle y fallos de `fork/open`. |
| `src/main.cpp` | Punto de entrada CLI. Registra `"Cancelación solicitada"` **antes** de llamar a `cancelarJobDetallado()` (con `origen: "CLI"`, `accion: "SOLICITUD"`). Registra `"Petición inválida"` en casos `NO_EXISTE`/`NO_CANCELABLE`. |
| `src/cancel/cancel.cpp` | Lógica de cancelación. Ya no duplica el log de solicitud, delegando ese registro al CLI para garantizar el orden correcto. |
| `src/validator/validator.cpp` | Registra `"Rechazo de Validación"` con `comando_intentado`, `motivo_del_rechazo` y el valor inválido para comandos, programa, `request-id`, filtros, IDs y status. |
| `include/timestamp.h` | Reutilizado para generar la marca temporal con `obtenerFechaHoraActual()`. |
| `include/nlohmann/json.hpp` | Librería para serialización JSON utilizada por el logger. |

---

## Implementación de `.h`

### `include/event_log.h`

**Propósito:** Definir el contrato del logger para la bitácora JSONL.

**Dependencias:**
```cpp
#include <string>
#include "nlohmann/json.hpp"
```

**Definiciones:**

- `enum class EventLevel { DEBUG, INFO, WARN, ERROR }` - Niveles exigidos por la política de logging.
- `class EventLog` con constructor eliminado (`EventLog() = delete`). Expone únicamente métodos estáticos, sin estado global mutable compartido.

**Prototipos clave:**
```cpp
static bool log_event(unsigned int job_id,
                      EventLevel level,
                      const std::string &message,
                      const nlohmann::json &extra = nlohmann::json::object());

static bool log_event_system(EventLevel level,
                             const std::string &message,
                             const nlohmann::json &extra = nlohmann::json::object());

static std::string level_to_string(EventLevel level);
```

- `log_event`: Para eventos asociados a un **trabajo real**. El `job_id` se pasa explícitamente (cumpliendo el requisito de "ningún log sin su respectivo Job ID").
- `log_event_system`: Para eventos **pre-creación** o **globales del daemon** (validaciones fallidas antes de crear el job, errores en `fork/open`, peticiones inválidas donde aplica). Escribe `job_id` como `null` nativo en JSON.

### `include/data_paths.h`

Se amplió `inicializarDatos()` para crear `events.jsonl` vacío si no existe (junto a `jobs.json`, `config.json`, `jobs.lock`). Se añadió:
```cpp
inline std::string rutaEventsLog() {
    return rutaDatos("events.jsonl");
}
```
Esto garantiza que el archivo se ubique **dinámicamente** en el mismo directorio que `jobs.json`.

---

## Implementación de `.cpp`

### `src/event_log.cpp`

El objetivo es garantizar **escritura append-only, serializada entre procesos (CLI y daemon) y con `job_id` siempre presente**.

**Flujo interno:**

1. **Construcción de la entrada:** Se crea un objeto `nlohmann::json` con `ts = obtenerFechaHoraActual()`, `level` vía `level_to_string`, `message` y, si `extra` es un objeto no vacío, se añade `context`. Para `log_event` se asigna `job_id` como `std::to_string(job_id)`. Para `log_event_system` se asigna `nullptr` para obtener `null` nativo en JSON.
2. **Apertura y bloqueo:** `escribirLineaJsonl()` abre con `O_WRONLY | O_APPEND | O_CREAT` (0644). Adquiere bloqueo exclusivo con `flock(fd, LOCK_EX)`. Esto serializa todas las escrituras al archivo desde distintos procesos.
3. **Escritura atómica por línea:** Se formatea con `entrada.dump() + "\n"` y se escribe con `write()` en bucle (manejando `EINTR`).
4. **Consistencia:** Se hace `fsync(fd)`, se libera `flock` y se cierra el descriptor.
5. **Tolerancia a errores:** En caso de fallo se registra en `stderr` pero no se interrumpe el flujo principal.

### `src/scheduler/scheduler.cpp`

Se integró el logging en los puntos críticos del ciclo de vida:

- **`guardarPid`**: Tras guardar el PID real, registra `"Transición a RUNNING"` con `{"pid": <pid_hijo>}`. Si hay `cancel_requested` previo, registra también un evento `DEBUG` para trazarlo.
- **`finalizarTrabajo`**: Determina el resultado. Si hubo `cancel_requested` -> `"Cancelación exitosa"` con `{"estado_previo": "RUNNING", "exit_code": ...}`. Si `procesoValido && codigoSalida == 0` -> `"Transición a SUCCEEDED"` con `{"exit_code": 0}`. En otro caso -> `"Transición a FAILED"` con `{"exit_code": ..., "signal_number": ...}` cuando fue terminado por señal (`WIFSIGNALED`).
- **`registrarFallo`**: En fallos de lanzamiento o excepciones del trabajador, registra `"Error interno del daemon"` con `{"exit_code", "detalle", "errno"}`. Si hubo cancelación solicitada, se clasifica como `"Cancelación exitosa"`.
- **`iniciarSchedulerSiNecesario`**: Registra `"Error interno del daemon"` en fallos de `open("scheduler.lock")` y `fork()` con `{"funcion", "errno", "detalle"}`.
- **`reservarTrabajo`**: Se eliminó el log redundante `"Cambio de estado"` (queda cubierto por `"Transición a RUNNING"` con PID).

### `src/main.cpp`

- **Recepción de comando / validaciones:** `validarComando` ya loguea `Rechazo de Validación` con `job_id: null`.
- **`cancel`**: Se registra `"Cancelación solicitada"` **inmediatamente después** de validar el ID y **antes** de `cancelarJobDetallado()`, con `{"origen": "CLI", "accion": "SOLICITUD"}`. Esto garantiza el orden semántico correcto independientemente de la velocidad del daemon. Si `cancelarJobDetallado()` devuelve `NO_EXISTE` o `NO_CANCELABLE`, se registra `"Petición inválida"` con `job_id: null`, `comando_intentado`, `motivo` y `estado_actual` cuando aplica.
- **`job`**: Los rechazos de `validarRequestId`/`validarPrograma` generan `Rechazo de Validación` con `job_id: null`.

### `src/validator/validator.cpp`

Se añadieron logs `WARN` con `log_event_system` para rechazos pre-creación con contexto claro: `comando_intentado`, `motivo_del_rechazo` y el campo inválido correspondiente (`programa_intentado`, `request_id_intentado`, `tipo_filtro_intentado`, `id_intentado`, `status_intentado`).

### `src/cancel/cancel.cpp`

Se removió el log duplicado de solicitud de cancelación. Ahora solo se encarga de actualizar el estado en `jobs.json` (marcar `cancel_requested`, enviar señal o cancelar en cola). El registro de la **solicitud del usuario** pasa a ser responsabilidad del CLI para garantizar el orden correcto.

---

## Integración con otros módulos

- **Con `data_paths.h`:** `event_log` obtiene la ruta del archivo mediante `rutaEventsLog()` que reutiliza `inicializarDatos()`, garantizando el mismo directorio que `jobs.json`.
- **Con `timestamp.h`:** Se reutiliza `obtenerFechaHoraActual()` para estandarizar la marca temporal `ts`.
- **Con `job.h` / `status.h`:** Se aprovechan los estados existentes (`QUEUED`, `RUNNING`, `SUCCEEDED`, `FAILED`, `CANCELED`) para clasificar las transiciones y las peticiones inválidas.
- **Con `nlohmann/json.hpp`:** Serialización directa con `.dump()` para generar JSON compacto por línea.
- **Con `main.cpp`:** El CLI registra la solicitud de cancelación antes de actuar y los rechazos pre-creación. También inicia el scheduler y coordina el flujo.
- **Con `scheduler.cpp`:** Es el principal emisor de eventos `INFO/ERROR` del ciclo de vida (arranque con PID, finalización, fallos internos).
- **Con `validator.cpp`:** Emite `WARN` para rechazos de validación sin necesidad de tener un `job_id` asignado.

---

## Ejemplo de funcionamiento

### Escenario 1: Job exitoso

**Comando ejecutado:**
```bash
cd /mnt/c/Users/alan/Desktop/CUCEI/Proyecto_Sistemas_Avanzados/ppl/src/hermes
./hermes job echo "test-completo"
sleep 4
cat ~/.local/share/hermes/data/events.jsonl
```

**Resultado en consola (relevante):**
```text
job ID: 1
PID: 2400
```

**Contenido en disco (`~/.local/share/hermes/data/events.jsonl`):**
```json
{"context":{"argumentos":["test-completo"],"programa":"echo"},"job_id":"1","level":"INFO","message":"Job recibido","ts":"2026-10-25 18:06:36"}
{"context":{"pid":2400},"job_id":"1","level":"INFO","message":"Transición a RUNNING","ts":"2026-10-25 18:06:36"}
{"context":{"exit_code":0},"job_id":"1","level":"INFO","message":"Transición a SUCCEEDED","ts":"2026-10-25 18:06:36"}
```

### Escenario 2: Cancelación en ejecución

**Comando ejecutado:**
```bash
./hermes job sleep 20
sleep 2
./hermes cancel 8
sleep 4
cat ~/.local/share/hermes/data/events.jsonl
```

**Resultado en consola:**
```text
job ID: 8
PID: 3863
Cancelación solicitada para el Job: 8
```

**Contenido en disco (`~/.local/share/hermes/data/events.jsonl`):**
```json
{"context":{"argumentos":["20"],"programa":"sleep"},"job_id":"8","level":"INFO","message":"Job recibido","ts":"2026-10-25 18:39:34"}
{"context":{"pid":3863},"job_id":"8","level":"INFO","message":"Transición a RUNNING","ts":"2026-10-25 18:39:34"}
{"context":{"accion":"SOLICITUD","origen":"CLI"},"job_id":"8","level":"INFO","message":"Cancelación solicitada","ts":"2026-10-25 18:39:44"}
{"context":{"estado_previo":"RUNNING","exit_code":-15},"job_id":"8","level":"INFO","message":"Cancelación exitosa","ts":"2026-10-25 18:39:44"}
```

### Escenario 3: Cancelación sobre job ya finalizado

**Comando ejecutado:**
```bash
./hermes job echo "rapido"
sleep 3
./hermes cancel 3
cat ~/.local/share/hermes/data/events.jsonl
```

**Resultado en consola:**
```text
El Job no se puede cancelar (estado: SUCCEEDED). Solo QUEUED o RUNNING.
```

**Contenido en disco (línea relevante):**
```json
{"context":{"comando_intentado":"cancel","estado_actual":"NO_CANCELABLE","job_id_intentado":3,"motivo":"cancelacion_sobre_trabajo_ya_finalizado"},"job_id":null,"level":"WARN","message":"Petición inválida","ts":"2026-10-25 18:12:02"}
```

### Escenario 4: Rechazos de validación pre-creación

**Comando ejecutado:**
```bash
./hermes job ""
./hermes cancel abc
./hermes filter foo bar
cat ~/.local/share/hermes/data/events.jsonl
```

**Contenido en disco (líneas relevantes):**
```json
{"context":{"comando_intentado":"job","motivo_del_rechazo":"Programa vacio","programa_intentado":""},"job_id":null,"level":"WARN","message":"Rechazo de Validación","ts":"2026-10-25 18:13:20"}
{"context":{"comando_intentado":"cancel","id_intentado":"abc","motivo_del_rechazo":"ID mal formado"},"job_id":null,"level":"WARN","message":"Rechazo de Validación","ts":"2026-10-25 18:13:25"}
{"context":{"comando_intentado":"filter","motivo_del_rechazo":"Filtro no reconocido","tipo_filtro_intentado":"foo"},"job_id":null,"level":"WARN","message":"Rechazo de Validación","ts":"2026-10-25 18:13:30"}
```

**Nota:** Todas las líneas son objetos JSON independientes (JSONL), válidas al validar con `python3`. El archivo se encuentra en `~/.local/share/hermes/data/events.jsonl`, mismo directorio que `jobs.json`. Cada entrada contiene obligatoriamente `ts`, `job_id`, `level` y `message`.
