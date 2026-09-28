# ADR-004: Estructura de módulos

## Contexto

Se requiere una estructura interna que permita organizar el código de acuerdo con las responsabilidades de cada componente. Debido a que el proyecto continuará incorporando funcionalidades como gestión de procesos, estados, persistencia, IPC y comunicación de red, mantener toda la lógica dentro de `main.cpp` dificultaría la lectura, mantenimiento y extensión del código.

Por este motivo, es necesario establecer una organización de carpetas que permita separar las bibliotecas, los módulos funcionales y los archivos de persistencia.

## Decisión

Se utilizará una estructura modular basada en la separación de responsabilidades. Los archivos de cabecera desarrollados por el proyecto y las bibliotecas externas se almacenarán en `include/`, mientras que la implementación de cada módulo se encontrará dentro de su propia carpeta en `src/`.
Además los datos de persistencia se almacenarán en `data/`.

La estructura inicial será:

```text
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

* **`include/`**: contendrá las bibliotecas propias del proyecto y las bibliotecas externas que sean necesarias para la compilación.
* **`src/`**: contendrá la implementación de los diferentes módulos del proyecto.
* **`src/job/`**: contendrá las funciones relacionadas con la creación y administración de jobs.
* **`src/status/`**: contendrá la lógica relacionada con los estados de los jobs.
* **`src/filter/`**: contendrá la lógica relacionada con los filtros de búsqueda de jobs.
* **`src/version/`**: contendrá la implementación del comando `version`.
* **`src/IPC/`**: contendrá los componentes relacionados con la comunicación entre procesos.
* **`src/network/`**: contendrá los componentes relacionados con la comunicación entre computadoras dentro de una red.
* **`data/`**: contendrá temporalmente la información persistente de los procesos, como `jobs.json`.
* **`main.cpp`**: funcionará como punto de entrada del programa y se encargará principalmente de interpretar los comandos y coordinar los diferentes módulos.

Los módulos se mantendrán separados para evitar convertir `main.cpp` en un archivo monolítico con una gran cantidad de código. Cada funcionalidad tendrá su propia implementación y podrá ser utilizada desde `main.cpp` mediante sus archivos de cabecera.

Además, se utilizará la opción `-Iinclude` en el `Makefile` para indicar al compilador la ubicación de las cabeceras. De esta manera, los archivos de implementación podrán incluir las bibliotecas del proyecto sin necesidad de declarar individualmente cada ruta de inclusión dentro del `Makefile`.

| Justificación     | La separación por módulos permite organizar el código de acuerdo con sus responsabilidades, mejorar la legibilidad y facilitar el mantenimiento y crecimiento del proyecto.                                                                                                                    |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | 1. No utilizar archivos de cabecera: declarar directamente las funciones de otros archivos .cpp dentro de los archivos donde sean utilizadas. 2. No separar los módulos por carpetas: mantener los archivos .cpp de los diferentes módulos directamente dentro de src/.                                                                                                                                                                       |
| Consecuencias     | El código queda distribuido en componentes independientes, facilitando la incorporación de nuevas funcionalidades y reduciendo la cantidad de lógica concentrada en `main.cpp`. Como consecuencia, será necesario mantener una estructura de archivos y dependencias correctamente organizada. |
| Riesgos           | Una separación excesiva o una mala definición de responsabilidades puede generar dependencias innecesarias entre módulos y dificultar la comprensión de la estructura del proyecto.                                                                                                            |
| Evidencia técnica | El proyecto contará con directorios independientes para `job`, `status`, `filter`, `version`, `IPC` y `network`, mientras que sus archivos de cabecera estarán centralizados en `include/`. El `Makefile` utilizará `-Iinclude` para localizar dichas cabeceras durante la compilación.        |
