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
│   └── jobs.json
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
- ```data/```: contendrá temporalmente la información persistente de los procesos, como jobs.json.
- ```main.cpp```: funcionará como punto de entrada del programa y se encargará principalmente de interpretar los comandos y coordinar los diferentes módulos.

Los módulos se mantendrán separados para evitar convertir main.cpp en un archivo monolítico con una gran cantidad de código. Cada funcionalidad tendrá su propia implementación y podrá ser utilizada desde main.cpp mediante sus archivos de cabecera.