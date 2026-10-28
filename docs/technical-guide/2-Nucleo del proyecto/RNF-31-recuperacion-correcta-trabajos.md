# RNF-31 — Recuperación correcta de trabajos pendientes, terminados e interrumpidos

## Descripción

El requisito no funcional RNF-31 garantiza que, al arrancar el daemon tras una caída o apagado inesperado, Hermes reconcilie correctamente el estado de los trabajos almacenados en `jobs.json`. 

La recuperación debe distinguir entre trabajos pendientes (`QUEUED`), en ejecución (`RUNNING`), terminados (`SUCCEEDED`, `FAILED`, `CANCELED`) e interrumpidos (`INTERRUPTED`), sin generar ejecuciones fantasma, sin falsos tiempos de terminación y sin re-ejecutar trabajos ya finalizados.

## Objetivo

Garantizar que la recuperación distinga trabajos pendientes, terminados e interrumpidos sin reportar ejecución inexistente.

> *"La recuperación deberá distinguir trabajos pendientes, terminados e interrumpidos sin reportar ejecución inexistente."*

**Consideraciones actuales:**

- **Lo que hace:**
  - Al arranque, `recuperarTrabajosInterrumpidos()` analiza únicamente los trabajos con `status == "RUNNING"`. El resto se dejan intactos.
  - Los trabajos `RUNNING` huérfanos se transicionan a `INTERRUPTED` con `codigo_salida = -1`, `mensaje_error`, `motivo`, `proceso_terminado` y `recuperado_en`.
  - Los trabajos `QUEUED` se mantienen intactos y quedan listos para ser procesados por el scheduler.
  - Los trabajos `SUCCEEDED`, `FAILED` y `CANCELED` se respetan sin modificar sus tiempos, resultados o estado.
  - Se verifica la identidad del proceso (`boot_id`, `pid_inicio`, `pgrp`, `sid`) para evitar matar PIDs reciclados.
  - Si el grupo sigue vivo sin dueño, se termina por grupo (integrado con RNF-30).
  - Se emiten eventos `"Trabajo interrumpido"` en `events.jsonl` con trazabilidad, incluyendo `request_id` cuando existe (integrado con RNF-22).
  - Si un grupo huérfano no es verificable, se marca como `INTERRUPTED` y se registra `"Huérfano no terminado"` a nivel `ERROR`.
  - El estado `INTERRUPTED` existe en `Status` con conversión completa y comportamiento *fail-closed*.

- **Lo que NO hace:**
  - No re-ejecuta trabajos ya terminados.
  - No asigna `tiempo_terminacion`, `codigo_salida` ni `mensaje_error` a trabajos `QUEUED`, `SUCCEEDED`, `FAILED` o `CANCELED`.
  - No genera ejecuciones fantasma ni reportes de finalización exitosa para trabajos interrumpidos.
  - No señala grupos de procesos ajenos cuando la verificación de identidad/grupo no es concluyente.
  - No corrompe el historial al ejecutar la recuperación múltiples veces (idempotente).

## Estructura del módulo

```text
src/hermes/
├── include/
│   ├── status.h
│   ├── recovery.h
│   └── storage.h
└── src/
    ├── status/
    │   └── status.cpp
    ├── recovery/
    │   └── recovery.cpp
    └── scheduler/
        └── scheduler.cpp
```

| Archivo / directorio | Responsabilidad |
|---|---|
| `include/status.h` / `src/status/status.cpp` | Definición del enumerador `Status` con `INTERRUPTED`, conversión a/desde texto y validación. |
| `include/recovery.h` / `src/recovery/recovery.cpp` | Lógica de reconciliación al arranque, clasificación de trabajos, terminación de huérfanos y registro de auditoría. |
| `include/storage.h` / `src/storage/storage.cpp` | Lectura/escritura atómica con bloqueo para aplicar la reconciliación. |
| `src/scheduler/scheduler.cpp` | Arranque del daemon y coordinación del proceso de recuperación bajo `scheduler.lock`. |

## Implementación

### 1) Estados soportados

```cpp
enum class Status {
      QUEUED,
      RUNNING,
      SUCCEEDED,
      FAILED,
      CANCELED,
      INTERRUPTED // Terminal: Hermes dejó de supervisar el Job; su resultado real es desconocido.
};
```

```cpp
string statusToString(Status status) {
    switch (status) {
        case Status::QUEUED:     return "QUEUED";
        case Status::RUNNING:    return "RUNNING";
        case Status::SUCCEEDED:  return "SUCCEEDED";
        case Status::FAILED:     return "FAILED";
        case Status::CANCELED:   return "CANCELED";
        case Status::INTERRUPTED: return "INTERRUPTED";
    }
    return "INTERRUPTED";
}

Status statusDesdeTexto(const string& texto) {
    if (texto == "QUEUED")     return Status::QUEUED;
    if (texto == "RUNNING")    return Status::RUNNING;
    if (texto == "SUCCEEDED")  return Status::SUCCEEDED;
    if (texto == "FAILED")     return Status::FAILED;
    if (texto == "CANCELED")   return Status::CANCELED;
    if (texto == "INTERRUPTED") return Status::INTERRUPTED;
    // Fail-closed
    return Status::INTERRUPTED;
}

bool statusEsTextoConocido(const string& texto) {
    return texto == "QUEUED" ||
           texto == "RUNNING" ||
           texto == "SUCCEEDED" ||
           texto == "FAILED" ||
           texto == "CANCELED" ||
           texto == "INTERRUPTED";
}
```

### 2) Lógica de reconciliación

En `recuperarTrabajosInterrumpidos()`, el flujo es:

1. **Carga bajo lock:** Se ejecuta dentro de `modificarJobsSeguros()` para garantizar atomicidad.
2. **Filtrado:** Solo se procesan filas con `status == "RUNNING"` y texto conocido. `QUEUED`, `SUCCEEDED`, `FAILED`, `CANCELED` se ignoran.
3. **Clasificación:** Para cada `RUNNING` se valida `pid`, `boot_id`, `pid_inicio`, `pgrp`, `sid`. Se comprueba `procesoVivo()`, `identidadCoincide()`, `estadoGrupoProceso()`.
4. **Terminación de huérfanos:** Si el grupo sigue vivo sin pertenecer a esta ejecución, se envía `SIGTERM`/`SIGKILL` al grupo antes de persistir.
5. **Transición:** Mediante `aplicarClasificacion()` se marca como `INTERRUPTED`, se fija `codigo_salida = -1`, `tiempo_terminacion = ahora`, `mensaje_error` con `mensajeInterrupcion()`, `motivo`, `proceso_terminado`, `recuperado_en`.
6. **Trazabilidad:** Se registra `"Trabajo interrumpido"` en `events.jsonl` con `motivo`, `proceso_terminado`, `pid` y `request_id` si existe. Si queda un grupo huérfano no verificable, se registra `"Huérfano no terminado"` a nivel `ERROR`.

### 3) Clasificación de motivos

| Motivo | Significado | Comportamiento |
|---|---|---|
| `caida` | Proceso/grupo sin dueño tras caída del daemon | Si el grupo sigue vivo y verificable → terminar por grupo. Marcar `INTERRUPTED`. |
| `sin_pid` | Fila `RUNNING` sin PID válido | Marcar `INTERRUPTED` sin señalar. |
| `sin_identidad` | Falta `boot_id`/`pid_inicio` | Marcar `INTERRUPTED` sin señalar. |
| `pid_reutilizado` | El PID fue reciclado por otro proceso | Marcar `INTERRUPTED` con `proceso_terminado = true`, **sin enviar señal**. |
| `estado_desconocido` | Estado no reconocido | Tratado como `INTERRUPTED` (fail-closed). |

## Integración con otros módulos

- **Scheduler**: Ejecución de recuperación bajo `scheduler.lock` antes de iniciar workers.
- **Recovery**: Núcleo de reconciliación y saneamiento.
- **Process**: Verificación de identidad, estado de grupo y terminación por árbol.
- **Storage**: Escritura atómica con bloqueo.
- **EventLog**: Trazabilidad de auditoría.
- **RNF-22**: Inclusión de `request_id` en logs de recuperación.
- **RNF-30**: Terminación segura de grupos huérfanos.

## Ejemplo de funcionamiento

### Escenario 1: Daemon cae con trabajos en ejecución

```bash
./hermes job /bin/sleep 300
# Simular caída
kill -KILL <pid_daemon>
# Reiniciar
./hermes job /bin/echo test
```

**Resultado:**
- El trabajo `RUNNING` pasa a `INTERRUPTED`.
- Se registra en `events.jsonl`: `{"message":"Trabajo interrumpido","context":{"motivo":"caida","proceso_terminado":true,...}}`
- No hay reporte de ejecución válida, `codigo_salida = -1`.

### Escenario 2: Trabajos en cola y terminados

Tras reinicio:
- Trabajos `QUEUED`: permanecen en cola, se ejecutan normalmente.
- Trabajos `SUCCEEDED`/`FAILED`/`CANCELED`: sin cambios, sin re-ejecución.
- Historial completamente preservado.

### Estado en `jobs.json`

```json
{
  "job_id": 10,
  "status": "INTERRUPTED",
  "codigo_salida": -1,
  "mensaje_error": "Trabajo interrumpido por reinicio o caída del scheduler: el servicio dejó de supervisar el Job. No se reejecutó automáticamente.",
  "motivo": "caida",
  "proceso_terminado": true,
  "recuperado_en": "2026-10-27 21:XX:XX",
  "request_id": "test-rnf31"
}
```

**Garantía:** La recuperación distingue correctamente pendientes, terminados e interrumpidos, sin reportar ejecuciones inexistentes. `RUNNING` → `INTERRUPTED`, `QUEUED` intactos, terminales respetados.
