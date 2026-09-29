# Uso de inteligencia artificial

# 5. Documentación técnica RF-02

## Objetivo

Documentamos la implementación de RF-02 (módulo `validator`) como documento técnico en `docs/technical-guide/2-Nucleo del proyecto/RF-02.validator.md`, siguiendo estrictamente la plantilla de `.atl/crear_doc_RF.md` (rol Arquitecto + Technical Writer, tono analítico, alcance delimitado, bloques `cpp/json/bash/text`).

---

(NOTA: el contenido de crear_doc_RF.md se encuentra al final de este archivo)

## Prompt 1
```text
esta terminado ahora accede y analiza .atl\crear_doc_RF.md y crea la documentacion de ese RF
```

---

## Resultado 1

Se analizó `.atl/crear_doc_RF.md` y los documentos existentes (`RF-TEMPLATE.md`, `RF-01.job.md`) para replicar estructura y tono. Se generó `RF-02.validator.md` con: descripción de 3 párrafos (guardián, doble capa `argc`/`validator`, transversal sin estado), objetivo con cita del requerimiento más lista de consideraciones (hace / NO hace), árbol del módulo más tabla de responsabilidades, definición del `enum class CodigoValidacion`, desglose de `.h` por fragmentos (propósito, includes, structs, prototipos), desglose de `.cpp` con subsección de `pos` y `try/catch`, integración con `main.cpp`/`job`/`filter` e integración con RF-01, y ejemplos (`12x`, `running`, camino feliz con JSON resultante).

---

# Modificaciones
**Estado de la resolución:** Aceptado tras verificación

**Revisión realizada:** Verificamos que el documento siguiera la plantilla estricta sin omitir secciones aplicables ni inventar comportamiento: la lista blanca documentada coincide con el código (`job/filter/--version`, `id/status/programa`, cinco estados en mayúsculas), el flujo `pos != size` describe el `validator.cpp` real y los ejemplos reproducen salidas y `jobs.json` observados en WSL.

**Cambios aplicados:** Ninguno sobre la propuesta de la IA; se aceptó el documento tal cual. Solo se mantuvo la convención de nombre `RF-02.validator.md` coherente con `RF-01.job.md` y `RF-09.filter.md`.

**Prueba agregada:** Lectura cruzada del documento contra `src/hermes/include/validator.h`, `src/hermes/src/validator/validator.cpp` y `src/hermes/src/main.cpp`: cada función, mensaje y ejemplo citados existen en el código.

---

## Implementación de feature

Se integró el documento `RF-02.validator.md` al technical-guide como referencia del requisito: qué valida, por qué con doble capa, qué NO hace (sin normalización, sin verificación en `PATH`, sin búsquedas en disco) y cómo probarlo.

---

## Modificación de archivo

Nuevo `docs/technical-guide/2-Nucleo del proyecto/RF-02.validator.md` (único archivo de esta interacción; no se tocó código).

---

# Implementación final

El documento quedó disponible en:

```text
docs/technical-guide/2-Nucleo del proyecto/RF-02.validator.md
```

con ejemplos ejecutables:

```bash
./hermes filter id 12x
./hermes filter status running
./hermes job sleep 5
```

---

# Aprendizaje

Aprendimos que documentar con plantilla estricta obliga a delimitar el NO-alcance con la misma precisión que el alcance, y que cada ejemplo del documento debe ser trazable a código y a salida real; de lo contrario la documentación se convierte en ficción.

# crear_doc_RF.md:
# ROL: Arquitecto de Software y Technical Writer C++
Actúas como un Ingeniero de Software Senior especializado en C++ moderno y arquitectura de sistemas. Tu tarea es redactar documentación técnica para Requisitos Funcionales (RF) de un proyecto llamado "Hermes".

# ESTILO Y TONO
- Escribe de forma analítica, directa y profesional.
- Explica el *por qué* de las decisiones de diseño, no solo el *qué*.
- Delimita estrictamente el alcance: menciona siempre qué es lo que el módulo hace y qué es lo que **todavía no hace**.
- Usa bloques de código con resaltado de sintaxis (`cpp`, `json`, `bash`, `text`).

# INSTRUCCIÓN PRINCIPAL
Cuando el usuario te proporcione los detalles de una nueva característica o código implementado, debes generar un documento Markdown siguiendo estrictamente la plantilla inferior. Si una sección marcada con "//SI APLICA" no es relevante para el RF actual, omítela por completo.

# PLANTILLA ESTRICTA A SEGUIR:

# {RF-##} — {Título del Requisito}

## Descripción
{Redacta un resumen de alto nivel (2-3 párrafos) sobre qué hace este requisito funcional dentro del ecosistema de Hermes.}

---

## Objetivo
{Define la meta técnica exacta de este RF. Incluye una cita en bloque (block quote) con el requerimiento del negocio o sistema. Finaliza esta sección listando explícitamente las "Consideraciones actuales" (lo que el módulo hace y lo que NO hace en esta etapa).}

---

## Estructura del módulo
{Crea un árbol de directorios en texto plano (`text`) mostrando solo los archivos involucrados en este RF.
Inmediatamente después, crea una tabla Markdown con dos columnas: `Archivo / directorio` y `Responsabilidad` para describir el propósito de cada elemento mostrado.}

## Definición de los estados
{Si este RF involucra lógica de estados, explica los valores del `enum class` correspondientes, qué significa cada estado en el ciclo de vida del proceso y cómo se representan en texto.}

---

## Implementación de `.h` //SI APLICA
{Desglosa el archivo de cabecera. Explica:
1. Propósito del archivo.
2. Dependencias incluidas (`#include`).
3. Estructuras de datos (`struct` o `class`).
4. Prototipos de funciones clave.
No pongas todo el código de golpe; explícalo por fragmentos lógicos.}

---

## Implementación de `.cpp` //SI APLICA
{Desglosa el archivo de implementación. Explica la lógica paso a paso.
Si hay lectura/escritura de archivos (JSON, I/O), manejo de memoria o llamadas al sistema (syscalls), dedica subsecciones para explicar cómo funciona ese flujo interno.}

---

## Integración con `[otros módulos]` //SI APLICA
{Explica cómo interactúa este nuevo código con los motores existentes (por ejemplo, cómo se conecta con `job.h`, `filter.h`, o cómo es invocado desde `main.cpp`).}

## Integración con {RF-##} //OTROS RF SI APLICA
{Describe si este requisito amplía, modifica o depende de un Requisito Funcional anterior.}

---

## Ejemplo de funcionamiento
{Muestra un escenario real de uso. Incluye:
1. El comando ejecutado en la terminal (`bash`).
2. El resultado esperado en la consola.
3. El estado resultante en el disco (ej. cómo queda el archivo `.json` o la base de datos tras la ejecución).}