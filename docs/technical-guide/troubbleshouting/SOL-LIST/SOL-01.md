# SOL-01 Resolución de ERR-01: Ejecución global de Hermes y vinculación del directorio de datos para desarrollo

## Problema identificado

El comando `hermes job` fallaba al ejecutarse fuera del directorio `hermes/src/hermes`, debido a que los archivos `jobs.json` y `config.json` se buscaban mediante rutas relativas:

```cpp
const string archivoJobs = "data/jobs.json";
const string archivoConfiguracion = "data/config.json";
```

Esto provocaba que Hermes intentara acceder a un directorio `data` dentro de la ubicación actual de la terminal, en lugar de utilizar una ubicación persistente y compartida.

## Solución implementada

Se centralizó la resolución de las rutas de los archivos de datos mediante `data_paths.h`, utilizando el directorio `~/.local/share/hermes/data` como ubicación predeterminada.

Para facilitar el desarrollo, se estableció un enlace simbólico entre el directorio de datos del usuario y la carpeta `hermes/src/hermes/data` del proyecto. De esta manera, los desarrolladores pueden visualizar y modificar los archivos JSON directamente desde el repositorio, mientras que Hermes utiliza la misma ubicación de almacenamiento al ejecutarse desde cualquier directorio.

## Configuración para desarrolladores

Los siguientes comandos permiten configurar el enlace simbólico en un entorno Linux o WSL. Cada desarrollador debe ejecutarlos desde su propio repositorio.

### 1. Entrar al directorio del proyecto

Desde la terminal, acceder al directorio que contiene el `Makefile` y la carpeta `data`:

```bash
cd ~/hermes/src/hermes
```

La ruta debe adaptarse a la ubicación real del repositorio de cada desarrollador.

### 2. Crear el directorio persistente

```bash
mkdir -p "$HOME/.local/share/hermes/data"
```

### 3. Copiar los datos existentes

Para conservar los archivos que ya se encuentran en el proyecto, ejecutar:

```bash
cp -an data/. "$HOME/.local/share/hermes/data/"
```

La opción `-n` evita sobrescribir archivos existentes en el destino.

### 4. Crear el enlace simbólico

Si `data` todavía es un directorio normal y no existe una copia de seguridad con el nombre `data.backup`, ejecutar:

```bash
mv data data.backup
ln -s "$HOME/.local/share/hermes/data" data
```

Si `data` ya es un enlace simbólico, no es necesario repetir este paso.

### 5. Verificar el enlace

```bash
ls -ld data
readlink -f data
ls -la data
```

La ruta resuelta debe apuntar al directorio:

```text
$HOME/.local/share/hermes/data
```

Dentro de `data` Hermes crea y mantiene `jobs.json`, `config.json`, `jobs.lock` y `scheduler.lock`. `jobs.json` guarda los Jobs; `config.json` contiene la configuración inicial `trabajos_maximos: 5` (actualmente no se lee para configurar el scheduler); `jobs.lock` coordina las escrituras concurrentes; y `scheduler.lock` evita iniciar más de un scheduler a la vez.

## Configuración del código fuente

Los módulos que utilizan los archivos JSON deben incluir `data_paths.h` y resolver las rutas mediante la función compartida.

En `job.cpp`:

```cpp
const string archivoJobs = hermes::rutaDatos("jobs.json");
const string archivoConfiguracion =
    hermes::rutaDatos("config.json");
```

En `filter.cpp` y `cancel.cpp`:

```cpp
const string archivoJobs = hermes::rutaDatos("jobs.json");
```

También se debe incluir el encabezado:

```cpp
#include "data_paths.h"
```

El Makefile debe conservar la opción `-Iinclude` para permitir que el compilador encuentre el encabezado.

## Instalación y verificación

Una vez configurados los archivos y modificados los módulos, recompilar e instalar Hermes:

```bash
make clean
make
make install
```

Para verificar que el ejecutable funciona fuera del directorio del proyecto:

```bash
cd /tmp

hermes --version
hermes job sleep 30
hermes filter status RUNNING
```

La cancelación debe probarse utilizando el identificador real de un trabajo que se encuentre ejecutándose:

```bash
hermes cancel ID
```

Sustituir `ID` por el identificador correspondiente.

Finalmente, revisar el archivo de persistencia:

```bash
cat "$HOME/.local/share/hermes/data/jobs.json"
```

Los cambios realizados por Hermes en `$HOME/.local/share/hermes/data/jobs.json` también son visibles en `hermes/src/hermes/data/jobs.json` a través del enlace simbólico.

## Verificación de la solución

| Prueba | Resultado esperado |
|---|---|
| Ejecutar `hermes job sleep 30` desde el directorio del proyecto | El trabajo se registra y comienza a ejecutarse |
| Ejecutar `hermes job sleep 30` desde otra ubicación | El trabajo se registra sin depender del directorio actual |
| Ejecutar `hermes filter` desde otra ubicación | Se consultan los mismos datos persistentes |
| Ejecutar `hermes cancel ID` desde otra ubicación | Se intenta cancelar el trabajo correspondiente |
| Revisar `$HOME/.local/share/hermes/data/jobs.json` o `hermes/src/hermes/data/jobs.json` | Se observan los mismos cambios gracias al enlace simbólico |
| Reiniciar la terminal o WSL | El enlace simbólico continúa disponible |

## Resultado esperado

Hermes puede ejecutarse desde cualquier directorio, siempre que esté correctamente instalado y que los módulos utilicen las rutas centralizadas. Los datos se conservan en `$HOME/.local/share/hermes/data`, mientras que los desarrolladores pueden visualizarlos directamente desde `hermes/src/hermes/data`, que es un enlace simbólico a la ruta persistente.

La configuración no requiere montar directorios mediante `sudo mount --bind`, ni modificar los permisos para permitir el acceso a otros usuarios. Cada desarrollador configura su propio directorio de datos y su enlace simbólico.

**Nota:** la ejecución satisfactoria de todas las pruebas debe confirmarse en el entorno de cada desarrollador antes de considerar la solución completamente verificada.