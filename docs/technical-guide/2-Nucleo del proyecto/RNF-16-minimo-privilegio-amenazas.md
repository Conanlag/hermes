# RNF-16: Mínimo privilegio y modelo básico de amenazas

## Principio de mínimo privilegio

Hermes debe ejecutarse con el usuario del operador, no como `root`:

- El arranque rechaza ejecución con UID efectivo 0.
- No instala binarios setuid ni requiere privilegios administrativos.
- Los datos se crean bajo el directorio personal del usuario.
- Los puertos configurados comienzan en 1024 para evitar requerir privilegios
  reservados.
- Los Jobs se ejecutan como proceso hijo del usuario que inició Hermes.
- No se utiliza shell para interpretar el programa y sus argumentos remotos;
  el lanzamiento usa `execvp`.
- Las operaciones remotas requieren identidad IP, operación permitida y programa
  permitido explícitos.

## Activos que proteger

- `jobs.json` y metadatos de Jobs.
- `events.jsonl` y otros registros operativos.
- Procesos hijo y capacidad de ejecución.
- Archivos de configuración e identidad de clientes.
- Disponibilidad del scheduler y del servidor.

## Modelo básico de amenazas

| Amenaza | Riesgo | Mitigación |
| --- | --- | --- |
| Cliente desde una red no autorizada | Intenta leer o modificar Jobs | Filtro por IP, loopback y redes privadas; operación autorizada |
| Suplantación de una dirección IP | Permisos asignados a la dirección observada | Modelo basado en IP; no sustituye autenticación criptográfica |
| Mensaje mal formado o excesivo | Parser, consumo de memoria o indisponibilidad | Longitud, UTF-8, NUL, profundidad y delimitación acotados |
| Programa no autorizado | Ejecución arbitraria | Lista blanca por cliente y validación estricta |
| Argumento sensible o secreto | Exposición en logs | Redacción central de eventos |
| Escritura parcial/corrupción | Pérdida del estado persistido | Bloqueos, escritura temporal, fsync y rename |
| Saturación de conexiones o trabajos | Bloqueo del servicio | Cupo de clientes, plazo de socket y capacidad de cola |
| Ejecución como administrador | Escalamiento del impacto de Jobs | Rechazo de UID efectivo 0 |

## Límites conocidos

La dirección IPv4 es identificación de configuración, no autenticación fuerte.
Los Jobs tienen los permisos del usuario de Hermes y no disponen de contenedor,
seccomp ni sandbox por proceso. El administrador debe aislar el equipo y utilizar
VPN/firewall si necesita separar redes.

## Evidencia

- [main.cpp](../../../src/hermes/src/main.cpp) rechaza ejecución como root.
- [process.cpp](../../../src/hermes/src/process/process.cpp) usa `execvp` directo
  sin una shell intermediaria.
- [remote.cpp](../../../src/hermes/src/network/remote.cpp) aplica permisos por
  operación y programa.
- [storage.cpp](../../../src/hermes/src/storage/storage.cpp) protege persistencia.

**Estado: CUMPLE.**
