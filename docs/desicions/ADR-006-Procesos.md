# ADR-005: Creación de procesos

## Contexto

Hermes debe permitir al usuario enviar un programa junto con sus argumentos y obtener un identificador único que permita identificar posteriormente el trabajo solicitado.

El sistema recibe el comando, almacena el programa y sus argumentos dentro de una estructura `Job`, genera un identificador único y persiste la información en `data/jobs.json`. 

La creación de un Job constituye la base para posteriormente implementar la ejecución de procesos, el control de estados, la concurrencia y la cancelación.

## Decisión

Se utilizará una estructura `Job` para representar cada trabajo solicitado a Hermes.

La estructura contendrá la información necesaria para identificar el trabajo y conservar los datos enviados por el usuario:

```cpp
struct Job {

    unsigned int job_id;

    string programa;

    vector<string> argumentos;

    Status status;

};
```

La creación del Job se realizará mediante la función:

```cpp
Job crearJob(
    const string& programa,
    const vector<string>& argumentos
);
```

La función recibirá únicamente el programa y sus argumentos. El identificador será generado internamente a partir de los Jobs almacenados previamente y el estado inicial será asignado automáticamente como `QUEUED`. 

El flujo de creación será:

```text
Usuario
   │
   │ hermes job <programa> [argumentos]
   ▼
main.cpp
   │
   │ crearJob()
   ▼
job.cpp
   │
   ├── Leer jobs.json
   ├── Obtener siguiente ID
   ├── Crear Job
   ├── Asignar programa
   ├── Asignar argumentos
   ├── Asignar estado QUEUED
   └── Guardar Job
          │
          ▼
     data/jobs.json
```

El identificador se obtendrá recorriendo los Jobs existentes y buscando el ID más alto. El siguiente Job utilizará el valor siguiente. Por ejemplo, si existen los IDs `1` y `5`, el nuevo Job recibirá el ID `6`. 

La información del Job será almacenada en `data/jobs.json`, permitiendo conservar los trabajos después de finalizar la ejecución del programa Hermes. 

La ejecución real del programa queda fuera del alcance de esta implementación. En esta etapa, Hermes solamente recibe, identifica y almacena el Job.

| Justificación     | Utilizar una estructura `Job` permite encapsular la información asociada a cada trabajo y separar la creación de Jobs de la ejecución de procesos. El ID se genera a partir de la información persistida, evitando utilizar un archivo independiente exclusivamente para controlar los identificadores. |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | Ejecutar directamente el programa recibido desde `main.cpp` sin crear una estructura `Job`, o Mantener la información del Job únicamente en memoria: crear el Job y asignarle un identificador durante la ejecución de Hermes, sin persistirlo en jobs.json. 3. Separar la generación del ID en un archivo independiente: utilizar un archivo dedicado como data/job_id para almacenar y administrar el siguiente identificador.                                                                                                                                 |
| Consecuencias     | Hermes puede recibir comandos con argumentos, generar identificadores únicos y conservar los Jobs entre diferentes ejecuciones del programa. La ejecución del programa y el control completo de su ciclo de vida quedan pendientes para etapas posteriores.                                             |
| Riesgos           | Si `jobs.json` se elimina o se encuentra corrupto, Hermes puede perder el historial necesario para determinar el siguiente identificador. Además, buscar el ID recorriendo todos los Jobs puede resultar menos eficiente cuando exista una cantidad muy grande de registros.                            |
| Evidencia técnica | `crearJob()` lee `data/jobs.json`, determina el siguiente identificador, crea el objeto `Job`, almacena el programa y sus argumentos, agrega el registro al arreglo JSON y vuelve a escribir el archivo. El módulo no ejecuta el programa recibido.                                                     |

