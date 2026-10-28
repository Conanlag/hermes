# Uso de inteligencia artificial

# 39. Configuración de concurrencia, cierre del scheduler y validación de `clean`

## Objetivo

Diagnosticar por qué Hermes mantenía cinco trabajos simultáneos aunque se modificaran `config.json` y `config.h`, explicar cómo se aplica la configuración a un daemon ya iniciado y simplificar su reinicio con `hermes clean scheduler`. Se verificó el cierre ordenado, la conservación de Jobs en cola y la validación del subcomando `clean`.

---

## Prompt 1

```text
en que parte del codigo realmente decide cuantos trabajos maximos pueden hacerse concurrentemente, por que tanto como /home/leo/tareas/proyecto/hermes/src/hermes/data/config.json y /home/leo/tareas/proyecto/hermes/src/hermes/include/config.h cuando les cambio no sigue siendo 5
```

## Resultado 1

Se siguió el flujo completo de configuración:

- `config.cpp` lee `trabajos_maximos` desde `$HOME/.local/share/hermes/data/config.json`.
- `main.cpp` pasa el valor cargado a `iniciarSchedulerSiNecesario()`.
- `ejecutarScheduler()` crea un hilo trabajador por cada valor recibido.
- `config.h` y los argumentos predeterminados del scheduler proporcionan `5` cuando no se usa un valor de configuración válido; cambiar el encabezado requiere recompilar.
- El scheduler que ya posee `scheduler.lock` no vuelve a leer la configuración ni cambia su número de trabajadores en caliente.

Se comprobó además que `src/hermes/data` apunta al directorio persistente del usuario.

---

## Prompt 2

```text
sigue pasando y cambie config.json y config.h a 1
```

## Resultado 2

La configuración persistente ya tenía `trabajos_maximos: 1` y el binario se había recompilado, pero un proceso Hermes iniciado antes seguía activo y mantenía `scheduler.lock`. Por tanto, cambiar el JSON y recompilar no alteraba los hilos del daemon ya iniciado.

---

## Prompt 3

```text
y como paso eso?
```

## Resultado 3

Se explicó cómo localizar el proceso que mantiene `scheduler.lock`, enviarle `SIGTERM` y esperar a que el lock se libere. Se aclaró que cerrar la terminal no detiene necesariamente el daemon y que no se debe borrar el archivo de bloqueo.

---

## Prompt 4

```text
y es normal o deberia cambiar
```

## Resultado 4

Se aclaró que la configuración solo se lee al iniciar el scheduler y que el comportamiento del daemon existente era el esperado por la implementación, aunque se podía mejorar la experiencia mediante recarga o reinicio controlado.

---

## Prompt 5

```text
entonces como seria el flujo tendria que borrar la terminal o que deberia hacer para que ese daemon libere
```

## Resultado 5

Se explicó que no es necesario cerrar la terminal: el scheduler es un proceso independiente. La opción manual era comprobar que no hubiera Jobs activos, enviar `SIGTERM` al proceso que conserva `scheduler.lock` y esperar a que el lock se liberara, sin borrar el archivo.

---

## Prompt 6

```text
sin mover nada del codigo como harias que fuera mas sencillo, sin estropear toda la implementacion actual
```

## Resultado 6

Se propuso un comando de reinicio reutilizable que verificara y solicitara el cierre ordenado, esperara la liberación del lock y dejara el scheduler listo para iniciarse con la nueva configuración.

---

## Prompt 7

```text
ok puedes implementarlo como hermes clean scheduler
```

## Resultado 7

Se añadió `hermes clean scheduler` como una petición de apagado ordenado:

- Registra el PID del daemon en `scheduler.lock` y usa el lock para esperar a que termine.
- Para daemons anteriores que no guardaron el PID, localiza el proceso que mantiene abierto ese archivo.
- Envía `SIGTERM` y espera hasta 30 segundos a que el daemon libere el lock; no borra el archivo.
- El cierre existente termina los Jobs activos y los registra como `INTERRUPTED`; conserva los Jobs `QUEUED`.
- El siguiente comando que necesite el scheduler lo vuelve a iniciar y carga la configuración vigente.

El comando se agregó al despacho de `main.cpp`, a `--help` y a la guía de usuario.

---

## Prompt 8

```text
tambien en los validadores pon Uso: hermes clean data | scheduler para poder ejecutarlo
```

## Resultado 8

Se agregó `validarObjetivoClean()` para aceptar `data` y `scheduler`. Cuando el objetivo falta o es inválido, el CLI muestra exactamente:

```text
Uso: hermes clean data | scheduler
```

---

# Modificaciones

**Estado de la resolución:** Implementado y verificado.

**Cambios de código registrados en esta conversación:**

1. Se añadió el apagado ordenado mediante `hermes clean scheduler`, con espera de liberación de `scheduler.lock` y compatibilidad con daemons que no guardaban su PID.
2. Se agregó la validación específica del objetivo de `clean` para `data` y `scheduler`, y se actualizó el texto de uso.
3. Se documentó el nuevo comando en ayuda y guía de usuario.

**Validación realizada:**

- `make -C src/hermes` compiló el comando y la validación.
- Pruebas aisladas con un `HOME` temporal confirmaron el cierre de un proceso que mantenía el lock sin PID (simulación de un daemon legado), el estado `INTERRUPTED` para el Job activo, la conservación de un Job `QUEUED` y el procesamiento de Jobs después de reiniciar el scheduler.
- Se verificó que los objetivos faltantes e inválidos de `clean` imprimen el uso solicitado, y que `clean scheduler` es aceptado.

## Implementación de feature

### Reinicio controlado para aplicar configuración

`hermes clean scheduler` permite que un cambio en `trabajos_maximos` se aplique sin buscar y señalar manualmente el PID del daemon. El comando usa el cierre ordenado existente; no introduce un segundo mecanismo de terminación ni elimina archivos de estado.

### Validación del subcomando

El dispatcher y el validador comparten el contrato `clean data | scheduler`; las entradas no admitidas se rechazan antes de iniciar el scheduler o modificar los Jobs, y el validador registra el rechazo en la bitácora.

## Modificación de archivo

- `src/hermes/src/scheduler/scheduler.cpp`: registro/identificación del daemon y apagado ordenado.
- `src/hermes/include/scheduler.h`: declaración de la operación de apagado.
- `src/hermes/src/main.cpp`: despacho de `clean data` y `clean scheduler`.
- `src/hermes/include/validator.h` y `src/hermes/src/validator/validator.cpp`: validación del objetivo.
- `src/hermes/src/help/help.cpp` y `docs/user-guide/user-guide.md`: ayuda y documentación del comando.

---

# Implementación final

La configuración dinámica continúa aplicándose al iniciar el scheduler. Para aplicar cambios sin editar archivos de bloqueo ni buscar procesos manualmente, se puede ejecutar `hermes clean scheduler`; el siguiente comando que requiera el scheduler iniciará uno nuevo con la configuración vigente.

# Aprendizaje

1. Un archivo de configuración actualizado no cambia el estado de un daemon que ya está ejecutándose; la documentación y el CLI deben dejar claro cuándo se carga la configuración.
2. Un comando de reinicio debe delegar en el apagado ordenado ya existente para preservar la propiedad del lock y los estados de Jobs.
3. Los Jobs activos y los pendientes requieren tratamientos distintos: el cierre registra como `INTERRUPTED` los activos y conserva los `QUEUED`.