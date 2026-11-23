# Uso de inteligencia artificial

# 53. RNF-15 — Documentación técnica y trazabilidad

## Objetivo

Documentar RNF-15 con el mismo nivel de rigor que RNF-14: un documento técnico en `docs/technical-guide/2-Nucleo del proyecto/`, seis fichas de caso en `verif/test-cases/`, la fila correspondiente de `verif/verification-plan/traceability-matrix.md` en `PASS` y este par de registros de uso de IA. El requisito no tenía ni una línea de cobertura previa: la matriz lo listaba como `Pendiente` con la fila vacía.

---

## Prompt 1

```text
Ya está implementado y verificado. Documenta RNF-15 siguiendo la plantilla de
crear_doc_RF.md y crear_ai_usage.md: documento técnico, fichas TC-043 a TC-048,
actualización de test-cases.md y de la matriz de trazabilidad.

Explica el por qué de la detección por tokens —que request_id e identidad no se
redacten— y declara los riesgos residuales sin maquillarlos.
```

---

## Resultado 1

El documento se estructuró como el de RNF-14: descripción del problema, objetivo con las consideraciones actuales, estructura del módulo, implementación del `.h` y del `.cpp`, integración con otros requisitos, ejemplo de funcionamiento, verificación y riesgo residual.

Tres decisiones de contenido que valen la pena:

1. **La descripción abre con la ausencia de frontera, no con la lista de claves.** El problema real no era «faltan claves sensibles en una lista», sino que cada punto de registro decidía por su cuenta. Empezar por ahí hace que la solución —una capa central— se lea como consecuencia y no como preferencia de estilo.
2. **La detección por tokens se explica con el contraejemplo.** `find("token")` habría redactado `request_id`; `find("auth")`, `identidad`. Sin ese contraejemplo, «detección por tokens» suena a refinamiento innecesario en lugar de a la condición que preserva RNF-22.
3. **Los riesgos residuales se declaran en cuatro puntos, con el motivo técnico.** R1 (`-p` sobre-redacta), R2 (`setup` fuera de la bitácora), R3 (lista cerrada, sin plurales) y R4 (errores del parser que solo van a la terminal del operador). El cuarto se añadió al revisar `filter.cpp` y `clean.cpp`, que imprimen texto del parser pero no escriben bitácora.

Las seis fichas siguen la plantilla de dos fases —diseño y ejecución— con los resultados observados copiados de las corridas reales, no redactados de memoria.

---

## Prompt 2

```text
¿Falta algo?
```

---

## Resultado 2

La revisión encontró un hueco de cobertura real: la auditoría inicial y las pruebas cubrían la redacción de cadenas y objetos, `validator`, `config` y `network`, pero **no** el camino de `scheduler` y `storage` cuando `jobs.json` no se puede recuperar. Ese camino registraba `e.what()`.

El hueco se cerró en tres pasos: corregir `scheduler.cpp`, `storage.cpp` y `cancel.cpp` con `detalleSeguro`; escribir `TC-048` que reproduce el escenario con `jobs.json` y `jobs.json.bak` corruptos; y reejecutar la batería completa —dieciocho scripts— antes de dar el documento por bueno.

La fila de la matriz se redactó con la evidencia de la corrida: seis casos en `PASS`, la regresión TC-030…TC-042 también en `PASS`, compilación limpia con `-Wall -Wextra` y los cuatro riesgos residuales citados.

---

# Modificaciones

**Estado de la resolución:** **[Modificado]** — la documentación estaba completa en su estructura, pero la revisión final identificó que la cobertura no incluía el arranque con estado corrupto; se corrigió el código, se añadió el caso y se reejecutó todo antes de publicar.

**Revisión realizada:** se contrastó cada afirmación del documento con una salida real. Las longitudes de `TC-045` (`13` y `140`), el detalle exacto de `TC-046` (`JSON mal formado`), los cuatro mensajes de `TC-047` y el detalle de `TC-048` se copiaron de las corridas. El ejemplo de `events.jsonl` se verificó con `od -c` para asegurar que el `[REDACTED]` está realmente en el archivo. También se revisó que la matriz no declarara `PASS` en una fila sin script ni evidencia.

**Cambios aplicados:**

1. `docs/technical-guide/2-Nucleo del proyecto/RNF-15.registros-sin-secretos.md` con las nueve secciones de la plantilla.
2. `verif/test-cases/TC-043.md` a `TC-048.md`, con diseño y resultados empíricos.
3. `verif/test-cases/test-cases.md`: párrafo de RNF-15 con los seis casos.
4. `verif/verification-plan/traceability-matrix.md`: fila RNF-15 completa en `PASS` con evidencia y riesgos residuales.
5. `verif/scripts/TC-048.sh` y `verif/results/results_TC-048.md` como evidencia del hueco cerrado.
6. `scheduler.cpp`, `storage.cpp`, `cancel.cpp`: `detalleSeguro` en los puntos que faltaban.

**Prueba agregada:** `TC-048` (arranque con `jobs.json` y respaldo corruptos) y la reejecución de TC-030…TC-047. Dieciocho scripts en `PASS`, compilación limpia con `make -B`.

---

## Implementación de feature

La documentación de RNF-15 se apoya en tres ideas que se repiten en el documento técnico:

```text
1. El problema es la ausencia de frontera, no la falta de reglas.
2. La detección por tokens es lo que permite redactar sin romper RNF-22.
3. Lo que no se registra no se puede fugarse; lo que se registra, pasa por la capa.
```

---

## Modificación de archivo

**`verif/verification-plan/traceability-matrix.md`** — la fila:

```markdown
| RNF-15 | Los registros no deberán exponer secretos ni contenido sensible de configuración: redacción centralizada por clave y patrón, errores de parseo controlados y metadatos operativos seguros. | Alta | Prueba | TC-043, TC-044, TC-045, TC-046, TC-047, TC-048 | verif/scripts/TC-043.sh…TC-048.sh + verif/results/results_TC-043.md…TC-048.md ([PASS], 2026-11-22); regresión TC-030…TC-042 en PASS; compilación limpia con `-Wall -Wextra` | PASS | R1…R4 |
```

**`docs/technical-guide/2-Nucleo del proyecto/RNF-15.registros-sin-secretos.md`** — el resumen de verificación:

```markdown
| Caso | Escenario | Resultado observado |
|---|---|---|
| TC-043 | Dos asignaciones sensibles en un Job | `--password=[REDACTED]` y `--api-key=[REDACTED]`; `jobs.json` con los valores reales |
| TC-048 | `jobs.json` y `jobs.json.bak` corruptos al arrancar | `detalle: "excepcion de formato JSON (detalle omitido)"` |
```

---

# Implementación final

```text
docs/technical-guide/2-Nucleo del proyecto/RNF-15.registros-sin-secretos.md
verif/test-cases/TC-043.md … TC-048.md
verif/scripts/TC-043.sh … TC-048.sh
verif/results/results_TC-043.md … results_TC-048.md
docs/ai-usage/52-RNF-15-redaccion-secretos.md
docs/ai-usage/53-RNF-15-documentacion-tecnica.md

$ bash verif/scripts/TC-048.sh
PASS V1/AC1: el error de arranque no expone jobs.json ni el parser.
PASS V2/AC2: la consola informa el fallo con un mensaje controlado.
PASS: RNF-15 TC-048 sin fallos.
```

---

# Aprendizaje

**Un documento no cierra un requisito; lo cierra la cobertura.** La estructura estaba completa desde la primera versión y aun así faltaba un camino entero: `jobs.json` irrecuperable. Documentar lo que existe no revela lo que no se probó. La pregunta «¿falta algo?» y, sobre todo, la búsqueda del patrón prohibido en todo el árbol fueron lo que convirtió un documento correcto en una garantía verificada.

**El riesgo residual también es documentación.** R1, R2, R3 y R4 no son disculpas: son límites declarados con su motivo técnico. Un lector que sepa que `-p` se sobre-redacta puede decidir si le importa; un lector que no lo sepa descubrirá el comportamiento como un defecto. Declarar el límite es parte del requisito.

**La trazabilidad exige evidencia ejecutada.** Escribir `PASS` en la matriz sin un script que lo produzca es una afirmación sin respaldo. Por eso cada fila cita el script, el archivo de resultados y la fecha de la corrida.

**Sobre Prompt Engineering.** El prompt pedía dos cosas que mejoraron el resultado: declarar los riesgos sin maquillar y explicar el por qué de la detección por tokens. Cuando se le pide a un modelo justificar una decisión de diseño, la documentación deja de describir el código y empieza a explicar el sistema.
