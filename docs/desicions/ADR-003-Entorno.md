# ADR-002: Entorno de compilación

## Contexto

El proyecto está desarrollado en C++ y requiere un mecanismo para automatizar y estandarizar el proceso de compilación de los diferentes archivos fuente que lo conforman.

## Decisión

Se utilizará Makefile como sistema de automatización de compilación y g++ como compilador de C++.

| Justificación     | Make permite automatizar la compilación y administrar las dependencias entre los archivos del proyecto, mientras que g++ proporciona el compilador necesario para generar el ejecutable. |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | Compilación manual con g++, CMake                                                                                                                                                        |
| Consecuencias     | Se simplifica el proceso de compilación y se evita ejecutar manualmente los comandos para cada archivo. El proyecto queda dependiente de la configuración definida en el Makefile.       |
| Riesgos           | Una configuración incorrecta del Makefile puede provocar errores de compilación o que no se actualicen correctamente las dependencias.                                                   |
| Evidencia técnica | El proyecto contará con un Makefile que permitirá ejecutar comandos como `make`, `make clean` y `make install`, utilizando g++ para compilar el código fuente.                           |
