# ADR-016: Arquitectura cliente-servidor centralizada para Hermes Red

## Contexto

Hermes actualmente permite administrar y ejecutar trabajos mediante un scheduler local. Para extender su funcionamiento a una red de equipos, se requiere establecer una arquitectura que permita solicitar, distribuir y ejecutar trabajos de manera remota, conservando la administración centralizada de las operaciones.

La solución debe permitir que diferentes equipos se conecten a un servidor principal, envíen solicitudes y, cuando estén autorizados, participen en la ejecución de trabajos remotos.

Se identifican tres equipos de referencia:

- **PC-A:** servidor principal que administra las conexiones de los clientes, recibe solicitudes, autoriza operaciones y distribuye trabajos hacia los equipos correspondientes.
- **PC-B:** cliente que puede enviar solicitudes al servidor principal y también recibir instrucciones autorizadas para ejecutar trabajos mediante su scheduler local. Conserva la capacidad de ejecutar trabajos propios.

El problema principal consiste en evitar una arquitectura descentralizada en la que los clientes puedan comunicarse directamente, administrar otros equipos o enviar instrucciones sin pasar por el servidor principal.

También se requiere considerar redes LAN, VPN y entornos donde las direcciones IP pueden cambiar mediante DHCP.

## Decisión

Se establece una **arquitectura cliente-servidor centralizada**, en la que PC-A será el único servidor principal y todos los demás equipos conectados funcionarán como clientes.

La comunicación entre los nodos deberá pasar exclusivamente por PC-A. No se permitirá la comunicación directa entre clientes para solicitar trabajos, administrar procesos, consultar schedulers o enviar instrucciones de ejecución.

### 1. Servidor principal (PC-A)

PC-A tendrá las siguientes responsabilidades:

- Administrar las conexiones de los clientes.
- Recibir solicitudes de los clientes conectados.
- Autenticar a los clientes y autorizar las operaciones solicitadas.
- Determinar qué equipo ejecutor recibirá cada trabajo.
- Distribuir instrucciones hacia los clientes ejecutores autorizados.
- Recibir resultados y estados de ejecución.
- Proporcionar información a los clientes solicitantes.
- Administrar las asociaciones y permisos de los equipos conectados.

PC-A también conservará la capacidad de ejecutar trabajos locales mediante su propio scheduler.

### 2. Clientes (PC-B, PC-C y otros equipos)

Los equipos conectados a PC-A funcionarán como clientes y podrán realizar solicitudes al servidor principal.

Un cliente podrá contar con las siguientes capacidades:

- Solicitar la ejecución de trabajos remotos.
- Consultar el estado de sus solicitudes.
- Recibir resultados proporcionados por el servidor.
- Ejecutar trabajos locales mediante su propio scheduler, independientemente de las operaciones remotas.
- Recibir instrucciones remotas de ejecución cuando el servidor lo autorice y el equipo tenga habilitada la capacidad de ejecución.

Por lo tanto, PC-B podrá actuar simultáneamente como cliente solicitante y cliente ejecutor.

PC-C representa un cliente que solicita operaciones al servidor, sin necesidad de participar en la ejecución de trabajos remotos.

### 3. Comunicación centralizada

Toda comunicación relacionada con operaciones de red deberá pasar por PC-A.

El flujo general será:

1. Un cliente establece una conexión con PC-A.
2. El cliente envía una solicitud al servidor.
3. PC-A valida la identidad, los permisos y la operación solicitada.
4. PC-A determina si puede procesar la solicitud localmente o si debe distribuirla a otro cliente ejecutor.
5. Si corresponde, PC-A envía la instrucción al ejecutor autorizado.
6. El cliente ejecutor procesa el trabajo mediante su scheduler local.
7. El ejecutor devuelve el resultado al servidor.
8. PC-A actualiza el estado de la solicitud y comunica el resultado al cliente solicitante.

Los clientes no podrán establecer sesiones de administración o ejecución directamente entre ellos.

### 4. Conexiones y autorización

Se establece que los clientes deberán mantener una conexión autorizada con el servidor principal para recibir instrucciones remotas.

La relación de conexión entre PC-A y cada cliente ejecutor deberá ser exclusiva respecto al control remoto: el cliente ejecutor únicamente aceptará instrucciones de ejecución provenientes de su servidor autorizado.

El servidor administrará la asociación de los clientes y conservará su identidad independientemente de los cambios de dirección IP.

La conexión deberá permitir comunicación bidireccional para que PC-A pueda enviar instrucciones y recibir resultados sin requerir que otros clientes establezcan conexiones directas con el ejecutor.

### 5. Identidad y direccionamiento de red

Cada instalación de Hermes deberá contar con un identificador único y persistente (UUID).

La dirección IP no será utilizada como identificador permanente de un equipo, debido a que puede cambiar por asignaciones DHCP o modificaciones en la configuración de red.

Se contemplan dos mecanismos de conexión:

- **Conexión manual:** mediante dirección IP o hostname.
- **Descubrimiento automático:** mediante mecanismos como mDNS/DNS-SD, cuando la infraestructura de red lo permita.

Se priorizará la compatibilidad con DHCP, manteniendo la posibilidad de utilizar direcciones IP estáticas.

### 6. Ejecución y persistencia

Cada equipo ejecutor utilizará su propio scheduler local para procesar los trabajos que reciba.

El servidor no modificará directamente los archivos de persistencia de los clientes ni compartirá sus archivos `jobs.json`.

Los trabajos remotos deberán conservar información que permita identificar su origen, solicitante, servidor controlador y equipo ejecutor.

La ejecución local de un cliente deberá mantenerse independiente de su conexión con el servidor. Una pérdida de conexión no deberá interrumpir los trabajos locales.

Para los trabajos remotos afectados por una desconexión, se contempla el estado `INTERRUPTED`, evitando que una pérdida de comunicación produzca estados inconsistentes o que los trabajos se reanuden automáticamente sin una nueva autorización.

### 7. Protocolo de comunicación

Se propone utilizar TCP con intercambio de mensajes JSON para la comunicación entre el servidor y los clientes.

El protocolo deberá contemplar:

- Identificación de los equipos.
- Autenticación y autorización.
- Solicitudes de ejecución.
- Distribución de instrucciones.
- Actualización de estados.
- Entrega de resultados.
- Detección de desconexiones.
- Reconexión de clientes.
- Identificación única de solicitudes para evitar duplicados.

Se contempla el uso de TLS para proteger la comunicación y mecanismos de autenticación para impedir que equipos no autorizados participen en la red Hermes.

## Justificación

| Criterio                    | Decisión                                                               | Alternativas consideradas                                  | Consecuencias                                                                      |
| --------------------------- | ---------------------------------------------------------------------- | ---------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Arquitectura                | Cliente-servidor centralizada                                          | P2P y arquitectura distribuida                             | Todas las operaciones de red pasan por un único servidor principal.                |
| Administración              | PC-A administra las conexiones y autorizaciones                        | Administración distribuida entre clientes                  | Se centraliza el control y se evita que un cliente administre directamente a otro. |
| Capacidades de los clientes | Un cliente puede solicitar trabajos y, si está autorizado, ejecutarlos | Separar permanentemente clientes solicitantes y ejecutores | PC-B puede desempeñar ambas funciones sin convertirse en servidor.                 |
| Comunicación                | Todas las comunicaciones de red pasan por PC-A                         | Comunicación directa entre clientes                        | Se evita la ejecución y administración remota fuera del control del servidor.      |
| Ejecución                   | Cada equipo utiliza su scheduler local                                 | Compartir un scheduler o archivos de persistencia          | Se conserva la independencia de ejecución y almacenamiento de cada equipo.         |
| Direccionamiento            | UUID persistente y soporte para DHCP e IP estática                     | Identificación basada exclusivamente en IP                 | Los cambios de dirección no modifican la identidad del equipo.                     |
| Descubrimiento              | Manual y automático                                                    | Configuración exclusivamente manual                        | Se facilita la incorporación de equipos en diferentes redes.                       |
| Recuperación                | Reconexión y tratamiento de trabajos interrumpidos                     | Continuar trabajos sin validar su estado                   | Se reducen inconsistencias ante pérdidas de conexión.                              |
| Seguridad                   | Autenticación, autorización y TLS                                      | Confiar únicamente en la presencia dentro de la LAN        | Se evita que cualquier equipo conectado pueda enviar instrucciones no autorizadas. |

### Consecuencias positivas

- Se mantiene un único punto de administración de la red.
- Los clientes pueden solicitar trabajos sin tener acceso directo a otros equipos.
- Un cliente puede actuar como solicitante y ejecutor simultáneamente.
- Se conserva la ejecución local de trabajos independientemente de la conectividad.
- Cada equipo mantiene su propio scheduler y almacenamiento.
- La identidad de los nodos permanece estable aunque cambie su dirección IP.
- Se facilita la administración de permisos y conexiones desde el servidor principal.

### Consecuencias negativas y riesgos

- PC-A se convierte en un punto central de dependencia para las operaciones remotas.
- Si PC-A deja de estar disponible, los clientes no podrán procesar nuevas solicitudes remotas ni recibir nuevas instrucciones.
- El servidor deberá administrar múltiples conexiones simultáneas.
- Será necesario implementar mecanismos de autenticación, autorización y recuperación de conexiones.
- La comunicación centralizada puede introducir latencia adicional respecto a una conexión directa.
- El descubrimiento automático mediante mDNS puede no funcionar entre diferentes subredes o determinadas configuraciones VPN.
- Será necesario controlar la duplicación de solicitudes cuando existan desconexiones y reintentos.

### Evidencia técnica

La arquitectura se fundamenta en un modelo de comunicación cliente-servidor mediante conexiones TCP persistentes.

Los clientes podrán iniciar conexiones salientes hacia PC-A, lo que facilita su funcionamiento en redes con DHCP, firewalls y determinadas configuraciones VPN. Una vez establecida la sesión, PC-A podrá enviar instrucciones y recibir resultados a través del mismo canal.

La identidad persistente mediante UUID permitirá asociar cada cliente con sus permisos y registros, sin depender de una dirección IP específica.

El uso de schedulers locales permitirá conservar la implementación existente de Hermes y evitar que la administración de trabajos remotos requiera compartir archivos de persistencia entre equipos.

## Resultado esperado

Hermes Red funcionará como un sistema centralizado donde PC-A administra todas las operaciones de red y los demás equipos participan como clientes.

Los clientes podrán solicitar trabajos al servidor y, cuando estén autorizados, recibir instrucciones para ejecutarlos localmente. Ningún cliente tendrá la capacidad de administrar directamente a otro cliente ni de enviarle instrucciones sin intervención del servidor principal.

La arquitectura permitirá ampliar la cantidad de equipos conectados sin modificar el principio fundamental de comunicación: **toda operación de red entre nodos deberá pasar por el servidor principal.**