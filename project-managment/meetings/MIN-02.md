# Minuta 02 — Selección de lenguaje y plataforma

**Proyecto:** Hermes
**Tema:** Lenguaje de programación y plataforma de ejecución
**Fecha:** 7 de septiembre de 2026
**Participantes:** Alberto, Arturo, Alan

## Objetivo

Definir el lenguaje de programación y el entorno donde se desarrollará y ejecutará Hermes.

## Temas tratados

Se analizaron las necesidades técnicas del proyecto, principalmente:

* Creación y administración de procesos.
* Uso de `fork()`.
* Ejecución de programas mediante `exec*()`.
* Sincronización mediante `waitpid()`.
* Manejo de señales POSIX.
* Comunicación entre procesos.
* Ejecución sobre Linux.

También se evaluaron diferentes alternativas para proporcionar un entorno Linux a los integrantes que utilizan Windows.

## Acuerdos

Se decidió utilizar **C++** como lenguaje principal del proyecto.

La decisión se tomó debido a que C++ permite trabajar directamente con APIs POSIX y proporciona acceso a mecanismos de procesos, señales, memoria y recursos del sistema.

Como plataforma de desarrollo y ejecución se utilizará **WSL 2**, utilizando una distribución Linux.

## Alternativas consideradas

Para el lenguaje se consideraron:

* C++
* Python
* Rust

Para la plataforma se consideraron:

* WSL 2
* Máquina virtual con Linux
* Instalación nativa de Linux

## Resultado

Se establecieron C++ y WSL 2 como las tecnologías base del proyecto.

La decisión quedó documentada en:

* ADR-001: Lenguaje de programación
* ADR-002: Plataforma de ejecución
