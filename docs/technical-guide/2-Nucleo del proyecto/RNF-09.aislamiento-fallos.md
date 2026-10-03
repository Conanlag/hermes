# RNF-09 — Fallo de un trabajo no afecta a otros

## Descripción

Hermes ejecuta cada trabajo en su propio proceso Linux (`fork` + `execvp`) bajo su propio supervisor huérfano, con su propio pipe de `stderr` y su propio `waitpid` sobre su PID. No existe memoria, hilo ni descriptor compartido entre trabajos, y el CLI es de vida corta: cada invocación nace, delega y termina. Por diseño, la terminación anormal de un trabajo (código distinto de cero, señal o programa inexistente) solo marca su propio resultado y deja intactos a los demás.

Las escrituras concurrentes al estado se serializan con `flock(LOCK_EX)` en `modificarJobs`, y las lecturas toleran archivo inexistente o corrupto devolviendo arreglo vacío. El supervisor que muere lo hace con `_exit` en su propio proceso hijo, sin arrastrar al padre ni a otros supervisores.

**Dictamen: CUMPLE.** Verificado en WSL con tres escenarios (paso 1–3 en la métrica). Observación fuera del requisito: `crearJob` genera ID con `leerJobs` + `guardarJobs` sin `flock`, por lo que dos creaciones en el mismo milisegundo podrían colisionar ID. No es cascada de fallos y no invalida este RNF; se propone como mejora separada.

---

## Categoría (Rendimiento, Seguridad, Escalabilidad, Mantenibilidad, Portabilidad, Confiabilidad).

Confiabilidad (aislamiento de fallos).

---

## Métrica de Aceptación (Medible)

Tres escenarios, todos con resultado PASS en WSL:

1. **Fallo normal vs éxito:** `job false` → `FAILED` (ID 9), `job true` → `SUCCEEDED` (ID 10), más 6 `SUCCEEDED` históricos intactos. Criterio: ningún otro Job cambia de estado.
2. **Señal a uno:** `job sleep 30` (ID 11, `RUNNING`) + `job echo vivo` (ID 12, `SUCCEEDED`); `cancel 11` → `CANCELED`; los `echo` (IDs 4, 8, 12) idénticos antes y después. Criterio: el `SIGTERM` solo afecta a su PID.
3. **Programa inexistente:** `job programa_que_no_existe_xyz` (ID 13) emite `No se pudo ejecutar... No such file` por su propio pipe; los 7 `sleep` conservan sus estados. Criterio: el `execvp` fallido (`_exit(127)`) no mancha a los demás.

Comando de construcción usado: `g++ -Wall -Wextra -std=c++17 -Iinclude src/cancel/cancel.cpp src/filter/filter.cpp src/job/job.cpp src/main.cpp src/process/process.cpp src/status/status.cpp src/validator/validator.cpp src/version/version.cpp -o hermes`.

---

## Módulos o Componentes Afectados

- `src/process/process.cpp` (`iniciarProceso` con `fork`/`execvp`/`_exit(127)`, `esperarProceso` con `waitpid` específico, `terminarProceso` con `kill/SIGTERM`).
- `src/job/job.cpp` (supervisor por Job en `supervisarJob`, `leerStderrProceso` con pipe propio, `modificarJobs` con `flock`, `leerJobs` tolerante).
- `src/filter/filter.cpp` (consultas de solo lectura; no modifican estado).
- `data/jobs.json` (estado compartido solo bajo lock).

---

## Restricciones Tecnológicas o de Arquitectura

POSIX/Linux (`fork`, `execvp`, `waitpid`, `pipe`, `dup2`, `kill`, `flock`) vía WSL; sin demonio central persistente. La garantía vale mientras cada Job conserve proceso, pipe y supervisor propios y toda escritura pase por `modificarJobs`.

---
