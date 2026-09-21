# Nucleo del proyecto

## Estructura de archivos

Actualmente, el núcleo de ejecución de Hermes está compuesto por los siguientes archivos:
```
hermes/
├── include/
│   ├── job.h
│   ├── status.h
│   └── version.h
│
├── src/
│   ├── job/
│   │   └── job.cpp
│   ├── status/
│   │   └── status.cpp
│   ├── version/
│   │   └── version.cpp
│   ├── IPC/
│   ├── database/
│   ├── network/
│   └── main.cpp
│
├── data/
│   └── .gitkeep
│
├── Makefile
└── README.md
```
Los archivos documentados en esta sección corresponden al punto de entrada del programa y a los primeros comandos implementados:

- En la carpeta ```Include``` se encontraran las liberias necesarias para el proyecto
- En la carpeta ```Data``` se encontraran los archivos de persistencia
- En la carpeta ```Job``` se encontraran los archivos relacionados con los procesos
- En la carpeta ```Status``` se encontrarn los archivos relacionados con el manejo de estados
- En la carpeta ```Version``` se encontraran los archivos relacionados con el comando version
- En la carpeta ```database``` se encontrarán los archivos para mantener la persistencia e historial de los procesos.
- En la carpeta ```IPC``` se encontrarán los archivos para la comunicacion entre los procesos
- En la carpeta ```network``` se encontrarán los archivos para la comunicacion entre computadoras dentro de la misma red.