# Uso de inteligencia artificial

## 11 - Utilizar procesos reales para `hermes job`

## Objetivo

Durante el desarrollo inicial de Hermes se implementó la creación de Jobs utilizando una lógica que todavía no ejecutaba procesos reales del sistema operativo.

Posteriormente se identificó que el requerimiento necesitaba que `hermes job` ejecutara realmente los programas indicados por el usuario. Esto implicó trabajar directamente con procesos de Linux y mecanismos como `fork()`, `execvp()`, `waitpid()` y señales.

Para comprender e implementar correctamente este comportamiento se utilizó inteligencia artificial como apoyo durante el desarrollo.

## Prompt

> “Quiero que `hermes job` ejecute comandos reales en Linux, sin sudo y que el proceso se ejecute en segundo plano para que la terminal no quede bloqueada.”

También se realizaron consultas relacionadas con:

> “¿Cómo puedo crear procesos reales en C++ usando Linux?”

> “¿Cómo puedo utilizar `fork`, `execvp` y `waitpid` para ejecutar y supervisar un proceso?”

> “Quiero que el Job tenga un PID real y que el estado cambie dependiendo de cómo termine el proceso.”

## Resultado

A partir de las consultas se identificó que la ejecución de un programa real podía realizarse mediante las funciones proporcionadas por Linux.

La solución propuesta utilizó una separación entre la creación del Job y la ejecución del proceso:

```text
hermes job <programa> [argumentos]
              │
              ▼
          crearJob()
              │
              ▼
            fork()
          ┌───┴───┐
          │       │
       padre     hijo
          │       │
          │    execvp()
          │       │
          │    proceso real
          │       │
          └──waitpid()
```

Esto permitió que Hermes dejara de trabajar únicamente con procesos simulados y comenzara a ejecutar programas reales del sistema.

## Modificaciones

Se realizaron modificaciones principalmente en el módulo encargado de los Jobs y en el módulo de procesos.

Se incorporó un PID real al `Job`:

```cpp
struct Job {
    unsigned int job_id;
    int pid;
    string programa;
    vector<string> argumentos;
    Status status;
    int codigoSalida;
};
```

Se implementó la creación de procesos mediante `fork()`.

El proceso hijo utiliza `execvp()` para reemplazar su ejecución por el programa solicitado:

```text
fork()
  │
  ├── Padre
  │
  └── Hijo → execvp()
```

También se implementó `waitpid()` para que Hermes pueda conocer cuándo termina el proceso y cuál fue su resultado.

Además, se incorporó el código de salida:

```cpp
int codigoSalida;
```

Esto permitió determinar si el proceso terminó correctamente o si ocurrió un error.

Por ejemplo:

```text
Código 0   → SUCCEEDED
Código != 0 → FAILED
```

También se agregó manejo para el caso en que el programa solicitado no exista. En este caso el proceso termina con un código de error y el Job queda registrado como `FAILED`.

## Implementación final

La implementación final permite ejecutar comandos reales mediante:

```text
hermes job <programa> [argumentos]
```

Por ejemplo:

```text
hermes job sleep 30
```

produce un Job asociado a un proceso Linux real:

```text
job ID: 5
PID: 1842
```

El Job comienza en:

```text
QUEUED
```

y posteriormente pasa a:

```text
RUNNING
```

Mientras el proceso continúa ejecutándose, Hermes conserva su PID y puede consultar su estado.

Cuando el proceso termina, Hermes utiliza `waitpid()` para obtener el resultado y actualiza el Job:

```text
RUNNING → SUCCEEDED
```

si el programa terminó correctamente, o:

```text
RUNNING → FAILED
```

si terminó con un código de error.

También se implementó posteriormente la cancelación mediante:

```text
hermes cancel <id>
```

lo que permite terminar un proceso en ejecución y registrar:

```text
RUNNING → CANCELED
```

De esta manera, Hermes actualmente trabaja con procesos reales del sistema operativo en lugar de únicamente simular su ejecución.

## Aprendizaje

Durante esta parte del desarrollo se aprendió que la ejecución de un comando desde un programa en C++ requiere interactuar directamente con los mecanismos proporcionados por el sistema operativo.

Se comprendió la función de:

* `fork()` para crear un nuevo proceso.
* `execvp()` para ejecutar el programa solicitado.
* `waitpid()` para esperar y obtener el resultado del proceso.
* `PID` para identificar un proceso específico.
* Códigos de salida para determinar el resultado de una ejecución.
* Señales de Linux para controlar procesos.

También se aprendió que la implementación de Jobs no consiste únicamente en almacenar información en un archivo, sino que debe existir una relación entre el Job registrado por Hermes y el proceso real que está ejecutándose en el sistema operativo.
