# RNF-20 — Pruebas automatizadas

## Descripción

Se implementó un sistema de pruebas automatizadas para verificar el funcionamiento de Hermes de manera rápida y reproducible.

Las pruebas se encuentran en el directorio `test/` y permiten comprobar diferentes funcionalidades del sistema sin necesidad de realizar las verificaciones manualmente.

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

Cuando una prueba se ejecuta correctamente se muestra:

```text
[PASS]
```

Cuando una prueba falla:

```text
[FAIL]
```

Además, `make test` devuelve un código de salida `0` cuando todas las pruebas son exitosas y `1` cuando alguna prueba falla.

---

## Estructura del módulo

Las pruebas automatizadas se encuentran organizadas de la siguiente manera:

```text
hermes/
├── Makefile
├── data/
├── include/
├── src/
└── test/
    └── test.sh
```

El archivo `test.sh` contiene las funciones necesarias para ejecutar las pruebas, obtener los identificadores de los Jobs, consultar sus estados y determinar si cada prueba fue exitosa.

El `Makefile` contiene el objetivo:

```makefile
test: $(TARGET)
	@./test/test.sh
```

Esto permite compilar Hermes y ejecutar las pruebas mediante:

```bash
make test
```

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

La prueba de cancelación utiliza un proceso de larga duración:

```bash
hermes job sleep 10
```

Después de aproximadamente dos segundos se solicita su cancelación:

```bash
hermes cancel <job_id>
```

Finalmente, la prueba verifica que el estado registrado sea:

```text
CANCELED
```

Esto permite comprobar que la cancelación se realiza sobre un proceso que todavía está en ejecución y no después de que el Job haya terminado.
