# Uso de inteligencia artificial

# 51. Documentación técnica final de RNF-14 en la guía del núcleo

## Objetivo

Producir la documentación de entrega de RNF-14 —validación de longitud y formato de todos los mensajes de red— para `docs/technical-guide/2-Nucleo del proyecto/`, siguiendo la plantilla de `.atl/crear_doc_RF.md`.

Este registro cubre **solo la redacción del documento**. La auditoría, el diseño, la implementación y la corrección del cliente están en el registro 50. RNF-14 es un requisito transversal, y eso cambia el problema de documentación: no hay un módulo que describir de arriba abajo, sino seis archivos que responden al mismo invariante desde lugares distintos.

---

## Prompt 1

```text
si
```

La autorización del plan incluía explícitamente: "Al terminar la verificación, y solo si sale verde, escribo el documento RNF-14 y su registro ai-usage, como en RF-28."

---

## Resultado 1

La IA extrajo primero las referencias del código, no del recuerdo: `network_protocol.h:5-8` (las cuatro constantes), `protocol.cpp:33-55` (los rechazos previos al parser), `protocol.cpp:67-79` (`rechazoConId` y el límite de `operation`), `server.cpp:119-140` (tabla de la ventana), `server.cpp:222-236` (`registrarRechazo`), `server.cpp:244` (retorno temprano), `server.cpp:292-311` (framing), `client.cpp:123-129` y `client.cpp:179-216` (validación de petición y respuesta), `validator.cpp:498-543` (`utf8Valido`) y `validator.cpp:545-565` (`validarTextoRed`).

Estructuró el documento alrededor de un eje distinto al de RF-28. En RF-28 la tesis era "la coherencia ya existía, faltaba observarla". Aquí la tesis es la asimetría deliberada: el servidor valida bytes crudos antes de parsear, el cliente valida el sobre ya parseado. Sin explicitar esa asimetría, el documento se lee como una lista de comprobaciones sin criterio.

Tres decisiones de contenido:

1. **Tabla de códigos con la columna `request_id`.** Es el detalle que conecta RNF-14 con el bug del cliente. Una tabla sin esa columna describiría los rechazos pero no explicaría por qué el cliente no podía leerlos.
2. **La línea literal de `events.jsonl` copiada de la corrida real de TC-039**, con `bytes_recibidos: 69` y `motivo: CIERRE_NORMAL`, en lugar de un ejemplo redactado. Incluye la explicación de que `CIERRE_NORMAL` es el valor real en ese instante y no un hueco.
3. **Riesgo R3 formulado como contrapartida del diseño**, no como defecto: la ventana de 60 s por código impide contar intentos exactos, y la salida correcta sería un registro agregado, no quitar la ventana.

Al contrastar el borrador con el código apareció una inexactitud que valía la pena corregir antes de publicar. La primera versión de la tabla afirmaba que **todos** los rechazos responden con `request_id: null`. Es falso: `rechazoConId()` conserva el identificador del cliente para `INVALID_VERSION`, `UNSUPPORTED_VERSION`, `INVALID_OPERATION`, `INVALID_PARAMS` y `UNKNOWN_OPERATION`. La versión final distingue las dos familias y matiza el caso de `INVALID_REQUEST_ID`, que responde `null` cuando el identificador no se pudo leer y lo conserva cuando se leyó pero no superó la validación de formato.

---

## Prompt 2

```text
haz el ai-usage de la documentacion del RNF-14
```

---

## Resultado 2

La IA generó este registro siguiendo `.atl/crear_ai_usage.md`. Se mantiene la separación por fase de la serie: el registro 50 documenta auditoría, diseño, implementación y la corrección encontrada por TC-041; el 51 documenta únicamente la redacción.

---

# Modificaciones

**Estado de la resolución:** **[Modificado]** — el documento generado describía correctamente el comportamiento, pero afirmaba una regla uniforme sobre `request_id` que el código no cumple.

**Revisión realizada:** cada afirmación del documento se cotejó contra el archivo que citaba: números de línea, nombres de constantes, códigos de error, orden de las comprobaciones y texto exacto de los mensajes del cliente. Las líneas de bitácora se tomaron de la salida real de TC-039. La tabla de verificación se contrastó con `verif/results/`.

El error corregido es de un tipo distinto al de RF-28. Allí la IA inventó un esquema de archivo completo; aquí generalizó una regla a partir de un caso verdadero. `errorProtocolo()` sí emite `request_id: null`, y de ahí era tentador concluir que todo rechazo lo hace. La realidad tiene dos caminos: el mensaje crudo y el sobre ilegible usan `null`; el sobre legible pero inválido conserva el identificador. Una regla general falsa es más difícil de detectar que una constante falsa, porque suena a descripción de diseño y nadie la contrasta con una línea concreta.

**Cambios aplicados:**

- `docs/technical-guide/2-Nucleo del proyecto/RNF-14.validacion-longitud-formato.md`: documento nuevo con las secciones de la plantilla.
- Tabla de códigos: columna `request_id` con las dos familias (`null` antes de leer el identificador, eco del identificador después) y matiz para `INVALID_REQUEST_ID`.
- Ejemplo de bitácora: línea real de TC-039, con la aclaración de que `motivo: CIERRE_NORMAL` es el valor del instante del rechazo.
- Se documentó la decisión de responder `null` cuando el sobre trae un identificador válido más una clave desconocida, porque la comprobación de claves precede a la confianza en el identificador.
- Se documentó la frontera con RF-28: los rechazos de negocio (`UNAUTHORIZED`, `NOT_FOUND`, `RESPONSE_TOO_LARGE`) no marcan `formatoInvalido` y conservan el evento `Solicitud interrumpida`.
- `verif/test-cases/TC-039.md`…`TC-042.md` y `verif/test-cases/test-cases.md`: fichas de los cuatro casos y su párrafo de conjunto.
- `verif/verification-plan/traceability-matrix.md`: fila RNF-14 con evidencia y riesgo R3.

**Prueba agregada:** no se añadieron pruebas en esta fase. La evidencia citada proviene de las cuatro ejecuciones de TC-039…TC-042 y de la regresión de trece scripts, todas realizadas antes de redactar. La revisión de la tabla se hizo leyendo `protocol.cpp:33-79` completo para confirmar qué lambda responde cada código.

---

## Implementación de feature

El documento se ordena para responder tres preguntas: **qué defectos no se distinguían**, **cómo se separan ahora** y **cómo se demuestra**.

| Sección | Función dentro del documento |
|---|---|
| Descripción | Plantea el requisito como propiedad transversal y explica por qué sus dos mitades se necesitan |
| Objetivo | Cita el requisito y delimita alcance con lo que hace, lo que no hace y lo que no cambia |
| Estructura del módulo | Los seis archivos y su responsabilidad dentro del invariante |
| Definición de los códigos | Tabla de doce códigos con disparador y `request_id` de la respuesta |
| Implementación de `.h` | Constantes únicas y por qué no un enum |
| Implementación de `.cpp` | Orden del rechazo, framing, registro, cliente y texto seguro |
| Integración | Frontera con RF-28, RF-22, RF-14 y RF-23/RF-25 |
| Ejemplo | Un rechazo por defecto, línea real de bitácora y mensajes del cliente |
| Verificación | Cuatro casos, regresión y compilación |
| Riesgo residual | R3: la ventana oculta repeticiones del mismo código |

El eje está en la sección de `protocol.cpp`: el orden tamaño → NUL → UTF-8 → parseo es lo que hace que cada defecto conserve su identidad. Un `find('\0')` colocado después del parser nunca se ejecutaría, porque el parser ya habría fallado.

---

## Modificación de archivo

### La tabla que el borrador generalizaba de más

```text
| Código              | Disparador                                  | request_id        |
| MESSAGE_TOO_LARGE   | Mensaje o línea mayor que MAX_MENSAJE_RED   | null              |
| NUL_BYTE            | Byte 0x00 en cualquier posición             | null              |
| INVALID_UTF8        | Secuencia UTF-8 inválida                    | null              |
| TOO_DEEP            | Anidamiento mayor que 32                    | null              |
| INVALID_JSON        | JSON no parseable                           | null              |
| INVALID_REQUEST     | Raíz no objeto o clave superior desconocida | null              |
| INVALID_REQUEST_ID  | Ausente, no string o fuera de charset       | null si no se leyó|
| INVALID_VERSION     | Ausente o distinta de 1                     | el del cliente    |
| INVALID_OPERATION   | Ausente, no string, vacía o > 32 bytes      | el del cliente    |
| INVALID_PARAMS      | Ausente, no objeto, o no vacío en ping      | el del cliente    |
| UNKNOWN_OPERATION   | Operación no despachable                    | el del cliente    |
| RESPONSE_TOO_LARGE  | Respuesta serializada > MAX_RESPUESTA_RED   | el del cliente    |
```

### La línea real que sustituyó al ejemplo redactado

```json
{"context": {"bytes_recibidos": 69, "codigo": "UNKNOWN_OPERATION", "identidad": "tcp-PC-B",
"ip": "127.0.0.1", "motivo": "CIERRE_NORMAL"}, "job_id": null, "level": "WARN",
"message": "Mensaje rechazado", "ts": "2026-11-19 21:20:20"}
```

---

# Implementación final

```text
# RNF-14 — Validación de longitud y formato de todos los mensajes de red

## Descripción
RNF-14 es un requisito transversal: no describe una operación, sino una propiedad que deben
cumplir todos los mensajes que cruzan el socket, en ambas direcciones. [...]

## Verificación
| TC-039 | Diez formatos inválidos + repetición de uno | Los diez códigos propios; 10 eventos
para 10 códigos; ningún duplicado como Solicitud interrumpida |
| TC-040 | Cliente contra tres sobres con request_id: null | Los tres códigos reportados; sin
json.exception |
| TC-041 | Cliente contra siete respuestas mal formadas | Las siete rechazadas con diagnóstico
propio |
| TC-042 | Dos sobres en un solo write | Solo responde el primero; jobs.json con 1 Job |
```

Y cierra con el riesgo que el propio diseño introduce: la ventana por código protege el disco de un flood de mensajes malformados al precio de no poder contar intentos exactos desde la bitácora.

---

# Aprendizaje

**Generalizar un caso verdadero produce errores más silenciosos que inventar un dato.** En RF-28 la IA inventó el contenido de `jobs.json`; el error era evidente al abrir el archivo. Aquí afirmó que todos los rechazos responden `request_id: null` porque `errorProtocolo()` lo hace. La regla sonaba a diseño y era falsa para cinco códigos. Cuando una afirmación empieza con "todos", hay que buscar la excepción en el código antes de escribirla.

**La documentación de un requisito transversal se ordena por invariante, no por archivo.** Recorrer los seis archivos uno tras otro habría producido un inventario ilegible. El documento sigue el orden en que un mensaje es validado, y los archivos aparecen donde intervienen.

**La tabla de códigos terminó siendo la sección más útil.** No describe el código: describe qué puede afirmarse del cliente en cada rechazo, que es justo la información que faltaba cuando el cliente no podía leer los errores.

**Sobre Prompt Engineering.** El prompt de esta fase fue de una línea porque el contexto ya existía y la autorización nombraba el entregable. Aun así, la instrucción relevante no estaba en ese prompt sino en el plan aprobado: "solo si sale verde". Documentar antes de que la verificación cierre es cómo se escriben documentos que describen lo que el sistema hace en lugar de lo que se pretendía que hiciera.
