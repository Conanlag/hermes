# ADR-014: Bitácora de eventos

## Contexto

Hermes necesita conservar trazabilidad del ciclo de vida de los Jobs y de eventos relevantes del CLI y del daemon. La bitácora debe poder escribirse desde procesos concurrentes sin reescribir el historial y debe complementar, no sustituir, el estado autoritativo de `jobs.json` ni los mensajes de consola.

## Decisión

Hermes mantiene `events.jsonl` en el directorio de datos, junto a `jobs.json`, con una entrada JSON por línea y escritura append-only. Cada registro contiene `ts`, `job_id`, `level` y `message`; `context` es opcional. Los eventos asociados a un Job incluyen su ID y los eventos generales usan `job_id: null`.

El logger serializa cada escritura con `flock` sobre el archivo, escribe la línea completa con `write()` y solicita `fsync()` antes de liberar el bloqueo. Los errores de registro se informan en `stderr`; la bitácora no reemplaza ni bloquea el resultado operativo del comando. Se registran transiciones, solicitudes y rechazos relevantes, así como errores críticos del daemon. No se implementan rotación, purga ni consultas de la bitácora.

## Justificación

| Justificación     | JSONL permite añadir y procesar eventos individualmente. El bloqueo entre procesos protege el orden de las escrituras concurrentes y la estructura común facilita correlacionar eventos por Job y marca temporal. |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | Reescribir un archivo JSON completo por evento; guardar los eventos en `jobs.json`; usar un servicio de logging externo o una base de datos. |
| Consecuencias     | El historial puede inspeccionarse línea por línea y conserva eventos anteriores al añadir nuevos. El archivo crece con el tiempo y los fallos al registrar se reportan, pero no detienen la operación principal. |
| Riesgos           | Sin rotación, el archivo puede consumir espacio creciente. La bitácora es evidencia operativa, no una fuente autoritativa para reconstruir el estado de los Jobs. |
| Evidencia técnica | [event_log.cpp](../../src/hermes/src/event_log.cpp) construye y escribe las entradas JSONL; [event_log.h](../../src/hermes/include/event_log.h) define los niveles y las operaciones del logger; [data_paths.h](../../src/hermes/include/data_paths.h) resuelve la ruta junto a los datos. La integración está descrita en [RF-14](../technical-guide/2-Nucleo%20del%20proyecto/RF-14-Bitacora-de-eventos-y-errores.md). |