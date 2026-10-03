# Uso de inteligencia artificial

# 10. Documentación técnica RNF-09

## Objetivo

Documentamos la verificación de RNF-09 (el fallo de un trabajo no afecta a otros, dictamen CUMPLE) como documento técnico en `docs/technical-guide/2-Nucleo del proyecto/RNF-09.aislamiento-fallos.md`, siguiendo la plantilla de `RNF-TEMPLATE.md` (descripción, categoría, métrica medible, módulos afectados, restricciones).

---

## Prompt 1
```text
haz el rnf siguiendo el template docs\technical-guide\2-Nucleo del proyecto\RNF-TEMPLATE.md, despues haz el ai-usage de la documentacion del RNF
```

---

## Resultado 1

Se generó `RNF-09.aislamiento-fallos.md` con: descripción del aislamiento (proceso, supervisor, pipe y `waitpid` propios; CLI de vida corta; `flock` y lecturas tolerantes) más dictamen CUMPLE con la observación fuera de requisito (ID sin lock en `crearJob`); categoría Confiabilidad; métrica con los tres escenarios WSL aportados por el usuario (IDs 9/10, 11/12, 13) y el comando `g++` usado; módulos (`process`, `job`, `filter`, `jobs.json`); restricciones POSIX/WSL.

---

# Modificaciones
**Estado de la resolución:** Aceptado tras verificación

**Revisión realizada:** Verificamos que cada mecanismo citado existiera en el código (`fork`/`execvp`/`_exit(127)`, `waitpid` específico, `flock`, `leerJobs` tolerante) y que cada resultado de la métrica coincidiera con las salidas aportadas (ID 9 `FAILED` vs ID 10 `SUCCEEDED`, `echo` intactos tras `cancel 11`, `sleep` intactos tras programa inexistente).

**Cambios aplicados:** Ninguno sobre la propuesta de la IA; se aceptó el documento tal cual con el nombre `RNF-09.aislamiento-fallos.md`.

**Prueba agregada:** Lectura cruzada contra `src/process/process.cpp`, `src/job/job.cpp` y las salidas WSL de la sesión (sin re-ejecución: evidencia aportada por el usuario).

---

## Implementación de feature

Se integró el documento `RNF-09.aislamiento-fallos.md` al technical-guide como dictamen del requisito no funcional: qué lo garantiza, cómo se midió y qué observación queda fuera de su alcance.

---

## Modificación de archivo

Nuevo `docs/technical-guide/2-Nucleo del proyecto/RNF-09.aislamiento-fallos.md` (único archivo de código documental de esta interacción).

---

# Implementación final

```text
docs/technical-guide/2-Nucleo del proyecto/RNF-09.aislamiento-fallos.md
```

---

# Aprendizaje

Aprendimos que documentar un RNF exige métrica replayable (comandos + IDs + estados esperados), no solo argumento arquitectónico: el dictamen vale por la evidencia, y la observación honesta fuera de alcance (colisión de IDs) fortalece en vez de debilitar el documento.
