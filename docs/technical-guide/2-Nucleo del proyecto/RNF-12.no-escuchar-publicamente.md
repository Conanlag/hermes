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
No equivale a restringir acceso a LAN/VPN. RNF-13 y RF-20 implementarán la
validación de direcciones de origen; esta entrega solo cubre RNF-12 y la base TCP.
El firewall y la topología del entorno pueden impedir el acceso desde otro equipo.

## Alcance del diagnóstico TCP

Cada conexión recibe, si la escritura es posible, una respuesta JSON delimitada
por salto de línea y se cierra inmediatamente:

```json
{"version":1,"ok":false,"error":"REMOTE_OPERATIONS_UNAVAILABLE"}
```

Esta respuesta permite comprobar conectividad; no representa todavía el
protocolo HNP completo. El servicio no interpreta solicitudes ni ofrece envío,
consulta o cancelación de trabajos. No se incluyen aún autenticación ni TLS.
Los sockets aceptados son no bloqueantes y no se retienen conexiones de clientes.
El backlog de escucha es 10; no constituye un límite configurable de sesiones.

## Verificación

```sh
make -C src/hermes
python3 src/hermes/tests/network_listener.py
```

Las pruebas usan un HOME temporal y verifican el bind real en `/proc/net/tcp`,
la escucha predeterminada, configuración explícita, fallback de interfaz inválida,
rechazo de puerto ocupado, conexiones sucesivas y cierre con SIGTERM.
