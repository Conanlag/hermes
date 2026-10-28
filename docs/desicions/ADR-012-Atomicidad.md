# ADR-012: Escritura atómica y recuperable de datos persistentes

## Contexto

`jobs.json` almacena el estado durable de los Jobs. Escribir directamente sobre el archivo puede truncarlo o dejar JSON incompleto si el proceso o el sistema se interrumpe durante una actualización. La persistencia también debe serializar modificaciones concurrentes y permitir recuperar una versión válida.

## Decisión

Hermes centraliza las modificaciones de `jobs.json` en `modificarJobsSeguros()` y las realiza bajo `mutexStorage` y un bloqueo exclusivo `flock` sobre `jobs.lock`, cubriendo todo el ciclo de lectura, modificación y escritura.

Cada actualización se publica mediante un archivo temporal único en el mismo directorio: Hermes escribe el documento completo, sincroniza el temporal con `fsync`, actualiza `jobs.json.bak` con la versión válida anterior, reemplaza el archivo principal con `rename` y sincroniza el directorio. No se trunca ni sobrescribe directamente `jobs.json`.

Si `jobs.json` no puede leerse o parsearse, Hermes intenta recuperar la versión válida desde `jobs.json.bak` y repara el archivo principal. Los temporales huérfanos se limpian al inicio. Si no existe una versión válida recuperable, el error se informa en lugar de inventar un arreglo vacío.

## Justificación

| Justificación     | El reemplazo por `rename` evita exponer una actualización parcial; `fsync` del archivo y del directorio mejora la durabilidad ante fallos. El respaldo y la validación proporcionan una vía de recuperación cuando el archivo principal no es válido. |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | Truncar y reescribir `jobs.json`; usar solo un archivo temporal sin respaldo; sustituir el JSON por una base de datos. |
| Consecuencias     | Las escrituras requieren espacio temporal y operaciones POSIX. El respaldo contiene la última versión íntegra anterior, no necesariamente la actualización más reciente. La atomicidad de `rename` requiere que temporal y destino estén en el mismo sistema de archivos. |
| Riesgos           | Un fallo de almacenamiento puede impedir tanto la publicación como la restauración. Si `jobs.json` y `jobs.json.bak` son inválidos, el estado no puede recuperarse automáticamente. |
| Evidencia técnica | [storage.cpp](../../src/hermes/src/storage/storage.cpp) implementa `guardarAtomico()`, los bloqueos, el respaldo y la lectura de recuperación; [storage.h](../../src/hermes/include/storage.h) declara las operaciones públicas. El detalle está en [RNF-11](../technical-guide/2-Nucleo%20del%20proyecto/RNF-11-escritura-atomica.md) y [RNF-28](../technical-guide/2-Nucleo%20del%20proyecto/RNF-28-persistencia-atomica-recuperable.md). |