# RNF-26: Demostración por red privada o VPN

## Alcance permitido

La demostración remota no debe exponerse directamente a Internet. Hermes limita
interfaces y orígenes a:

- Loopback: `127.0.0.0/8`.
- Redes privadas RFC1918: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
- Rango compartido usado por VPN: `100.64.0.0/10`.

No se permite `0.0.0.0` como interfaz. Las direcciones públicas individuales,
subredes públicas, enlaces locales, multicast y rangos reservados se rechazan.

## Controles

1. `interfazValida()` acepta solo direcciones privadas o de loopback.
2. `reglaRedValida()` acepta solo subredes privadas completas o loopback.
3. `origenRedPermitido()` rechaza listas inválidas o orígenes públicos.
4. El bind por configuración falla o conserva el fallback seguro a loopback.
5. `network.json` exige direcciones IPv4 que cumplan el mismo límite.

Esto evita que la demostración dependa de Internet público. La exposición real
también debe protegerse con firewall y reglas LAN/VPN.

## Evidencia

- [access.cpp](../../../src/hermes/src/network/access.cpp)
- [config.cpp](../../../src/hermes/src/config/config.cpp)
- [RNF-13: acceso remoto LAN/VPN](RNF-13.acceso-remoto-LAN-VPN.md)
- [RF-20: restricción de redes](RF-20.restriccion-redes-direcciones.md)

**Estado: CUMPLE.**
