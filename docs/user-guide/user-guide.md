# GUÍA DE USUARIO: HERMES

## 1. Prerrequisitos

Antes de comenzar, asegúrate de contar con los siguientes requisitos:

* **Git**
* **Linux** o **WSL (Windows Subsystem for Linux)**
* **Ubuntu**, en caso de utilizar WSL
* **Make**
* **Visual Studio Code**, recomendado para trabajar con el código fuente

> **Nota:** Hermes está diseñado para ejecutarse en Linux. Si utilizas Windows, se recomienda utilizar Ubuntu mediante WSL.

### Verificar Ubuntu

Si utilizas WSL, puedes iniciar Ubuntu desde CMD o PowerShell:

```bash
ubuntu
```

Para comprobar la versión de Ubuntu:

```bash
lsb_release -a
```

### Verificar Git

Comprueba que Git esté instalado:

```bash
git --version
```

Si Git no está instalado:

```bash
sudo apt update
sudo apt install git
```

### Actualizar los paquetes de Ubuntu

Se recomienda actualizar la información de los paquetes antes de instalar las herramientas necesarias:

```bash
sudo apt update
```

### Instalar Make y herramientas de compilación

Instala `build-essential`, que incluye Make y otras herramientas necesarias para compilar el proyecto:

```bash
sudo apt install build-essential
```

Comprueba la instalación:

```bash
make --version
```

### Visual Studio Code

Si utilizas Visual Studio Code con WSL, puedes abrir el proyecto desde la carpeta correspondiente utilizando:

```bash
code .
```

---

## 2. Clonar el repositorio

Clona el repositorio de Hermes:

```bash
git clone https://github.com/Conanlag/hermes.git
```

Después, entra al directorio del proyecto:

```bash
cd hermes/src/hermes
```

Puedes verificar que te encuentras en la ubicación correcta con:

```bash
pwd
```

---

## 3. Compilación del proyecto

Una vez dentro del directorio `hermes`, utiliza el Makefile incluido en el proyecto.

### Compilar e instalar Hermes

Ejecuta:

```bash
make install
```

Este comando compila el proyecto y coloca el ejecutable en:

```text
~/.local/bin/hermes
```

La instalación se realiza dentro del directorio personal del usuario, por lo que **no es necesario utilizar `sudo`**.

### Limpiar la compilación

Para eliminar los archivos generados durante la compilación:

```bash
make clean
```

Después puedes volver a compilar utilizando:

```bash
make install
```

---

## 4. Configurar el PATH

Para poder ejecutar `hermes` desde cualquier directorio, es necesario que `~/.local/bin` se encuentre en el `PATH`.

Ejecuta:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Estos comandos realizan lo siguiente:

* `echo ... >> ~/.bashrc` agrega permanentemente `~/.local/bin` al `PATH`.
* `source ~/.bashrc` recarga la configuración actual de la terminal para aplicar el cambio inmediatamente.

> **Nota:** Esta configuración solo necesita realizarse una vez.

Puedes comprobar que Hermes está disponible con:

```bash
which hermes
```

Deberías obtener una ruta similar a:

```text
/home/usuario/.local/bin/hermes
```

---

# 5. Ejecutar Hermes

Una vez instalado y configurado el `PATH`, Hermes puede ejecutarse desde cualquier directorio.

Para comprobar que la instalación funciona correctamente:

```bash
hermes --version
```

Si la instalación fue correcta, se mostrará la versión actual de Hermes.

---

# 6. Comandos disponibles

Hermes cuenta actualmente con los siguientes comandos:

```text
hermes job
hermes filter
hermes cancel
hermes --version
```

---

## 6.1 Hermes Job

El comando `job` permite crear un nuevo Job y ejecutar un programa con sus argumentos.

### Sintaxis

```bash
hermes job <programa> [argumentos...]
```

### Ejemplo

Ejecutar `sleep` durante 30 segundos:

```bash
hermes job sleep 30
```

Otro ejemplo:

```bash
hermes job echo Hola
```

Al crear un Job, Hermes asigna un identificador y administra su estado durante el ciclo de ejecución.

Los estados utilizados por Hermes son:

```text
QUEUED
RUNNING
SUCCEEDED
FAILED
CANCELED
```

---

## 6.2 Hermes Filter

El comando `filter` permite buscar Jobs utilizando diferentes criterios:

* `id`
* `programa`
* `status`

### Sintaxis

```bash
hermes filter <id|programa|status> <valor>
```

### Buscar por ID

```bash
hermes filter id 30
```

### Buscar por programa

```bash
hermes filter programa sleep
```

### Buscar por estado

```bash
hermes filter status QUEUED
```

El filtro permite consultar los Jobs almacenados en Hermes que coincidan con el criterio indicado.

---

## 6.3 Hermes Cancel

El comando `cancel` permite solicitar la cancelación de un Job.

### Sintaxis

```bash
hermes cancel <id>
```

### Ejemplo

```bash
hermes cancel 30
```

El Job correspondiente será marcado como cancelado de acuerdo con su estado y ciclo de ejecución.

---

## 6.4 Hermes --version

Permite consultar la versión instalada de Hermes.

### Sintaxis

```bash
hermes --version
```

### Ejemplo

```bash
$ hermes --version
Hermes version ...
```

---

# 7. Flujo básico de uso

Una vez instalado Hermes, un flujo básico puede ser:

### 1. Crear un Job

```bash
hermes job sleep 30
```

### 2. Consultar el Job

```bash
hermes filter id 1
```

### 3. Consultar Jobs por estado

```bash
hermes filter status RUNNING
```

### 4. Cancelar un Job

```bash
hermes cancel 1
```

### 5. Consultar nuevamente su estado

```bash
hermes filter id 1
```

De esta manera se puede crear, consultar y cancelar un Job utilizando las funcionalidades disponibles actualmente en Hermes.
