# ADR-002: Plataforma de ejecución

## Contexto

El proyecto requiere un entorno Linux para desarrollar y ejecutar una aplicación orientada a la administración y monitoreo de procesos. Debido a que el equipo de desarrollo utiliza Windows, es necesario seleccionar la forma en que se proporcionará el entorno Linux.

Se consideran dos alternativas principales: utilizar WSL 2 (Windows Subsystem for Linux 2) o ejecutar una distribución Linux mediante una máquina virtual (VM).

## Decisión

Se utilizará WSL 2 como plataforma de desarrollo y ejecución del proyecto, utilizando una distribución Linux dentro de WSL 2.

| Justificación     | WSL 2 proporciona un entorno Linux integrado con Windows y permite utilizar herramientas y APIs de Linux con menor sobrecarga operativa que una máquina virtual tradicional. También facilita el acceso al código, herramientas de desarrollo y recursos del sistema desde Windows.                                              |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | Máquina virtual con una distribución Linux, instalación nativa de Linux                                                                                                                                                                                                                                                          |
| Consecuencias     | Se simplifica la configuración del entorno de desarrollo y se evita mantener una máquina virtual completa. El proyecto dependerá de las características y limitaciones de WSL 2, por lo que algunas funcionalidades específicas del kernel o del hardware pueden comportarse de manera diferente a una instalación Linux nativa. |
| Riesgos           | Diferencias de comportamiento entre WSL 2 y una instalación Linux tradicional, especialmente en acceso al hardware, dispositivos, red, servicios del sistema y determinadas funcionalidades del kernel.                                                                                                                          |
| Evidencia técnica | Se realizarán pruebas de creación, ejecución, monitoreo y terminación de procesos utilizando las APIs POSIX disponibles dentro de WSL 2. Los resultados podrán compararse con una distribución Linux ejecutada en una máquina virtual para identificar diferencias relevantes.                                                   |
