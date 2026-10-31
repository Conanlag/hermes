
## Ejecucion: 2026-10-26 17:16:11 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo ==
job ID: 1
PID: 14814
OK: (a) el hijo murió al morir el demonio (PDEATHSIG).
OK: (a) fila INTERRUPTED (motivo=caida, proceso_terminado=true), sin huérfano.
NOTA: (a) no cubre motivo=apagado; el cierre ordenado es Corte 3.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 15116
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
FAIL: (c) la fila fabricada no quedó INTERRUPTED.
OK: (c) el proceso ajeno 15519 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
malformed UTF-8 character in JSON string, at character offset 256 (before "\x{ed}da del schedul...") at -e line 7.
FAIL: (d) el Job QUEUED no terminó SUCCEEDED (estado: '').

== (e) estados terminales intactos y estado desconocido fail-closed ==
malformed UTF-8 character in JSON string, at character offset 256 (before "\x{ed}da del schedul...") at -e line 7.
malformed UTF-8 character in JSON string, at character offset 256 (before "\x{ed}da del schedul...") at -e line 7.
malformed UTF-8 character in JSON string, at character offset 256 (before "\x{ed}da del schedul...") at -e line 7.
malformed UTF-8 character in JSON string, at character offset 256 (before "\x{ed}da del schedul...") at -e line 7.
malformed UTF-8 character in JSON string, at character offset 256 (before "\x{ed}da del schedul...") at -e line 7.
FAIL: (e) Job 5 alterado: estado='', codigo='', mensaje='', terminacion=''.
FAIL: (e) Job 6 alterado: estado='', codigo='', mensaje='', terminacion=''.
FAIL: (e) Job 7 alterado: estado='', codigo='', mensaje='', terminacion=''.
FAIL: (e) Job 8 alterado: estado='', codigo='', mensaje='', terminacion=''.
FAIL: (e) el estado desconocido no se reclasificó INTERRUPTED.
FAIL: (e) el filtro no rechazó ESTADO_INEXISTENTE como se esperaba (rc=1).
FAIL: (e) el filtro INTERRUPTED no listó ninguna fila.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== Auditoría F1: los Jobs no heredan los locks del demonio ==
FAIL: (F1) no se pudo crear el Job para auditar descriptores.

FAIL: TC-022 detectó 10 problema(s).
```

## Ejecucion: 2026-10-26 17:18:11 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo ==
job ID: 1
PID: 17639
OK: (a) el hijo murió al morir el demonio (PDEATHSIG).
OK: (a) fila INTERRUPTED (motivo=caida, proceso_terminado=true), sin huérfano.
NOTA: (a) no cubre motivo=apagado; el cierre ordenado es Corte 3.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 17939
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
OK: (c) el proceso ajeno 18342 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).

== (e) estados terminales intactos y estado desconocido fail-closed ==
OK: (e) Job 5 terminal intacto (SUCCEEDED).
OK: (e) Job 6 terminal intacto (FAILED).
OK: (e) Job 7 terminal intacto (CANCELED).
OK: (e) Job 8 terminal intacto (INTERRUPTED).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED.
OK: (e) el filtro acepta INTERRUPTED y lista las filas recuperadas.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
OK: (F1) el Job 18810 no heredó scheduler.lock, jobs.lock ni archivos de datos.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=18810).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

PASS: TC-022 cubrió (a) sin huérfanos, (b) sin RUNNING tras SIGKILL, (c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos y estado desconocido fail-closed; además, los Jobs no heredan locks.
```

## Ejecucion: 2026-10-26 17:26:13 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo ==
job ID: 1
PID: 21550
OK: (a) el hijo murió al morir el demonio (PDEATHSIG).
OK: (a) fila INTERRUPTED (motivo=caida, proceso_terminado=true), sin huérfano.
NOTA: (a) no cubre motivo=apagado; el cierre ordenado es Corte 3.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 21850
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
OK: (c) el proceso ajeno 22253 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).

== (e) estados terminales intactos y estado desconocido fail-closed ==
OK: (e) Job 5 terminal intacto (SUCCEEDED).
OK: (e) Job 6 terminal intacto (FAILED).
OK: (e) Job 7 terminal intacto (CANCELED).
OK: (e) Job 8 terminal intacto (INTERRUPTED).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED.
OK: (e) el filtro acepta INTERRUPTED y lista las filas recuperadas.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
OK: (F1) el Job 22725 no heredó scheduler.lock, jobs.lock ni archivos de datos.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=22725).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

PASS: TC-022 cubrió (a) sin huérfanos, (b) sin RUNNING tras SIGKILL, (c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos y estado desconocido fail-closed; además, los Jobs no heredan locks.
```

## Ejecucion: 2026-10-26 18:06:40 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo ==
job ID: 1
PID: 24186
OK: (a) el hijo murió al morir el demonio (PDEATHSIG).
OK: (a) fila INTERRUPTED (motivo=caida, proceso_terminado=true), sin huérfano.
NOTA: (a) no cubre motivo=apagado; el cierre ordenado es Corte 3.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 24456
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
OK: (c) el proceso ajeno 24819 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).

== (e) estados terminales intactos y estado desconocido fail-closed ==
OK: (e) Job 5 terminal intacto (SUCCEEDED).
OK: (e) Job 6 terminal intacto (FAILED).
OK: (e) Job 7 terminal intacto (CANCELED).
OK: (e) Job 8 terminal intacto (INTERRUPTED).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED.
OK: (e) el filtro acepta INTERRUPTED y lista las filas recuperadas.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== (h) nietos que sobreviven a PDEATHSIG: el grupo sin líder se termina ==
job ID: 10
PID: 25425
OK: (h) el líder y su nieto comparten grupo y sesión privada (sid=25419).
OK: (h) el líder murió y el nieto 25426 sobrevivió (hueco reproducido).
OK: (h) no queda ningún miembro vivo del grupo (proceso_terminado real).

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
OK: (F1) el Job 25712 no heredó scheduler.lock, jobs.lock ni archivos de datos.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=25712).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

PASS: TC-022 cubrió (a) sin huérfanos, (b) sin RUNNING tras SIGKILL, (c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos y estado desconocido fail-closed, (h) grupo sin líder terminado por sid; además, los Jobs no heredan locks.
```

## Ejecucion: 2026-10-26 18:11:43 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo ==
job ID: 1
PID: 27222
OK: (a) el hijo murió al morir el demonio (PDEATHSIG).
OK: (a) fila INTERRUPTED (motivo=caida, proceso_terminado=true), sin huérfano.
NOTA: (a) no cubre motivo=apagado; el cierre ordenado es Corte 3.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 27506
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
OK: (c) el proceso ajeno 27885 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).

== (e) estados terminales intactos y estado desconocido fail-closed ==
OK: (e) Job 5 terminal intacto (SUCCEEDED).
OK: (e) Job 6 terminal intacto (FAILED).
OK: (e) Job 7 terminal intacto (CANCELED).
OK: (e) Job 8 terminal intacto (INTERRUPTED).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED.
OK: (e) el filtro acepta INTERRUPTED y lista las filas recuperadas.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== (h) nietos que sobreviven a PDEATHSIG: el grupo sin líder se termina ==
job ID: 10
PID: 28512
OK: (h) el líder y su nieto comparten grupo y sesión privada (sid=28506).
OK: (h) el líder murió y el nieto 28513 sobrevivió (hueco reproducido).
OK: (h) no queda ningún miembro vivo del grupo (proceso_terminado real).

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
  descriptor heredado: /proc/28811/fd/5 -> /tmp/tmp.a0xewqkiqn/home/.local/share/hermes/data/jobs.json (deleted)
FAIL: (F1) el Job heredó 1 descriptor(es) del demonio.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=28811).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

FAIL: TC-022 detectó 1 problema(s).
```

## Ejecucion: 2026-10-26 18:12:07 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo ==
job ID: 1
PID: 29133
OK: (a) el hijo murió al morir el demonio (PDEATHSIG).
OK: (a) fila INTERRUPTED (motivo=caida, proceso_terminado=true), sin huérfano.
NOTA: (a) no cubre motivo=apagado; el cierre ordenado es Corte 3.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 29415
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
OK: (c) el proceso ajeno 29794 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).

== (e) estados terminales intactos y estado desconocido fail-closed ==
OK: (e) Job 5 terminal intacto (SUCCEEDED).
OK: (e) Job 6 terminal intacto (FAILED).
OK: (e) Job 7 terminal intacto (CANCELED).
OK: (e) Job 8 terminal intacto (INTERRUPTED).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED.
OK: (e) el filtro acepta INTERRUPTED y lista las filas recuperadas.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== (h) nietos que sobreviven a PDEATHSIG: el grupo sin líder se termina ==
job ID: 10
PID: 30421
OK: (h) el líder y su nieto comparten grupo y sesión privada (sid=30415).
OK: (h) el líder murió y el nieto 30422 sobrevivió (hueco reproducido).
OK: (h) no queda ningún miembro vivo del grupo (proceso_terminado real).

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
  descriptor heredado: /proc/30722/fd/8 -> /tmp/tmp.BhloOwdCwR/home/.local/share/hermes/data/jobs.json (deleted)
FAIL: (F1) el Job heredó 1 descriptor(es) del demonio.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=30722).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

FAIL: TC-022 detectó 1 problema(s).
```

## Ejecucion: 2026-10-26 18:13:57 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo ==
job ID: 1
PID: 31102
OK: (a) el hijo murió al morir el demonio (PDEATHSIG).
OK: (a) fila INTERRUPTED (motivo=caida, proceso_terminado=true), sin huérfano.
NOTA: (a) no cubre motivo=apagado; el cierre ordenado es Corte 3.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 31384
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
OK: (c) el proceso ajeno 31763 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).

== (e) estados terminales intactos y estado desconocido fail-closed ==
OK: (e) Job 5 terminal intacto (SUCCEEDED).
OK: (e) Job 6 terminal intacto (FAILED).
OK: (e) Job 7 terminal intacto (CANCELED).
OK: (e) Job 8 terminal intacto (INTERRUPTED).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED.
OK: (e) el filtro acepta INTERRUPTED y lista las filas recuperadas.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== (h) nietos que sobreviven a PDEATHSIG: el grupo sin líder se termina ==
job ID: 10
PID: 32390
OK: (h) el líder y su nieto comparten grupo y sesión privada (sid=32384).
OK: (h) el líder murió y el nieto 32391 sobrevivió (hueco reproducido).
OK: (h) no queda ningún miembro vivo del grupo (proceso_terminado real).

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
OK: (F1) el Job 32687 no heredó scheduler.lock, jobs.lock ni archivos de datos.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=32687).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

PASS: TC-022 cubrió (a) sin huérfanos, (b) sin RUNNING tras SIGKILL, (c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos y estado desconocido fail-closed, (h) grupo sin líder terminado por sid; además, los Jobs no heredan locks.
```

## Ejecucion: 2026-10-26 18:14:05 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo ==
job ID: 1
PID: 32988
OK: (a) el hijo murió al morir el demonio (PDEATHSIG).
OK: (a) fila INTERRUPTED (motivo=caida, proceso_terminado=true), sin huérfano.
NOTA: (a) no cubre motivo=apagado; el cierre ordenado es Corte 3.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 33270
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
OK: (c) el proceso ajeno 33649 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).

== (e) estados terminales intactos y estado desconocido fail-closed ==
OK: (e) Job 5 terminal intacto (SUCCEEDED).
OK: (e) Job 6 terminal intacto (FAILED).
OK: (e) Job 7 terminal intacto (CANCELED).
OK: (e) Job 8 terminal intacto (INTERRUPTED).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED.
OK: (e) el filtro acepta INTERRUPTED y lista las filas recuperadas.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== (h) nietos que sobreviven a PDEATHSIG: el grupo sin líder se termina ==
job ID: 10
PID: 34276
OK: (h) el líder y su nieto comparten grupo y sesión privada (sid=34270).
OK: (h) el líder murió y el nieto 34277 sobrevivió (hueco reproducido).
OK: (h) no queda ningún miembro vivo del grupo (proceso_terminado real).

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
OK: (F1) el Job 34573 no heredó scheduler.lock, jobs.lock ni archivos de datos.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=34573).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

PASS: TC-022 cubrió (a) sin huérfanos, (b) sin RUNNING tras SIGKILL, (c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos y estado desconocido fail-closed, (h) grupo sin líder terminado por sid; además, los Jobs no heredan locks.
```

## Ejecucion: 2026-10-26 18:26:21 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo ==
job ID: 1
PID: 36173
OK: (a) el hijo murió al morir el demonio (PDEATHSIG).
OK: (a) fila INTERRUPTED (motivo=caida, proceso_terminado=true), sin huérfano.
NOTA: (a) no cubre motivo=apagado; el cierre ordenado es Corte 3.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 36426
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
OK: (c) el proceso ajeno 36765 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).

== (e) estados terminales intactos y estado desconocido fail-closed ==
OK: (e) Job 5 terminal intacto (SUCCEEDED).
OK: (e) Job 6 terminal intacto (FAILED).
OK: (e) Job 7 terminal intacto (CANCELED).
OK: (e) Job 8 terminal intacto (INTERRUPTED).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED.
OK: (e) el filtro acepta INTERRUPTED y lista las filas recuperadas.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== (h) nietos que sobreviven a PDEATHSIG: el grupo sin líder se termina ==
job ID: 10
PID: 37332
OK: (h) el líder y su nieto comparten grupo y sesión privada (sid=37326).
OK: (h) el líder murió y el nieto 37333 sobrevivió (hueco reproducido).
OK: (h) no queda ningún miembro vivo del grupo (proceso_terminado real).

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
OK: (F1) el Job 37599 no heredó scheduler.lock, jobs.lock ni archivos de datos.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=37599).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

PASS: TC-022 cubrió (a) sin huérfanos, (b) sin RUNNING tras SIGKILL, (c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos y estado desconocido fail-closed, (h) grupo sin líder terminado por sid; además, los Jobs no heredan locks.
```

## Ejecucion: 2026-10-26 18:36:00 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo ==
job ID: 1
PID: 38009
OK: (a) el hijo murió al morir el demonio (PDEATHSIG).
OK: (a) fila INTERRUPTED (motivo=caida, proceso_terminado=true), sin huérfano.
NOTA: (a) no cubre motivo=apagado; el cierre ordenado es Corte 3.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 38309
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
OK: (c) el proceso ajeno 38712 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).

== (e) estados terminales intactos y estado desconocido fail-closed ==
OK: (e) Job 5 terminal intacto (SUCCEEDED).
OK: (e) Job 6 terminal intacto (FAILED).
OK: (e) Job 7 terminal intacto (CANCELED).
OK: (e) Job 8 terminal intacto (INTERRUPTED).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED.
OK: (e) el filtro acepta INTERRUPTED y lista las filas recuperadas.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== (f) SIGKILL en plena ráfaga de escrituras: jobs.json parsea y no quedan temporales ==
OK: (f) jobs.json parsea como arreglo tras el SIGKILL en escrituras.
OK: (f) jobs.json.bak existe y parsea como arreglo.
OK: (f) el arranque eliminó el jobs.json.tmp.* huérfano.
OK: (f) jobs.json sigue parseando después de la recuperación.

== (i) fila RUNNING con pid=0: motivo=sin_pid ==
OK: (i) sin_pid queda INTERRUPTED sin afirmar una terminación que no ocurrió.

== (h) nietos que sobreviven a PDEATHSIG: el grupo sin líder se termina ==
job ID: 51
PID: 40357
OK: (h) el líder y su nieto comparten grupo y sesión privada (sid=40351).
OK: (h) el líder murió y el nieto 40358 sobrevivió (hueco reproducido).
OK: (h) no queda ningún miembro vivo del grupo (proceso_terminado real).

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
OK: (F1) el Job 40688 no heredó scheduler.lock, jobs.lock ni archivos de datos.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=40688).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

PASS: TC-022 cubrió (a) sin huérfanos, (b) sin RUNNING tras SIGKILL, (c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos y estado desconocido fail-closed, (f) jobs.json y .bak parsean y los .tmp se limpian tras SIGKILL en escrituras, (h) grupo sin líder terminado por sid, (i) sin_pid sin afirmar terminación; además, los Jobs no heredan locks.
```

## Ejecucion: 2026-10-26 18:40:42 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo ==
job ID: 1
PID: 42382
OK: (a) el hijo murió al morir el demonio (PDEATHSIG).
OK: (a) fila INTERRUPTED (motivo=caida, proceso_terminado=true), sin huérfano.
NOTA: (a) no cubre motivo=apagado; el cierre ordenado es Corte 3.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 42699
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
OK: (c) el proceso ajeno 43118 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).

== (e) estados terminales intactos y estado desconocido fail-closed ==
OK: (e) Job 5 terminal intacto (SUCCEEDED).
OK: (e) Job 6 terminal intacto (FAILED).
OK: (e) Job 7 terminal intacto (CANCELED).
OK: (e) Job 8 terminal intacto (INTERRUPTED).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED.
OK: (e) el filtro acepta INTERRUPTED y lista las filas recuperadas.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== (f) SIGKILL en plena ráfaga de escrituras: jobs.json parsea y no quedan temporales ==
OK: (f) jobs.json parsea como arreglo tras el SIGKILL en escrituras.
OK: (f) jobs.json.bak existe y parsea como arreglo.
OK: (f) el arranque eliminó el jobs.json.tmp.* huérfano.
OK: (f) jobs.json sigue parseando después de la recuperación.
OK: (f) con jobs.json corrupto se leyó jobs.json.bak y se conservó la fila 5.
OK: (f) jobs.json se reparó desde jobs.json.bak.

== (i) fila RUNNING con pid=0: motivo=sin_pid ==
OK: (i) sin_pid queda INTERRUPTED sin afirmar una terminación que no ocurrió.

== (h) nietos que sobreviven a PDEATHSIG: el grupo sin líder se termina ==
job ID: 51
PID: 45110
OK: (h) el líder y su nieto comparten grupo y sesión privada (sid=45104).
OK: (h) el líder murió y el nieto 45111 sobrevivió (hueco reproducido).
OK: (h) no queda ningún miembro vivo del grupo (proceso_terminado real).

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
OK: (F1) el Job 45461 no heredó scheduler.lock, jobs.lock ni archivos de datos.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=45461).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

PASS: TC-022 cubrió (a) sin huérfanos, (b) sin RUNNING tras SIGKILL, (c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos y estado desconocido fail-closed, (f) jobs.json y .bak parsean y los .tmp se limpian tras SIGKILL en escrituras, (h) grupo sin líder terminado por sid, (i) sin_pid sin afirmar terminación; además, los Jobs no heredan locks.
```

## Ejecucion: 2026-10-26 18:48:44 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo ==
job ID: 1
PID: 47259
OK: (a) el hijo murió al morir el demonio (PDEATHSIG).
OK: (a) fila INTERRUPTED (motivo=caida, proceso_terminado=true), sin huérfano.
NOTA: (a) no cubre motivo=apagado; el cierre ordenado es Corte 3.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 47596
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
OK: (c) el proceso ajeno 48035 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).

== (e) estados terminales intactos y estado desconocido fail-closed ==
OK: (e) Job 5 terminal intacto (SUCCEEDED).
OK: (e) Job 6 terminal intacto (FAILED).
OK: (e) Job 7 terminal intacto (CANCELED).
OK: (e) Job 8 terminal intacto (INTERRUPTED).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED.
OK: (e) el filtro acepta INTERRUPTED y lista las filas recuperadas.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== (f) SIGKILL en plena ráfaga de escrituras: jobs.json parsea y no quedan temporales ==
OK: (f) jobs.json parsea como arreglo tras el SIGKILL en escrituras.
OK: (f) jobs.json.bak existe y parsea como arreglo.
OK: (f) el arranque eliminó el jobs.json.tmp.* huérfano.
OK: (f) jobs.json sigue parseando después de la recuperación.
OK: (f) con jobs.json corrupto se leyó jobs.json.bak y se conservó la fila 5.
OK: (f) jobs.json se reparó desde jobs.json.bak.

== (i) fila RUNNING con pid=0: motivo=sin_pid ==
OK: (i) sin_pid queda INTERRUPTED sin afirmar una terminación que no ocurrió.

== (h) nietos que sobreviven a PDEATHSIG: el grupo sin líder se termina ==
job ID: 51
PID: 50087
OK: (h) el líder y su nieto comparten grupo y sesión privada (sid=50081).
OK: (h) el líder murió y el nieto 50088 sobrevivió (hueco reproducido).
OK: (h) no queda ningún miembro vivo del grupo (proceso_terminado real).

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
OK: (F1) el Job 50438 no heredó scheduler.lock, jobs.lock ni archivos de datos.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=50438).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

PASS: TC-022 cubrió (a) sin huérfanos, (b) sin RUNNING tras SIGKILL, (c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos y estado desconocido fail-closed, (f) jobs.json y .bak parsean y los .tmp se limpian tras SIGKILL en escrituras, (h) grupo sin líder terminado por sid, (i) sin_pid sin afirmar terminación; además, los Jobs no heredan locks.
```

## Ejecucion: 2026-10-26 19:02:36 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo: cierre ordenado ==
job ID: 1
PID: 51433
OK: (a) el coordinador terminó el grupo del hijo.
OK: (a) fila INTERRUPTED (motivo=apagado, proceso_terminado=true), sin huérfano.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 51748
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
OK: (c) el proceso ajeno 52156 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).

== (e) estados terminales intactos y estado desconocido fail-closed ==
OK: (e) Job 5 terminal intacto (SUCCEEDED).
OK: (e) Job 6 terminal intacto (FAILED).
OK: (e) Job 7 terminal intacto (CANCELED).
OK: (e) Job 8 terminal intacto (INTERRUPTED).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED.
OK: (e) el filtro acepta INTERRUPTED y lista las filas recuperadas.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== (f) SIGKILL en plena ráfaga de escrituras: jobs.json parsea y no quedan temporales ==
OK: (f) jobs.json parsea como arreglo tras el SIGKILL en escrituras.
OK: (f) jobs.json.bak existe y parsea como arreglo.
OK: (f) el arranque eliminó el jobs.json.tmp.* huérfano.
OK: (f) jobs.json sigue parseando después de la recuperación.
OK: (f) con jobs.json corrupto se leyó jobs.json.bak y se conservó la fila 5.
OK: (f) jobs.json se reparó desde jobs.json.bak.

== (i) fila RUNNING con pid=0: motivo=sin_pid ==
OK: (i) sin_pid queda INTERRUPTED sin afirmar una terminación que no ocurrió.

== (h) nietos que sobreviven a PDEATHSIG: el grupo sin líder se termina ==
job ID: 51
PID: 54073
OK: (h) el líder y su nieto comparten grupo y sesión privada (sid=54066).
OK: (h) el líder murió y el nieto 54074 sobrevivió (hueco reproducido).
OK: (h) no queda ningún miembro vivo del grupo (proceso_terminado real).

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
OK: (F1) el Job 54401 no heredó scheduler.lock, jobs.lock ni archivos de datos.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=54401).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

== (g) clean data tras una caída: recupera antes de borrar y no arranca daemon ==
job ID: 53
PID: 54723
[34mHistorial de trabajos limpiado correctamente.[0m
OK: (g) clean data recuperó la caída y limpió el historial.
OK: (g) clean data no arrancó el scheduler.

PASS: TC-022 cubrió (a) apagado ordenado con motivo=apagado y sin huérfanos, (b) sin RUNNING tras SIGKILL, (c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos y estado desconocido fail-closed, (f) jobs.json y .bak parsean y los .tmp se limpian tras SIGKILL en escrituras, (g) clean data recupera una caída antes de borrar y no arranca daemon, (h) grupo sin líder terminado por sid, (i) sin_pid sin afirmar terminación; además, los Jobs no heredan locks.
```

## Ejecucion: 2026-10-26 19:51:06 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo: cierre ordenado ==
job ID: 1
PID: 58646
OK: (a) el coordinador terminó el grupo del hijo.
OK: (a) fila INTERRUPTED (motivo=apagado, proceso_terminado=true), sin huérfano.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 58991
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
OK: (c) el proceso ajeno 59439 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).

== (e) estados terminales intactos y estado desconocido fail-closed ==
OK: (e) Job 5 terminal intacto (SUCCEEDED).
OK: (e) Job 6 terminal intacto (FAILED).
OK: (e) Job 7 terminal intacto (CANCELED).
OK: (e) Job 8 terminal intacto (INTERRUPTED).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED.
OK: (e) el filtro acepta INTERRUPTED y lista las filas recuperadas.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== (f) SIGKILL en plena ráfaga de escrituras: jobs.json parsea y no quedan temporales ==
OK: (f) jobs.json parsea como arreglo tras el SIGKILL en escrituras.
OK: (f) jobs.json.bak existe y parsea como arreglo.
OK: (f) el arranque eliminó el jobs.json.tmp.* huérfano.
OK: (f) jobs.json sigue parseando después de la recuperación.
OK: (f) con jobs.json corrupto se leyó jobs.json.bak y se conservó la fila 5.
OK: (f) jobs.json se reparó desde jobs.json.bak.

== (i) fila RUNNING con pid=0: motivo=sin_pid ==
OK: (i) sin_pid queda INTERRUPTED sin afirmar una terminación que no ocurrió.

== (h) nietos que sobreviven a PDEATHSIG: el grupo sin líder se termina ==
job ID: 51
PID: 61538
OK: (h) el líder y su nieto comparten grupo y sesión privada (sid=61531).
OK: (h) el líder murió y el nieto 61539 sobrevivió (hueco reproducido).
OK: (h) no queda ningún miembro vivo del grupo (proceso_terminado real).

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
OK: (F1) el Job 61896 no heredó scheduler.lock, jobs.lock ni archivos de datos.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=61896).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

== (g) clean data tras una caída: recupera antes de borrar y no arranca daemon ==
job ID: 53
PID: 62248
[34mHistorial de trabajos limpiado correctamente.[0m
OK: (g) clean data recuperó la caída y limpió el historial.
OK: (g) clean data no arrancó el scheduler.

PASS: TC-022 cubrió (a) apagado ordenado con motivo=apagado y sin huérfanos, (b) sin RUNNING tras SIGKILL, (c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos y estado desconocido fail-closed, (f) jobs.json y .bak parsean y los .tmp se limpian tras SIGKILL en escrituras, (g) clean data recupera una caída antes de borrar y no arranca daemon, (h) grupo sin líder terminado por sid, (i) sin_pid sin afirmar terminación; además, los Jobs no heredan locks.
```

## Ejecucion: 2026-10-30 22:45:14 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo: cierre ordenado ==
job ID: 1
PID: 59290
OK: (a) el coordinador terminó el grupo del hijo.
OK: (a) fila INTERRUPTED (motivo=apagado, proceso_terminado=true), sin huérfano.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 61256
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
OK: (c) el proceso ajeno 64425 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).

== (e) estados terminales intactos y estado desconocido fail-closed ==
OK: (e) Job 5 terminal intacto (SUCCEEDED).
OK: (e) Job 6 terminal intacto (FAILED).
OK: (e) Job 7 terminal intacto (CANCELED).
OK: (e) Job 8 terminal intacto (INTERRUPTED).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED.
OK: (e) el filtro acepta INTERRUPTED y lista las filas recuperadas.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== (f) RNF-28: SIGKILL durante escrituras; jobs.json se conserva o recupera ==
OK: (f) jobs.json parsea como arreglo tras el SIGKILL en escrituras.
OK: (f) jobs.json.bak existe y parsea como arreglo.
OK: (f) el arranque eliminó el jobs.json.tmp.* huérfano.
OK: (f) jobs.json sigue parseando después de la recuperación.
OK: (f) con jobs.json corrupto se leyó jobs.json.bak y se conservó la fila 5.
OK: (f) jobs.json se reparó desde jobs.json.bak.

== (i) fila RUNNING con pid=0: motivo=sin_pid ==
OK: (i) sin_pid queda INTERRUPTED sin afirmar una terminación que no ocurrió.

== (h) nietos que sobreviven a PDEATHSIG: el grupo sin líder se termina ==
job ID: 51
PID: 80524
OK: (h) el líder y su nieto comparten grupo y sesión privada (sid=80517).
OK: (h) el líder murió y el nieto 80525 sobrevivió (hueco reproducido).
OK: (h) no queda ningún miembro vivo del grupo (proceso_terminado real).

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
OK: (F1) el Job 83501 no heredó scheduler.lock, jobs.lock ni archivos de datos.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=83501).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

== (g) clean data tras una caída: recupera antes de borrar y no arranca daemon ==
job ID: 53
PID: 86586
[34mHistorial de trabajos limpiado correctamente.[0m
OK: (g) clean data recuperó la caída y limpió el historial.
OK: (g) clean data no arrancó el scheduler.

PASS: TC-022 cubrió (a) apagado ordenado con motivo=apagado y sin huérfanos, (b) sin RUNNING tras SIGKILL, (c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos y estado desconocido fail-closed, (f) jobs.json y .bak parsean y los .tmp se limpian tras SIGKILL en escrituras, (g) clean data recupera una caída antes de borrar y no arranca daemon, (h) grupo sin líder terminado por sid, (i) sin_pid sin afirmar terminación; además, los Jobs no heredan locks.
```

## Ejecucion: 2026-10-30 22:54:58 -0600

```text
== (a) SIGTERM al demonio con un Job sleep activo: cierre ordenado ==
job ID: 1
PID: 92596
OK: (a) el coordinador terminó el grupo del hijo.
OK: (a) fila INTERRUPTED (motivo=apagado, proceso_terminado=true), sin huérfano.

== (b) SIGKILL al demonio con un Job sleep activo ==
job ID: 2
PID: 95858
OK: (b) PDEATHSIG mató al hijo tras SIGKILL.
OK: (b) no sobrevive ninguna fila RUNNING al reinicio.

== (c) fila RUNNING con el PID vivo de un proceso ajeno ==
OK: (c) el proceso ajeno 100194 sigue vivo: no se señaló un PID no verificado.

== (d) QUEUED sigue pendiente y se ejecuta ==
OK: (d) el Job QUEUED se conservó y se ejecutó (marcador creado).

== (e) estados terminales intactos y estado desconocido fail-closed ==
OK: (e) Job 5 terminal intacto (SUCCEEDED).
OK: (e) Job 6 terminal intacto (FAILED).
OK: (e) Job 7 terminal intacto (CANCELED).
OK: (e) Job 8 terminal intacto (INTERRUPTED).
OK: (e) estado desconocido se reclasificó INTERRUPTED (fail-closed).
OK: (e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED.
OK: (e) el filtro acepta INTERRUPTED y lista las filas recuperadas.
OK: (e) la ayuda documenta el estado INTERRUPTED.

== (f) RNF-28: SIGKILL durante escrituras; jobs.json se conserva o recupera ==
OK: (f) jobs.json parsea como arreglo tras el SIGKILL en escrituras.
OK: (f) jobs.json.bak existe y parsea como arreglo.
OK: (f) el arranque eliminó el jobs.json.tmp.* huérfano.
OK: (f) jobs.json sigue parseando después de la recuperación.
OK: (f) con jobs.json corrupto se leyó jobs.json.bak y se conservó la fila 5.
OK: (f) jobs.json se reparó desde jobs.json.bak.

== (i) fila RUNNING con pid=0: motivo=sin_pid ==
OK: (i) sin_pid queda INTERRUPTED sin afirmar una terminación que no ocurrió.

== (h) nietos que sobreviven a PDEATHSIG: el grupo sin líder se termina ==
job ID: 51
PID: 110591
OK: (h) el líder y su nieto comparten grupo y sesión privada (sid=110578).
OK: (h) el líder murió y el nieto 110593 sobrevivió (hueco reproducido).
OK: (h) no queda ningún miembro vivo del grupo (proceso_terminado real).

== Auditoría F1: los Jobs no heredan los locks del demonio ==
OK: (F1) el demonio sí conserva scheduler.lock.
OK: (F1) el Job 111791 no heredó scheduler.lock, jobs.lock ni archivos de datos.
OK: (F1) el Job corre en su propio grupo (pgrp=pid=111791).
OK: (F1) la identidad persistida coincide con /proc (boot_id + starttime).

== (g) clean data tras una caída: recupera antes de borrar y no arranca daemon ==
job ID: 53
PID: 112925
[34mHistorial de trabajos limpiado correctamente.[0m
OK: (g) clean data recuperó la caída y limpió el historial.
OK: (g) clean data no arrancó el scheduler.

PASS: TC-022 cubrió (a) apagado ordenado con motivo=apagado y sin huérfanos, (b) sin RUNNING tras SIGKILL, (c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos y estado desconocido fail-closed, (f) jobs.json y .bak parsean y los .tmp se limpian tras SIGKILL en escrituras, (g) clean data recupera una caída antes de borrar y no arranca daemon, (h) grupo sin líder terminado por sid, (i) sin_pid sin afirmar terminación; además, los Jobs no heredan locks.
```
