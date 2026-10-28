# Uso de inteligencia artificial

# 26. Detección y diagnóstico de terminación inesperada de procesos hijo (RF-29)

## Objetivo

Implementar el requerimiento funcional **RF-29** en Hermes: ante la terminación inesperada o forzada de un proceso hijo (por ejemplo, fallos de segmentación `SIGSEGV`, terminación abrupta `SIGKILL`, o excepciones aritméticas `SIGFPE`), el servicio debe detectar el evento de forma reactiva y sin latencia, liberar deterministamente los recursos asociados (tuberías de captura de `stderr` y cosechar el proceso para evitar zombies en la tabla de procesos del kernel) y registrar un estado terminal `FAILED` acompañado de metadatos de diagnóstico forense detallados tanto en `jobs.json` como en `events.jsonl`.

---

## Prompt 1

```text
/plan Actúa como un experto arquitecto en C++17. Nuestro próximo objetivo en conanlag/hermes es implementar el RF-29 — Manejo de terminación inesperada de procesos hijo ("Si un proceso hijo termina inesperadamente, el servicio deberá detectar el evento, liberar sus recursos y registrar un estado terminal con información de diagnóstico").

Fase 1: Auditoría del manejo actual de procesos
Revisa el código actual, específicamente el motor de ejecución (scheduler.cpp, process.cpp o donde manejes waitpid()/señales de Linux). Verifica lo siguiente:

¿El código actual ya evalúa macros de Linux como WIFSIGNALED(status) y WTERMSIG(status) para distinguir entre una salida limpia y un "crash" (ej. Segmentation Fault, SIGKILL)?

¿Qué ocurre actualmente con los recursos en memoria y las estructuras de datos del trabajo si el proceso hijo es asesinado por el sistema operativo?

Fase 2: Plan de Implementación (RF-29)
Basado en tu diagnóstico, diseña la estrategia algorítmica para cumplir con este requerimiento. Tu reporte debe incluir:

Mecanismo de Detección: Cómo interceptará Hermes esta caída. ¿Propones un manejador de la señal SIGCHLD, o revisar activamente mediante waitpid(pid, &status, WNOHANG) en el bucle principal (polling)?

Gestión de Estados e Información: Cuando ocurra un crash, el trabajo debe pasar al estado FAILED. ¿Cómo extraerás la señal fatal (WTERMSIG) y cómo la inyectarás en el nodo context del events.jsonl usando la Política de Logging (Nivel ERROR) que ya tenemos definida?

Liberación de Recursos: Detalla qué descriptores de archivo (pipes de stdout/stderr) y bloqueos (jobs.lock) deben cerrarse o liberarse al ocurrir este evento.

Entrégame únicamente el reporte de diagnóstico y tu propuesta de diseño paso a paso. No modifiques el código fuente hasta que yo apruebe la estrategia.
```

---

## Resultado 1

La IA realizó una auditoría rigurosa del subsistema de procesos y del scheduler, volcando su diagnóstico y propuesta en el artefacto interactivo `plan_rf29_terminacion_inesperada.md`:

1. **Diagnóstico de Fase 1:**
   - Detectó que en `src/hermes/src/process/process.cpp:474-482`, `esperarProceso` ya evaluaba `WIFSIGNALED` y `WTERMSIG`, pero con deficiencias técnicas importantes:
     - Codificaba la señal como un número negativo simple (`codigoSalida = -WTERMSIG(estado)`), generando colisión y ambigüedad con retornos de fallo de `waitpid` (`-1`).
     - Omitía la macro `WCOREDUMP(estado)`, impidiendo registrar si hubo un volcado de memoria.
     - En `finalizarTrabajo` (`scheduler.cpp`), ante una terminación anormal, se actualizaba el estado a `FAILED` pero **nunca se llenaba `mensaje_error` en `jobs.json`**, dejando al usuario sin información explicativa.
     - En `events.jsonl`, únicamente se inyectaba el entero numérico `signal_number`, omitiendo el nombre canónico de la señal (`SIGSEGV`, `SIGKILL`) y la descripción textual provista por `strsignal`.
   - Respecto a los recursos:
     - El cierre del pipe de `stderr` por parte del kernel al morir el hijo desbloquea el `read()` del trabajador (`read == 0` / EOF). Sin embargo, identificó que faltaba blindar el cierre de `pipeStderr` en los bloques `catch` ante posibles excepciones previas a la recolección.
     - El worker cosechaba al hijo inmediatamente con `waitpid`, liberando la tabla del kernel.
     - Durante la ejecución del hijo, `jobs.lock` no está retenido (se opera únicamente bajo locks efímeros y atómicos al escribir en disco), descartando riesgos de bloqueo huérfano.

2. **Propuesta Arquitectónica de Fase 2:**
   - **Mecanismo de Detección:** Propuso **conservar el modelo síncrono del hilo trabajador** (`read` bloqueante + `waitpid`). Descartó formalmente `SIGCHLD` (inseguro en un demonio multihilo, pues roba PIDs a los hilos trabajadores con `waitpid(-1)` y no es *async-signal-safe*) y descartó *polling* con `WNOHANG` (evita latencia periódica y consumo inútil de CPU).
   - **Estructura Enriquecida:** Declarar `struct ResultadoProceso` en `process.h` para recopilar de forma tipada `terminadoPorSenal`, `numeroSenal`, `nombreSenal`, `descripcionSenal` (`strsignal`) y `coreDump`.
   - **Trazabilidad y Persistencia:** Llenar `mensaje_error` en `jobs.json` y alimentar el nodo `context` de `events.jsonl` (Nivel `ERROR`) con metadatos completos (`signal_name`, `signal_description`, `core_dump`, `anomalous_termination: true`).
   - **Visualización en CLI:** Actualizar `filter.cpp` para mostrar `Mensaje de error:` en la salida de `filtrarPorId`.

---

## Prompt 2

```text
[Aprobación del artefacto interactivo plan_rf29_terminacion_inesperada.md por parte del usuario]
```

---

## Resultado 2

La IA implementó la totalidad de los componentes aprobados:
1. Modificó `src/hermes/include/process.h` declarando `ResultadoProceso`, `obtenerNombreSenal()` y la sobrecarga diagnóstica `esperarProceso(pid, resultado)`.
2. Actualizó `src/hermes/src/process/process.cpp` implementando el mapeo completo de señales POSIX, la extracción de macros (`WIFSIGNALED`, `WTERMSIG`, `WCOREDUMP`, `strsignal`) y el adaptador compatible hacia la firma legacy.
3. Modificó `src/hermes/src/scheduler/scheduler.cpp` para usar `ResultadoProceso` en `trabajador()`, blindar el reseteo y cierre de `pipeStderr` en todos los flujos y bloques de excepción, persistir `mensaje_error` detallado en `jobs.json` y enriquecer el evento de `EventLog`.
4. Modificó `src/hermes/src/filter/filter.cpp` para renderizar en pantalla el mensaje de error diagnóstico al consultar por ID.
5. Generó el artefacto `walkthrough.md` resumiendo las garantías técnicas y cambios realizados.

---

# Modificaciones

**Estado de la resolución:** **[Aceptado]** tras verificación.

**Revisión realizada:**
Se analizó la coherencia de la arquitectura con los estándares POSIX y C++17:
- **Ausencia de carreras en multihilo:** Al descartar `SIGCHLD` asíncrono, se evita la contención de PIDs entre hilos trabajadores y se respeta la restricción de llamadas *async-signal-safe*.
- **Compatibilidad hacia atrás:** La sobrecarga `esperarProceso(pid_t, int&)` y la sobrecarga `finalizarTrabajo(unsigned int, int, bool)` garantizan que ninguna parte del código legacy se rompa.
- **Seguridad ante excepciones:** El reseteo explícito de `pipeStderr = -1` tras su cierre y su inclusión defensiva en todos los bloques `catch` elimina la fuga de descriptores si se produce una excepción durante la manipulación del proceso.
- **Distinción semántica:** Se verificó que las cancelaciones voluntarias (`cancel_requested == true`) sigan marcándose como `CANCELED` (Nivel `INFO`), distinguiéndose claramente de caídas fortuitas por señales fatales.

**Cambios aplicados:**
1. Definición de `struct ResultadoProceso` en `src/hermes/include/process.h`.
2. Función `obtenerNombreSenal()` y sobrecarga `esperarProceso(pid, resultado)` en `src/hermes/src/process/process.cpp`.
3. Cierre determinista de `pipeStderr` en `src/hermes/src/scheduler/scheduler.cpp` en rutas normales y excepcionales.
4. Generación de diagnósticos explicativos en `finalizarTrabajo()` para `jobs.json` (`mensaje_error`).
5. Inyección de `signal_name`, `signal_description`, `core_dump` y `anomalous_termination` en el nodo `context` de `events.jsonl` (Nivel `ERROR`).
6. Inclusión de `Mensaje de error:` en `src/hermes/src/filter/filter.cpp` (`filtrarPorId`).

**Prueba agregada:** Inspección de diferencias con `git diff` y validación del árbol de trabajo con `git status -s`.

---

## Implementación de feature

### Diagnóstico forense y detección de terminación anormal (RF-29)

Se implementó el flujo completo de detección y diagnóstico ante la muerte de procesos hijo:
- El cierre del extremo de escritura del pipe por el kernel sirve como señal reactiva a costo cero de CPU.
- `esperarProceso` extrae la señal causal (`WTERMSIG`), el nombre estándar (`SIGSEGV`, `SIGKILL`, etc.), la descripción del sistema (`strsignal`) y si el kernel generó volcado de memoria (`WCOREDUMP`).
- El estado terminal `FAILED` ahora contiene información forense completa en disco y bitácora, facilitando la depuración operativa.

---

## Modificación de archivo

### `src/hermes/include/process.h`
```cpp
/**
 * Resultado detallado de la terminación de un proceso hijo (RF-29).
 */
struct ResultadoProceso {
    bool completado = false;
    bool salidoNormalmente = false;
    int codigoSalida = 0;
    bool terminadoPorSenal = false;
    int numeroSenal = 0;
    string nombreSenal;
    string descripcionSenal;
    bool coreDump = false;
};

/**
 * Obtiene el nombre simbólico de una señal POSIX (ej. SIGSEGV, SIGKILL).
 */
string obtenerNombreSenal(int senal);

/**
 * Espera a que termine un proceso con diagnóstico estructurado (RF-29).
 */
bool esperarProceso(
    pid_t pid,
    ResultadoProceso& resultado
);
```

### `src/hermes/src/process/process.cpp`
```cpp
bool esperarProceso(pid_t pid, ResultadoProceso& resultado) {
    resultado = ResultadoProceso{};
    int estado = 0;

    while (true) {
        pid_t res = waitpid(pid, &estado, 0);

        if (res == -1) {
            if (errno == EINTR) {
                continue;
            }

            resultado.completado = false;
            resultado.codigoSalida = -1;
            return false;
        }

        break;
    }

    resultado.completado = true;

    if (WIFEXITED(estado)) {
        resultado.salidoNormalmente = true;
        resultado.codigoSalida = WEXITSTATUS(estado);
        return true;
    }

    if (WIFSIGNALED(estado)) {
        resultado.terminadoPorSenal = true;
        resultado.numeroSenal = WTERMSIG(estado);
        resultado.codigoSalida = -resultado.numeroSenal;
        resultado.nombreSenal = obtenerNombreSenal(resultado.numeroSenal);
        const char* desc = strsignal(resultado.numeroSenal);
        resultado.descripcionSenal = (desc != nullptr) ? desc : "";
#ifdef WCOREDUMP
        resultado.coreDump = WCOREDUMP(estado);
#endif
        return true;
    }

    resultado.codigoSalida = -1;
    return false;
}
```

### `src/hermes/src/scheduler/scheduler.cpp`
```cpp
void finalizarTrabajo(
    unsigned int id,
    const ResultadoProceso& resultado
) {
    bool fueCancelado = false;
    bool fueExitoso = false;
    bool fueFallido = false;
    string mensajeDiagnostico;

    if (resultado.terminadoPorSenal) {
        mensajeDiagnostico = "Terminado por señal fatal " +
            resultado.nombreSenal + " (" +
            to_string(resultado.numeroSenal) + "): " +
            resultado.descripcionSenal +
            (resultado.coreDump ? " (core dumped)" : "");
    } else if (!resultado.salidoNormalmente && !resultado.completado) {
        mensajeDiagnostico = "Error al esperar la terminación del proceso";
    } else if (resultado.codigoSalida != 0) {
        mensajeDiagnostico = "El proceso terminó con código de error " +
            to_string(resultado.codigoSalida);
    }

    modificarJobsSeguros([&](json& jobs) {
        for (auto& item : jobs) {
            if (!item.contains("job_id") || item["job_id"] != id) {
                continue;
            }

            bool cancelar = item.contains("cancel_requested") &&
                            item["cancel_requested"].is_boolean() &&
                            item["cancel_requested"].get<bool>();

            if (cancelar) {
                item["status"] = "CANCELED";
                fueCancelado = true;
            } else if (resultado.salidoNormalmente && resultado.codigoSalida == 0) {
                item["status"] = "SUCCEEDED";
                fueExitoso = true;
            } else {
                item["status"] = "FAILED";
                fueFallido = true;
                if (!mensajeDiagnostico.empty()) {
                    item["mensaje_error"] = mensajeDiagnostico;
                }
            }

            item["codigo_salida"] = resultado.codigoSalida;
            item["tiempo_terminacion"] = obtenerFechaHoraActual();
            return true;
        }
        return false;
    });

    if (fueFallido) {
        nlohmann::json ctx;
        ctx["exit_code"] = resultado.codigoSalida;
        if (resultado.terminadoPorSenal) {
            ctx["signal_number"] = resultado.numeroSenal;
            ctx["signal_name"] = resultado.nombreSenal;
            if (!resultado.descripcionSenal.empty()) {
                ctx["signal_description"] = resultado.descripcionSenal;
            }
            ctx["core_dump"] = resultado.coreDump;
            ctx["anomalous_termination"] = true;
        }
        if (!mensajeDiagnostico.empty()) {
            ctx["detalle"] = mensajeDiagnostico;
        }
        hermes::EventLog::log_event(id, hermes::EventLevel::ERROR, "Transición a FAILED", ctx);
    }
}
```

### `src/hermes/src/filter/filter.cpp`
```cpp
    cout << "Terminacion: "
         << job.tiempo_terminacion << endl;

    if (!job.mensajeError.empty()) {
        cout << "Mensaje de error: "
             << job.mensajeError << endl;
    }

    cout << "Argumentos: ";
```

---

# Implementación final

Flujo operativo al producirse un fallo por señal fatal (`SIGSEGV`):

```bash
$ ./hermes job bash -c "kill -SEGV \$\$"
job ID: 14
PID: 5821

$ ./hermes filter id 14
Job ID: 14
PID: 5821
Programa: bash
Estado: FAILED
Codigo de salida: -11
Recepcion: 2026-10-27 17:15:30
Inicio: 2026-10-27 17:15:30
Terminacion: 2026-10-27 17:15:31
Mensaje de error: Terminado por señal fatal SIGSEGV (11): Segmentation fault (core dumped)
Argumentos: -c kill -SEGV $$ 
```

Entrada generada en `events.jsonl`:
```json
{"context":{"anomalous_termination":true,"core_dump":true,"detalle":"Terminado por señal fatal SIGSEGV (11): Segmentation fault (core dumped)","exit_code":-11,"signal_description":"Segmentation fault","signal_name":"SIGSEGV","signal_number":11},"job_id":"14","level":"ERROR","message":"Transición a FAILED","ts":"2026-10-27 17:15:31"}
```

---

# Aprendizaje

1. **Gestión de Señales en Arquitecturas Multihilo POSIX:**
   En programas concurrentes con múltiples hilos que despachan procesos hijos, delegar la supervisión a un manejador asíncrono central de `SIGCHLD` es un antipatrón recurrente. El manejador está severamente limitado a funciones *async-signal-safe*, y cosechar hijos con `waitpid(-1)` roba el PID del hilo trabajador que lo originó (`ECHILD`), desincronizando la captura de `stderr`. La solución arquitectónica óptima es el acoplamiento reactivo mediante tuberías: el cierre natural del descriptor por parte del kernel notifica al hilo supervisor con cero latencia y sin consumir ciclos de CPU.

2. **Diseño de Tipos Fuertes vs Códigos Sobrecargados en C++17:**
   Sobrecargar un entero primitivo (`int codigoSalida`) para representar simultáneamente códigos de salida normales (`0..255`), caídas por señal (`-signal`) y errores de invocación de sistema (`-1`) crea ambigüedad técnica (por ejemplo, colisión entre error de llamada y `SIGHUP`). Reemplazar esta convención frágil por una estructura fuertemente tipada (`ResultadoProceso`) otorga claridad semántica, extensible y libre de ambigüedades.

3. **Garantía RAII de Descriptores de Archivo:**
   El cierre explícito de descriptores (`pipeStderr`) debe estar blindado tanto en el flujo normal como en cualquier bloque de manejo de excepciones. Restablecer el descriptor a `-1` tras cerrarlo previene errores de doble cierre (*double-close*) y asegura que llamadas posteriores en bloques `catch` o destructores no cierren descriptores reasignados por el sistema operativo.
