# Guía de Instalación y Ejecución del Proyecto Hermes (Entorno WSL / Linux)

Esta guía detalla los pasos desde cero para preparar tu entorno de desarrollo en Windows Subsystem for Linux (WSL) o cualquier distribución basada en Debian/Ubuntu, compilar el código fuente y ejecutar el proyecto Hermes.

## Paso 1: Preparación del entorno (Herramientas base)

El proyecto Hermes está desarrollado en C/C++ y utiliza `make` para automatizar su construcción. Los sistemas operativos Linux no incluyen los compiladores por defecto, por lo que el primer paso es instalar el "kit de construcción".

Abre tu terminal de WSL y ejecuta los siguientes comandos en orden:

### 1.1 Actualizar el catálogo de paquetes
```bash
sudo apt update
```

### 1.2 Instalar el compilador y herramientas esenciales
```bash
sudo apt install build-essential git
```
*(Nota: `build-essential` incluye `gcc`, `g++` y `make`. Añadimos `git` para poder descargar el repositorio).*

## Paso 2: Obtener el código fuente

### 2.1 Clonar el repositorio
```bash
git clone https://github.com/Conanlag/hermes
```

### 2.2 Entrar al directorio del proyecto
```bash
cd hermes
```

## Paso 3: Compilación del proyecto

### 3.1 Navegar al directorio del código principal
```bash
cd src/hermes/
```

### 3.2 Compilar el código
```bash
make
```
*(Nota: Este comando buscará el archivo `Makefile` en esa carpeta y automatizará el ensamblaje de los diferentes módulos, generando un archivo binario/ejecutable)*

## Paso 4: Instalación y Ejecución Global

Una vez compilado el código, el siguiente paso es "instalar" el programa para que puedas usar el comando `hermes` desde cualquier parte de la computadora, sin tener que estar dentro de la carpeta del código fuente.

### 4.1 Instalar el binario
Desde la misma carpeta `src/hermes/`, ejecuta:
```bash
make install
```
*(Nota:Al ejecutar este comando, el `Makefile` realiza dos acciones de forma automática: primero asegura que el directorio de destino exista usando `mkdir -p ~/.local/bin`, y luego copia el archivo ejecutable `hermes` recién compilado a esa ubicación)*

### 4.2 Configurar el PATH
Para que tu terminal reconozca el comando `hermes` globalmente, necesitamos decirle al sistema dónde buscarlo. 
Ejecuta estos dos comandos una sola vez:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```
*(Nota: El `PATH` es una variable de entorno que contiene la lista de directorios donde Linux busca los programas ejecutables. El primer comando registra de forma permanente la carpeta de nuestra instalación (`~/.local/bin`) en el archivo de configuración de tu terminal (`~/.bashrc`). El comando `source` simplemente recarga esa configuración para que el cambio aplique de inmediato, sin necesidad de reiniciar la consola)*

### 4.3 Ejecutar el proyecto
Listo. Ahora tu sistema reconoce la aplicación como un comando nativo. Para verificar que todo funciona correctamente, prueba pedirle la versión del programa:
```bash
hermes --version
```
