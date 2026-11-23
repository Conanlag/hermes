# RNF-32: Compatibilidad y versionado del protocolo

## Política de versión

La versión actual del protocolo es `1`. Se define una constante compartida,
`VERSION_PROTOCOLO`, usada por el cliente y el servidor.

Una solicitud debe incluir `version` como entero y el valor debe ser exactamente
la versión soportada.

| Condición | Resultado |
| --- | --- |
| `version` ausente o no entera | `INVALID_VERSION` |
| `version` entera distinta de `1` | `UNSUPPORTED_VERSION` |
| `version: 1` y sobre válido | operación normal |

Las respuestas usan la misma versión en sobres de éxito y error. El cliente
rechaza `version` ausente, no entera o distinta de la constante actual.

## Evolución compatible

- Una versión nueva se agrega como constante y casos de compatibilidad.
- Campos nuevos solo se aceptan si no rompen los sobres existentes.
- Cambios incompatibles requieren una nueva versión y rechazo explícito.
- No se realiza negociación silenciosa ni se interpreta una versión futura.

## Evidencia

- [protocol.cpp](../../../src/hermes/src/network/protocol.cpp) valida y genera la versión.
- [client.cpp](../../../src/hermes/src/network/client.cpp) valida la respuesta.
- [TC-039](../../../verif/test-cases/TC-039.md) incluye `UNSUPPORTED_VERSION`.
- [TC-041](../../../verif/test-cases/TC-041.md) valida respuestas incompatibles.

**Estado: CUMPLE.**
