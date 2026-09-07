# ADR-001: Lenguaje de programación

## Contexto

El proyecto requiere desarrollar una aplicación capaz de crear, ejecutar, administrar y monitorear procesos en un sistema Linux. Por lo tanto, se necesita un lenguaje que permita interactuar con las APIs del sistema operativo y con mecanismos de procesos y comunicación entre procesos.

## Decisión

Se utilizará C++ como lenguaje de programación principal.

| Justificación     | C++ permite interactuar directamente con APIs POSIX y proporciona control sobre procesos, memoria, señales y recursos del sistema.                                                                    |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | Python, Rust                                                                                                                                                                                          |
| Consecuencias     | Mayor control sobre los recursos del sistema y acceso directo a funcionalidades de Linux. Como consecuencia, el desarrollo puede ser más complejo y requiere mayor cuidado en memoria y concurrencia. |
| Riesgos           | Errores de memoria, condiciones de carrera, deadlocks y mayor complejidad en el manejo de procesos.                                                                                                   |
| Evidencia técnica | Se realizarán pruebas utilizando `fork()`, `exec()`, `waitpid()` y señales POSIX.                                                                                                                     |
