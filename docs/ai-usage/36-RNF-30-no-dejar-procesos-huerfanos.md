# Uso de inteligencia artificial

# 36. Implementación del RNF-30: No dejar procesos huérfanos

## Objetivo

Auditar y garantizar el cumplimiento estricto del RNF-30: *"Después de un cierre o falla, el servicio no deberá dejar procesos huérfanos bajo su responsabilidad"* en el proyecto conanlag/hermes.

Se verificó que el sistema ya implementaba el apagado controlado, la recuperación tras caída abrupta y la gestión por grupos de procesos. Se confirmó su correcto funcionamiento, trazabilidad en logs y recolección de zombies.

## Prompt 1

```text
Actúa como un arquitecto experto en C++17 y sistemas POSIX. Nuestro objetivo es auditar y garantizar el cumplimiento estricto del RNF-30 — No dejar procesos huérfanos ("Después de un cierre o falla, el servicio no deberá dejar procesos huérfanos bajo su responsabilidad") en el proyecto conanlag/hermes.

Fase 1: Auditoría de Gestión de Procesos
...
Fase 2: Plan de Acción
...
Entrégame tu diagnóstico inicial y tu propuesta de diseño paso a paso. No comiences a escribir código fuente ni a refactorizar hasta que yo apruebe el plan estratégico.
```

## Resultado 1

Se realizó auditoría completa:

- **Apagado controlado:** `instalarHandlersDeApagado()` con `sigaction`/`SA_RESTART`, `coordinarApagado()` y `terminarActivos()` con terminación por grupo y ventana de gracia.
- **Recuperación tras caída abrupta:** `iniciarSchedulerSiNecesario()` ejecuta recuperación bajo `scheduler.lock`. `recuperarTrabajosInterrumpidos()` sanea trabajos `RUNNING` huérfanos verificando identidad.
- **Árboles de procesos:** `iniciarProceso()` crea grupo propio con `setpgid(0,0)` en hijo y `setpgid(pid,pid)` en padre. `senalizarGrupoProceso()` usa `kill(-pgid, ...)`. `guardarPid()` aborta grupos si no puede registrar el PID.

Tras revisión, el plan propuesto era mayoritariamente cubrir huecos menores, pero al inspeccionar el código se determinó que **ya estaba completamente implementado**.

## Prompt 2

```text
apruebo el plan, prosigue
```

## Resultado 2

Se realizó verificación exhaustiva sin necesidad de refactorización masiva:

- **Manejo de señales:** Señales `SIGINT`/`SIGTERM` interceptadas correctamente, sin operaciones no async-signal-safe.
- **Terminación por grupo:** Uso consistente de `kill(-pgid, SIGTERM)`/`SIGKILL` cuando el grupo es verificable.
- **Saneamiento al arranque:** Identidad verificada con `boot_id`, `pid_inicio`, `pgrp`, `sid`. Grupos vivos sin dueño son terminados y marcados como `INTERRUPTED`.
- **Prevención de huérfanos:** `prctl(PR_SET_PDEATHSIG, SIGKILL)`, cierre de descriptores heredados, `waitpid` para recolectar zombies.
- **Protección:** No se señalan grupos ajenos cuando la verificación no es concluyente.

**Compilación:** `make` exitoso sin errores.

## Estado

**[Aceptado tras verificación]** - RNF-30 completo al 100%. No deja procesos huérfanos bajo responsabilidad de Hermes en apagado controlado ni tras caídas abruptas.

## Aprendizaje

1. **Grupos de procesos son clave:** `setpgid` + `kill(-pgid, ...)` permite terminar todo el árbol (hijo + nietos).
2. **Identidad de proceso:** Verificar `boot_id`/`pid_inicio` evita matar PIDs reciclados por el sistema.
3. **Apagado coordinado:** Ventana de gracia compartida es eficiente y evita esperas excesivas.
4. **Recuperación proactiva:** Saneamiento al arranque bajo lock garantiza consistencia tras `SIGKILL`.
5. **Defensa en profundidad:** Múltiples capas (señales, grupos, identidad, `waitpid`) aseguran que no queden huérfanos o zombies.
