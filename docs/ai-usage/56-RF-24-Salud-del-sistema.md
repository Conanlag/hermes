# Uso de inteligencia artificial

# 56. RF-24 — Salud del sistema

## Objetivo

Implementar RF-24: permitir al administrador consultar un resumen de salud con servicio activo, trabajos en ejecución, trabajos en cola y errores recientes. Evaluar si convenía extender `hermes logs` o agregar una consulta independiente basada en los módulos existentes. Después se amplió el alcance para incluir el estado de `hermes red start`, su interfaz y su puerto de escucha.

---

## Prompt 1

```text
Como implementarias el siguiente RF con todo el proyecto RF-24. El administrador deberá poder consultar un resumen de salud: servicio activo, trabajos en ejecución, en cola y errores recientes. tengo por el momento un hermes logs que puede servir pero quiero que me comentes si hacer otro o basandote en lo mismo haz la implementacion adecuada
```

---

## Resultado 1

Se revisaron el despacho del CLI, el validador, la ayuda, `EventLog`, las rutas configurables de datos, el almacenamiento seguro de trabajos y el ciclo de vida del scheduler.

Se agregó `hermes health [--json]`. La decisión fue mantener `hermes logs` como seguimiento de eventos nuevos y ofrecer el resumen mediante una consulta que termina después de mostrar los datos. Ambos comandos utilizan `events.jsonl`; no se creó otra bitácora.

El resumen inicial integró tres fuentes:

- **Scheduler:** consulta no bloqueante de `scheduler.lock`. La existencia del archivo o de un PID no se interpreta como servicio activo.
- **Trabajos:** una lectura mediante `leerJobsSeguros()` cuenta los estados `RUNNING` y `QUEUED`, incluidos los trabajos recibidos por red en el equipo.
- **Errores:** `EventLog::recent_errors()` obtiene los últimos 10 eventos `ERROR`, del más reciente al más antiguo según el orden de escritura. Se definió explícitamente que no existe una ventana temporal.

Las fuentes se consultan de manera independiente. Si alguna falla, su dato aparece como `NO DISPONIBLE` en texto o `null` en JSON y la consulta devuelve 1. Una consulta completa devuelve 0, aunque el scheduler esté inactivo o existan errores históricos. Los trabajos con estados inválidos no se convierten silenciosamente en conteos de cero.

Se agregaron advertencias para filas `RUNNING` con el scheduler inactivo y para líneas completas inválidas de la bitácora. La última línea sin terminador se considera todavía en escritura. Los mensajes históricos vuelven a pasar por la redacción de secretos y el escape de caracteres de control.

En esta etapa se compiló sin advertencias y se ejecutó TC-057 con datos temporales. La salida registrada en la conversación confirmó instalación vacía, detección por bloqueo, conteos, redacción, fuentes degradadas y un scheduler real con un trabajo ejecutándose y otro en cola.

---

## Prompt 2

```text
puedes hacer que tambien muestre si el servicio de hermes red start esta activo? osea el puerto y el puerto donde esta
```

---

## Resultado 2

Se amplió el resumen para mostrar por separado el scheduler y Hermes Red. Se interpretó la petición como estado del servidor TCP, dirección y puerto de escucha.

Se agregó `RegistroServidorRed`: después de `listen()`, el servidor registra su interfaz y puerto en `network-service.lock` y mantiene un bloqueo POSIX durante su ejecución. `consultarEstadoServidorRed()` comprueba el bloqueo antes de utilizar el registro. Un archivo antiguo o un puerto ocupado por otro programa no basta para declarar Hermes Red activo.

La primera implementación del registro utilizó `flock`. Durante la revisión se cambió a bloqueos POSIX con `fcntl`, porque pertenecen al proceso y no se heredan mediante `fork()`. Así, un proceso hijo que conserve un descriptor no mantiene el servidor marcado como activo tras la muerte de su propietario.

La salida distingue la escucha efectiva de la configuración para el siguiente inicio:

```text
Servicio (Hermes Red): ACTIVO
  Escuchando en: 127.0.0.1:45820 (TCP)
  Direccion configurada: 127.0.0.1:45820
```

En JSON se agregó `red`, con `activo`, `interfaz`, `puerto` y `configurado`. Si la red está inactiva, la interfaz y el puerto activos son `null`; la configuración sigue disponible. Esto evita presentar un puerto modificado en el archivo de configuración como si el servidor ya lo estuviera utilizando.

La verificación de TC-058 necesitó ejecutarse fuera del aislamiento porque este rechazó la creación de sockets locales. Los primeros intentos también permitieron corregir dos supuestos de la prueba:

1. Durante el registro inicial puede existir un bloqueo con metadatos todavía incompletos. La espera de arranque se ajustó para tolerar temporalmente `NO DISPONIBLE` y volver a consultar.
2. Se había supuesto que un `submit` remoto reiniciaba un scheduler detenido. La lectura de `remote.cpp` mostró que esa operación persiste el trabajo sin arrancarlo. Se corrigió la prueba para conservar el scheduler iniciado por `red start` y verificar que siguiera vivo después de terminar el servidor.

La ejecución final pasó: otro programa escuchando no se confundió con Hermes Red, la interfaz y el puerto fueron correctos, un cambio de configuración no alteró la dirección activa, se rechazó un segundo servidor para el mismo directorio de datos y el estado se liberó tanto con cierre normal como con `SIGKILL`.

---


# Modificaciones

**Estado de la resolución:** implementado con ajustes. El resumen inicial se amplió por solicitud del usuario para incluir Hermes Red. Se revisó el mecanismo de bloqueo del registro de red y se corrigieron los supuestos de la prueba antes de obtener una ejecución satisfactoria.

**Revisión realizada:** lectura del código existente, compilación con `-Wall -Wextra -std=c++17`, consultas con datos temporales, pruebas de ciclo de vida del servidor y comprobación de formato con `git diff --check`. En este último pedido solo se documentó la conversación; no se volvió a ejecutar la implementación.

---

## Implementación de feature

**Resumen local de salud.** `health.h` y `health.cpp` concentran la consulta y sus salidas de texto y JSON. El comando no inicia ni detiene servicios. Reutiliza el almacenamiento protegido por `jobs.lock` y consulta el bloqueo del scheduler sin basarse en el PID persistido. Los conteos describen estados almacenados; no verifican individualmente los procesos de cada trabajo.

**Errores recientes.** Se extendió `EventLog` con `recent_errors()`. Retiene como máximo los eventos solicitados, omite registros inválidos con advertencia y expone fecha, ID de trabajo y mensaje redactado. La lectura recorre la bitácora completa, aunque el número de eventos retenidos esté limitado.

---

## Implementación de feature

**Estado de Hermes Red.** `network_status.h` y `service_status.cpp` implementan el registro mediante RAII: la construcción toma el bloqueo y publica los metadatos; la destrucción cierra el descriptor. El sistema operativo libera el bloqueo si el proceso termina de forma inesperada.

`server.cpp` conserva el registro mientras mantiene el servicio. `health.cpp` consulta el estado y presenta la dirección activa y la configurada. Se admite un servidor por directorio de datos. Los servidores iniciados con un binario anterior deben reiniciarse para que registren su estado.

---

## Modificación de archivo

| Archivo | Cambio |
|---|---|
| `src/hermes/include/health.h` | Interfaz de `mostrarSalud()` |
| `src/hermes/src/health/health.cpp` | Resumen de scheduler, red, trabajos y errores; salida de texto y JSON |
| `src/hermes/include/event_log.h` | Declaración de `recent_errors()` |
| `src/hermes/src/events/event_log.cpp` | Consulta histórica de errores reutilizando redacción y presentación segura |
| `src/hermes/include/network_status.h` | Interfaz del registro y de la consulta del servidor |
| `src/hermes/src/network/service_status.cpp` | Bloqueo POSIX, metadatos de escucha y consulta del estado |
| `src/hermes/src/network/server.cpp` | Registro de la escucha después de `listen()` |
| `src/hermes/src/main.cpp` | Despacho de `health` y validación de `--json` |
| `src/hermes/src/validator/validator.cpp` | Inclusión de `health` en los comandos permitidos y mensajes de ayuda |
| `src/hermes/src/help/help.cpp` | Descripción y ejemplos del comando |

---

## Modificación de archivo

- `docs/user-guide/user-guide.md`: uso de `hermes health`, interpretación de los estados y distinción entre dirección activa y configurada.
- `docs/technical-guide/2-Nucleo del proyecto/RF-24.resumen-salud.md`: diseño, fuentes de datos, errores, consistencia, alcance administrativo local y estado de red.
- `docs/ai-usage/56-RF-24-Salud-del-sistema.md`: registro de esta conversación siguiendo el template.

Durante la sesión también se crearon pruebas y resultados de TC-057 y TC-058, y se trabajó en la trazabilidad de RF-24. Su ausencia posterior y el estado actual de la matriz se explican en Resultado 3 para no confundir el historial de trabajo con los archivos disponibles.

---

# Implementación final

```bash
hermes health
hermes health --json
```

El comando reúne el estado del scheduler, el estado de Hermes Red con interfaz y puerto, los trabajos en ejecución y en cola y los últimos 10 errores. `hermes logs` mantiene su seguimiento de eventos nuevos.

Comandos de verificación ejecutados durante la conversación:

```text
make -C src/hermes hermes       -> compilación sin advertencias
python3 verif/scripts/TC-057.py -> PASS RF-24 / TC-057
python3 verif/scripts/TC-058.py -> PASS RF-24 / TC-058
git diff --check               -> sin errores de formato
```

Estas ejecuciones no representan una regresión completa del proyecto. Los scripts de prueba citados no estaban presentes al redactar este archivo.

El resumen es una observación de fuentes independientes, no una transacción global. La consulta de red acredita el registro del proceso servidor local; no comprueba accesibilidad desde otro equipo, firewall, proxy WSL ni rutas. El comando utiliza los permisos del usuario propietario de Hermes, sin agregar roles locales ni una nueva operación al protocolo remoto.

---

# Aprendizaje

**La bitácora y el estado actual responden preguntas distintas.** Un evento de arranque no demuestra que el servicio continúe vivo. Reutilizar `EventLog` para los errores y consultar bloqueos para los servicios permite aprovechar el proyecto sin deducir disponibilidad a partir del historial.

**La vida del bloqueo debe coincidir con la del servicio.** La diferencia entre `flock` y los bloqueos POSIX importa cuando existen procesos hijos. Elegir un bloqueo perteneciente al proceso evita que un descriptor heredado prolongue artificialmente el estado activo.

**La configuración no equivale a la escucha efectiva.** Mostrar ambos valores permite reconocer cambios pendientes de reinicio. Del mismo modo, un puerto ocupado no demuestra que quien escucha sea Hermes.

**Un dato desconocido no debe convertirse en cero.** Los valores `null`, las advertencias y los códigos de salida distinguen una consulta incompleta de un sistema sin trabajos o sin errores.

**Las pruebas también contienen supuestos que deben revisarse.** Los intentos fallidos de TC-058 detectaron una ventana de arranque y una suposición incorrecta sobre `submit`. La corrección se basó en el ciclo de vida real del servidor y del scheduler.

**La evidencia de una sesión debe distinguirse de la conservada en Git.** Registrar que una prueba pasó en la conversación no autoriza a afirmar que sus archivos siguen presentes o que la matriz actual está cerrada. Mantener esa distinción hace el registro de uso de IA verificable.
