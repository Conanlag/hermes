# RNF-20 — Pruebas automatizadas

## Descripción

Se implementó un sistema de pruebas automatizadas para verificar el funcionamiento de Hermes de manera rápida y reproducible.

Las pruebas se encuentran en el directorio `tests/` y permiten comprobar diferentes funcionalidades del sistema sin necesidad de realizar las verificaciones manualmente.

La ejecución de todas las pruebas se realiza mediante un único comando:

```bash
make test
```

---

## Objetivo

El objetivo es automatizar la validación de las principales funcionalidades de Hermes y detectar errores de manera temprana.

Las pruebas verifican:

* Generación correcta del ejecutable.
* Ejecución del comando `--version`.
* Creación y ejecución de Jobs.
* Finalización correcta de procesos.
* Manejo de programas inexistentes.
* Cancelación de procesos en ejecución.
* Filtrado de Jobs.
* Estados finales de los Jobs.

Cada prueba muestra su resultado en la terminal mediante:

```text
[PASS]
```

cuando la prueba es exitosa, y:

```text
[FAIL]
```

cuando se produce un error.

Al finalizar, el script devuelve un código de salida `0` si todas las pruebas fueron exitosas. Si alguna prueba falla, devuelve `1`.

---

## Estructura del módulo

Las pruebas automatizadas se encuentran organizadas de la siguiente manera:

```text
hermes/
├── Makefile
├── data/
├── include/
├── src/
└── tests/
    └── test.sh
```

El archivo `test.sh` contiene el conjunto de pruebas automatizadas y las funciones necesarias para ejecutarlas y comprobar sus resultados.

Antes de ejecutar las pruebas por primera vez, es necesario otorgar permiso de ejecución al script mediante:

```bash
chmod +x tests/test.sh
```

El comando `chmod +x` agrega el permiso de ejecución al archivo `test.sh`, permitiendo que Linux pueda ejecutarlo directamente.

Después de otorgar el permiso, las pruebas pueden ejecutarse con:

```bash
make test
```

El `Makefile` contiene el objetivo encargado de ejecutar las pruebas:

```makefile
test: $(TARGET)
	@./tests/test.sh
```

De esta manera, `make test` primero compila el ejecutable `hermes` y posteriormente ejecuta el script `test.sh`.

El permiso de ejecución del script solamente necesita configurarse una vez, siempre que el archivo conserve dicho permiso.

---

## Definición de los estados

Las pruebas automatizadas utilizan los estados definidos para los Jobs de Hermes:

| Estado      | Descripción                                                                          |
| ----------- | ------------------------------------------------------------------------------------ |
| `QUEUED`    | El Job fue creado y está esperando iniciar su ejecución.                             |
| `RUNNING`   | El proceso asociado al Job se encuentra ejecutándose.                                |
| `SUCCEEDED` | El proceso terminó correctamente con código de salida `0`.                           |
| `FAILED`    | El proceso terminó con un código de salida diferente de `0` o no pudo ejecutarse.    |
| `CANCELED`  | El Job recibió una solicitud de cancelación mientras el proceso estaba ejecutándose. |

Las pruebas comprueban diferentes transiciones de estado. Por ejemplo, para una ejecución correcta:

```text
QUEUED → RUNNING → SUCCEEDED
```

Para un proceso que no puede ejecutarse:

```text
QUEUED → RUNNING → FAILED
```

Y para un proceso cancelado:

```text
QUEUED → RUNNING → CANCELED
```

En particular, la prueba de cancelación utiliza un proceso de larga duración:

```bash
hermes job sleep 10
```

La prueba espera aproximadamente dos segundos y posteriormente solicita su cancelación:

```bash
hermes cancel <job_id>
```

Finalmente, verifica que el Job termine con el estado:

```text
CANCELED
```

Esto permite comprobar que Hermes puede cancelar un proceso real mientras todavía se encuentra en ejecución, en lugar de solicitar la cancelación después de que el proceso haya terminado.
