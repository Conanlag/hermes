# Uso de inteligencia artificial

# 57. TC-010 — Flujo remoto completo en LAN/VPN

## Objetivo

Diseñar, implementar y verificar TC-010 para RF-18, RF-19 y RNF-26 conforme a `verif/scripts/GUIA-PRUEBAS-RED.md`. Separar la integración local aislada de la demostración entre PC B y PC A en WSL, conservar la evidencia de cada ejecución y cerrar el caso mediante revisión conjunta de sus criterios.

---

## Prompt 1

```text
OK, Vamos a crear el siguiente TC-10 y modificalo en la - TC-010 Flujo remoto completo en LAN/VPN → RF-18, RF-19, RNF-26.
Primero necesito que leas el contexto de cada RF y RNF luego planea conforme a verif\scripts\GUIA-PRUEBAS-RED.md y ten en cuenta que estamos en WSL y que hay que leer la documentacion necesaria de red para entender el proyecto
```

---

## Resultado 1

Se revisaron los requisitos, el contexto de red, las guías de WSL y setup, el CLI, el protocolo, la política de direcciones y los casos existentes. Primero se creó la ficha de planificación, se agregó al índice y se registró en la matriz sin atribuirle resultados todavía no ejecutados.

Se definieron doce criterios: ping, éxito de `true`, fallo de `false`, estado RUNNING y filtros, deduplicación/conflicto, cancelación y rechazo terminal, equivalencia local/remota, cancelación en cola, persistencia/eventos, política privada, recorrido real entre equipos y limpieza.

El diseño diferenció las fuentes de verdad: el puerto del cliente procede de su `config.json`; la escucha del servidor también procede de la configuración general; los metadatos `servidor` y `equipos` de `network.json` no asignan por sí mismos permisos. En NAT, Hermes identifica el acceso del proxy, no la IP LAN original de PC B.

También se contrastaron indicaciones obsoletas con el código: no se utilizó una escucha en `0.0.0.0` ni una excepción pública /32. La selección de loopback para el arnés no sustituyó la demostración LAN requerida por AC11.

---

## Prompt 2

```text
como hago para dar el PASS descargo el codigo en otra compu y te mando la ip o como tomando en cuenta que esta seria PC A y la otra PC B
```

En el siguiente mensaje el usuario proporcionó las direcciones y pidió:

```text
dime que hago para que se ejecuten las pruebas
```

Datos aportados: Windows A `192.168.1.83`, WSL A `172.25.70.19`, gateway A `172.25.64.1`; Windows B `192.168.1.81`, WSL B `172.23.236.91`, gateway B `172.23.224.1`.

---

## Resultado 2

Se implementó `verif/scripts/TC-010.sh`, con Bash y Python integrado, dos modos, HOME/XDG temporales, identificadores únicos, puertos propios y evidencia append. Se explicó cómo preparar PC A con `red setup`, iniciar el servidor, comprobar cada tramo TCP y ejecutar desde PC B el cliente contra `192.168.1.83:45820`. PC B no necesitaba servidor ni setup.

La ejecución local comprobó AC1–AC10 y AC12 y dejó AC11 como SKIP. El código final fue **3**, correspondiente a PASS parcial por modo. La prueba comparó los resultados de los programas y las transiciones de estado; no exigió que IDs, PID o tiempos fueran iguales entre interfaces.

Los primeros intentos permitieron corregir la prueba sin cambiar producción:

1. El aislamiento bloqueó los sockets; se solicitó autorización y se ejecutó fuera de él. La salida inicial se conservó.
2. Se suponía que el CLI imprimía literalmente `JOB_OPERATION_FAILED` y `NOT_CANCELABLE`. La lectura de `client.cpp` mostró que puede presentar el mensaje. Se mantuvo la comprobación del código de salida del CLI y se verificaron los códigos de error mediante respuestas JSON.
3. El CLI local puede observar el FAILED de `false` antes de devolver la admisión. Se verificó el resultado persistido y la salida final del programa, sin confundirlos con el retorno de la solicitud de creación.

---

## Prompt 3

El usuario confirmó el equipo ejecutor:

```text
eso lo hice desde el pc b
```

Después compartió la salida completa. Extractos de esa evidencia:

```text
## Ejecucion: 2026-11-27 17:02:01 -0600
- Commit: b4467ed
- Arbol: con cambios locales
Modo: remoto
Destino solicitado: 192.168.1.83:45820
Cliente (etiqueta): PC-B
PASS V11/AC11: flujo desde el cliente al destino LAN/VPN indicado por el operador
Codigo de salida TC-010: 3
```

---

## Resultado 3

Se incorporó la salida de PC B al historial, indicando que fue aportada por el usuario y no obtenida mediante acceso directo al otro equipo. Se restauraron las cercas Markdown sin modificar los resultados.

La ejecución remota confirmó los trabajos 166 (`SUCCEEDED`, código 0), 167 (`FAILED`, código 1) y 168 (`RUNNING` → `CANCELED`, código -15). Los filtros incluyeron el trabajo 168; el duplicado reutilizó su ID, el conflicto de argumentos produjo `JOB_OPERATION_FAILED` y la cancelación terminal produjo `NOT_CANCELABLE`.

La revisión conjunta cubrió todos los criterios:

| Criterios | Ejecución local | Ejecución desde B | Cierre conjunto |
|---|---|---|---|
| AC1–AC6 | PASS | PASS | PASS |
| AC7–AC10 | PASS | SKIP | PASS |
| AC11 | SKIP | PASS LAN | PASS LAN |
| AC12 | PASS | SKIP | PASS |

**TC-010 quedó en PASS para LAN privada.** Cada ejecución conserva su código 3 y sus SKIP; la revisión conjunta es una conclusión documental separada. No se acreditó VPN.

---

# Modificaciones

**Estado de la resolución:** implementado, corregido y verificado mediante evidencia local y LAN. El cierre del caso se registró después de recibir la salida completa de B.

**Revisión realizada:** lectura de requisitos y código, validación de sintaxis Bash/Python, compilación, ejecución local con limpieza, contraste de la evidencia remota, revisión de cobertura AC1–AC12 y `git diff --check`.

Las bases registradas fueron `31cbaf2` para local y `b4467ed` para B, ambas con cambios locales. La comparación entre commits no presentó diferencias bajo `src/hermes`; no se dispuso de hashes de binarios ni del diff local de B. Esta limitación se conservó en la ficha y en la revisión de evidencia.

---

## Implementación de feature

**Flujo funcional y equivalencia.** El script utiliza el CLI real para enviar, consultar, filtrar y cancelar. Complementa la presentación con consultas JSON y, en local, revisa el almacenamiento. Repite el flujo sobre un dominio local separado para comparar éxito, fallo, duplicados, filtros y cancelación sin interferir con la capacidad del servidor de prueba.

---

## Implementación de feature

**Modos y ciclo de vida.** Local crea servidor y scheduler propios; remoto configura únicamente el cliente temporal y no administra PC A. Se registran los IDs creados para cancelar solo los trabajos de la ejecución que queden activos. La limpieza local detiene procesos propios, espera su terminación y verifica puertos y procesos remanentes. La evidencia conserva intentos, resultados y omisiones por modo.

---

## Modificación de archivo

- [TC-010.sh](../../verif/scripts/TC-010.sh): arnés ejecutable, aislamiento, modos, pruebas, códigos y limpieza.
- [TC-010.md](../../verif/test-cases/TC-010.md): planificación, doce criterios, topología WSL, instrucciones y resultados empíricos.
- [results_TC-010.md](../../verif/results/results_TC-010.md): historial local, salida de PC B y revisión conjunta, sin sustituir los códigos originales.

---

## Modificación de archivo

- [Índice de casos](../../verif/test-cases/test-cases.md): incorporación de TC-010 y actualización de planificación a cierre conjunto.
- [Matriz de trazabilidad](../../verif/verification-plan/traceability-matrix.md): vinculación de RF-18, RF-19 y RNF-26 con la evidencia del caso.
- Este registro de uso de IA se creó por la petición posterior de una bitácora por cada TC. No se modificó producción para conseguir el PASS.

---

# Implementación final

```bash
# Local aislado: código 3 por falta del recorrido entre equipos.
bash verif/scripts/TC-010.sh

# En WSL de B: código 3 por omitir inspecciones del servidor.
HERMES_TEST_HOST=192.168.1.83 HERMES_TEST_PORT=45820 \
  HERMES_TEST_CLIENT_ID=PC-B bash verif/scripts/TC-010.sh
```

**Resultado final:** PASS conjunto local + LAN del 2026-11-27. No equivale a cambiar las salidas individuales a 0 ni a demostrar VPN. La conectividad TCP fue preparación; el cierre se basó en operaciones de Hermes y resultados de trabajos.

---

# Aprendizaje

**Un PASS parcial puede ser correcto por diseño.** Los criterios del servidor no deben simularse desde un cliente que no puede inspeccionarlos. El cierre requiere revisar las coberturas complementarias y conservar los SKIP.

**El CLI y el protocolo no siempre presentan igual los errores.** La prueba debe comprobar cada contrato en su capa y evitar depender de que un mensaje legible contenga el identificador interno.

**WSL NAT cambia la identidad observable.** La IP exterior de B sirve para el firewall; Hermes autoriza el origen que el proxy utiliza hacia WSL A. Registrar ambos evita atribuir autenticación por equipo a un acceso compartido.

**La procedencia de evidencia importa.** Una salida aportada por el usuario puede respaldar la prueba remota, pero no debe describirse como observación directa del asistente ni como prueba de identidad binaria. Conservar commits, cambios locales y confirmación del operador hace explícito ese límite.
