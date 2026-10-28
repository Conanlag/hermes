# Uso de inteligencia artificial

# 34. Implementación del RNF-28: Persistencia atómica o recuperable

## Objetivo

Garantizar el cumplimiento estricto del RNF-28: *"Las actualizaciones persistentes deberán ser atómicas o recuperables; una interrupción durante la escritura no deberá dejar el repositorio de datos inutilizable"* en el proyecto conanlag/hermes.

Se verificó y endureció el mecanismo de persistencia de `jobs.json`, añadiendo una validación y auto-restauración proactiva al arranque desde `jobs.json.bak`, manteniendo la bitácora `events.jsonl` en modo append y sin romper el comportamiento existente.

## Prompt 1

```text
Actúa como un arquitecto experto en C++17. Nuestro objetivo es auditar y garantizar el cumplimiento estricto del RNF-28 — Persistencia atómica o recuperable ("Las actualizaciones persistentes deberán ser atómicas o recuperables; una interrupción durante la escritura no deberá dejar el repositorio de datos inutilizable") en el proyecto conanlag/hermes.

Fase 1: Auditoría de Persistencia y Recuperación
...
Fase 2: Plan de Acción
...
Entrégame tu diagnóstico inicial y tu propuesta de diseño paso a paso. No comiences a escribir código fuente ni a refactorizar hasta que yo apruebe el plan estratégico.
```

## Resultado 1

Se realizó auditoría completa:
- **Atomicidad `jobs.json`:** Ya existía `tmp + fsync(archivo) + rename + fsync(directorio)`, `O_EXCL`, respaldo con `link()`, protección `EXDEV` y limpieza de temporales.
- **Recuperabilidad:** Existía fallback perezoso en `leerSinBloqueo()` desde `jobs.json.bak`, pero **no era proactivo al arranque**.
- **`events.jsonl`:** Ya utilizaba `O_WRONLY | O_APPEND | O_CREAT` garantizando que los logs anteriores no se pierden.

Se aprobó añadir validación proactiva al arranque sin bloquearlo, emitiendo log `WARN` al restaurar.

## Prompt 2

```text
apruebo tu plan, prosigue
```

## Resultado 2

Se implementaron los cambios:

- **`include/storage.h`**: Declaración de `verificarYRestaurarJobsAlArranque()`.
- **`src/storage/storage.cpp`**: 
  - Añadido `#include <fstream>`.
  - Implementado `verificarYRestaurarJobsAlArranque()`: valida `jobs.json` con `nlohmann::json`. Si es inválido/truncado, comprueba `jobs.json.bak`, lo copia con `std::filesystem::copy_file(overwrite_existing)` sobre `jobs.json`, vuelve a validar y registra `"jobs.json corrupto o truncado. Restaurado automáticamente desde jobs.json.bak"` con `EventLog::log_event_system()` a nivel `WARN`. Si ambos están inválidos o la copia falla, registra el error sin abortar el arranque.
- **`src/scheduler/scheduler.cpp`**: Llamada a `verificarYRestaurarJobsAlArranque()` tras `limpiarTemporalesDeJobs()` y antes de `recuperarTrabajosInterrumpidos()`.

## Verificación

- **Compilación:** `make` exitoso en `src/hermes` sin errores.
- **Atomicidad:** Confirmado patrón `.tmp + fsync + rename + fsync(dir)`, `link()` para respaldo, `EXDEV` manejado.
- **Append log:** `escribirLineaJsonl()` usa `O_WRONLY | O_APPEND | O_CREAT` con `flock()` y `fsync()`.
- **No bloqueante:** La restauración es silenciosa para el flujo, solo emite log cuando realmente restaura.

## Estado

**[Aceptado tras verificación]** - RNF-28 completo al 100%. Las actualizaciones son atómicas o recuperables y una interrupción durante la escritura no deja el repositorio de datos inutilizable.

## Aprendizaje

1. **Proactivo vs perezoso:** Validar al arranque evita que `jobs.json` corrupto circule por el sistema antes de cualquier lectura.
2. **Doble capa de seguridad:** Validación temprana + `leerSinBloqueo()` como *fallback* perezoso cubren ambos escenarios.
3. **Respaldo válido:** Usar `link()` desde la última versión íntegramente válida evita crear un `.bak` corrupto.
4. **Sin romper arranque:** Ante corrupción irrecuperable, el sistema registra el fallo pero no aborta, manteniendo la robustez.
5. **Logs persistentes:** `events.jsonl` en modo *append* garantiza trazabilidad incluso tras fallos de escritura.
