# Uso de inteligencia artificial

# 47. Documentación técnica final de RF-22 en la guía del núcleo

## Objetivo

Producir la documentación técnica definitiva de RF-22 —desconexión del cliente sin afectar al servicio— para `docs/technical-guide/2-Nucleo del proyecto/`. El material existente hasta ese momento era un documento de trabajo con auditoría, matriz de cumplimiento, comparativa de alternativas, riesgos y una lista de tareas `T-00`…`T-15`. Ese formato sirve para ejecutar un cambio, pero no como documentación de entrega: mezcla el proceso de decisión con la descripción del requisito.

Se buscaba un documento que siguiera estrictamente la plantilla de `.atl/crear_doc_RF.md` y que fuera consistente con los cuarenta y pico documentos RF/RNF ya presentes en la guía: descripción, objetivo con consideraciones de alcance, estructura del módulo, definición de estados, implementación de `.h` y `.cpp` por fragmentos, integración con otros módulos, ejemplos de funcionamiento y trazabilidad hacia las pruebas.

---

## Prompt 1
```text
utilizando el skill ".atl\crear_doc_RF.md" redacta la documentacion final del RF-22 (cambie el nombre del .md anterior a "docs\technical-guide\2-Nucleo del proyecto\DESARROLLO-RF-22.desconexion-cliente.md" porque no me sirve de documentacion final)
```

---

## Resultado 1

La IA leyó la plantilla, tres documentos de referencia del mismo directorio para igualar registro y estructura (`RF-29.terminacion-inesperada.md`, `RF-18.operaciones-remotas.md`, `RF-20.restriccion-redes-direcciones.md`), y el código real de `server.cpp`, `remote.cpp` y `protocol.cpp` antes de escribir.

Produjo un documento de ~500 líneas con diez secciones: descripción en tres párrafos que explica por qué el modelo de un solo hilo convierte la conexión de un cliente en un riesgo de servicio; objetivo con cita del requisito y listas explícitas de **lo que hace** y **lo que no hace**; árbol del módulo con tabla de responsabilidades; `enum class Motivo` completo con tabla de los diez valores; sección de `.h` que declara que no se modificó ningún encabezado y documenta los contratos consumidos; ocho subsecciones de `.cpp` con el código final; integración con `event_log`, `scheduler`, `client` y `storage`; ocho requisitos relacionados; cinco escenarios de funcionamiento; y verificación con los cinco casos de prueba.

Al revisar el borrador contra el código antes de entregarlo, la IA detectó y corrigió por su cuenta **cuatro inexactitudes**:

| Afirmación del borrador | Valor real verificado |
|---|---|
| `MAX_MENSAJE_RED = 65536` | `16384` en `network_protocol.h:5` |
| `log_event_system` devuelve `void` | devuelve `bool` |
| Un `RST` produce `motivo: ERROR_LECTURA` | produce `ERROR_SOCKET`, porque `POLLERR` se evalúa antes que `recv()` |
| El sobre de `log_event_system` no incluye `job_id` | incluye `"job_id": null` |

Las dos últimas se descubrieron ejecutando pruebas de sondeo contra el servidor real con `HOME` temporal, no leyendo el código: se provocó un corte con `SO_LINGER{1,0}`, un cierre ordenado con `shutdown(SHUT_WR)`, un cliente que nunca completa el mensaje y una conexión desde un origen no autorizado, y se volcó `events.jsonl` en cada caso. Con eso se fijaron también los recuentos exactos de bytes recibidos (76, 33, 1) para que las líneas de bitácora del documento fueran copiables en lugar de ilustrativas.

Por último ajustó las referencias cruzadas: `traceability-matrix.md:27` pasó a apuntar al documento final para el requisito y al documento de desarrollo para la matriz AC1–AC7, y la tabla de tareas del documento de desarrollo corrigió su auto-referencia a `T-00`.

---

# Modificaciones

**Estado de la resolución:** **[Modificado]** — el borrador no era correcto tal como se generó; requirió verificación contra fuente y contra el binario en ejecución antes de publicarse.

**Revisión realizada:** La plantilla se respetó sección por sección, y se comprobó que el documento fuera coherente con los otros RF de la guía: mismo registro impersonal, mismos bloques de código con lenguaje declarado, misma tabla de responsabilidades por archivo. La estructura del módulo se contrastó con el árbol real y la sección de estados se contrastó con el `enum` de `server.cpp`.

El hallazgo importante de la revisión es de método, no de contenido: **la IA escribió de memoria tres valores técnicos y los tres estaban mal**. `MAX_MENSAJE_RED` se asumió como el tamaño típico de un buffer de red, no como el valor que el proyecto realmente define. La firma de `log_event_system` se reconstruyó por analogía con `log_event` en lugar de abrir el encabezado. Y el motivo de cierre por `RST` se dedujo del nombre del evento (`POLLHUP`) en lugar de razonar que un `RST` llega como `POLLERR` y que `POLLERR` se evalúa primero en el bucle.

El error del `RST` merece registro aparte porque es contraintuitivo incluso después de leer el código: el servidor había recibido 76 bytes del mensaje parcial, y aun así el evento registra `ERROR_SOCKET` y no `ERROR_LECTURA`, porque el `POLLERR` del descriptor gana antes de que se intente cualquier `recv()`. Un documento que hubiera afirmado lo contrario no habría fallado ningún test —ninguno de los cinco casos de RF-22 verifica el texto del motivo en ese escenario— y habría quedado como una inexactitud silenciosa en la guía del núcleo.

La revisión humana confirmó que el resto se sostiene: la cita del requisito, las listas de alcance, la explicación de que el cierre normal no genera evento mientras los eventos de Job sí existen, y la clasificación del riesgo residual R1.

**Cambios aplicados:**

- `docs/technical-guide/2-Nucleo del proyecto/RF-22.desconexion-cliente.md`: documento nuevo de ~500 líneas con las diez secciones de la plantilla, cinco escenarios y tabla de verificación.
- Documento: la constante citada pasó de `65536` a `16384` y el tipo declarado de `std::size_t` a `unsigned`, que es el que realmente usa `network_protocol.h:5`. El encabezado no se modificó: la corrección fue del texto que lo citaba.
- `event_log.h`: las dos firmas citadas pasaron de `static void` a `static bool` y se alinearon los nombres de parámetros con los reales (`job_id`, `level`, `message`, `extra`).
- Escenario 2: motivo corregido de `ERROR_LECTURA` a `ERROR_SOCKET`, recuento de bytes ajustado al valor observado (`76`) y párrafo nuevo que explica por qué gana `POLLERR`.
- Escenario 3: recuento de bytes ajustado al valor observado (`33`).
- Escenarios 2, 3, 4 y 5: se añadió `"job_id":null` al sobre de cada evento y se sustituyeron las horas de ejemplo por las observadas.
- Escenario 5: el ejemplo de terminal pasó de `nc -vz` a una conexión en Python, porque el `ECONNRESET` del texto era el observado con Python y no el que produce `nc`.
- Escenario 1: se precisó que el cierre normal no genera *entrada de desconexión*, porque la afirmación anterior —"no genera ninguna entrada en `events.jsonl`"— era falsa: los eventos del ciclo de vida del Job sí se escriben.
- `verif/verification-plan/traceability-matrix.md:27`: la evidencia ahora referencia el documento final para el requisito y `DESARROLLO-RF-22.desconexion-cliente.md` para la matriz AC1–AC7.
- `DESARROLLO-RF-22.desconexion-cliente.md`: la fila `T-00` dejó de apuntar al nombre anterior del archivo.

**Prueba agregada:**

- **Sondeo 1** (`HOME` temporal, `network.json` con `127.0.0.1` autorizado): mensaje parcial + `RST` → `{"motivo":"ERROR_SOCKET","bytes_recibidos":76}`; mensaje parcial + `FIN` → `{"motivo":"FIN_SIN_MENSAJE","bytes_recibidos":30}`; servidor vivo en ambos casos.
- **Sondeo 2**: cliente que envía `{"version":1,"request_id":"lento"` y no cierra → a los ~3 s recibe `{"error":"REQUEST_TIMEOUT","ok":false,"request_id":null,"version":1}` y la bitácora registra `TIMEOUT_LECTURA` con 33 bytes.
- **Sondeo 3** (`redes_permitidas: ["10.0.0.0/8"]`): conexión desde `127.0.0.1` → `ECONNRESET` en el cliente y `{"motivo":"ORIGEN_RECHAZADO"}` en bitácora.
- **Verificación de fuente**: `MAX_MENSAJE_RED = 16384` en `network_protocol.h:5`; `static bool log_event_system(...)` en `event_log.h:26`; `CXXFLAGS = -Wall -Wextra -std=c++17` en `src/hermes/Makefile:3`.
- **Trazabilidad**: la tabla de verificación del documento cita los cinco casos con el resultado observado de cada uno (`57 ms`, `3.0 s`, `5 → 5` descriptores, `1` aviso para 5 desconexiones, `21 ms`), todos tomados de `verif/results/results_TC-030.md`…`TC-034.md`.

---

## Implementación de feature

El documento se organiza para responder tres preguntas en orden: **qué problema existe**, **cómo está implementado** y **cómo se comprueba que funciona**.

| Sección | Función dentro del documento |
|---|---|
| Descripción | Sitúa el riesgo en el modelo de un solo hilo: la conexión no es un recurso aislado, es un descriptor dentro de la estructura de control del proceso |
| Objetivo | Fija la meta con la cita del requisito y delimita el alcance con **lo que hace** (8 puntos) y **lo que NO hace** (6 puntos) |
| Estructura del módulo | Árbol `text` con los archivos implicados y tabla de responsabilidades que incluye los dos artefactos persistentes |
| Definición de los estados | `enum class Motivo` completo y tabla de los diez valores con la condición que los produce y si generan bitácora |
| Implementación de `.h` | Declara que no se tocó ningún encabezado y explica por qué dos contratos existentes determinan el diseño |
| Implementación de `.cpp` | Ocho subsecciones con el código final y el razonamiento detrás de cada decisión |
| Integración | Qué se conecta con `event_log`, `scheduler`, `client` y `storage`, y qué no se tocó |
| Integración con otros RF | Ocho requisitos relacionados con el tipo de relación |
| Ejemplo de funcionamiento | Cinco escenarios con terminal, salida de consola y la línea exacta de bitácora |
| Verificación | Cinco casos con resultado observado y ubicación de scripts y resultados |

El principio que ordena la sección de `.cpp` es explicar el **orden de evaluación** del bucle, porque ahí está toda la corrección: `POLLERR`/`POLLNVAL` antes que cualquier lectura, `POLLHUP` desdoblado según haya o no respuesta pendiente, y dos plazos distintos —lectura y escritura— porque retener una respuesta que nadie va a leer no tiene sentido.

---

## Modificación de archivo

### `docs/technical-guide/2-Nucleo del proyecto/RF-22.desconexion-cliente.md` — contratos corregidos

```cpp
// include/network_protocol.h
constexpr unsigned MAX_MENSAJE_RED = 16384;             // techo de un mensaje completo
std::string errorProtocolo(const std::string& codigo);  // sobre de error mínimo
std::string procesarSolicitudRed(const std::string& mensaje,
                                 const std::string& identidad,
                                 const PermisosRemotos* permisos);
```

```cpp
// include/event_log.h
static bool log_event(unsigned int job_id, EventLevel level,
                      const std::string& message, const nlohmann::json& extra = {});
static bool log_event_system(EventLevel level,
                             const std::string& message, const nlohmann::json& extra = {});
```

### Escenario 2 — corte con `RST`

```json
{"context":{"bytes_recibidos":76,"ip":"127.0.0.1","motivo":"ERROR_SOCKET"},"job_id":null,"level":"WARN","message":"Cliente desconectado","ts":"2026-11-18 20:29:15"}
```

El motivo es `ERROR_SOCKET`, no `ERROR_LECTURA`: el `RST` llega al bucle como `POLLERR`, que se evalúa antes que cualquier lectura.

### Escenario 3 — cliente que nunca completa el mensaje

```json
{"error":"REQUEST_TIMEOUT","ok":false,"request_id":null,"version":1}
```

```json
{"context":{"bytes_recibidos":33,"ip":"127.0.0.1","motivo":"TIMEOUT_LECTURA"},"job_id":null,"level":"WARN","message":"Cliente desconectado","ts":"2026-11-18 20:29:40"}
```

### Escenario 5 — origen no autorizado, con el cliente real que lo demuestra

```python
# config.json con redes_permitidas: ["10.0.0.0/8"]
# y una conexión desde 127.0.0.1
s = socket.create_connection(("127.0.0.1", 45820))
s.sendall(b'{"version":1,"request_id":"p1","operation":"ping","params":{}}\n')
s.recv(4096)   # OSError: [Errno 104] Connection reset by peer
```

```json
{"context":{"ip":"127.0.0.1","motivo":"ORIGEN_RECHAZADO"},"job_id":null,"level":"WARN","message":"Conexión rechazada","ts":"2026-11-18 20:29:41"}
```

---

# Implementación final

El documento abre con la tesis del requisito y la sostiene hasta el último escenario:

```text
# RF-22 — Desconexión del cliente sin afectar al servicio

## Descripción
Hermes Red atiende a todos sus clientes dentro de un único hilo con un bucle
poll() no bloqueante. En ese modelo, la conexión de un cliente no es un recurso
aislado: es un descriptor más dentro de la misma estructura de control que
sostiene al proceso entero. [...]
```

La tabla de estados es la pieza que más se consulta en la práctica, porque responde "¿qué significa este evento?" sin abrir el código:

```text
| Valor            | Texto en bitácora | Condición que lo produce                        | ¿Registra? |
| CierreNormal     | CIERRE_NORMAL     | La respuesta se entregó completa                | No         |
| FinSinMensaje    | FIN_SIN_MENSAJE   | recv() devuelve 0 sin completar un mensaje      | Sí (WARN)  |
| TimeoutLectura   | TIMEOUT_LECTURA   | 3 s sin recibir '\n'                            | Sí (WARN)  |
| ErrorSocket      | ERROR_SOCKET      | POLLERR o POLLNVAL sobre el descriptor          | Sí (WARN)  |
| OrigenRechazado  | ORIGEN_RECHAZADO  | La IPv4 de origen no está en redes_permitidas   | Sí (WARN)  |
```

Y cada escenario de funcionamiento cierra con la línea literal de `events.jsonl` que produce, de modo que quien lea el documento puede reproducir el caso y comparar carácter por carácter:

```json
{"context":{"bytes_recibidos":1,"ip":"127.0.0.1","motivo":"FIN_SIN_MENSAJE"},"job_id":null,"level":"WARN","message":"Cliente desconectado","ts":"2026-11-18 20:31:07"}
```

---

# Aprendizaje

**Sobre documentar código.** Un documento técnico no puede escribir de memoria ninguna constante, firma ni etiqueta que aparezca en el código, aunque el valor "suene razonable". En este caso los tres valores inventados eran plausibles —65536 es el tamaño típico de un buffer de red, `void` es el retorno habitual de un logger, y `ERROR_LECTURA` es lo que sugiere el nombre de un fallo de lectura— y precisamente por ser plausibles habrían pasado desapercibidos. La regla que queda es simple: cada valor numérico y cada firma se copia del archivo, no se recuerda.

**Sobre el modelo de `poll()`.** El caso del `RST` es la mejor lección técnica del ejercicio. El servidor había recibido 76 bytes y aun así no hubo error de lectura: el descriptor se marca con `POLLERR` y esa bandera se evalúa antes de intentar leer, de modo que los bytes en vuelo se descartan con el socket. Entender que el evento del descriptor puede preceder al resultado de la syscall es lo que separa un bucle de eventos correcto de uno que "casi siempre funciona". Y explica también por qué el cierre normal no debe registrarse mientras el anómalo sí: sin esa distinción, la bitácora se vuelve ruido y deja de servir para diagnosticar.

**Sobre verificación de documentación.** Los cinco casos de prueba de RF-22 pasan sin verificar el texto del motivo de cierre en el escenario de `RST`. Eso significa que un documento con el motivo equivocado habría sido indistinguible de uno correcto para la suite. La conclusión no es que falten pruebas, sino que **la documentación necesita su propia verificación empírica**: para escribir la tabla de estados hubo que provocar cada desconexión y leer lo que realmente se escribe en disco.

**Sobre Prompt Engineering.** El prompt fue de una sola frase y funcionó porque nombraba explícitamente el skill que define la plantilla y el archivo de destino. Cuando el formato exigido es estricto, referenciar el documento que lo define es más eficaz que describir la estructura en el prompt: evita que el modelo improvise secciones y traslada la responsabilidad del formato al artefacto que ya lo especifica.
