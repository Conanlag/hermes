# ADR-005: Implementación de persistencia

## Contexto

El sistema Hermes debe ser capaz de conservar el historial de los procesos creados, incluso después de cerrar y volver a ejecutar el programa. La información mínima que debe persistirse corresponde al identificador del job, el nombre del programa, sus argumentos y su estado.

Para el Hito-01 se necesitó decidir entre utilizar archivos de texto, archivos JSON o integrar un motor de base de datos ligero como SQLite.

El mecanismo seleccionado también debía permitir que el proyecto pudiera ejecutarse desde cero sin requerir que el usuario instalara o configurara servicios adicionales.

## Decisión

Se utilizará **JSON como formato de persistencia**, mediante un archivo `jobs.json` ubicado dentro del directorio `data/`.

La estructura actual de cada job será:

```json
{
    "argumentos": [
        ""
    ],
    "job_id": 1,
    "programa": "",
    "status": ""
}
```

El archivo `jobs.json` será creado y administrado automáticamente por Hermes. De esta manera, el usuario no necesita crear manualmente el archivo de persistencia antes de ejecutar el programa.

Para trabajar con JSON desde C++, se utilizará la biblioteca **nlohmann/json**, la cual permite leer y escribir estructuras JSON directamente desde el código del proyecto.

La persistencia permitirá conservar información como:

* `job_id`: identificador único del proceso.
* `programa`: nombre del programa asociado al job.
* `argumentos`: argumentos utilizados por el programa.
* `status`: estado actual del job.

## Justificación

Se seleccionó JSON debido a que proporciona una estructura más organizada y sencilla de manipular que un archivo de texto plano, además de permitir que la información pueda ser leída y modificada directamente desde C++ mediante una biblioteca especializada.

Durante las pruebas se consideró inicialmente utilizar un archivo `.txt` para almacenar los identificadores. Sin embargo, esta alternativa presentaba problemas para administrar la persistencia cuando el archivo no existía. Por ejemplo, si `jobs.txt` no se encontraba disponible, se podía perder el registro necesario para determinar el siguiente `job_id`.

Además, el archivo de persistencia debe ser administrado por la computadora del usuario y no formar parte de los archivos que se mantienen en el repositorio de GitHub. Esto implicaría agregar el archivo al `.gitignore` y requerir que cada usuario creara manualmente el archivo antes de ejecutar el programa.

Con `jobs.json`, Hermes puede comprobar si el archivo existe y generarlo automáticamente cuando sea necesario, evitando esta configuración manual.

También se identificó la biblioteca **nlohmann/json**, que permite realizar la serialización y deserialización de JSON en C++, facilitando la implementación de la persistencia sin desarrollar manualmente un parser para el formato.

La utilización de un motor de base de datos como SQLite se consideró innecesaria para el alcance actual del Hito-01. Aunque SQLite permitiría administrar la información de manera estructurada, introduciría una capa adicional de complejidad para un sistema que actualmente solo necesita almacenar y recuperar el historial de jobs. Para este punto del proyecto, JSON permite cumplir con el requisito sin requerir la configuración de un servidor o una infraestructura de base de datos.

| Justificación     | JSON permite almacenar el historial de jobs de manera estructurada y puede ser creado, leído y actualizado directamente por Hermes mediante la biblioteca `nlohmann/json`. Además, permite que el archivo de persistencia sea generado automáticamente sin requerir configuración adicional por parte del usuario.                 |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | **1. Archivo de texto (`.txt`):** almacenar los datos directamente como texto. **2. SQLite:** utilizar un motor de base de datos ligero para administrar la persistencia.                                                                                                                                                          |
| Consecuencias     | Hermes puede conservar el historial de jobs entre ejecuciones y crear automáticamente `jobs.json` cuando no existe. El proyecto incorpora una dependencia adicional para el manejo de JSON y los datos persistidos quedan almacenados en un archivo estructurado.                                                                  |
| Riesgos           | Si el archivo `jobs.json` se elimina o se corrompe, Hermes puede perder el historial almacenado. Además, al tratarse de un archivo completo, el manejo de grandes cantidades de jobs podría resultar menos eficiente que utilizar una base de datos.                                                                               |
| Evidencia técnica | El proyecto cuenta con `data/jobs.json` como archivo de persistencia y utiliza la biblioteca `nlohmann/json` para leer y escribir los jobs. Cada registro almacena `job_id`, `programa`, `argumentos` y `status`. El archivo de datos se mantiene fuera del código fuente y puede excluirse del repositorio mediante `.gitignore`. |
