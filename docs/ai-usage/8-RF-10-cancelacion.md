# Uso de inteligencia artificial

# 8. Cancelación de trabajos RF-10

## Objetivo

Implementamos RF-10 (cancelación en cola o en ejecución con resultado reflejado) partiendo de una base parcial del equipo: ya existían `cancel.h`, `cancel.cpp`, la rama `cancel` en `main` y `marcarCancelacionSolicitada`. Buscamos completar la rama `QUEUED` (rechazada por doble candado `RUNNING`-only) y dar mensajes con causa (`NO_EXISTE`, `NO_CANCELABLE`) sin romper a los consumidores existentes.

---

## Prompt 1
```text
Ayudame a implementar la siguiente feature: RF-10 — Cancelación de trabajos: El usuario deberá poder solicitar la cancelación de un trabajo en cola o en ejecución;el sistema deberá reflejar el resultado. sigue el plan de AGENTS.md y asegurate de que yo entienda la implementacion
```

---

## Resultado 1

Se auditó lo existente (`cancel.h`, `cancel.cpp` con `marcar + SIGTERM`, `terminarProceso` con `kill/SIGTERM`, supervisor que confirma `CANCELED`, rama `main` y `validator` con `cancel` en lista blanca) y se detectó el hallazgo: `cancel.cpp` y `marcarCancelacionSolicitada` exigían `RUNNING`, dejando `QUEUED` fuera del RF. Se propuso la rama directa (marcar `CANCELED` con `actualizarResultadoJob` sin señal) y se implementó tras aprobación, más la distinción de mensajes (`Job cancelado:` vs `Cancelación solicitada:`).

---

## Prompt 2
```text
solo agrega validaciones a cancel con mensajes de error significativos, para estos casos por ejemplo: ./hermes cancel 999999 → No se pudo cancelar ... ./hermes cancel <1> → bash syntax error ... ./hermes cancel 1 → No se pudo cancelar el Job: 1
```

---

## Resultado 2

Se agregó `enum CodigoCancelacion` + `struct ResultadoCancelacion` + `cancelarJobDetallado` en `cancel.h`, preservando `cancelarJob` como envoltorio. Cada `false` anterior ahora lleva causa (`NO_EXISTE`, `NO_CANCELABLE` con estado actual, `ERROR_LECTURA` con detalle) y `main` traduce cada código a mensaje. Se aclaró que `cancel <1>` sin comillas lo rechaza `bash` (redirección), no el programa; con comillas lo rechaza RF-02 como mal formado.

---

## Prompt 3
```text
verifica por ultima vez que no se haya roto nada mas
```

---

## Resultado 3

Se verificó por `git diff` (3 archivos: `cancel.h`, `cancel.cpp`, `main.cpp`) y por búsqueda de consumidores (único llamador: `main`). La lógica `RUNNING` quedó intacta bajo el diff, las ramas `job`/`filter`/`--version` y RF-02 intactos, sin includes circulares (`<string>` propio en `cancel.h`). Se entregó batería de regresión de 9 comandos.

---

# Modificaciones
**Estado de la resolución:** Aceptado tras verificación

**Revisión realizada:** Verificamos rama por rama en WSL: `QUEUED` plantado (ID 999) → `Job cancelado:` + `CANCELED/-1`; `RUNNING` (ID 5) → `solicitada` + `CANCELED/-15` (`-SIGTERM`); inexistente → `No existe`; terminado → mensaje con estado; `<1>` explicado como shell. Criticamos el doble candado original y la impresión del `false` genérico.

**Cambios aplicados:** Rama `QUEUED` con `actualizarResultadoJob(CANCELED, -1)`, `pid` aceptado con/sin signo, orden flag-antes-que-señal preservado, mensajes por código en `main`, envoltorio `cancelarJob` intacto.

**Prueba agregada:** `make clean && make` más matriz: `job/filter` felices, `cancel 999999`, `cancel <succeeded>`, `cancel "<1>"`, `cancel` QUEUED plantado y `cancel` RUNNING real con `filter` posterior.

---

## Implementación de feature

Se integró la cancelación completa en dos velocidades: síncrona para cola, asíncrona con confirmación del supervisor para ejecución, ambas con causa visible y contrato anterior preservado.

---

## Modificación de archivo

Modificados `include/cancel.h` (veredicto detallado), `src/cancel/cancel.cpp` (ramificación por estado) y `src/main.cpp` (traducción de códigos a mensajes).

---

# Implementación final

```bash
./hermes cancel 999
./hermes cancel 5
./hermes cancel 999999
```

```text
Job cancelado: 999
Cancelación solicitada para el Job: 5
No existe el Job ID: 999999
```

---

# Aprendizaje

Aprendimos que una cancelación correcta necesita dos mecanismos (marca en disco + señal) en orden preciso, que los mensajes genéricos esconden decisiones (inexistente vs terminado) y que preservar el contrato viejo como envoltorio permite enriquecer sin romper. También que la carrera `QUEUED → RUNNING` debe discutirse en equipo aunque la ventana sea mínima.
