# Uso de inteligencia artificial

# 31. Documentación técnica del RNF-11: Escritura persistente evitando estados parcialmente actualizados

## Objetivo

Redactar la documentación técnica del **RNF-11** siguiendo la plantilla `.atl/crear_doc_RF.md`, describiendo el mecanismo de escritura atómica ya existente en Hermes (`guardarAtomico()`), el respaldo con `link()`, la sincronización con `fsync`, el bloqueo con `flock` y `mutex`, y la recuperación desde `jobs.json.bak`. Además, reflejar los chequeos defensivos añadidos recientemente (`EXDEV`, validación de directorio) y dejar claro que el sistema evita escrituras directas con truncamiento.

---

## Prompt 1

```text
ahora haz la documentacio del RNF-11 usando las skill ".atl\crear_doc_RF.md"
```

---

## Resultado 1

La IA generó el documento `docs/technical-guide/2-Nucleo del proyecto/RNF-11-escritura-atomica.md` siguiendo estrictamente la plantilla:

**Estructura aplicada:**
- **Descripción:** Explicación del problema (estados parcialmente actualizados) y la solución con escritura atómica.
- **Objetivo:** Meta técnica con cita en bloque y lista "Lo que hace / Lo que NO hace".
- **Estructura del módulo:** Árbol con archivos involucrados (`storage.h`, `storage.cpp`, `data_paths.h`) y tabla de responsabilidades.
- **Implementación de `.cpp`:** Desglose paso a paso de `modificarJobsSeguros()`, `guardarAtomico()`, `actualizarRespaldo()`, `leerSinBloqueo()`, `sincronizarDirectorio()`, `limpiarTemporalesDeJobs()`.
- **Integración con otros módulos:** Relación con `scheduler`, `recovery`, `event_log`, `main/clean/config`.
- **Integración con RNF-09 / RF-13:** Complemento a recuperación tras reinicio y aislamiento de fallos.
- **Ejemplo de funcionamiento:** Flujo con archivos resultantes (`jobs.json`, `jobs.json.bak`, `jobs.lock`) y garantía ante corte de energía.

Se dejó explícito que **no** se utilizan `std::ofstream` con truncamiento y que se emplea `tmp + fsync + rename + fsync(dir)`, con manejo de `EXDEV` y validación del directorio.

---

# Modificaciones

**Estado de la resolución:** **[Aceptado tras verificación]**

**Revisión realizada:**
Se verificó que la documentación coincidiera con el código actual en `storage.cpp`:
- Patrón atómico presente tal como se describe.
- Uso de `O_EXCL`, `fsync`, `link`, `rename`, `fsync` directorio.
- Bloqueo con `mutexStorage` + `BloqueoArchivo` (`flock`).
- Auto-reparación desde respaldo.
- Chequeos defensivos añadidos (`EXDEV`, validación de directorio).
- Limpieza de temporales huérfanos.

**Cambios aplicados:**
1. Creación de `docs/technical-guide/2-Nucleo del proyecto/RNF-11-escritura-atomica.md` con la plantilla completa.
2. Documentación detallada del mecanismo sin inventar código no existente.

**Prueba agregada:** Revisión cruzada entre documentación y `storage.cpp` para asegurar consistencia.

---

## Implementación de feature

### Documentación técnica de RNF-11

Se documentó formalmente el requisito no funcional, dejando trazable:
- **Por qué:** Evitar estados parcialmente actualizados ante fallos.
- **Cómo:** Escritura atómica duradera con sincronización a disco.
- **Qué garantiza:** Integridad, recuperabilidad y consistencia entre procesos.
- **Qué no hace:** Escritura directa con truncamiento o atomicidad entre distintos sistemas de archivos.

---

## Modificación de archivo

### `docs/technical-guide/2-Nucleo del proyecto/RNF-11-escritura-atomica.md`
Documento completo siguiendo `.atl/crear_doc_RF.md` con todas las secciones aplicables (sin "Implementación de .h" ya que no hay cabecera nueva específica para este RNF, únicamente el uso de `storage.h` existente).

---

# Implementación final

**Resultado:** Documentación técnica del RNF-11 creada y alineada con la implementación actual. Queda claramente establecido que Hermes cumple con RNF-11 mediante escritura atómica, sincronización a disco, respaldo seguro y recuperación automática.

---

# Aprendizaje

1. **Documentar lo existente:** No siempre es necesario implementar para documentar. Cuando el mecanismo ya es correcto y robusto, el valor está en explicarlo con claridad, justificar las decisiones y delimitar el alcance.
2. **Importancia del `fsync` directorio:** Tras `rename`, sincronizar el directorio es tan importante como sincronizar el archivo para garantizar durabilidad ante corte de energía.
3. **Hardlink como respaldo:** Usar `link()` evita copiar datos y permite mantener una copia íntegramente válida del estado anterior antes del reemplazo atómico.
4. **Plantillas fuerzan rigor:** Seguir `.atl/crear_doc_RF.md` obliga a explicar el *por qué*, delimitar qué no hace y mostrar ejemplos reales, resultando en documentación más útil para auditorías.
5. **Trazabilidad RNF-RF:** Vincular RNF-11 con RF-13/RNF-09 deja claro cómo los requisitos no funcionales sostienen la resiliencia del sistema.
