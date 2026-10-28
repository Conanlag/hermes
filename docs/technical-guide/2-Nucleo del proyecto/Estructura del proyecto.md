# Nucleo del proyecto

## Estructura de archivos

Actualmente, el núcleo de ejecución de Hermes está compuesto por los siguientes archivos:
```
hermes/
├── include/
│   ├── nlohmann/
│   │   └── json.hpp
│   ├── cancel.h
│   ├── clean.h
│   ├── data_paths.h
│   ├── filter.h
│   ├── help.h
│   ├── job.h
│   ├── process.h
│   ├── scheduler.h
│   ├── status.h
│   ├── storage.h
│   ├── terminal.colors.h
│   ├── timestamp.h
│   ├── validator.h
│   └── version.h
│
├── src/
│   ├── cancel/
│   │   └── cancel.cpp
│   ├── clean/
│   │   └── clean.cpp
│   ├── filter/
│   │   └── filter.cpp
│   ├── help/
│   │   └── help.cpp
│   ├── job/
│   │   └── job.cpp
│   ├── network/
│   ├── process/
│   │   └── process.cpp
│   ├── scheduler/
│   │   └── scheduler.cpp
│   ├── status/
│   │   └── status.cpp
│   ├── storage/
│   │   └── storage.cpp
│   ├── validator/
│   │   └── validator.cpp
│   ├── version/
│   │   └── version.cpp
│   └── main.cpp
│
├── data/
│   └── -> $HOME/.local/share/hermes/data/
│
├── Makefile
└── README.md
```
Cada directorio tendrá una responsabilidad específica:

- ```include/```: contendrá las bibliotecas propias del proyecto y las bibliotecas externas que sean necesarias para la compilación.
- ```include/nlohmann/```: dependencia externa header-only `nlohmann/json`, usada para la persistencia en JSON.
- ```src/```: contendrá la implementación de los diferentes módulos del proyecto.
- ```src/job/```: contendrá las funciones relacionadas con la creación y administración de jobs.
- ```src/status/```: contendrá la lógica relacionada con los estados de los jobs.
- ```src/filter/```: contendrá la lógica relacionada con los filtros de búsqueda de jobs.
- ```src/version/```: contendrá la implementación del comando version.
- ```src/help/```: contendrá la implementación del comando de ayuda (texto de uso).
- ```src/validator/```: contendrá la validación de entradas del usuario y los códigos de error asociados.
- ```src/process/```: contendrá la gestión de procesos hijos (espera, terminación y escalado de cancelación).
- ```src/cancel/```: contendrá la lógica del comando de cancelación de jobs.
- ```src/clean/```: contendrá la lógica del comando de limpieza del historial persistente.
- ```src/scheduler/```: contendrá el scheduler en segundo plano que lanza los jobs pendientes.
- ```src/storage/```: contendrá el acceso serializado al almacenamiento JSON (lectura/escritura con bloqueo).
- ```src/network/```: contendrá los componentes relacionados con la comunicación entre computadoras dentro de una red.
- `data/`: enlace simbólico a `$HOME/.local/share/hermes/data/`; la ruta física contiene los archivos persistentes de Hermes.
- ```main.cpp```: funcionará como punto de entrada del programa y se encargará principalmente de interpretar los comandos y coordinar los diferentes módulos.

### Cabeceras header-only

Tres cabeceras de `include/` no tienen `.cpp` asociado porque su implementación es `inline`:

- ```timestamp.h```: obtención de la fecha y hora actual formateada.
- ```terminal.colors.h```: utilidades de salida con color para mensajes de error, advertencia e información.
- ```data_paths.h```: resolución e inicialización de las rutas del directorio persistente de datos.

Los módulos se mantendrán separados para evitar convertir main.cpp en un archivo monolítico con una gran cantidad de código. Cada funcionalidad tendrá su propia implementación y podrá ser utilizada desde main.cpp mediante sus archivos de cabecera.

El `Makefile` descubre los fuentes con `find src -type f -name '*.cpp'`, por lo que un nuevo módulo con su `.cpp` dentro de `src/` se compila sin editar el `Makefile`.

## Directorio de datos persistentes

La ruta física usada por Hermes es:

```text
$HOME/.local/share/hermes/data/
```

En el repositorio, `src/hermes/data` es un enlace simbólico a ese directorio. Así, las rutas relativas de desarrollo como `data/jobs.json` y la ruta persistente del usuario apuntan a los mismos archivos. Hermes crea el directorio y los archivos necesarios al inicializar sus rutas de datos.

| Archivo | Contenido o función |
| ------- | ------------------- |
| `jobs.json` | Arreglo JSON con el historial y los metadatos de cada Job: ID, programa, argumentos, estado, PID, tiempos y resultado. |
| `config.json` | Configura `trabajos_maximos`, el máximo de workers simultáneos (de 1 a 64). Se lee al iniciar el scheduler; si falta o no es válido, se usa el valor predeterminado `5`. |
| `jobs.lock` | Archivo de bloqueo que `flock` usa para serializar modificaciones concurrentes del almacenamiento. |
| `scheduler.lock` | Bloqueo exclusivo que conserva abierto el scheduler en segundo plano para evitar iniciar otro scheduler al mismo tiempo; también contiene el PID del daemon para `hermes clean scheduler`. |

Se puede revisar la ruta y su contenido con:

```bash
readlink -f src/hermes/data
ls -la "$HOME/.local/share/hermes/data"
```