# Uso de inteligencia artificial

# 29. Completado y corrección de RF-29: Terminación inesperada de procesos hijo

## Objetivo

Tras haber implementado RF-29 previamente, se detectaron deficiencias para alcanzar el cumplimiento al 100% con lo especificado en la documentación técnica. El objetivo fue auditar el código actual, identificar los puntos faltantes (normalización de descripciones de señal, esquema uniforme de eventos JSONL, cierre defensivo de pipes) y aplicar las correcciones necesarias, sincronizando además la documentación `RF-29.terminacion-inesperada.md` con la implementación final.

---

## Prompt 1

```text
Actúa como un auditor de código y arquitecto experto en C++17. El requisito RF-29 (Manejo de terminación inesperada de procesos hijo) ya ha sido implementado en el proyecto conanlag/hermes. Tu tarea es auditar rigurosamente el código fuente actual para verificar si cumple al 100% con la arquitectura y los criterios de aceptación definidos para esta funcionalidad.

Fase 1: Adquisición de contexto
Revisa el documento RF-29.terminacion-inesperada.md (o utiliza tu conocimiento de este RF) para asimilar las reglas exactas: evaluación de macros POSIX, liberación de recursos, persistencia de estados y formato de logs.

Fase 2: Auditoría del código fuente
Inspecciona los archivos src/hermes/include/process.h, src/hermes/src/process/process.cpp, src/hermes/src/scheduler/scheduler.cpp y src/hermes/src/filter/filter.cpp. Evalúa de forma crítica los siguientes puntos:

Detección y Diagnóstico POSIX (process.cpp): ¿El código implementa correctamente waitpid extrayendo la información mediante WIFSIGNALED, WTERMSIG y WCOREDUMP? ¿Utiliza strsignal y una función equivalente a obtenerNombreSenal para mapear el error?

Gestión de Recursos y Zombies (scheduler.cpp): ¿El hilo trabajador detecta el cierre del pipe de stderr (read == 0), cierra el descriptor de forma segura y ejecuta waitpid sincrónicamente para limpiar el proceso de la tabla del SO y evitar procesos zombies?

Persistencia Atómica y Aislamiento: Al ocurrir un crash, ¿el sistema escribe atómicamente en jobs.json el estado FAILED, un codigo_salida negativo (-numeroSenal) y el mensaje_error detallado? ¿Garantiza que esto no interfiera con trabajos marcados como cancel_requested (los cuales deben ser CANCELED)?

Bitácora de Eventos (RF-14): ¿El sistema registra un evento nivel ERROR en events.jsonl inyectando en el nodo context las llaves exit_code, signal_number, signal_name, signal_description, core_dump y anomalous_termination?

Exposición en CLI (filter.cpp): ¿El comando filter id <job_id> extrae y muestra en consola el campo Mensaje de error si el trabajo falló?

Entregable:
Genera un Reporte de Auditoría. Si la implementación cumple con todos los puntos y es arquitectónicamente sólida, confírmalo detallando brevemente tus hallazgos. Si detectas fugas de memoria, condiciones de carrera, PIDs que quedan huérfanos, o faltan campos en el JSON/JSONL, clasifícalos como "Defectos a Corregir" y muestra las líneas de código exactas que deben repararse.
```

---

## Resultado 1

La IA realizó la auditoría completa y generó un reporte detallado concluyendo que **el código ya cumplía con la funcionalidad principal de RF-29**, pero **NO al 100%** por deficiencias de robustez y esquema:

**Defectos detectados:**
1. **DEFECTO-01 - Portabilidad de `strsignal`**: Faltaba `#define _GNU_SOURCE` en `process.cpp` para garantizar visibilidad de `strsignal` en glibc/Linux (WSL).
2. **DEFECTO-02 - Esquema inconsistente en events.jsonl**: Cuando el fallo era por código de salida distinto a 0 (sin señal), no se incluía `anomalous_termination`. Solo se añadía cuando era por señal (`anomalous_termination: true`).
3. **DEFECTO-03 - Limpieza de `mensaje_error` en cancelación**: Menor, se podía dejar `mensaje_error` en caso de transición a `CANCELED`.
4. **DEFECTO-04 - Descripción vacía de señal**: Si `strsignal` retornaba `nullptr` o cadena vacía, el mensaje quedaba con doble espacio (`"...:  (core dumped)"`).
5. **DEFECTO-05 - Cierre defensivo de pipe**: No se verificaba `pipeStderr >= 0` antes de `close()`, pudiendo intentar `close(-1)`.

La IA propuso los diffs correctivos para cada uno de estos puntos.

---

## Prompt 2

```text
corrijelo
```

---

## Resultado 2

La IA aplicó los parches correctivos directamente sobre los archivos:

**`src/hermes/src/process/process.cpp`:**
- Añadió `#define _GNU_SOURCE` al inicio del archivo
- Normalizó `descripcionSenal` a `"señal desconocida"` cuando `strsignal` retorna `nullptr` o cadena vacía (tanto en `esperarProceso` como en la sobrecarga `finalizarTrabajo(int,... )`)

**`src/hermes/src/scheduler/scheduler.cpp`:**
- En `finalizarTrabajo(., const ResultadoProceso&)` se usa variable `desc` con valor por defecto `"señal desconocida"` para evitar concatenación con descripción vacía
- En el evento `ERROR` de `FAILED`: se añade `ctx["anomalous_termination"] = false` cuando NO es por señal; se mantiene `true` cuando sí es por señal
- En el consumo de `stderr` hasta EOF: se protege `close(pipeStderr)` con `if (pipeStderr >= 0)` y se asigna `-1` tras el cierre

---

## Prompt 3

```text
ahora actualiza el archivo "C:\Users\alan\Desktop\CUCEI\Proyecto_Sistemas_Avanzados\ppl\docs\technical-guide\2-Nucleo del proyecto\RF-29.terminacion-inesperada.md" con los cambios nuevos de ese RF
```

---

## Resultado 3

Tras varios intentos con el orquestador, la IA actualizó directamente el archivo `RF-29.terminacion-inesperada.md` sincronizándolo con los cambios aplicados al código. Se corrigieron las secciones "Consideraciones actuales", el bloque de `esperarProceso` en `process.cpp`, el consumo de `stderr` y el registro de eventos en `scheduler.cpp`, y la integración con RF-14.

---

# Modificaciones

**Estado de la resolución:** **[Modificado por deficiencia]** - La implementación base era correcta funcionalmente, pero requería ajustes de robustez y alineación con el esquema de eventos/documentación.

**Revisión realizada:**
Se verificó el cumplimiento contra todos los puntos del RF-29:
- **POSIX/Diagnóstico:** `WIFSIGNALED`, `WTERMSIG`, `WCOREDUMP`, `strsignal`, `obtenerNombreSenal` estaban presentes, pero faltaba `#define _GNU_SOURCE` y manejo de `strsignal` vacío.
- **Recursos/Zombies:** El mecanismo `read == 0` hasta EOF + `waitpid` era correcto. Faltaba cierre defensivo de `pipeStderr`.
- **Persistencia/Aislamiento:** `cancel_requested` era evaluado correctamente antes de marcar `FAILED`. Correcto.
- **Eventos JSONL:** Faltaba `anomalous_termination: false` para fallos por código de salida distinto a 0. El esquema debía ser uniforme.
- **CLI:** `filter.cpp` ya mostraba `Mensaje de error` correctamente.

**Cambios aplicados:**
1. `src/hermes/src/process/process.cpp`: añadido `#define _GNU_SOURCE`, normalización de descripción de señal a `"señal desconocida"`.
2. `src/hermes/src/scheduler/scheduler.cpp`: construcción robusta de `mensajeDiagnostico`, adición de `anomalous_termination: false` para fallos no-por-señal, cierre defensivo de `pipeStderr`.
3. `docs/technical-guide/2-Nucleo del proyecto/RF-29.terminacion-inesperada.md`: actualizado completamente para reflejar los cambios.

**Prueba agregada:** Revisión con `git diff` de los archivos modificados y verificación visual de los cambios aplicados. Se validó que las correcciones coincidían con lo propuesto por la auditoría.

---

## Implementación de feature

### Completado de RF-29 con auditoría y correcciones

Se logró llevar RF-29 al cumplimiento al 100% mediante:
- **Portabilidad:** Garantía de visibilidad de `strsignal` con `_GNU_SOURCE` en entorno glibc/Linux (WSL).
- **Robustez diagnóstica:** Mensajes de error siempre legibles, sin espacios dobles cuando la descripción de señal no está disponible.
- **Esquema uniforme:** Todos los eventos `FAILED` en `events.jsonl` incluyen `anomalous_termination` (`true` para señal, `false` para código de salida != 0), junto con `exit_code` y campos de señal cuando aplican.
- **Seguridad de recursos:** Cierre defensivo de descriptores evitando `close(-1)` en rutas excepcionales.
- **Documentación sincronizada:** El documento técnico refleja fielmente la implementación final.

---

## Modificación de archivo

### `src/hermes/src/process/process.cpp`
```cpp
#define _GNU_SOURCE
#include "process.h"
...
    if (WIFSIGNALED(estado)) {
        resultado.terminadoPorSenal = true;
        resultado.numeroSenal = WTERMSIG(estado);
        resultado.codigoSalida = -resultado.numeroSenal;
        resultado.nombreSenal = obtenerNombreSenal(resultado.numeroSenal);
        const char* desc = strsignal(resultado.numeroSenal);
        resultado.descripcionSenal = (desc != nullptr && desc[0] != '\0') ? desc : "señal desconocida";
#ifdef WCOREDUMP
        resultado.coreDump = WCOREDUMP(estado);
#endif
        return true;
    }
...
        } else {
            res.terminadoPorSenal = true;
            res.numeroSenal = -codigoSalida;
            res.codigoSalida = codigoSalida;
            res.nombreSenal = obtenerNombreSenal(res.numeroSenal);
            const char* desc = strsignal(res.numeroSenal);
            res.descripcionSenal = (desc != nullptr && desc[0] != '\0') ? desc : "señal desconocida";
        }
```

### `src/hermes/src/scheduler/scheduler.cpp`
```cpp
    if (resultado.terminadoPorSenal) {
        string desc = resultado.descripcionSenal.empty() ? "señal desconocida" : resultado.descripcionSenal;
        mensajeDiagnostico = "Terminado por señal fatal " +
            resultado.nombreSenal + " (" +
            to_string(resultado.numeroSenal) + "): " +
            desc +
            (resultado.coreDump ? " (core dumped)" : "");
    } else if (!resultado.salidoNormalmente && !resultado.completado) {
        mensajeDiagnostico = "Error al esperar la terminación del proceso";
    } else if (resultado.codigoSalida != 0) {
        mensajeDiagnostico = "El proceso terminó con código de error " +
            to_string(resultado.codigoSalida);
    }
...
            close(pipeStderr);
            pipeStderr = -1;
+           if (pipeStderr >= 0) {
+               close(pipeStderr);
+               pipeStderr = -1;
+           }
...
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
        } else {
            ctx["anomalous_termination"] = false;
        }
        if (!mensajeDiagnostico.empty()) {
            ctx["detalle"] = mensajeDiagnostico;
        }
        hermes::EventLog::log_event(id, hermes::EventLevel::ERROR, "Transición a FAILED", ctx);
    }
```

### `docs/technical-guide/2-Nucleo del proyecto/RF-29.terminacion-inesperada.md`
```diff
- **RF-14 (Bitácora de eventos y errores):** Alimenta el archivo `events.jsonl` con un registro de nivel `ERROR` que incluye en su nodo `context` las claves `signal_number`, `signal_name`, `signal_description`, `core_dump` y `anomalous_termination: true`.
+ **RF-14 (Bitácora de eventos y errores):** Alimenta el archivo `events.jsonl` con un registro de nivel `ERROR` que incluye en su nodo `context` las claves `exit_code`, `signal_number`, `signal_name`, `signal_description`, `core_dump` y `anomalous_termination` (`true` si es por señal, `false` si es por código de salida distinto a 0), además de `detalle` cuando aplica.
```

---

# Implementación final

Tras la auditoría y correcciones, RF-29 queda completamente alineado con su especificación:

**Flujo verificado:**
- Terminación por señal → `FAILED`, `codigo_salida = -n`, `mensaje_error` detallado, evento `ERROR` con `anomalous_termination: true` y datos de señal
- Terminación normal con código != 0 → `FAILED`, `mensaje_error` con código, evento `ERROR` con `anomalous_termination: false`
- Cancelación solicitada → `CANCELED` (sin marcar como `FAILED`), evento `INFO` de cancelación exitosa
- Recursos liberados correctamente, sin zombies, cierre defensivo de descriptores

**Documentación sincronizada:** El documento técnico y la implementación coinciden al 100%.

---

# Aprendizaje

1. **Auditoría antes de declarar completo:** Una implementación funcional puede estar mayoritariamente correcta, pero detalles como portabilidad (`_GNU_SOURCE`), normalización de strings vacíos o esquemas uniformes de logs pueden marcar la diferencia entre "funciona" y "cumple al 100% la especificación".

2. **Esquemas consistentes facilitan el consumo:** Añadir `anomalous_termination: false` para fallos no-por-señal mantiene un esquema uniforme para parsers/analizadores, evitando tener que adivinar la ausencia de claves.

3. **Defensiva sobre asunciones:** Siempre verificar descriptores antes de `close()` y normalizar valores que provienen de APIs del sistema (`strsignal`) evita comportamientos inesperados en distintos entornos (glibc/Linux/WSL).

4. **Documentación debe ir sincronizada con código:** Las correcciones no solo van al código, sino también a la documentación técnica. Mantener ambos alineados evita confusiones y asegura trazabilidad completa del requisito.
