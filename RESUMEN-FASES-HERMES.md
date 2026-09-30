# Hermes — Resumen de Fases (acordeón de memoria)

> Para releer si se te olvida. Sin código nuevo, solo el modelo mental.

## Fase 1 — Fundamentos y Arquitectura

**Idea:** Hermes es un CLI despachador y modular de gestión de procesos.

- `src/hermes/include/` = promesas (contratos: `job.h`, `status.h`, `filter.h`, `version.h`).
- `src/hermes/src/` = cumplimiento (implementaciones por dominio: `job/job.cpp`, `status/status.cpp`, `filter/filter.cpp`, `version/version.cpp`, `main.cpp`).
- `src/hermes/src/IPC/`, `database/`, `network/` = intención futura (hoy solo `prueba.txt`). Según `docs/.../Estructura del proyecto.md`: IPC = entre procesos, database = persistencia/historial, network = entre computadoras.
- `src/hermes/data/jobs.json` = persistencia fuera del binario.
- `src/hermes/Makefile` + `README.md` = construcción y documentación.

**Concepto C++:** separación declaración (` .h`) vs definición (`.cpp`) permite compilación separada.

## Fase 2 — Ejecución Principal

**Idea:** `Makefile` cocina, `main.cpp` valida y delega.

Makefile:
- `CXX = g++`, `CXXFLAGS = -Wall -Wextra -std=c++17 -Iinclude` (avisos + C++17 + buscar cabeceras en `include/`).
- `SRC = $(shell find src -type f -name '*.cpp')` descubre módulos solo.
- `$(CXX) $(CXXFLAGS) $(SRC) -o $(TARGET)` compila y enlaza en `hermes`.
- `clean / install / uninstall` gestionan el binario.

`src/hermes/src/main.cpp`:
- `if (argc < 2)` → saludo `HERMES`.
- `string comando = argv[1];` convierte C (`char*`) a `string` seguro.
- `if (comando == "--version") return version();`
- `if (comando == "job")` valida `argc < 3`, junta `vector<string> argumentos`, llama `Job job = crearJob(programa, argumentos);`, imprime `job.job_id`.
- `if (comando == "filter")` exige `argc < 4`, lee `tipoFiltro = argv[2]`, sub-despacha `filtrarPorId / filtrarPorStatus / filtrarPorPrograma`. Convierte id con `std::stoul(argv[3])`.
- Si nada coincide: `error("Comando no reconocido: ", comando); return 1;`

**Conceptos:** `0` = éxito, `1` = error. Compilador traduce cada `.cpp` a `.o` confiando en los `.h`; linker conecta al final.

**Regla de oro:** primero validar `argc`, después tocar `argv`. Evita leer memoria basura (crash) y operar con datos incompletos.

## Fase 3 — Módulos Core

**Regla:** `.h` promete, `.cpp` cumple. Protegido con `#ifndef JOB_H`.

- **status:** `enum class Status { QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED }` + `string statusToString(Status status);`. `status.cpp` traduce enum → texto con `switch`. Es el vocabulario común.
- **job (escritor):** `struct Job { job_id; programa; argumentos; Status status; }` + `Job crearJob(...)`. Depende de `status.h`. Flujo en `job.cpp`: lee `data/jobs.json` con `ifstream`, tolera `parse_error`, busca `siguienteId` con `contains("job_id")`, crea `job.status = Status::QUEUED;`, convierte a JSON, `push_back`, guarda con `dump(4)` vía `ofstream`, devuelve `Job`.
- **filter (lector):** `void filtrarPorId / filtrarPorStatus / filtrarPorPrograma`. Devuelven `void` (imprimen). Patrón repetido: abrir → validar `is_open()` → leer con `try` → recorrer `for (const auto& job : jobs)` → checar `contains` + tipo → imprimir con `cout` → si no hay, `error(...)`.
- **version + terminal.colors.h:** `version()` hace `info("version 0.1");`. `terminal.colors.h` define `error / warning / info` como `template <typename... Args>` en la cabecera (obligatorio para templates).
- **IPC / network / database:** hoy no existen como código. La persistencia la hacen a mano `job` y `filter` sobre el mismo archivo.

## Fase 4 — JSON con nlohmann/json.hpp

**Integración:** librería header-only vendorizada en `include/nlohmann/json.hpp`. Se usa con `#include <nlohmann/json.hpp>` + `using json = nlohmann::json;`.

Ciclo:
- `json jobs = json::array();` → arreglo válido aunque no haya archivo.
- `archivoLectura >> jobs;` → parsea texto a objetos (sin parser manual). Protegido con `catch (const json::parse_error&)`.
- `contains / is_number_unsigned / is_string / operator[] / push_back` → trabajo tipado y seguro.
- `archivoEscritura << jobs.dump(4);` → serializa bonito con indentación.

`job.cpp` escribe, `filter.cpp` lee. El JSON es el contrato de persistencia que los une sin llamarse entre ellos.

`ofstream archivoEscritura(archivoJobs);` crea el archivo si no existe, lo trunca si existe. Por eso borrar `jobs.json` solo reinicia el historial.

## Cómo conecta todo (lectura de 30 segundos)

1. `Makefile` junta todos los `.cpp` en el binario `hermes`.
2. `main.cpp` valida `argc/argv` y delega a `version`, `job` o `filter`.
3. `status` define el idioma de estados.
4. `job` crea Jobs (nacen `QUEUED`) y los guarda en `data/jobs.json` vía `nlohmann/json`.
5. `filter` lee ese mismo JSON y los muestra por `id / status / programa`.
6. `IPC / database / network` son el hueco futuro: centralizar persistencia y comunicación.

> Frase ancla: **el compilador confía, el linker cumple, el JSON persiste.**
