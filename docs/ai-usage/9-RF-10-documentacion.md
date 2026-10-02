# Uso de inteligencia artificial

# 9. Documentación técnica RF-10

## Objetivo

Documentamos la feature RF-10 (cancelación `QUEUED` directa y `RUNNING` con señal, veredicto detallado y mensajes con causa) como documento técnico en `docs/technical-guide/2-Nucleo del proyecto/RF-10.cancel.md`, siguiendo estrictamente la plantilla de `.atl/crear_doc_RF.md` (rol Arquitecto + Technical Writer, tono analítico, alcance delimitado, bloques `cpp/json/bash/text`).

---

## Prompt 1
```text
muy bien, haz el RF correspondiente, el ai-usage del feature y el ai-usage de la creacion del RF
```

---

## Resultado 1

Se generó `RF-10.cancel.md` con: descripción de 3 párrafos (doble mecanismo marca + señal, dos velocidades, reutilización sin ser dueño), objetivo con cita del requerimiento más lista de consideraciones (hace / NO hace, incluida la carrera pendiente), árbol del módulo más tabla, definición del `enum CodigoCancelacion` con tabla de efectos, desglose de `.h` y `.cpp` (ramificación por estado, orden flag-antes-que-señal, cierre `NO_EXISTE`), integración con `main`/`job`/`process`/`validator` (incluida la nota del `<1>` de `bash`) e integración con RF-01/RF-02/RF-06/RF-08, y ejemplos (`cancel 5 → -15`, `cancel 999 → -1`, rechazos con causa).

---

# Modificaciones
**Estado de la resolución:** Aceptado tras verificación

**Revisión realizada:** Verificamos que cada rama, mensaje y ejemplo del documento existiera en el código (`CANCELADO`/`SOLICITUD_REGISTRADA`/`NO_EXISTE`/`NO_CANCELABLE`/`ERROR_LECTURA`, `actualizarResultadoJob(CANCELED, -1)`, `kill/SIGTERM`, mensajes `Job cancelado:` vs `Cancelación solicitada:`) y que el NO-alcance fuera exacto (sin `SIGKILL`, sin reintentos, sin cerrar la carrera).

**Cambios aplicados:** Ninguno sobre la propuesta de la IA; se aceptó el documento tal cual con el nombre `RF-10.cancel.md` coherente con la serie.

**Prueba agregada:** Lectura cruzada contra `include/cancel.h`, `src/cancel/cancel.cpp` y `src/main.cpp`, más las salidas WSL aportadas (ID 5 `RUNNING → CANCELED/-15`, ID 999 `QUEUED → CANCELED/-1`).

---

## Implementación de feature

Se integró el documento `RF-10.cancel.md` al technical-guide como referencia de la cancelación en dos velocidades: qué hace cada rama, por qué en ese orden y cómo probarla.

---

## Modificación de archivo

Nuevo `docs/technical-guide/2-Nucleo del proyecto/RF-10.cancel.md` (único archivo de esta interacción; no se tocó código).

---

# Implementación final

```text
docs/technical-guide/2-Nucleo del proyecto/RF-10.cancel.md
```

```bash
./hermes cancel 5
./hermes cancel 999
./hermes cancel 999999
```

---

# Aprendizaje

Aprendimos que documentar una operación con efectos reales (señales, estados finales asíncronos) exige narrar el orden y la confirmación, no solo la llamada: el valor del documento está en explicar por qué el flag va antes que la señal y qué significa cada `-15`/`-1`.
