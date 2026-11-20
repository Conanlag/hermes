# Uso de inteligencia artificial

# 49. Documentación técnica final de RF-28 en la guía del núcleo

## Objetivo

Producir la documentación de entrega de RF-28 —estado coherente y desenlace documentado ante desconexión del cliente— para `docs/technical-guide/2-Nucleo del proyecto/`, siguiendo estrictamente la plantilla de `.atl/crear_doc_RF.md`.

Este registro cubre **solo la redacción del documento**. La auditoría, el diseño y la implementación están en el registro 48; separar ambos permite auditar por separado lo que se decidió en código y lo que se afirmó por escrito sobre ese código, que es donde aparecen las inexactitudes.

A diferencia de RF-22, aquí no había un documento de trabajo previo que reescribir: el requisito se implementó y se documentó en la misma sesión. Eso reduce el riesgo de contradicción con el código, pero también elimina la distancia que normalmente obliga a releer lo implementado antes de escribirlo.

---

## Prompt 1

```text
si autorizo, comienza solo con la implementacion y despues cuando sea correcta realizas Documento final de RF-28 y registro ai-usage
```

---

## Resultado 1

La IA leyó la plantilla `.atl/crear_doc_RF.md` completa, la lista de secciones del documento final de RF-22 para igualar el registro de la guía y, antes de escribir una sola línea, extrajo del código real las referencias que pensaba citar: la declaración de `DetalleSolicitud` en `network_protocol.h`, los ocho puntos de salida de `procesarSolicitudRedDetallada` en `protocol.cpp` (líneas 16, 27, 32, 37, 44, 61, 75) y los puntos del bucle de `server.cpp` (`Cliente.detalle` en la 163, `registrar()` en la 200, las banderas de cierre en 237-238, la ruta de `MESSAGE_TOO_LARGE` en 249-253).

Produjo un documento con las secciones de la plantilla y tres decisiones de contenido:

1. **Explicar el orden de operaciones antes que el código.** La sección de descripción abre afirmando que la coherencia ya existía y que el RF pedía hacerla observable. Sin esa tesis, el lector buscaría una reparación de estado que nunca ocurrió y leería el cambio como un simple añadido de logging.
2. **Tabla de tres estados en lugar de un `enum`.** `DetalleSolicitud` usa dos booleanos; documentarlo como máquina de estados con nombre (`SIN_EFECTO`, `ACEPTADA`, `RECHAZADA`) es lo que hace legible la política de registro.
3. **Los cuatro escenarios cierran con la línea literal de `events.jsonl`** copiada de las ejecuciones reales de TC-035 a TC-038, no con ejemplos redactados.

Al revisar el borrador contra la realidad antes de entregarlo, aparecieron **cuatro inexactitudes**, todas corregidas:

| Afirmación del borrador | Valor real verificado |
|---|---|
| `jobs.json` contiene `"pid": 0` y `"propietario_remoto": "red-tcp-PC-B-tc035-corte"` | El Job terminado tiene `pid` real (11210) y `propietario_remoto: "tcp-PC-B"`; el `request_id` es el campo que vale `red-tcp-PC-B-tc035-corte`. Además faltaban seis campos del esquema real |
| "La ruta de `MESSAGE_TOO_LARGE` (línea 250-254)" | El bloque ocupa 249-253 |
| "TC-033 se reescribió para medir la ventana con conexiones que no envían bytes" sin más contexto | El `.md` del caso también había cambiado de puerto (`45843`) y su ficha necesitaba la nota de alcance tras RF-28 |
| "TC-038 repetido tres veces" | Se había ejecutado dos veces |

La última se resolvió de la forma menos cómoda y más correcta: **se ejecutó TC-038 dos veces más** para que la afirmación fuera verdadera, en lugar de rebajar el texto a "dos veces". Una cifra de repeticiones es evidencia, y la evidencia se produce o no se escribe.

La primera se resolvió capturando un `jobs.json` real: se lanzó el servidor con `HOME` temporal en el puerto `45899`, se envió el `submit` con `RST` inmediato, se esperó el estado terminal y se volcó el archivo. El esquema real incluye `boot_id`, `cancel_requested`, `codigo_salida`, `pid_inicio`, `sid`, `tipo_ejecucion` y marcas de tiempo que el borrador había omitido por completo.

---

## Prompt 2

```text
haz el ai-usage de la documentacion del RF-28
```

---

## Resultado 2

La IA generó este registro siguiendo `.atl/crear_ai_usage.md`, con la plantilla completa y la clasificación explícita en la sección de modificaciones. Se mantuvo la separación por fase que ya usa la serie: el registro 48 documenta auditoría, diseño e implementación; el 49 documenta únicamente la redacción del documento final.

---

# Modificaciones

**Estado de la resolución:** **[Modificado]** — el documento no era correcto tal como se generó; requirió verificación contra el binario en ejecución y contra las cifras observadas antes de publicarse.

**Revisión realizada:** Se comprobó cada referencia del documento contra el archivo que citaba: números de línea, nombres de campos, códigos de error y sobre JSON. Las líneas de bitácora se contrastaron con la salida real de los cuatro scripts de RF-28, y la estructura se contrastó con los documentos RF ya presentes en la guía para mantener el mismo registro impersonal y el mismo formato de tablas.

El hallazgo relevante es el mismo patrón que ya apareció al documentar RF-22, con una variante nueva: **la IA no inventó un valor aislado, inventó un esquema completo**. Escribió un `jobs.json` plausible —con `pid: 0` porque recordaba que `remote.cpp` responde `pid: 0` al cliente— y colocó en `propietario_remoto` la cadena que en realidad pertenece a `request_id`. Ninguno de los dos errores habría roto una prueba: `jobs.json` no se valida contra el documento. La consecuencia habría sido un ejemplo que nadie puede reproducir y que, peor, sugiere que el `pid` del Job aceptado es cero cuando el Job ya se ejecutó.

La segunda corrección, la del número de repeticiones de TC-038, es metodológica. Es tentador suavizar el texto cuando la cifra no cuadra; hacerlo convierte la sección de verificación en una narración. Se ejecutaron las dos corridas que faltaban y el documento pasó a citar cuatro.

La revisión humana confirmó el resto: la cita del requisito, la tabla de estados, el orden lectura-clasificación explicado como corrección de un defecto real, la delimitación de la ventana de 60 s y la clasificación del riesgo residual R2.

**Cambios aplicados:**

- `docs/technical-guide/2-Nucleo del proyecto/RF-28.estado-coherente-desconexion.md`: documento nuevo con las secciones de la plantilla, cuatro escenarios y tabla de verificación.
- Escenario 1: el ejemplo de `jobs.json` se sustituyó por el esquema real capturado, con `propietario_remoto: "tcp-PC-B"`, `request_id: "red-tcp-PC-B-tc035-corte"` y los campos del Job terminado.
- Escenario 1: se añadió la aclaración de que `pid` y las marcas de tiempo varían en cada ejecución, para que el ejemplo no se lea como un valor fijo.
- Implementación de `.cpp`: la referencia de línea de `MESSAGE_TOO_LARGE` pasó de 250-254 a 249-253.
- Verificación: "TC-038 repetido tres veces" pasó a cuatro, tras ejecutarlo dos veces más.
- `verif/test-cases/TC-038.md`: la misma corrección de cifra, con las dos corridas adicionales registradas en `verif/results/results_TC-038.md`.
- `verif/test-cases/TC-033.md`: ficha actualizada con el puerto `45843`, el escenario de conexiones sin bytes y una nota de alcance explicando qué cambió con RF-28.

**Prueba agregada:**

- **Captura de esquema**: servidor con `HOME` temporal en `45899`, `submit` de `true` con `RST` inmediato, espera de estado terminal y volcado de `jobs.json`. Ocho campos reales que el borrador no tenía.
- **Repetición de TC-038**: dos corridas adicionales, ambas `20 de 20` registros, para sostener la cifra que el documento afirma.
- **Verificación de referencias**: `grep` sobre `protocol.cpp` y `server.cpp` para cada línea citada; lectura del bloque 244-262 de `server.cpp` para confirmar la ruta de `MESSAGE_TOO_LARGE`.
- **Trazabilidad**: la tabla de verificación cita los cuatro casos con el resultado observado de cada uno (`job_id: 1`, `sha256` idéntico, `3` registros `SIN_EFECTO`, `20 de 20`), tomados de `verif/results/results_TC-035.md`…`results_TC-038.md`.

---

## Implementación de feature

El documento se ordena para responder tres preguntas: **qué hueco dejó RF-22**, **cómo se propaga ahora el desenlace** y **cómo se demuestra**.

| Sección | Función dentro del documento |
|---|---|
| Descripción | Separa coherencia de observabilidad: el estado nunca estuvo en riesgo, lo que faltaba era el rastro |
| Objetivo | Cita el requisito y delimita alcance con **lo que hace**, **lo que no hace** y **lo que no cambia** |
| Estructura del módulo | Los tres archivos tocados y su responsabilidad en el contrato |
| Definición de los estados | Tabla `procesada`/`aceptada` → `SIN_EFECTO`/`ACEPTADA`/`RECHAZADA`, más el `enum Motivo` reutilizado |
| Implementación de `.h` | `DetalleSolicitud` y por qué la sobrecarga conserva la firma pública |
| Implementación de `.cpp` | `protocol.cpp` por punto de salida y `server.cpp` por orden de operaciones |
| Integración | Qué se conecta con `event_log`, `storage` y `scheduler`, y qué no se tocó |
| Ejemplo de funcionamiento | Cuatro escenarios con la línea literal de bitácora |
| Verificación | Cuatro casos nuevos, la regresión y el motivo del cambio en TC-033 |
| Riesgo residual | R2: el `fsync` de una solicitud iniciada, sin ventana |

El eje del documento es la sección de `.cpp` del servidor, porque ahí está el defecto que la implementación descubrió: clasificar `POLLERR` antes de leer descartaba solicitudes completas de forma no determinista. Ese párrafo es también el que justifica por qué TC-035 pasó y TC-036 falló con el mismo código.

---

## Modificación de archivo

### `docs/technical-guide/2-Nucleo del proyecto/RF-28.estado-coherente-desconexion.md` — esquema corregido

```json
[{"argumentos":[],"cancel_requested":false,"codigo_salida":0,"job_id":1,"pid":11210,
  "programa":"true","propietario_remoto":"tcp-PC-B","request_id":"red-tcp-PC-B-tc035-corte",
  "status":"SUCCEEDED","tiempo_recepcion":"2026-11-19 20:47:02",
  "tiempo_terminacion":"2026-11-19 20:47:02","tipo_ejecucion":"remote"}]
```

### Los tres desenlaces, con la línea real de bitácora

```json
{"context":{"bytes_recibidos":117,"identidad":"tcp-PC-B","ip":"127.0.0.1","job_id":1,
"motivo":"ERROR_SOCKET","operacion":"submit","request_id":"tc035-corte","resultado":"ACEPTADA"},
"job_id":null,"level":"WARN","message":"Solicitud interrumpida","ts":"2026-11-19 20:41:15"}
```

```json
{"context":{"bytes_recibidos":94,"error":"NOT_CANCELABLE","identidad":"tcp-PC-B",
"ip":"127.0.0.1","job_id":1,"motivo":"ERROR_SOCKET","operacion":"cancel",
"request_id":"tc036-rechazo","resultado":"RECHAZADA"},"job_id":null,"level":"WARN",
"message":"Solicitud interrumpida","ts":"2026-11-19 20:41:16"}
```

```json
{"context":{"bytes_recibidos":61,"identidad":"tcp-PC-B","ip":"127.0.0.1",
"motivo":"FIN_SIN_MENSAJE","resultado":"SIN_EFECTO"},"job_id":null,"level":"WARN",
"message":"Solicitud interrumpida","ts":"2026-11-19 20:41:48"}
```

---

# Implementación final

```text
# RF-28 — Estado coherente y desenlace documentado ante desconexión del cliente

## Descripción
RF-22 garantizó que una desconexión no derriba el servicio ni corrompe jobs.json.
RF-28 cubre el hueco que quedaba abierto: saber qué ocurrió con la operación que el
cliente ya había enviado. [...]
```

La tabla que se consulta en la práctica es la de desenlaces, porque responde "¿qué significa esta entrada?" sin abrir el código:

```text
| procesada | aceptada | Desenlace | Significado                          | Registro |
| false     | —        | SIN_EFECTO| El mensaje no llegó a interpretarse  | Solicitud interrumpida |
| true      | true     | ACEPTADA  | El efecto quedó persistido           | Solicitud interrumpida |
| true      | false    | RECHAZADA | Se evaluó y se negó; nada cambió     | Solicitud interrumpida |
```

Y el documento cierra con el riesgo que la propia decisión de diseño introduce: documentar toda solicitud iniciada cuesta un `fsync` por conexión y no tiene ventana, acotado únicamente por el cupo de 32 conexiones y el plazo de lectura de 3 s.

---

# Aprendizaje

**Un esquema inventado es más peligroso que un valor inventado.** En RF-22 los errores fueron constantes y firmas sueltas; aquí la IA produjo un `jobs.json` completo, coherente y falso. Un campo equivocado se detecta al compararlo con el archivo; un esquema equivocado se lee como una descripción razonable del sistema y nadie lo compara con nada. La regla que queda es más estricta que "no cites de memoria": **si el documento muestra el contenido de un archivo, ese contenido se captura del archivo**, con el mismo comando que el lector usaría para reproducirlo.

**La sección de verificación es evidencia, no narración.** La cifra "tres veces" era cómoda y falsa. Rebajarla a "dos" habría arreglado la exactitud destruyendo el propósito; ejecutar las dos corridas que faltaban arregló ambas cosas. En documentación de pruebas, la salida correcta ante un número que no cuadra nunca es suavizar el texto.

**La documentación fuerza el orden de la suite.** Escribir el documento expuso que TC-033 medía otra cosa después de RF-28 y que dos scripts chocaban con un servidor activo del usuario. Ninguno de los dos problemas rompía la implementación, pero ambos habrían hecho que la evidencia citada no fuera reproducible por un tercero. Documentar antes de cerrar el requisito es lo que convierte la suite en algo que otra persona puede correr.

**Sobre Prompt Engineering.** El prompt de esta fase fue una sola frase porque el contexto ya existía: la implementación estaba hecha y verificada en la misma sesión. Ese es el escenario más favorable y también el más engañoso, porque la cercanía con el código invita a escribir de memoria en lugar de mirar. La disciplina que funcionó fue invertir el orden: primero extraer las referencias del código, después redactar alrededor de ellas.
