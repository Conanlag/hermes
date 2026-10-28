# RNF-28 — Persistencia atómica o recuperable

## Descripción

El requisito no funcional RNF-28 garantiza que las actualizaciones persistentes de Hermes sean atómicas o recuperables. En caso de una interrupción (corte de energía, señal, caída del proceso o fallo durante la escritura), `jobs.json` no debe quedar en un estado parcialmente actualizado ni inutilizable. 

Para lograrlo, el sistema utiliza un patrón de escritura atómica con archivo temporal, sincronización a disco, reemplazo atómico (`rename`) y un mecanismo de respaldo (`jobs.json.bak`) con restauración automática tanto perezosa como proactiva al arranque. Además, la bitácora `events.jsonl` se mantiene en modo adición continua para no perder eventos previos.

## Objetivo

Garantizar que las actualizaciones persistentes sean atómicas o recuperables; una interrupción durante la escritura no deberá dejar el repositorio de datos inutilizable.

> *"Las actualizaciones persistentes deberán ser atómicas o recuperables; una interrupción durante la escritura no deberá dejar el repositorio de datos inutilizable."*

**Consideraciones actuales:**

- **Lo que hace:**
  - Escritura atómica de `jobs.json` mediante `tmp + fsync(archivo) + rename + fsync(directorio)`.
  - Creación del respaldo `jobs.json.bak` con `link()` desde la última versión íntegramente válida justo antes del `rename`.
  - Protección ante `EXDEV` al detectar origen/destino en distintos sistemas de archivos.
  - Validación proactiva al arranque con `verificarYRestaurarJobsAlArranque()`: si `jobs.json` está corrupto/truncado/no parsea, lo restaura automáticamente desde `jobs.json.bak` (previamente validado), emite `WARN` vía `log_event_system()` y **no aborta** el arranque.
  - *Fallback* perezoso en `leerSinBloqueo()`: ante fallo de parseo de `jobs.json`, intenta leer `jobs.json.bak`, registra advertencia y repara `jobs.json` con `guardarAtomico()`.
  - Limpieza de archivos temporales huérfanos (`jobs.json.tmp.*`) al arranque con `limpiarTemporalesDeJobs()`.
  - `events.jsonl` se abre con `O_WRONLY | O_APPEND | O_CREAT`, con `flock()` y `fsync()` por escritura, garantizando que los logs anteriores no se pierdan.
  - Bloqueo con `mutexStorage` y `flock(LOCK_EX)` sobre `jobs.lock` durante todo el ciclo read-modify-write.

- **Lo que NO hace:**
  - No realiza una copia byte a byte innecesaria del respaldo: utiliza `link()` (hardlink) para mayor eficiencia y atomicidad lógica.
  - No fuerza atomicidad entre distintos sistemas de archivos (se detecta `EXDEV` y se informa con error claro).
  - No aborta el arranque si `jobs.json` y `jobs.json.bak` ambos están corruptos o ausentes: registra advertencia y continúa con normalidad.
  - No escribe directamente truncando `jobs.json` desde ningún otro módulo (únicamente `guardarAtomico()` lo gestiona).
  - No depende de `std::ofstream` con `std::ios::trunc` para actualizar `jobs.json`.

## Estructura del módulo

```text
src/hermes/
├── include/
│   ├── data_paths.h
│   ├── event_log.h
│   └── storage.h
└── src/
    ├── scheduler/
    │   └── scheduler.cpp
    ├── event_log.cpp
    └── storage/
        └── storage.cpp
```

| Archivo / directorio | Responsabilidad |
|---|---|
| `include/storage.h` | Declaración de `leerJobsSeguros()`, `modificarJobsSeguros()`, `limpiarTemporalesDeJobs()` y `verificarYRestaurarJobsAlArranque()`. |
| `src/storage/storage.cpp` | Escritura atómica con `fsync`, creación de respaldo con `link()`, recuperación perezosa, validación proactiva al arranque, limpieza de temporales y sincronización de directorio. |
| `include/event_log.h` / `src/event_log.cpp` | Escritura en `events.jsonl` en modo append (`O_APPEND`), con bloqueo y `fsync` por línea. |
| `include/data_paths.h` | Resolución de rutas a `~/.local/share/hermes/data/` e inicialización de archivos. |
| `src/scheduler/scheduler.cpp` | Orquestación del arranque: invoca `limpiarTemporalesDeJobs()`, `verificarYRestaurarJobsAlArranque()` y `recuperarTrabajosInterrumpidos()`. |

## Implementación de `.h` //SI APLICA

### `include/storage.h`

```cpp
#ifndef STORAGE_H
#define STORAGE_H

#include <functional>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

json leerJobsSeguros();
bool modificarJobsSeguros(const std::function<bool(json&)>& funcion);

/**
 * Elimina los archivos `jobs.json.tmp.*` que dejaron ejecuciones muertas.
 */
void limpiarTemporalesDeJobs();

/**
 * Verifica la integridad de jobs.json al arranque. Si está corrupto o truncado
 * y existe jobs.json.bak válido, lo restaura automáticamente sin interrumpir
 * el arranque. Emite un evento WARN en events.jsonl si se realiza la restauración.
 */
void verificarYRestaurarJobsAlArranque();

#endif
```

## Implementación de `.cpp` //SI APLICA

### `src/storage/storage.cpp`

#### 1) Escritura atómica duradera

```cpp
void guardarAtomico(const json& jobs) {
    // Escritura atómica: tmp + fsync + rename + fsync(dir)
    const string ruta = hermes::rutaDatos(NOMBRE_JOBS);
    const string respaldo = hermes::rutaDatos(NOMBRE_RESPALDO);

    namespace fs = std::filesystem;

    const fs::path rutaPath(ruta);
    const fs::path dirPath = rutaPath.parent_path();

    if (dirPath.empty()) {
        throw runtime_error("No se pudo determinar el directorio de datos para escritura atómica");
    }

    static std::atomic<unsigned long long> contador{0};

    const string temporal =
        ruta + ".tmp." + to_string(getpid()) + "." +
        to_string(contador.fetch_add(1));

    const string contenido = jobs.dump(4) + '\n';

    int descriptor = open(
        temporal.c_str(),
        O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC,
        0644
    );

    if (descriptor == -1) {
        const int error = errno;
        throw runtime_error(string("No se pudo crear el archivo temporal: ") + strerror(error));
    }

    bool renombrado = false;

    try {
        escribirTodo(descriptor, contenido);

        if (fsync(descriptor) == -1) {
            const int error = errno;
            throw runtime_error(string("No se pudo sincronizar el archivo temporal: ") + strerror(error));
        }

        if (close(descriptor) == -1) {
            const int error = errno;
            descriptor = -1;
            throw runtime_error(string("No se pudo cerrar el archivo temporal: ") + strerror(error));
        }

        descriptor = -1;

        actualizarRespaldo(ruta, respaldo);

        if (rename(temporal.c_str(), ruta.c_str()) == -1) {
            const int error = errno;

            if (error == EXDEV) {
                throw runtime_error(
                    "No se pudo actualizar jobs.json: origen y destino en distintos sistemas de archivos (rename atómico no soportado)"
                );
            }

            throw runtime_error(string("No se pudo actualizar jobs.json: ") + strerror(error));
        }

        renombrado = true;

        sincronizarDirectorio(ruta);
    } catch (...) {
        if (descriptor != -1) {
            close(descriptor);
        }

        if (!renombrado) {
            unlink(temporal.c_str());
        }

        throw;
    }
}
```

#### 2) Respaldo con `link()` y recuperación perezosa

```cpp
void actualizarRespaldo(const string& ruta, const string& respaldo) {
    if (!archivoValido(ruta)) {
        return;
    }

    if (unlink(respaldo.c_str()) == -1 && errno != ENOENT) {
        const int error = errno;
        throw runtime_error(string("No se pudo retirar jobs.json.bak: ") + strerror(error));
    }

    if (link(ruta.c_str(), respaldo.c_str()) == -1) {
        if (errno == ENOENT) {
            return;
        }
        const int error = errno;
        throw runtime_error(string("No se pudo crear jobs.json.bak: ") + strerror(error));
    }
}

json leerSinBloqueo() {
    const string ruta = hermes::rutaDatos(NOMBRE_JOBS);
    const string respaldo = hermes::rutaDatos(NOMBRE_RESPALDO);

    string errorPrincipal;

    try {
        return leerArreglo(ruta);
    } catch (const exception& error) {
        errorPrincipal = error.what();
    }

    try {
        json jobs = leerArreglo(respaldo);

        hermes::EventLog::log_event_system(
            hermes::EventLevel::WARN,
            "jobs.json recuperado desde jobs.json.bak",
            {
                {"archivo", NOMBRE_JOBS},
                {"detalle", errorPrincipal}
            }
        );

        try {
            guardarAtomico(jobs);
        } catch (...) {
            // El respaldo sigue disponible.
        }

        return jobs;
    } catch (const exception& errorRespaldo) {
        throw runtime_error(
            string("No se pudo leer jobs.json ni jobs.json.bak: ") +
            errorPrincipal + " / " + errorRespaldo.what()
        );
    }
}
```

#### 3) Validación proactiva al arranque (RNF-28)

```cpp
void verificarYRestaurarJobsAlArranque() {
    namespace fs = std::filesystem;

    try {
        lock_guard<std::mutex> guardia(mutexStorage);
        BloqueoArchivo bloqueo;

        const string ruta = hermes::rutaDatos(NOMBRE_JOBS);
        const string respaldo = hermes::rutaDatos(NOMBRE_RESPALDO);

        if (archivoValido(ruta)) {
            return;
        }

        if (!archivoValido(respaldo)) {
            hermes::EventLog::log_event_system(
                hermes::EventLevel::WARN,
                "jobs.json corrupto o inexistente y jobs.json.bak no válido; se continuará con un estado sin recuperar",
                {
                    {"archivo", NOMBRE_JOBS},
                    {"respaldo", NOMBRE_RESPALDO}
                }
            );
            return;
        }

        std::error_code ec;
        fs::copy_file(respaldo, ruta, fs::copy_options::overwrite_existing, ec);

        if (ec) {
            hermes::EventLog::log_event_system(
                hermes::EventLevel::ERROR,
                "No se pudo restaurar jobs.json desde jobs.json.bak",
                {
                    {"archivo", NOMBRE_JOBS},
                    {"respaldo", NOMBRE_RESPALDO},
                    {"detalle", ec.message()}
                }
            );
            return;
        }

        if (archivoValido(ruta)) {
            hermes::EventLog::log_event_system(
                hermes::EventLevel::WARN,
                "jobs.json corrupto o truncado. Restaurado automáticamente desde jobs.json.bak",
                {
                    {"archivo", NOMBRE_JOBS},
                    {"respaldo", NOMBRE_RESPALDO}
                }
            );
            return;
        }

        hermes::EventLog::log_event_system(
            hermes::EventLevel::ERROR,
            "Restauración desde jobs.json.bak completada pero jobs.json sigue inválido tras copia",
            {
                {"archivo", NOMBRE_JOBS},
                {"respaldo", NOMBRE_RESPALDO}
            }
        );
    } catch (const std::exception& e) {
        try {
            hermes::EventLog::log_event_system(
                hermes::EventLevel::ERROR,
                "Error durante la verificación/restauración de jobs.json al arranque",
                {
                    {"detalle", e.what()}
                }
            );
        } catch (...) {
            // No interrumpir el arranque
        }
    } catch (...) {
        // No interrumpir el arranque
    }
}
```

### `src/event_log.cpp`

```cpp
static bool escribirLineaJsonl(const std::string &ruta, const nlohmann::json &entrada) {
    int fd = open(
        ruta.c_str(),
        O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC,
        0644
    );
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

`events.jsonl` se abre en modo **append** (`O_APPEND`), se bloquea con `flock` y se sincroniza con `fsync` tras cada escritura. Los eventos anteriores **nunca se pierden** ante una interrupción durante la escritura.

## Integración con otros módulos //SI APLICA

- **Arranque del scheduler (`src/scheduler/scheduler.cpp`)**: En `iniciarSchedulerSiNecesario()`, tras adquirir `scheduler.lock` y ejecutar `verificarCapacidadDeRecuperacion()` y `limpiarTemporalesDeJobs()`, se invoca `verificarYRestaurarJobsAlArranque()` **antes** de `recuperarTrabajosInterrumpidos()`. Esto garantiza que `jobs.json` esté íntegro antes de reconciliar trabajos.
- **Recuperación (`recovery.cpp`)**: Se beneficia de tener `jobs.json` válido tras la restauración proactiva, evitando inconsistencias al marcar trabajos como `INTERRUPTED`.
- **Job/Scheduler**: Todo el ciclo read-modify-write pasa por `modificarJobsSeguros()` → `leerSinBloqueo()` → `guardarAtomico()`, con bloqueo `mutex` + `flock`.
- **Event Log**: Se utiliza `log_event_system()` para registrar la restauración y advertencias sin asociarlas a un `job_id` concreto.

## Ejemplo de funcionamiento

### Escenario: interrupción durante la escritura de `jobs.json`

1. **En ejecución:** El scheduler actualiza el estado de un trabajo y llama a `guardarAtomico()`.
2. **Interrupción:** Se produce un corte de energía justo después de escribir el `.tmp` o durante el `rename()`.
3. **Tras reinicio:** Al arrancar `hermes`, `iniciarSchedulerSiNecesario()` ejecuta:
   - `limpiarTemporalesDeJobs()` → elimina `.tmp.*` huérfanos
   - `verificarYRestaurarJobsAlArranque()` → detecta que `jobs.json` no parsea/corrupto, copia `jobs.json.bak` (válido) sobre `jobs.json`, valida y emite:
     ```json
     {"ts":"...","job_id":null,"level":"WARN","message":"jobs.json corrupto o truncado. Restaurado automáticamente desde jobs.json.bak","context":{"archivo":"jobs.json","respaldo":"jobs.json.bak"}}
     ```
   - `recuperarTrabajosInterrumpidos()` → continua con la reconciliación normal
4. **Resultado:** `jobs.json` queda íntegramente restaurado, sin datos perdidos y sin abortar el arranque. Los eventos anteriores en `events.jsonl` permanecen intactos (modo append).

### Estado en disco tras restauración

```text
~/.local/share/hermes/data/
├── jobs.json      # Restaurado íntegramente desde jobs.json.bak
├── jobs.json.bak  # Última versión válida preservada
├── events.jsonl   # Bitácora previa + evento WARN de restauración
├── jobs.lock
└── scheduler.lock
```

**Garantía:** Las actualizaciones son **atómicas** (`rename`) o **recuperables** (restauración desde `.bak` al arranque). Una interrupción durante la escritura **no deja el repositorio de datos inutilizable**.