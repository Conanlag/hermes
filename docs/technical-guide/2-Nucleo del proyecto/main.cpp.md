# Main.cpp

Main.cpp tiene la responsabilidad es recibir los argumentos proporcionados desde la línea de comandos, identificar el comando solicitado y delegar su ejecución a la función correspondiente.

## Dependencias
Las dependencias son las siguientes:
```
#include <iostream>
#include <string>
```
- iostream se utiliza para mostrar datos de E/S. 
- string permite trabajar con los comandos identificarlos y ejecutarlos.

## Funciones externas declaradas

antes de ```main()```  declaran las funciones que se utilizan de otros archivos.

```
int proceso();
int version();
```

## Funcion main

``` int main(int argc, char* argv[])```

parametros: 
- argc: Cantidad de argumentos recibidos por el programa
- argv: Arreglo que contiene los argumentos recibidos

## Comandos implementados

Se puede ejecutar el programa de dos maneras. 
1. ```./hermes ```
2. hermes

los comandos actuales son:


```
hermes
```
**hermes** da como salida "HOLA ESTE ES EL INICIO DEL PROYECTO"

```
hermes --version
```

**hermes** *--version* da como salida "version 0.1"

```
hermes fork
```

**hermes** *fork* da como salida "Hola estoy en pid-ppid.cpp" y como se genera un proceso hijo vuelve a dar la misma salida en la siguiente linea.


