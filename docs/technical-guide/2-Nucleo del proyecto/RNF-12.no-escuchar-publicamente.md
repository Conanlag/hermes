# RNF-12: El servicio no deberá escuchar en interfaces públicas de forma predeterminada.

`hermes red start` inicia un servidor TCP en primer plano usando `interfaz` y
`puerto` de RF-16. Sin configuración explícita escucha en `127.0.0.1:45820`.
Una interfaz inválida también vuelve a `127.0.0.1`; no hay fallback automático
a `0.0.0.0` si falla el bind. Una dirección que no pertenece al equipo o un puerto
ocupado producen un error y código de salida 1.

El comando no inicia el scheduler. Ctrl+C o SIGTERM cierran la escucha y liberan
el puerto. Esta primera fase todavía no incluye daemonización ni los comandos
`red status`, `red stop`, descubrimiento o conexiones persistentes.

## Configuración explícita para LAN

En el archivo de configuración existente, establecer `interfaz` a la dirección
IPv4 de la interfaz LAN del servidor y conservar el resto de las claves:

```json
{
    "interfaz": "192.168.1.20",
    "puerto": 45820
}
```

La dirección del ejemplo debe reemplazarse por una dirección real del equipo.
Los otros equipos conectan a esa dirección y puerto. La configuración se lee al
arrancar; para cambiarla hay que detener y volver a iniciar el servicio.

`0.0.0.0`, si se configura explícitamente, escucha en todas las interfaces IPv4.
No equivale a restringir acceso a LAN/VPN. [RNF-13](RNF-13.acceso-remoto-LAN-VPN.md) define los espacios admitidos y
[RF-20](RF-20.restriccion-redes-direcciones.md) aplica la lista de orígenes
autorizados mediante `redes_permitidas`.
El firewall y la topología del entorno pueden impedir el acceso desde otro equipo.

## Diagnóstico y verificación

La escucha ahora utiliza el protocolo documentado en
[RNF-08: Solicitudes inválidas](RNF-08.solicitudes-invalidas.md).
El cliente debe enviar un objeto JSON terminado en salto de línea; una solicitud
`ping` válida recibe `pong`. Ya no se envía un diagnóstico espontáneo al conectar.

```sh
make -C src/hermes
python3 src/hermes/tests/network_invalid.py
```

Las pruebas usan un HOME temporal y comprueban solicitudes, continuidad del
servicio, rechazo de origen y cierre con SIGTERM.
