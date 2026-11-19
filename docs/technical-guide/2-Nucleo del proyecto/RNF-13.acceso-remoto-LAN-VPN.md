# RNF-13: Acceso remoto limitado a LAN/VPN

## Objetivo

Limitar los espacios de direcciones que pueden autorizarse para acceso remoto.
Estar en una LAN o VPN no autoriza automáticamente a un equipo: sus direcciones
además deben coincidir con la lista configurada mediante RF-20.

## Espacios admitidos

Las reglas de subred deben estar contenidas íntegramente en uno de estos espacios:

- Loopback: `127.0.0.0/8`.
- Privados RFC1918: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
- Compartido para VPN que lo utilicen: `100.64.0.0/10`.

También se admiten direcciones unicast individuales explícitas, sin prefijo o
con `/32`, aunque estén fuera de RFC1918: por ejemplo `200.39.175.140` asignada
a un equipo de una LAN. La clase de dirección no prueba por sí sola si el
equipo está en una LAN, VPN o Internet. Esta excepción permite registrar un
equipo concreto; no habilita subredes públicas como `200.39.175.0/24`.

Los bits de host de las subredes privadas se normalizan. Se rechazan nombres
DNS, IPv6, prefijos fuera de 0–32, tipos JSON incorrectos, `0.0.0.0/0`, el
espacio 0/8, multicast/reservado 224/4 y superiores y link-local 169.254/16.
El servidor sigue exigiendo una coincidencia exacta con los permisos configurados.

## Política de acceso

Sin configuración explícita, solo se permite loopback (`127.0.0.0/8`). Para
habilitar LAN/VPN es necesario configurar la interfaz de escucha y autorizar los
orígenes. Una escucha en `0.0.0.0` no amplía los espacios admitidos ni la lista de
orígenes autorizados.

Hermes no identifica automáticamente si una dirección pertenece a una LAN o una
VPN. El administrador define los rangos; el servidor utiliza la dirección de
origen observada por TCP, incluido cualquier NAT intermedio.

El filtro de origen no autentica la identidad del nodo.
[RF-18](RF-18.operaciones-remotas.md) utiliza clientes registrados por IP y
autorización por operación y programa para trabajos procesados en el servidor.
El emparejamiento y control exclusivo de clientes ejecutores siguen pendientes.

## Verificación

Las pruebas de `src/hermes/tests/network_access.sh` comprueban los límites de
los espacios privados, loopback y VPN compartida, y el rechazo de direcciones
no autorizadas y subredes fuera de los espacios admitidos; las IP unicast
individuales explícitas se verifican como excepciones /32.

La configuración y aplicación de la lista se describen en
[RF-20: Restricción a redes y direcciones permitidas](RF-20.restriccion-redes-direcciones.md).
