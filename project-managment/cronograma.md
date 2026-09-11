# Cronograma de Actividades y Gestión de Riesgos

## Desglose de Tareas por Hito

| Hito | Actividad / Requisito | Asignación | Fecha Límite | Estado |
| :--- | :--- | :--- | :--- | :--- |
| **HITO 0** | **Línea Base y Repositorio** | | | |
| | Elegir Lenguaje de programación (C++) | Todos | 10/09/2026 | Completado |
| | Elegir Roles del equipo | Daniel | 10/09/2026 | Completado |
| | Elegir nombre del proyecto / jobrunner | Alan, Daniel, Leonel | 10/09/2026 | Completado |
| | Generar esqueleto del repositorio | Leonel | 11/09/2026 | Pendiente |
| | Crear Issues en github | Alan | 11/09/2026 | Pendiente |
| | Documentar ADR para hito 0 | Leonel | 11/09/2026 | Pendiente |
| **HITO 1** | **Núcleo Local (Cierre: 02/10/2026)** | | | |
| | RF-01 — Envío de comando/programa y generación de ID. | Por definir | 18/09/2026 | Pendiente |
| | RF-02 — Validación de solicitudes. | Por definir | 18/09/2026 | Pendiente |
| | RF-03 — Cola inicial cuando no hay capacidad. | Por definir | 22/09/2026 | Pendiente |
| | RF-04 — Ejecución en procesos separados (`fork`/`exec`). | Por definir | 25/09/2026 | Pendiente |
| | RF-06 — Estados QUEUED, RUNNING, SUCCEEDED... | Por definir | 27/09/2026 | Pendiente |
| | RF-11 — Captura separada de stdout y stderr (`pipes`). | Por definir | 29/09/2026 | Pendiente |
| | RF-08 — Consulta de un trabajo mediante ID. | Por definir | 01/10/2026 | Pendiente |
| | *QA - Redactar pruebas unitarias de Hito 1* | Por definir | 02/10/2026 | Pendiente |
| **HITO 2** | **Concurrencia y Persistencia** | | | |
| | RF-05, RF-07, RF-09, RF-10 (Concurrencia y Cancelación) | Por definir | 16/10/2026 | Pendiente |
| | RF-12, RF-13, RF-14 (Persistencia atómica y Bitácora) | Por definir | 23/10/2026 | Pendiente |
| | RF-23, RF-25 a RF-30 (Manejo de límites y fallos) | Por definir | 30/10/2026 | Pendiente |
| **HITO 3** | **Operación Remota Privada** | | | |
| | RF-16, RF-17 (Configuración y CLI remota) | Por definir | 06/11/2026 | Pendiente |
| | RF-18 a RF-22, RF-28 (Protocolo de red y desconexiones) | Por definir | 13/11/2026 | Pendiente |
| **HITO 4** | **Candidato de Entrega** | | | |
| | Pruebas de integración completas y corrección de defectos | Todos | 25/11/2026 | Pendiente |
| **HITO 5** | **Aceptación Final** | | | |
| | Preparación de demostración, falla controlada y Release | Todos | 04/12/2026 | Pendiente |

---

## Dependencias Conocidas

* **Dependencia Técnica:** Para iniciar el Hito 1, el equipo debe investigar y familiarizarse con la API POSIX de Linux en C++ (`fork`, `execvp`, `pipe`).
* **Dependencia de Verificación:** Los requisitos del cronograma no se marcarán como finalizados hasta que el revisor de QA valide la prueba correspondiente.

## Riesgos Iniciales

| Riesgo | Impacto | Estrategia de Mitigación |
| :--- | :--- | :--- |
| **Procesos Zombis:** El sistema no recolecta a los procesos hijos, saturando los recursos. | Alto | Monitoreo exhaustivo de finalización con `waitpid()` o la señal `SIGCHLD`. |
| **Corrupción de Datos:** Caída del demonio durante la escritura del estado de los trabajos. | Crítico | Manejar la escritura en disco de forma atómica. |
| **Exposición de Red:** Uso incorrecto del socket dejando el servicio expuesto a internet. | Alto | Restricción estricta de `bind()` a IP local o de VPN. |
