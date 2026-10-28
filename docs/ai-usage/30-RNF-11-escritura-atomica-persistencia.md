# Uso de inteligencia artificial

# 30. Auditoría y refuerzo del RNF-11: Escritura persistente evitando estados parcialmente actualizados

## Objetivo

Auditar el mecanismo de persistencia de `jobs.json` para garantizar el cumplimiento estricto del **RNF-11**: *"Los archivos persistentes deberán escribirse de forma que se evite dejar un estado parcialmente actualizado"*. Se revisó `storage.cpp`, se verificó que no existan escrituras directas con truncamiento y se aplicaron mejoras defensivas mínimas (chequeo de directorio, manejo explícito de `EXDEV` y documentación del patrón atómico), sin refactorizaciones masivas.

---

## Prompt 1

```text
Actúa como un experto arquitecto en C++17. Necesitamos auditar y garantizar el cumplimiento estricto del RNF-11 — Escritura persistente evitando estados parcialmente actualizados ("Los archivos persistentes deberán escribirse de forma que se evite dejar un estado parcialmente actualizado") en el proyecto conanlag/hermes.

Fase 1: Auditoría del código actual
Inspecciona el mecanismo de persistencia actual (probablemente la función modificarJobsSeguros o la lógica de escritura en scheduler.cpp / storage.cpp / data_paths.h).
Evalúa críticamente:

¿El código abre directamente jobs.json en modo de escritura/truncamiento (std::ofstream) y escribe sobre él? Si es así, esto es una violación directa al RNF-11, ya que un fallo eléctrico a mitad de la escritura corromperá el JSON dejándolo irrecuperable.

¿Se está utilizando un patrón de Escritura Atómica (escribir en un archivo .tmp, hacer flush() y luego reemplazar el original con std::filesystem::rename)?

Fase 2: Plan de Acción (Resolución del RNF-11)
Si el sistema actual es vulnerable (escribe directamente), diseña un plan de refactorización detallando:

Implementación de Escritura Atómica: Cómo modificarás la función que guarda los metadatos para que escriba en jobs.json.tmp de forma segura.

Sincronización a disco (Opcional pero recomendado): Si propones forzar la escritura a disco antes del renombre (ej. usando fsync a nivel POSIX o cerrando el ofstream correctamente) para garantizar que los datos estén en la unidad física.

Manejo del archivo Lock: Cómo interactúa este cambio con jobs.lock para que los hilos no choquen al renombrar los archivos.

Entrégame tu diagnóstico inicial y tu propuesta de diseño paso a paso. No comiences a escribir ni a refactorizar el código fuente hasta que yo apruebe el plan estratégico.
```

---

## Resultado 1

La IA realizó la auditoría completa de `src/hermes/src/storage/storage.cpp`. **El sistema YA CUMPLE con RNF-11**. No se encontró ningún `std::ofstream` abriendo `jobs.json` en modo truncamiento.

**Hallazgos clave:**
- **Escritura atómica:** `guardarAtomico()` escribe en un `.tmp` único (`pid + contador atómico` con `O_EXCL | O_CREAT | O_CLOEXEC`), hace `fsync()` sobre el descriptor, cierra el archivo, crea respaldo con `link()` desde `jobs.json` válido, ejecuta `rename()` y finalmente `fsync()` sobre el directorio.
- **Recuperación:** `leerSinBloqueo()` intenta leer `jobs.json`, si falla lee `jobs.json.bak` y repara `jobs.json` mediante `guardarAtomico()`. `limpiarTemporalesDeJobs()` elimina `.tmp.*` huérfanos al arranque.
- **Concurrencia:** `mutexStorage` + `BloqueoArchivo` con `flock(LOCK_EX)` protegen el read-modify-write completo. El `rename` ocurre mientras `jobs.lock` sigue retenido.

**Propuesta:** En lugar de refactorización masiva, aplicar **endurecimiento defensivo mínimo** (verificación de directorio, manejo explícito de `EXDEV`, documentación del patrón).

---

## Prompt 2

```text
aplica tus recomendaciones, nada de refactorizaciones masivas
1. Añadir los chequeos defensivos arriba (pequeños, sin romper API)
2. Añadir un comentario breve en guardarAtomico() documentando explícitamente "Escritura atómica: tmp + fsync + rename + fsync(dir)"
3. Verificar que ningún otro módulo escriba jobs.json directamente (auditoría rápida con grep)
```

---

## Resultado 2

Se aplicaron únicamente las mejoras solicitadas:

**Auditoría con grep:**
- `ofstream.*jobs.json` / `fopen.*jobs.json` → Sin resultados
- `"jobs.json"` → Únicamente en `storage.cpp` (constante `NOMBRE_JOBS`)
- `std::ofstream` / `fstream` → Sin resultados
- Conclusión: **Ningún otro módulo escribe directamente `jobs.json`. Todo pasa por `guardarAtomico()` vía `modificarJobsSeguros()`.**

**Modificaciones en `storage.cpp`:**
- Añadido comentario: `// Escritura atómica: tmp + fsync + rename + fsync(dir)`
- Añadido chequeo defensivo: validación de que el directorio de datos no esté vacío
- Añadido manejo explícito de `EXDEV` en `rename()` con mensaje claro

**Compilación:** `make` exitoso en `src/hermes` sin errores.

---

# Modificaciones

**Estado de la resolución:** **[Aceptado tras verificación]** - El mecanismo ya era correcto. Se reforzó con validaciones defensivas mínimas sin cambiar la API ni el comportamiento.

**Revisión realizada:**
- Se confirmó que no existe escritura directa con truncamiento a `jobs.json`.
- Se verificó el patrón completo: `O_EXCL` + `fsync` archivo + `link` backup + `rename` atómico + `fsync` directorio.
- Se validó la interacción con `jobs.lock` (mantenido durante todo el RMW).
- Se confirmó ausencia de escrituras desde otros módulos con búsqueda con `grep`.

**Cambios aplicados:**
1. Comentario explícito en `guardarAtomico()` documentando el patrón atómico.
2. Validación defensiva del directorio de datos.
3. Manejo explícito de `EXDEV` al renombrar.

**Prueba agregada:** Búsqueda con `grep` para descartar escrituras directas. Compilación con `make` en `src/hermes` exitosa.

---

## Implementación de feature

### Refuerzo del cumplimiento RNF-11 (Escritura atómica duradera)

Se consolida y documenta el mecanismo ya existente:
- **Durabilidad:** `fsync()` del archivo temporal antes de cerrar, `fsync()` del directorio tras `rename()`.
- **Atomicidad:** `rename()` sobre mismo filesystem reemplaza `jobs.json` sin ventana de truncamiento.
- **Recuperabilidad:** Respaldado con `link()` + auto-reparación desde `jobs.json.bak`.
- **Robustez:** Limpieza de temporales huérfanos y manejo de errores explícito.

---

## Modificación de archivo

### `src/hermes/src/storage/storage.cpp`
```cpp
void guardarAtomico(const json& jobs) {
    // Escritura atómica: tmp + fsync + rename + fsync(dir)
    const string ruta = hermes::rutaDatos(NOMBRE_JOBS);
    const string respaldo = hermes::rutaDatos(NOMBRE_RESPALDO);

    namespace fs = std::filesystem;

    const fs::path rutaPath(ruta);
    const fs::path dirPath = rutaPath.parent_path();

    if (dirPath.empty()) {
        throw runtime_error("No se pudo determinar el directorio de datos para escritura atómica");
    }
    ...
        actualizarRespaldo(ruta, respaldo);

        if (rename(temporal.c_str(), ruta.c_str()) == -1) {
            const int error = errno;

            if (error == EXDEV) {
                throw runtime_error(
                    "No se pudo actualizar jobs.json: origen y destino en distintos sistemas de archivos (rename atómico no soportado)"
                );
            }

            throw runtime_error(
                string("No se pudo actualizar jobs.json: ") +
                strerror(error)
            );
        }
    ...
}
```

---

# Implementación final

**Verificación realizada:**
- `grep` confirma que únicamente `storage.cpp` referencia `jobs.json` para escritura/persistencia.
- No existen `std::ofstream` truncando `jobs.json`.
- Compilación limpia en `src/hermes`.

**Resultado:** **RNF-11 queda completamente garantizado y documentado.** El mecanismo es correcto, atómico y duradero. Las mejoras aplicadas son puramente defensivas y no afectan al comportamiento existente.

---

# Aprendizaje

1. **Antes de refactorizar, auditar:** En muchos casos el proyecto ya implementa el patrón correcto. Es importante verificar con `grep` y lectura del código antes de proponer grandes refactorizaciones.
2. **Escritura atómica requiere dos `fsync`:** No basta con sincronizar el archivo; hay que sincronizar también el directorio tras `rename()` para que la entrada de directorio sea durable ante cortes de energía.
3. **Backups inteligentes:** Usar `link()` para crear el respaldo evita copiar bytes y mantiene una copia válida del estado anterior antes del reemplazo atómico.
4. **Defensiva pero mínima:** Pequeños chequeos (`EXDEV`, validación de rutas) añaden robustez sin romper la API ni introducir complejidad innecesaria.
5. **Bloqueo correcto:** Mantener `flock` + `mutex` durante todo el read-modify-write es clave para evitar lecturas inconsistentes entre procesos.
