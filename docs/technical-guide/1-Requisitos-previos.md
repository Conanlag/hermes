
## Requisitos

Antes de comenzar, asegúrate de tener instalado:

* [Git](https://git-scm.com/)
* Linux o WSL (Windows Subsystem for Linux)
* Ubuntu, en caso de utilizar WSL

---

## 1.1 Clonar el repositorio

Clona el repositorio ejecutando:

```bash
git clone https://github.com/Conanlag/ppl.git
```

Entra a la carpeta del proyecto:

```bash
cd ppl
```

---

## 1.2  Crear una rama propia

Para trabajar sin modificar directamente la rama principal, crea una rama con tu nombre:

```bash
git branch <nombre-rama>
```

Por ejemplo:

```bash
git branch alberto
```

Después, cambia a tu nueva rama:

```bash
git checkout <nombre-rama>
```

También puedes crear y cambiar a la rama en un solo comando:

```bash
git checkout -b <nombre-rama>
```

---

## 1.3 Realizar cambios y hacer commit

Después de realizar tus cambios, agrega los archivos modificados:

```bash
git add .
```

Crea un commit con un mensaje descriptivo:

```bash
git commit -m "Descripción de los cambios"
```

Por ejemplo:

```bash
git commit -m "Agrega configuración inicial del proyecto"
```

---

## 4. Subir tu rama al repositorio

Para subir tu rama a GitHub:

```bash
git push origin <nombre-rama>
```

Por ejemplo:

```bash
git push origin alberto
```

---

## 5. Mantener tu rama actualizada con `main`

Antes de comenzar a trabajar, es importante asegurarse de tener los cambios más recientes de `main`.

Primero, cambia a la rama `main`:

```bash
git checkout main
```

Actualiza la rama:

```bash
git pull origin main
```

Después, regresa a tu rama:

```bash
git checkout <nombre-rama>
```

Y trae los cambios recientes de `main` a tu rama:

```bash
git merge main
```

Si existen conflictos, Git los indicará. Deberás resolverlos manualmente antes de continuar.

Una vez resueltos los conflictos:

```bash
git add .
git commit -m "Resuelve conflictos con main"
```

---

## 6. Pasar los cambios de tu rama a `main`

Una vez que tu trabajo esté terminado y listo para integrarse a `main`, cambia a la rama principal:

```bash
git checkout main
```

Antes de integrar tus cambios, asegúrate de tener la versión más reciente:

```bash
git pull origin main
```

Ahora integra tu rama:

```bash
git merge <nombre-rama>
```

Por ejemplo:

```bash
git merge alberto
```

Si no existen conflictos, puedes subir los cambios a GitHub:

```bash
git push origin main
```

> **Importante:** Antes de hacer un `merge` hacia `main`, asegúrate de que tus cambios estén terminados y que hayas revisado que no existan conflictos.

---

## 7. Instalar WSL y Ubuntu

Si utilizas Windows, puedes instalar WSL junto con Ubuntu desde la **Microsoft Store**.

1. Abre la Microsoft Store.
2. Busca **Ubuntu**.
3. Instala la versión disponible.
4. Abre Ubuntu desde el menú de inicio.
5. La primera vez que lo ejecutes, se te solicitará crear:

   * Un nombre de usuario.
   * Una contraseña.

Una vez configurado, podrás utilizar la terminal de Ubuntu para ejecutar los comandos del proyecto.

### Alternativa: instalar WSL desde PowerShell

También puedes instalar WSL directamente desde PowerShell ejecutándolo como administrador:

```powershell
wsl --install
```

Después de la instalación, reinicia tu computadora si Windows lo solicita.

---

## Flujo recomendado

Para trabajar normalmente en el proyecto, puedes seguir este flujo:

```bash
# Actualizar main
git checkout main
git pull origin main

# Regresar a tu rama
git checkout <nombre-rama>

# Obtener los últimos cambios de main
git merge main

# Trabajar en el proyecto...

# Guardar cambios
git add .
git commit -m "Descripción de los cambios"

# Subir tu rama
git push origin <nombre-rama>
```

Cuando tu trabajo esté listo para integrarse:

```bash
git checkout main
git pull origin main
git merge <nombre-rama>
git push origin main
```
