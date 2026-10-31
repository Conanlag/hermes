# RNF-29 — Backpressure y rechazo al alcanzar límites

## Descripción

Hermes deberá aplicar backpressure o rechazo explícito cuando alcance los límites de cola, memoria, descriptores o clientes.

> "El sistema deberá aplicar backpressure o rechazo explícito cuando alcance sus límites de cola, memoria, descriptores o clientes."

## Categoría

Confiabilidad y gestión de recursos.

## Métrica de aceptación

- Cuando se alcanza la capacidad configurada de Jobs activos, una solicitud nueva se rechaza con un mensaje y código de salida no exitoso.
- El rechazo no crea un registro de Job y se registra con nivel `WARN`, el límite y la cantidad de Jobs activos.
- Los límites de memoria, descriptores y clientes requieren controles y pruebas específicos antes de poder declararse cubiertos.

## Implementación y estado de cumplimiento

**Cumplimiento parcial.** `crearJob()` cuenta los Jobs `QUEUED` y `RUNNING` dentro de una actualización protegida de `jobs.json`. Al alcanzar `trabajos_maximos`, rechaza la solicitud antes de crear un Job y escribe un evento `WARN` con `trabajos_activos`, `capacidad` y el motivo. El usuario recibe un error explícito; si falla el registro del evento, también se informa ese fallo.

La capacidad configurada limita el total de Jobs activos admitidos; no existe un límite de cola independiente. La implementación actual tampoco establece ni valida cuotas específicas de memoria o descriptores de archivos. Hermes opera como CLI local y no administra un límite de conexiones de clientes. Por ello, la evidencia cubre el backpressure por capacidad de Jobs, no todos los recursos enumerados en el enunciado.

## Verificación

El caso [TC-023](../../../verif/test-cases/TC-023.md) lanza solicitudes concurrentes con capacidad `2`. Comprueba los rechazos explícitos, ausencia de registros para solicitudes rechazadas, eventos `WARN`, reutilización idempotente y liberación de capacidad tras cancelar un Job. La prueba pasó el 2026-10-30; véase [results_TC-023.md](../../../verif/results/results_TC-023.md).

## Módulos o componentes afectados

- `job`: conteo de capacidad, rechazo y no creación del Job excedente.
- `storage`: serialización de la comprobación y escritura de Jobs.
- `event_log`: registro del rechazo.
- [TC-023](../../../verif/scripts/TC-023.sh): prueba de capacidad y solicitudes concurrentes.

## Trabajo pendiente

Definir umbrales y políticas verificables para memoria y descriptores si forman parte del alcance de Hermes; especificar el modelo de clientes antes de exigir un límite de conexiones. Hasta entonces, RNF-29 permanece **parcial**.
