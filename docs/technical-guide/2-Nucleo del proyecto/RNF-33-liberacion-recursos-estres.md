# RNF-33 — Liberación de recursos después de pruebas de estrés

## Descripción

Al concluir una carga de estrés, Hermes deberá liberar la memoria retenida por el scheduler, los procesos hijos, los descriptores de archivos y los sockets utilizados, así como los archivos temporales de persistencia.

## Categoría

Confiabilidad y gestión de recursos.

## Métrica de aceptación

Se comparan el scheduler y el servidor TCP real antes y después de la carga, sin reiniciarlos entre rondas:

- El RSS posterior de cada proceso no excede su línea base en más de **8192 KiB**.
- La cantidad de descriptores y sockets regresa a la línea base de cada servicio.
- No quedan procesos de trabajos ni archivos `jobs.json.tmp.*` en reposo. Los hijos se inspeccionan en todas las tareas, incluidos workers.
- El scheduler iniciado por el servidor es infraestructura persistente, se identifica por `scheduler.lock` y se mide separadamente; su presencia no se interpreta como un Job filtrado.
- Al detener el servidor, cierran los clientes abiertos y la escucha, se recoge el proceso y el puerto se puede reutilizar.
- Al detener el scheduler, libera sus descriptores; la limpieza final exige ausencia de procesos con el HOME temporal del servicio.

Con Hermes Red activo hay un socket de escucha legítimo. La prueba debe observar sockets aceptados durante la carga y comprobar su liberación, no limitarse a contar cero sockets en el scheduler. TIME_WAIT del kernel no es un descriptor abierto.

## Verificación

El caso [TC-024](../../../verif/test-cases/TC-024.md) utiliza un servidor real aislado en loopback, HOME/XDG temporales y puerto libre. Por defecto ejecuta **100 Jobs true locales + 100 por CLI TCP y dos de calentamiento**. Dos rondas sobre los mismos servicios mantienen además 16 conexiones simultáneas con pong confirmado, ciclos de conexión/cierre normal y RST, abortos a mitad de mensaje y cuatro clientes abiertos al detener el servidor.

La concurrencia de la prueba es 10 y la cola tiene 10 cupos. Cada lote de diez Jobs debe terminar antes del siguiente: el submit TCP confirma admisión sin esperar al scheduler. La saturación de cola se verifica en otros casos y no se trata como fuga de recursos.

```bash
make -C src/hermes hermes
bash verif/scripts/TC-024.sh

# Otro volumen por via, manteniendo los mismos criterios:
bash verif/scripts/TC-024.sh 500
```

HERMES_TEST_PORT permite fijar un puerto libre distinto de 45820. La inspección de recursos y el cierre requieren modo local; una conexión desde PC B no permite medir por sí sola los recursos del servidor. No hace falta modificar portproxy ni firewall de Windows/WSL.

## Evidencia y cobertura

Los resultados acumulados y las métricas de cada ronda están en [results_TC-024.md](../../../verif/results/results_TC-024.md). Los PASS parcial históricos se conservan y describen una versión que todavía no ejercitaba sockets. La ficha actual reemplaza la afirmación obsoleta de que Hermes no implementa red.

**Estado vigente: PASS**, ejecución del 2026-11-27 20:25:48 -0600, AC1–AC6 y código 0. Se completaron 202 Jobs; el servidor volvió a 5 FDs/1 socket y el scheduler a 4 FDs/0 sockets después de observar 17 sockets simultáneos en Hermes Red. Los incrementos RSS fueron 768 KiB y 8056 KiB, respectivamente, dentro de 8192 KiB; el segundo está próximo al umbral. La parada cerró clientes y escucha y permitió reutilizar el puerto. La cobertura es de recursos locales de ambos servicios, incluida la ruta TCP real; no demuestra conectividad LAN/VPN ni ausencia de toda fuga bajo cargas ilimitadas. La tolerancia de RSS permite memoria retenida por el asignador y no exige retornar byte por byte a la línea base.

## Módulos o componentes afectados

- `network/server`: sockets de escucha y clientes, cierre de conexiones y proceso.
- `network/client`: CLI remoto real ejercitado bajo carga.
- `scheduler`: workers, procesos hijos y descriptores.
- `process`: creación y recolección de procesos.
- `storage`: integridad y limpieza de temporales.
- `verif/scripts/TC-024.sh`: carga y medición por servicio, con limpieza acotada.

## Restricciones tecnológicas o de arquitectura

La inspección depende de Linux/WSL y `/proc`. El script requiere Bash, Python 3 y ss, ya usados por la batería de red; no requiere Perl/JSON::PP. Se toman cinco muestras consecutivas estables de descriptores/sockets sin hijos de trabajos, con plazo de 15 s para regresar a reposo. No se modifica producción para alcanzar PASS.
