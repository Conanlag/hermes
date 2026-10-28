# Uso de inteligencia artificial

# 35. Documentación técnica del RNF-28: Persistencia atómica o recuperable

## Objetivo

Redactar la documentación técnica del **RNF-28** siguiendo la plantilla `.atl/crear_doc_RF.md`, describiendo el mecanismo de persistencia atómica y recuperable de `jobs.json`, el respaldo con `jobs.json.bak`, la restauración automática al arranque y la protección de la bitácora `events.jsonl` en modo append.

## Prompt 1

```text
ahora haz la documentacion del RNF-28 ".atl\crear_doc_RF.md"
```

## Resultado 1

La IA generó el documento `docs/technical-guide/2-Nucleo del proyecto/RNF-28-persistencia-atomica-recuperable.md` siguiendo estrictamente la plantilla:

**Estructura aplicada:**
- **Descripción:** Explicación de atomicidad y recuperabilidad ante interrupciones.
- **Objetivo:** Cita del requisito con lista "Lo que hace / Lo que NO hace".
- **Estructura del módulo:** Árbol con archivos involucrados (`storage.h/cpp`, `scheduler.cpp`, `event_log.h/cpp`, `data_paths.h`) y tabla de responsabilidades.
- **Implementación de `.h` y `.cpp`:** Desglose de `guardarAtomico()` (`tmp + fsync + rename + fsync(dir)`), `actualizarRespaldo()` con `link()`, `leerSinBloqueo()` como *fallback* perezoso y `verificarYRestaurarJobsAlArranque()` como validación proactiva al arranque.
- **Bitácora de eventos:** Confirmación del uso de `O_WRONLY | O_APPEND | O_CREAT` con `flock()` y `fsync()`.
- **Integración con otros módulos:** Relación con el arranque del scheduler, `recovery`, `job` y `event_log`.
- **Ejemplo de funcionamiento:** Escenario de interrupción durante la escritura y restauración automática desde `jobs.json.bak` con log `WARN` en `events.jsonl`.

## Modificaciones

**Estado de la resolución:** **[Aceptado tras verificación]**

**Revisión realizada:**
Se verificó consistencia entre la documentación y la implementación:
- Patrón atómico completo presente en `storage.cpp`.
- Respaldo con `hardlink()` (`link()`).
- Restauración proactiva al arranque añadida e integrada en `scheduler.cpp`.
- `events.jsonl` en modo append.
- No bloqueante ante corrupción irrecuperable.

**Cambios aplicados:**
1. Creación de `docs/technical-guide/2-Nucleo del proyecto/RNF-28-persistencia-atomica-recuperable.md`.
2. Documentación detallada del flujo completo sin inventar código no existente.

## Aprendizaje

1. **Atomicidad + recuperabilidad:** Ambos mecanismos son complementarios: prevenir (atomicidad) y restaurar (respaldo + auto-recuperación).
2. **Proactivo vs perezoso:** La validación al arranque evita inconsistencias antes de reconciliar trabajos.
3. **Hardlink eficiente:** `link()` crea el respaldo sin copiar bytes y preserva la última versión válida.
4. **Append-only para logs:** Mantener `events.jsonl` en modo adición garantiza trazabilidad ante fallos.
5. **Arranque robusto:** Nunca abortar por corrupción irrecuperable es clave para mantener el sistema usable.
