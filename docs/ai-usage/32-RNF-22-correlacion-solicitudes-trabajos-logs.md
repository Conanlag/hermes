# Uso de inteligencia artificial

# 32. Implementación del RNF-22: Correlación entre solicitudes, trabajos y logs

## Objetivo

Implementar y verificar el cumplimiento estricto del RNF-22: "La bitácora deberá permitir correlacionar una solicitud con su trabajo" (Correlación entre solicitudes, trabajos y logs). Se añadió el soporte de `request_id` desde CLI hasta jobs.json y events.jsonl, manteniendo compatibilidad hacia atrás.

## Prompt 1

```text
Actúa como un arquitecto experto en C++17. Nuestro objetivo es auditar y garantizar el cumplimiento estricto del RNF-22 — Correlación entre solicitudes, trabajos y logs ("La bitácora deberá permitir correlacionar una solicitud con su trabajo") en el proyecto conanlag/hermes.
Fase 1: Auditoría de Trazabilidad
Fase 2: Plan de Acción
Entrégame tu diagnóstico inicial y tu propuesta de diseño paso a paso. No comiences a escribir código fuente ni a refactorizar hasta que yo apruebe el plan estratégico.
```

## Resultado 1

Se realizó auditoría completa: CLI sin `--request-id`, `Job` sin campo, sin persistencia ni inyección en logs. Se aprobó plan de refactorización mínimo y retrocompatible.

## Prompt 2

```text
muy bien, apruebo tu propuesta
```

## Resultado 2

Se implementó la propagación completa de `request_id`:

- **CLI (`src/hermes/src/main.cpp`)**: Parseo de `--request-id`, validación con `validarRequestId()` y paso a `crearJob()`.
- **Modelo (`src/hermes/include/job.h`, `src/hermes/src/job/job.cpp`)**: Añadido `std::string request_id` a `Job`, guardado al crear job, recuperado al reutilizar por duplicado, cargado en `obtenerJobPorId()`.
- **Persistencia (`src/hermes/src/job/job.cpp`)**: Al crear, se guarda `"request_id"` solo si no está vacío. Al leer, se carga si existe para mantener compatibilidad con trabajos antiguos.
- **Scheduler (`src/hermes/src/scheduler/scheduler.cpp`)**: Añadido `request_id` a `TrabajoPendiente`, extraído al reservar desde `jobs.json`, inyectado en contexto de `"Job recibido"`, `"Transición a RUNNING"`, `"Transición a SUCCEEDED"`, `"Transición a FAILED"`, `"Cancelación exitosa"` y `"Error interno del daemon"`.
- **Duplicados**: Mantiene correlación al reutilizar job existente por `request_id`.

## Verificación

```bash
./hermes job --request-id test-123 /bin/echo hola
grep -A 5 '"job_id": 62' ~/.local/share/hermes/data/jobs.json
grep test-123 ~/.local/share/hermes/data/events.jsonl
```

**Resultado:**
- `jobs.json`: `"request_id": "test-123"` presente en el job.
- `events.jsonl`: `"Job recibido"` con `"request_id": "test-123"` en su `context`.

## Estado

**[Aceptado tras verificación]** - RNF-22 completo. Trazabilidad end-to-end funcional entre solicitud, trabajo y logs.

## Aprendizaje

1. **Ubicación de datos**: Los archivos persisten en `~/.local/share/hermes/data/`, no junto al binario.
2. **Retrocompatibilidad**: Campo opcional permite trabajar con jobs.json antiguos sin romper nada.
3. **Inyección desde el punto que conoce el valor**: Extraer `request_id` desde jobs.json en el scheduler asegura correlación.
4. **Duplicados**: Al reutilizar por `request_id` se preserva la trazabilidad sin crear nuevos jobs.
