# Uso de inteligencia artificial

## 2. Al generar un Id por cada proceso en JSON 

# Objetivo:
Se genero un archivo que mantenia la persistencia de los Ids dentro del programa, en un archivo ```jobs_id``` sin embargo solo guardaba el contador, pensando mas a futuro, puedo considerar la persistencia en este momento y como guardar los datos de cada proceso en un Arreglo en JSON sin embargo no se como realizarlo y necesito una guia para instalar lo necesario.



**Propmt:**
```

quiero hacer que un archivo de c++ pueda leer un arreglo en JSON leer la propiedad job_id y con base a eso agregar un nuevo job_id un campo programa y un campo argumentos, este es mi codigo que permite ahora generar solo guardar en memoria el contador de job_id

job.cpp
#include "job.h"
#include <fstream>

using std::ifstream;
using std::ofstream;

Job crearJob(
    const string& programa,
    const vector<string>& argumentos
){
    // Generar un ID por cada job creado
    const string archivoId = "data/job_id";
    
    unsigned int siguienteId = 1;

    // Leer el anterior Id Desde el archivo
        ifstream archivoLectura(archivoId);

    if (archivoLectura.is_open()) {
        archivoLectura >> siguienteId;
        archivoLectura.close();
    }

    // Crear el job 
    Job job;
    job.id = siguienteId;
    job.programa = programa;
    job.argumentos = argumentos;


    // Guardar el siguiente ID
    ofstream archivoEscritura(archivoId);

    if (archivoEscritura.is_open()) {
        archivoEscritura << siguienteId + 1;
        archivoEscritura.close();
    }

    return job;
}

job.h
#ifndef JOB_H
#define JOB_H

#include <string>
#include <vector>

using std::string;
using std::vector;

struct Job {
    unsigned int id;
    string programa;
    vector<string> argumentos;
};

Job crearJob(
    const string& programa,
    const vector<string>& argumentos
);

#endif

```

**Resultado**

```
Sí. En tu caso conviene cambiar el enfoque de `data/job_id` a un archivo JSON, por ejemplo:

```text
data/jobs.json
```

Y que tenga una estructura como esta:

```json
[
    {
        "job_id": 1,
        "programa": "ls",
        "argumentos": ["-la"]
    },
    {
        "job_id": 2,
        "programa": "echo",
        "argumentos": ["Hola mundo"]
    }
]
```

Entonces `crearJob()` haría lo siguiente:

1. Abrir `data/jobs.json`.
2. Leer el arreglo JSON.
3. Buscar el `job_id` más alto.
4. Generar `job_id + 1`.
5. Crear el `Job`.
6. Agregarlo al arreglo.
7. Guardar nuevamente el JSON.

### 1. Usar `nlohmann/json`

Para C++ te recomiendo **nlohmann/json**, porque permite trabajar con JSON de una manera bastante natural.

Tu estructura actual puede quedarse prácticamente igual:

```cpp
#ifndef JOB_H
#define JOB_H

#include <string>
#include <vector>

using std::string;
using std::vector;

struct Job {
    unsigned int id;
    string programa;
    vector<string> argumentos;
};

Job crearJob(
    const string& programa,
    const vector<string>& argumentos
);

#endif
```

### 2. `job.cpp`

Podrías dejarlo así:

```cpp
#include "job.h"

#include <fstream>
#include <nlohmann/json.hpp>

using std::ifstream;
using std::ofstream;

using json = nlohmann::json;

Job crearJob(
    const string& programa,
    const vector<string>& argumentos
) {
    const string archivoJobs = "data/jobs.json";

    json jobs = json::array();

    // Leer los jobs existentes
    ifstream archivoLectura(archivoJobs);

    if (archivoLectura.is_open()) {
        try {
            archivoLectura >> jobs;
        } catch (const json::parse_error&) {
            jobs = json::array();
        }

        archivoLectura.close();
    }

    // Buscar el siguiente job_id
    unsigned int siguienteId = 1;

    for (const auto& job : jobs) {
        if (job.contains("job_id") &&
            job["job_id"].is_number_unsigned()) {

            unsigned int id = job["job_id"];

            if (id >= siguienteId) {
                siguienteId = id + 1;
            }
        }
    }

    // Crear el job
    Job job;
    job.id = siguienteId;
    job.programa = programa;
    job.argumentos = argumentos;

    // Crear representación JSON del nuevo job
    json nuevoJob;

    nuevoJob["job_id"] = job.id;
    nuevoJob["programa"] = job.programa;
    nuevoJob["argumentos"] = job.argumentos;

    // Agregarlo al arreglo
    jobs.push_back(nuevoJob);

    // Guardar el archivo JSON
    ofstream archivoEscritura(archivoJobs);

    if (archivoEscritura.is_open()) {
        archivoEscritura << jobs.dump(4);
        archivoEscritura.close();
    }

    return job;
}
```

Con esto ya **no necesitas `data/job_id`**.

---

### 3. Ejemplo de funcionamiento

Si inicialmente tienes:

```json
[]
```

y haces:

```cpp
Job job = crearJob(
    "ls",
    {"-la"}
);
```

el archivo queda:

```json
[
    {
        "job_id": 1,
        "programa": "ls",
        "argumentos": [
            "-la"
        ]
    }
]
```

Después:

```cpp
Job job = crearJob(
    "echo",
    {"Hola"}
);
```

queda:

```json
[
    {
        "job_id": 1,
        "programa": "ls",
        "argumentos": [
            "-la"
        ]
    },
    {
        "job_id": 2,
        "programa": "echo",
        "argumentos": [
            "Hola"
        ]
    }
]
```

Y si cierras `hermes` y vuelves a ejecutarlo, **no pierde el contador**, porque ahora el ID se obtiene del JSON.

---

## Un detalle importante para Hermes

Para tu proyecto, yo **sí cambiaría el nombre `id` de `Job` a `job_id`** para que coincida directamente con tu modelo persistente:

```cpp
struct Job {
    unsigned int job_id;
    string programa;
    vector<string> argumentos;
};
```

Entonces en `job.cpp`:

```cpp
Job job;
job.job_id = siguienteId;
job.programa = programa;
job.argumentos = argumentos;
```

Y:

```cpp
nuevoJob["job_id"] = job.job_id;
```

Esto te evita tener una traducción innecesaria entre:

```text
Job.id
```

y:

```text
JSON.job_id
```

---

## También te recomiendo separar la persistencia

Como tu proyecto **Hermes** va a crecer hacia estados, timestamps, stdout/stderr, SQLite, etc., `job.cpp` puede terminar teniendo demasiada responsabilidad.

Por ahora está bien hacerlo directamente ahí, pero posteriormente podrías tener:

```text
src/hermes/
├── main.cpp
├── job.h
├── job.cpp
├── data/
│   └── jobs.json
└── ...
```

Y eventualmente:

```text
job.h
job.cpp

job-storage.h
job-storage.cpp
```

Donde:

```text
job.cpp
    -> creación y lógica de Job

job-storage.cpp
    -> leer/escribir JSON
```

Eso encaja bastante bien con el diseño que estás haciendo para el **Hito 1**, porque después puedes cambiar la implementación de almacenamiento de JSON a SQLite sin tener que modificar toda la lógica de `Job`.

### Instalación de `nlohmann/json` en Ubuntu/WSL

Si quieres usar el paquete del sistema:

```bash
sudo apt update
sudo apt install nlohmann-json3-dev
```

Y entonces:

```cpp
#include <nlohmann/json.hpp>
```

No necesitas enlazar ninguna biblioteca adicional al compilar, porque `nlohmann/json` es una biblioteca *header-only*.

Si tu `Makefile` actualmente compila algo como:

```make
g++ -Wall -Wextra -std=c++17 main.cpp job.cpp -o hermes
```

no necesitas agregar `-ljson` ni nada parecido.

## Resultados
Se pudo tener un resultado exitoso, sin embargo me toco investigar como hacerlo reproducible en cualquier computadora sin necesidad de sudo, la solucion fue tener instalada la libreria de manera local.

## Aprendizaje 
Me queda claro que la forma de implementar algo que yo conozco en otros programas, va a requerir que alguien mas haya programado la compatibilidad necesaria con c++, tambien me ayuda a conocer como se instalan las librerias externas de C++ que era algo que yo no sabia que se podia hacer hasta este momento. 