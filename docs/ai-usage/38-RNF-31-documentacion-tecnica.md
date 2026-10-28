# Uso de inteligencia artificial

# 38. Documentación técnica del RNF-31: Recuperación correcta de trabajos pendientes, terminados e interrumpidos

## Objetivo

Redactar la documentación técnica del **RNF-31** siguiendo la plantilla `.atl/crear_doc_RF.md`, describiendo cómo Hermes distingue correctamente trabajos pendientes (`QUEUED`), en ejecución (`RUNNING`), terminados (`SUCCEEDED`, `FAILED`, `CANCELED`) e interrumpidos (`INTERRUPTED`), garantizando que no se generen ejecuciones fantasma ni reportes de ejecución inexistente tras una caída o apagado inesperado del daemon.

---

## Prompt 1

```text
ok, haz la documentacion del RNF-31 con .atl\crear_doc_RF.md
```

---

## Resultado 1

La IA generó el documento `docs/technical-guide/2-Nucleo del proyecto/RNF-31-recuperacion-correcta-trabajos.md` con el siguiente contenido:

- **Descripción y objetivo:** Explicación del requisito y su garantía.
- **Estados:** Soporte de `INTERRUPTED` en `status.h/status.cpp`, conversión a/desde texto y comportamiento *fail-closed*.
- **Lógica de reconciliación:** `recuperarTrabajosInterrumpidos()` actúa únicamente sobre `RUNNING`, deja `QUEUED` intactos, respeta `SUCCEEDED/FAILED/CANCELED` sin re-ejecutarlos.
- **Clasificación de motivos:** `caida`, `sin_pid`, `sin_identidad`, `pid_reutilizado`, `estado_desconocido`.
- **Terminación de huérfanos:** Integración con RNF-30 para terminar grupos huérfones verificables.
- **Trazabilidad:** Eventos `"Trabajo interrumpido"` con `motivo`, `proceso_terminado`, `pid` y `request_id` (integrado con RNF-22).
- **Ejemplos:** Escenario tras caída, preservación de cola e historial.

---

# Modificaciones

**Estado de la resolución:** [Aceptado tras verificación]

**Revisión realizada:** Se revisó la documentación generada contra la plantilla `.atl/crear_doc_RF.md` y contra el código existente en `src/hermes/src/recovery/recovery.cpp`, `src/hermes/src/status/status.cpp` y `src/hermes/include/status.h`. Se verificó que la lógica descrita coincide fielmente con la implementación: solo se procesa `RUNNING`, se respeta el resto de estados, se marca `INTERRUPTED` con `codigo_salida = -1` y se integra con RNF-30/RNF-22.

**Prueba agregada:** Se verificó compilación con `make` en `src/hermes` tras los cambios de trazabilidad aplicados anteriormente, se revisaron los eventos en `~/.local/share/hermes/data/events.jsonl` y se confirmó la existencia del documento en la ruta indicada.

---

## Implementación de feature

Se documentó correctamente **RNF-31 — Recuperación correcta de trabajos pendientes, terminames e interrumpidos**, garantizando la distinción entre estados, ausencia de ejecuciones fantasma, protección ante PIDs reciclados, idempotencia, trazabilidad y integración con los RNF-30 y RNF-22.

---

## Modificación de archivo

**Archivo: `docs/technical-guide/2-Nucleo del proyecto/RNF-31-recuperacion-correcta-trabajos.md`**

Se creó la documentación técnica completa del RNF-31 siguiendo la plantilla propuesta, mostrando estructura, implementación, integración, ejemplos y garantía del requisito.

---

# Implementación final

Se generó y guardó exitosamente `docs/technical-guide/2-Nucleo del proyecto/RNF-31-recuperacion-correcta-trabajos.md`, junto con su registro correspondiente `docs/ai-usage/38-RNF-31-documentacion-tecnica.md`.

---

# Aprendizaje

1. **Trazabilidad:** Es fundamental documentar tanto la implementación, como RNF-30/RNF-31, como el proceso de documentación, manteniendo el registro `ai-usage` completo.
2. **Distinción de estados:** En sistemas con caída inesperada, `INTERRUPTED` debe distinguirse claramente de `FAILED`. La verificación de identidad (`boot_id`, `pid_inicio`) es clave para evitar matar PIDs reciclados.
3. **Fail-closed:** Es más seguro asumir `INTERRUPTED` ante estados desconocidos, que asumir un estado terminal erróneo.
4. **Integración entre requisitos:** RNF-31 se apoya fuertemente en RNF-30 (grupos de procesos) and RNF-22 (correlación con `request_id`), demostrando que los requisitos no funcionales no son aislados.
5. **Documentación fiel al código:** Crear documentación a partir del código existente requiere verificar exactamente qué hace la reconciliación, not assumptions.
