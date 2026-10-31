# Resultados TC-023 — Rechazo explícito cuando la cola está llena

**Fecha:** 2026-10-30  
**Entorno:** Linux WSL2, `HOME` temporal  
**Resultado:** PASS

## Ejecución

```bash
bash verif/scripts/TC-023.sh
```

El script completó con código `0` y reportó:

```text
PASS: el límite concurrente rechazó sin persistir Jobs extra, registró los rechazos y liberó la capacidad.
```

La prueba verificó que, con capacidad `2`, las solicitudes excedentes no se persistieran como Jobs, que los rechazos se registraran como eventos `WARN` y que cancelar un Job liberara capacidad para una solicitud posterior.
