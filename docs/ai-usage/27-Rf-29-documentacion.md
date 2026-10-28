# Uso de inteligencia artificial

# 27. RF-29 Documentación del Requisito Funcional: Manejo de terminación inesperada de procesos hijo

## Objetivo

Documentar el Requisito Funcional **RF-29** ("Manejo de terminación inesperada de procesos hijo"), generando el documento técnico formal `docs/technical-guide/2-Nucleo del proyecto/RF-29.terminacion-inesperada.md` con base en la plantilla y directrices estandarizadas en la skill `.atl/crear_doc_RF.md`.

El objetivo fue plasmar de forma técnica, analítica y transparente la arquitectura completa de supervisión y diagnóstico post-mortem de Hermes ante muertes inesperadas de procesos subordinados (crashes por `SIGSEGV`, `SIGKILL`, `SIGABRT`, etc.), detallando el porqué de la decisión de descartar `SIGCHLD` asíncrono y *polling*, la estructura fuertemente tipada `ResultadoProceso`, el blindaje de tuberías de `stderr`, la persistencia en `jobs.json` (`mensaje_error`), el registro en `events.jsonl` (Nivel `ERROR`) y la exposición en el CLI.

---

## Prompt 1

```text
haz la documentacion con todo lo que hiciste para ese RF usando el skill ".atl\crear_doc_RF.md"
```

---

## Resultado 1

La IA consultó el archivo `.atl/crear_doc_RF.md` para asimilar la estructura requerida, el tono analítico y las secciones mandatorias. A partir de la auditoría y de la implementación realizada en `process.h`, `process.cpp`, `scheduler.cpp` y `filter.cpp`, generó el documento técnico `docs/technical-guide/2-Nucleo del proyecto/RF-29.terminacion-inesperada.md`.

El documento estructuró detalladamente:
1. **Descripción:** Resumen de alto nivel del problema de terminación abrupta en entornos POSIX y el rol de Hermes para evitar recursos zombies y garantizar la trazabilidad forense.
2. **Objetivo y Consideraciones actuales:** Meta técnica formal mediante cita en bloque, delimitando explícitamente lo que el módulo hace y lo que NO hace (sin reintentos automáticos, sin `SIGCHLD` global asíncrono).
3. **Estructura del módulo:** Diagrama de árbol y tabla Markdown con las responsabilidades de cada componente involucrado.
4. **Definición de los estados:** Matriz de transiciones hacia `FAILED` y `CANCELED`, detallando condiciones desencadenantes, códigos de salida negativos y mensajes diagnósticos.
5. **Implementación de `.h` y `.cpp`:** Desglose modular de `ResultadoProceso`, `obtenerNombreSenal()`, `esperarProceso()`, drenado reactivo de tuberías en `trabajador()` y persistencia en `finalizarTrabajo()`.
6. **Integración con otros módulos y RFs:** Vínculos con `jobs.json`, `events.jsonl`, `filter.cpp` y compatibilidad con RF-06, RF-10, RF-11, RF-14, RF-30 y RNF-09.
7. **Ejemplo de funcionamiento:** Trazabilidad de dos escenarios reales (`SIGSEGV` y `SIGKILL`) ilustrando la salida en CLI, en `jobs.json` y en `events.jsonl`.

---

# Modificaciones

**Estado de la resolución:** **[Aceptado]** tras verificación.

**Revisión realizada:**
Se verificó que el documento redactado cumpliera estrictamente con los estándares fijados en `.atl/crear_doc_RF.md`:
- **Estilo y tono:** Redacción directa, profesional y centrada en justificar las decisiones de diseño (ej. descarte de `SIGCHLD` por falta de *async-signal safety* y colisión de cosecha de PIDs).
- **Delimitación de alcance:** Sección de "Consideraciones actuales" claramente dividida en lo que el módulo hace y lo que no hace.
- **Fidelidad técnica:** Los fragmentos de código C++ y los esquemas JSON reflejan con total exactitud la implementación en el código base.
- **Ejemplos prácticos:** Se incluyeron las salidas esperadas en consola y las líneas JSONL resultantes con sus marcas temporales y claves obligatorias.

**Cambios aplicados:**
- `docs/technical-guide/2-Nucleo del proyecto/RF-29.terminacion-inesperada.md` [NUEVO]: Creación del documento técnico para el Requisito Funcional RF-29.

**Prueba agregada:**
Revisión visual de la sintaxis Markdown, validación de la jerarquía de títulos y comprobación cruzada contra los archivos de código fuente `process.h`, `process.cpp`, `scheduler.cpp` y `filter.cpp`.

---

## Implementación de feature

### Documentación técnica formal del RF-29

Se redactó y publicó la documentación de ingeniería que describe el comportamiento del sistema ante terminaciones inesperadas de procesos subordinados. Esta documentación provee:
- Especificación formal del contrato de supervisión de procesos.
- Justificación algorítmica de la detección reactiva vía descriptor de pipe (costo cero de CPU y latencia cero).
- Registro estandarizado de señales fatales POSIX en la bitácora operativa y en el almacén de datos.
- Referencia técnica clara para futuros mantenedores del motor de ejecución de Hermes.

---

## Modificación de archivo

### `docs/technical-guide/2-Nucleo del proyecto/RF-29.terminacion-inesperada.md` [NUEVO]
```markdown
# RF-29 — Manejo de terminación inesperada de procesos hijo

## Descripción
En entornos de ejecución basados en procesos POSIX, los procesos hijo ejecutados por un despachador pueden ser terminados de forma anormal debido a señales fatales del sistema operativo...
```

---

# Implementación final

El archivo quedó integrado en la estructura documental del núcleo del proyecto:

```text
docs/technical-guide/2-Nucleo del proyecto/
├── RF-01.job.md
├── RF-02.validator.md
├── RF-06.status.md
├── ...
├── RF-27.solicitudes-idempotentes.md
├── RF-29.terminacion-inesperada.md
└── RF-30.escalamiento-cancelacion.md
```

Ruta del documento generado:
`docs/technical-guide/2-Nucleo del proyecto/RF-29.terminacion-inesperada.md`

---

# Aprendizaje

1. **Estandarización documental como salvaguarda arquitectónica:**
   Tener una plantilla estructurada (`.atl/crear_doc_RF.md`) garantiza que ningún aspecto crítico (como la delimitación de alcance "lo que NO hace", el árbol de responsabilidades o las interacciones entre módulos) quede omitido. Esto previene ambigüedades durante auditorías de calidad o fases de integración.

2. **Documentar el "por qué" previene regresiones:**
   En sistemas concurrentes de bajo nivel en C++, es tan importante documentar por qué se adoptó un enfoque (supervisión síncrona por hilo trabajador) como por qué se rechazaron otros enfoques populares pero riesgosos (manejadores asíncronos de `SIGCHLD`). Dejar esto por escrito en la guía técnica evita que futuros colaboradores introduzcan defectos por desconocimiento del contexto de diseño.

3. **Separación de roles en la bitácora de IA:**
   Registrar de forma separada el uso de IA para la codificación técnica (archivo `26`) y para la documentación técnica (archivo `27`) asegura una trazabilidad granular, permitiendo auditar con exactitud qué partes del trabajo fueron generadas, modificadas o verificadas en cada fase del desarrollo.
