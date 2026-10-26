# Uso de inteligencia artificial

# 22. RF-14 Documentación del Requisito Funcional

## Objetivo

Documentar el Requisito Funcional RF-14 "Bitácora de eventos y errores", generando el archivo `docs/technical-guide/RF-14-Bitacora-de-eventos-y-errores.md` con base en la skill `.atl/crear_doc_RF.md`. 

El objetivo fue plasmar de forma técnica y veraz todo lo relacionado con la implementación del módulo `event_log`, incluyendo su diseño, integración, serialización entre procesos, política de logging, ejemplos de funcionamiento y alcance del mismo.

---

## Prompt 1

```text
ahora tomando en cuenta todo lo de este RF/Feature, redacta el documento del RF en base a la skill .atl\crear_doc_RF.md guarda el archivo tu

# Resultado 1
Se leyó el archivo .atl/crear_doc_RF.md para seguir al pie de la letra su plantilla. Tomando en cuenta la implementación ya realizada para el RF-14, así como los archivos creados y modificados (event_log.h/.cpp, data_paths.h, scheduler.cpp, main.cpp, cancel.cpp, validator.cpp), se generó el documento técnico docs/technical-guide/RF-14-Bitacora-de-eventos-y-errores.md.
El documento fue redactado con las secciones aplicables: Descripción, Objetivo, Estructura del módulo, Implementación de .h, Implementación de .cpp, Integración con otros módulos y Ejemplo de funcionamiento. Se hizo énfasis en el porqué de las decisiones tomadas (uso de flock, log_event_system con job_id: null, registro de la solicitud de cancelación desde CLI antes de invocarla, entre otros), delimitando correctamente qué hace y qué NO hace el módulo.
Modificaciones
Estado de la resolución: Aceptado: La IA generó el documento siguiendo fielmente la plantilla de .atl/crear_doc_RF.md, con una estructura correcta, ejemplos reales extraídos de las pruebas ejecutadas, referencias a los archivos involucrados y una correcta delimitación de alcance.
Revisión realizada:
Se verificó que el documento plasmara correctamente la naturaleza del archivo events.jsonl en formato JSONL, el uso obligatorio de job_id (con valor null para eventos globales/pre-creación), la serialización entre procesos con open/write + flock(LOCK_EX) + fsync, el orden semántico correcto al cancelar un trabajo y todos los puntos de integración acordados para este RF.
Cambios aplicados:
- docs/technical-guide/RF-14-Bitacora-de-eventos-y-errores.md: Creación del documento técnico del RF-14 con base a la plantilla, evidenciando el diseño, implementación, integración y pruebas realizadas.
Prueba agregada: Revisión visual contra la implementación existente y verificación de que los ejemplos plasmados coincidieran con las salidas reales obtenidas en las pruebas realizadas en WSL.
Implementación de feature
Se documentó la Bitácora de eventos y errores (RF-14) del sistema Hermes. 
El archivo se ubica dinámicamente en el mismo directorio que jobs.json (~/.local/share/hermes/data/events.jsonl), se genera en formato JSON Lines (JSONL) y cada línea contiene obligatoriamente ts, job_id (string para eventos asociados a un trabajo o null para eventos globales), level y message, con un campo opcional context. 
Se documentaron los eventos cubiertos: Job recibido, Transición a RUNNING (con PID), Transición a SUCCEEDED/Transición a FAILED, Cancelación solicitada (desde CLI), Cancelación exitosa, Petición inválida, Rechazo de Validación y Error interno del daemon. Además, se dejó explícito el uso de log_event para eventos asociados a un job y log_event_system para eventos pre-creación con job_id: null.
Aprendizaje
- Documentar con base real: Al contar con la implementación ya probada en WSL, fue posible plasmar decisiones técnicas reales (race condition entre CLI y daemon, necesidad de flock, causalidad en el orden de logs) en lugar de suposiciones.
- Plantilla estricta: Seguir .atl/crear_doc_RF.md al pie de la letra obligó a mantener consistencia con el resto de la documentación técnica del proyecto Hermes.
- Delimitar alcance: Es fundamental dejar claro qué sí cubre el RF y qué no cubre, evitando ambigüedad para futuras iteraciones.
- Evidencia trazable: Relacionar directamente los archivos .h/.cpp modificados con cada punto del documento facilita la trazabilidad entre requisito, implementación y verificación.
- Valor de la iteración: Las correcciones detectadas durante las pruebas (orden de logs, serialización, eventos pre-creación) merecen quedar documentadas, ya que explican el porqué detrás de la solución final.