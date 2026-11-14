# Hermes Red: prueba completa entre PC A y PC B con WSL

Este procedimiento documenta la configuración que permitió comunicar los dos
equipos y el diagnóstico del bloqueo inicial. PC A recibe y ejecuta los trabajos;
PC B los solicita. No se utilizan certificados. La conexión es TCP sin cifrado,
con permisos de Hermes por dirección observada y firewall restringido a PC B.

## 1. Direcciones del caso comprobado

| Equipo | Windows, dirección LAN | WSL, dirección interna | Gateway de WSL |
| --- | --- | --- | --- |
| PC A, servidor | `192.168.1.74` | `172.25.70.19/20` | `172.25.64.1` |
| PC B, solicitante | `192.168.1.73` | `172.23.236.91` | `172.23.224.1` |

El recorrido es PC B → `192.168.1.74:45820` en Windows de A → proxy de
Windows → `172.25.70.19:45820` en WSL de A → Hermes y scheduler de A.

PC B debe conectar a la IP LAN de Windows de A. No debe usar su propia IP de
WSL ni la IP interna de WSL de A como destino LAN. PC B no necesita servidor,
portproxy ni regla de entrada para esta prueba. Las direcciones WSL y gateway
de B no se registran en Hermes de A.

El proxy crea otra conexión hacia WSL. En esta prueba Windows usó
`172.25.64.1` como origen hacia WSL de A: esa es la dirección que Hermes autoriza.
Windows limita el acceso al proxy por la IP LAN real de B, `192.168.1.73`.
Hermes no puede distinguir por sí solo varios clientes que entren mediante
ese mismo proxy; el registro `pc-b-via-windows` representa ese acceso.

## 2. Confirmar las direcciones antes de configurar

En PowerShell de cada equipo:

```powershell
ipconfig
```

En WSL de cada equipo:

```bash
ip -4 addr show eth0
ip -4 route show default
```

Si los resultados difieren de la tabla, sustituirlos en los pasos siguientes.
No poner `/20` en `interfaz`, en `direcciones` ni en `connectaddress`: esas
propiedades requieren la IP individual.

## 3. Actualizar y compilar en ambos equipos

Con la misma versión del proyecto en ambas computadoras, desde la raíz del
repositorio y dentro de WSL:

```bash
make -C src/hermes
```

La compilación ejecuta el arranque normal para crear los archivos que falten y
preparar los enlaces `src/hermes/data` y `src/hermes/config`. No requiere un
comando init. Usar `./hermes` desde `src/hermes` durante la prueba para no ejecutar
por accidente una versión instalada anterior. Si hay un servidor de red activo,
detenerlo con Ctrl+C antes de cambiar su configuración y volver a iniciarlo.

## 4. JSON completo de configuración general de PC A

En WSL de PC A:

```bash
mkdir -p "$HOME/.config/hermes"
cp -n "$HOME/.config/hermes/config.json" "$HOME/.config/hermes/config.json.antes-prueba-red"
nano "$HOME/.config/hermes/config.json"
```

Contenido para el usuario `leo` de PC A:

```json
{
    "directorio_datos": "/home/leo/.local/share/hermes/data",
    "trabajos_maximos": 10,
    "max_cola": 5,
    "interfaz": "172.25.70.19",
    "puerto": 45820,
    "redes_permitidas": [
        "127.0.0.0/8",
        "172.25.64.1"
    ]
}
```

Se mantienen la concurrencia 10, la cola 5 y el directorio de datos de A.
Si la instalación tiene otras propiedades personalizadas, conservarlas también.
Estos ejemplos usan `~/.config/hermes`; si se ha definido un `XDG_CONFIG_HOME`
absoluto, editar su subdirectorio `hermes` en lugar de la ruta predeterminada.

## 5. JSON completo de permisos remotos en PC A

En WSL de PC A:

```bash
mkdir -p "$HOME/.local/share/hermes/network"
nano "$HOME/.local/share/hermes/network/network.json"
```

Contenido:

```json
{
    "habilitada": true,
    "clientes": [
        {
            "id": "pc-b-via-windows",
            "direcciones": [
                "172.25.64.1"
            ],
            "operaciones": [
                "submit",
                "query",
                "list",
                "cancel"
            ],
            "programas": [
                "sleep",
                "true",
                "false",
                "/usr/bin/sleep",
                "/usr/bin/true",
                "/usr/bin/false"
            ]
        }
    ]
}
```

`query` y `list` son nombres internos del protocolo: el usuario sigue utilizando
`filter id`, `filter status` y `filter programa`. Los programas se autorizan por
su nombre literal: `sleep` y `/usr/bin/sleep` son entradas distintas.

## 6. Proxy de Windows y firewall: solo en PC A

Abrir **PowerShell como administrador en Windows de PC A**. No ejecutar estos
comandos en Bash/WSL ni configurar el reenvío en PC B.

Registrar el proxy:

```powershell
netsh interface portproxy add v4tov4 listenaddress=192.168.1.74 listenport=45820 connectaddress=172.25.70.19 connectport=45820
```

Si ya existe y solo hay que actualizar su destino:

```powershell
netsh interface portproxy set v4tov4 listenaddress=192.168.1.74 listenport=45820 connectaddress=172.25.70.19 connectport=45820
```

Revisar lo registrado:

```powershell
netsh interface portproxy show v4tov4
```

Debe mostrar esta relación:

```text
Listen: 192.168.1.74 45820     Connect: 172.25.70.19 45820
```

La existencia de la regla no confirma todavía que el puerto escuche o que
Windows pueda llegar al servicio de WSL.

Crear la regla de firewall si todavía no existe:

```powershell
if (-not (Get-NetFirewallRule -Name "Hermes-PC-B-45820" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule `
      -Name "Hermes-PC-B-45820" `
      -DisplayName "Hermes desde PC B" `
      -Direction Inbound `
      -Action Allow `
      -Protocol TCP `
      -LocalAddress 192.168.1.74 `
      -LocalPort 45820 `
      -RemoteAddress 192.168.1.73 `
      -Profile Any
}
```

Aplicar estos comandos también si la regla ya existía, para corregir permisos,
puerto y direcciones sin crear reglas duplicadas:

```powershell
Set-NetFirewallRule -Name "Hermes-PC-B-45820" -Enabled True -Direction Inbound -Action Allow -Profile Any

Get-NetFirewallRule -Name "Hermes-PC-B-45820" |
    Get-NetFirewallPortFilter |
    Set-NetFirewallPortFilter -Protocol TCP -LocalPort 45820

Get-NetFirewallRule -Name "Hermes-PC-B-45820" |
    Get-NetFirewallAddressFilter |
    Set-NetFirewallAddressFilter -LocalAddress 192.168.1.74 -RemoteAddress 192.168.1.73
```

Esto no desactiva el firewall ni autoriza a toda la LAN. Una regla Allow tampoco
anula reglas Block explícitas ni políticas administradas que puedan existir.

## 7. JSON completo de PC B

PC B utiliza el puerto 45820 para conectar al servidor. No necesita
`network.json`, credenciales ni ejecutar `red start`.

En WSL de PC B, este bloque genera el JSON completo con el HOME de su usuario;
se ejecuta como bloque de Bash, no se pega el texto `$HOME` directamente en un
editor JSON:

```bash
mkdir -p "$HOME/.config/hermes"
cp -n "$HOME/.config/hermes/config.json" "$HOME/.config/hermes/config.json.antes-prueba-red"

cat > "$HOME/.config/hermes/config.json" <<EOF_CONFIG
{
    "directorio_datos": "$HOME/.local/share/hermes/data",
    "trabajos_maximos": 5,
    "max_cola": 0,
    "interfaz": "127.0.0.1",
    "puerto": 45820,
    "redes_permitidas": [
        "127.0.0.0/8"
    ]
}
EOF_CONFIG
```

Esta plantilla usa valores iniciales para B. Si ya tiene un directorio,
concurrencia, cola u otras propiedades personalizadas, conservarlas y confirmar
únicamente que el puerto utilizado sea 45820. Si usa `XDG_CONFIG_HOME`, adaptar
la ruta del archivo como en PC A.

## 8. Iniciar el servidor y comprobar cada tramo

En WSL de PC A, desde la raíz del repositorio:

```bash
cd src/hermes
./hermes red start
```

Mantener esa terminal abierta. Debe mostrar:

```text
Hermes Red escuchando en 172.25.70.19:45820
```

En otra terminal WSL de A:

```bash
ss -ltnp 'sport = :45820'
```

Debe aparecer `LISTEN` en `172.25.70.19:45820`, asociado a `hermes`.
El PID y descriptor son variables; no deben coincidir con los de otra prueba.

En PowerShell de PC A:

```powershell
Test-NetConnection 172.25.70.19 -Port 45820
```

Resultado observado en el caso documentado:

```text
InterfaceAlias   : vEthernet (WSL (Hyper-V firewall))
SourceAddress    : 172.25.64.1
TcpTestSucceeded : True
```

En PowerShell de PC A como administrador:

```powershell
Get-Service iphlpsvc
Get-NetTCPConnection -State Listen -LocalPort 45820 -ErrorAction SilentlyContinue
Test-NetConnection 192.168.1.74 -Port 45820
```

Resultados esperados: IP Helper en `Running`, escucha en `192.168.1.74:45820`
y `TcpTestSucceeded : True`. Si IP Helper está detenido:

```powershell
Start-Service iphlpsvc
```

Repetir las comprobaciones después de iniciarlo.

Finalmente, en **PowerShell de PC B**:

```powershell
Test-NetConnection 192.168.1.74 -Port 45820
```

Debe aparecer `TcpTestSucceeded : True`. Un ping fallido no demuestra por sí solo
que el servicio TCP sea inaccesible. Esta prueba verifica el establecimiento
TCP; no prueba todavía la autorización de operaciones de Hermes.

## 9. Enviar, consultar y cancelar desde PC B

En WSL de PC B, desde `src/hermes`:

```bash
./hermes red job 192.168.1.74 sleep 120
```

Anotar el job ID devuelto. En los ejemplos siguientes se usa 7: reemplazarlo
por el ID real, sin asumir que el historial de A comienza en 1.

```bash
./hermes red filter 192.168.1.74 id 7
./hermes red filter 192.168.1.74 status RUNNING
./hermes red filter 192.168.1.74 programa sleep
./hermes red cancel 192.168.1.74 7
```

Esperar unos segundos y consultar de nuevo:

```bash
./hermes red filter 192.168.1.74 id 7
```

Debe terminar en `CANCELED`. Si estaba en ejecución, la primera respuesta de
cancelación indica solicitud aceptada, no necesariamente terminación inmediata.

Para comprobar éxito y error del programa:

```bash
./hermes red job 192.168.1.74 true
./hermes red job 192.168.1.74 false
```

Consultar cada nuevo ID: se espera `SUCCEEDED` con código 0 para `true`, y
`FAILED` con código 1 para `false`. El comando de admisión no sustituye la
consulta del resultado final.

Prueba de deduplicación opcional:

```bash
./hermes red job 192.168.1.74 --request-id prueba.red-001 sleep 30
./hermes red job 192.168.1.74 --request-id prueba.red-001 sleep 30
```

Debe reutilizar el mismo trabajo mientras se conserve su historial.

## 10. Incidente real: PC B no podía conectar

Al principio PC B informó `PingSucceeded : False` y
`TcpTestSucceeded : False`, aunque `portproxy show v4tov4` mostraba correctamente
`192.168.1.74:45820` → `172.25.70.19:45820`.

Se comprobó, en este orden:

1. WSL conservaba `172.25.70.19/20` en eth0.
2. Hermes escuchaba en `172.25.70.19:45820`.
3. Windows de A podía conectar a WSL de A: TCP True y origen `172.25.64.1`.
4. `iphlpsvc` estaba en Running.
5. Windows escuchaba en `192.168.1.74:45820` y podía conectar localmente: TCP True.
6. La regla de firewall estaba habilitada y permitía entrada, pero su filtro
   mostraba `RemoteAddress : 192.168.1.7`, en lugar de `192.168.1.73`.

El fallo estaba en la IP autorizada del firewall. Se corrigió en PowerShell
administrador de PC A con:

```powershell
Get-NetFirewallRule -Name "Hermes-PC-B-45820" |
    Get-NetFirewallAddressFilter |
    Set-NetFirewallAddressFilter -RemoteAddress 192.168.1.73
```

Se verificó el resultado completo, no solo que la regla existiera:

```powershell
Get-NetFirewallRule -Name "Hermes-PC-B-45820" |
    Format-List Enabled,Direction,Action,Profile

Get-NetFirewallRule -Name "Hermes-PC-B-45820" |
    Get-NetFirewallAddressFilter |
    Format-List LocalAddress,RemoteAddress
```

Debe mostrar:

```text
Enabled       : True
Direction     : Inbound
Action        : Allow
LocalAddress  : 192.168.1.74
RemoteAddress : 192.168.1.73
```

`Profile` se consulta con su nombre completo, no `Profil`. Después se repitió
`Test-NetConnection 192.168.1.74 -Port 45820` desde B. El usuario confirmó que la
corrección resolvió la conexión. No se necesitó desactivar el firewall ni cambiar
los permisos de trabajos para resolver ese bloqueo TCP.

## 11. Diagnóstico rápido y cambios posteriores de IP

| Resultado | Revisar |
| --- | --- |
| Windows de A no conecta a `172.25.70.19:45820` | IP actual de WSL, interfaz configurada, servidor iniciado y acceso Windows → WSL |
| Windows de A llega a WSL, pero no escucha en `192.168.1.74:45820` | Portproxy e IP Helper |
| Todas las pruebas de A pasan, pero B falla | IP LAN actual de B, filtro RemoteAddress completo, reglas Block y conectividad LAN |
| `UNAUTHORIZED` desde el CLI | Habilitación, registro del origen observado y permisos de operación en network.json |
| Conexión cerrada sin respuesta | Filtro redes_permitidas y origen que observa WSL |
| `PROGRAM_NOT_ALLOWED` | Nombre literal del programa en programas |
| ID no encontrado | ID real, registro propietario y equipo servidor consultado |

Si cambia la IP WSL de A, actualizar `interfaz` y `connectaddress` del proxy.
Si cambia la IP LAN de Windows de A, actualizar `listenaddress`, `LocalAddress`
del firewall y el destino de los comandos de B. Si cambia la IP LAN de B,
actualizar `RemoteAddress`. Si cambia el gateway/origen del proxy hacia WSL,
actualizar `redes_permitidas` y `clientes[].direcciones`, conservando el `id` del
registro para mantener el acceso al historial. Reiniciar Hermes Red tras cambiar
sus JSON. No es necesario editar el gateway de WSL de B en Hermes de A.

Ctrl+C detiene el servicio de red en A. El scheduler local se administra por
separado con `./hermes clean scheduler`; ese comando afecta los trabajos activos.

## Referencias

- [RF-18: operaciones remotas](../technical-guide/2-Nucleo%20del%20proyecto/RF-18.operaciones-remotas.md).
- [Microsoft: acceso LAN a WSL y portproxy](https://learn.microsoft.com/es-es/windows/wsl/networking#accessing-a-wsl-2-distribution-from-your-local-area-network-lan).
