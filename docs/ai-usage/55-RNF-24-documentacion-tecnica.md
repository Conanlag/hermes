# Uso de inteligencia artificial

# 55. RNF-24 — Documentación técnica y trazabilidad

## Objetivo

Documentar RNF-24 con el mismo rigor que RNF-14 y RNF-15: documento técnico en `docs/technical-guide/2-Nucleo del proyecto/`, fichas de TC-042 y TC-049 a TC-056, párrafo en `verif/test-cases/test-cases.md`, fila de la matriz de trazabilidad en `PASS` y este par de registros de uso de IA. Además, corregir los documentos anteriores que describían el framing antiguo como si siguiera vigente.

Esa segunda parte era la delicada. RNF-24 no solo agrega comportamiento: contradice frases escritas en requisitos ya cerrados. Documentar lo nuevo sin corregir lo viejo habría dejado el repositorio afirmando dos cosas opuestas sobre el mismo bucle.

---

## Prompt 1

```text
Ya está implementado y verificado. Documenta RNF-24 siguiendo la plantilla de
crear_doc_RF.md y crear_ai_usage.md: documento técnico, fichas de TC-042 y TC-049
a TC-056, actualización de test-cases.md y de la matriz de trazabilidad.

Antes de escribir, busca en todo docs/ las afirmaciones que contradigan el nuevo
framing —"un mensaje por conexión", "plazo absoluto", "el segundo mensaje se
descarta"— y corrígelas en RNF-08, RNF-14 y CONTEXTO-RED-ACTUAL.

Explica el porqué del plazo de inactividad, del cierre tras rechazo y del reintento
acotado del cliente. Declara los riesgos residuales sin maquillarlos.
```

---

## Resultado 1

El documento se estructuró como el de RNF-14: descripción, objetivo con las consideraciones actuales, estructura del módulo, modelo de la conexión, implementación del servidor, implementación del cliente, integración con otros requisitos, ejemplo de funcionamiento, verificación, riesgos residuales e historial.

Cuatro decisiones de contenido que valen la pena:

1. **El documento abre con «el eje es la frontera de la transacción».** RNF-24 se puede contar como una lista de arreglos —renovar un plazo, no cerrar, reutilizar un socket—, y así se lee como tres parches. Contarlo como un cambio de modelo —la conexión deja de ser la transacción— hace que los tres arreglos sean consecuencias.
2. **Se dedica una sección a lo que NO cambia.** `protocol.cpp` y `remote.cpp` no se tocaron, y eso es el resultado más importante del diseño: el validador nunca supo de conexiones. Si hubiera hecho falta modificarlo, la separación entre transporte y protocolo habría sido ficticia.
3. **El límite por mensaje se justifica con el contraejemplo numérico.** Veinte mensajes de 1 KiB superan 16 384 bytes en total sin que ninguno lo supere por separado. Sin esa frase, `fin > MAX_MENSAJE_RED` parece un detalle de estilo.
4. **Los riesgos residuales se declaran en cinco puntos, con el motivo técnico.** R1 (el plazo de inactividad sigue siendo un límite duro de tres segundos), R2 (un rechazo descarta lo encadenado detrás), R3 (el reintento cubre solo paginación de solo lectura), R4 (no hay multiplexación dentro de una conexión) y R5 (`bytes_recibidos` cuenta la transacción, no el tráfico).

La búsqueda de afirmaciones contradictorias encontró tres documentos afectados:

| Documento | Frase obsoleta | Corrección |
|---|---|---|
| `RNF-08.md:3-6` | «El servidor procesa un mensaje por conexión TCP… Después de responder cierra la conexión» | Se describe la secuencia de solicitudes por conexión y el cierre solo tras rechazo o inactividad |
| `RNF-08.md` (tabla) | «No se completa el mensaje en tres segundos desde la aceptación» | «…en tres segundos de inactividad (el plazo se reanuda con cada fragmento)» |
| `RNF-14.md:20` | «no cambia el framing: un mensaje por conexión» | Remite a RNF-24 como dueño del framing |
| `RNF-14.md:177` | «Bytes posteriores al primer `\n`: se descartan con la conexión» | Se conservan como la solicitud siguiente y se validan de forma independiente |
| `RNF-14.md` (TC-042) | «Solo responde `tc042-primero`; el segundo se descarta» | El válido responde, el inválido se rechaza con su código |
| `CONTEXTO-RED-ACTUAL.md` §1.2, §1.4, §3.1, §5.1, §5.2, §6.5 | «cierra la conexión», «una conexión = un mensaje», «plazo absoluto», «el segundo nunca se procesa» | Estado actual, con `server.cpp:288-403,443-450` como referencia |
| `CONTEXTO-RED-ACTUAL.md` §6.9 D16 | «Una conexión por operación, sin reutilización — coste, no defecto» | Resuelto en RNF-24 |

La distinción importante fue **qué se corrige y qué no**. `RNF-08` no se contradice: su requisito real es que una solicitud inválida no termine el servicio —lo fija `TC-008`—, y «un mensaje por conexión» era una descripción del diseño de entonces, no un criterio de aceptación. Se reescribió la descripción y se conservó el requisito. En cambio `RNF-14` sí necesitaba una nota de vigencia en el apartado del límite: la comprobación pasó de `entrada.size()` a `fin`, y la decisión que documenta —código único, registro en el rechazo, cierre del descriptor— sigue siendo válida.

---

## Prompt 2

```text
¿Falta algo?
```

---

## Resultado 2

La revisión encontró tres defectos en la documentación ya escrita, todos del mismo tipo: afirmaciones que no estaban respaldadas por una corrida.

1. **El recuento de regresión no cuadraba.** El borrador decía «veintiséis scripts en total incluyendo los nueve de RNF-24». El cálculo correcto es TC-030…TC-048 —diecinueve— más TC-049…TC-056 —ocho—: veintisiete. El error venía de contar TC-042 dos veces, como previo y como reescrito. Se corrigió el número y, sobre todo, se ejecutó la batería completa para que la cifra tuviera una salida detrás: TC-030 a TC-056, veintisiete `PASS`, con `make -B` limpio.
2. **Dos erratas en nombres técnicos.** `búster` por `búfer` y `MSGNOSIGNAL` por `MSG_NOSIGNAL`. La segunda importa: es el nombre real de una bandera de `send()`, y escribirlo mal en un documento que cita código invita a copiarlo mal.
3. **La ficha de TC-054 describía la aserción correcta, pero el script no.** El primer intento de `TC-054` buscaba `Cliente desconectado`; con el bucle nuevo, `detalle.procesada` sigue siendo verdadero y lo que corresponde es `Solicitud interrumpida` con `TIMEOUT_LECTURA` y `ACEPTADA`. Se corrigió el script, se regeneró la evidencia y la ficha se escribió desde esa corrida.

También se verificó que la fila de la matriz no declarara `PASS` sin evidencia: cita los nueve scripts, los nueve archivos de resultados, la fecha de la corrida, la regresión y los cinco riesgos residuales.

---

# Modificaciones

**Estado de la resolución:** **[Modificado]** — la estructura del documento era correcta desde el primer borrador, pero contenía dos erratas en nombres técnicos y un recuento de pruebas equivocado; la revisión lo detectó y se regeneró la evidencia antes de publicar.

**Revisión realizada:** se contrastó cada cifra y cada cita de código del documento contra el repositorio. Los rangos `server.cpp:288-403,443-450` y `client.cpp:167-195,197-220` se comprobaron con búsqueda de las lambdas y del chequeo de `MAX_RESPUESTA_RED`, no de memoria. Los fragmentos de salida de TC-049, TC-050, TC-051, TC-053, TC-054 y TC-056 se copiaron de `verif/results/`. El recuento de scripts se recalculó y se respaldó con una corrida completa, porque un número en la matriz es una afirmación verificable.

La revisión más útil no fue sobre el documento nuevo, sino sobre los viejos: buscar las frases del framing anterior en todo `docs/` encontró once afirmaciones repartidas en tres archivos. Ninguna de esas frases habría fallado una prueba; todas habrían confundido a quien leyera el requisito.

**Cambios aplicados:**

1. `docs/technical-guide/2-Nucleo del proyecto/RNF-24.mensajes-fragmentados-solicitudes-secuenciales.md` con las nueve secciones de la plantilla.
2. `verif/test-cases/TC-042.md` reescrita y `TC-049.md` a `TC-056.md` nuevas, con diseño y resultados empíricos.
3. `verif/test-cases/test-cases.md`: párrafo de RNF-24 con los ocho casos, y nota de la reescritura de TC-042.
4. `verif/verification-plan/traceability-matrix.md`: fila RNF-24 completa en `PASS` con evidencia y riesgos residuales.
5. `docs/technical-guide/2-Nucleo del proyecto/RNF-08.solicitudes-invalidas.md`: descripción del framing, tabla de tiempo muerto y sección de verificación automatizada.
6. `docs/technical-guide/2-Nucleo del proyecto/RNF-14.validacion-longitud-formato.md`: tres frases obsoletas y la fila de TC-042.
7. `docs/technical-guide/2-Nucleo del proyecto/CONTEXTO-RED-ACTUAL.md`: §1.2, §1.4, §3.1, §5.1, §5.2, §6.5, §6.9 D16 y §7.2.
8. `verif/scripts/TC-054.sh`: aserción alineada con RF-28 y salida sin acentos.
9. Corrección de `búster` → `búfer`, `MSGNOSIGNAL` → `MSG_NOSIGNAL` y del recuento de regresión.

**Prueba agregada:** ejecución completa de la batería de red —TC-030 a TC-056, veintisiete scripts— con compilación limpia `make -B -C src/hermes hermes`. Todos en `PASS`.

---

## Implementación de feature

La documentación de RNF-24 se apoya en tres ideas:

```text
1. La conexión deja de ser la transacción; el par mensaje-respuesta lo es.
2. El validador no cambió: transporte y protocolo son capas separadas de verdad.
3. Un requisito nuevo que contradice documentación previa obliga a corregir la
   documentación, no a convivir con dos verdades.
```

---

## Modificación de archivo

**`verif/verification-plan/traceability-matrix.md`** — la fila:

```markdown
| RNF-24 | El protocolo deberá funcionar con mensajes fragmentados y múltiples solicitudes secuenciales. | Alta | Prueba | TC-042, TC-049, TC-050, TC-051, TC-052, TC-053, TC-054, TC-055, TC-056 | verif/scripts/TC-042.sh + TC-049.sh…TC-056.sh + verif/results/results_TC-042.md y results_TC-049.md…results_TC-056.md ([PASS], 2026-11-22/23); regresión TC-030…TC-048 en PASS (27 scripts); compilación limpia con `-Wall -Wextra` | PASS | R1…R5 |
```

**`docs/technical-guide/2-Nucleo del proyecto/RNF-08.solicitudes-invalidas.md`** — la descripción corregida:

```markdown
El servidor procesa mensajes JSON terminados en salto de línea (`\n`) sobre una
conexión TCP. TCP puede fragmentar un mensaje; el servidor acumula sus bytes
hasta recibir el delimitador. Una misma conexión puede transportar varias
solicitudes secuenciales: cada mensaje completo se atiende en orden FIFO y la
conexión permanece abierta mientras el flujo esté sincronizado. Un rechazo de
protocolo responde con su código y cierra la conexión; una conexión inactiva más
de tres segundos se cierra con `REQUEST_TIMEOUT`.
```

**`docs/technical-guide/2-Nucleo del proyecto/RNF-14.validacion-longitud-formato.md`** — la nota de vigencia:

```markdown
**Bytes posteriores al primer `\n`:** cuando RNF-14 se implementó se descartaban con
la conexión, porque el protocolo era de un mensaje por conexión. **RNF-24 sustituyó
ese comportamiento**: los bytes posteriores al delimitador quedan en el búfer como
solicitud siguiente y se validan de forma independiente, con las mismas reglas de
este documento.
```

---

## Implementación final

```text
docs/technical-guide/2-Nucleo del proyecto/RNF-24.mensajes-fragmentados-solicitudes-secuenciales.md
docs/technical-guide/2-Nucleo del proyecto/RNF-08.solicitudes-invalidas.md        (corregido)
docs/technical-guide/2-Nucleo del proyecto/RNF-14.validacion-longitud-formato.md  (corregido)
docs/technical-guide/2-Nucleo del proyecto/CONTEXTO-RED-ACTUAL.md                 (actualizado)
verif/test-cases/TC-042.md
verif/test-cases/TC-049.md … TC-056.md
verif/scripts/TC-042.sh … TC-056.sh
verif/results/results_TC-042.md … results_TC-056.md
verif/test-cases/test-cases.md
verif/verification-plan/traceability-matrix.md
docs/ai-usage/54-RNF-24-mensajes-fragmentados.md
docs/ai-usage/55-RNF-24-documentacion-tecnica.md

$ bash verif/scripts/TC-030.sh … TC-056.sh
TC-030: PASS … TC-056: PASS
TOTAL: 0 fallos
```

---

# Aprendizaje

**Un requisito nuevo puede invalidar documentación, no solo código.** Las frases obsoletas no rompían nada: el código funcionaba y las pruebas pasaban. Pero un lector que abriera `RNF-08` habría diseñado un cliente de un mensaje por conexión, y habría descubierto el error en producción. Corregir la documentación es parte de entregar el requisito.

**Distinguir requisito de descripción es lo que evita borrar garantías.** `RNF-08` decía «un mensaje por conexión» y también «una solicitud inválida no termina el servicio». La primera era descripción; la segunda, criterio de aceptación. Se reescribió la primera y se conservó la segunda. Tratar ambas como requisito habría obligado a rechazar RNF-24; tratar ambas como descripción habría perdido `TC-008`.

**Un número en una matriz es una afirmación.** «Veintiséis scripts» parecía inocente hasta que se contó. La respuesta correcta no fue cambiar el número, sino ejecutar la batería para que el número tuviera una salida detrás. Un `PASS` sin comando es una opinión.

**Sobre Prompt Engineering.** El prompt pidió explícitamente buscar las afirmaciones contradictorias antes de escribir. Esa instrucción convirtió una tarea de redacción en una auditoría de consistencia, y fue lo que encontró los tres documentos afectados. Cuando el cambio contradice decisiones previas, pedir «qué documentos quedan mintiendo» vale más que pedir «documenta lo nuevo».
