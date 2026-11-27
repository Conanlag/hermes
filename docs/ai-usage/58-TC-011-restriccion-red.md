# Uso de inteligencia artificial

# 58. TC-011 — Restricción de red

## Objetivo

Implementar y verificar TC-011 para RF-20, RNF-12 y RNF-13 siguiendo la guía de pruebas de red. Comprobar origen IPv4/CIDR, escucha segura, rechazo de configuraciones inválidas y limpieza, utilizando servidores aislados en WSL sin modificar el servicio LAN del usuario.

---

## Prompt 1

```text
ahora - TC-011 Restricción de red → RF-20, RNF-12, RNF-13.
```

---

## Resultado 1

Se leyeron los tres requisitos, la guía de pruebas, el caso TC-010 y el código de configuración, acceso y servidor. Se eligió un caso exclusivamente local: comprobar restricciones exige controlar reglas y orígenes, mientras que una conexión de B a través del proxy no permite inferir por sí sola la IP observada por Hermes.

Se creó `verif/scripts/TC-011.sh` con Bash y Python integrado. Cada escenario utiliza HOME/XDG temporales, configuración propia, un puerto libre y el servidor real. Los sockets enlazan explícitamente su origen a `127.0.0.1`, `127.0.0.2` o `127.0.0.5`; la escucha permanece en `127.0.0.1`, sin recurrir a una interfaz comodín.

Se definieron once criterios: valores seguros predeterminados, IP individual y /32, normalización CIDR, listas vacías o sin coincidencia, reglas privadas/VPN válidas, listas inválidas, fallback de interfaz, aplicación de reglas al reiniciar, errores de bind, separación de permiso de red y de operaciones, y cierre/limpieza.

El primer intento terminó con **2**, error de entorno, porque el aislamiento impedía crear sockets. Se conservó la salida y, con autorización, se repitió fuera del aislamiento. La ejecución de las 17:39:02 del 2026-11-27 pasó AC1–AC11 con código **0**. Tras ajustar la limpieza de intentos de arranque, la validación de las 17:41:25 volvió a pasar.

---

## Prompt 2

```text
ahora haz una bitacora de ia-usage por cada TC usando el template de ai-usage
```

---

## Resultado 2

Se revisó `docs/ai-usage/#-template.md` y la numeración disponible, y se creó este registro independiente del de TC-010. Se contrastaron las afirmaciones con la ficha y el historial de resultados.

El archivo de evidencia también contiene una ejecución posterior de las 17:42:11 con código 0. Se reconoce como un registro presente en el repositorio, sin atribuir su ejecución al asistente en los turnos anteriores. Para escribir esta bitácora no se repitieron pruebas ni se alteró el historial.

---

## Prompt 3

No hubo un tercer pedido específico para este caso en la conversación. Las revisiones internas del script no se presentan como prompts adicionales del usuario.

---

## Resultado 3

No aplica una tercera respuesta técnica. El caso ya estaba implementado y cerrado en PASS antes del pedido de esta bitácora.

---

# Modificaciones

**Estado de la resolución:** implementado y verificado, **PASS con código 0**. Se corrigió la limpieza de los intentos de arranque antes de validar la versión final. No se modificó código de producción.

**Revisión realizada:** validación de sintaxis Bash/Python, comprobación de binario actualizado mediante Make, pruebas de sockets y servidor real, revisión de logs y procesos, evidencia append y `git diff --check`.

La base de las ejecuciones registradas fue `792623f`, con cambios locales. El caso puede cerrar sus criterios sin PC B: aquí se verifica la restricción y la escucha con control del servidor; el recorrido LAN entre equipos ya corresponde a TC-010.

---

## Implementación de feature

**Política de red y escucha.** Se comprobaron ocho reglas privadas/VPN válidas y veinte listas inválidas, incluyendo tipos JSON incorrectos, prefijos fuera de rango, redes demasiado amplias, DNS, IPv6, NUL, direcciones públicas, link-local, multicast/reservados y límites de 100.64/10.

Se distinguieron tres respuestas del sistema:

| Condición | Comportamiento verificado |
|---|---|
| Interfaz inválida o `0.0.0.0` | Advertencia y fallback exclusivamente a loopback |
| Interfaz privada válida pero no asignada, o puerto ocupado | Fallo de bind, código 1, sin fallback de escucha |
| Lista de redes inválida | Arranque rechazado antes de abrir puerto o iniciar scheduler |

Las conexiones denegadas se verificaron como cierre sin datos de aplicación, acompañado de evento `ORIGEN_RECHAZADO` e IP observada. Después se repitió una conexión autorizada para demostrar continuidad del servicio. El éxito de `connect()` no se interpretó como autorización.

---

## Implementación de feature

**Aislamiento, reinicio y recursos.** Se comprobó que editar las reglas no cambia la política del proceso vivo y que el reinicio sí aplica la nueva lista. Un origen permitido pudo recibir pong, pero sin registro de cliente su submit devolvió `UNAUTHORIZED` y no creó trabajos.

La limpieza utiliza SIGTERM, espera del proceso, verificación del mensaje/evento de parada y cierre del scheduler de cada HOME propio. Al terminar se comprueban los puertos y la ausencia de procesos con el entorno de la prueba. El escenario de puerto ocupado utiliza un socket creado por el propio script; no interfiere con una escucha ajena.

---

## Modificación de archivo

- [TC-011.sh](../../verif/scripts/TC-011.sh): script ejecutable, escenarios, orígenes explícitos, aserciones, códigos y limpieza.
- [TC-011.md](../../verif/test-cases/TC-011.md): planificación, once criterios locales, instrucciones, alcance y resultados empíricos.
- [results_TC-011.md](../../verif/results/results_TC-011.md): intento bloqueado por el entorno y ejecuciones satisfactorias, con fechas, commit, configuración y puertos.
- [Índice](../../verif/test-cases/test-cases.md) y [matriz](../../verif/verification-plan/traceability-matrix.md): incorporación del caso y estado PASS para RF-20, RNF-12 y RNF-13.

---

## Modificación de archivo

- [RF-20](../technical-guide/2-Nucleo%20del%20proyecto/RF-20.restriccion-redes-direcciones.md): referencia al caso disponible y aclaración sobre la interfaz comodín.
- [RNF-12](../technical-guide/2-Nucleo%20del%20proyecto/RNF-12.no-escuchar-publicamente.md): corrección de la afirmación de que `red start` nunca inicia el scheduler; depende de la habilitación remota. Se sustituyó una referencia de prueba inexistente y se aclararon las solicitudes secuenciales de RNF-24.
- [RNF-13](../technical-guide/2-Nucleo%20del%20proyecto/RNF-13.acceso-remoto-LAN-VPN.md): reemplazo de una prueba inexistente y eliminación de la descripción obsoleta de excepciones públicas /32.
- [Guía de pruebas de red](../../verif/scripts/GUIA-PRUEBAS-RED.md): corrección de la variante que exigía escuchar en `0.0.0.0` para distinguir orígenes loopback.
- Este registro documenta la intervención de IA y las pruebas observadas, conforme al pedido de una bitácora por TC.

---

# Implementación final

Desde la raíz del proyecto, en WSL:

```bash
make -C src/hermes hermes
bash verif/scripts/TC-011.sh
```

Salida final verificada:

```text
PASS V11/AC11: SIGTERM, wait, eventos de parada, schedulers y puertos liberados; sin huerfanos
PASS: RF-20 RNF-12 RNF-13 TC-011 sin fallos.
Resultado: 0
Codigo de salida TC-011: 0
```

**Resultado:** PASS de AC1–AC11, sin requerir PC B ni modificar proxy o firewall. La aceptación de configuración privada/VPN no acredita tráfico real desde todos esos rangos ni la existencia de un túnel VPN. La pertenencia efectiva se comprobó con orígenes loopback explícitos.

---

# Aprendizaje

**Interfaz, origen y autorización son controles distintos.** Elegir dónde escuchar no concede acceso a toda una red; permitir una IP tampoco le concede operaciones de trabajos. El ping permitido con submit rechazado permite comprobar esa separación.

**Un rechazo puede ocurrir después del handshake.** Exigir que falle `connect()` habría producido una prueba incorrecta. Se debe observar el cierre sin respuesta y el motivo registrado por el servidor.

**No todos los errores de configuración admiten el mismo fallback.** Una interfaz inválida vuelve a loopback; una lista inválida aborta y una interfaz válida no local falla al enlazar. Mezclar esos contratos puede ocultar una apertura excesiva o rechazar comportamiento correcto.

**Controlar el origen simplifica la prueba en WSL.** Enlazar el origen de los sockets permite verificar reglas de pertenencia sin manipular el servicio real, inventar identidades detrás del proxy ni abrir una escucha comodín.

**La documentación también debe contrastarse con el código.** El trabajo encontró una prueba inexistente, una descripción de permisos públicos ya eliminados y una afirmación obsoleta sobre el scheduler. Corregirlas dejó instrucciones coherentes con el caso ejecutado.
