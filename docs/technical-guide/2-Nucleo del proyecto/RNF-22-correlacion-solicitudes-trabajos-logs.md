# RNF-22 — Correlación entre solicitudes, trabajos y logs

## Descripción

El requisito no funcional RNF-22 garantiza la trazabilidad completa entre una solicitud externa, el trabajo que se ejecuta y la bitácora de eventos (`events.jsonl`). 

Con este requisito, cualquier `request_id` proporcionado por el usuario al crear un trabajo debe poder cruzarse directamente con su `job_id` en `jobs.json` y con todos los eventos asociados en la bitácora, permitiendo auditoría, depuración e integración con sistemas externos.

## Objetivo

Garantizar que la bitácora permita correlacionar una solicitud con su trabajo, asegurando que el identificador de solicitud viaje desde el CLI hasta la persistencia y quede inyectado en los eventos relevantes.

> *"La bitácora deberá permitir correlacionar una solicitud con su trabajo."*

**Consideraciones actuales:**

- **Lo que hace:**
  - Soporte opcional de `--request-id` en el subcomando `job`.
  - Almacenamiento de `request_id` en la estructura `Job` y persistido en `jobs.json` cuando se proporciona.
  - Propagación del `request_id` desde CLI → `crearJob()` → persistencia → scheduler.
  - Enriquecimiento del `context` de eventos clave con `request_id`: `"Job recibido"`, `"Transición a RUNNING"`, `"Transición a SUCCEEDED"`, `"Transición a FAILED"`, `"Cancelación exitosa"` y `"Error interno del daemon"`.
  - Soporte para reutilización de trabajos duplicados por `request_id` manteniendo la correlación.
  - Retrocompatible con trabajos existentes sin `request_id`.
  - Ubicación centralizada de persistencia en `~/.local/share/hermes/data/`.

- **Lo que NO hace:**
  - No obliga a proporcionar `request_id`. Si no se envía, el sistema funciona exactamente como antes.
  - No añade `request_id` a eventos a nivel sistema (`log_event_system()`), ya que no están asociados a un `job_id` concreto.
  - No fuerza un formato específico más allá de la validación con `validarRequestId()`.
  - No modifica el comportamiento de idempotencia más allá de aprovechar el `request_id` para detectar duplicados.

## Estructura del módulo

```text
src/hermes/
├── include/
│   ├── job.h
│   ├── validator.h
│   └── event_log.h
└── src/
    ├── main.cpp
    ├── job/
    │   └── job.cpp
    ├── scheduler/
    │   └── scheduler.cpp
    └── validator/
        └── validator.cpp
```

| Archivo / directorio | Responsabilidad |
|---|---|
| `include/job.h` / `src/job/job.cpp` | Define y gestiona el campo `request_id` en `Job`, persistencia y reutilización por duplicado. |
| `src/main.cpp` | Parseo de `--request-id` para el subcomando `job`, validación y paso a `crearJob()`. |
| `src/scheduler/scheduler.cpp` | Propagación vía `TrabajoPendiente`, enriquecimiento de eventos con `request_id` en su `context`. |
| `src/validator/validator.cpp` | Validación del formato de `request_id` mediante `validarRequestId()`. |
| `include/event_log.h` / `src/event_log.cpp` | Registro de eventos con `context` JSON opcional. |

## Implementación

### 1) Captura en CLI

En `main.cpp`, al procesar el subcomando `job`, se detecta el flag opcional:

```cpp
string requestId;
int indicePrograma = 2;

if (string(argv[2]) == "--request-id") {
    if (argc < 5) {
        error("Uso: hermes job --request-id <id> <programa> [argumentos..]");
        return 1;
    }

    ResultadoValidacion rr = validarRequestId(argv[3]);
    if (!rr.esValido) {
        error(rr.mensaje);
        return 1;
    }

    requestId = argv[3];
    indicePrograma = 4;
}
...
job = crearJob(programa, argumentos, requestId);
```

### 2) Modelo y persistencia

En `job.h`:

```cpp
struct Job {
    unsigned int job_id;
    int pid;
    string programa;
    vector<string> argumentos;
    Status status;
    std::string tiempo_recepcion;
    std::string tiempo_inicio;
    std::string tiempo_terminacion;
    int codigoSalida;
    std::string mensajeError;
    bool solicitudDuplicada = false;
    std::string request_id; // RNF-22: correlación solicitud-trabajo-logs
};
```

En `job.cpp`, al crear el job se persiste únicamente si no está vacío:

```cpp
json item;
...
if (!requestId.empty()) {
    item["request_id"] = requestId;
}
jobs.push_back(item);
```

Al reutilizar un job duplicado por `request_id`, se recupera su estado completo incluyendo `request_id` para mantener la correlación. En `obtenerJobPorId()`, también se carga desde `jobs.json` de forma opcional para asegurar compatibilidad con jobs antiguos.

### 3) Propagación por el scheduler

`TrabajoPendiente` fue ampliado para transportar el `request_id`:

```cpp
struct TrabajoPendiente {
    unsigned int id = 0;
    string programa;
    vector<string> argumentos;
    string request_id;
};
```

Al reservar el trabajo, se extrae desde `jobs.json`:

```cpp
if (item.contains("request_id") && item["request_id"].is_string()) {
    requestIdReservado = item["request_id"].get<string>();
}
...
trabajo.request_id = std::move(requestIdReservado);
```

Posteriormente, al registrar transiciones, se inyecta en el `context` del evento:

```cpp
nlohmann::json ctxRunning;
ctxRunning["pid"] = static_cast<int>(pid);
try {
    json jobs = leerJobsSeguros();
    for (const auto& item : jobs) {
        if (item.contains("job_id") && item["job_id"] == id &&
            item.contains("request_id") && item["request_id"].is_string()) {
            const string rid = item["request_id"].get<string>();
            if (!rid.empty()) {
                ctxRunning["request_id"] = rid;
            }
            break;
        }
    }
} catch (...) {
    // No bloquear el flujo si no se puede leer request_id
}
hermes::EventLog::log_event(id, hermes::EventLevel::INFO, "Transición a RUNNING", ctxRunning);
```

Este mismo patrón se aplica a `"Transición a SUCCEEDED"`, `"Transición a FAILED"`, `"Cancelación exitosa"` y `"Error interno del daemon"`. Además, `"Job recibido"` se enriquece desde `crearJob()`.

## Integración con otros módulos

- **`main.cpp`**: Punto de entrada para recibir `--request-id` desde el usuario.
- **`job.cpp`**: Lógica de creación, deduplicación e idempotencia por `request_id`.
- **`scheduler.cpp`**: Motor de ejecución que garantiza la propagación al primer y resto de eventos.
- **`storage.cpp`**: Persistencia atómica de `jobs.json` (ya existente, ahora con campo opcional).
- **`event_log.cpp`**: Almacenamiento de eventos JSONL con `context` flexible.
- **`validator.cpp`**: Validación de formato del `request_id`.

## Ejemplo de funcionamiento

### Creación con request-id

```bash
./hermes job --request-id test-123 /bin/echo hola
```

**Salida:**

```text
job ID: 62
PID: 67140
```

### Verificación de correlación

Los archivos se encuentran en `~/.local/share/hermes/data/`:

**`jobs.json` (fragmento):**

```json
{
  "job_id": 62,
  "pid": 67140,
  "pid_inicio": 4205371,
  "programa": "/bin/echo",
  "argumentos": ["hola"],
  "status": "SUCCEEDED",
  "request_id": "test-123",
  "sid": 27021,
  "tiempo_recepcion": "...",
  "tiempo_inicio": "...",
  "tiempo_terminacion": "...",
  "codigo_salida": 0
}
```

**`events.jsonl` (fragmento):**

```json
{"context":{"argumentos":["hola"],"programa":"/bin/echo","request_id":"test-123"},"job_id":"62","level":"INFO","message":"Job recibido","ts":"2026-10-27 20:24:47"}
{"context":{"pid":67140,"request_id":"test-123"},"job_id":"62","level":"INFO","message":"Transición a RUNNING","ts":"2026-10-27 20:24:47"}
{"context":{"exit_code":0,"request_id":"test-123"},"job_id":"62","level":"INFO","message":"Transición a SUCCEEDED","ts":"2026-10-27 20:24:47"}
```

**Resultado:** Con `request_id` se puede correlacionar directamente `request_id` ↔ `job_id` ↔ todos los eventos del trabajo.

## Notas

- **Retrocompatibilidad total:** Trabajos creados sin `--request-id` siguen funcionando sin cambios.
- **Opcional por diseño:** El campo solo se persiste e inyecta cuando está presente.
- **Centralización de datos:** Hermes utiliza `rutaDatos()` para resolver `~/.local/share/hermes/data/`.
- **Idempotencia existente:** Se mantiene la lógica de detección de solicitudes duplicadas por `request_id` con las mismas restricciones de programa/argumentos.
- **Trazabilidad completa:** Cubre la ruta end-to-end desde CLI hasta la bitácora.
