# Minuta 06 — Seguimiento y organización de casos de prueba

Proyecto: Hermes\
Tema: Organización, actualización y creación de casos de prueba (TC)\
Fecha: 2 de noviembre de 2026\
Participantes: Alberto, Alan

## Objetivo

Dar seguimiento a la organización de los casos de prueba de Hermes, establecer la distribución de responsabilidades entre Alberto y Alan, e identificar las pruebas pendientes de actualización, creación o validación.

## Temas revisados

Se revisó el estado de los casos de prueba relacionados con la administración de trabajos, concurrencia, persistencia, cancelación, recuperación y manejo de errores.

Se estableció la siguiente distribución de responsabilidades para QA:

Alberto

- TC-004 — Consultar y listar.
- TC-018 — Solicitud duplicada.
- TC-021 — Escalamiento de cancelación.
- TC-022 — Interrupción durante persistencia.
- TC-024 — Liberación de recursos bajo carga.

Alan

- TC-002 — Cola y límite de concurrencia.
- TC-005 — Cancelar en cola y ejecución.
- TC-006 — Capturar stdout/stderr y código.
- TC-007 — Reinicio y recuperación.
- TC-008 — Aislamiento de fallo.
- TC-016 — Saturación de cola y rechazo explícito.
- TC-017 — Cancelaciones concurrentes.
- TC-020 — Terminación inesperada del proceso hijo.

## Actualización y creación de casos de prueba

Se identificaron los casos que requieren actualización y aquellos que todavía deben crearse.

Casos por actualizar:

- TC-004 — Consultar y listar.
- TC-005 — Cancelar en cola y ejecución.
- TC-006 — Capturar stdout/stderr y código.
- TC-008 — Aislamiento de fallo.

Casos por crear:

- TC-017 — Cancelaciones concurrentes.
- TC-018 — Solicitud duplicada.
- TC-020 — Terminación inesperada del proceso hijo.
- TC-021 — Escalamiento de cancelación.
- TC-022 — Interrupción durante persistencia.
- TC-024 — Liberación de recursos bajo carga.

## Pruebas pendientes de validación

Se identificaron tres casos de prueba cuya ejecución y validación dependen de que se complete la implementación y verificación de la capacidad de la cola:

- TC-002 — Cola y límite de concurrencia.
- TC-007 — Reinicio y recuperación.
- TC-016 — Saturación de cola y rechazo explícito.

Estos casos permanecerán pendientes hasta que se complete la funcionalidad correspondiente y sea posible verificar su comportamiento.

## Acuerdos

Se acordó mantener la distribución de los casos de prueba entre Alberto y Alan para organizar el trabajo de QA.

Alberto dará seguimiento a los casos TC-004, TC-018, TC-021, TC-022 y TC-024.

Alan dará seguimiento a los casos TC-002, TC-005, TC-006, TC-007, TC-008, TC-016, TC-017 y TC-020.

Los casos pendientes de creación deberán documentar sus escenarios, condiciones de ejecución y resultados esperados.

Los casos que requieren actualización deberán revisarse para asegurar que correspondan con el comportamiento actual del sistema.

La validación de TC-002, TC-007 y TC-016 quedará condicionada a la finalización de los trabajos relacionados con la capacidad y el comportamiento de la cola.

## Resultado

Se estableció una distribución de 13 casos de prueba entre Alberto y Alan, identificando las actividades de actualización, creación y validación pendientes.

Se determinó que TC-002, TC-007 y TC-016 requieren esperar la finalización de la implementación relacionada con la cola antes de completar su validación.

Finalmente, se definió continuar con la actualización y creación de los casos de prueba para mantener la trazabilidad entre los requisitos funcionales y las pruebas correspondientes.