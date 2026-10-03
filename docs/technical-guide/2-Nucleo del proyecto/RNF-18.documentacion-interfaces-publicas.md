# RNF-18 — Documentación de interfaces públicas

## Descripción

Hermes expone dos capas de interfaz pública: una interfaz de línea de comandos para usuarios finales y una colección de cabeceras C++ que definen contratos de integración para el resto del sistema. La documentación de estas interfaces debe ser clara, estable y fiel a la implementación actual para evitar ambigüedad en uso, validación y resultados esperados.

El conjunto público incluye los comandos principales del ejecutable `hermes`, así como los tipos y funciones visibles en `include/`:

- `--version`: devuelve la versión del programa.
- `job <programa> [argumentos...]`: crea y lanza un trabajo.
- `cancel <id>`: solicita la cancelación de un trabajo existente.
- `filter <id|status|programa> <valor>`: consulta trabajos por identificador, estado o programa.
- `Job`: estructura pública del trabajo creado.
- `Status`: enumeración de estados del trabajo.
- `ResultadoValidacion`, `ResultadoCancelacion`, `CodigoValidacion` y `CodigoCancelacion`: resultados de validación y cancelación.

El requisito no funcional no exige una API REST ni una librería de terceros; exige que la interfaz actual quede documentada de forma explícita para que usuarios y desarrolladores puedan operar sin lectura del código fuente.

**Dictamen: CUMPLE.** La interfaz pública está presente en `src/hermes/src/main.cpp` y en los headers de `src/hermes/include`, y su uso queda descrito de manera consistente con los mensajes de error y validaciones implementadas.

---

## Categoría (Rendimiento, Seguridad, Escalabilidad, Mantenibilidad, Portabilidad, Confiabilidad).

Mantenibilidad.

---

## Métrica de Aceptación (Medible)

Se considera compatible con el requisito si se cumple lo siguiente:

1. Todos los comandos públicos del binario aparecen documentados y son invocables desde la línea de comandos.
2. Cada comando documentado corresponde con un flujo real en `main.cpp`.
3. Los tipos y estructuras públicas en `include/` están identificados y su semántica queda descrita.
4. Las validaciones y errores esperados coinciden con el comportamiento del código.

Verificación aplicada sobre el código del proyecto:

```bash
./hermes --version
./hermes job sleep 2
./hermes cancel 1
./hermes filter status RUNNING
```

Criterio: la sintaxis visible en la documentación debe coincidir con las ramas de ejecución en `main.cpp` y con las firmas de las cabeceras públicas.

---

## Módulos o Componentes Afectados

- `src/hermes/src/main.cpp` — entrada principal del binario y contratos de CLI.
- `src/hermes/include/job.h` — estructura pública `Job` y operaciones de creación y consulta.
- `src/hermes/include/status.h` — enum `Status` y conversiones a texto.
- `src/hermes/include/filter.h` — funciones públicas de filtrado.
- `src/hermes/include/validator.h` — validación de comandos y parámetros.
- `src/hermes/include/cancel.h` — interfaz pública de cancelación con resultados estructurados.

---

## Restricciones Tecnológicas o de Arquitectura

- Hermes está diseñado como ejecutable CLI y no como librería compartida.
- La interfaz pública es estable por convención del propio programa, no por un contrato formal de API externa.
- Los nombres y tipos de la interfaz deben mantenerse sincronizados con las cabeceras de `include/` y con la lógica de `main.cpp`.
- La documentación debe priorizar claridad de uso, validaciones y casos de error sobre detalle de implementación interna.

---
