# Matriz de Trazabilidad y Verificación
**Estado:** Avance 1

| Req ID   | Descripción breve   | Prioridad   | Método   | Caso(s)   | Evidencia   | Resultado   | Defecto/Excepción   |
|:---------|:--------------------|:------------|:---------|:----------|:------------|:------------|:--------------------|
| RF-01    | Envío de comando/programa y generación de ID único | Alta        | Prueba  | TC-001    | salida consola + jobs.json | Pendiente   | -                   |
| RF-02    | Validación de solicitudes con mensaje útil | Alta        | Prueba  | TC-001    | salida consola (stdout/stderr) + código de salida | Pendiente   | -                   |
| RF-03    | Cola inicial cuando no hay capacidad inmediata | Alta        | Prueba  | TC-002    | jobs.json + salida consola | Pendiente   | -                   |
| RF-04    |                     |             |          |           |             | Pendiente   |                     |
| RF-05    |                     |             |          |           |             | Pendiente   |                     |
| RF-06    | Estados QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED | Crítica     | Prueba  | TC-003    | salida consola + jobs.json | Pendiente   | -                   |
| RF-07    | Tiempos de recepción, inicio, terminación y código de salida | Alta        | Prueba  | TC-003, TC-006 | jobs.json (marcas de tiempo) | Pendiente   | -                   |
| RF-08    | Consulta de un trabajo mediante ID | Alta        | Prueba  | TC-004    | salida consola + jobs.json | Pendiente   | -                   |
| RF-09    | Listado de trabajos con filtros básicos por estado | Alta        | Prueba  | TC-004    | salida consola | Pendiente   | -                   |
| RF-10    | Cancelación de trabajo en ejecución con resultado reflejado | Crítica     | Prueba  | TC-005    | salida consola + jobs.json | Pendiente   | -                   |
| RF-11    | Captura separada de stdout y stderr | Alta        | Prueba  | TC-006    | salida consola (stdout/stderr separados) | Pendiente   | -                   |
| RF-12    |                     |             |          |           |             | Pendiente   |                     |
| RF-13    |                     |             |          |           |             | Pendiente   |                     |
| RF-14    |                     |             |          |           |             | Pendiente   |                     |
| RF-15    |                     |             |          |           |             | Pendiente   |                     |
| RF-16    |                     |             |          |           |             | Pendiente   |                     |
| RF-17    | Ayuda de uso y códigos de salida adecuados | Media       | Prueba  | TC-015    | salida consola + códigos de salida | Pendiente   | -                   |
| RF-18    |                     |             |          |           |             | Pendiente   |                     |
| RF-19    |                     |             |          |           |             | Pendiente   |                     |
| RF-20    |                     |             |          |           |             | Pendiente   |                     |
| RF-21    |                     |             |          |           |             | Pendiente   |                     |
| RF-22    |                     |             |          |           |             | Pendiente   |                     |
| RF-23    |                     |             |          |           |             | Pendiente   |                     |
| RF-24    |                     |             |          |           |             | Pendiente   |                     |
| RNF-01   | Compila y se ejecuta en distro Linux declarada | Alta        | Prueba  | TC-014    | log de compilación + humo funcional | Pendiente   | -                   |
| RNF-02   | Construcción reproducible desde clon limpio | Alta        | Prueba  | TC-014    | clon fresco + log de compilación | Pendiente   | -                   |
| RNF-03   | Sin privilegios root en operación normal | Media       | Prueba  | TC-014    | whoami + ejecución sin sudo | Pendiente   | -                   |
| RNF-04   |                     |             |          |           |             | Pendiente   |                     |
| RNF-05   |                     |             |          |           |             | Pendiente   |                     |
| RNF-06   |                     |             |          |           |             | Pendiente   |                     |
| RNF-07   |                     |             |          |           |             | Pendiente   |                     |
| RNF-08   | Solicitud inválida no termina el servicio (local; desconexión en Fase 2) | Alta        | Prueba  | TC-008    | salida consola + códigos de salida | Pendiente   | -                   |
| RNF-09   | Terminación anormal de un trabajo no afecta a otros | Alta        | Prueba  | TC-008    | salida consola + jobs.json | Pendiente   | -                   |
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
| RNF-21   | Mensajes de error con operación, causa y acción sugerida | Media       | Prueba  | TC-015    | salida de errores | Pendiente   | -                   |
| RNF-22   |                     |             |          |           |             | Pendiente   |                     |
| RNF-23   | Guía permite instalar, enviar y consultar sin asistencia | Media       | Prueba  | TC-015    | guía + flujo completo | Pendiente   | -                   |
| RNF-24   |                     |             |          |           |             | Pendiente   |                     |
| RNF-25   |                     |             |          |           |             | Pendiente   |                     |
| RNF-26   |                     |             |          |           |             | Pendiente   |                     |
