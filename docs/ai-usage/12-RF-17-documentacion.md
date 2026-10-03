# Uso de inteligencia artificial

# 12. Documentación técnica RF-17

## Objetivo

Documentamos la feature RF-17 (comando `--help` con ayuda integrada y códigos de salida) como documento técnico en `docs/technical-guide/2-Nucleo del proyecto/RF-17.ayuda.md`, siguiendo la plantilla de `.atl/crear_doc_RF.md` (rol Arquitecto + Technical Writer, tono analítico, alcance delimitado, bloques `cpp/bash/text`).

---

## Prompt 1
```text
ahora haz el rf con el rf template, al ai-usage de esto y el de la creacion del rf
```

---

## Resultado 1

Se generó `RF-17.ayuda.md` con: descripción de 3 párrafos (ayuda como presentación pura, módulo espejo, régimen compartido con RF-02), objetivo con cita del requerimiento más lista de consideraciones (hace / NO hace, sin ayuda por comando ni red), árbol del módulo más tabla, vocabulario de códigos `0/1`, desglose de `.h` (sin dependencias ni structs, firma espejo) y `.cpp` (`cout` plano vs `info()`, sin `try/catch` justificado), integración con `main`/`validator` (orden validador-primero) e integración con RF-01/RF-02/RF-06/RF-10, y ejemplos (`--help → 0`, `foo → 1`) sin efectos en disco.

---

# Modificaciones
**Estado de la resolución:** Aceptado tras verificación

**Revisión realizada:** Verificamos que la firma, el texto y los códigos del documento coincidieran con `help.h`/`help.cpp`/`main.cpp`/`validator.cpp` reales y con las salidas WSL aportadas, y que el NO-alcance fuera exacto (sin `job --help`, sin paginación, sin red).

**Cambios aplicados:** Ninguno sobre la propuesta de la IA; se aceptó el documento tal cual con el nombre `RF-17.ayuda.md` coherente con la serie.

**Prueba agregada:** Lectura cruzada contra `include/help.h`, `src/help/help.cpp`, `src/main.cpp` y `src/validator/validator.cpp`, más salidas WSL de la sesión.

---

## Implementación de feature

Se integró el documento `RF-17.ayuda.md` al technical-guide como referencia del comando de ayuda: qué muestra, por qué como módulo propio y cómo probarlo.

---

## Modificación de archivo

Nuevo `docs/technical-guide/2-Nucleo del proyecto/RF-17.ayuda.md` (único archivo de esta interacción; no se tocó código).

---

# Implementación final

```text
docs/technical-guide/2-Nucleo del proyecto/RF-17.ayuda.md
```

```bash
./hermes --help; echo $?
```

---

# Aprendizaje

Aprendimos que documentar presentación pura exige justificar lo ausente (`try/catch`, dependencias, structs) con la misma fuerza que lo presente: el valor está en explicar por qué la ayuda no lee disco y por qué el color se reservó para una línea.
