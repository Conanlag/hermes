# Uso de inteligencia artificial

# 24. Auditoría de persistencia y recuperación (RF-12, RF-13) y corrección de filtros

## Objetivo

Auditar de forma exhaustiva la implementación técnica de los requisitos RF-12 (Persistencia de metadatos y resultados) y RF-13 (Recuperación tras reinicio) en el proyecto Hermes (C++17), cruzando el código fuente con la documentación técnica formal para verificar el cumplimiento estricto de los requisitos no funcionales RNF-10, RNF-11, RNF-30 y RNF-31. El objetivo secundario fue subsanar los defectos y observaciones identificados durante la auditoría, específicamente el hallazgo abierto F10 en el módulo de filtros (`filter.cpp`) y la remoción de interfaces obsoletas de transiciones de Jobs en `job.h` y `job.cpp`.

---

## Prompt 1

```text
Actúa como un auditor de código y arquitecto experto en C++17. Los requisitos RF-12 (Persistencia) y RF-13 (Recuperación tras reinicio) ya han sido implementados en el proyecto conanlag/hermes. Tu tarea es auditar rigurosamente esta implementación para verificar si es segura, completa y si cumple con los objetivos establecidos.

Fase 1: Adquisición de contexto
Lee y asimila las reglas de negocio definidas en estos documentos específicos:

docs/technical-guide/2-Nucleo del proyecto/RF-13.recuperacion-tras-reinicio.md

docs/technical-guide/2-Nucleo del proyecto/implementacion-inicial-RF-13.md

Fase 2: Auditoría del código fuente
Cruza la información de los documentos con la implementación real (revisando src/hermes/src/scheduler/scheduler.cpp, main.cpp y la lógica de almacenamiento/estado). Evalúa de forma crítica los siguientes puntos:

Seguridad de Persistencia (RF-12, RNF-11): ¿El sistema escribe el archivo jobs.json de manera atómica para evitar estados parcialmente actualizados o corrupción si el servidor pierde energía durante la escritura?

Precisión de Estados (RNF-31): ¿El código clasifica correctamente los trabajos que se quedaron a medias (asignándoles el estado INTERRUPTED u otro equivalente documentado) para no confundirlos con trabajos que terminaron en FAILED?

Manejo de PIDs y Huérfanos (RNF-10, RNF-30): En la lógica de arranque, cuando el sistema detecta un trabajo que estaba en RUNNING, ¿verifica a nivel del sistema operativo (ej. mediante kill(pid, 0)) si el proceso sigue vivo? De ser así, ¿garantiza que el proceso se detenga de forma segura para no dejar huérfanos antes de actualizar la bitácora y el estado?

Entregable:
Genera un Reporte de Auditoría. Si la implementación es impecable, confírmalo explicando cómo se cumplen los RNFs. Si detectas vulnerabilidades lógicas (por ejemplo, riesgos por reciclaje de PIDs por parte del SO), condiciones de carrera o desviaciones respecto a los archivos .md proporcionados, clasifícalos como "Defectos a Corregir" y muestra qué líneas de código exactas deben modificarse.
```

---

## Resultado 1

La IA emitió un Reporte de Auditoría Arquitectónica en el que confirmó el cumplimiento riguroso de los RNFs en el núcleo:
1. **Seguridad de Persistencia (RF-12, RNF-11):** Verificó que `storage.cpp` implementa el protocolo atómico y durable completo (`O_CREAT | O_EXCL`, bucle contra `EINTR`, `fsync` del temporal, `link()` atómico a `jobs.json.bak` condicionada a validez del archivo, `rename()` POSIX y `fsync()` del descriptor del directorio padre, junto a auto-reparación en lectura y limpieza de temporales en arranque).
2. **Precisión de Estados (RNF-31):** Confirmó que `status.cpp` y `recovery.cpp` diferencian estrictamente `FAILED` de `INTERRUPTED`, aplicando fail-closed ante estados desconocidos y registrando metadatos de auditoría (`motivo`, `proceso_terminado`, `recuperado_en`, `codigo_salida = -1`).
3. **Manejo de PIDs y Huérfanos (RNF-10, RNF-30):** Detalló que Hermes va más allá de un `kill(pid, 0)` elemental (el cual fallaría ante procesos zombies y reciclaje de PIDs) mediante la verificación de identidad de 3 factores (`boot_id`, starttime en `/proc/<pid>/stat` y `pgrp == pid`), absteniéndose de señalizar procesos reciclados (`motivo=pid_reutilizado`) y rastreando nietos sin líder vía `sid`.
4. **Defectos detectados:** Clasificó el hallazgo abierto F10 en `filter.cpp` (lectura directa con `ifstream` evadiendo `storage` y `jobs.lock`), la observación O1 (sello de `tiempo_inicio` en reserva antes de `execvp`, F13) y la observación O2 (métodos muertos `actualizarEstadoJob` y `actualizarResultadoJob` en `job.h/.cpp`).

---

## Prompt 2

```text
ok, entonces si se interrumpe hermes por cualquier cosa sabra manejar esas situaciones?
Puedes hacer los cambios necesarios del defecto y observaciones?
```

---

## Resultado 2

La IA explicó técnicamente la respuesta del sistema ante cada tipo de interrupción:
- **Apagado ordenado (`SIGTERM`/`SIGINT`):** Captura `async-signal-safe` con `banderaApagado`, cierre de admisión vía `mutexArranque`, terminación en lote y único escritor del estado final con `motivo = "apagado"`.
- **Caída súbita (`SIGKILL`, corte de proceso):** Muerte inmediata de hijos vía `PR_SET_PDEATHSIG` y reconciliación síncrona en el siguiente comando CLI antes de arrancar un nuevo scheduler.
- **Corte de energía:** Garantías ACID en disco, fallback auto-curativo a `.bak` y descarte de PIDs reciclados tras reboot vía `boot_id`.
- **Limpieza (`clean data`):** Reconciliación previa bajo `scheduler.lock` para evitar bloqueos por filas caídas.

Posteriormente, la IA aplicó las modificaciones de código directamente en los archivos:
1. `src/hermes/src/filter/filter.cpp`: Sustituyó la lectura directa con `ifstream` en `filtrarPorStatus()` y `filtrarPorPrograma()` por `leerJobsSeguros()`, cerrando el defecto F10.
2. `src/hermes/include/job.h` y `src/hermes/src/job/job.cpp`: Removió las declaraciones e implementaciones no utilizadas de `actualizarEstadoJob()` y `actualizarResultadoJob()`.
3. Justificó que la observación O1 (F13 sobre `tiempo_inicio`) pertenece contractualmente al RF-07 y se conservó en la reserva para no alterar la especificación de ese requisito ni afectar sus pruebas.

---

## Prompt 3

```text
dame el mensaje de commit de esto con el prefijo "fix:"
```
*(seguido de la aclaración: "dame el mensaje en español")*

---

## Resultado 3

La IA proporcionó el mensaje de commit bajo el estándar de Conventional Commits en español:

```text
fix: sincronizar lecturas en filtros mediante storage y retirar transiciones obsoletas

- Usar leerJobsSeguros en filtrarPorStatus y filtrarPorPrograma para garantizar sincronización con jobs.lock y respaldo .bak (F10)
- Eliminar funciones obsoletas no utilizadas actualizarEstadoJob y actualizarResultadoJob en job.h y job.cpp
```

El desarrollador agregó los cambios a stage (`git add .`) y ejecutó el commit con el mensaje generado.

---

# Modificaciones

**Estado de la resolución:** **[Aceptado]** tras verificación.

**Revisión realizada:** Se verificó que la propuesta de corrección en `filter.cpp` elimina completamente el acoplamiento con la ruta en disco y la lectura no sincronizada, haciendo que todos los filtros (`id`, `status` y `programa`) pasen por la capa segura de almacenamiento (`leerJobsSeguros`). Se confirmó que la remoción de `actualizarEstadoJob` y `actualizarResultadoJob` en `job.h/.cpp` no dejó llamadas rotas en ningún punto del proyecto y eliminó deuda técnica.

**Cambios aplicados:**
1. Inclusión de `#include "storage.h"` y remoción de `#include <fstream>` y de la constante `archivoJobs` en `src/hermes/src/filter/filter.cpp`.
2. Reemplazo del bloque `ifstream archivoLectura(archivoJobs)` por `jobs = leerJobsSeguros()` dentro de `filtrarPorStatus()` y `filtrarPorPrograma()` en `src/hermes/src/filter/filter.cpp`.
3. Eliminación de prototipos e implementaciones de `actualizarEstadoJob` y `actualizarResultadoJob` en `src/hermes/include/job.h` y `src/hermes/src/job/job.cpp`.

**Prueba agregada:** Inspección de estado de repositorio (`git status -s`) y verificación de diff limpio (`git diff`), confirmando que solo 3 archivos fueron afectados con 9 inserciones y 94 eliminaciones.

---

## Implementación de feature

### Sincronización y durabilidad en módulo de filtros (Cierre de F10)

Se integró el módulo `filter` al subsistema de almacenamiento seguro de Hermes (`storage.h`). Con este cambio:
- Las consultas `hermes filter status <valor>` y `hermes filter programa <valor>` adquieren `jobs.lock` y `mutexStorage`, eliminando condiciones de carrera frente a la recuperación síncrona en el arranque o escrituras activas del scheduler.
- Si el archivo principal `jobs.json` sufriera corrupción por corte eléctrico imprevisto, los filtros ya no arrojan un error fatal de lectura; se benefician automáticamente de la cadena de fallback hacia `jobs.json.bak` y disparan la auto-reparación del archivo principal.

---

## Modificación de archivo

### `src/hermes/src/filter/filter.cpp`
```cpp
#include "filter.h"
#include "job.h"
#include "status.h"
#include "storage.h"

#include <iostream>
#include <nlohmann/json.hpp>
#include "terminal.colors.h"

using std::cout;
using std::endl;
using json = nlohmann::json;

// ...

void filtrarPorStatus(const string& status){
    json jobs;

    try {
        jobs = leerJobsSeguros();
    } catch (const std::exception& e) {
        error("Error al leer jobs: ", e.what());
        return;
    }

    bool encontrado = false;
    for (const auto& job : jobs) {
        if (job.contains("status") &&
            job["status"].is_string() &&
            job["status"] == status) {
            // ... presentación ...
            encontrado = true;
        }
    }

    if (!encontrado) {
        error("No se encontraron Jobs con estado: ", status);
    }
}

void filtrarPorPrograma(const string& programa){
    json jobs;

    try {
        jobs = leerJobsSeguros();
    } catch (const std::exception& e) {
        error("Error al leer jobs: ", e.what());
        return;
    }

    bool encontrado = false;
    for (const auto& job : jobs) {
        if (job.contains("programa") &&
            job["programa"].is_string() &&
            job["programa"] == programa) {
            // ... presentación ...
            encontrado = true;
        }
    }

    if (!encontrado) {
        error("No se encontraron Jobs con el programa indicado: ", programa);
    }
}
```

### `src/hermes/include/job.h`
```cpp
// Se eliminaron:
// bool actualizarEstadoJob(unsigned int jobId, Status nuevoEstado);
// bool actualizarResultadoJob(unsigned int jobId, Status nuevoEstado, int codigoSalida);
```

### `src/hermes/src/job/job.cpp`
```cpp
// Se eliminaron las definiciones completas de actualizarEstadoJob() y actualizarResultadoJob()
```

---

# Implementación final

Consolidación en el control de versiones:

```text
$ git status
On branch alan
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   src/hermes/include/job.h
        modified:   src/hermes/src/filter/filter.cpp
        modified:   src/hermes/src/job/job.cpp

$ git commit -m "fix: sincronizar lecturas en filtros mediante storage y retirar transiciones obsoletas"
[alan 70a746f] fix: sincronizar lecturas en filtros mediante storage y retirar transiciones obsoletas
 3 files changed, 9 insertions(+), 94 deletions(-)
```

---

# Aprendizaje

1. **Defensa en profundidad en sistemas POSIX:** La auditoría demostró que comprobar la vida de un proceso no puede limitarse a `kill(pid, 0)` debido a estados zombi y reciclaje de identificadores por el kernel. Comprobar la tupla `boot_id` + `starttime` + `pgrp` es el estándar correcto en Linux para atribuir identidad real a un proceso.
2. **Consistencia de interfaz y abstracción única:** Cuando un sistema diseña una capa de almacenamiento transaccional segura (`storage.h`), **ningún** módulo cliente debe abrir los archivos de datos directamente con flujos estándar (`std::ifstream`). Si un submódulo elude la capa de abstracción, se rompe el modelo de concurrencia y se pierden los mecanismos de durabilidad y auto-sanación.
3. **Respeto a las fronteras de requisitos:** Durante una auditoría es vital distinguir entre un defecto real dentro del alcance evaluado (F10) y detalles de diseño que pertenecen a otros requisitos (como el sellado de timestamps en RF-07 vs RF-13), evitando introducir regresiones en contratos previamente aprobados.
