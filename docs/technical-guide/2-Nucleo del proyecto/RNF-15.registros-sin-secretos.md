# RNF-15 — Los registros no deben exponer secretos

## Descripción

RNF-15 no describe una operación nueva, sino una garantía sobre **todas** las líneas que Hermes escribe en su bitácora: `events.jsonl` y cualquier mensaje de error que viaje a otro extremo. Antes de este requisito no existía ninguna capa de redacción. Cada punto de registro decidía por su cuenta qué copiar: `job.cpp` volcaba el arreglo `argumentos` completo —la línea de comandos tal como llegó, incluida cualquier contraseña—, `validator.cpp` copiaba el `request_id` crudo de un cliente TCP incluso cuando lo estaba rechazando por longitud, y tres módulos distintos concatenaban el texto interno de `nlohmann::json` en la bitácora o en el mensaje de error.

El problema no era un descuido aislado: era la ausencia de una frontera. Cuando la redacción depende de que cada autor de un `log_event` recuerde aplicarla, la primera línea nueva que alguien escriba sin recordarla vuelve a filtrar. Por eso el requisito se resuelve en un solo punto: `EventLog::log_event()` y `EventLog::log_event_system()` redactan `message` y `context` antes de serializar. Ningún punto de registro puede saltarse la redacción porque no hay un punto que la aplique por fuera.

La segunda mitad del requisito es la contraria: **no redactar de más**. La correlación de RNF-22 depende de que `request_id`, `job_id`, `operacion` y `desenlace` sobrevivan intactos; la ejecución real depende de que `jobs.json` conserve los argumentos literales. Un filtro que tache `identidad` o `request_id` porque contienen `id` o `auth` rompería más de lo que protege.

---

## Objetivo

> Los registros no deberán exponer secretos ni contenido sensible de configuración.

**Consideraciones actuales:**

- **Sí hace:** redacta por nombre de clave en objetos y anidados, por patrón en cadenas libres (`--password=...`, `--token valor`, `-p valor`, `Bearer valor`, `clave: valor`), oculta el elemento siguiente a una bandera suelta en un arreglo de argumentos, clasifica el texto de excepción del parser JSON, acota y escapa entradas no confiables, y aplica todo eso de forma centralizada e inevitable en las dos funciones de registro.
- **No hace:** no redacta fuera de la bitácora ni de los mensajes entre extremos —la ejecución y `jobs.json` conservan los valores reales—; no hace análisis semántico ni reconoce secretos por su forma (un token sin clave ni bandera pasa intacto); no aplica plurales ni sinónimos (`passwords`, `credencial`); no distingue un `-p` de `password` de un `-p` de `mkdir`.
- **No cambia:** el sobre JSON `version: 1`, el framing de un mensaje por línea `\n`, el esquema persistido de trabajos, los códigos de error de RNF-14 ni los campos de correlación de RNF-22.

---

## Estructura del módulo

```text
src/hermes/
├── include/
│   └── event_log.h              # API de redacción (claveSensible, redactarTexto…)
└── src/
    ├── events/
    │   └── event_log.cpp        # Frontera única: redacta antes de serializar
    ├── validator/validator.cpp  # Rechazos sin el valor crudo del cliente
    ├── config/config.cpp        # Aviso de config.json sin contenido
    ├── config/config_update.cpp # Error de actualización controlado
    ├── job/job.cpp              # (sin cambios: el filtro ocurre en event_log)
    ├── storage/storage.cpp      # Fallo de restauración clasificado
    ├── scheduler/scheduler.cpp  # Fallo de arranque clasificado
    ├── cancel/cancel.cpp        # Error de lectura sin texto del parser
    └── network/
        ├── remote.cpp           # Respuesta de error sin detalle interno
        ├── server.cpp           # Metadatos operativos y detalle clasificado
        └── setup.cpp            # Setup sin texto del parser en consola
```

| Archivo / directorio | Responsabilidad |
|---|---|
| `include/event_log.h` | Declara la API de redacción que comparten todos los módulos. |
| `src/events/event_log.cpp` | Implementa la redacción y la aplica en los dos puntos de escritura de la bitácora. |
| `src/validator/validator.cpp` | Deja de copiar el `request_id` rechazado; registra longitud y motivo. |
| `src/config/config.cpp` | Sustituye el texto del parser por una causa controlada. |
| `src/config/config_update.cpp` | Falla con un mensaje propio al no poder interpretar `config.json`. |
| `src/storage/storage.cpp` | Registra el fallo de restauración con `detalleSeguro`. |
| `src/scheduler/scheduler.cpp` | Registra el fallo de arranque con `detalleSeguro`. |
| `src/cancel/cancel.cpp` | Devuelve un mensaje clasificado en vez del texto del parser. |
| `src/network/remote.cpp` | No propaga el detalle interno al cliente; clasifica el error de `network.json`. |
| `src/network/server.cpp` | Solo metadatos seguros; clasifica el detalle de excepción. |
| `src/network/setup.cpp` | No imprime el texto del parser en la consola de configuración. |

---

## Implementación de `.h`

La API vive en `namespace hermes` y expone cinco piezas con responsabilidades separadas:

```cpp
bool claveSensible(const std::string &clave);
std::string redactarTexto(const std::string &texto);
nlohmann::json redactarContexto(const nlohmann::json &valor);
std::string detalleSeguro(const std::exception &error);
std::string paraRegistro(const std::string &texto, std::size_t maximo = 64);
```

`claveSensible` responde a una pregunta y solo a una: ¿este **nombre** designa un dato sensible? No toca valores. `redactarTexto` opera sobre cadenas libres. `redactarContexto` recorre el árbol JSON. `detalleSeguro` es la puerta para texto de excepción. `paraRegistro` es la primitiva de saneamiento de entradas no confiables —hoy la consume `detalleSeguro`— y queda pública porque es el ladrillo correcto para cualquier campo nuevo que registre texto de origen externo.

La firma de `detalleSeguro` recibe `const std::exception&` y no un `std::string`, para que el llamador no pueda pasar por accidente otra cadena y creer que quedó clasificada.

---

## Implementación de `.cpp`

### Detección por tokens, no por subcadena

La tentación es `clave.find("token") != npos`. Eso redactaría `request_id` —contiene `id`— y `identidad` —contiene `auth` en su forma inglesa `identity`—, es decir, destruiría la correlación de RNF-22 y el identificador de cliente de RF-28.

La implementación parte la clave en tokens por separadores (`_`, `-`, `.`, comillas) **y** por transiciones de minúscula a mayúscula, de modo que `apiKey` y `api_key` producen el mismo conjunto, y compara token contra token:

```cpp
for (const std::string &token : tokensClave(clave)) {
    for (const char *termino : TERMINOS_SENSIBLES) {
        if (token == termino) return true;
    }
}
```

La lista es: `secret`, `token`, `password`, `passwd`, `pwd`, `apikey`, `auth`, `authorization`, `credential`, `credentials`, `privatekey`, `cert`, `tls`, `sha256`, `cookie`, `session`, `bearer`. Las claves compuestas que no se parten de forma útil (`api_key`, `private_key`, `ambito_trabajos`) se comparan además por su forma compacta, sin separadores.

La consecuencia deliberada: `request_id` (tokens `request`, `id`) y `identidad` (token único `identidad`) **no** se redactan; `ambito_trabajos` **sí**, pero solo cuando aparece como nombre de clave literal, no cuando viaja como valor de `identidad` (`tcp-PC-B`).

### El orden de las reglas en una cadena

`redactarSegmento` recorre la cadena palabra por palabra **preservando el espaciado original**, porque la bitácora se lee con los ojos y perder el formato estropea el diagnóstico. Mantiene una bandera `redactarSiguiente` y aplica, en este orden:

1. Si la palabra anterior pedía redacción, esta se sustituye por `[REDACTED]`.
2. `clave=valor` con nombre sensible → se conserva el nombre y se redacta el valor: `--password=[REDACTED]`.
3. `clave:` con nombre sensible → se marca la palabra siguiente.
4. Bandera con guion (`--token`) o, en arreglos, bandera sin guion (`token`) → se marca la palabra siguiente.
5. `Bearer` → se marca la palabra siguiente.

Conservar el nombre de la clave es una decisión explícita: `--password=[REDACTED]` dice al operador qué argumento llegó, mientras que un `[REDACTED]` desnudo elimina la mitad útil del diagnóstico. Y el valor real sigue estando en `jobs.json` para la ejecución.

`-p` se reconoce como bandera sensible de forma explícita, aunque en un CLI genérico pueda significar `--parents`. La sobre-redacción se acepta y se declara como riesgo R1: es preferible perder la ruta de un `mkdir -p` en la bitácora que perder una contraseña.

### El árbol JSON y el arreglo de argumentos

`redactarContexto` es recursiva. En un objeto, redacta el valor completo cuando la clave es sensible y, si no lo es, desciende. En un arreglo, desciende cada elemento y aplica la misma bandera de «elemento siguiente» que la redacción de cadenas, ahora a nivel de elemento, para cubrir el caso en que la línea de comandos llegó como lista:

```json
{"argumentos": ["-p", "[REDACTED]", "--token", "[REDACTED]"]}
```

La bandera suelta se distingue de un valor con asignación con una regla simple: una palabra es bandera suelta si no contiene `=` y no termina en `:`. Eso separa `--password` (bandera, redacta el siguiente) de `--password=abc` (asignación, ya cubierta por la regla 2) sin necesidad de una tabla de banderas.

### La frontera inevitable

Las dos funciones de escritura aplican la redacción **antes** de construir la línea:

```cpp
entrada["message"] = redactarTexto(message);
...
entrada["context"] = redactarContexto(extra);
```

Esto no solo protege las llamadas actuales: `job.cpp` sigue haciendo `ctxRecibido["argumentos"] = nuevo.argumentos` sin saber que existe RNF-15, y la línea que llega al archivo ya está redactada. El módulo que registra no puede olvidar una regla que no ejecuta.

### Errores de parseo: clasificar, no copiar

`detalleSeguro` inspecciona el texto en minúsculas y, si reconoce la firma de un parser (`[json.`, `parse error`, `syntax error`), devuelve una causa fija:

```cpp
if (revisado.find("[json.") != std::string::npos ||
    revisado.find("parse error") != std::string::npos ||
    revisado.find("syntax error") != std::string::npos) {
    return "excepcion de formato JSON (detalle omitido)";
}
return paraRegistro(texto, 160);
```

El motivo es concreto: el mensaje de `nlohmann::json` incluye **un fragmento del texto que falló al parsear**. En un `config.json` ese fragmento son valores de configuración; en un `jobs.json`, registros de trabajo; en un `network.json`, credenciales de cliente. La excepción ya estaba capturada, pero su texto llegaba igual al archivo —exactamente la misma trampa que RNF-14 documentó en el cliente y que aquí reaparecía en tres módulos—.

Para cualquier otro texto de excepción, `paraRegistro` escapa los bytes de control como `\xHH` —para que una entrada no confiable no pueda inyectar un salto de línea en el JSONL o una secuencia de terminal en la consola— y acota a 160 caracteres con `...`.

### Los puntos de llamada corregidos

| Archivo | Antes | Después |
|---|---|---|
| `validator.cpp` | `{"request_id_intentado", requestId}` en los dos rechazos de `request-id` | `{"longitud_intentada", requestId.size()}` y `motivo_del_rechazo` |
| `config.cpp` | `{"detalle", e.what()}` | `{"detalle", "JSON mal formado"}` |
| `config_update.cpp` | `"…config.json: " + error.what()` | `"…config.json: JSON mal formado"` |
| `remote.cpp` (parseo) | `archivo >> datos` sin envolver | `try/catch` → `"network.json no es un JSON válido"` |
| `remote.cpp` (catch) | `respuesta["message"] = detalle.what()` | mensaje fijo + `detalleSeguro` en la bitácora |
| `server.cpp` | `{"detalle", error.what()}` | `{"detalle", detalleSeguro(error)}` |
| `scheduler.cpp` | `{"detalle", e.what()}` (arranque) | `{"detalle", hermes::detalleSeguro(e)}` |
| `storage.cpp` | `{"detalle", e.what()}` (restauración) | `{"detalle", hermes::detalleSeguro(e)}` |
| `cancel.cpp` | `mensaje = e.what()` (llega al cliente) | `mensaje = hermes::detalleSeguro(e)` |
| `setup.cpp`, `main.cpp` | `e.what()` en `std::cerr` | `detalleSeguro(e)` |

El caso de `validator.cpp` merece una nota. El `request_id` se validaba **después** de registrarlo, y la rama de longitud corría antes que la de charset: un cliente podía pegar un secreto en el campo y verlo aparecer en la bitácora. Un identificador inválido no tiene valor diagnóstico —su longitud y el motivo sí—, y no hay razón para conservar un valor que el propio sistema acaba de declarar inaceptable.

### Lo que se conserva

- **`jobs.json` no cambia.** Los argumentos se guardan literales y la ejecución es idéntica; solo la copia en la bitácora está redactada.
- **La correlación de RNF-22 no cambia.** `job_id`, `request_id`, `operacion`, `desenlace`, `nivel` y `ts` mantienen su nombre y su valor.
- **El protocolo no cambia.** `version: 1`, el sobre y el framing por `\n` siguen igual; lo único que cambia en la respuesta remota es que `message` ya no transporta texto interno del servidor.

---

## Integración con otros Requisitos

- **RF-14 — Bitácora de eventos.** RNF-15 no añade eventos ni niveles: se inserta dentro de los dos escritores existentes, de modo que toda la bitácora histórica conserva su formato.
- **RNF-22 — Correlación solicitud/trabajo/bitácora.** La detección por tokens es lo que permite redactar sin romper la correlación: `request_id` y `identidad` sobreviven por diseño, no por excepción.
- **RF-28 — Estado coherente ante desconexión.** El evento `Solicitud interrumpida` y sus campos siguen intactos; el detalle de excepción que pudiera acompañarlo pasa ahora por `detalleSeguro`.
- **RNF-14 — Validación de longitud y formato.** Comparte la lección de fondo: el texto interno de una librería no es un diagnóstico, es una fuga con formato de diagnóstico. RNF-14 la cerró en el cliente; RNF-15 la cierra en la bitácora.
- **RNF-28 — Persistencia atómica.** La restauración desde `jobs.json.bak` registra su fallo con la causa clasificada, sin copiar el archivo corrupto.

---

## Ejemplo de funcionamiento

### Antes y después de un argumento sensible

```text
$ hermes job true --password=sentinel123 --api-key=sentinel456

# events.jsonl (antes)
{"context":{"argumentos":["--password=sentinel123","--api-key=sentinel456"],...}}

# events.jsonl (después)
{"context":{"argumentos":["--password=[REDACTED]","--api-key=[REDACTED]"],...}}

# jobs.json (sin cambios)
"argumentos": ["--password=sentinel123", "--api-key=sentinel456"]
```

### Banderas separadas y forma corta

```text
$ hermes job true -p secreto3 --token secreto4 --secret secreto5
  argumentos en bitacora: ['-p', '[REDACTED]', '--token', '[REDACTED]', '--secret', '[REDACTED]']
  argumentos persistidos: ['-p', 'secreto3', '--token', 'secreto4', '--secret', 'secreto5']
```

### Un rechazo sin el valor del cliente

```text
# antes
{"context":{"comando_intentado":"job","request_id_intentado":"abc def sentinel789",
 "motivo_del_rechazo":"Caracteres inválidos en request-id"}}

# después
{"context":{"comando_intentado":"job","longitud_intentada":19,
 "motivo_del_rechazo":"Caracteres inválidos en request-id"}}
```

### Un estado corrupto al arrancar

```text
$ hermes filter list
No se pudo iniciar el scheduler: No se pudo recuperar el estado antes de iniciar el scheduler

# events.jsonl
{"context":{"detalle":"excepcion de formato JSON (detalle omitido)","funcion":"arranque del scheduler"},
 "level":"ERROR","message":"Error interno del daemon","ts":"2026-11-22 17:51:12"}
```

---

## Verificación

Seis casos automatizados nuevos, ejecutados el 2026-11-20 y el 2026-11-22 en WSL Ubuntu. Todos en `PASS`.

| Caso | Escenario | Resultado observado |
|---|---|---|
| **TC-043** | Dos asignaciones sensibles en un Job | Bitácora con `--password=[REDACTED]` y `--api-key=[REDACTED]`; `jobs.json` con los valores reales; cero apariciones de los sentinelas |
| **TC-044** | `-p`, `--token` y `--secret` con el valor en el elemento siguiente | Los tres valores redactados, las tres banderas visibles y el orden intacto |
| **TC-045** | `request_id` con espacios y de 140 caracteres | Rechazos con `longitud_intentada` `13` y `140`, sin `request_id_intentado`; un `request_id` válido en `3` eventos correlacionados |
| **TC-046** | `config.json` truncado con sentinela | Advertencia con `detalle: "JSON mal formado"`; `configmax` falla con mensaje controlado; sin contenido ni texto del parser |
| **TC-047** | Cuatro `network.json` inválidos (`tls`, `sha256`, `ambito_trabajos`, JSON roto) | Cada diagnóstico cita la regla y no el valor; ningún sentinela en la bitácora |
| **TC-048** | `jobs.json` y `jobs.json.bak` corruptos al arrancar | `detalle: "excepcion de formato JSON (detalle omitido)"`; consola con mensaje controlado; sin sentinela |

**Regresión.** TC-030 a TC-042 (RF-22, RF-28 y RNF-14) se reejecutaron y siguen en `PASS`: dieciocho scripts en total. Compilación completa con `g++ -Wall -Wextra -std=c++17` mediante `make -B`, sin advertencias.

Scripts en `verif/scripts/TC-043.sh`…`TC-048.sh`; evidencia en `verif/results/results_TC-043.md`…`results_TC-048.md`; descripciones en `verif/test-cases/TC-043.md`…`TC-048.md`; fila RNF-15 de `verif/verification-plan/traceability-matrix.md` en `PASS`.

### Sonda directa sobre la API

Los casos anteriores prueban el comportamiento de extremo a extremo. La tabla de detección se verificó además con una sonda de veinte líneas que compila `event_log.cpp` en un directorio temporal y llama a las funciones directamente:

```text
request_id -> intacta        api_key -> REDACTADA       programa -> intacta
identidad -> intacta         password -> REDACTADA      token -> REDACTADA
ambito_trabajos -> REDACTADA passwords -> intacta       auth -> REDACTADA
tls -> REDACTADA             sha256 -> REDACTADA         --password -> REDACTADA

redactarTexto("fallo con --password=abc123 y -p xyz789 y token: zzz000")
  -> fallo con --password=[REDACTED] y -p [REDACTED] y token: [REDACTED]

redactarContexto({"identidad":"tcp-PC-B","request_id":"abc",
                  "argumentos":["-p","s3","--token","t4"]})
  -> {"argumentos":["-p","[REDACTED]","--token","[REDACTED]"],
      "identidad":"tcp-PC-B","request_id":"abc"}
```

La sonda confirma las dos mitades del requisito en el mismo lugar: lo sensible se tacha y lo que sostiene la correlación de RNF-22 no. También confirma R3: `passwords` no se detecta, porque la lista no aplica plurales.

---

## Riesgo residual

**R1 — `-p` sobre-redacta.** `-p` se trata siempre como bandera sensible. En un comando como `hermes job mkdir -p /tmp/x`, la bitácora registra `["-p","[REDACTED]","/tmp/x"]` y pierde la ruta. La ejecución no se ve afectada. Es una elección deliberada: no hay forma de distinguir la intención sin conocer el programa, y un falso negativo cuesta más que un falso positivo.

**R2 — el volcado de `hermes red setup` queda fuera de alcance.** La confirmación que `setup.cpp` imprime en stdout muestra el comando que el operador debe ejecutar en el otro equipo. Es una instrucción interactiva, no una línea de bitácora, y su contenido ya lo controla el operador.

**R3 — la lista de claves sensibles es cerrada.** No hay stemming ni sinónimos: `passwords`, `credencial` o `clave_privada` no se detectan por nombre. La lista se amplía en `TERMINOS_SENSIBLES`, en un solo lugar, cuando aparezca un caso real.

**R4 — los errores del parser que solo se imprimen en la terminal del operador no pasan por la redacción.** `hermes logs`, `filter` y `clean` imprimen el texto del parser cuando leen un archivo corrupto, porque el destinatario es el operador que inspecciona su propio estado local y no se produce un registro persistente. Si en el futuro esos mensajes se enrutan a la bitácora, deben pasar por `detalleSeguro`.

---

## Historial

| Fecha | Cambio |
|---|---|
| 2026-11-22 | Implementación de RNF-15: capa central de redacción por clave y patrón en `event_log`, clasificación de errores de parseo en config, red, scheduler, storage y cancel, rechazos sin el valor crudo del cliente, y casos TC-043…TC-048 |
