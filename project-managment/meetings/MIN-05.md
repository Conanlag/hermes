# Minuta 05 — Organización de RNF para el avance 02

**Proyecto:** Hermes  
**Tema:** Organización de requisitos no funcionales, asignación de responsabilidades y seguimiento de pruebas  
**Fecha:** 19 de octubre de 2026  
**Participantes:** Alberto, Arturo, Alan

## Objetivo

Organizar los requisitos no funcionales correspondientes al avance 02 de Hermes, establecer responsables para su cumplimiento y definir las pruebas necesarias para verificar aspectos de rendimiento, concurrencia, persistencia, recuperación y estabilidad.

## Temas revisados

Se revisaron los requisitos no funcionales relacionados con los límites de ejecución, capacidad de almacenamiento, tiempos de respuesta, consistencia de estados, recuperación ante fallos y liberación de recursos.

Se estableció la siguiente distribución de responsabilidades:

**Daniel**
- RNF-04 — Al menos 3 trabajos simultáneos.
- RNF-07 — No ejecutar más procesos que el límite de concurrencia.
- RNF-10 — No reportar RUNNING después de reinicio si ya no existe el proceso.
- RNF-29 — Backpressure/rechazo al alcanzar límites.

**Alberto**
- RNF-05 — Consulta de estado ≤ 1 segundo con 100 trabajos.
- RNF-06 — Soporte mínimo de 500 trabajos.
- RNF-27 — Transiciones de estado consistentes.
- RNF-33 — Pruebas de liberación de recursos después de estrés.

**Alan**
- RNF-11 — Escritura persistente evitando estados parcialmente actualizados.
- RNF-22 — Correlación entre solicitudes, trabajos y logs.
- RNF-28 — Persistencia atómica o recuperable.
- RNF-30 — No dejar procesos huérfanos.
- RNF-31 — Recuperación correcta de trabajos pendientes, terminados e interrumpidos.

Se identificaron los siguientes registros de seguimiento en GitHub:

- RNF-04 — Issue #46.
- RNF-05 — Issue #47.
- RNF-06 — Issue #48.
- RNF-10 — Issue #49.
- RNF-11 — Issue #50.
- RNF-22 — Issue #51.
- RNF-27 — Issue #52.
- RNF-28 — Issue #53.
- RNF-29 — Issue #54.
- RNF-30 — Issue #55.
- RNF-31 — Issue #56.
- RNF-33 — Issue #57.

## Organización de casos de prueba

Se revisaron los casos de prueba que permiten comprobar el cumplimiento de los requisitos no funcionales.

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

Los casos de prueba se relacionaron con los requisitos no funcionales correspondientes para comprobar que Hermes mantenga un comportamiento estable bajo concurrencia, carga y condiciones de fallo.

Los casos TC-002, TC-007 y TC-016 quedaron sujetos a la finalización y verificación de la capacidad de la cola antes de completar su validación.

## Acuerdos

Se acordó mantener la distribución de requisitos no funcionales por responsable y verificar que cada implementación cumpla con los criterios establecidos.

Se continuará utilizando pruebas para comprobar los tiempos de respuesta, los límites de concurrencia, la capacidad de almacenamiento y la recuperación de información después de reinicios o interrupciones.

QA será responsable de mantener actualizados los casos de prueba, ejecutar las validaciones correspondientes y registrar los resultados.

Los problemas encontrados deberán documentarse para facilitar su seguimiento y corrección.

## Resultado

Se organizó la distribución de los requisitos no funcionales del avance 02 entre los responsables correspondientes.

También se relacionaron los requisitos con los casos de prueba necesarios para evaluar el rendimiento, la persistencia, la recuperación y la estabilidad de Hermes.

Se estableció como objetivo verificar que el sistema no solo cumpla con sus funcionalidades, sino que mantenga un comportamiento confiable bajo condiciones de carga y situaciones inesperadas.