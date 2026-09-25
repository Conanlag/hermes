# Uso de inteligencia artificial

# 3. Implementar salidas de error

## Objetivo

Implementar un mecanismo centralizado para manejar las salidas de información, advertencias y errores dentro de Hermes.

La intención inicial era diferenciar los mensajes mostrados por el programa mediante `stdout` y `stderr`, además de utilizar colores para identificar visualmente cada tipo de mensaje.

Se buscó que la solución pudiera utilizarse desde diferentes módulos del proyecto, como `main.cpp` y `filter.cpp`, evitando repetir los códigos ANSI y la lógica de salida en cada archivo.

---

## Prompt 1

Se solicitó una forma de mostrar todos los mensajes de error mediante `stderr` utilizando el color rojo en Linux y que pudiera utilizarse desde cualquier archivo `.cpp` del proyecto.

La propuesta inicial fue crear un módulo independiente:

```text
src/
└── terminal/
    ├── terminal.colors.h
    └── terminal.colors.cpp
```

El módulo contenía funciones independientes para errores, advertencias e información:

```cpp
void error(const std::string& mensaje);
void warning(const std::string& mensaje);
void info(const std::string& mensaje);
```

La implementación utilizaba códigos ANSI para modificar temporalmente el color de la terminal.

---

## Resultado 1

Se obtuvo una primera implementación basada en `std::string`:

```cpp
void error(const std::string& mensaje) {
    std::cerr << "\033[31m"
              << mensaje
              << "\033[0m"
              << std::endl;
}
```

De manera similar se implementaron las funciones `warning()` e `info()`.

Los colores definidos fueron:

```text
error()   → rojo
warning() → amarillo
info()    → salida normal
```

Esta solución permitía centralizar el manejo de colores y evitar repetir los códigos ANSI.

Sin embargo, se identificó una limitación: las funciones solamente recibían un `std::string`.

Por ejemplo, para mostrar un identificador numérico sería necesario realizar una conversión:

```cpp
error("No se encontró el Job ID: " + std::to_string(job_id));
```

Esto hacía menos flexible el uso del módulo.

---

## Prompt 2

Se solicitó modificar las funciones para permitir llamadas como:

```cpp
error("No se encontró el Job ID: ", job_id);
```

La intención era poder enviar directamente diferentes tipos de datos, como:

```cpp
std::string
int
unsigned int
const char*
```

sin tener que convertirlos manualmente a cadenas.

---

## Resultado 2

Se modificaron las funciones para utilizar templates variádicos de C++:

```cpp
template <typename... Args>
void error(const Args&... args) {
    std::cerr << "\033[31m";
    (std::cerr << ... << args);
    std::cerr << "\033[0m" << std::endl;
}
```

También se implementaron `warning()` e `info()`:

```cpp
template <typename... Args>
void warning(const Args&... args) {
    std::cerr << "\033[33m";
    (std::cerr << ... << args);
    std::cerr << "\033[0m" << std::endl;
}
```

```cpp
template <typename... Args>
void info(const Args&... args) {
    std::cout << "\033[34m";
    (std::cout << ... << args);
    std::cout << "\033[0m" << std::endl;
}
```

La función `info()` se modificó posteriormente para utilizar el color azul.

La implementación final permite utilizar múltiples argumentos:

```cpp
error("No se encontró el Job ID: ", job_id);

warning("Filtros disponibles: id, status, programa");

info("Uso: hermes Job <programa> [argumentos..]");
```

---

## Prompt 3

Se presentó un problema en `filter.cpp`, donde algunos mensajes estaban construidos de la siguiente manera:

```cpp
error("No se encontró el Job ID: " + job_id);
```

Al utilizar valores numéricos como `unsigned int`, la salida obtenida era incorrecta y en algunos casos aparecían mensajes truncados o información inesperada.

Se solicitó identificar la causa del problema y determinar si estaba relacionada con la función `error()`.

---

## Resultado 3

Se identificó que el problema no estaba en el template variádico, sino en la expresión:

```cpp
"No se encontró el Job ID: " + job_id
```

Cuando el primer elemento es un literal de cadena y `job_id` es un valor numérico, la expresión no realiza una concatenación de cadenas.

El literal es tratado como un puntero `const char*` y la operación `+` realiza aritmética de punteros.

Por ejemplo:

```cpp
error("No se encontró el Job ID: " + job_id);
```

no debe utilizarse cuando `job_id` es numérico.

La forma correcta con el nuevo módulo es:

```cpp
error("No se encontró el Job ID: ", job_id);
```

De esta manera, cada argumento se envía directamente al flujo correspondiente mediante el fold expression.

También se modificaron otros mensajes para utilizar el mismo formato:

```cpp
error("No se puede abrir: ", archivoJobs);
```

```cpp
error("Error al leer: ", archivoJobs);
```

```cpp
error("No se encontraron Jobs con estado: ", status);
```

```cpp
error("No se encontraron Jobs con el programa indicado: ", programa);
```

---

# Modificaciones

## Creación del módulo `terminal.colors`

Se creó un módulo independiente para centralizar las salidas:

```text
src/
└── terminal/
    └── terminal.colors.h
```

Debido a que las funciones utilizan templates, la implementación se mantiene directamente en el archivo `.h`.

Por este motivo, ya no es necesario utilizar:

```text
terminal.colors.cpp
```

---

## Implementación de `error()`

La función `error()` utiliza `stderr` mediante `std::cerr` y muestra los mensajes en rojo:

```cpp
template <typename... Args>
void error(const Args&... args) {
    std::cerr << "\033[31m";
    (std::cerr << ... << args);
    std::cerr << "\033[0m" << std::endl;
}
```

---

## Implementación de `warning()`

La función `warning()` utiliza `stderr` y muestra los mensajes en amarillo:

```cpp
template <typename... Args>
void warning(const Args&... args) {
    std::cerr << "\033[33m";
    (std::cerr << ... << args);
    std::cerr << "\033[0m" << std::endl;
}
```

---

## Implementación de `info()`

La función `info()` utiliza `stdout` mediante `std::cout` y muestra los mensajes en azul:

```cpp
template <typename... Args>
void info(const Args&... args) {
    std::cout << "\033[34m";
    (std::cout << ... << args);
    std::cout << "\033[0m" << std::endl;
}
```

---

## Modificación de `main.cpp`

Los mensajes de `main.cpp` fueron adaptados para utilizar el nuevo módulo.

Ejemplo de error:

```cpp
error("Comando no reconocido: ", comando);
```

Mensaje informativo:

```cpp
info("Uso: hermes Job <programa> [argumentos..]");
```

Advertencia:

```cpp
warning("Filtros disponibles: id, status, programa");
```

De esta manera, `main.cpp` ya no necesita implementar directamente los códigos ANSI.

---

## Modificación de `filter.cpp`

Los mensajes relacionados con los filtros también fueron adaptados:

```cpp
error("No se puede abrir: ", archivoJobs);
```

```cpp
error("No se encontró el Job ID: ", job_id);
```

Esto permite enviar directamente tanto cadenas como valores numéricos.

También se eliminaron mensajes duplicados que utilizaban `cout` para reportar errores, centralizando este tipo de salida mediante `error()`.

---

## Separación de `stdout` y `stderr`

La implementación estableció una separación entre los diferentes tipos de salida:

| Función     | Canal    | Color    | Uso                |
| ----------- | -------- | -------- | ------------------ |
| `info()`    | `stdout` | Azul     | Información normal |
| `warning()` | `stderr` | Amarillo | Advertencias       |
| `error()`   | `stderr` | Rojo     | Errores            |

Esto permite aprovechar los mecanismos de redirección proporcionados por Linux.

Por ejemplo:

```bash
hermes filter id 10 > salida.txt
```

redirige `stdout`, mientras que:

```bash
hermes filter id 10 2> errores.txt
```

redirige `stderr`.

---

# Implementación final

El archivo utilizado por Hermes quedó de la siguiente manera:

```cpp
#ifndef TERMINAL_COLORS_H
#define TERMINAL_COLORS_H

#include <iostream>

template <typename... Args>
void error(const Args&... args) {
    std::cerr << "\033[31m";
    (std::cerr << ... << args);
    std::cerr << "\033[0m" << std::endl;
}

template <typename... Args>
void warning(const Args&... args) {
    std::cerr << "\033[33m";
    (std::cerr << ... << args);
    std::cerr << "\033[0m" << std::endl;
}

template <typename... Args>
void info(const Args&... args) {
    std::cout << "\033[34m";
    (std::cout << ... << args);
    std::cout << "\033[0m" << std::endl;
}

#endif
```

---

# Aprendizaje

Aprendí que existen diferentes formas de manejar las salidas de un programa en Linux y que `stdout` y `stderr` cumplen funciones diferentes dentro de la ejecución de un proceso.

También aprendí que una solución aparentemente sencilla, como concatenar directamente un mensaje con un valor numérico mediante `+`, puede producir comportamientos incorrectos debido a la forma en que C++ interpreta los tipos y las operaciones entre punteros.

El uso de templates variádicos permitió crear una solución más flexible, ya que las funciones pueden recibir diferentes tipos de datos y múltiples argumentos sin realizar conversiones manuales.

Además, aprendí la importancia de centralizar funcionalidades comunes en módulos reutilizables. En lugar de implementar los colores y el manejo de errores en cada archivo, `terminal.colors.h` permite utilizar las mismas funciones desde diferentes módulos de Hermes.

Finalmente, comprendí que elegir correctamente el mecanismo de salida es importante para mantener un flujo de ejecución claro y evitar errores. La separación entre información, advertencias y errores permite que el programa sea más fácil de utilizar, depurar y automatizar mediante las herramientas proporcionadas por Linux.

