# Minuta 04 — Organización de RF para el avance 02

**Proyecto:** Hermes  
**Tema:** Organización de requisitos funcionales, asignación de responsabilidades y seguimiento de pruebas  
**Fecha:** 13 de octubre de 2026  
**Participantes:** Alberto, Arturo, Alan

## Objetivo

Organizar los requisitos funcionales correspondientes al avance 02 de Hermes, establecer responsables para su desarrollo y seguimiento, y relacionarlos con los casos de prueba necesarios para verificar su cumplimiento.

## Temas revisados

Se revisaron los requisitos funcionales relacionados con la concurrencia, persistencia, recuperación, cancelación y administración de trabajos.

Se estableció la siguiente distribución de responsabilidades:

**Daniel**
- RF-05 — Máximo configurable de trabajos simultáneos.
- RF-23 — Rechazo y registro de solicitudes que excedan límites.
- RF-25 — Rechazo explícito cuando la cola está llena.

**Alberto**
- RF-12 — Persistencia de metadatos y resultados.
- RF-26 — Cancelaciones concurrentes coherentes.
- RF-27 — Semántica para solicitudes duplicadas.
- RF-30 — Política de escalamiento de cancelación.

**Alan**
- RF-13 — Recuperación después de reinicio.
- RF-14 — Bitácora de eventos y errores.
- RF-29 — Manejo de terminación inesperada de procesos hijo.

Se identificaron los siguientes registros de seguimiento en GitHub:

- RF-05 — Issue #8.
- RF-12 — Issue #12.
- RF-13 — Issue #13.
- RF-14 — Issue #14.
- RF-23 — Issue #15.
- RF-25 — Issue #16.
- RF-26 — Issue #17.
- RF-27 — Issue #18.
- RF-29 — Issue #19.
- RF-30 — Issue #20.

## Organización de casos de prueba

Se revisaron los casos de prueba relacionados con los requisitos funcionales y se estableció la siguiente distribución para QA.

**Alberto**
- TC-004 — Consultar y listar.
- TC-018 — Solicitud duplicada.
- TC-021 — Escalamiento de cancelación.
- TC-022 — Interrupción durante persistencia.
- TC-024 — Liberación de recursos bajo carga.

**Alan**
- TC-002 — Cola y límite de concurrencia.
- TC-005 — Cancelar en cola y ejecución.
- TC-006 — Capturar stdout/stderr y código.
- TC-007 — Reinicio y recuperación.
- TC-008 — Aislamiento de fallo.
- TC-016 — Saturación de cola y rechazo explícito.
- TC-017 — Cancelaciones concurrentes.
- TC-020 — Terminación inesperada del proceso hijo.

Los casos TC-002, TC-007 y TC-016 quedaron sujetos a la finalización y verificación de la capacidad de la cola antes de completar su validación.

## Acuerdos

Se acordó mantener la asignación de requisitos funcionales por responsable para facilitar el seguimiento del avance 02.

Cada responsable deberá verificar que su implementación corresponda con el comportamiento esperado y mantener actualizada la documentación relacionada.

QA continuará con la actualización y creación de casos de prueba, procurando que cada requisito funcional tenga pruebas que permitan comprobar su comportamiento.

Los casos de prueba deberán documentar los resultados obtenidos y los problemas encontrados durante su ejecución.

## Resultado

Se organizó la distribución de los requisitos funcionales del avance 02 entre los responsables correspondientes.

También se estableció la asignación de casos de prueba entre Alberto y Alan, identificando los casos que requieren esperar la verificación de la capacidad de la cola.

Se definió como objetivo mantener la trazabilidad entre requisitos, implementación y pruebas para facilitar la validación del avance.