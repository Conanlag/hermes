# RNF-12: El servicio no deberá escuchar en interfaces públicas de forma predeterminada.

`hermes red start` inicia un servidor TCP en primer plano usando `interfaz` y
`puerto` de RF-16. Sin configuración explícita escucha en `127.0.0.1:45820`.
Una interfaz inválida también vuelve a `127.0.0.1`; no hay fallback automático
a `0.0.0.0` si falla el bind. Una dirección que no pertenece al equipo o un puerto
ocupado producen un error y código de salida 1.

Con `network.json` habilitado, el comando inicia el scheduler antes de abrir
la escucha; si está deshabilitado, solo atiende ping y no lo inicia. Ctrl+C o
SIGTERM cierran la escucha y liberan el puerto; el scheduler se administra por
separado. No incluye daemonización ni los comandos `red status`, `red stop`
o descubrimiento. RNF-24 admite solicitudes secuenciales en una conexión,
sin sesiones de identidad autenticadas.

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

`0.0.0.0` no está permitido como interfaz: [RNF-26](RNF-26-demostracion-red-privada.md)
limita la escucha a loopback, redes privadas RFC1918 y el rango compartido de VPN.
[RNF-13](RNF-13.acceso-remoto-LAN-VPN.md) define los espacios admitidos y
[RF-20](RF-20.restriccion-redes-direcciones.md) aplica la lista de orígenes
autorizados mediante `redes_permitidas`.
El firewall y la topología del entorno pueden impedir el acceso desde otro equipo.

## Diagnóstico y verificación

La escucha ahora utiliza el protocolo documentado en
[RNF-08: Solicitudes inválidas](RNF-08.solicitudes-invalidas.md).
El cliente debe enviar un objeto JSON terminado en salto de línea; una solicitud
`ping` válida recibe `pong`. Ya no se envía un diagnóstico espontáneo al conectar.

```sh
make -C src/hermes hermes
bash verif/scripts/TC-011.sh
```

[TC-011](../../../verif/test-cases/TC-011.md) utiliza HOME y XDG_CONFIG_HOME
temporales y puertos libres propios. Comprueba escucha real con `ss`, fallback
seguro a loopback, error de bind por puerto ocupado o interfaz no asignada,
continuidad y cierre con SIGTERM. La evidencia se conserva en
`verif/results/results_TC-011.md` (PASS, 2026-11-27).
