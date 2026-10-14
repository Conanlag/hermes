# SOL-02 Resolución de ERR-02: Manejo de entradas de usuario en programas ejecutados mediante Hermes

## Problema identificado

El comando `hermes job` no permitía ejecutar correctamente programas que requieren entradas del usuario durante su ejecución.

Al ejecutar un programa como `input.py` mediante:

```bash
hermes job python3 input.py
```

el programa intentaba solicitar información mediante la función `input()` de Python. Sin embargo, el proceso no recibía las entradas esperadas y terminaba con una excepción `EOFError`.

El problema se relacionaba con la configuración de los flujos estándar del proceso hijo. Para evitar que los programas mostraran su salida directamente en la terminal, se realizaron redirecciones de sus flujos de salida. Sin embargo, la entrada estándar (`stdin`) también debe estar disponible cuando el programa necesita recibir datos del usuario.

Como consecuencia, el trabajo terminaba con código de salida `1` y su estado se registraba como `FAILED` en `jobs.json`.

## Solución implementada

Se propone modificar el módulo `process.cpp` para permitir que los programas ejecutados mediante Hermes reciban entradas desde la terminal, sin modificar el mecanismo de supervisión y registro de los trabajos.

La solución contempla los siguientes comportamientos:

- **Entrada estándar (`stdin`):** conservar la entrada estándar heredada de Hermes para que los programas puedan recibir información del usuario.
- **Salida estándar (`stdout`):** redirigirla a `/dev/null` para evitar que la salida del programa aparezca directamente en la terminal.
- **Salida de errores (`stderr`):** mantener su captura mediante un pipe para que Hermes pueda filtrar los mensajes que muestra.
- **Control de ejecución:** conservar el seguimiento del PID, el código de salida y el estado final del trabajo.

La modificación debe realizarse en el proceso hijo, antes de ejecutar `execvp()`. No es necesario modificar la estructura de `jobs.json` para implementar esta solución.

## Configuración del código fuente

### 1. Modificar `process.cpp`

Dentro de la función `iniciarProceso()`, localizar el bloque correspondiente al proceso hijo:

```cpp
if (pid == 0) {
    // Configuración de los flujos estándar
}
```

En esta sección, conservar la redirección de `stdout` a `/dev/null` y la redirección de `stderr` al pipe. No se debe redirigir `STDIN_FILENO` a `/dev/null`, ya que esto impediría que los programas recibieran entradas del usuario.

La configuración de los flujos debe mantener el siguiente comportamiento:

```cpp
// Conservar stdin heredado de Hermes.

// Descartar stdout.
dup2(salidaNula, STDOUT_FILENO);

// Capturar stderr para que Hermes pueda procesarlo.
dup2(pipefd[1], STDERR_FILENO);
```

Las llamadas a `dup2()` deben comprobar sus valores de retorno y manejar los errores antes de continuar con `execvp()`.

### 2. Mantener el filtrado de errores en `job.cpp`

En la función `leerStderrProceso()`, conservar el filtro que permite mostrar el mensaje cuando no se encuentra el ejecutable:

```cpp
if (
    mensaje.find("No se pudo ejecutar el programa '") == 0
) {
    error(mensaje);
}
```

Aplicar el mismo criterio al texto restante que se procesa al finalizar la lectura del pipe.

Este comportamiento permite mantener la salida normal de los programas fuera de la terminal y mostrar el mensaje específico de Hermes cuando falla la ejecución del ejecutable.

### 3. No modificar la persistencia de los trabajos

Los campos existentes en `jobs.json` continúan siendo suficientes para registrar el resultado de la ejecución:

- `job_id`
- `pid`
- `programa`
- `argumentos`
- `status`
- `codigo_salida`
- `tiempo_recepcion`
- `tiempo_inicio`
- `tiempo_terminacion`

Si el usuario proporciona correctamente todas las entradas solicitadas y el programa termina con código `0`, Hermes debe registrar el trabajo como `SUCCEEDED`. Si el programa termina con un código distinto de `0`, debe conservarse el comportamiento existente y registrar el estado `FAILED`, salvo que se haya solicitado y gestionado una cancelación.

## Instalación y verificación

Una vez realizados los cambios, recompilar Hermes:

```bash
make clean
make
make install
```

### Prueba 1. Ejecutar un programa que no requiere entradas

```bash
hermes job echo hola
```

Resultado esperado: Hermes registra el trabajo sin mostrar directamente `hola` en la terminal.

### Prueba 2. Ejecutar un programa que solicita entradas

Crear un archivo `input.py` con el siguiente contenido:

```python
print("--- FECHA DE NACIMIENTO ---")
dia_nac = int(input("Introduce el día de nacimiento (DD): "))
mes_nac = int(input("Introduce el mes de nacimiento (MM): "))
anio_nac = int(input("Introduce el año de nacimiento (AAAA): "))

print("\n--- FECHA ACTUAL ---")
dia_act = int(input("Introduce el día actual (DD): "))
mes_act = int(input("Introduce el mes actual (MM): "))
anio_act = int(input("Introduce el año actual (AAAA): "))

edad = anio_act - anio_nac

if (mes_act < mes_nac) or (
    mes_act == mes_nac and dia_act < dia_nac
):
    edad -= 1

print(f"\nTu edad exacta es: {edad} años.")
```

Ejecutar:

```bash
hermes job python3 input.py
```

El programa debe poder leer los datos ingresados por el usuario. Sin embargo, dado que `stdout` continúa redirigido a `/dev/null`, los mensajes impresos mediante `print()` no aparecerán directamente en la terminal. Para una experiencia interactiva completa, también se necesita definir cómo se mostrarán los mensajes y las respuestas de los programas.

### Prueba 3. Verificar el estado del trabajo

Consultar el archivo de persistencia:

```bash
cat "$HOME/.local/share/hermes/data/jobs.json"
```

Resultado esperado: si el programa recibió las entradas necesarias y terminó correctamente, el registro debe incluir:

```json
{
    "programa": "python3",
    "argumentos": [
        "input.py"
    ],
    "status": "SUCCEEDED",
    "codigo_salida": 0
}
```

Los valores de `job_id`, `pid` y las marcas de tiempo dependerán de la ejecución.

## Verificación de la solución

| Prueba | Resultado esperado |
|---|---|
| Ejecutar un programa sin entradas | El trabajo se ejecuta sin mostrar su salida estándar |
| Ejecutar un programa que utiliza `input()` | El proceso conserva el acceso a `stdin` |
| Ejecutar un programa que termina correctamente | Se registra `SUCCEEDED` con código `0` |
| Ejecutar un programa que termina con error | Se registra `FAILED` con su código de salida |
| Ejecutar un programa inexistente | Hermes muestra el mensaje correspondiente de error |
| Revisar `jobs.json` | Se conservan los datos y estados de ejecución |

## Resultado esperado

Hermes conserva su mecanismo de ejecución y supervisión de procesos, permitiendo que los programas hereden la entrada estándar de la terminal mientras su salida estándar continúa descartándose y los errores se procesan mediante el mecanismo existente.

Esta modificación evita cerrar deliberadamente la entrada estándar del proceso hijo. No obstante, **no implementa por sí sola una interfaz interactiva completa**: para que el usuario pueda leer los mensajes que solicita el programa y responderlos desde Hermes, será necesario definir una estrategia adicional para gestionar la salida y la entrada interactivas.

La solución debe probarse en el entorno de cada desarrollador antes de considerar resuelto el error ERR-02.
