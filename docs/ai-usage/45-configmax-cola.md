# Uso de inteligencia artificial

# 45. Exposición de los cupos de espera en el CLI mediante `configmax --cola`

## Objetivo

Cerrar la asimetría que dejó la implementación de ADR-017: `max_cola` solo se podía fijar editando `config.json` a mano, mientras que `trabajos_maximos` disponía de una vía validada, serializada y con escritura atómica a través de `hermes configmax <N>`. Se buscaba determinar si esa diferencia constituía un defecto de requisito y, en su caso, extender el CLI para que ambas llaves de configuración tuvieran la misma clase de garantías.

---

## Prompt 1
```text
no existe el TC-025 en las especificaciones del proyecto, ignora eso, ahora, esto es un error?: hermes configmax no expone max_cola; hoy se edita a mano en config.json.
```

---

## Resultado 1

La IA se negó a responder con un sí o un no plano y separó el juicio en dos planos. Contra el requisito, concluyó que **no era un error**: `configmax` cumple RF-05 (fijar el máximo de trabajos simultáneos, rango `[1, 64]`, `config.lock` y escritura atómica), y ni RF-03 ni RF-05 exigen exponer la capacidad de cola por CLI. Era una omisión de interfaz, no un incumplimiento.

Como diseño, en cambio, señaló un hueco real, apoyado en el código de `config_update.cpp` y de `config.cpp`: el contraste de garantías entre las dos vías de escritura.

| | `configmax` | Edición manual |
|---|---|---|
| Validación de rango | Rechaza con error | Ajusta con `WARN`, silencioso |
| Exclusión mutua | `config.lock` | Ninguna |
| Escritura | Atómica (`fsync` + `rename`) | Editor, sin garantías |

El riesgo concreto que destacó está en que `cargarConfiguracion()` es tolerante por diseño: si `config.json` queda con JSON inválido, no falla, sino que cae a los valores por defecto `5` y `0` dejando solo un `WARN` en `events.jsonl`. Un typo al editar a mano no rompe Hermes; lo deja corriendo con otra configuración de la que el operador cree tener. Añadió que `max_cola: 5000` tampoco se rechaza, se recorta a `256`.

Propuso tres caminos: extender `configmax` con `--cola`, dejarlo documentado, o endurecer el parser para que un archivo inválido falle en lugar de caer a defaults. Recomendó el primero si se iba a seguir trabajando en esa superficie, y el tercero si preocupaba más la integridad que la comodidad.

---

## Prompt 2
```text
ve con la opcion 1
```

---

## Resultado 2

La IA implementó la extensión del CLI con tres formas de invocación: `configmax <N>`, `configmax --cola <M>` y `configmax <N> --cola <M>`. Antes de escribir código registró la evidencia RED correspondiente (`configmax --cola 1` respondía con el mensaje de uso y código `1`).

En lugar de duplicar la validación de enteros, factorizó `validarTrabajosMaximosTexto()` en un helper privado `validarEnteroEnRango()` que recibe rango, comando, mensaje de uso y etiqueta del valor, conservando byte por byte los mensajes existentes de `trabajos_maximos`. Del lado de la persistencia, sustituyó la función que escribía una sola clave por `actualizarConfiguracion()`, que recibe una estructura de intenciones, valida **todas** las claves activas antes de abrir el archivo, y escribe una sola vez bajo `config.lock`. `establecerTrabajosMaximos()` y `establecerMaxCola()` quedaron como atajos sobre esa ruta única, de modo que no existen dos caminos de escritura con garantías distintas.

También actualizó la ayuda de `--help`, la guía de usuario, los documentos RF-03 y RF-05, ADR-017 y `Estructura del proyecto.md`.

---

# Modificaciones

**Estado de la resolución:** [Aceptado] — la IA dio un código correcto después de su verificación.

**Revisión realizada:** El diagnóstico del plano funcional fue correcto y se comprobó contra el código: `establecerTrabajosMaximos()` usaba `BloqueoConfiguracion` y `guardarAtomico()`, mientras `max_cola` solo existía como llave leída por `cargarConfiguracion()`. La clasificación "no viola RF-05, pero sí es una inconsistencia de robustez" se sostiene.

La revisión humana encontró dos puntos que merecen registro crítico. El primero es que la solución elegida **no elimina el riesgo original**, solo lo desvía: el parser sigue cayendo a defaults con `WARN` cuando el archivo es inválido, de modo que una edición manual defectuosa continúa degradando la configuración en silencio. Lo que cambia es que ahora existe una vía recomendada y validada, y los documentos lo advierten. La opción de endurecer el parser quedó descartada por el desarrollador, no por la IA.

El segundo es una sobreingeniería menor de la IA: añadió una rama para el caso "el archivo no existe", cuando `rutaDatos()` ejecuta `inicializarDatos()`, que crea el directorio y un `config.json` por defecto antes de devolver la ruta. La rama es inalcanzable en la práctica; se conservó como guarda defensiva porque distingue "archivo ausente" de "archivo ilegible", pero no era necesaria.

**Cambios aplicados:**

- `config.h`: estructura `CambiosConfiguracion`, declaración de `actualizarConfiguracion()` y de los dos atajos, con sus contratos de excepción.
- `config_update.cpp`: `validarRango()` privado, validación previa a cualquier escritura, una sola transacción bajo `config.lock`, un evento `INFO` por clave modificada, y distinción entre archivo ausente y archivo ilegible.
- `validator.cpp` / `validator.h`: helper privado `validarEnteroEnRango()` y `validarMaxColaTexto()`, conservando los mensajes previos de `trabajos_maximos`.
- `main.cpp`: parseo de `<N>`, `--cola <M>` y ambos en cualquier orden, con rechazo de duplicados, de argumentos desconocidos y de `--cola` sin valor.
- `help.cpp`: dos líneas nuevas de comandos y un ejemplo.
- Documentación: `user-guide.md`, `RF-03.cola-inicial.md`, `RF-05.maximo-configurable.md`, `ADR-017-Cola-Espera.md`, `Estructura del proyecto.md` y la celda de RF-05 en la matriz de trazabilidad.

**Prueba agregada:**

- RED: `./hermes configmax --cola 1` devolvía `Uso: hermes configmax <N> (N debe estar entre 1 y 64).` con código `1`.
- GREEN, sobre un `HOME` temporal: `--cola 2` persiste `{"max_cola":2,"trabajos_maximos":5}`; `4 --cola 1` persiste ambos; `5` conserva `max_cola`; `--cola 257`, `--cola abc`, `configmax` sin argumentos, `configmax 5 --cola` y `configmax 0` se rechazan con código `1` sin escribir; el archivo final queda en `{"max_cola":1,"trabajos_maximos":5}`.
- Bitácora: cuatro eventos `INFO` con `clave: max_cola` y `clave: trabajos_maximos`, dentro de la transacción.
- Regresión: `TC-004` (`configmax 64`), `TC-016` y `TC-023` en `[PASS]`.
- Hallazgo durante la regresión: `TC-024` resultó inestable. En tres corridas comparó descriptores `5 → 7` una vez (`FAIL`) y `5 → 5` dos veces (`PASS parcial`). El código del scheduler no fue modificado, por lo que se clasificó como flakiness preexistente en la medición y no como regresión de este cambio.

---

## Modificación de archivo

`src/hermes/src/main.cpp` — parseo de las tres formas de invocación, con validación previa y una sola llamada a la persistencia:

```cpp
    if (comando == "configmax") {
        const string uso =
            "Uso: hermes configmax <N> | hermes configmax --cola <M> | "
            "hermes configmax <N> --cola <M> "
            "(N entre 1 y 64; M entre 0 y 256).";

        bool tieneTrabajosMaximos = false;
        bool tieneMaxCola = false;
        string valorTrabajosMaximos;
        string valorMaxCola;

        for (int i = 2; i < argc; ++i) {
            const string argumento = argv[i];

            if (argumento == "--cola") {
                if (tieneMaxCola || i + 1 >= argc) {
                    error(uso);
                    return 1;
                }

                valorMaxCola = argv[++i];
                tieneMaxCola = true;
                continue;
            }

            if (tieneTrabajosMaximos || argumento.rfind("--", 0) == 0) {
                error(uso);
                return 1;
            }

            valorTrabajosMaximos = argumento;
            tieneTrabajosMaximos = true;
        }

        if (!tieneTrabajosMaximos && !tieneMaxCola) {
            error(uso);
            return 1;
        }

        if (tieneTrabajosMaximos) {
            const ResultadoValidacion validacion =
                validarTrabajosMaximosTexto(valorTrabajosMaximos);
            if (!validacion.esValido) {
                error(validacion.mensaje);
                return 1;
            }
        }

        if (tieneMaxCola) {
            const ResultadoValidacion validacion =
                validarMaxColaTexto(valorMaxCola);
            if (!validacion.esValido) {
                error(validacion.mensaje);
                return 1;
            }
        }

        hermes::CambiosConfiguracion cambios;
        if (tieneTrabajosMaximos) {
            cambios.trabajosMaximos = true;
            cambios.valorTrabajosMaximos = std::stoi(valorTrabajosMaximos);
        }
        if (tieneMaxCola) {
            cambios.maxCola = true;
            cambios.valorMaxCola = std::stoi(valorMaxCola);
        }

        try {
            hermes::actualizarConfiguracion(cambios);
        } catch (const exception& e) {
            error("No se pudo actualizar la configuración: ", e.what());
            return 1;
        }

        if (tieneTrabajosMaximos) {
            info(
                "Máximo de trabajos simultáneos configurado en ",
                cambios.valorTrabajosMaximos,
                ". El cambio de workers se aplica al iniciar el scheduler."
            );
        }

        if (tieneMaxCola) {
            info(
                "Cupos de espera (max_cola) configurados en ",
                cambios.valorMaxCola,
                ". El cambio se aplica al iniciar el scheduler."
            );
        }

        warning(
            "Para aplicarlo ahora, ejecute 'hermes clean scheduler'; "
            "los trabajos en ejecución serán interrumpidos."
        );
        return 0;
    }
```

`src/hermes/src/config/config_update.cpp` — validación completa antes de tocar el disco:

```cpp
void actualizarConfiguracion(const CambiosConfiguracion& cambios) {
    // Se valida todo antes de abrir el archivo: si una de las claves está fuera
    // de rango, no se escribe ninguna.
    if (cambios.trabajosMaximos) {
        validarRango(
            cambios.valorTrabajosMaximos,
            MIN_TRABAJOS_MAXIMOS,
            MAX_TRABAJOS_MAXIMOS,
            "trabajos_maximos"
        );
    }

    if (cambios.maxCola) {
        validarRango(
            cambios.valorMaxCola,
            MIN_MAX_COLA,
            MAX_MAX_COLA,
            "max_cola"
        );
    }

    BloqueoConfiguracion bloqueo;
    const std::string ruta = rutaDatos("config.json");
    std::ifstream archivo(ruta);
    json datos = json::object();

    if (archivo.is_open()) {
        try {
            archivo >> datos;
        } catch (const std::exception& error) {
            throw std::runtime_error(
                std::string("No se pudo interpretar config.json: ") +
                error.what()
            );
        }

        if (!datos.is_object()) {
            throw std::runtime_error(
                "config.json debe contener un objeto JSON."
            );
        }
    } else if (std::filesystem::exists(ruta)) {
        // El archivo existe pero no se puede leer: no se sobrescribe.
        throw std::runtime_error("No se pudo abrir config.json");
    }

    if (cambios.trabajosMaximos) {
        datos["trabajos_maximos"] = cambios.valorTrabajosMaximos;
    }

    if (cambios.maxCola) {
        datos["max_cola"] = cambios.valorMaxCola;
    }

    guardarAtomico(ruta, datos);
}
```

`src/hermes/src/validator/validator.cpp` — un solo parser de enteros en rango para ambas llaves:

```cpp
ResultadoValidacion validarMaxColaTexto(
    const string& texto
) {
    return validarEnteroEnRango(
        texto,
        hermes::MIN_MAX_COLA,
        hermes::MAX_MAX_COLA,
        "configmax --cola",
        "Uso: hermes configmax [<N>] --cola <M> (M debe estar entre " +
            to_string(hermes::MIN_MAX_COLA) + " y " +
            to_string(hermes::MAX_MAX_COLA) + ").",
        "de --cola "
    );
}
```

---

# Implementación final

```bash
$ ./hermes configmax --cola 2
Cupos de espera (max_cola) configurados en 2. El cambio se aplica al iniciar el scheduler.
Para aplicarlo ahora, ejecute 'hermes clean scheduler'; los trabajos en ejecución serán interrumpidos.

$ ./hermes configmax 4 --cola 1
Máximo de trabajos simultáneos configurado en 4. El cambio de workers se aplica al iniciar el scheduler.
Cupos de espera (max_cola) configurados en 1. El cambio se aplica al iniciar el scheduler.

$ ./hermes configmax --cola 257
El valor de --cola debe estar entre 0 y 256.
$ echo $?
1

$ ./hermes configmax --cola abc
El valor de --cola debe ser un número entero entre 0 y 256.

$ ./hermes configmax
Uso: hermes configmax <N> | hermes configmax --cola <M> | hermes configmax <N> --cola <M> (N entre 1 y 64; M entre 0 y 256).
```

Estado persistido tras `configmax 5` (la llave no modificada se conserva):

```json
{
    "max_cola": 1,
    "trabajos_maximos": 5
}
```

---

# Aprendizaje

La lección más útil no fue de C++ sino de superficie de interfaz: cuando dos parámetros viven en el mismo archivo pero solo uno tiene una vía validada de escritura, la diferencia de garantías se convierte en un modo de fallo silencioso. El parser tolerante que parecía una virtud — nunca negarse a arrancar por configuración inválida — se vuelve un riesgo en cuanto la edición manual es la única forma de escribir una llave, porque el sistema sigue operando con valores que el operador no eligió y solo lo deja dicho en la bitácora.

En Prompt Engineering, la pregunta original era cerrada ("¿esto es un error?") y la respuesta útil fue negarse a responderla así: separar "cumple el requisito" de "es una decisión de diseño defendible" permitió que el desarrollador eligiera con información en lugar de aceptar un diagnóstico binario. También quedó registrado que la opción aceptada mitiga pero no elimina el riesgo, y que decirlo explícitamente vale más que presentar la solución como completa.
