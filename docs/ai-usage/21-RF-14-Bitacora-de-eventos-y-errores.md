# Uso de inteligencia artificial

# 14. RF-14 Bitácora de eventos y errores

## Objetivo

Implementar la bitácora de eventos y errores del sistema "Hermes" con marca temporal e identificador de trabajo obligatorios. 

Se buscaba que el sistema produjera una traza operativa en formato **JSON Lines (JSONL)**, ubicada dinámicamente en el mismo directorio que `jobs.json` mediante la infraestructura de `data_paths.h`. Dicha bitácora debía registrar el ciclo de vida de los trabajos (recepción, arranque, finalización, cancelación), peticiones inválidas, rechazos de validación y errores internos del daemon, respetando los niveles `DEBUG`, `INFO`, `WARN` y `ERROR`. Además, se exigía que **toda línea contuviera siempre la llave `job_id`** (con valor `null` para eventos globales/pre-creación) y que la escritura fuera **append-only**.

--- 

## Prompt 1

```text
Actúa como un ingeniero de software experto en C++17. Vamos a implementar la feature "Bitácora de eventos y errores" en el proyecto "hermes": el sistema deberá producir una bitácora de eventos operativos y errores con marca temporal e identificador de trabajo.
Para desarrollar esta funcionalidad respetando la arquitectura, ejecuta este proceso en dos fases:
Fase 1: Adquisición de Contexto
Explora el repositorio y analiza los siguientes componentes clave para entender los estándares del proyecto antes de escribir código:
1. docs/technical-guide/2-Nucleo del proyecto/Estructura del proyecto.md (y el árbol general de directorios): Para comprender la estricta separación entre cabeceras (include/) y código fuente (src/).
2. src/hermes/include/data_paths.h: Analiza este archivo, ya que el nuevo archivo de bitácora (ej. events.jsonl) deberá inicializarse aquí mismo y guardarse dinámicamente en el mismo directorio que jobs.json.
3. src/hermes/include/timestamp.h y src/hermes/include/job.h: Para estandarizar las marcas temporales (ISO 8601) y extraer de forma segura el Job ID.
4. docs/technical-guide/2-Nucleo del proyecto/RF-11.stderr.md y RF-06.status.md: Para conocer las directrices de manejo de errores y estados.
5. src/hermes/include/nlohmann/json.hpp: La bitácora se estructurará usando esta librería.
Fase 2: Ejecución de la Skill AGENTS.MD
Una vez asimilado el contexto, activa tu skill AGENTS.MD para guiar el desarrollo. Empleando los lineamientos de la skill, genera una propuesta de diseño e implementación modular (nuevos archivos .h/.cpp o modificaciones a los existentes) con estos requisitos innegociables:
- Todo evento y error debe registrar obligatoriamente su marca temporal y Job ID.
- El archivo físico debe utilizar el formato JSON Lines (JSONL) (donde cada evento es un objeto JSON independiente en una nueva línea, sin corchetes de arreglo) para permitir operaciones append-only eficientes, seguras contra fallos y de bajo consumo de memoria.
- El archivo se ubicará dinámicamente usando la infraestructura de data_paths.h.
Entrégame primero un resumen rápido de tus hallazgos en la Fase 1 y tu plan de acción estructurado con la skill en la Fase 2. No escribas la implementación final en C++ hasta que yo apruebe el diseño.
```

---

## Resultado 1

La IA realizó correctamente la fase de adquisición de contexto, identificando la estricta separación `include/`/`src/`, el uso de `nlohmann/json`, `timestamp.h`, `job.h` y el patrón de rutas dinámicas con `data_paths.h`. 

Propuso un módulo `event_log` con `event_log.h/.cpp`, añadir un getter para `events.jsonl` en `data_paths.h`, usar escritura **append-only** con `std::ofstream` en modo `std::ios::app` y pasar el `job_id` explícitamente (rechazando un *singleton* global). 

Tras recibir las aprobaciones (nombre `events.jsonl`, namespace `hermes`, paso explícito de `job_id`, niveles `DEBUG/INFO/WARN/ERROR`, integración solo en puntos específicos) generó la primera versión funcional con `EventLog::log_event`, creación de `events.jsonl` desde `data_paths` e integración inicial en `crearJob`, `actualizarEstadoJob`, `actualizarResultadoJob` y `cancelarJobDetallado`.

---

## Prompt 2

```text
Actúa como un ingeniero de software experto en C++17. La estructura base del logger en formato JSON Lines (events.jsonl) ha quedado perfecta. Ahora necesitamos expandir su integración en el resto del código del repositorio conanlag/hermes para cumplir a cabalidad con el requisito RF-14 (Bitácora de eventos y errores).

Tu tarea es inyectar llamadas al logger en los puntos críticos del ciclo de vida de los trabajos, respetando la siguiente Política de Logging:

Nivel INFO (Flujo normal de operaciones):
Transición a RUNNING: Cuando el planificador/sistema hace el fork()/exec() y el trabajo arranca. Contexto: PID del proceso hijo.
Transición a SUCCEEDED: Cuando el trabajo termina exitosamente (código de salida 0). Contexto: exit_code, tiempo de ejecución (si está disponible).
Cancelación exitosa: Cuando la señal de cancelación surte efecto y el proceso muere por intervención del usuario. Contexto: estado previo (ej. RUNNING).

Nivel WARN (Anomalías y errores de usuario no fatales):
Peticiones inválidas: Como la cancelación de un trabajo ya terminado (SUCCEEDED/FAILED). Contexto: estado_actual.
Rechazos de Validación: Cuando validator.cpp rechaza un trabajo por comando inválido o argumentos incorrectos. Contexto: motivo del rechazo, comando_intentado.

Nivel ERROR (Fallos del sistema o del trabajo):
Transición a FAILED: Cuando el trabajo termina con un código distinto de 0 o es asesinado por una señal inesperada (ej. Segmentation Fault). Contexto: exit_code, signal_number.
Errores internos del daemon: Fallos críticos como que fork() devuelva error, fallos de lectura/escritura en jobs.json o errores de memoria. Contexto: código de error del sistema operativo (errno) o descripción de la excepción.

Plan de Acción Requerido:
Analiza los archivos .cpp correspondientes (probablemente process.cpp, scheduler.cpp, status.cpp, validator.cpp, etc.) para identificar exactamente dónde ocurren estos eventos.

Entrégame primero un resumen de los archivos y funciones específicas que planeas modificar para implementar esta política. Espera mi aprobación antes de generar el código C++ definitivo.
```

---

## Resultado 2

La IA realizó un análisis detallado por archivo (`scheduler.cpp`, `process.cpp`, `validator.cpp`, `main.cpp`, `cancel.cpp`, `job.cpp`, `storage.cpp`). Identificó correctamente que **no existía forma de loguear eventos pre-creación** sin violar "todo log debe llevar `job_id`".

Propuso la **Opción B**: añadir `EventLog::log_event_system` con `job_id: null` nativo (usando `nullptr` con `nlohmann::json`). Tras la aprobación con ese ajuste, expandió la integración a `scheduler.cpp` (`Transición a RUNNING`, `Transición a SUCCEEDED/FAILED/CANCELED`, `Error interno del daemon`), `validator.cpp` (`Rechazo de Validación`), `main.cpp` (`Petición inválida`) y enriqueció `registrarFallo/finalizarTrabajo`.

---

## Prompt 3

```text
me parece que esta mal todavia el orden de logueo cuando se cancela un trabajo, primero se registra el cambio de estado y despues la solicitud realizada, asi le dejamos o se puede solucionar?
...
ahora sí queda en el orden correcto.
parece que ya, user@Alan:/mnt/c/Users/alan/Desktop/CUCEI/Proyecto_Sistemas_Avanzados/ppl/src/hermes$ cat ~/.local/share/hermes/data/events.jsonl
{"context":{"argumentos":["20"],"programa":"sleep"},"job_id":"8","level":"INFO","message":"Job recibido",...}
{"context":{"pid":3863},"job_id":"8","level":"INFO","message":"Transición a RUNNING",...}
{"context":{"accion":"SOLICITUD","origen":"CLI"},"job_id":"8","level":"INFO","message":"Cancelación solicitada",...}
{"context":{"estado_previo":"RUNNING","exit_code":-15},"job_id":"8","level":"INFO","message":"Cancelación exitosa",...}
no rompiste alguna otra cosa verdad?
```

---

## Resultado 3

Tras detectar el problema de **concurrencia entre CLI y daemon**, se corrigió de forma progresiva:

1. Se movió el log `"Cancelación solicitada"` al CLI, pero persistía el desorden por escrituras simultáneas.
2. Se reescribió `event_log.cpp` para usar **escritura directa con `open/write` + `flock(LOCK_EX)` + `fsync`** serializando todas las llamadas a `events.jsonl` entre procesos.
3. Se **logueó la solicitud desde `main.cpp` ANTES de llamar a `cancelarJobDetallado()`**, eliminando el log duplicado desde `cancel.cpp`. 
4. Se removió el log redundante `"Cambio de estado"` al reservar el trabajo en `scheduler.cpp`.

Con esto se logró el orden semántico correcto: `Transición a RUNNING` -> `Cancelación solicitada` (origen `CLI`) -> `Cancelación exitosa` (ejecutada por el daemon).

---

# Modificaciones

**Estado de la resolución:** [Modificado]: La IA generó la base correcta, pero presentó deficiencias técnicas que requirieron corrección manual (ausencia de `log_event_system` para eventos pre-creación, orden incorrecto de logs por concurrencia CLI/daemon y necesidad de serialización con `flock`).

**Revisión realizada:** 

Se verificó la arquitectura propuesta contra el proyecto Hermes: correcta separación `include/src`, uso de `nlohmann/json`, reutilización de `data_paths.h` y `timestamp.h`. Se detectó que el diseño inicial con `std::ofstream` era vulnerable a **race condition** entre el proceso CLI y el daemon del scheduler al escribir en el mismo `events.jsonl`. También se observó que registrar `"Cancelación solicitada"` desde `cancel.cpp` era tarde, y que dejar `"Cambio de estado"` al reservar era redundante frente a `"Transición a RUNNING"` con `pid`. Además, se corrigió la necesidad de mantener `job_id` siempre presente (exigiendo `log_event_system` con `job_id: null`).

**Cambios aplicados:**

- **`src/hermes/include/data_paths.h`**: Añadida inicialización de `events.jsonl` vacío y función `rutaEventsLog()`.
- **`src/hermes/include/event_log.h` / `src/hermes/src/event_log.cpp`**: Creación del módulo `EventLog`. Se añadió `log_event_system` con `job_id` a `nullptr`. Se reemplazó escritura con `std::ofstream` por escritura con descriptores POSIX (`open/write`) protegida con `flock(LOCK_EX)`, escritura atómica por línea y `fsync` para mayor consistencia.
- **`src/hermes/src/scheduler/scheduler.cpp`**: Integración de logging en `guardarPid` (`Transición a RUNNING` con `pid`), `finalizarTrabajo` (`Transición a SUCCEEDED/FAILED/Cancelación exitosa` con `exit_code`/`signal_number`), `registrarFallo` (`Error interno del daemon`) e `iniciarSchedulerSiNecesario` (`fork/open` con `errno`). Se eliminó el log redundante de `reservarTrabajo`.
- **`src/hermes/src/main.cpp`**: Se registra `"Cancelación solicitada"` **antes** de `cancelarJobDetallado()` con `{"origen":"CLI","accion":"SOLICITUD"}`. Se añaden logs `WARN` `Petición inválida` para `NO_EXISTE` y `NO_CANCELABLE`.
- **`src/hermes/src/cancel/cancel.cpp`**: Se elimina el log duplicado de cancelación (pasando la responsabilidad al CLI). Se mantiene el enriquecimiento con `event_log.h` solo donde aplica.
- **`src/hermes/src/validator/validator.cpp`**: Se añaden `Rechazo de Validación` con `comando_intentado`, `motivo_del_rechazo` y el valor inválido para `validarComando`, `validarPrograma`, `validarRequestId`, `validarTipoFiltro`, `validarIdTexto`, `validarStatusTexto`.

**Prueba agregada:** Compilación con `make` en entorno WSL/Linux, validación con `./hermes` de flujo normal (`echo`), cancelación en ejecución (`sleep` + `cancel`), cancelación sobre job finalizado, rechazos pre-creación (`job ""`, `cancel abc`, `filter foo bar`) y verificación de validez JSON por línea con `python3`.

---

## Implementación de feature

Se integró la **Bitácora de eventos y errores (RF-14)** en el ciclo de vida de Hermes. El archivo `~/.local/share/hermes/data/events.jsonl` se crea automáticamente por `data_paths.h` en el mismo directorio que `jobs.json`. 

Cada entrada es un objeto JSON independiente (JSONL), con `ts` (timestamp del proyecto), `job_id` (`string` para eventos asociados a un trabajo o `null` para eventos globales), `level` (`DEBUG|INFO|WARN|ERROR`) y `message`. Se utiliza `context` opcional para añadir información relevante (`pid`, `exit_code`, `signal_number`, `errno`, `comando_intentado`, `motivo_del_rechazo`, etc.).

Los puntos cubiertos son: recepción de job, transición a `RUNNING` con PID, transición a `SUCCEEDED`/`FAILED`, cancelación solicitada desde CLI, cancelación exitosa por intervención del daemon, peticiones inválidas al cancelar trabajos ya finalizados, rechazos de validación pre-creación y errores internos del daemon.

---

## Modificación de archivo

### `src/hermes/include/event_log.h`
```cpp
#ifndef EVENT_LOG_H
#define EVENT_LOG_H

#include <string>

#include "nlohmann/json.hpp"

namespace hermes {

enum class EventLevel {
    DEBUG,
    INFO,
    WARN,
    ERROR
};

class EventLog {
public:
    EventLog() = delete;

    static bool log_event(unsigned int job_id,
                          EventLevel level,
                          const std::string &message,
                          const nlohmann::json &extra = nlohmann::json::object());

    static bool log_event_system(EventLevel level,
                                 const std::string &message,
                                 const nlohmann::json &extra = nlohmann::json::object());

    static std::string level_to_string(EventLevel level);
};

} // namespace hermes

#endif
```

### `src/hermes/src/event_log.cpp` (fragmento clave - serialización con flock)
```cpp
static bool escribirLineaJsonl(const std::string &ruta, const nlohmann::json &entrada) {
    int fd = open(ruta.c_str(), O_WRONLY | O_APPEND | O_CREAT, 0644);
    if (fd == -1) {
        return false;
    }

    if (flock(fd, LOCK_EX) == -1) {
        close(fd);
        return false;
    }

    std::string linea = entrada.dump() + "\n";
    ssize_t escrito = 0;
    const char *buf = linea.c_str();
    size_t restante = linea.size();
    while (restante > 0) {
        escrito = write(fd, buf, restante);
        if (escrito <= 0) {
            if (errno == EINTR) {
                continue;
            }
            flock(fd, LOCK_UN);
            close(fd);
            return false;
        }
        buf += escrito;
        restante -= static_cast<size_t>(escrito);
    }

    fsync(fd);
    flock(fd, LOCK_UN);
    close(fd);

    return true;
}
```

### `src/hermes/src/main.cpp` (cancelación - log antes de actuar)
```cpp
    unsigned int id =
        static_cast<unsigned int>(
            stoul(argv[2])
        );

    hermes::EventLog::log_event(id, hermes::EventLevel::INFO, "Cancelación solicitada", {
        {"origen", "CLI"},
        {"accion", "SOLICITUD"}
    });

    ResultadoCancelacion cr = cancelarJobDetallado(id);

    if (!cr.exito) {
        ...
        // Petición inválida con job_id null si NO_EXISTE / NO_CANCELABLE
        ...
        return 1;
    }

    if (cr.codigo == CodigoCancelacion::CANCELADO) {
        info("Job cancelado: ", id);
    } else {
        info("Cancelación solicitada para el Job: ", id);
    }
```

### `src/hermes/include/data_paths.h` (adición)
```cpp
    crearArchivoSiFalta(
        directorio / "events.jsonl",
        ""
    );

    ...
}

inline std::string rutaEventsLog() {
    return rutaDatos("events.jsonl");
}
```

---

# Implementación final

## Flujo probado

### 1) Flujo normal exitoso
```bash
./hermes job echo "test-completo"
sleep 4
cat ~/.local/share/hermes/data/events.jsonl
```

**Salida:**
```json
{"context":{"argumentos":["test-completo"],"programa":"echo"},"job_id":"1","level":"INFO","message":"Job recibido","ts":"2026-10-25 18:06:36"}
{"context":{"pid":2400},"job_id":"1","level":"INFO","message":"Transición a RUNNING","ts":"2026-10-25 18:06:36"}
{"context":{"exit_code":0},"job_id":"1","level":"INFO","message":"Transición a SUCCEEDED","ts":"2026-10-25 18:06:36"}
```

### 2) Cancelación en ejecución (orden correcto)
```bash
./hermes job sleep 20
sleep 2
./hermes cancel 8
sleep 4
cat ~/.local/share/hermes/data/events.jsonl
```

**Salida:**
```json
{"context":{"argumentos":["20"],"programa":"sleep"},"job_id":"8","level":"INFO","message":"Job recibido","ts":"2026-10-25 18:39:34"}
{"context":{"pid":3863},"job_id":"8","level":"INFO","message":"Transición a RUNNING","ts":"2026-10-25 18:39:34"}
{"context":{"accion":"SOLICITUD","origen":"CLI"},"job_id":"8","level":"INFO","message":"Cancelación solicitada","ts":"2026-10-25 18:39:44"}
{"context":{"estado_previo":"RUNNING","exit_code":-15},"job_id":"8","level":"INFO","message":"Cancelación exitosa","ts":"2026-10-25 18:39:44"}
```

### 3) Cancelación sobre job finalizado (WARN)
```json
{"context":{"comando_intentado":"cancel","estado_actual":"NO_CANCELABLE","job_id_intentado":3,"motivo":"cancelacion_sobre_trabajo_ya_finalizado"},"job_id":null,"level":"WARN","message":"Petición inválida","ts":"2026-10-25 18:12:02"}
```

### 4) Rechazos de validación pre-creación (WARN, job_id null)
```json
{"context":{"comando_intentado":"job","motivo_del_rechazo":"Programa vacio","programa_intentado":""},"job_id":null,"level":"WARN","message":"Rechazo de Validación","ts":"2026-10-25 18:13:20"}
{"context":{"comando_intentado":"cancel","id_intentado":"abc","motivo_del_rechazo":"ID mal formado"},"job_id":null,"level":"WARN","message":"Rechazo de Validación","ts":"2026-10-25 18:13:25"}
{"context":{"comando_intentado":"filter","motivo_del_rechazo":"Filtro no reconocido","tipo_filtro_intentado":"foo"},"job_id":null,"level":"WARN","message":"Rechazo de Validación","ts":"2026-10-25 18:13:30"}
```

**Validación de formato:** Todas las líneas validadas como JSON válido con `python3 -c "import json,sys; json.loads(...)"` -> `OK`.

---

# Aprendizaje

Esta interacción dejó varias lecciones importantes:

- **Arquitectura primero:** Entender la separación `include/src`, convenciones (`#ifndef`, `const&`, `enum class`) y la infraestructura existente (`data_paths`, `timestamp`, `nlohmann/json`) ahorra tiempo y evita romper el proyecto.
- **Serialización entre procesos:** Dos procesos escribiendo al mismo archivo con `ofstream` causa **race conditions**. Usar `open()` + `flock(LOCK_EX)` + `write()` es la forma correcta para asegurar **append-atómico** entre CLI y daemon.
- **Semántica sobre timestamps:** El orden cronológico exacto no basta si no refleja la **causalidad**. Loguear la acción del usuario **antes** de invocar la operación es más correcto semánticamente para una bitácora auditables.
- **Diseño defensivo:** Exigir `job_id` explícito para logs de trabajo y añadir `log_event_system` con `job_id: null` permite cubrir eventos pre-creación sin violar la regla ni inventar IDs.
- **Iteración con la IA:** La primera propuesta fue buena, pero las deficiencias aparecieron con pruebas reales. Saber **cuándo aceptar, cuándo corregir y cuándo insistir** con pruebas fue clave para llegar a una solución correcta y minimalista.
- **JSONL práctico:** Formato ideal para bitácoras operativas: fácil de parsear línea a línea, seguro para `append`, liviano y apto para análisis posterior sin cargar todo el archivo.

# AGENTS.md inicial

# Contexto del Proyecto: Hermes
Hermes es una herramienta escrita en C++ moderno. Utiliza `make` para la compilación, separa estrictamente las declaraciones (`.h`) de las implementaciones (`.cpp`), y utiliza la librería `nlohmann/json` para la persistencia de datos (serialización a disco). El entorno de desarrollo es VS Code en Windows, pero la compilación y ejecución suceden nativamente en WSL (Linux).

# Rol de la IA
Actúa como un Desarrollador C++ Senior. Tu objetivo es ayudar al usuario a desarrollar nuevas características (features) escribiendo código limpio, eficiente y que respete las convenciones establecidas. Por cada implementacion que hagas ASEGURATE (OBLIGATORIO) que el usuario comprenda que estas haciendo y porque lo haces, ese esencial que el usuario pueda defender las implementaciones.

# Reglas Estrictas de Desarrollo
1. **Respetar la Arquitectura:** Cualquier nueva función debe integrarse lógicamente en los módulos existentes (`job`, `filter`, `status`, etc.) o proponer un nuevo módulo con su respectivo `.h` y `.cpp`.
2. **Convenciones de C++:** 
   - Usa siempre guardas de inclusión (`#ifndef`, `#define`, `#endif`) en los `.h`.
   - Utiliza referencias constantes (`const auto&`, `const string&`) para evitar copias innecesarias de memoria.
   - Maneja estados con `enum class`.
   - Utiliza `try/catch` para operaciones de I/O o parseo de JSON.
3. **Cero Código "Mágico":** Antes de generar bloques de código, explica brevemente *dónde* se va a colocar y *por qué* elegiste esa solución.
4. **Makefile:** Si agregamos un nuevo archivo `.cpp`, recuérdale al usuario cómo debe actualizar el `Makefile` para que el enlazador no falle.

# Flujo de Trabajo para Nuevas Features
Cuando el usuario solicite una nueva característica, sigue exactamente estas 4 fases en orden:

* **Fase 1: Análisis y Diseño del Contrato (.h)**
  - Identifica qué archivos existentes se verán afectados.
  - Define las nuevas estructuras (`structs`), estados (`enum class`) o prototipos de funciones necesarias.
  - Presenta el código para actualizar los archivos `.h` correspondientes.

* **Fase 2: Implementación de Lógica (.cpp)**
  - Una vez aprobados los contratos, desarrolla la lógica interna.
  - Asegura el correcto manejo de memoria y persistencia (lectura/escritura de JSON si aplica).

* **Fase 3: Integración**
  - Conecta la nueva feature con el punto de entrada principal (`main.cpp`).
  - Asegura que el flujo de ejecución llegue correctamente a la nueva función.

* **Fase 4: Pruebas y Compilación (WSL)**
  - Proporciona los comandos exactos de compilación (`make`) y ejecución (`./hermes [argumentos]`) para que el usuario valide el código en su terminal WSL.