**# ERR-03 Hermes cancel interpreta identificadores negativos como valores positivos**

**## Contexto:**

Al ejecutar el comando `hermes cancel` con un identificador de Job negativo, Hermes no rechaza el valor como inválido, sino que lo convierte en un número entero positivo considerablemente mayor. Esto provoca que el mensaje de error muestre un ID diferente al que proporcionó el usuario, lo que puede generar confusión al diagnosticar el problema.

Por ejemplo, al proporcionar `-1`, Hermes muestra el identificador `4294967295`, correspondiente a la representación de `-1` como un entero sin signo de 32 bits.

**## Reproducción:**

1. Ejecutar el siguiente comando en la terminal:

```bash
hermes cancel -1
```

2. Observar la salida obtenida:

```text
No existe el Job ID: 4294967295
```

3. Verificar que el identificador mostrado no coincide con el valor proporcionado originalmente (`-1`).

**## Resultado esperado:**

Hermes debe validar que el identificador del Job sea un entero positivo válido antes de intentar cancelar el proceso. Si el usuario proporciona un valor negativo, el programa debe rechazarlo y mostrar un mensaje que indique que el ID no es válido.

Por ejemplo:

```text
Error: el Job ID debe ser un entero positivo.
```

**## Posibles soluciones:**

1. Validar el argumento recibido por `hermes cancel` antes de convertirlo al tipo de dato utilizado internamente.
2. Rechazar identificadores negativos, valores no numéricos y otros argumentos que no cumplan con el formato esperado.
3. Realizar la conversión numérica utilizando un mecanismo que permita detectar valores fuera del rango válido y evitar conversiones inesperadas entre enteros con signo y sin signo.