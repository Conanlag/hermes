**# SOL-03 Resolución de ERR-03: Validación de identificadores negativos en Hermes cancel**

**## Problema identificado:**

El comando `hermes cancel` permitía que un identificador negativo, como `-1`, fuera interpretado como un número entero sin signo debido al uso de `std::stoul()`. Como resultado, el identificador se convertía en un valor positivo inesperado, por ejemplo, `4294967295`, y Hermes mostraba un mensaje indicando que dicho Job no existía.

**## Solución implementada:**

Se modificó la función `validarIdTexto()` del módulo `validator` para validar que el identificador contenga únicamente caracteres numéricos del `0` al `9` antes de realizar la conversión.

```
    for (char caracter : textoId) {
        if (caracter < '0' || caracter > '9') {
            return {
                false,
                CodigoValidacion::MALFORMADO,
                "ID mal formado: " +
                textoId +
                ". Debe ser un numero entero positivo."
            };
        }
    }

```

Con esta modificación:

1. Se rechazan identificadores negativos y argumentos que contienen caracteres no numéricos.
2. Se mantiene la validación para impedir que el identificador sea igual a `0`.
3. Se conservan las excepciones para manejar valores fuera del rango permitido.
4. Se evita que entradas como `-1` sean convertidas a valores positivos inesperados durante la validación.

**## Verificación de la solución:**

Se establecieron las siguientes pruebas para comprobar el comportamiento de la validación:

| Entrada | Resultado esperado |
|---|---|
| `-1` | Rechazar por formato inválido |
| `0` | Rechazar porque el ID debe ser mayor que cero |
| `abc` | Rechazar por formato inválido |
| `1.5` | Rechazar por formato inválido |
| Un número fuera del rango permitido | Rechazar por estar fuera de rango |
| `47` | Aceptar el formato y comprobar si el Job existe |

**## Resultado:**

Al ejecutar `hermes cancel -1`, Hermes debe rechazar el argumento e informar que el identificador debe ser un número entero positivo, en lugar de intentar cancelar un Job con ID `4294967295`.

```
ID mal formado: -1. Debe ser un numero entero positivo.
```