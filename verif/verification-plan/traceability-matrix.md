# Matriz de Trazabilidad y VerificaciÃ³n
**Estado:** Avance 1

| Req ID   | DescripciÃ³n breve   | Prioridad   | MÃ©todo   | Caso(s)   | Evidencia   | Resultado   | Defecto/ExcepciÃ³n   |
|:---------|:--------------------|:------------|:---------|:----------|:------------|:------------|:--------------------|
| RF-01    | EnvÃ­o de comando/programa y generaciÃ³n de ID Ãºnico | Alta        | Prueba  | TC-001    | verif/scripts/TC-001.sh + verif/results/tc001.log ([PASS]) | PASS        | -                   |
| RF-02    | ValidaciÃ³n de solicitudes con mensaje Ãºtil | Alta        | Prueba  | TC-001    | verif/scripts/TC-001.sh + verif/results/tc001.log ([PASS]) | PASS        | -                   |
| RF-03    | Cola inicial cuando no hay capacidad inmediata | Alta        | Prueba  | TC-002    | verif/scripts/TC-002.sh + verif/results/tc002.log (corrida 1: FAIL, en diagnÃ³stico) | Pendiente   | -                   |
| RF-04    |                     |             |          |           |             | Pendiente   |                     |
| RF-05    |                     |             |          |           |             | Pendiente   |                     |
| RF-06    | Estados QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED | CrÃ­tica     | Prueba  | TC-003    | verif/scripts/TC-003.sh + verif/results/tc003.log ([PASS]) | PASS        | -                   |
| RF-07    | Tiempos de recepciÃ³n, inicio, terminaciÃ³n y cÃ³digo de salida | Alta        | Prueba  | TC-003, TC-006 | tc003.log + tc006.log ([PASS]) | PASS        | -                   |
| RF-08    | Consulta de un trabajo mediante ID | Alta        | Prueba  | TC-004    | verif/scripts/TC-004.sh + verif/results/tc004.log ([PASS]) | PASS        | -                   |
| RF-09    | Listado de trabajos con filtros bÃ¡sicos por estado | Alta        | Prueba  | TC-004    | verif/scripts/TC-004.sh + verif/results/tc004.log ([PASS]) | PASS        | -                   |
| RF-10    | CancelaciÃ³n de trabajo en ejecuciÃ³n con resultado reflejado | CrÃ­tica     | Prueba  | TC-005    | verif/scripts/TC-005.sh + verif/results/tc005.log ([PASS]) | PASS        | -                   |
| RF-11    | Captura separada de stdout y stderr | Alta        | Prueba  | TC-006    | verif/scripts/TC-006.sh + verif/results/tc006.log ([PASS]) | PASS        | -                   |
| RF-12    |                     |             |          |           |             | Pendiente   |                     |
| RF-13    |                     |             |          |           |             | Pendiente   |                     |
| RF-14    |                     |             |          |           |             | Pendiente   |                     |
| RF-15    |                     |             |          |           |             | Pendiente   |                     |
| RF-16    |                     |             |          |           |             | Pendiente   |                     |
| RF-17    | Ayuda de uso y cÃ³digos de salida adecuados | Media       | Prueba  | TC-015    | verif/scripts/TC-015.sh + verif/results/tc015.log ([PASS]) | PASS        | -                   |
| RF-18    |                     |             |          |           |             | Pendiente   |                     |
| RF-19    |                     |             |          |           |             | Pendiente   |                     |
| RF-20    |                     |             |          |           |             | Pendiente   |                     |
| RF-21    |                     |             |          |           |             | Pendiente   |                     |
| RF-22    |                     |             |          |           |             | Pendiente   |                     |
| RF-23    |                     |             |          |           |             | Pendiente   |                     |
| RF-24    |                     |             |          |           |             | Pendiente   |                     |
| RNF-01   | Compila y se ejecuta en distro Linux declarada | Alta        | Prueba  | TC-014    | verif/scripts/TC-014.sh + verif/results/tc014.log ([PASS]) | PASS        | -                   |
| RNF-02   | ConstrucciÃ³n reproducible desde clon limpio | Alta        | Prueba  | TC-014    | verif/scripts/TC-014.sh + verif/results/tc014.log ([PASS]) | PASS        | -                   |
| RNF-03   | Sin privilegios root en operaciÃ³n normal | Media       | Prueba  | TC-014    | verif/scripts/TC-014.sh + verif/results/tc014.log ([PASS]) | PASS        | -                   |
| RNF-04   |                     |             |          |           |             | Pendiente   |                     |
| RNF-05   |                     |             |          |           |             | Pendiente   |                     |
| RNF-06   |                     |             |          |           |             | Pendiente   |                     |
| RNF-07   |                     |             |          |           |             | Pendiente   |                     |
| RNF-08   | Solicitud invÃ¡lida no termina el servicio (local; desconexiÃ³n en Fase 2) | Alta        | Prueba  | TC-008    | verif/scripts/TC-008.sh + verif/results/tc008.log ([PASS]) | PASS        | -                   |
| RNF-09   | TerminaciÃ³n anormal de un trabajo no afecta a otros | Alta        | Prueba  | TC-008    | verif/scripts/TC-008.sh + verif/results/tc008.log ([PASS]) | PASS        | -                   |
| RNF-10   |                     |             |          |           |             | Pendiente   |                     |
| RNF-11   |                     |             |          |           |             | Pendiente   |                     |
| RNF-12   |                     |             |          |           |             | Pendiente   |                     |
| RNF-13   |                     |             |          |           |             | Pendiente   |                     |
| RNF-14   |                     |             |          |           |             | Pendiente   |                     |
| RNF-15   |                     |             |          |           |             | Pendiente   |                     |
| RNF-16   |                     |             |          |           |             | Pendiente   |                     |
| RNF-17   |                     |             |          |           |             | Pendiente   |                     |
| RNF-18   |                     |             |          |           |             | Pendiente   |                     |
| RNF-19   |                     |             |          |           |             | Pendiente   |                     |
| RNF-20   |                     |             |          |           |             | Pendiente   |                     |
| RNF-21   | Mensajes de error con operación, causa y acción sugerida | Media       | Prueba  | TC-015    | verif/scripts/TC-015.sh + verif/results/tc015.log ([PASS]) | PASS        | -                   |
| RNF-22   |                     |             |          |           |             | Pendiente   |                     |
| RNF-23   | Guía permite instalar, enviar y consultar sin asistencia | Media       | Prueba  | TC-015    | verif/scripts/TC-015.sh + verif/results/tc015.log ([PASS]) | PASS        | -                   |
| RNF-24   |                     |             |          |           |             | Pendiente   |                     |
| RNF-25   |                     |             |          |           |             | Pendiente   |                     |
| RNF-26   |                     |             |          |           |             | Pendiente   |                     |
