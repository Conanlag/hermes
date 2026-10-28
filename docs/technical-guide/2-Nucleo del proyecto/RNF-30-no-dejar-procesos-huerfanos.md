# RNF-30 — No dejar procesos huérfanos

## Descripción

El requisito no funcional RNF-30 garantiza que Hermes no deje procesos huérfanos bajo su responsabilidad, tanto en un apagado controlado (SIGINT/SIGTERM) como tras una caída abrupta del daemon (SIGKILL o fallo inesperado). 

Para ello, el sistema gestiona los procesos mediante grupos de procesos (process groups), intercepta señales para un apagado ordenado, verifica la identidad de los procesos al arrancar y sanea automáticamente cualquier proceso huérfano heredado de una ejecución anterior.

## Objetivo

Garantizar que, después de un cierre o falla, el servicio no deberá dejar procesos huérfanos bajo su responsabilidad.

> *"Después de un cierre o falla, el servicio no deberá dejar procesos huérfanos bajo su responsabilidad."*

**Consideraciones actuales:**

- **Lo que hace:**
  - Interceptación de `SIGINT`/`SIGTERM` con `sigaction` y bandera segura para señales.
  - Apagado coordinado mediante `coordinarApagado()` que cierra la puerta a nuevos trabajos y termina todos los activos.
  - Creación de grupos de procesos propios para cada trabajo (`setpgid(0,0)` en hijo, `setpgid(pid,pid)` en padre).
  - Terminación del árbol completo con `kill(-pgid, SIGTERM)` / `kill(-pgid, SIGKILL)`.
  - Recuperación sincronizada al arranque bajo `scheduler.lock` para saneamiento tras caídas.
  - Verificación de identidad (`boot_id`, `pid_inicio`, `pgrp`, `sid`) para evitar matar PIDs reciclados.
  - Recolección de zombies con `waitpid` en trabajadores.
  - Marcado de trabajos huérfanos como `INTERRUPTED` con trazabilidad en `events.jsonl`.

- **Lo que NO hace:**
  - No señala grupos de procesos ajenos cuando no hay verificación concluyente.
  - No aborta el arranque por fallos en el saneamiento; los registra y continúa.
  - No depende únicamente del PID: utiliza grupos de procesos y verificación de identidad.
  - No deja ventanas sin supervisión: el coordinador es el único escritor del estado final durante el apagado.

## Estructura del módulo

```text
src/hermes/
├── include/
│   ├── process.h
│   ├── scheduler.h
│   └── recovery.h
└── src/
    ├── main.cpp
    ├── process/
    │   └── process.cpp
    ├── scheduler/
    │   └── scheduler.cpp
    └── recovery/
        └── recovery.cpp
```

| Archivo / directorio | Responsabilidad |
|---|---|
| `src/process/process.cpp` | Creación de procesos, formación de grupos (`setpgid`), lectura de identidad (`/proc`), terminación por grupo, espera y recolección. |
| `src/scheduler/scheduler.cpp` | Coordinador de apagado, instalación de handlers de señal, terminación ordenada por grupo, gestión de trabajadores. |
| `src/recovery/recovery.cpp` | Saneamiento al arranque: detección y terminación de trabajos `RUNNING` huérfanos tras caída abrupta. |
| `src/main.cpp` | Punto de entrada, inicio del scheduler y ciclo de vida. |

## Implementación

### 1) Creación de grupos de procesos

En `process.cpp` (`iniciarProceso()`):

```cpp
// Hijo
close(aux[0]);
close(pipefd[0]);
// Cierra descriptores heredados
for (int descriptor = 3; descriptor < 1024; ++descriptor) {
    (void)fcntl(descriptor, F_SETFD, FD_CLOEXEC);
}
// Grupo propio
setpgid(0, 0);
// Muerte si padre muere
prctl(PR_SET_PDEATHSIG, SIGKILL);
if (getppid() != padre) {
    _exit(127);
}
// Redirigir stdin/stdout/stderr
...
execvp(programa.c_str(), argv.data());
...

// Padre
close(aux[1]);
close(pipefd[1]);
// Evitar race condition
setpgid(pid, pid);
// Esperar resultado de exec
...
```

### 2) Terminación por grupo

```cpp
bool senalizarGrupoProceso(pid_t pgid, int senal) {
    if (pgid <= 0) {
        return false;
    }
    if (kill(-pgid, senal) == 0) {
        return true;
    }
    return errno == ESRCH;
}
```

`terminarActivos()` envía `SIGTERM` a todos los grupos, espera 5 segundos, envía `SIGKILL` a los que persistan y registra el resultado.

### 3) Apagado controlado

```cpp
void instalarHandlersDeApagado() {
    struct sigaction accion;
    std::memset(&accion, 0, sizeof(accion));
    accion.sa_handler = manejarSenalApagado;
    sigemptyset(&accion.sa_mask);
    accion.sa_flags = SA_RESTART;
    sigaction(SIGTERM, &accion, nullptr);
    sigaction(SIGINT, &accion, nullptr);
}

void coordinarApagado() {
    while (banderaApagado == 0) {
        sleep_for(milliseconds(50));
    }
    std::map<unsigned int, TrabajoActivo> pendientes;
    {
        std::lock_guard<std::mutex> bloqueoArranque(mutexArranque);
        apagadoSolicitado = true;
        std::lock_guard<std::mutex> bloqueoActivos(mutexActivos);
        for (auto& entrada : activos) {
            entrada.second.interrumpido = true;
            pendientes.emplace(entrada.first, entrada.second);
        }
    }
    terminarActivos(pendientes);
    {
        std::unique_lock<std::mutex> bloqueo(mutexActivos);
        cvActivos.wait_for(bloqueo, seconds(5), [] { return activos.empty(); });
    }
    persistirInterrumpidosPorApagado(pendientes);
}
```

### 4) Saneamiento al arranque tras caída abrupta

En `recuperarTrabajosInterrumpidos()`, para trabajos con `status == "RUNNING"`:
1. Leer `pid`, `boot_id`, `pid_inicio`, `sid` guardados.
2. Verificar si el proceso sigue vivo con `procesoVivo()`.
3. Si no pertenece a esta ejecución (`identidadCoincide()` falla) o no hay dueño válido, marcar como huérfano.
4. Si el grupo sigue vivo (`estadoGrupoProceso()`), terminarlo con `senalizarGrupoProceso()` (`SIGTERM` luego `SIGKILL`).
5. Marcar como `INTERRUPTED` con motivo (`caida`, `sin_pid`, `pid_reutilizado`, etc.) y persistir.
6. Registrar en `events.jsonl` con `log_event()` / `log_event_system()`.

## Integración con otros módulos

- **Scheduler**: Coordina apagado, mantiene mapa de activos y workers.
- **Process**: Abstracción POSIX para identidad, grupos, señales y espera.
- **Recovery**: Reconciliación tras caída.
- **Storage/EventLog**: Persistencia atómica de estados y trazabilidad.
- **Main**: Arranque del daemon y ciclo de vida.

## Ejemplo de funcionamiento

### Apagado controlado

```bash
# Enviar SIGINT (Ctrl+C) o SIGTERM
kill -TERM $(pidof hermes)
```

**Comportamiento:**
1. Handler marca `banderaApagado = 1`.
2. `coordinarApagado()` toma `mutexArranque`, marca `apagadoSolicitado`, recopila activos.
3. `terminarActivos()` envía `SIGTERM` a `-pgid`, espera 5s, luego `SIGKILL` si persisten.
4. Trabajadores recolectan con `waitpid`.
5. `persistirInterrumpidosPorApagado()` marca `INTERRUPTED` en `jobs.json`.

### Recuperación tras caída abrupta

```bash
# Simular caída
kill -KILL $(pgrep -f "hermes.*scheduler")
./hermes job /bin/sleep 60  # Al arrancar realiza saneamiento
```

**Comportamiento:**
1. `iniciarSchedulerSiNecesario()` adquiere `scheduler.lock` y ejecuta recuperación antes de fork.
2. `recuperarTrabajosInterrumpidos()` encuentra trabajos `RUNNING` con PID de ejecución anterior.
3. Verifica identidad: si no coincide con boot actual o pertenece a ejecución muerta, detecta huérfanos.
4. Termina grupo con `kill(-pgid, SIGTERM/SIGKILL)` si está vivo.
5. Marca como `INTERRUPTED` con motivo `caida` y registra en `events.jsonl`.

## Garantía

- **Sin procesos huérfanos:** Todo trabajo lanzado por Hermes queda en su propio grupo de procesos y es terminado con el árbol completo.
- **Sin zombies:** Los trabajadores recolectan con `waitpid`.
- **Seguro ante PIDs reciclados:** Verificación de identidad evita terminaciones erróneas.
- **Trazable:** Todas las terminaciones quedan registradas en `events.jsonl`.
- **Robusto:** Funciona tanto en apagado controlado como tras caídas abruptas.
