# Resultados TC-024 — Máximo configurable de trabajos simultáneos

**Fecha:** 2026-10-30  
**Entorno:** Linux WSL2, `HOME` temporal  
**Preparación:** `make -C src/hermes` (sin cambios pendientes de compilación)  
**Resultado:** PASS

## Ejecución

```bash
bash verif/scripts/TC-024.sh
```

El script completó con código `0` y reportó:

```text
PASS: configmax persistió el valor, conservó otras claves, rechazó valores inválidos y el scheduler ejecutó tres Jobs simultáneos sin superar el límite.
```

La prueba verificó que tres Jobs `sleep` alcanzaran simultáneamente el estado `RUNNING` con `trabajos_maximos=3`, y que una cuarta solicitud se rechazara explícitamente. También comprobó la persistencia de la configuración, la conservación de otras claves y el rechazo de valores fuera del rango permitido.
