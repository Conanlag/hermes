# Nucleo del proyecto

## Estructura de archivos

Actualmente, el núcleo de ejecución de Hermes está compuesto por los siguientes archivos:
```
hermes/
├── include/
│   ├── filter.h
│   ├── job.h
│   ├── status.h
│   └── version.h
│
├── src/
│   ├── filter/
│   │   └── filter.cpp
│   ├── job/
│   │   └── job.cpp
│   ├── status/
│   │   └── status.cpp
│   ├── version/
│   │   └── version.cpp
│   ├── IPC/
│   ├── network/
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
- ```src/```: contendrá la implementación de los diferentes módulos del proyecto.
- ```src/job/```: contendrá las funciones relacionadas con la creación y administración de jobs.
- ```src/status/```: contendrá la lógica relacionada con los estados de los jobs.
- ```src/filter/```: contendrá la lógica relacionada con los filtros de búsqueda de jobs.
- ```src/version/```: contendrá la implementación del comando version.
- ```src/IPC/```: contendrá los componentes relacionados con la comunicación entre procesos.
- ```src/network/```: contendrá los componentes relacionados con la comunicación entre computadoras dentro de una red.
- `data/`: enlace simbólico a `$HOME/.local/share/hermes/data/`; la ruta física contiene los archivos persistentes de Hermes.
- ```main.cpp```: funcionará como punto de entrada del programa y se encargará principalmente de interpretar los comandos y coordinar los diferentes módulos.

Los módulos se mantendrán separados para evitar convertir main.cpp en un archivo monolítico con una gran cantidad de código. Cada funcionalidad tendrá su propia implementación y podrá ser utilizada desde main.cpp mediante sus archivos de cabecera.

## Directorio de datos persistentes

La ruta física usada por Hermes es:

```text
$HOME/.local/share/hermes/data/
```

En el repositorio, `src/hermes/data` es un enlace simbólico a ese directorio. Así, las rutas relativas de desarrollo como `data/jobs.json` y la ruta persistente del usuario apuntan a los mismos archivos. Hermes crea el directorio y los archivos necesarios al inicializar sus rutas de datos.

| Archivo | Contenido o función |
| ------- | ------------------- |
| `jobs.json` | Arreglo JSON con el historial y los metadatos de cada Job: ID, programa, argumentos, estado, PID, tiempos y resultado. |
| `config.json` | Configuración inicial con `trabajos_maximos: 5`. Actualmente se crea como valor predeterminado, pero el código no lo lee para configurar el scheduler. |
| `jobs.lock` | Archivo de bloqueo que `flock` usa para serializar modificaciones concurrentes del almacenamiento. |
| `scheduler.lock` | Bloqueo exclusivo que conserva abierto el scheduler en segundo plano para evitar iniciar otro scheduler al mismo tiempo. |

Se puede revisar la ruta y su contenido con:

```bash
readlink -f src/hermes/data
ls -la "$HOME/.local/share/hermes/data"
```