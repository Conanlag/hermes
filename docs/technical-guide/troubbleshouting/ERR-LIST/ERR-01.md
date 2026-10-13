# ERR-01 Hermes job solo se puede ejecutar y cancelar en la ruta relativa del proyecto: 

## Contexto: 
Al estar en la ruta `hermes/src/hermes` podemos ejecutar compilar el proyecto. mediante el comando `make install` podemos ejecutar en cualquier parte del sistema el comando hermes por ejemplo `hermes --version,` `hermes filter` sin embargo, si ejecutamos `hermes job` o `hermes cancel`
fuera de `hermes/src/hermes` tendremos problemas en ejecutar el proceso pedido..

## Reproduccion:
1. Estar en  `hermes/src/hermes`
2. Ejecutar:
``
cd
``
3. Ejecutar `hermes job sleep 30`

4. Se muestra el error:
```
terminate called after throwing an instance of 'std::runtime_error'
  what():  No se pudo guardar jobs.json
Aborted (core dumped)
```
## Posibles soluciones:
1. Dejar de guardar jobs.json dentro del proyecto y que lo guarde en el directorio de datos del usuario.
El programa detecta automaticamente `$HOME`:
```
$HOME/.local/share/hermes/jobs.json
```
sin embargo esta solucion mientras estamos en la etapa de desarrollo dificultara la visualizacion de los procesos.

2. Misma solucion pero haciendo un mount bind en las carpetas para visualizar los datos.
```
sudo mount --bind /home/leo/proyecto/hermes/hermes-bin /home/leo/.local/bin
```
ayudara a ver los datos de jobs.json pero esto no puede ser posible para el usuario final. Solo para desarrolladores.
