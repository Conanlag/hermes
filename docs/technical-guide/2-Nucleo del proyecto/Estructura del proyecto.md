# Nucleo del proyecto

## Estructura de archivos

Actualmente, el núcleo de ejecución de Hermes está compuesto por los siguientes archivos:
```
hermes/
├── data/jobs.json
├── include/
│   └── nlohmann/
│         └──  json.hpp
├── src/
│   ├── job/
│   |   |── job.cpp
│   |   └──  job.h
│   │
│   ├── database/
│   ├── IPC/
│   ├── network/
│   └── main.cpp
│
├── hermes
└── Makefile
```
Los archivos documentados en esta sección corresponden al punto de entrada del programa y a los primeros comandos implementados:

- En la carpeta ```commands``` se encontrarán los archivos .cpp que puedan ejecutarse como comandos
- En la carpeta ```database``` se encontrarán los archivos para mantener la persistencia e historial de los procesos.
- En la carpeta ```IPC``` se encontrarán los archivos para la comunicacion entre los procesos
- En la carpeta ```network``` se encontrarán los archivos para la comunicacion entre computadoras dentro de la misma red.