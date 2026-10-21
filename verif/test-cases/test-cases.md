# Casos de prueba

Las referencias a `data/jobs.json` en los casos de prueba apuntan al archivo persistente `$HOME/.local/share/hermes/data/jobs.json`: dentro del repositorio, `src/hermes/data` es un enlace simbólico al directorio de datos. Este directorio también contiene `config.json`, `jobs.lock` y `scheduler.lock`. `config.json` se inicializa con `trabajos_maximos: 5`, pero hoy no se lee para configurar la concurrencia; el scheduler usa cinco trabajadores definidos en código.

Los casos para RF-27 y RF-12 son [TC-017](./TC-017.md) y [TC-016](./TC-016.md), respectivamente.