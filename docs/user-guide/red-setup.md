# Asistente `hermes red setup`

Ejecutar este comando en el equipo que recibirá y ejecutará trabajos (PC A):

```bash
./hermes red setup
```

No requiere editar JSON ni preparar certificados. PC B conserva los comandos
`hermes red job <host> ...`, `filter` y `cancel`; no necesita ejecutar setup
para actuar únicamente como solicitante. El asistente no inicia el servidor.

## Un solo flujo, en azul

Las preguntas, ayudas y resumen aparecen en azul. Ya no se muestra un menú
para elegir entre LAN y WSL. El asistente detecta el entorno: Linux utiliza
acceso directo; WSL consulta `wslinfo --networking-mode`, usando el proxy en NAT
y acceso directo en mirrored. En WSL antiguo sin esa herramienta usa NAT.
Otros modos no soportados producen un diagnóstico, sin guardar ajustes.

Los dos consentimientos se conservan: guardar JSON y, cuando corresponde,
aplicar cambios de Windows con autorización de administrador.

## Obtener la IP correcta sin elegir entre VMware y Wi-Fi

Cada pregunta muestra un comando y especifica en qué equipo y terminal debe
usarse. No se utiliza una IP de ejemplo como valor automático.

**PowerShell de PC A**, para obtener la IPv4 de su ruta de salida actual:

```powershell
Find-NetRoute -RemoteIPAddress 1.1.1.1 | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress
```

La consulta calcula una ruta; no requiere enviar tráfico a 1.1.1.1. El asistente
intenta ejecutar esa consulta automáticamente mediante powershell.exe, sin
solicitar administrador, y propone el resultado si es válido. Si no puede
obtenerlo, muestra la ayuda y solicita introducir la IP, sin reutilizar a ciegas
una dirección de Windows guardada anteriormente.

En el ipconfig compartido durante esta mejora, el adaptador Wi-Fi tenía
`10.204.218.198`, máscara `255.255.240.0` y gateway IPv4 `10.204.223.254`.
Las IP `192.168.206.1` y `192.168.37.1` correspondían a VMware VMnet1/VMnet8,
sin gateway. La IP LAN de Windows de A en esa captura era `10.204.218.198`, no
las IP VMware ni la antigua `192.168.1.74`. El gateway Wi-Fi no es la IP del
servidor y tampoco es el gateway interno de WSL.

**PowerShell de PC B**, con la IP de A ya conocida, para obtener la IPv4 que
B usaría para llegar al servidor:

```powershell
Find-NetRoute -RemoteIPAddress 10.204.218.198 | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress
```

El asistente construye este comando con la IP de A que se confirmó en ese
momento. Copiar el resultado obtenido en B, no la IP de A ni la IP interna de
WSL de B. No se presupone que B conserve `192.168.1.73` después de cambiar de red.

**WSL de PC A**, para obtener la IPv4 de origen hacia Windows de A:

```bash
ip -4 route get 10.204.218.198 | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}'
```

Copiar la única IP mostrada, sin `/20`. El asistente consulta las interfaces
actuales y propone una dirección local, prefiriendo la interfaz con ruta
predeterminada; comprueba que la respuesta pertenezca al equipo. En Linux
directo, muestra el mismo tipo de consulta hacia el cliente.

**WSL de PC A**, para obtener el gateway interno:

```bash
ip -4 route show default | awk '/default/ {print $3; exit}'
```

Este es el gateway/origen esperado del proxy, por ejemplo `172.25.64.1` en el
caso anterior. No sustituirlo por `10.204.223.254`, que era el gateway Wi-Fi de
Windows. Comprobar el origen real con el diagnóstico de la guía manual si la
autorización posterior falla.

Find-NetRoute elige la ruta al destino consultado. Con VPN o varias redes, la
ruta de salida puede diferir de la LAN que se quiere utilizar; confirmar que
ambos equipos tengan acceso a la red seleccionada. Obtener una IPv4 válida no
garantiza que el firewall, el router o la red permitan conexiones entre equipos.

## Paso 1: confirmar juntas las direcciones de PC A

El asistente detecta las direcciones de PC A antes de preguntar por otro equipo
y muestra un único bloque azul:

```text
Paso 1 — Configuración de PC-A

IP LAN de Windows de esta PC A [10.204.218.198]
IP interna de este WSL (PC A) [172.25.70.19]
Gateway PC-A / origen de Windows hacia WSL [172.25.64.1]
¿Estas son las direcciones que quiere configurar? [y/n]:
```

Los valores son los detectados en ese momento; este bloque es un ejemplo con
las direcciones aportadas por el usuario, no una configuración fija. Escribir
`y` para continuar. Escribir `n` para corregir las direcciones y volver a revisar
el bloque. Si falta algún dato detectado, se solicita con su comando de ayuda.
Ctrl+D cancela la entrada. No se guarda aún la configuración.

En Linux directo se confirma solo la interfaz del servidor y se omiten los
campos exclusivos de Windows/WSL.

## Paso 2: registrar PC B, PC C u otro equipo

Después de confirmar PC A aparecen las preguntas de la otra computadora:

```text
Paso 2 — Registrar la otra computadora
Nombre/ID de la otra computadora (por ejemplo PC-B o PC-C): PC-C
IP LAN de la otra computadora (PC-C): 200.39.175.140
```

Antes de pedir la IP se muestra el comando a ejecutar en esa otra computadora.
El nombre es el del equipo remoto, no el del gateway de PC A. Para actualizar
una computadora ya registrada, conservar su ID. Cada ID mantiene su propia
regla Windows `Hermes-<puerto>-<id>`: configurar PC C no reemplaza el archivo
PowerShell ni la regla de PC B.

Al final se revisan todos los cambios y se confirma guardar con `y` o cancelar
con `n` (Enter cancela). Si corresponde, se confirma por separado aplicar
Windows y se acepta la elevación. Se aceptan también las respuestas españolas
`s` y `si`, pero la interfaz presenta una sola forma `[y/n]`.

## Separación de servidor, gateway y equipos

El asistente guarda tres conceptos distintos en network.json:

- `servidor`: direcciones y puerto de PC A.
- `clientes`: permisos de acceso que Hermes puede distinguir por el origen TCP;
  en NAT incluye el único registro común `gateway-PC-A`.
- `equipos`: nombres e IP LAN de PC B, PC C y los demás, relacionados con ese
  acceso y con una regla de firewall por equipo.

Ejemplo de estructura (los programas y direcciones son ilustrativos):

```json
{
    "habilitada": true,
    "servidor": {
        "id": "PC-A",
        "modo": "wsl-nat",
        "ip_windows": "10.204.218.198",
        "interfaz": "172.25.70.19",
        "gateway_wsl": "172.25.64.1",
        "puerto": 45820
    },
    "clientes": [
        {
            "id": "gateway-PC-A",
            "tipo": "gateway",
            "ambito_trabajos": "pc-b-via-windows",
            "direcciones": ["172.25.64.1"],
            "operaciones": ["submit", "query", "list", "cancel"],
            "programas": ["sleep", "true", "false", "echo", "ls", "yes", "time", "bash"]
        }
    ],
    "equipos": [
        {
            "id": "PC-B",
            "ip_lan": "200.39.175.139",
            "acceso": "gateway-PC-A",
            "regla_firewall": "Hermes-45820-PC-B"
        },
        {
            "id": "PC-C",
            "ip_lan": "200.39.175.140",
            "acceso": "gateway-PC-A",
            "regla_firewall": "Hermes-45820-PC-C"
        }
    ]
}
```

La IP `200.39.175.139` de PC B en esta estructura es solo un ejemplo; se debe
registrar su dirección real. PC C utiliza la dirección proporcionada por el
usuario. El gateway `172.25.64.1` pertenece a PC A y no se repite como dirección
propia de cada equipo.

Si el origen del gateway ya pertenecía a `pc-b-via-windows`, setup renombra ese
registro a `gateway-PC-A`, conserva sus permisos y guarda el ID anterior en
`ambito_trabajos`. Esto conserva el acceso y la deduplicación de los trabajos
anteriores. No se debe borrar ese campo para cambiar solo el nombre visible.

Los equipos admitidos por el proxy comparten ese ámbito de trabajos: pueden
ver y administrar los trabajos del acceso común según sus permisos compartidos.
`equipos` no agrega autenticación por computadora ni permite al servidor
recuperar la IP original perdida por el proxy. La separación del firewall
permite admitir varias computadoras sin atribuirles identidades autenticadas
que el transporte actual no proporciona.

## Qué conserva y qué modifica

El asistente habilita la red, cambia la interfaz de escucha elegida y agrega
el origen a `redes_permitidas` bajo el bloqueo de configuración, conservando
las reglas anteriores. Conserva concurrencia, cola, directorio de datos y
propiedades adicionales de config.json.

En network.json conserva los otros registros y propiedades adicionales.
Conserva las operaciones, programas y direcciones del acceso existente. El ID
introducido en el segundo paso crea o actualiza el equipo, sin apropiarse del
gateway de PC A. Si el acceso es nuevo, asigna submit/query/list/cancel y los programas iniciales
sleep, true, false, echo, ls, yes, time y bash con sus rutas explícitas.
Autorizar bash o time permite lanzar otros programas a través de ellos.

Antes de escribir, valida la política completa y comprueba, bajo network.lock,
que network.json no haya cambiado mientras se contestaba. Las escrituras de
cada JSON son atómicas. Los dos archivos no constituyen una transacción única:
si falla el segundo guardado, el asistente informa que config.json ya se guardó.
Se conserva el primer respaldo de cada archivo en `config.json.setup.bak` y
`network.json.setup.bak`, sin sobrescribir respaldos anteriores.

Cancelar antes de confirmar no guarda ajustes ni ejecuta Windows. El arranque
normal del CLI puede haber creado previamente los archivos iniciales que
faltaban, como ocurre con cualquier comando de Hermes.

## Preparación de Windows

En modo NAT se genera un archivo revisable en el directorio de red:

```text
~/.local/share/hermes/network/setup-windows-<id>.ps1
```

Para nombres con dos puntos, el nombre del archivo sustituye esos caracteres
por guion bajo. El ID del cliente permanece igual.

El archivo configura:

- IP Helper (`iphlpsvc`) con inicio automático y servicio iniciado.
- El proxy TCP de la IP LAN Windows hacia la interfaz WSL, en el puerto actual.
- Una regla `Hermes-<puerto>-<id>` limitada a la IP LAN del cliente y al puerto.
- Actualización de esa misma regla si ya existe, sin crear otra en cada intento.
- Comprobación del listener; si falta, reinicio de IP Helper y nueva comprobación.

Las reglas de firewall se aplican a todos los perfiles, manteniendo la
restricción por IP local, IP remota y puerto. No se desactiva el firewall.
El asistente no borra otras reglas anteriores, incluidas las creadas durante
el procedimiento manual; revisar reglas antiguas si conceden acceso adicional.
El reinicio condicional de IP Helper puede afectar otras conexiones que lo usen.

Si se elige aplicar ahora, Hermes usa `wslpath` para convertir la ruta y llama a
`powershell.exe`, solicitando elevación con `Start-Process -Verb RunAs`.
`sudo` no sustituye a esa autorización de Windows. El comando espera el
resultado de PowerShell y reporta un error si la elevación se cancela o falla.
La política Bypass afecta solo a ese proceso, no cambia la política global.

Si se decide no aplicar aún, la configuración Linux queda guardada y el archivo
PowerShell preparado. Obtener su ruta Windows:

```bash
wslpath -w "$HOME/.local/share/hermes/network/setup-windows-pc-b-via-windows.ps1"
```

En PowerShell **como administrador**, ejecutar con la ruta que devolvió:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "RUTA_WINDOWS_DEVUELTA"
```

Si falla la interoperabilidad, la apertura de la ruta UNC de WSL, UAC o una
política administrada de Windows, el asistente no anuncia éxito de Windows.
Conserva la configuración local y el .ps1 para revisar y completar el paso.

## Comprobar el resultado

Iniciar el servidor en PC A, o detener con Ctrl+C la instancia anterior y
volver a iniciarla para que lea los cambios:

```bash
./hermes red start
```

Desde PowerShell de B:

```powershell
Test-NetConnection 192.168.1.74 -Port 45820
```

Desde WSL de B:

```bash
./hermes red job 192.168.1.74 sleep 30
```

Consultar el ID real con `filter id` y probar cancelación. El asistente verifica
los valores y, si se aplica Windows, el listener del proxy. No certifica que
PC B tenga conectividad, que el firewall no tenga reglas Block adicionales ni
que un trabajo remoto haya terminado: estas pruebas finales siguen siendo
necesarias. El cliente debe utilizar el mismo puerto del servidor.

## Límites actuales

El acceso directo detectado prepara Hermes; no administra el firewall de Linux ni el
firewall Hyper-V de WSL reflejado. El modo Windows automatizado cubre el caso
WSL NAT y portproxy del procedimiento comprobado.

Un proxy puede presentar la misma IP de origen para varias computadoras.
Ahora ese origen se registra una sola vez como gateway-PC-A y los equipos se
agregan por separado, con reglas de firewall independientes. No es necesario
renombrar cada equipo como el gateway ni sustituir la IP autorizada de B por
la de C. La comunicación sigue siendo TCP sin cifrado y los trabajos detrás
del proxy comparten el ámbito descrito arriba. La identidad autenticada por
cliente y el emparejamiento son etapas pendientes.

No se configura el arranque automático de Hermes, no se cambia .wslconfig,
no se activa el modo reflejado y no se instala una tarea de recuperación tras
reiniciar. Esos pasos son etapas posteriores del plan de instalación.

## Referencias

- [Procedimiento manual y diagnóstico PC A / PC B](red-wsl-pc-a-pc-b.md).
- [RF-18](../technical-guide/2-Nucleo%20del%20proyecto/RF-18.operaciones-remotas.md).
- [Microsoft: Start-Process y elevación](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-5.1).

- [Microsoft: Find-NetRoute, selección de dirección y ruta](https://learn.microsoft.com/powershell/module/nettcpip/find-netroute).


## PC B tiene una IP fuera de los rangos privados

Una LAN puede asignar a PC B una IP como `200.39.175.140`. El asistente admite
esa dirección individual: no exige que empiece por 10, 172.16–31 o 192.168.
Se conserva la autorización explícita por IP, sin abrir una subred pública.
No se aceptan direcciones de multicast, broadcast global, 0/8 ni link-local.
En WSL NAT, ese dato se aplica a RemoteAddress del firewall de Windows; Hermes
continúa registrando el origen real del proxy. No se debe reemplazar el gateway
WSL por la IP de PC B. Poder registrar la IP no garantiza que el router o la red
permitan comunicar las computadoras; se verifica después con Test-NetConnection.
