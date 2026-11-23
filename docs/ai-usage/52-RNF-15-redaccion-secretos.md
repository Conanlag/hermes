# Uso de inteligencia artificial

# 52. RNF-15 — Redacción de secretos en registros y mensajes

## Objetivo

Implementar RNF-15 —«Los registros no deberán exponer secretos ni contenido sensible de configuración»— sobre un sistema que no tenía ninguna capa de redacción. El requisito es transversal: no hay un módulo que lo posea, sino una propiedad que deben cumplir `events.jsonl` y todos los mensajes de error que salen hacia otro extremo. Antes de tocar código hacía falta un inventario exacto de qué se registra hoy y por dónde se fuga.

---

## Prompt 1

```text
Audita los registros, bitácoras y salidas de diagnóstico de Hermes e implementa RNF-15:
"Los registros no deberán exponer secretos ni contenido sensible de configuración".

Fase 1 — Auditoría transversal (sin editar nada):
... Revisa event_log.cpp: cómo se serializa message y context, si hay allowlist,
    recursión o truncado.
... Revisa todos los call sites de log_event y log_event_system y enumera qué
    claves llegan a context.
... Revisa job.cpp: qué se copia del Job recibido a la bitácora.
... Revisa validator.cpp: qué se registra en los rechazos, en especial
    request_id_intentado.
... Revisa remote.cpp, protocol.cpp, setup.cpp y config.cpp: si un error de parseo
    JSON propaga e.what() a la bitácora, a stderr o al cliente.
... Revisa server.cpp: si alguna vez registra entrada/salida en lugar de metadatos.
... Revisa config_update.cpp y recovery/storage/scheduler por el mismo motivo.
Clasifica cada hallazgo como fuga real, higiene o correcto, con ruta:línea.

Fase 2 — Implementación:
... Una capa centralizada en event_log.h / event_log.cpp aplicada
    automáticamente a message y recursivamente a context.
... Claves sensibles, sin distinguir mayúsculas: secret, token, password, passwd,
    pwd, api_key, apikey, auth, authorization, credential, private_key, cert,
    tls, sha256, cookie, session, bearer, ambito_trabajos -> [REDACTED].
... Redactar además cadenas con patrones --password=..., --token=..., --secret=...,
    clave=valor y el valor inmediato tras -p / --password / --token / --secret /
    --api-key, solo en logs, sin alterar la ejecución real.
... Los errores de parseo JSON de remote.cpp, protocol.cpp, setup.cpp y config.cpp
    deben capturarse internamente y emitir mensajes controlados, sin fragmentos
    crudos del JSON ni valores de configuración.
... server.cpp: registrar solo metadatos operativos seguros.
... Mantener intacta la correlación de RNF-22/RF-28 y el protocolo version 1 con
    framing \n; no romper storage.cpp, scheduler.cpp ni process.cpp.

Escribe los casos de prueba y la documentación después.
```

---

## Resultado 1

La auditoría se delegó a un explorador de solo lectura con mandato de citar `ruta:línea`. Devolvió tres fugas reales y cuatro puntos de higiene:

1. **`job.cpp:230` → `event_log.cpp:239`.** `ctxRecibido["argumentos"] = nuevo.argumentos` copiaba la línea de comandos íntegra a `events.jsonl`. Un `hermes job true --password=x` dejaba la contraseña en la bitácora.
2. **`validator.cpp:121` y `:144`.** `{"request_id_intentado", requestId}` registraba el identificador crudo del cliente, y la rama de longitud corría **antes** de la validación de charset: bytes arbitrarios llegaban al archivo.
3. **`remote.cpp:218` → `client.cpp:237`.** `respuesta["message"] = detalle.what()` propagaba el texto interno de `nlohmann::json` al stderr del cliente.

Y cuatro de higiene: `context` se escribía sin filtro ni recursión, `config.cpp:57` registraba `e.what()` del parser, `config_update.cpp:273` lo concatenaba en el error de consola, y `server.cpp:353` registraba el detalle sin clasificar.

El plan propuso una capa central en `event_log` y una decisión de diseño que resultó ser la clave de todo el requisito: **detectar la clave por tokens, no por subcadena**. Con `find("token")` se habría redactado `request_id`; con `find("auth")`, `identidad`. La detección por tokens —partiendo por `_`, `-`, `.` y por transiciones de mayúscula— conserva ambos campos y, con ellos, la correlación de RNF-22.

---

## Prompt 2

```text
dale, implementa
```

---

## Resultado 2

La implementación se escribió en línea, módulo por módulo, con compilación limpia tras cada bloque. El primer corte produjo las cinco funciones de la API, su aplicación en `log_event` y `log_event_system`, y la corrección de siete puntos de llamada.

La primera compilación falló por espacio de nombres: `main.cpp` llama a `detalleSeguro` sin cualificar y el símbolo vive en `hermes`. Se corrigió con `hermes::detalleSeguro` en los cuatro puntos de `main.cpp`. Segunda compilación: cero advertencias con `-Wall -Wextra`.

Las pruebas encontraron dos defectos **en las propias pruebas**, no en el código:

- **TC-045** esperaba `[19, 140]` como longitudes registradas, pero el `request_id` de entrada era `rf15 secreto6`, de 13 caracteres. La prueba se corrigió para calcular la longitud esperada con `len()` en lugar de fijarla a mano.
- **TC-046** invocaba `hermes status` para forzar la carga de `config.json`, y `status` no lo carga. Se cambió a `hermes red job 127.0.0.1 true`, que sí pasa por `cargarConfiguracion()` antes de intentar conectar.

Después de las pruebas, una revisión dirigida al resto de los escritores de `events.jsonl` encontró **tres fugas que la auditoría inicial no había cubierto**: `scheduler.cpp:1341` y `storage.cpp:473` registraban `e.what()` en `context`, y `cancel.cpp:59` devolvía `e.what()` como `Cancelacion::mensaje`, que `remote.cpp` puede enviar al cliente. Las tres se corrigieron con `detalleSeguro` y se añadió `TC-048`, que reproduce el caso de `jobs.json` irrecuperable al arrancar.

---

# Modificaciones

**Estado de la resolución:** **[Modificado]** — el diseño y la capa central fueron correctos y no necesitaron cambios. Lo que faltó fue cobertura del inventario: tres puntos adicionales registraban texto de excepción del parser y quedaron fuera de la primera pasada; la verificación los encontró y se corrigieron.

**Revisión realizada:** cuatro niveles.

1. Spot-check propio de las regiones que la auditoría declaraba como fugas, antes de aceptar el informe.
2. Compilación forzada con `make -B` bajo `-Wall -Wextra`, para descartar que el «sin advertencias» dependiera de objetos ya compilados.
3. Prueba empírica del comportamiento en `events.jsonl` con `od -c`, para verificar que `[REDACTED]` aparece realmente en el archivo y no solo en la salida de la prueba.
4. Barrido final de `\.what\(\)` en todo `src/`, clasificando cada aparición en «va a la bitácora», «va al cliente» o «solo va a la terminal del operador». Ese barrido es lo que encontró `scheduler.cpp`, `storage.cpp` y `cancel.cpp`.

También se verificó explícitamente que **no se redacta de más**: una sonda directa sobre la API —compilando `event_log.cpp` con un `main` de veinte líneas en un directorio temporal— imprimió `request_id -> intacta`, `identidad -> intacta`, y a la vez `api_key`, `password`, `token`, `tls`, `sha256` y `ambito_trabajos` como `REDACTADA`. La misma sonda mostró `passwords -> intacta`, que coincide con el riesgo R3 declarado. Con `HOME` temporal, un `hermes job --request-id rf15-ok-1 true` produjo tres eventos correlacionados con el `request_id` intacto.

**Cambios aplicados:**

1. `event_log.h` / `event_log.cpp`: `claveSensible`, `redactarTexto`, `redactarContexto`, `detalleSeguro` y `paraRegistro`; aplicación en los dos escritores de la bitácora.
2. `validator.cpp`: los dos rechazos de `request_id` registran `longitud_intentada` y `motivo_del_rechazo`, no el valor.
3. `config.cpp`: `detalle: "JSON mal formado"`.
4. `config_update.cpp`: `"No se pudo interpretar config.json: JSON mal formado"`.
5. `remote.cpp`: parseo de `network.json` envuelto en `try/catch` con mensaje propio; el `catch` general ya no propaga `detalle.what()` al cliente y lo clasifica en la bitácora.
6. `server.cpp`, `setup.cpp`, `main.cpp`: `detalleSeguro` en los mensajes de excepción.
7. `scheduler.cpp`, `storage.cpp`, `cancel.cpp`: `detalleSeguro` en el detalle de bitácora y en el mensaje que llega al cliente.

**Prueba agregada:** `TC-043` (asignaciones sensibles), `TC-044` (banderas separadas y `-p`), `TC-045` (`request_id` rechazado sin copiar el valor), `TC-046` (`config.json` corrupto), `TC-047` (cuatro `network.json` inválidos), `TC-048` (`jobs.json` irrecuperable al arrancar). Las seis en `PASS`, más la regresión TC-030…TC-042: dieciocho scripts en total.

---

## Implementación de feature

La redacción ocurre en un solo sitio y por dos mecanismos complementarios:

```text
objeto JSON  -> clave sensible? -> [REDACTED]
             -> no? -> recursión
cadena libre -> bandera / clave=valor / Bearer -> [REDACTED]
             -> resto -> intacto
```

El primer mecanismo atrapa el caso estructurado —el arreglo `argumentos`, el objeto `context`—. El segundo atrapa el texto que ya viene formado dentro de una cadena, como el mensaje de una excepción o un campo libre. Ninguno de los dos mira valores por su forma: no hay heurística de «esto parece un token». La detección es estructural y declarativa.

| Capa | Qué garantiza |
|---|---|
| `event_log.cpp` | Ningún punto de registro puede omitir la redacción |
| `claveSensible` | Redacta `--password`, `--token`, `tls`, `sha256`… y respeta `request_id` e `identidad` |
| `redactarTexto` | Cubre patrones en cadenas libres conservando el nombre de la clave |
| `detalleSeguro` | Convierte el texto del parser en una causa clasificada |
| `paraRegistro` | Escapa bytes de control y acota la longitud |
| Puntos de llamada | Los rechazos y los errores remotos dejan de llevar el valor crudo |

---

## Modificación de archivo

**`include/event_log.h`** — la API:

```cpp
bool claveSensible(const std::string &clave);
std::string redactarTexto(const std::string &texto);
nlohmann::json redactarContexto(const nlohmann::json &valor);
std::string detalleSeguro(const std::exception &error);
std::string paraRegistro(const std::string &texto, std::size_t maximo = 64);
```

**`src/events/event_log.cpp`** — detección por tokens:

```cpp
std::vector<std::string> tokensClave(const std::string &clave) {
    // Parte por _ - . y por transición minúscula->mayúscula.
    if (std::isupper(byte) && anteriorMinuscula && !actual.empty()) {
        tokens.push_back(minusculas(actual));
        actual.clear();
    }
    ...
}
```

**`src/events/event_log.cpp`** — la frontera:

```cpp
entrada["message"] = redactarTexto(message);
entrada["context"] = redactarContexto(extra);
```

**`src/events/event_log.cpp`** — clasificación del parser:

```cpp
if (revisado.find("[json.") != std::string::npos ||
    revisado.find("parse error") != std::string::npos ||
    revisado.find("syntax error") != std::string::npos) {
    return "excepcion de formato JSON (detalle omitido)";
}
```

**`src/validator/validator.cpp`** — el rechazo sin el valor:

```cpp
{"comando_intentado", "job"},
{"longitud_intentada", requestId.size()},
{"motivo_del_rechazo", "Caracteres inválidos en request-id"}
```

**`src/network/remote.cpp`** — el cliente deja de recibir detalle interno:

```cpp
} catch (const std::exception& detalle) {
    EventLog::log_event_system(EventLevel::ERROR,
        "Error interno al procesar solicitud remota",
        {{"detalle", detalleSeguro(detalle)}});
    auto respuesta = error("JOB_OPERATION_FAILED");
    respuesta["message"] = "Error interno al procesar la solicitud";
    return respuesta;
}
```

---

# Implementación final

```text
$ hermes job true --password=sentinel123 --api-key=sentinel456

$ grep -o '"argumentos":\[[^]]*\]' events.jsonl
"argumentos":["--password=[REDACTED]","--api-key=[REDACTED]"]

$ grep -c sentinel123 events.jsonl
0

$ grep -o '"argumentos":\[[^]]*\]' jobs.json
"argumentos":["--password=sentinel123","--api-key=sentinel456"]

$ hermes job true -p secreto3 --token secreto4 --secret secreto5
  argumentos en bitacora: ['-p', '[REDACTED]', '--token', '[REDACTED]', '--secret', '[REDACTED]']
  argumentos persistidos: ['-p', 'secreto3', '--token', 'secreto4', '--secret', 'secreto5']

$ hermes job --request-id "rf15 secreto6" true
El identificador de solicitud solo admite letras, numeros, punto, guion, dos puntos y guion bajo.
$ grep -o '"longitud_intentada":[0-9]*' events.jsonl
"longitud_intentada":13

$ bash verif/scripts/TC-048.sh
PASS: RNF-15 TC-048 sin fallos.
```

---

# Aprendizaje

**Una capa central vale más que veinte parches, pero solo si el inventario está completo.** La redacción en `log_event` protegió `job.cpp` sin que `job.cpp` supiera que existía. Sin embargo, tres módulos escribían `detalle` con texto de excepción y la primera pasada no los vio. La lección operativa: cuando la garantía es «ningún registro expone secretos», el trabajo no termina en implementar la capa, termina en barrer todas las apariciones del patrón prohibido. `grep '\.what\(\)'` fue más eficaz que releer el diseño.

**Redactar de más también es un defecto.** La diferencia entre `find("token")` y la detección por tokens es la diferencia entre romper RNF-22 y cumplirlo. `request_id` y `identidad` contienen secuencias que parecen sensibles; un filtro ingenuo los habría tachado y la bitácora habría dejado de correlacionar. La pregunta correcta no es «¿contiene esta clave una palabra peligrosa?» sino «¿el nombre completo designa un dato sensible?».

**La excepción capturada no es el problema; su texto sí.** Es exactamente la trampa que RNF-14 documentó en el cliente y que reapareció aquí en cuatro módulos: `try/catch` correcto, `what()` filtrado. Cuando el requisito habla de lo que queda escrito, la frontera no es el `throw`, es la última cadena que llega al archivo.

**Las pruebas también tienen defectos.** TC-045 falló porque la longitud esperada estaba escrita a mano y no coincidía con el dato de entrada; TC-046 falló porque el comando elegido no ejercitaba la ruta que la prueba decía ejercitar. Ambas habrían pasado por buena revisión de código: el código estaba bien, la prueba no. Un caso de prueba se verifica igual que el código, ejecutándolo contra un caso conocido.

**Sobre Prompt Engineering.** El prompt enumeraba archivos y comportamientos concretos en dos fases, con la auditoría separada de la implementación. Eso permitió que el inventario fuera verificable antes de escribir y que la implementación tuviera superficies claras. La parte que faltó no fue del prompt: fue del proceso —no hubo, hasta después de las pruebas, un barrido exhaustivo del patrón a eliminar—.
