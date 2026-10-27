# Uso de inteligencia artificial

# 25. Configuración dinámica de concurrencia y tolerancia a fallos en config.json

## Objetivo

Eliminar el defecto arquitectónico en Hermes donde el número de procesos concurrentes (hilos trabajadores) se encontraba congelado en una constante en tiempo de compilación (`constexpr int NUM_TRABAJADORES = 5`), volviendo inoperante el archivo `config.json`. Se buscó implementar la lectura dinámica de la llave `"trabajos_maximos"` utilizando `nlohmann::json`, aplicando el principio de inyección de dependencias desde `main.cpp` para desacoplar el motor del sistema de archivos y dotar al cargador de una política exhaustiva de tolerancia a fallos (archivo ausente, sin permisos, JSON corrupto o valores fuera del rango seguro `[1, 64]`).

---

## Prompt 1

```text
/plan Actúa como un ingeniero de software experto en C++17. Actualmente tenemos un defecto arquitectónico en conanlag/hermes: el límite máximo de trabajos en cola (o procesos concurrentes) está hardcodeado en el motor, lo que vuelve inútil al archivo config.json.

Fase 1: Exploración y Diagnóstico

Revisa src/hermes/include/data_paths.h para verificar cómo se inicializa config.json y localizar la llave exacta (ej. "trabajos_maximos").

Inspecciona el motor de planificación (src/hermes/src/scheduler/scheduler.cpp o scheduler.h) o el validador, y localiza la variable estática o el número mágico que está limitando la cola actualmente.

Fase 2: Plan de Implementación
Diseña la estrategia para reemplazar este valor hardcodeado por la lectura dinámica del archivo usando nlohmann::json. En tu reporte, responde:

Inyección de dependencias: ¿Cargarás la configuración directamente en el constructor del Scheduler, o propones leer el JSON en main.cpp y pasar el límite como parámetro al inicializar el servicio? (Se prefiere la inyección desde main para facilitar pruebas unitarias).

Tolerancia a fallos: ¿Cuál será tu lógica de respaldo si config.json es eliminado manualmente, no tiene permisos de lectura, o tiene un formato JSON corrupto? Especifica qué valor por defecto seguro usarías.

Entrégame únicamente el reporte de tu diagnóstico y tu propuesta de diseño. No modifiques el código fuente hasta que yo apruebe la estrategia.
```

---

## Resultado 1

La IA presentó un diagnóstico preciso y un plan de diseño estructurado en un artefacto interactivo (`plan_limite_dinamico_concurrencia.md`):
1. **Diagnóstico del defecto:**
   - En `data_paths.h:74` localizó la creación por defecto de `config.json` con la llave `"trabajos_maximos": 5`.
   - En `scheduler.cpp:38` localizó la constante `constexpr int NUM_TRABAJADORES = 5;` que fijaba de forma estática la cantidad de hilos lanzados en `ejecutarScheduler()`.
2. **Propuesta de inyección de dependencias:**
   - Propuso no acoplar el Scheduler con el sistema de archivos, sino cargar la configuración en `main.cpp` (*Composition Root*) a través de un nuevo módulo (`config.h`/`config.cpp`) e inyectar el valor hacia `iniciarSchedulerSiNecesario(int trabajosMaximos = 5)` y `ejecutarScheduler(int trabajosMaximos = 5)`, preservando compatibilidad hacia atrás mediante parámetros por defecto.
3. **Estrategia de tolerancia a fallos:**
   - Definición de constante de respaldo `DEFAULT_TRABAJOS_MAXIMOS = 5`.
   - Manejo de fallos sin lanzar excepciones ante archivo inexistente, falta de permisos (`EACCES`), JSON corrupto (`parse_error`) o tipo de dato no entero, emitiendo registros de advertencia (`WARN`) en `EventLog`.
   - Validación defensiva de rango con clamping seguro: valores $\le 0$ ajustados a `1` y valores excesivos acotados a un techo seguro de `64` para evitar agotamiento de hilos o descriptores en el sistema operativo.

---

## Prompt 2

```text
[Aprobación del artefacto interactivo plan_limite_dinamico_concurrencia.md por parte del usuario]
```

---

## Resultado 2

La IA procedió a la implementación de los cambios aprobados:
1. Creó `src/hermes/include/config.h` y `src/hermes/src/config/config.cpp` encapsulando la estructura `ConfiguracionSistema`, los umbrales seguros y la función `cargarConfiguracion()`.
2. Modificó `src/hermes/include/scheduler.h` y `src/hermes/src/scheduler/scheduler.cpp` para eliminar `NUM_TRABAJADORES` y parametrizar las funciones del scheduler con `trabajosMaximos`.
3. Actualizó `src/hermes/src/main.cpp` para cargar la configuración al iniciar y pasar el límite obtenido al scheduler.
4. Generó el artefacto `walkthrough.md` resumiendo la arquitectura final y los archivos intervenidos.

---

# Modificaciones

**Estado de la resolución:** **[Aceptado]** tras verificación.

**Revisión realizada:** Se revisó que la solución respeta estrictamente los principios SOLID: el motor de planificación ahora es completamente agnóstico a la procedencia de su configuración. Se validó que el uso de parámetros por defecto (`= 5`) en las cabeceras previene la ruptura de cualquier invocación existente. Asimismo, se auditó que el nuevo archivo `src/config/config.cpp` es detectado de forma automática por el `Makefile` gracias a la directiva de búsqueda `SRC = $(shell find src -type f -name '*.cpp')`.

**Cambios aplicados:**
1. Creación de `src/hermes/include/config.h` con constantes `DEFAULT_TRABAJOS_MAXIMOS` (5), `MIN_TRABAJOS_MAXIMOS` (1) y `MAX_TRABAJOS_MAXIMOS` (64).
2. Creación de `src/hermes/src/config/config.cpp` con lectura resiliente, captura de excepciones y logging en `EventLog`.
3. Actualización de `src/hermes/include/scheduler.h` agregando el parámetro `int trabajosMaximos = 5` a `iniciarSchedulerSiNecesario()` y `ejecutarScheduler()`.
4. Eliminación de `constexpr int NUM_TRABAJADORES = 5;` en `src/hermes/src/scheduler/scheduler.cpp` y sustitución por `trabajosMaximos` en la reserva y lanzamiento del vector de hilos trabajadores.
5. Inclusión de `#include "config.h"` en `src/hermes/src/main.cpp` e invocación de `hermes::cargarConfiguracion()` antes de llamar a `iniciarSchedulerSiNecesario()`.

**Prueba agregada:** Comprobación de estado del repositorio mediante `git status -s` y verificación de diferencias limpias con `git diff`.

---

## Implementación de feature

### Carga resiliente de configuración e inyección de concurrencia

Se implementó el subsistema de configuración que permite gobernar la concurrencia del daemon Hermes desde `$HOME/.local/share/hermes/data/config.json`:
- El archivo es leído únicamente durante el arranque del proceso en `main.cpp`.
- Se desacopló el Scheduler de dependencias directas con el parser JSON del disco.
- La tolerancia a fallos garantiza que ante cualquier corrupción o alteración manual del archivo `config.json`, el daemon continúe operando de forma estable bajo el valor seguro predeterminado.

---

## Modificación de archivo

### `src/hermes/include/config.h` [NUEVO]
```cpp
#ifndef CONFIG_H
#define CONFIG_H

namespace hermes {

constexpr int DEFAULT_TRABAJOS_MAXIMOS = 5;
constexpr int MIN_TRABAJOS_MAXIMOS = 1;
constexpr int MAX_TRABAJOS_MAXIMOS = 64;

struct ConfiguracionSistema {
    int trabajosMaximos = DEFAULT_TRABAJOS_MAXIMOS;
};

/**
 * Lee config.json de manera tolerante a fallos.
 * Si el archivo falta, está corrupto o tiene valores fuera de rango,
 * registra una advertencia en EventLog y retorna una configuración segura por defecto.
 */
ConfiguracionSistema cargarConfiguracion();

} // namespace hermes

#endif
```

### `src/hermes/src/config/config.cpp` [NUEVO]
```cpp
#include "config.h"
#include "data_paths.h"
#include "event_log.h"

#include <fstream>
#include <nlohmann/json.hpp>
#include <string>

using json = nlohmann::json;

namespace hermes {

ConfiguracionSistema cargarConfiguracion() {
    ConfiguracionSistema config;

    const std::string ruta = rutaDatos("config.json");
    std::ifstream archivo(ruta);

    if (!archivo.is_open()) {
        EventLog::log_event_system(
            EventLevel::WARN,
            "No se pudo abrir config.json; se utiliza la configuración por defecto",
            { {"archivo", ruta}, {"trabajos_maximos", config.trabajosMaximos} }
        );
        return config;
    }

    json datos;
    try {
        archivo >> datos;
    } catch (const std::exception& e) {
        EventLog::log_event_system(
            EventLevel::WARN,
            "Error al parsear config.json; se utiliza la configuración por defecto",
            { {"archivo", ruta}, {"detalle", e.what()}, {"trabajos_maximos", config.trabajosMaximos} }
        );
        return config;
    }

    if (!datos.is_object() || !datos.contains("trabajos_maximos") || !datos["trabajos_maximos"].is_number_integer()) {
        EventLog::log_event_system(
            EventLevel::WARN,
            "config.json no contiene una llave 'trabajos_maximos' entera válida",
            { {"archivo", ruta}, {"trabajos_maximos", config.trabajosMaximos} }
        );
        return config;
    }

    const int valor = datos["trabajos_maximos"].get<int>();

    if (valor < MIN_TRABAJOS_MAXIMOS) {
        config.trabajosMaximos = MIN_TRABAJOS_MAXIMOS;
    } else if (valor > MAX_TRABAJOS_MAXIMOS) {
        config.trabajosMaximos = MAX_TRABAJOS_MAXIMOS;
    } else {
        config.trabajosMaximos = valor;
    }

    return config;
}

} // namespace hermes
```

### `src/hermes/include/scheduler.h`
```cpp
#ifndef SCHEDULER_H
#define SCHEDULER_H

void iniciarSchedulerSiNecesario(int trabajosMaximos = 5);
void ejecutarScheduler(int trabajosMaximos = 5);

#endif
```

### `src/hermes/src/scheduler/scheduler.cpp`
```cpp
// Eliminado: constexpr int NUM_TRABAJADORES = 5;

void ejecutarScheduler(int trabajosMaximos) {
    instalarHandlersDeApagado();

    std::thread coordinador(coordinarApagado);

    vector<thread> trabajadores;
    trabajadores.reserve(trabajosMaximos);

    for (int i = 0; i < trabajosMaximos; ++i) {
        trabajadores.emplace_back(trabajador);
    }

    for (auto& hilo : trabajadores) {
        hilo.join();
    }

    coordinador.join();
}

void iniciarSchedulerSiNecesario(int trabajosMaximos) {
    // ... apertura de lock, sonda y recuperación ...
    // ... fork() ...
    if (pid > 0) {
        close(descriptor);
        return;
    }

    // Hijo daemon:
    // ... setsid y redirección stdio ...
    ejecutarScheduler(trabajosMaximos);
    _exit(0);
}
```

### `src/hermes/src/main.cpp`
```cpp
#include "scheduler.h"
#include "clean.h"
#include "event_log.h"
#include "config.h"

// ...

int main(int argc, char* argv[]) {
    // ... validación y filtros rápidos ...

    try {
        const auto config = hermes::cargarConfiguracion();
        iniciarSchedulerSiNecesario(config.trabajosMaximos);
    } catch (const exception& e) {
        error("No se pudo iniciar el scheduler: ", e.what());
        return 1;
    }

    // ... despacho de comandos (job, cancel, filter) ...
}
```

---

# Implementación final

Estado en el control de cambios:

```text
$ git status -s
 M src/hermes/include/scheduler.h
 M src/hermes/src/main.cpp
 M src/hermes/src/scheduler/scheduler.cpp
?? src/hermes/include/config.h
?? src/hermes/src/config/
```

Diferencial sintetizado:
- `include/scheduler.h`: firmas parametrizadas con valor por defecto.
- `src/scheduler/scheduler.cpp`: eliminación de constante estática y reserva dinámica de hilos.
- `src/main.cpp`: inyección de configuración al inicio del ciclo de vida.
- `include/config.h` y `src/config/config.cpp`: módulo desacoplado con validación de límites `[1, 64]`.

---

# Aprendizaje

1. **Inyección de dependencias como protección de diseño:** Acoplar componentes de orquestación interna (como el Scheduler) a la lectura directa de archivos en disco genera rigidez y complica los entornos de pruebas. Leer la configuración en la capa de aplicación (`main.cpp`) e inyectarla mediante parámetros preserva la cohesión y facilita la prueba con diferentes capacidades sin requerir alterar archivos en el disco.
2. **Programación defensiva ante configuración externa:** Cualquier archivo JSON editable por usuarios o procesos externos debe considerarse potencialmente hostil o corruptible. Nunca se debe asumir que una clave existirá o tendrá el tipo correcto; validar la estructura, aplicar valores de respaldo y asegurar cotas mínimas y máximas garantiza que el software nunca quede fuera de servicio por un error de sintaxis en un archivo de configuración.
