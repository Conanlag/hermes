# Uso de inteligencia artificial

# 6. Consulta de trabajo por ID RF-08

## Objetivo

Implementamos la consulta de estado y metadatos de un trabajo por su ID (RF-08) respetando separación de responsabilidades: el módulo `job` provee el dato tipado, `status` traduce en ambas direcciones, `filter` solo presenta y `validator` (RF-02) protege la entrada. Buscamos eliminar la mezcla de lectura e impresión en `filtrarPorId` sin romper su contrato ni `main.cpp`.

---

## Prompt 1
```text
muy bien, ahora siguiendo la convencion de separacion de responsabilidades, ayudame a implementar esta feature: "El usuario deberá poder consultar el estado y metadatos de un trabajo por su ID."
```

---

## Resultado 1

Se diseñó en Fase 1 el contrato mínimo: `Status statusDesdeTexto(const string& texto)` en `status.h` (inversa de `statusToString`) y `bool obtenerJobPorId(unsigned int jobId, Job& jobOut)` en `job.h` (lectura sin imprimir, con `bool + salida` en vez de `optional` o valores mágicos). En Fase 2 se implementó `statusDesdeTexto` con default seguro `QUEUED` y `obtenerJobPorId` reutilizando `leerJobs()` con extracción defensiva campo por campo (`pid = 0`, `programa = ""`, `codigoSalida = -1` ante ausencia). En Fase 3 se adelgazó `filtrarPorId` para delegar el dato y solo imprimir, agregando la línea `Codigo de salida`.

---

## Prompt 2
```text
a que te refieres con que el prototipo de job.h sea bool en vez del objeto de la clase?
```

---

## Resultado 2

Se explicó que devolver `Job` directo no puede señalar ausencia sin excepciones, Jobs trampa (`job_id = 0`) ni `std::optional` (concepto nuevo para el equipo). El patrón `bool + Job&` deja claro el veredicto: `true` rellena la salida, `false` indica no encontrado o fallo. El desarrollador lo aprobó como forma de limitar responsabilidades.

---

## Prompt 3
```text
./hermes filter programa sleep → (crash: Assertion `it != m_data.m_value.object->end()' failed. Aborted)
```

---

## Resultado 3

Se diagnosticó un crash latente en `filtrarPorStatus` y `filtrarPorPrograma`: imprimían `job["pid"]` y otras claves con `operator[]` const sin `contains`, lo que aborta con Jobs antiguos sin campo `pid`. La regresión la expuso el `filter programa sleep` sobre un `jobs.json` con entradas viejas. Se corrigió con impresión defensiva por clave (`job_id → N/A`, `programa → N/A`, `pid → 0`, `status → QUEUED`).

---

# Modificaciones
**Estado de la resolución:** Modificado por deficiencia

**Revisión realizada:** Verificamos por `git diff` que solo se agregara (`statusDesdeTexto`, `obtenerJobPorId`) sin tocar `crearJob`, actualizaciones ni `validator`. Criticamos que la primera versión solo adelgazó `filtrarPorId` y dejó el mismo patrón inseguro en los otros dos filtros. La prueba de regresión (`filter programa sleep` con datos viejos) lo evidenció con el `abort` de `nlohmann/json`.

**Cambios aplicados:** Agregamos guardas `contains` en los bloques de impresión de `filtrarPorStatus` y `filtrarPorPrograma` manteniendo el formato cuando las claves existen. No cambiamos firmas ni `main.cpp`.

**Prueba agregada:** En WSL con `make clean && make`: `./hermes filter id 2` (tipado + `Codigo de salida`), `./hermes filter id 999` (`No se encontró`), `./hermes filter id abc` (`mal formado`, RF-02 intacto), `./hermes filter programa sleep` y `./hermes filter status QUEUED/RUNNING` (sin abort, Jobs viejos con `PID: 0` tolerados).

---

## Implementación de feature

Se integró la consulta por ID con responsabilidades separadas: `obtenerJobPorId` como única lectura puntual tipada, `statusDesdeTexto` como traducción inversa segura y `filtrarPorId` como presentador delgado.

---

## Modificación de archivo

Modificados `include/status.h` + `src/status/status.cpp` (inversa de estados), `include/job.h` + `src/job/job.cpp` (consulta con `leerJobs()` y extracción defensiva) y `src/filter/filter.cpp` (delegación del dato + impresión defensiva en los tres filtros).

---

# Implementación final

```bash
./hermes filter id 2
```

```text
Job ID: 2
PID: 882
Programa: sleep
Estado: SUCCEEDED
Codigo de salida: 0
Argumentos: 15
```

```bash
./hermes filter programa sleep
```

```text
Job ID: 1
Programa: "sleep"
PID: 0
Estado: "QUEUED"
Argumentos: "5"
------------------------
```

Sin aborts y sin modificar `data/jobs.json` (solo lectura).

---

# Aprendizaje

Aprendimos que adelgazar una sola función no basta cuando el mismo patrón inseguro vive en funciones hermanas, y que probar con datos viejos (sin `pid`) es tan importante como probar el camino feliz. También que `operator[]` const de `nlohmann/json` no perdona claves faltantes: toda impresión debe verificar `contains` primero.
