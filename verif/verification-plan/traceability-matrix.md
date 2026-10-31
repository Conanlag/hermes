# Matriz de Trazabilidad y VerificaciÃ³n
**Estado:** Avance 1

| Req ID   | Descripcionn breve   | Prioridad   | Metodo   | Caso(s)   | Evidencia   | Resultado   | Defecto/Excepcion   |
|:---------|:--------------------|:------------|:---------|:----------|:------------|:------------|:--------------------|
| RF-01    | Envi­o de comando/programa y generacion de ID unico | Alta | Prueba | TC-001    | verif/scripts/TC-001.sh + verif/results/tc001.log ([PASS]) | PASS        | -                   |
| RF-02    | Validacion de solicitudes con mensaje util | Alta        | Prueba  | TC-001    | verif/scripts/TC-001.sh + verif/results/tc001.log ([PASS]) | PASS        | -                   |
| RF-03    | Cola inicial cuando no hay capacidad inmediata | Alta        | Prueba  | TC-002    | verif/scripts/TC-002.sh + verif/results/tc002.log ([PASS]) | PASS | -                   |
| RF-04    |                     |             |          |           |             | Pendiente   |                     |
| RF-05    | Máximo configurable de trabajos simultáneos | Alta | Prueba | TC-024 | verif/scripts/TC-024.sh ([PASS]) | PASS | - |
| RF-06    | Estados QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED, INTERRUPTED | CrÃ­tica     | Prueba  | TC-003    | verif/scripts/TC-003.sh + verif/results/tc003.log ([PASS]) | PASS        | -                   |
| RF-07    | Tiempos de recepcion, inicio, terminaciÃ³n y cÃ³digo de salida | Alta        | Prueba  | TC-003, TC-006 | tc003.log + tc006.log ([PASS]) | PASS        | -                   |
| RF-08    | Consulta de un trabajo mediante ID | Alta        | Prueba  | TC-004    | verif/scripts/TC-004.sh + verif/results/tc004.log ([PASS]) | PASS        | -                   |
| RF-09    | Listado de trabajos con filtros basicos por estado | Alta        | Prueba  | TC-004    | verif/scripts/TC-004.sh + verif/results/tc004.log ([PASS]) | PASS        | -                   |
| RF-10    | Cancelacion de trabajo en ejecucion con resultado reflejado | CrÃ­tica     | Prueba  | TC-005    | verif/scripts/TC-005.sh + verif/results/tc005.log ([PASS]) | PASS        | -                   |
| RF-11    | Captura separada de stdout y stderr | Alta        | Prueba  | TC-006    | verif/scripts/TC-006.sh + verif/results/tc006.log ([PASS]) | PASS        | -                   |
| RF-12    | Persistencia de metadatos y resultados tras reinicio del scheduler | Alta | Prueba | TC-007 | verif/scripts/TC-007.sh + verif/results/results_TC-007.md ([PASS]) | PASS | - |
| RF-13    | Recuperación tras reinicio: ningún RUNNING sobrevive, sin huérfanos y persistencia durable | Alta | Prueba | TC-007 | verif/scripts/TC-007.sh + verif/results/results_TC-007.md ([PASS]) | PASS | - |
| RF-14    |                     |             |          |           |             | Pendiente   |                     |
| RF-15    |                     |             |          |           |             | Pendiente   |                     |
| RF-16    |                     |             |          |           |             | Pendiente   |                     |
| RF-17    | Ayuda de uso y codigos de salida adecuados | Media | Prueba  | TC-015 | verif/scripts/TC-015.sh + verif/results/tc015.log ([PASS]) | PASS | -                   |
| RF-18    |                     |             |          |           |             | Pendiente   |                     |
| RF-19    |                     |             |          |           |             | Pendiente   |                     |
| RF-20    |                     |             |          |           |             | Pendiente   |                     |
| RF-21    |                     |             |          |           |             | Pendiente   |                     |
| RF-22    |                     |             |          |           |             | Pendiente   |                     |
| RF-23    | Rechazo y registro de solicitudes que exceden límites configurados | Alta | Prueba | TC-023 | verif/scripts/TC-023.sh ([PASS]); eventos WARN en events.jsonl | PASS | - |
| RF-24    |                     |             |          |           |             | Pendiente   |                     |
| RF-25    | Rechazo explícito al alcanzar capacidad configurada de cola | Alta | Prueba | TC-023 | verif/scripts/TC-023.sh | Pendiente | - |
| RF-26    | Cancelaciones concurrentes coherentes | Crítica | Prueba | TC-017 | verif/scripts/TC-017.sh + verif/results/tc017.log ([PASS]) | PASS | - |
| RF-27    | Solicitudes repetidas no crean Jobs contradictorios | Alta | Prueba | TC-017 | verif/scripts/TC-017.sh + verif/results/tc017.log ([PASS]) | PASS | - |
| RF-29 | Detección determinista de muerte por señales, liberación de descriptores/tuberías y volcado de diagnóstico `FAILED`. | Alta | Prueba | TC-020 | Salida de script TC-020.sh + verif/results/tc020.log ([PASS]) | Pass | - |
| RNF-01   | Compila y se ejecuta en distro Linux declarada | Alta        | Prueba  | TC-014    | verif/scripts/TC-014.sh + verif/results/tc014.log ([PASS]) | PASS        | -                   |
| RNF-02   | ConstrucciÃ³n reproducible desde clon limpio | Alta        | Prueba  | TC-014    | verif/scripts/TC-014.sh + verif/results/tc014.log ([PASS]) | PASS        | -                   |
| RNF-03   | Sin privilegios root en operaciÃ³n normal | Media       | Prueba  | TC-014    | verif/scripts/TC-014.sh + verif/results/tc014.log ([PASS]) | PASS        | -                   |
| RNF-04   |                     |             |          |           |             | Pendiente   |                     |
| RNF-05   | Consulta de estado en menos de 1 s con 100 Jobs | Alta | Prueba | TC-018 | verif/scripts/TC-018.sh; evidencia acumulada en verif/results/results_TC-018.md | PASS | - |
| RNF-06   | Conservación de metadatos para al menos 500 Jobs | Alta | Prueba | TC-018 | verif/scripts/TC-018.sh; fixture de 519 registros validado | PASS | - |
| RNF-07   |                     |             |          |           |             | Pendiente   |                     |
| RNF-08   | Solicitud invalida no termina el servicio (local; desconexion en Fase 2) | Alta | Prueba | TC-008 | verif/scripts/TC-008.sh + verif/results/tc008.log ([PASS]) | PASS | -                   |
| RNF-09   | TerminaciÃ³n anormal de un trabajo no afecta a otros | Alta | Prueba | TC-008 | verif/scripts/TC-008.sh + verif/results/tc008.log ([PASS]) | PASS | -                   |
| RNF-10 | Prevención de falsos positivos en supervisión: tras un reinicio, el sistema no reportará como RUNNING a procesos huérfanos. | Crítica | Prueba | TC-007 | verif/scripts/TC-007.sh + verif/results/results_TC-007.md ([PASS]) | Pendiente | - |
| RNF-11 | Escritura atómica y duradera (O_EXCL, fsync, rename) para evitar dejar jobs.json parcialmente actualizado o corrupto. | Crítica | Prueba | TC-007 | verif/scripts/TC-007.sh + verif/results/results_TC-007.md ([PASS]) | Pendiente | - |
| RNF-12   |                     |             |          |           |             | Pendiente   |                     |
| RNF-13   |                     |             |          |           |             | Pendiente   |                     |
| RNF-14   |                     |             |          |           |             | Pendiente   |                     |
| RNF-15   |                     |             |          |           |             | Pendiente   |                     |
| RNF-16   |                     |             |          |           |             | Pendiente   |                     |
| RNF-17   |                     |             |          |           |             | Pendiente   |                     |
| RNF-18   |                     |             |          |           |             | Pendiente   |                     |
| RNF-19   |                     |             |          |           |             | Pendiente   |                     |
| RNF-20   |                     |             |          |           |             | Pendiente   |                     |
| RNF-21   | Mensajes de error con operación, causa y acción sugerida | Media | Prueba | TC-015 | verif/scripts/TC-015.sh + verif/results/tc015.log ([PASS]) | PASS | -                   |
| RNF-22   |                     |             |          |           |             | Pendiente   |                     |
| RNF-23   | Guía permite instalar, enviar y consultar sin asistencia | Media       | Prueba  | TC-015    | verif/scripts/TC-015.sh + verif/results/tc015.log ([PASS]) | PASS        | -                   |
| RNF-24   |                     |             |          |           |             | Pendiente   |                     |
| RNF-25   |                     |             |          |           |             | Pendiente   |                     |
| RNF-26   |                     |             |          |           |             | Pendiente   |                     |
| RNF-33   | Liberación de memoria, procesos, archivos y sockets después de estrés | Alta | Prueba de estrés | TC-020 | verif/scripts/TC-020.sh + verif/results/results_TC-020.md | Parcial | No hay uso de sockets implementado; falta validar su ciclo de vida. |
| RNF-27   | Transiciones de estado consistentes ante solicitudes concurrentes | Crítica | Prueba | TC-017 | verif/scripts/TC-017.sh + verif/results/tc017.log ([PASS]) | PASS | - |
| RNF-30   | Sin huérfanos: terminación de grupo, PDEATHSIG y cierre ordenado | Alta | Prueba | TC-020 | verif/scripts/TC-020.sh + verif/results/tc020.log; casos| PASS | - |
| RNF-31   | Clasificación explícita y fail-closed: INTERRUPTED con motivo | Alta | Prueba | TC-022, TC-016 | verif/scripts/TC-022.sh; casos (d), (e), (i); TC-016 | PASS | - |
