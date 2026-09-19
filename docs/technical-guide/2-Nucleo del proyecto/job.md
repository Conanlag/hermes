# Gestión de Jobs — RF-01

## 1. Objetivo

El módulo `job` implementa la funcionalidad correspondiente al **RF-01** de Hermes:

> El sistema deberá aceptar el envío de un comando o programa con sus argumentos y devolver un identificador único de trabajo.

En esta etapa, Hermes **no ejecuta el programa recibido**. El programa y sus argumentos únicamente se almacenan dentro de una estructura `Job` y se genera un identificador para el trabajo.

---

# 2. Estructura del módulo

La implementación utiliza la siguiente estructura:

```text
hermes/
├── src/
│   ├── job/
│   │   ├── job.h
│   │   └── job.cpp
│   │
│   └── main.cpp
│
└── data/
    └── job_id
```

### Componentes

| Archivo / directorio | Responsabilidad                                                  |
| -------------------- | ---------------------------------------------------------------- |
| `job.h`              | Define la estructura `Job` y declara la función `crearJob()`     |
| `job.cpp`            | Implementa la creación del Job y generación del ID               |
| `data/job_id`        | Almacena el siguiente identificador disponible                   |
| `main.cpp`           | Recibe los argumentos del comando y solicita la creación del Job |

---

# 3. `job.h`

## 3.1 Propósito

El archivo `job.h` contiene la definición de la estructura que representa un trabajo dentro de Hermes.

También declara la función encargada de crear un nuevo Job.

## 3.2 Dependencias

```cpp
#include <string>
#include <vector>
```

Se utilizan:

* `std::string` para almacenar el nombre del programa.
* `std::vector<std::string>` para almacenar sus argumentos.

## 3.3 Estructura `Job`

```cpp
struct Job {
    unsigned int id;
    string programa;
    vector<string> argumentos;
};
```

La estructura contiene actualmente tres elementos:

### `id`

```cpp
unsigned int id;
```

Identificador del trabajo.

Este valor permite distinguir un Job de otro.

### `programa`

```cpp
string programa;
```

Contiene el nombre o comando recibido por Hermes.

Ejemplo:

```text
ls
```

### `argumentos`

```cpp
vector<string> argumentos;
```

Contiene los argumentos asociados al programa.

Por ejemplo, para:

```bash
hermes job ls -la /tmp
```

se almacena:

```text
programa = "ls"

argumentos:
    "-la"
    "/tmp"
```

## 3.4 Función `crearJob()`

La función se declara como:

```cpp
Job crearJob(
    const string& programa,
    const vector<string>& argumentos
);
```

Recibe:

1. El programa.
2. Los argumentos del programa.

Y devuelve:

```cpp
Job
```

con un identificador asignado.

---

# 4. `job.cpp`

## 4.1 Propósito

`job.cpp` contiene la implementación de `crearJob()`.

Su responsabilidad actual es:

1. Obtener el siguiente ID disponible.
2. Crear un `Job`.
3. Asignar el ID.
4. Guardar el programa.
5. Guardar los argumentos.
6. Actualizar el siguiente ID disponible.
7. Devolver el Job.

El módulo **no ejecuta el programa recibido**.

## 4.2 Archivo de identificadores

La función utiliza:

```cpp
const string archivoId = "data/job_id";
```

Este archivo permite conservar el identificador entre diferentes ejecuciones de Hermes.

Por ejemplo:

```text
data/job_id
```

puede contener:

```text
5
```

Esto significa que el siguiente Job utilizará el ID `5`.

Después de crear el Job, el archivo se actualiza con:

```text
6
```

## 4.3 Lectura del ID

Se utiliza:

```cpp
ifstream archivoLectura(archivoId);
```

Si el archivo existe, se obtiene el siguiente identificador:

```cpp
archivoLectura >> siguienteId;
```

Si el archivo todavía no existe, se utiliza:

```cpp
unsigned int siguienteId = 1;
```

Por lo tanto, el primer Job comienza con el ID `1`.

## 4.4 Creación del Job

El Job se crea mediante:

```cpp
Job job;
```

Posteriormente se asignan sus datos:

```cpp
job.id = siguienteId;
job.programa = programa;
job.argumentos = argumentos;
```

Por ejemplo:

```bash
hermes job ls -la /tmp
```

produce conceptualmente:

```text
Job
├── id: 1
├── programa: "ls"
└── argumentos:
    ├── "-la"
    └── "/tmp"
```

## 4.5 Actualización del identificador

Después de crear el Job, se actualiza el archivo:

```cpp
archivoEscritura << siguienteId + 1;
```

Esto permite que el siguiente Job utilice un identificador diferente.

Por ejemplo:

```text
Primer Job:
ID = 1
Archivo = 2

Segundo Job:
ID = 2
Archivo = 3

Tercer Job:
ID = 3
Archivo = 4
```

---

# 5. Directorio `data`

## 5.1 Propósito

El directorio `data/` contiene información persistente utilizada por Hermes.

Actualmente únicamente contiene:

```text
data/
└── job_id
```

## 5.2 Archivo `job_id`

`job_id` almacena el siguiente identificador disponible para un nuevo Job.

Ejemplo:

```text
4
```

Significa que el siguiente Job creado tendrá:

```text
Job ID: 4
```

Después de crearlo, el archivo se actualizará a:

```text
5
```

## 5.3 Persistencia

La utilización de este archivo permite conservar el contador después de que termina el proceso de Hermes.

Por ejemplo:

```bash
hermes job ls
```

```text
Job ID: 1
```

Después:

```bash
hermes job pwd
```

```text
Job ID: 2
```

El segundo comando es una nueva ejecución del programa `hermes`, pero el identificador no vuelve a comenzar desde `1` porque el valor se conserva en:

```text
data/job_id
```

---

# 6. Flujo de RF-01

El flujo actual es:

```text
Usuario
   │
   │ hermes job ls -la /tmp
   ▼
main.cpp
   │
   │ programa + argumentos
   ▼
crearJob()
   │
   ├── obtiene siguiente ID
   ├── crea Job
   ├── almacena programa
   ├── almacena argumentos
   └── actualiza data/job_id
   │
   ▼
Job ID
   │
   ▼
Usuario
```

Ejemplo:

```bash
hermes job ls -la /tmp
```

Resultado:

```text
Job ID: 1
```

El comando `ls` **no se ejecuta**.

---