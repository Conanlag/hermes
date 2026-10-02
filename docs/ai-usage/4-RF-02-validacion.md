# Uso de inteligencia artificial

# 4. Validación de solicitudes RF-02

## Objetivo

Implementamos la validación centralizada de solicitudes de Hermes (RF-02): rechazar entradas vacías, mal formadas o no autorizadas con un mensaje útil, sin crashear por conversión numérica directa (`std::stoul` sin protección) y sin persistir programas vacíos en `jobs.json`.

Se buscó que la solución respetara la arquitectura existente (`include/` como contrato, `src/<modulo>/` como implementación), usara `enum class`, `const string&` y `try/catch`, y se integrara en `main.cpp` como guardián previo a `crearJob` y `filtrarPor*`.

---

(NOTA: el contenido de agents.md se encuentra al final de este archivo)

## Prompt 1
```text
Lee las reglas en agents.md. Quiero que actuemos según el Flujo de Trabajo para Nuevas Features. Vamos a implementar el RF-02: El sistema deberá validar la solicitud y rechazar entradas vacías, mal formadas o no autorizadas con un mensaje útil.. Empieza por la Fase 1 (Análisis y Diseño del Contrato) y muéstrame los cambios en los .h antes de programar la lógica.
```

---

## Resultado 1

Se propuso un nuevo módulo transversal `validator` en lugar de repartir la lógica entre `job.h` y `filter.h`, con este contrato:

```cpp
enum class CodigoValidacion { OK, VACIO, MALFORMADO, NO_AUTORIZADO };

struct ResultadoValidacion {
    bool esValido;
    CodigoValidacion codigo;
    string mensaje;
};

ResultadoValidacion validarComando(const string& comando);
ResultadoValidacion validarPrograma(const string& programa);
ResultadoValidacion validarTipoFiltro(const string& tipoFiltro);
ResultadoValidacion validarIdTexto(const string& textoId);
ResultadoValidacion validarStatusTexto(const string& status);
```

En Fase 2 se implementó `src/validator/validator.cpp`, donde `validarIdTexto` encapsula `std::stoul(textoId, &pos)` con verificación `pos != size` más `try/catch` de `invalid_argument` y `out_of_range`. En Fase 3 se integró en `main.cpp` con el patrón guardián `if (!r.esValido) { error(r.mensaje); return 1; }` antes de cada delegación.

---

## Prompt 2
```text
no entendi el uso de pos y como se uso para validar, me lo explicas?
```

---

## Resultado 2

Se explicó que `std::stoul(texto, &pos)` es permisivo: convierte `"12x"` en `12` con `pos = 2`. Sin el chequeo `pos != textoId.size()` ese caso se aceptaría como `12` (falso positivo). Con el chequeo se exige consumo total. La capa `try/catch` atrapa basura total (`"abc"` → `invalid_argument`, desbordamiento → `out_of_range`) y `pos` atrapa basura parcial (`"12x"`). El desarrollador confirmó el modelo mental (`pos` como parámetro de salida `size_t`).

---

## Prompt 3
```text
le hice cambios al main.cpp para evitar redundancia, verifica si es correcto y dame lo que tengo que hacer para debuggearlo (tambien dime como recompilo el programa con make)
```

---

## Resultado 3

Se detectó que los cambios habían eliminado guardas necesarias: el `if (comando == "job")` con `if (argc < 3)` y el `if (argc < 4)` en `filter`. Se explicó que no eran redundantes: `argc` protege existencia (memoria) y `validator` protege contenido (negocio). Sin `argc` se lee `argv[2]/argv[3]` inexistente (comportamiento indefinido). La versión editada además dejó `string programa` con ámbito recortado y llaves descuadradas, por lo que no compilaba.

Posteriormente se diagnosticó un falso fallo (`hermes filter id 12x` devolvía `No se encontró el Job ID: 12`): se ejecutaba el binario instalado (`hermes`) en lugar del recién compilado (`./hermes`). Tras `make clean && make` y `make install`, el caso `12x` pasó a rechazarse como `ID mal formado`.

---

# Modificaciones
**Estado de la resolución:** Aceptado tras verificación

**Revisión realizada:** Verificamos que `validator.h/.cpp` cubrieran las tres categorías (vacías, mal formadas, no autorizadas), que `main.cpp` mantuviera ambas capas (`argc` + `validator`), que las llaves y ámbitos estuvieran balanceados y que el `Makefile` descubriera `validator.cpp` vía `find` sin edición manual. Criticamos el intento de eliminar los `argc` como redundancia: son la capa de memoria, no duplican al validador. También criticamos probar con el binario instalado en vez del local.

**Cambios aplicados:** Restauramos `if (comando == "job")` + `if (argc < 3)` y `if (comando == "filter")` + `if (argc < 4)`; agregamos `#include <stdexcept>` en `validator.cpp` para los `catch`; corregimos el mensaje de uso de `filter`; dejamos intactas las validaciones de contenido propuestas por la IA.

**Prueba agregada:** Compilando en WSL con `make clean && make` desde `src/hermes` y ejecutando `./hermes filter id 12x`, `./hermes filter id abc`, `./hermes filter status running` y `./hermes foo` (rechazos con mensaje útil y código `1`), más `./hermes job sleep 5` y `./hermes filter id 1` (camino feliz sin efectos laterales en casos inválidos).

---

## Implementación de feature

Se integró el módulo `validator` como puerta de entrada de RF-02: `main.cpp` valida comando, programa, tipo de filtro, ID y estado antes de delegar. `validarIdTexto` eliminó el crash por `stoul` directo y `validarStatusTexto` restringe a los cinco valores del `enum class Status` con mensaje que lista los permitidos.

---

## Modificación de archivo

Nuevo `src/hermes/include/validator.h` con `CodigoValidacion`, `ResultadoValidacion` y cinco prototipos por `const string&`.

Nuevo `src/hermes/src/validator/validator.cpp` con listas blancas y `stoul` protegido:

```cpp
size_t pos = 0;
unsigned long valor = std::stoul(textoId, &pos);
if (pos != textoId.size()) {
    return {false, CodigoValidacion::MALFORMADO, "ID mal formado: " + textoId + ". Debe ser un numero entero positivo."};
}
```

Modificado `src/hermes/src/main.cpp`: `#include "validator.h"` más guardianes en ramas `job` y `filter`; la conversión a `unsigned int` solo ocurre tras validación exitosa.

---

# Implementación final

Flujo real verificado en WSL desde `src/hermes`:

```bash
./hermes filter id 12x
```

```text
ID mal formado: 12x. Debe ser un numero entero positivo.
```

```bash
./hermes job sleep 5
./hermes filter id 1
```

```text
job ID: 1
Job ID: 1
Programa: sleep
Estado: QUEUED
Argumentos: 5
```

Los rechazos terminan con código `1` y no modifican `data/jobs.json`.

---

# Aprendizaje

Aprendimos que `std::stoul` sin `pos` perdona basura parcial y que `argc` (existencia) y validador (contenido) son capas distintas, no redundancia. También aprendimos a distinguir `./hermes` (recién compilado) de `hermes` (instalado) al probar, y que centralizar el rechazo temprano con `enum class` + `struct` de resultado hace el flujo defendible: fallamos rápido con mensaje útil y sin efectos laterales.

# agents.md:
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
