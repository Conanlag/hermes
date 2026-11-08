# Uso de inteligencia artificial

# 44. Cola de espera separada del límite de concurrencia (Issue #102 / TC-002)

## Objetivo

Corregir el Issue #102, materializado en el fallo de `TC-002`: con `trabajos_maximos = 3` y cuatro solicitudes, Hermes rechazaba la cuarta en lugar de retenerla en cola. El trabajo consistía en analizar cómo se dimensiona el pool del scheduler y cómo se admite un Job, diseñar la corrección, y solo después de la autorización explícita del desarrollador modificar el código C++ y la suite de pruebas (`TC-002.sh` y `TC-002.md`).

---

## Prompt 1
```text
analiza el "fix-TC-002.md" y ponte a trabajar
```

---

## Resultado 1

La IA leyó el documento del sprint y auditó `config.h`, `config.cpp`, `config_update.cpp`, `scheduler.h`, `scheduler.cpp`, `job.h`, `job.cpp`, `storage.cpp`, `main.cpp` y la suite de verificación. Concluyó:

- El dimensionamiento **ya era dinámico**: `main.cpp:107-110` carga `config.json` y pasa `trabajosMaximos` a `ejecutarScheduler(int)`, que crea exactamente N hilos (`scheduler.cpp:1135-1154`). Los `= 5` de las firmas son solo valores por defecto.
- El parser de configuración ya era tolerante a fallos (archivo ausente, JSON corrupto, llave inválida o fuera de rango → `WARN` + default 5).
- El defecto real estaba en la **admisión**: `crearJob()` contaba `QUEUED + RUNNING` y rechazaba al llegar a `trabajos_maximos`. Como el pool consume todos esos cupos, un Job nunca podía permanecer en `QUEUED`; la cola era arquitectónicamente inalcanzable.
- La corrección literal del documento (eliminar el rechazo y dejar cola ilimitada) habría roto RF-23/RF-25 y las pruebas `TC-016` y `TC-023`, que verifican el rechazo explícito.

Se propuso una alternativa de dos capacidades (`trabajos_maximos` para concurrencia y `max_cola` para cupos de espera, con `max_cola = 0` por defecto para conservar el comportamiento histórico) y se detuvo la ejecución para pedir autorización, tal como exigía el documento del sprint.

---

## Prompt 2
```text
si la opcion "A" implica resolver los conflictos dentro del TC-002 y mantener todo lo demas funcionando correctamente, escoje la opcion "A"
```

---

## Resultado 2

La IA implementó la Opción A: añadió `max_cola` a `ConfiguracionSistema`, la parseó de forma opcional y tolerante en `cargarConfiguracion()`, propagó ambos valores desde `main.cpp` y cambió la condición de admisión de `crearJob()` a `QUEUED + RUNNING >= trabajos_maximos + max_cola`. No tocó `scheduler.cpp`, porque el pool ya imponía el límite de `RUNNING`.

Además reescribió `verif/scripts/TC-002.sh` como prueba de integración bajo estrés (configuración forzada, ráfaga de cuatro `sleep 10`, auditoría de `3 RUNNING` + `1 QUEUED`, validación campo por campo del Job en espera y auditoría pospuesta), actualizó `verif/test-cases/TC-002.md`, redactó `ADR-017-Cola-Espera.md` y ajustó las referencias de `user-guide.md`, `RNF-07-limite-concurrencia.md` y `Estructura del proyecto.md`.

---

# Modificaciones

**Estado de la resolución:** Modificado por deficiencia.

**Revisión realizada:** La primera interpretación del documento del sprint era técnicamente válida en C++ pero arquitectónicamente incompleta: eliminar el rechazo habría satisfecho RF-03 destruyendo RF-23 y RF-25, ambos ya verificados y documentados en ADR-008 y ADR-015. La IA detectó el conflicto al cruzar el código con la matriz de trazabilidad y las pruebas existentes, y en lugar de aplicar la instrucción literal propuso dos capacidades separadas. La decisión de política fue del desarrollador; el diseño no se codificó hasta recibir esa autorización.

También se corrigió un defecto propio durante la construcción de la prueba: la primera versión del script hacía una lectura única de `jobs.json` inmediatamente después de la ráfaga, lo que podía observar un estado intermedio (un Job creado pero todavía no reservado por un worker) y producir un falso `FAIL`. Se sustituyó por una espera acotada hasta que el pool ocupa sus workers y una única instantánea para leer `RUNNING` y `QUEUED` de forma consistente.

**Cambios aplicados:**

- `config.h`: constantes `DEFAULT_MAX_COLA`, `MIN_MAX_COLA` y `MAX_MAX_COLA`, y campo `maxCola` en `ConfiguracionSistema`.
- `config.cpp`: lectura opcional de `max_cola` con `WARN` y ajuste de rango, sin afectar el comportamiento cuando la llave no existe.
- `job.h` / `job.cpp`: parámetro `maxCola` en `crearJob()` y capacidad total `trabajosMaximos + maxCola`; el evento de rechazo conserva `capacidad` y añade `trabajos_en_espera` y `capacidad_cola`.
- `main.cpp`: propagación de `config.maxCola`.
- `verif/scripts/TC-002.sh` y `verif/test-cases/TC-002.md`: reescritura completa del caso.
- `docs/desicions/ADR-017-Cola-Espera.md`, `docs/user-guide/user-guide.md`, `RNF-07-limite-concurrencia.md`, `Estructura del proyecto.md`: actualización de la semántica documentada.

**Prueba agregada:**

- `TC-002` reescrito y ejecutado dos veces en WSL (Ubuntu, g++ 15.2.0): `[ PASS ]` en ambas, con `4/4` solicitudes admitidas, `3 RUNNING` + `1 QUEUED` y transición del Job encolado a `RUNNING`.
- Regresión: `TC-016`, `TC-023` y `TC-024` en `[ PASS ]` con `max_cola` ausente.
- Comparación diferencial: `TC-003` falla en su paso 5 con el mismo mensaje tanto en el árbol modificado como en un worktree del commit base `6723219`; se comprobó que era un fallo preexistente y no una regresión de este cambio.

---

## Modificación de archivo

`src/hermes/include/config.h` — nueva capacidad de cola, con default compatible:

```cpp
// Cupos de espera (QUEUED) por encima de trabajos_maximos. Cero significa que
// no se admite cola de espera y que el excedente se rechaza, que es el
// comportamiento histórico descrito en ADR-008.
constexpr int DEFAULT_MAX_COLA = 0;
constexpr int MIN_MAX_COLA = 0;
constexpr int MAX_MAX_COLA = 256;

struct ConfiguracionSistema {
    int trabajosMaximos = DEFAULT_TRABAJOS_MAXIMOS;
    int maxCola = DEFAULT_MAX_COLA;
};
```

`src/hermes/src/job/job.cpp` — el límite de concurrencia lo impone el pool; la admisión solo acota el total:

```cpp
const size_t capacidadTotal =
    static_cast<size_t>(trabajosMaximos) +
    static_cast<size_t>(maxCola);
...
if (status == "QUEUED" || status == "RUNNING") {
    ++trabajosActivos;
}
if (status == "QUEUED") {
    ++trabajosEnEspera;
}

if (trabajosActivos >= capacidadTotal) {
    colaLlena = true;
    return false;
}
```

`src/hermes/src/main.cpp` — propagación de la configuración:

```cpp
job = crearJob(
    programa,
    argumentos,
    requestId,
    config.trabajosMaximos,
    config.maxCola
);
```

---

# Implementación final

```bash
$ cat "$HOME/.local/share/hermes/data/config.json"
{
  "trabajos_maximos": 3,
  "max_cola": 1
}

$ ./hermes job sleep 10 &   # x4 en ráfaga
job ID: 1
job ID: 2
job ID: 3
job ID: 4

$ python3 -c 'import json,os; ...'   # conteo sobre jobs.json
4 Jobs persistidos
3 Jobs RUNNING con límite 3
1 Job QUEUED retenido
Paso 6.1 (auditoría del Job 4):
  OK (job_id = 4 (numérico))
  OK (programa = sleep (cadena))
  OK (argumentos contiene 10)
  OK (status = QUEUED (cadena))
  OK (pid = 0 (numérico))
  OK (codigo_salida = -1 (numérico))
  OK (cancel_requested = false (booleano))
Paso 7 OK (el Job 4 pasó de QUEUED a RUNNING)
[ PASS ] TC-002
```

Con `max_cola` ausente, el comportamiento es el histórico y las pruebas de rechazo siguen intactas:

```bash
$ ./hermes job sleep 30
No se pudo crear el Job: La cola está llena (5/5 trabajos activos). Intente de nuevo cuando haya espacio.
```

---

# Aprendizaje

La lección central es de arquitectura, no de C++: un requisito puede parecer "solo un límite" y en realidad estar definiendo dos capacidades distintas que, al colapsarse en una sola variable, hacen inalcanzable otro requisito. Cuando dos RF calificados se contradicen, la respuesta correcta no es elegir el más reciente, sino separar las dimensiones que se estaban mezclando y darle al cambio un valor por defecto que preserve el contrato existente.

En Prompt Engineering, el documento del sprint pedía "cambia el código para que la cola funcione" y una implementación literal habría roto dos requisitos ya verificados. Vale más auditar el resto de la suite y la matriz de trazabilidad antes de escribir la primera línea: el coste de cinco minutos de lectura cruzada es mucho menor que el de descubrir la regresión después.
