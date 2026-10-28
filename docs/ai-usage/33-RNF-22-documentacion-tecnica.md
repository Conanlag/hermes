# Uso de inteligencia artificial

# 33. Documentación técnica del RNF-22: Correlación entre solicitudes, trabajos y logs

## Objetivo

Redactar la documentación técnica del **RNF-22** siguiendo la plantilla `.atl/crear_doc_RF.md`, describiendo el flujo completo de correlación entre solicitudes, trabajos y logs en Hermes. Se documentó el soporte de `--request-id` desde CLI hasta `jobs.json` y `events.jsonl`, la propagación vía scheduler, la inyección en el `context` de eventos y la retrocompatibilidad con trabajos existentes.

## Prompt 1

```text
muy bien, ahora crea la documentacion completa de ese RNF-22 usando ".atl\crear_doc_RF.md"
```

## Resultado 1

La IA generó el documento `docs/technical-guide/2-Nucleo del proyecto/RNF-22-correlacion-solicitudes-trabajos-logs.md` siguiendo estrictamente la plantilla:

**Estructura aplicada:**
- **Descripción:** Explicación de la necesidad de trazabilidad end-to-end.
- **Objetivo:** Cita del requisito y lista "Lo que hace / Lo que NO hace".
- **Estructura del módulo:** Árbol con archivos involucrados (`main.cpp`, `job.h/cpp`, `scheduler.cpp`, `validator.cpp`, `event_log.*`) y tabla de responsabilidades.
- **Implementación:** Desglose de captura en CLI, modelo y persistencia, y propagación por el scheduler con enriquecimiento de eventos.
- **Integración con otros módulos:** Relación con `main`, `job`, `scheduler`, `storage`, `event_log` y `validator`.
- **Ejemplo de funcionamiento:** Comando con `--request-id test-123`, resultado en consola y estado resultante en `~/.local/share/hermes/data/jobs.json` y `events.jsonl`.

Se dejó explícito que el campo es opcional, retrocompatible y que los archivos persisten en el directorio de datos del usuario.

## Modificaciones

**Estado de la resolución:** **[Aceptado tras verificación]**

**Revisión realizada:**
Se verificó consistencia entre la documentación y los cambios implementados:
- Parseo de `--request-id` en CLI.
- Campo `request_id` en `Job` y persistencia opcional.
- Propagación por `TrabajoPendiente`.
- Inyección en eventos clave con `request_id` en `context`.
- Soporte para duplicados por `request_id`.
- Ubicación correcta en `~/.local/share/hermes/data/`.

**Cambios aplicados:**
1. Creación de `docs/technical-guide/2-Nucleo del proyecto/RNF-22-correlacion-solicitudes-trabajos-logs.md`.
2. Documentación clara del flujo end-to-end sin inventar código no existente.

**Prueba agregada:** Verificación cruzada con la prueba realizada en terminal (`jobs.json` y `events.jsonl`).

## Aprendizaje

1. **Trazabilidad end-to-end:** Es fundamental que el identificador viaje por todo el flujo (CLI → Job → Persistencia → Scheduler → Logs).
2. **Retrocompatibilidad primero:** Añadir campos opcionales permite cumplir el requisito sin romper el comportamiento existente.
3. **Contexto en eventos:** Inyectar `request_id` en el `context` de `EventLog` permite correlacionar sin acoplar el logger al modelo `Job`.
4. **Datos centralizados:** Documentar la ubicación en `~/.local/share/hermes/data/` evita confusiones al validar la trazabilidad.
5. **Plantillas fuerzan rigor:** Seguir `.atl/crear_doc_RF.md` obliga a delimitar alcance, explicar integración y mostrar ejemplos reales.
