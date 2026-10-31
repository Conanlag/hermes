# Matriz de Trazabilidad y VerificaciÃ³n
**Estado:** Avance 1

| Req ID   | Descripcionn breve   | Prioridad   | Metodo   | Caso(s)   | Evidencia   | Resultado   | Defecto/Excepcion   |
|:---------|:--------------------|:------------|:---------|:----------|:------------|:------------|:--------------------|
| RF-01    | Envi­o de comando/programa y generacion de ID unico | Alta | Prueba | TC-001    | verif/scripts/TC-001.sh + verif/results/tc001.log ([PASS]) | PASS        | -                   |
| RF-02    | Validacion de solicitudes con mensaje util | Alta        | Prueba  | TC-001    | verif/scripts/TC-001.sh + verif/results/tc001.log ([PASS]) | PASS        | -                   |
| RF-03    | Cola inicial cuando no hay capacidad inmediata | Alta        | Prueba  | TC-002    | verif/scripts/TC-002.sh + verif/results/tc002.log ([PASS]) | PASS | -                   |
| RF-04    |                     |             |          |           |             | Pendiente   |                     |
| RF-05    | Máximo configurable de trabajos simultáneos | Alta | Prueba | TC-025 | verif/scripts/TC-025.sh; verif/results/results.md ([PASS], 2026-10-30) | PASS | - |
| RF-06    | Estados QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED, INTERRUPTED | CrÃ­tica     | Prueba  | TC-003    | verif/scripts/TC-003.sh + verif/results/tc003.log ([PASS]) | PASS        | -                   |
| RF-07    | Tiempos de recepciÃ³n, inicio, terminaciÃ³n y cÃ³digo de salida | Alta        | Prueba  | TC-003, TC-006 | tc003.log + tc006.log ([PASS]) | PASS        | -                   |
| RF-08    | Consulta de un trabajo mediante ID | Alta        | Prueba  | TC-004    | verif/scripts/TC-004.sh + verif/results/tc004.log ([PASS]) | PASS        | -                   |
| RF-09    | Listado de trabajos con filtros bÃ¡sicos por estado | Alta        | Prueba  | TC-004    | verif/scripts/TC-004.sh + verif/results/tc004.log ([PASS]) | PASS        | -                   |
| RF-10    | CancelaciÃ³n de trabajo en ejecuciÃ³n con resultado reflejado | CrÃ­tica     | Prueba  | TC-005    | verif/scripts/TC-005.sh + verif/results/tc005.log ([PASS]) | PASS        | -                   |
| RF-11    | Captura separada de stdout y stderr | Alta        | Prueba  | TC-006    | verif/scripts/TC-006.sh + verif/results/tc006.log ([PASS]) | PASS        | -                   |
| RF-12    | Persistencia de metadatos y resultados tras reinicio del scheduler | Alta | Prueba | TC-016 | verif/scripts/TC-016.sh + verif/results/results_TC-016.md ([PASS]) | PASS | - |
| RF-13    | Recuperación tras reinicio: ningún RUNNING sobrevive, sin huérfanos y persistencia durable | Alta | Prueba | TC-022, TC-016 | verif/scripts/TC-022.sh; verif/results/results_TC-022.md ([PASS]); TC-016 ([PASS]) | PASS | - |
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
| RF-26    | Cancelaciones concurrentes coherentes | Alta | Prueba | TC-019 | verif/scripts/TC-019.sh; 10/10 iteraciones ([PASS]); verif/results/results_TC-019.md | PASS | - |
| RF-27    | Solicitudes repetidas no crean Jobs contradictorios | Alta | Prueba | TC-017, TC-018 | verif/scripts/TC-017.sh ([PASS]); TC-018 ejecutado 2026-10-30 21:48:51 -0600 ([PASS], código 0); verif/results/results_TC-018.md | PASS | - |
| RF-30    | Escalamiento forzoso tras ignorar SIGTERM durante el periodo de gracia de 5 segundos | No especificada | Prueba | TC-021 | verif/scripts/TC-021.sh; verif/results/tc021.log ([PASS], código 0) | PASS | - |
| RNF-01   | Compila y se ejecuta en distro Linux declarada | Alta        | Prueba  | TC-014    | verif/scripts/TC-014.sh + verif/results/tc014.log ([PASS]) | PASS        | -                   |
| RNF-02   | ConstrucciÃ³n reproducible desde clon limpio | Alta        | Prueba  | TC-014    | verif/scripts/TC-014.sh + verif/results/tc014.log ([PASS]) | PASS        | -                   |
| RNF-03   | Sin privilegios root en operaciÃ³n normal | Media       | Prueba  | TC-014    | verif/scripts/TC-014.sh + verif/results/tc014.log ([PASS]) | PASS        | -                   |
| RNF-04   |                     |             |          |           |             | Pendiente   |                     |
| RNF-05   | Consulta de programa en menos de 1 s con al menos 100 Jobs | Alta | Prueba | TC-004 | verif/scripts/TC-004.sh; verif/results/tc004.log (100 Jobs en 0.013 s, [PASS]) | PASS | - |
| RNF-06   | Conservación de metadatos para al menos 500 Jobs | Alta | Prueba | TC-018 | verif/scripts/TC-018.sh; fixture de 519 registros validado | PASS | - |
| RNF-07   |                     |             |          |           |             | Pendiente   |                     |
| RNF-08   | Solicitud invalida no termina el servicio (local; desconexion en Fase 2) | Alta | Prueba | TC-008 | verif/scripts/TC-008.sh + verif/results/tc008.log ([PASS]) | PASS | -                   |
| RNF-09   | TerminaciÃ³n anormal de un trabajo no afecta a otros | Alta | Prueba | TC-008 | verif/scripts/TC-008.sh + verif/results/tc008.log ([PASS]) | PASS | -                   |
| RNF-10   | Ningún Job queda RUNNING si el demonio muere; recuperación al arrancar | Alta | Prueba | TC-022 | verif/scripts/TC-022.sh; casos (b), (c), (h) | PASS | - |
| RNF-11   | Persistencia durable: jobs.json sobrevive a kill -9 y siempre parsea | Alta | Prueba | TC-022 | verif/scripts/TC-022.sh; casos (f) y (g) | PASS | - |
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
| RNF-33   | Liberación de memoria, procesos, archivos y sockets después de estrés | Alta | Prueba de estrés | TC-024 | verif/scripts/TC-024.sh + verif/results/results_TC-024.md | Parcial | No hay uso de sockets implementado; falta validar su ciclo de vida. |
| RNF-27   | Transiciones de estado consistentes ante solicitudes concurrentes | Alta | Prueba de concurrencia | TC-019 | verif/scripts/TC-019.sh; 10 iteraciones ([PASS]); verif/results/results_TC-019.md | PASS | - |
| RNF-28   | Persistencia atómica o recuperable tras una interrupción durante la escritura | Alta | Prueba | TC-022 | verif/scripts/TC-022.sh; caso (f); verif/results/results_TC-022.md (2026-10-30, [PASS]) | PASS | - |
| RNF-30   | Sin huérfanos: terminación de grupo, PDEATHSIG y cierre ordenado | Alta | Prueba | TC-022 | verif/scripts/TC-022.sh; casos (a), (b), (c), (h) | PASS | - |
| RNF-31   | Clasificación explícita y fail-closed: INTERRUPTED con motivo | Alta | Prueba | TC-022, TC-016 | verif/scripts/TC-022.sh; casos (d), (e), (i) ([PASS], 2026-10-30); TC-016 | PASS | - |
