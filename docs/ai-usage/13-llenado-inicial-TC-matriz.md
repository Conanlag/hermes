# Uso de inteligencia artificial

# 13. Llenado inicial de TC y matriz de trazabilidad

## Objetivo

Llenamos el diseño inicial de los casos de prueba del proyecto (TC-001, TC-002, TC-003, TC-004, TC-005, TC-006, TC-008, TC-014, TC-015) y sus filas en `traceability-matrix.md`. El desarrollador indicaba en cada mensaje el número de TC, el título, el nivel de prueba (Sistema, Unitaria, Robustez, Aceptación, parciales de Fase 1) y los RF/RNF afectados con su descripción; la IA redactaba el archivo del caso y rellenaba la fila de la matriz siguiendo `.atl/skill_redactar_TC_XXX.md`.

---

## Prompt 1
```text
Muy bien, pasemos a la creacion de test-cases, siguiendo las reglas de ".atl\skill_redactar_TC_XXX.md" ayudame a realizar el siguiente test-case: TC-001 Enviar trabajo válido (Sistema) → RF-01: El sistema deberá aceptar el envío de un comando o programa con sus argumentos y devolver un identificador único de trabajo. RF-02: El sistema deberá validar la solicitud y rechazar entradas vacías, mal formadas o no autorizadas con un mensaje útil.
```

---

## Resultado 1

Se creó `verif/test-cases/TC-001.md` (nivel Sistema, RF-01 + RF-02) con objetivo, precondiciones, entorno Linux/GCC, datos de entrada, 7 pasos reproducibles y resultado esperado (códigos `0/1`, unicidad `N+1`, JSON intacto en rechazos), más fase de ejecución con placeholders sin resultados inventados. Se rellenaron las filas RF-01 y RF-02 de la matriz (Alta, Prueba, TC-001, `Pendiente`). El patrón quedó fijado para los siguientes: un archivo por TC más su(s) fila(s).

---

## Prompt 2
```text
ahora este: TC-002 Validar estructura de cola inicial (Unitaria) → RF-03 ... / ahora este: TC-003 Estados y tiempos (Sistema) → RF-06 ... RF-07 ... / entonces ya como quedo ese TC esta bien? / ahora el siguiente, TC-004 Consultar y listar (Sistema) → RF-08 ... RF-09 ... / ahora este: TC-005 Solicitar cancelación de proceso en ejecución (Sistema - Parcial Fase 1) → RF-10 ... / ahora este: TC-006 Capturar stdout/stderr separados y código de salida (Sistema - Parcial Fase 1) → RF-11 ... RF-07 ...
```

---

## Resultado 2

Se crearon en serie `TC-002.md` (Unitaria, RF-03, estructura inicial de 7 campos), `TC-003.md` (Sistema, RF-06 + RF-07, 5 estados y tiempos con `codigo_salida`), `TC-004.md` (Sistema, RF-08 + RF-09, consulta puntual y listados), `TC-005.md` (Sistema - Parcial Fase 1, RF-10 solo rama `RUNNING`) y `TC-006.md` (Sistema - Parcial Fase 1, RF-11 + código de salida, tiempos postergados), cada uno con su fila en la matriz (RF-03, RF-06 Crítica, RF-07 ampliada a `TC-003, TC-006`, RF-08, RF-09, RF-10 Crítica, RF-11). En TC-003 el desarrollador cuestionó (`estas seguro que no registra tiempos?`) y la verificación en código demostró que sí existían (`timestamp.h`, `tiempo_recepcion/inicio/terminacion`), por lo que se corrigieron `obtenerJobPorId` y `filtrarPorId` para cubrirlos en vez de tocar el caso.

---

## Prompt 3
```text
ahora este: TC-008 Aislamiento de fallos y comandos inválidos locales (Robustez - Parcial Fase 1) → RNF-08 ... RNF-09 ... / ahora este: TC-014 Construcción reproducible desde clon limpio (Aceptación - Fase 1) → RNF-01 ... RNF-02 ... RNF-03 ... / ahora este: TC-015 Usabilidad documental local (Aceptación - Fase 1) → RF-17 ... RNF-21 ... RNF-23 ...
```

---

## Resultado 3

Se crearon `TC-008.md` (Robustez - Parcial Fase 1, RNF-08 + RNF-09, servicio que sobrevive a inválidas y testigo de aislamiento), `TC-014.md` (Aceptación - Fase 1, RNF-01 + RNF-02 + RNF-03, clon fresco y operación sin root) y `TC-015.md` (Aceptación - Fase 1, RF-17 + RNF-21 + RNF-23, ayuda/códigos y guía sin asistencia), con sus filas en la matriz. TC-015 se retocó después al nacer `--help` (paso 1 explícito). Todas las filas quedaron en `Pendiente` con evidencia sugerida y defecto `-`, sin hashes ni PASS inventados.

---

# Modificaciones
**Estado de la resolución:** Aceptado tras verificación

**Revisión realizada:** Verificamos que cada TC respetara la plantilla obligatoria (fase de diseño completa, fase de ejecución solo con placeholders), que el nivel lo dictara el desarrollador y el método quedara solo en la matriz, y que cada fila tocara únicamente su requisito sin reescribir vecinas.

**Cambios aplicados:** Ninguno sobre lo propuesto salvo los dos ajustes pedidos en el camino (tiempos de TC-003 cubiertos en código, `--help` en TC-015). El desarrollador dirigió números, títulos, niveles y mapeos; la IA solo redactó y estructuró.

**Prueba agregada:** Ninguna en esta interacción (fase de diseño); la ejecución de los TC queda para WSL con `make clean && make` caso por caso.

---

## Implementación de feature

Se integró la batería inicial de 9 casos (`TC-001, TC-002, TC-003, TC-004, TC-005, TC-006, TC-008, TC-014, TC-015`) y 17 filas de matriz (RF-01, RF-02, RF-03, RF-06, RF-07, RF-08, RF-09, RF-10, RF-11, RF-17, RNF-01, RNF-02, RNF-03, RNF-08, RNF-09, RNF-21, RNF-23) como base de verificación del proyecto.

---

## Modificación de archivo

Nuevos `verif/test-cases/TC-00X.md` y ediciones por fila en `verif/verification-plan/traceability-matrix.md`; sin tocar código fuente.

---

# Implementación final

```text
verif/test-cases/TC-001.md, TC-002.md, TC-003.md, TC-004.md, TC-005.md, TC-006.md, TC-008.md, TC-014.md, TC-015.md
verif/verification-plan/traceability-matrix.md (17 filas con Caso(s) y Pendiente)
```

---

# Aprendizaje

Aprendimos que el flujo más rápido es que el humano dicte el qué (número, título, nivel, requisitos) y la IA sostenga el cómo (plantilla, reproducibilidad, matriz): la calidad del TC depende del mapeo que trae el mensaje, y la matriz solo es fiable si cada fila se edita quirúrgicamente sin tocar vecinas.
