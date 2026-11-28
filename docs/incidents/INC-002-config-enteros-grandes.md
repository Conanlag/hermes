# INC-002: Enteros grandes de capacidad se ajustan al mínimo

- **Detectado:** 2026-11-27, TC-013 / AC4, WSL2, base `81fa439` con cambios locales de verificación.
- **Requisito:** RF-16; comportamiento relacionado de RF-05 y límites de cola.
- **Estado:** Observación exploratoria fuera del alcance acordado de TC-013; no bloquea el caso. No se corrigió ni se modificó producción. El usuario acotó la aceptación de capacidad a los límites configurables 1–64 y 0–256 y sus valores adyacentes.
- **Evidencia:** [ejecuciones TC-013](../../verif/results/results_TC-013.md).

## Reproducción histórica

Las primeras versiones de TC-013 ejecutaban el escenario extremo con este comando. La versión actual lo excluye de los criterios obligatorios; ejecutar el comando ya no reproduce esta observación:

```bash
make -C src/hermes hermes
bash verif/scripts/TC-013.sh
```

El escenario AC4 escribe esta configuración en un HOME/XDG temporal y llama a `cargarConfiguracion()` mediante un auxiliar enlazado con los módulos reales:

```json
{
  "trabajos_maximos": 18446744073709551615,
  "max_cola": 18446744073709551615
}
```

| Campo | Esperado según ajuste a límites de RF-16 | Observado |
|---|---|---|
| trabajos_maximos | 64 | 1 |
| max_cola | 256 | 0 |

La lectura termina sin excepción. Las ejecuciones históricas continuaron con el resto de bloques y devolvieron **1 (FAIL)** por este hallazgo. RF-24 pasó sus criterios. Esa clasificación se conserva como historial, pero no determina el estado de la versión actual de TC-013.

## Impacto y punto de investigación

Una capacidad entera muy superior al máximo puede terminar reducida al mínimo. La exposición comprobada es la lectura del JSON; la API de actualización recibe `int` y no admite ese valor como argumento.

La función local `entero()` de `src/hermes/src/config/config.cpp` compara valores JSON con límites de tipo int antes de convertir. La interacción de enteros JSON unsigned grandes con esa comparación es un punto de investigación; este registro no acredita todavía una corrección ni delimita todos los valores afectados.

El puerto con ese mismo valor cae correctamente a 45820. No se debe extender el defecto observado a todas las claves ni cambiar las expectativas del caso para obtener PASS. Una futura corrección deberá conservar el escenario y añadir una nueva ejecución a la evidencia.

## Revisión de alcance

Por indicación del usuario, TC-013 comprueba ahora aceptación de 64 workers y 256 cupos, límites mínimos, ajuste de lectura de 65/257 y rechazo de esas entradas por configmax sin cambios parciales. La observación con UINT64_MAX no demuestra un fallo al configurar 64 y no se usa para rechazar este caso. El comportamiento observado con la entrada extrema no se presenta como corregido.
