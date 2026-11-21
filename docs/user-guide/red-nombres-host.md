# Usar un nombre en lugar de la IP en Hermes Red

Hermes ya permite usar un nombre de host en `red job`, `red filter` y
`red cancel`. El cliente utiliza `getaddrinfo` para resolver ese nombre a una
dirección IPv4 antes de conectarse. No requiere modificar ni recompilar Hermes.

Este procedimiento configura un nombre local en el equipo cliente (PC B),
desde donde se envían los comandos al servidor (PC A).

## 1. Registrar el nombre en el cliente

En Linux o en la misma distribución WSL donde ejecutas Hermes, abre:

```bash
sudo nano /etc/hosts
```

Conserva las entradas existentes y agrega una línea con la IP del servidor y
el nombre que quieras utilizar:

```text
192.168.1.74 equipo-a
```

Sustituye `192.168.1.74` por la IP real que ya usas para conectar con PC A.
En el caso WSL NAT de la [guía PC A / PC B](red-wsl-pc-a-pc-b.md), corresponde
a la IP LAN de Windows de A, donde escucha el proxy hacia WSL.

Guarda con **Ctrl+O**, Enter, y sal con **Ctrl+X**.

La asociación solo se configura en ese cliente; no publica el nombre para
los demás equipos. Si ejecutas Hermes en WSL, edita `/etc/hosts` dentro de
esa distribución. WSL puede regenerar este archivo al reiniciarse: si el
nombre deja de funcionar, comprueba que la entrada siga presente.

## 2. Comprobar la resolución

En la misma terminal Linux o WSL del cliente:

```bash
getent ahostsv4 equipo-a
```

La salida debe contener la IPv4 que registraste. Puede aparecer varias veces
para distintos tipos de socket. Si no devuelve resultados, revisa la entrada
y que el nombre esté escrito igual.

Resolver el nombre confirma la asociación con la IP; todavía no comprueba
que el servicio Hermes esté disponible ni que autorice al cliente.

## 3. Enviar, consultar y cancelar

Desde el directorio que contiene el ejecutable:

```bash
./hermes red job equipo-a sleep 30
```

Anota el ID devuelto. Sustituye `7` por ese ID en los comandos siguientes:

```bash
./hermes red filter equipo-a id 7
./hermes red filter equipo-a status RUNNING
./hermes red filter equipo-a programa sleep
./hermes red cancel equipo-a 7
```

El nombre reemplaza únicamente el argumento `<host>`: aún debes escribir
`equipo-a` en cada comando. Actualmente no hay un servidor predeterminado
que permita omitir ese argumento.

## Configuración y diagnóstico

- Si cambia la IP del servidor, actualiza su entrada en `/etc/hosts`.
- Si el nombre ya resuelve mediante el DNS de tu red a una IPv4 válida,
  puedes usarlo directamente sin agregar una entrada local.
- El cliente actual resuelve solo IPv4 y mantiene las restricciones de
  direcciones LAN/VPN de Hermes.
- El nombre no sustituye la autorización por IP de origen en `network.json`,
  ni las reglas del firewall o el proxy de WSL. El ID de cliente registrado
  por `red setup` tampoco crea automáticamente un nombre resoluble.
- Si `getent` devuelve la IP correcta pero Hermes no conecta, prueba el mismo
  comando con esa IP y sigue el diagnóstico de la
  [guía PC A / PC B](red-wsl-pc-a-pc-b.md).

Para preparar el servidor, consulta el
[asistente `hermes red setup`](red-setup.md).

## Referencias

- [getaddrinfo(3): resolución de nombres y servicios](https://man7.org/linux/man-pages/man3/getaddrinfo.3.html).
- [hosts(5): formato de `/etc/hosts`](https://man7.org/linux/man-pages/man5/hosts.5.html).
