# Dependencia nlohmann/json

## Descripción

Hermes utiliza **nlohmann/json v3.12.0** para trabajar con archivos JSON desde C++.

Esta dependencia se utiliza para la persistencia de los `Job`, permitiendo leer y modificar el archivo que contiene el arreglo de trabajos. Entre los datos almacenados se encuentran:

* `job_id`
* `programa`
* `argumentos`

La biblioteca **nlohmann/json** es *header-only*, por lo que no requiere una compilación o enlace de una biblioteca adicional.

Para mantener el proyecto reproducible, la versión utilizada por Hermes se encuentra incluida directamente dentro del repositorio.

## Versión utilizada

```text
nlohmann/json v3.12.0
```

El archivo utilizado es:

```text
json.hpp
```

y corresponde al *single-header* de nlohmann/json.

## Ubicación dentro del proyecto

La dependencia se encuentra dentro del directorio `include` del proyecto:

```text
hermes/
├── include/
│   └── nlohmann/
│       └── json.hpp
├── src/
│   └── hermes/
│       ├── main.cpp
│       ├── job.cpp
│       ├── job.h
│       └── ...
├── data/
│   └── jobs.json
└── Makefile
```

Esto significa que Hermes no depende de que `nlohmann/json` esté instalado globalmente en el sistema operativo.

Por lo tanto, no es necesario instalar el paquete mediante el administrador de paquetes del sistema, por ejemplo:

```bash
sudo apt install nlohmann-json3-dev
```

La dependencia utilizada por Hermes ya forma parte del proyecto.

---

# Instalación para desarrollo

Para preparar el entorno de desarrollo, primero se debe obtener el repositorio de Hermes:

```bash
git clone <URL_DEL_REPOSITORIO>
cd hermes
```

La dependencia `nlohmann/json v3.12.0` ya debe encontrarse dentro del repositorio en:

```text
include/nlohmann/json.hpp
```

Si se está configurando el proyecto desde cero y el archivo todavía no existe, puede descargarse la versión correspondiente desde la release `v3.12.0`:

```bash
mkdir -p include/nlohmann

curl -L https://github.com/nlohmann/json/releases/download/v3.12.0/json.hpp \
    -o include/nlohmann/json.hpp
```

Después se puede comprobar que el archivo existe:

```bash
ls -lh include/nlohmann/json.hpp
```

Una vez descargado, el archivo debe mantenerse dentro del repositorio para que todos los desarrolladores utilicen la misma versión.

---

# Uso desde C++

Los archivos que necesiten utilizar la biblioteca pueden incluirla mediante:

```cpp
#include <nlohmann/json.hpp>

using json = nlohmann::json;
```

Por ejemplo, `job.cpp` utiliza la biblioteca para representar y manipular los datos de los trabajos:

```cpp
#include "job.h"
#include <nlohmann/json.hpp>

using json = nlohmann::json;
```

---

# Integración con Makefile

El `Makefile` configura `include/` como uno de los directorios donde el compilador debe buscar archivos de cabecera.

La configuración utiliza:

```make
CXX = g++
CXXFLAGS = -Wall -Wextra -std=c++17 -Iinclude
```

La opción:

```text
-Iinclude
```

indica al compilador que también debe buscar los archivos incluidos dentro del directorio `include`.

Por esta razón, cuando el código contiene:

```cpp
#include <nlohmann/json.hpp>
```

el compilador puede encontrar:

```text
include/nlohmann/json.hpp
```

durante la compilación.

No es necesario agregar una opción como:

```text
-ljson
```

porque nlohmann/json es una biblioteca *header-only*.

---

# Compilación

Una vez configurado el proyecto, la compilación se realiza mediante el `Makefile`:

```bash
make
```

El proceso utiliza el código fuente del proyecto junto con la dependencia almacenada en:

```text
include/nlohmann/json.hpp
```

y genera el ejecutable de Hermes.

La dependencia no necesita instalarse en `/usr/include`, `/usr/local/include` ni en ninguna otra ubicación global del sistema.

---

# Reproducibilidad

La dependencia se mantiene dentro del repositorio para evitar que la compilación dependa de la configuración específica de cada computadora.

De esta manera, cualquier desarrollador que obtenga el repositorio cuenta con la misma versión de `nlohmann/json` utilizada durante el desarrollo.

El usuario no necesita permisos de administrador ni modificar las dependencias globales del sistema para utilizar esta biblioteca.

## Requisitos del sistema

Aunque las bibliotecas del proyecto se mantienen dentro del repositorio, Hermes requiere las herramientas básicas necesarias para compilar un proyecto C++:

```text
g++
make
```

Estas herramientas pertenecen al entorno de desarrollo y son independientes de `nlohmann/json`.

La dependencia JSON utilizada por Hermes, en cambio, está incluida directamente en el proyecto:

```text
nlohmann/json v3.12.0
└── include/nlohmann/json.hpp
```

Esta estrategia permite que Hermes mantenga una versión fija y controlada de su dependencia JSON, evitando diferencias entre entornos de desarrollo y reduciendo la necesidad de instalar paquetes adicionales en el sistema operativo.
