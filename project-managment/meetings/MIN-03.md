# Minuta 08 — Revisión técnica del proyecto

**Proyecto:** Hermes
**Tema:** Revisión de arquitectura, implementación y documentación
**Fecha:** 2 de octubre de 2026
**Participantes:** Alberto, Arturo, Alan

## Objetivo

Revisar el avance técnico de Hermes y verificar que las decisiones de implementación se encuentren respaldadas por documentación.

## Temas revisados

Se revisaron los siguientes elementos:

* Lenguaje C++.
* Plataforma WSL 2.
* Compilación mediante Makefile y g++.
* Estructura modular.
* Persistencia mediante JSON.
* Creación de Jobs.
* Estados de los Jobs.
* Cola FIFO.
* Capacidad máxima de 5 Jobs.
* Creación de procesos mediante `fork()`.
* Ejecución mediante `execvp()`.
* Sincronización mediante `waitpid()`.
* Cancelación mediante `SIGTERM`.
* Comunicación mediante pipes.
* Convenciones de commits.
* Evolución futura mediante comunicación LAN.

## Acuerdos

Se acordó mantener los ADR actualizados conforme evolucionen las decisiones técnicas del proyecto.

Los cambios de código deberán mantenerse separados por módulos y deberán pasar por revisión cruzada antes de integrarse.

QA continuará verificando el comportamiento mediante pruebas y documentando los resultados obtenidos.

Ingeniería continuará revisando la arquitectura y las decisiones técnicas.

Producto continuará validando que las implementaciones correspondan con los requisitos establecidos.

## Resultado

Se confirmó la separación de responsabilidades entre Producto, QA, Ingeniería y Desarrollo.

También se estableció que las decisiones técnicas relevantes deberán quedar documentadas mediante ADR para mantener trazabilidad entre los requisitos, las decisiones y la implementación.
