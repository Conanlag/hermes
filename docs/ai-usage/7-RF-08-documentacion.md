# Uso de inteligencia artificial

# 7. Documentación técnica RF-08

## Objetivo

Documentamos la feature RF-08 (consulta por ID con `obtenerJobPorId`, `statusDesdeTexto` y corrección del crash en filtros) como documento técnico en `docs/technical-guide/2-Nucleo del proyecto/RF-08.consulta-id.md`, siguiendo estrictamente la plantilla de `.atl/crear_doc_RF.md` (rol Arquitecto + Technical Writer, tono analítico, alcance delimitado, bloques `cpp/json/bash/text`).

---

## Prompt 1
```text
si, genera primero el RF-08 de la feature, despues el ai-usage para completar la feature y despues el ai-usage de como se hizo el doc de RF-08
```

---

## Resultado 1

Se generó `RF-08.consulta-id.md` con: descripción de 3 párrafos (lectura puntual, separación `job`/`status`/`filter`/`validator`, corrección del crash), objetivo con cita del requerimiento más lista de consideraciones (hace / NO hace), árbol del módulo más tabla de responsabilidades, definición de los cinco `Status` con representación en disco, desglose de `.h` (propósito, includes, `struct Job`, prototipos con justificación `bool + salida`), desglose de `.cpp` (`statusDesdeTexto`, `obtenerJobPorId` con extracción defensiva, `filtrarPorId` adelgazado, impresión defensiva en los otros filtros), integración con `main`/`validator`/`job`/`status`/`filter` e integración con RF-01/RF-02/RF-06/RF-09, y ejemplos (`filter id 2`, `filter id 999`, JSON de solo lectura).

---

# Modificaciones
**Estado de la resolución:** Aceptado tras verificación

**Revisión realizada:** Verificamos que cada prototipo, mensaje y ejemplo del documento existiera en el código (`obtenerJobPorId`, `statusDesdeTexto`, línea `Codigo de salida`, guardas `contains` con defaults `N/A`/`0`/`QUEUED`) y que el alcance negativo fuera exacto (sin normalización, sin paginación, sin formato máquina).

**Cambios aplicados:** Ninguno sobre la propuesta de la IA; se aceptó el documento tal cual con el nombre `RF-08.consulta-id.md` coherente con `RF-01.job.md` y `RF-09.filter.md`.

**Prueba agregada:** Lectura cruzada contra `include/job.h`, `include/status.h`, `src/job/job.cpp`, `src/status/status.cpp` y `src/filter/filter.cpp`, más las salidas WSL aportadas (`filter id 2`, `filter programa sleep`, `filter status QUEUED`).

---

## Implementación de feature

Se integró el documento `RF-08.consulta-id.md` al technical-guide como referencia de la consulta puntual: qué devuelve, por qué con `bool + salida`, qué crash corrigió y cómo probarla.

---

## Modificación de archivo

Nuevo `docs/technical-guide/2-Nucleo del proyecto/RF-08.consulta-id.md` (único archivo de esta interacción; no se tocó código).

---

# Implementación final

```text
docs/technical-guide/2-Nucleo del proyecto/RF-08.consulta-id.md
```

```bash
./hermes filter id 2
./hermes filter id 999
```

---

# Aprendizaje

Aprendimos que la documentación de una feature con bug incluido debe narrar el bug (causa `operator[]` sin `contains`, datos viejos sin `pid`) en vez de ocultarlo: el documento gana valor cuando explica por qué la impresión defensiva existe.
