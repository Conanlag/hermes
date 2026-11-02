# Uso de inteligencia artificial

# 43. Comando hermes logs como watcher de eventos

## Objetivo

Agregar un comando de terminal para consultar los eventos escritos en `events.jsonl` por el módulo `event_log.cpp`, y ajustarlo para que funcione como watcher: mostrar únicamente los eventos que se generen después de iniciar el comando y permitir volver a la terminal con `Ctrl+C`. Mantener actualizados los validadores, el despacho de comandos y la documentación de RF-14.

---

## Prompt 1

> Puedes hacer un comando llamado hermes logs que muestre en terminal algo como | hermes | log y utilice los events.json.l y event_log.cpp recuerda actualizar validators main.cpp y el RF-14

## Resultado 1

Se revisaron la estructura del CLI, la lista blanca de comandos en `validator.cpp`, la entrada en `main.cpp`, la API y persistencia de `EventLog`, la ayuda y RF-14. Se implementó inicialmente una salida tabular que leía `events.jsonl`, se integró `logs` al validador y al despacho, y se agregó a la ayuda y a la documentación.

La primera validación confirmó la compilación y el manejo de bitácora vacía, eventos registrados, JSON inválido y argumentos adicionales. Después, se precisó el comportamiento esperado del comando.

---

## Prompt 2

> quiero que sea algo como logs de un backend algo como | hermes | (el log) y que sea un watcher es decir que no muestre el historial completo si no desde que lo mandaste a llamar y la otra es que con ctrl c puedas volver a poder usar la terminal

## Resultado 2

Se reemplazó la lectura histórica por `EventLog::watch_logs()`. Al arrancar, el watcher se posiciona al final de `events.jsonl`, espera y muestra las nuevas entradas completas con un prefijo de backend, por ejemplo:

```text
| hermes | (2026-11-02 14:00:00) [INFO] [job_id=7] Job recibido {"programa":"echo"}
```

El seguimiento no inicia el scheduler. La señal `SIGINT` de `Ctrl+C` detiene el bucle y deja la terminal en una línea nueva; los errores de lectura o JSON inválido se informan explícitamente.

---

# Modificaciones

## Implementación de feature

- `src/hermes/include/event_log.h`: se agregó la interfaz `watch_logs()`.
- `src/hermes/src/events/event_log.cpp`: se implementó el seguimiento de nuevas entradas JSONL, su presentación en formato de backend, el manejo de `Ctrl+C` y los errores de parseo/lectura.
- `src/hermes/src/main.cpp`: `hermes logs` valida que no reciba argumentos y ejecuta el watcher antes de inicializar el scheduler.
- `src/hermes/src/validator/validator.cpp`: `logs` se agregó a la lista de comandos permitidos y a los mensajes de comandos válidos.
- `src/hermes/src/help/help.cpp`: se agregó `logs` a la ayuda y a los ejemplos.

## Modificación de documentación

- `docs/technical-guide/2-Nucleo del proyecto/RF-14-Bitacora-de-eventos-y-errores.md`: se documentó el comportamiento de seguimiento, la salida, la ausencia de historial inicial y la salida con `Ctrl+C`.

---

# Implementación final

El comando `hermes logs` muestra únicamente eventos nuevos desde el momento de invocación. Conserva el formato JSONL existente, espera a que cada línea se complete antes de mostrarla y no requiere detener manualmente procesos ni recuperar la terminal después de `Ctrl+C`.

---

# Verificación

- `make -C src/hermes`: compilación correcta.
- Pruebas con un `HOME` temporal: no se imprimió el evento histórico; los eventos nuevos se mostraron al completarse su línea JSONL; el formato incluyó el prefijo `| hermes |`.
- `Ctrl+C`: el watcher terminó con código cero y dejó una línea nueva en la salida.
- JSON inválido agregado durante el seguimiento: se reportó el error y el comando terminó con código distinto de cero.
- `git diff --check`: sin errores de formato.

---

# Aprendizaje

Un comando de logs en vivo debe separar la lectura de la bitácora histórica del seguimiento: abrir al final evita reproducir eventos previos. Como JSONL puede escribirse por partes, el watcher debe conservar una línea incompleta y parsearla solo cuando llegue su terminador; además, `SIGINT` debe solicitar el cierre normal del bucle para que el proceso libere la terminal de forma limpia.
