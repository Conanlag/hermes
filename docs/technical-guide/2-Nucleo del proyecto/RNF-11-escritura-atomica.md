# RNF-11 — Escritura persistente evitando estados parcialmente actualizados

## Descripción

El requisito no funcional RNF-11 garantiza que los archivos persistentes de Hermes se escriban de forma atómica y duradera, evitando dejar `jobs.json` en un estado parcialmente actualizado ante un fallo del proceso, un corte de energía o una interrupción del sistema operativo.

En lugar de truncar directamente el archivo original con `std::ofstream`, Hermes utiliza un patrón de escritura atómica basado en archivos temporales, sincronización a disco (`fsync`), reemplazo atómico (`rename`) y respaldo seguro (`hardlink`). Este mecanismo asegura que, en todo momento, o bien se conserva la última versión íntegramente válida de `jobs.json`, o bien se aplica la nueva versión completamente.

---

## Objetivo

Garantizar la integridad y recuperabilidad de la base de datos de trabajos (`jobs.json`) ante fallos inesperados, asegurando que nunca quede un JSON truncado o corrupto debido a una escritura interrumpida.

> *"Los archivos persistentes deberán escribirse de forma que se evite dejar un estado parcialmente actualizado."*

**Consideraciones actuales:**

- **Lo que hace:**
  - Toda escritura a `jobs.json` pasa por `guardarAtomico()` en `src/hermes/src/storage/storage.cpp`.
  - Se escribe en un archivo temporal único (`jobs.json.tmp.<pid>.<contador>`) con `O_EXCL | O_CREAT | O_CLOEXEC`.
  - Se vuelca el JSON completo (`jobs.dump(4) + '\n'`) mediante escritura por bloques con reintento ante `EINTR`.
  - Se sincroniza el archivo temporal con `fsync()` antes de cerrarlo.
  - Se actualiza `jobs.json.bak` con `link()` desde la versión válida anterior antes del reemplazo.
  - Se reemplaza atómicamente con `rename()` y se sincroniza el directorio con `fsync()` tras el renombre.
  - Se protege con `mutexStorage` y `flock(LOCK_EX)` sobre `jobs.lock` durante todo el ciclo read-modify-write.
  - Se limpian `.tmp.*` huérfanos en arranque con `limpiarTemporalesDeJobs()`.
  - Se realiza auto-reparación: si `jobs.json` no es válido, se restaura desde `jobs.json.bak` y se regenera atómicamente.
  - Se añaden chequeos defensivos: validación del directorio de datos y manejo explícito de `EXDEV` al renombrar.

- **Lo que NO hace:**
  - No utiliza escritura directa con truncamiento sobre `jobs.json`.
  - No depende de copias con `std::ofstream` en modo `std::ios::trunc`.
  - No fuerza `fsync` sobre el disco físico de forma dependiente de `std::fstream` (se utiliza `fsync` POSIX sobre descriptores).
  - No garantiza atomicidad entre sistemas de archivos distintos (si origen/destino están en volúmenes diferentes, `rename` no es atómico y el código lo detecta con `EXDEV` lanzando un error claro).

---

## Estructura del módulo

```text
src/hermes/
├── include/
│   ├── data_paths.h
│   ├── event_log.h
│   └── storage.h
└── src/
    └── storage/
        └── storage.cpp
```

| Archivo / directorio | Responsabilidad |
|---|---|
| `include/storage.h` | Declaración de `leerJobsSeguros()` y `modificarJobsSeguros()`. Punto único de acceso a la persistencia de jobs. |
| `src/storage/storage.cpp` | Implementación de la escritura atómica, bloqueo (`flock` + `mutex`), respaldo con `link()`, recuperación desde respaldo, limpieza de temporales y sincronización a disco. |
| `include/data_paths.h` | Resolución de rutas de datos (`rutaDatos()`) donde residen `jobs.json`, `jobs.json.bak` y `jobs.lock`. |

---

## Implementación de `.cpp`

### 1) Punto único de escritura

Toda modificación pasa por `modificarJobsSeguros()`:

```cpp
bool modificarJobsSeguros(const std::function<bool(json&)>& funcion) {
    lock_guard<std::mutex> guardia(mutexStorage);
    BloqueoArchivo bloqueo;

    json jobs = leerSinBloqueo();

    if (!funcion(jobs)) {
        return false;
    }

    guardarAtomico(jobs);
    return true;
}
```

Se adquiere `mutexStorage` (serialización intra-proceso) y `BloqueoArchivo` con `flock(LOCK_EX)` sobre `jobs.lock` (serialización inter-proceso) antes de leer y durante todo el ciclo de modificación.

### 2) Escritura atómica duradera

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

    // PID + contador: dos escrituras concurrentes nunca comparten temporal
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

Flujo garantizado:

1. **Crear `.tmp` exclusivo** con `O_EXCL` para evitar reutilización accidental.
2. **Escribir todo el JSON** con `escribirTodo()` reintentando ante `EINTR`.
3. **Sincronizar archivo** con `fsync()` antes de `close()`.
4. **Respaldar versión anterior válida** con `actualizarRespaldo()` usando `link()` (hardlink) desde `jobs.json` existente y parseable.
5. **Reemplazar atómicamente** con `rename()` hacia `jobs.json`.
6. **Sincronizar directorio** con `fsync()` para hacer durable la entrada de directorio.
7. **Limpieza**: si falla antes del `rename`, se elimina el `.tmp`. Si ya fue renombrado, **no** se borra (ya pasó a ser `jobs.json`).

### 3) Respaldo, recuperación y limpieza

- **`actualizarRespaldo()`**: Elimina `jobs.json.bak` si existe, crea un hardlink con `link()` solo si `jobs.json` es parseable. Si `jobs.json` aún no existe (primera escritura), se omite sin error.
- **`leerSinBloqueo()`**: Intenta leer `jobs.json`. Si falla, lee `jobs.json.bak`, registra advertencia en `events.jsonl` y **repara automáticamente** `jobs.json` llamando a `guardarAtomico()` desde el respaldo.
- **`sincronizarDirectorio()`**: Abre el directorio con `O_RDONLY | O_DIRECTORY` y hace `fsync()`. Protege contra cortes de energía tras `rename()`.
- **`limpiarTemporalesDeJobs()`**: Al arranque, elimina archivos `.tmp.*` huérfanos sin abortar el arranque si no se pueden borrar.

---

## Integración con otros módulos

- **`scheduler.cpp`**: Utiliza `modificarJobsSeguros()` para transiciones de estado (`QUEUED -> RUNNING`, `RUNNING -> SUCCEEDED/FAILED/CANCELED/INTERRUPTED`), actualización de `pid`, `tiempo_inicio`, `tiempo_terminacion`, `codigo_salida`, `mensaje_error` y `cancel_requested`.
- **`recovery.cpp`**: Se apoya en el mecanismo de persistencia para reconciliar trabajos interrumpidos tras reinicio.
- **`event_log.cpp`**: Registra eventos relacionados con recuperación/auto-reparación desde respaldo.
- **`main.cpp` / `clean.cpp` / `config.cpp`**: Utilizan `rutaDatos()` para localizar el directorio de datos compartido.

---

## Integración con RNF-09 / RF-13

RNF-11 complementa **RF-13 (Recuperación tras reinicio)** y **RNF-09 (Aislamiento de fallos)**. Al garantizar que `jobs.json` nunca quede parcialmente escrito, la recuperación tras un apagado inesperado puede confiar en que el archivo leído es íntegramente válido o que existe un respaldo parseable para auto-repararse.

---

## Ejemplo de funcionamiento

### Escenario: escritura exitosa con protección atómica

**Acción:**
```bash
./hermes job /bin/sh -c "sleep 1"
```

**Comportamiento interno:**
1. `modificarJobsSeguros()` bloquea `mutexStorage` + `jobs.lock`.
2. Se lee el estado actual.
3. Se reserva el trabajo (`QUEUED -> RUNNING`) en memoria.
4. `guardarAtomico()` crea `/ruta/datos/jobs.json.tmp.<pid>.<n>`, escribe el JSON completo, hace `fsync()`, cierra.
5. Se crea/actualiza `jobs.json.bak` con `link()` desde el `jobs.json` anterior válido.
6. `rename()` reemplaza atómicamente `jobs.json`.
7. `fsync()` del directorio.
8. Se liberan locks.

**Estado resultante en disco (directorio de datos):**
```text
jobs.json
jobs.json.bak
jobs.lock
```

**Garantía:** Si ocurre un corte de energía entre el paso 4 y 7, `jobs.json` permanece íntegramente en su versión anterior y válida. Si el corte ocurre tras el `rename` exitoso, `jobs.json` contiene la nueva versión completamente escrita. Nunca se observa un JSON truncado.
