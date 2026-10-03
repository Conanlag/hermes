# ADR-007: Estructura de commits

## Contexto

El proyecto necesita una estructura uniforme para los mensajes de commit que permita identificar rápidamente el propósito de cada cambio. Para esto, se utilizará una convención basada en prefijos que clasifica los commits según el tipo de modificación realizada.

Además, los mensajes deberán utilizar verbos en modo imperativo, de forma que describan directamente la acción realizada sobre el proyecto.

## Decisión

Se utilizará la siguiente estructura para los mensajes de commit:

```text
<prefijo>: <descripción en modo imperativo>
```

Los prefijos definidos son:

| Prefijo    | Uso                                                                                                               |
| ---------- | ----------------------------------------------------------------------------------------------------------------- |
| `feat`     | Añade una nueva característica para el usuario.                                                                   |
| `fix`      | Corrige un error que afecta al usuario.                                                                           |
| `perf`     | Realiza cambios que mejoran el rendimiento.                                                                       |
| `build`    | Modifica el sistema de build, instalación o despliegue.                                                           |
| `ci`       | Realiza cambios relacionados con integración continua.                                                            |
| `docs`     | Añade o modifica documentación.                                                                                   |
| `refactor` | Modifica la estructura interna del código sin cambiar su comportamiento.                                          |
| `style`    | Modifica formato, espacios, tabulaciones, puntos y coma u otros aspectos de estilo sin afectar el comportamiento. |
| `test`     | Añade o modifica pruebas.                                                                                         |

Las descripciones deberán utilizar verbos en modo imperativo, por ejemplo:

```bash
git commit -m "feat: agregar búsqueda por categoría"
git commit -m "fix: corregir validación de argumentos"
git commit -m "refactor: separar lógica de creación de jobs"
git commit -m "docs: actualizar documentación de instalación"
```

## Justificación

| Justificación     |                                                                                                                                                                                        |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | Utilizar mensajes de commit libres sin una convención definida.                                                                                                                        |
| Consecuencias     | Los commits tendrán una estructura uniforme y será más sencillo identificar el propósito de cada cambio.                                                                               |
| Riesgos           | Una clasificación incorrecta del prefijo puede dificultar la interpretación del historial.                                                                                             |
| Evidencia técnica | Se adopta la estructura `<prefijo>: <descripción>` y los prefijos `feat`, `fix`, `perf`, `build`, `ci`, `docs`, `refactor`, `style` y `test` para clasificar los cambios del proyecto. |



