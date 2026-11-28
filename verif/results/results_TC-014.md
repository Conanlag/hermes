
## Ejecucion: 2026-11-27 20:39:14 -0600

- Modo: local
- Commit del origen: 009fff4015ed4d9f0feaaf02aef0b2e8aeeea813
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol origen: con cambios locales (no se copian al clon)

```text
Sistema: PRETTY_NAME="Ubuntu 24.04.1 LTS"; VERSION_ID="24.04"; ID=ubuntu
UID real=1000, efectivo=1000
g++: g++ (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0
make: GNU Make 4.3
git: git version 2.43.0
Python: 3.15.2 (solo ejecutor de pruebas)
PASS V1/AC1: Linux/WSL y herramientas documentadas, usuario real/efectivo sin root
Clon A: HEAD=009fff4015ed4d9f0feaaf02aef0b2e8aeeea813, limpio, sin binario; nlohmann/json 3.12.0 incluido
Clon B: HEAD=009fff4015ed4d9f0feaaf02aef0b2e8aeeea813, limpio, sin binario; nlohmann/json 3.12.0 incluido
PASS V2/AC2: dos clones locales independientes del mismo commit; sin copiar cambios ni binarios del origen
Compilacion A: limpia, sin advertencias; SHA256=e5c4bba3ddb60161590be0d58c2aae4ab103442440cff56d789c7d6ed7f6d0c4
Compilacion B: limpia, sin advertencias; SHA256=e5c4bba3ddb60161590be0d58c2aae4ab103442440cff56d789c7d6ed7f6d0c4
  A hermes --version: [34mversion 0.3[0m
  B hermes --version: [34mversion 0.3[0m
SHA256 iguales: True (dato adicional; no se exige identidad binaria entre toolchains)
PASS V3/AC3: ambos clones compilan con make y flags actuales, sin descargas ni root; version coincidente
  A hermes job echo hola-tc014: job ID: 1
PID: 231
  A hermes filter id 1: Job ID: 1
PID: 231
Programa: echo
Estado: SUCCEEDED
Codigo de salida: 0
Recepcion: 2026-11-27 20:40:03
Inicio: 2026-11-27 20:40:03
Terminacion: 2026-11-27 20:40:03
Argumentos: hola-tc014
  A hermes --help: HERMES - Gestor de trabajos en cola

Uso: hermes <comando> [argumentos..]

Comandos:
  job [--request-id <id>] <programa> [argumentos..]
                                 Crea un trabajo; el ID de solicitud evita duplicados
  filter id <numero>             Muestra un trabajo por su ID
  filter status <ESTADO>         Lista trabajos por estado
  filter programa <nombre>       Lista trabajos por programa
  cancel <id>                    Cancela un trabajo en cola o en ejecucion
  clean data                     Limpia el historial de trabajos finalizados
  clean scheduler                Detiene el scheduler ordenadamente
  configmax <N>                  Configura el máximo de trabajos simultáneos (1-64)
  configmax --cola <M>           Configura los cupos de espera en cola (0-256)
  configmax <N> --cola <M>       Configura ambos valores en una sola operación
  red setup                      Asistente para registrar un equipo y configurar LAN/WSL
  red start                      Inicia escucha TCP en primer plano; Ctrl+C detiene
  red job <host> [--request-id <id>] <programa> [args...]
                                 Envía un trabajo al servidor por TCP LAN/VPN
  red filter <host> <id|status|programa> <valor>
                                 Aplica los mismos filtros que en modo local
  red cancel <host> <id>         Solicita cancelar un trabajo remoto propio
  health [--json]                Resume scheduler, red (direccion/puerto), trabajos y errores
  logs                           Sigue eventos nuevos hasta Ctrl+C
  --version                      Muestra la version
  --help                         Muestra esta ayuda

Estados: QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED, INTERRUPTED

Ejemplos:
  hermes job sleep 30
  hermes job --request-id pago-42 sleep 30
  hermes filter id 1
  hermes filter status RUNNING
  hermes cancel 1
  hermes clean data
  hermes clean scheduler
  hermes configmax 3
  hermes configmax 5 --cola 2
  hermes logs
  hermes health
  hermes health --json

Codigos de salida: 0 exito, 1 error
  A hermes health --json: {
  "advertencias": [],
  "completo": true,
  "consultado_en": "2026-11-27 20:40:03",
  "errores_recientes": [],
  "limite_errores": 10,
  "lineas_invalidas": 0,
  "red": {
    "activo": false,
    "configurado": {
      "interfaz": "127.0.0.1",
      "puerto": 45820
    },
    "interfaz": null,
    "puerto": null
  },
  "servicio": {
    "activo": true,
    "nombre": "scheduler"
  },
  "trabajos": {
    "en_cola": 0,
    "en_ejecucion": 0
  }
}
  B hermes job echo hola-tc014: job ID: 1
PID: 243
  B hermes filter id 1: Job ID: 1
PID: 243
Programa: echo
Estado: SUCCEEDED
Codigo de salida: 0
Recepcion: 2026-11-27 20:40:03
Inicio: 2026-11-27 20:40:03
Terminacion: 2026-11-27 20:40:03
Argumentos: hola-tc014
  B hermes --help: HERMES - Gestor de trabajos en cola

Uso: hermes <comando> [argumentos..]

Comandos:
  job [--request-id <id>] <programa> [argumentos..]
                                 Crea un trabajo; el ID de solicitud evita duplicados
  filter id <numero>             Muestra un trabajo por su ID
  filter status <ESTADO>         Lista trabajos por estado
  filter programa <nombre>       Lista trabajos por programa
  cancel <id>                    Cancela un trabajo en cola o en ejecucion
  clean data                     Limpia el historial de trabajos finalizados
  clean scheduler                Detiene el scheduler ordenadamente
  configmax <N>                  Configura el máximo de trabajos simultáneos (1-64)
  configmax --cola <M>           Configura los cupos de espera en cola (0-256)
  configmax <N> --cola <M>       Configura ambos valores en una sola operación
  red setup                      Asistente para registrar un equipo y configurar LAN/WSL
  red start                      Inicia escucha TCP en primer plano; Ctrl+C detiene
  red job <host> [--request-id <id>] <programa> [args...]
                                 Envía un trabajo al servidor por TCP LAN/VPN
  red filter <host> <id|status|programa> <valor>
                                 Aplica los mismos filtros que en modo local
  red cancel <host> <id>         Solicita cancelar un trabajo remoto propio
  health [--json]                Resume scheduler, red (direccion/puerto), trabajos y errores
  logs                           Sigue eventos nuevos hasta Ctrl+C
  --version                      Muestra la version
  --help                         Muestra esta ayuda

Estados: QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED, INTERRUPTED

Ejemplos:
  hermes job sleep 30
  hermes job --request-id pago-42 sleep 30
  hermes filter id 1
  hermes filter status RUNNING
  hermes cancel 1
  hermes clean data
  hermes clean scheduler
  hermes configmax 3
  hermes configmax 5 --cola 2
  hermes logs
  hermes health
  hermes health --json

Codigos de salida: 0 exito, 1 error
  B hermes health --json: {
  "advertencias": [],
  "completo": true,
  "consultado_en": "2026-11-27 20:40:03",
  "errores_recientes": [],
  "limite_errores": 10,
  "lineas_invalidas": 0,
  "red": {
    "activo": false,
    "configurado": {
      "interfaz": "127.0.0.1",
      "puerto": 45820
    },
    "interfaz": null,
    "puerto": null
  },
  "servicio": {
    "activo": true,
    "nombre": "scheduler"
  },
  "trabajos": {
    "en_cola": 0,
    "en_ejecucion": 0
  }
}
PASS V4/AC4: humo --version/--help/job/filter/health en ambos binarios y schedulers bajo UID del usuario
  instalado hermes --version: [34mversion 0.3[0m
  instalado hermes job sleep 120: job ID: 2
PID: 255
  instalado hermes cancel 2: [34mCancelación solicitada para el Job: 2[0m
PASS V5/AC5: make install en HOME temporal; binario igual, sin setuid/setgid; Job real ejecutado y cancelado sin root
ENTORNO: [Errno 1] Operation not permitted
  A hermes clean scheduler: [34mScheduler detenido correctamente.[0m
  B hermes clean scheduler: [34mScheduler detenido correctamente.[0m
Resultado: 2

Codigo de salida TC-014: 2
```

## Ejecucion: 2026-11-27 20:40:40 -0600

- Modo: local
- Commit del origen: 009fff4015ed4d9f0feaaf02aef0b2e8aeeea813
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol origen: con cambios locales (no se copian al clon)

```text
Sistema: PRETTY_NAME="Ubuntu 24.04.1 LTS"; VERSION_ID="24.04"; ID=ubuntu
UID real=1000, efectivo=1000
g++: g++ (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0
make: GNU Make 4.3
git: git version 2.43.0
Python: 3.15.2 (solo ejecutor de pruebas)
PASS V1/AC1: Linux/WSL y herramientas documentadas, usuario real/efectivo sin root
Clon A: HEAD=009fff4015ed4d9f0feaaf02aef0b2e8aeeea813, limpio, sin binario; nlohmann/json 3.12.0 incluido
Clon B: HEAD=009fff4015ed4d9f0feaaf02aef0b2e8aeeea813, limpio, sin binario; nlohmann/json 3.12.0 incluido
PASS V2/AC2: dos clones locales independientes del mismo commit; sin copiar cambios ni binarios del origen
Compilacion B: limpia, sin advertencias; SHA256=e5c4bba3ddb60161590be0d58c2aae4ab103442440cff56d789c7d6ed7f6d0c4
Compilacion A: limpia, sin advertencias; SHA256=e5c4bba3ddb60161590be0d58c2aae4ab103442440cff56d789c7d6ed7f6d0c4
  A hermes --version: [34mversion 0.3[0m
  B hermes --version: [34mversion 0.3[0m
SHA256 iguales: True (dato adicional; no se exige identidad binaria entre toolchains)
PASS V3/AC3: ambos clones compilan con make y flags actuales, sin descargas ni root; version coincidente
  A hermes job echo hola-tc014: job ID: 1
PID: 13188
  A hermes filter id 1: Job ID: 1
PID: 13188
Programa: echo
Estado: SUCCEEDED
Codigo de salida: 0
Recepcion: 2026-11-27 20:41:29
Inicio: 2026-11-27 20:41:29
Terminacion: 2026-11-27 20:41:29
Argumentos: hola-tc014
  A hermes --help: HERMES - Gestor de trabajos en cola

Uso: hermes <comando> [argumentos..]

Comandos:
  job [--request-id <id>] <programa> [argumentos..]
                                 Crea un trabajo; el ID de solicitud evita duplicados
  filter id <numero>             Muestra un trabajo por su ID
  filter status <ESTADO>         Lista trabajos por estado
  filter programa <nombre>       Lista trabajos por programa
  cancel <id>                    Cancela un trabajo en cola o en ejecucion
  clean data                     Limpia el historial de trabajos finalizados
  clean scheduler                Detiene el scheduler ordenadamente
  configmax <N>                  Configura el máximo de trabajos simultáneos (1-64)
  configmax --cola <M>           Configura los cupos de espera en cola (0-256)
  configmax <N> --cola <M>       Configura ambos valores en una sola operación
  red setup                      Asistente para registrar un equipo y configurar LAN/WSL
  red start                      Inicia escucha TCP en primer plano; Ctrl+C detiene
  red job <host> [--request-id <id>] <programa> [args...]
                                 Envía un trabajo al servidor por TCP LAN/VPN
  red filter <host> <id|status|programa> <valor>
                                 Aplica los mismos filtros que en modo local
  red cancel <host> <id>         Solicita cancelar un trabajo remoto propio
  health [--json]                Resume scheduler, red (direccion/puerto), trabajos y errores
  logs                           Sigue eventos nuevos hasta Ctrl+C
  --version                      Muestra la version
  --help                         Muestra esta ayuda

Estados: QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED, INTERRUPTED

Ejemplos:
  hermes job sleep 30
  hermes job --request-id pago-42 sleep 30
  hermes filter id 1
  hermes filter status RUNNING
  hermes cancel 1
  hermes clean data
  hermes clean scheduler
  hermes configmax 3
  hermes configmax 5 --cola 2
  hermes logs
  hermes health
  hermes health --json

Codigos de salida: 0 exito, 1 error
  A hermes health --json: {
  "advertencias": [],
  "completo": true,
  "consultado_en": "2026-11-27 20:41:29",
  "errores_recientes": [],
  "limite_errores": 10,
  "lineas_invalidas": 0,
  "red": {
    "activo": false,
    "configurado": {
      "interfaz": "127.0.0.1",
      "puerto": 45820
    },
    "interfaz": null,
    "puerto": null
  },
  "servicio": {
    "activo": true,
    "nombre": "scheduler"
  },
  "trabajos": {
    "en_cola": 0,
    "en_ejecucion": 0
  }
}
  B hermes job echo hola-tc014: job ID: 1
PID: 13200
  B hermes filter id 1: Job ID: 1
PID: 13200
Programa: echo
Estado: SUCCEEDED
Codigo de salida: 0
Recepcion: 2026-11-27 20:41:29
Inicio: 2026-11-27 20:41:29
Terminacion: 2026-11-27 20:41:29
Argumentos: hola-tc014
  B hermes --help: HERMES - Gestor de trabajos en cola

Uso: hermes <comando> [argumentos..]

Comandos:
  job [--request-id <id>] <programa> [argumentos..]
                                 Crea un trabajo; el ID de solicitud evita duplicados
  filter id <numero>             Muestra un trabajo por su ID
  filter status <ESTADO>         Lista trabajos por estado
  filter programa <nombre>       Lista trabajos por programa
  cancel <id>                    Cancela un trabajo en cola o en ejecucion
  clean data                     Limpia el historial de trabajos finalizados
  clean scheduler                Detiene el scheduler ordenadamente
  configmax <N>                  Configura el máximo de trabajos simultáneos (1-64)
  configmax --cola <M>           Configura los cupos de espera en cola (0-256)
  configmax <N> --cola <M>       Configura ambos valores en una sola operación
  red setup                      Asistente para registrar un equipo y configurar LAN/WSL
  red start                      Inicia escucha TCP en primer plano; Ctrl+C detiene
  red job <host> [--request-id <id>] <programa> [args...]
                                 Envía un trabajo al servidor por TCP LAN/VPN
  red filter <host> <id|status|programa> <valor>
                                 Aplica los mismos filtros que en modo local
  red cancel <host> <id>         Solicita cancelar un trabajo remoto propio
  health [--json]                Resume scheduler, red (direccion/puerto), trabajos y errores
  logs                           Sigue eventos nuevos hasta Ctrl+C
  --version                      Muestra la version
  --help                         Muestra esta ayuda

Estados: QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED, INTERRUPTED

Ejemplos:
  hermes job sleep 30
  hermes job --request-id pago-42 sleep 30
  hermes filter id 1
  hermes filter status RUNNING
  hermes cancel 1
  hermes clean data
  hermes clean scheduler
  hermes configmax 3
  hermes configmax 5 --cola 2
  hermes logs
  hermes health
  hermes health --json

Codigos de salida: 0 exito, 1 error
  B hermes health --json: {
  "advertencias": [],
  "completo": true,
  "consultado_en": "2026-11-27 20:41:29",
  "errores_recientes": [],
  "limite_errores": 10,
  "lineas_invalidas": 0,
  "red": {
    "activo": false,
    "configurado": {
      "interfaz": "127.0.0.1",
      "puerto": 45820
    },
    "interfaz": null,
    "puerto": null
  },
  "servicio": {
    "activo": true,
    "nombre": "scheduler"
  },
  "trabajos": {
    "en_cola": 0,
    "en_ejecucion": 0
  }
}
PASS V4/AC4: humo --version/--help/job/filter/health en ambos binarios y schedulers bajo UID del usuario
  instalado hermes --version: [34mversion 0.3[0m
  instalado hermes job sleep 120: job ID: 2
PID: 13212
  instalado hermes cancel 2: [34mCancelación solicitada para el Job: 2[0m
PASS V5/AC5: make install en HOME temporal; binario igual, sin setuid/setgid; Job real ejecutado y cancelado sin root
  instalado hermes red job 127.0.0.1 true: job ID: 3
PID: pendiente (en cola)
PASS V6/AC6: binario instalado atiende TCP 127.0.0.1:39145 y ejecuta Job remoto sin privilegios
PASS V7/AC7: uninstall retira solo instalacion temporal; datos y src/ del origen conservados
  A hermes clean scheduler: [34mScheduler detenido correctamente.[0m
  B hermes clean scheduler: [34mScheduler detenido correctamente.[0m
PASS V8/AC8: servidor recogido, schedulers detenidos y puerto libre; sin procesos propios; clones/HOME eliminados al salir
PASS: RNF-01 RNF-02 RNF-03 TC-014 sin fallos.
Resultado: 0

Codigo de salida TC-014: 0
```

## Ejecucion: 2026-11-27 20:42:56 -0600

- Modo: local
- Commit del origen: 009fff4015ed4d9f0feaaf02aef0b2e8aeeea813
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Arbol origen: con cambios locales (no se copian al clon)

```text
Sistema: PRETTY_NAME="Ubuntu 24.04.1 LTS"; VERSION_ID="24.04"; ID=ubuntu
UID real=1000, efectivo=1000
g++: g++ (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0
make: GNU Make 4.3
git: git version 2.43.0
Python: 3.15.2 (solo ejecutor de pruebas)
PASS V1/AC1: Linux/WSL y herramientas documentadas, usuario real/efectivo sin root
Clon A: HEAD=009fff4015ed4d9f0feaaf02aef0b2e8aeeea813, limpio, sin binario; nlohmann/json 3.12.0 incluido
Clon B: HEAD=009fff4015ed4d9f0feaaf02aef0b2e8aeeea813, limpio, sin binario; nlohmann/json 3.12.0 incluido
PASS V2/AC2: dos clones locales independientes del mismo commit; sin copiar cambios ni binarios del origen
Compilacion B: limpia, sin advertencias; SHA256=e5c4bba3ddb60161590be0d58c2aae4ab103442440cff56d789c7d6ed7f6d0c4
Compilacion A: limpia, sin advertencias; SHA256=e5c4bba3ddb60161590be0d58c2aae4ab103442440cff56d789c7d6ed7f6d0c4
  A hermes --version: [34mversion 0.3[0m
  B hermes --version: [34mversion 0.3[0m
SHA256 iguales: True (dato adicional; no se exige identidad binaria entre toolchains)
PASS V3/AC3: ambos clones compilan con make y flags actuales, sin descargas ni root; version coincidente
  A hermes job echo hola-tc014: job ID: 1
PID: 13693
  A hermes filter id 1: Job ID: 1
PID: 13693
Programa: echo
Estado: SUCCEEDED
Codigo de salida: 0
Recepcion: 2026-11-27 20:43:44
Inicio: 2026-11-27 20:43:44
Terminacion: 2026-11-27 20:43:44
Argumentos: hola-tc014
  A hermes --help: HERMES - Gestor de trabajos en cola

Uso: hermes <comando> [argumentos..]

Comandos:
  job [--request-id <id>] <programa> [argumentos..]
                                 Crea un trabajo; el ID de solicitud evita duplicados
  filter id <numero>             Muestra un trabajo por su ID
  filter status <ESTADO>         Lista trabajos por estado
  filter programa <nombre>       Lista trabajos por programa
  cancel <id>                    Cancela un trabajo en cola o en ejecucion
  clean data                     Limpia el historial de trabajos finalizados
  clean scheduler                Detiene el scheduler ordenadamente
  configmax <N>                  Configura el máximo de trabajos simultáneos (1-64)
  configmax --cola <M>           Configura los cupos de espera en cola (0-256)
  configmax <N> --cola <M>       Configura ambos valores en una sola operación
  red setup                      Asistente para registrar un equipo y configurar LAN/WSL
  red start                      Inicia escucha TCP en primer plano; Ctrl+C detiene
  red job <host> [--request-id <id>] <programa> [args...]
                                 Envía un trabajo al servidor por TCP LAN/VPN
  red filter <host> <id|status|programa> <valor>
                                 Aplica los mismos filtros que en modo local
  red cancel <host> <id>         Solicita cancelar un trabajo remoto propio
  health [--json]                Resume scheduler, red (direccion/puerto), trabajos y errores
  logs                           Sigue eventos nuevos hasta Ctrl+C
  --version                      Muestra la version
  --help                         Muestra esta ayuda

Estados: QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED, INTERRUPTED

Ejemplos:
  hermes job sleep 30
  hermes job --request-id pago-42 sleep 30
  hermes filter id 1
  hermes filter status RUNNING
  hermes cancel 1
  hermes clean data
  hermes clean scheduler
  hermes configmax 3
  hermes configmax 5 --cola 2
  hermes logs
  hermes health
  hermes health --json

Codigos de salida: 0 exito, 1 error
  A hermes health --json: {
  "advertencias": [],
  "completo": true,
  "consultado_en": "2026-11-27 20:43:44",
  "errores_recientes": [],
  "limite_errores": 10,
  "lineas_invalidas": 0,
  "red": {
    "activo": false,
    "configurado": {
      "interfaz": "127.0.0.1",
      "puerto": 45820
    },
    "interfaz": null,
    "puerto": null
  },
  "servicio": {
    "activo": true,
    "nombre": "scheduler"
  },
  "trabajos": {
    "en_cola": 0,
    "en_ejecucion": 0
  }
}
  B hermes job echo hola-tc014: job ID: 1
PID: 13705
  B hermes filter id 1: Job ID: 1
PID: 13705
Programa: echo
Estado: SUCCEEDED
Codigo de salida: 0
Recepcion: 2026-11-27 20:43:44
Inicio: 2026-11-27 20:43:44
Terminacion: 2026-11-27 20:43:44
Argumentos: hola-tc014
  B hermes --help: HERMES - Gestor de trabajos en cola

Uso: hermes <comando> [argumentos..]

Comandos:
  job [--request-id <id>] <programa> [argumentos..]
                                 Crea un trabajo; el ID de solicitud evita duplicados
  filter id <numero>             Muestra un trabajo por su ID
  filter status <ESTADO>         Lista trabajos por estado
  filter programa <nombre>       Lista trabajos por programa
  cancel <id>                    Cancela un trabajo en cola o en ejecucion
  clean data                     Limpia el historial de trabajos finalizados
  clean scheduler                Detiene el scheduler ordenadamente
  configmax <N>                  Configura el máximo de trabajos simultáneos (1-64)
  configmax --cola <M>           Configura los cupos de espera en cola (0-256)
  configmax <N> --cola <M>       Configura ambos valores en una sola operación
  red setup                      Asistente para registrar un equipo y configurar LAN/WSL
  red start                      Inicia escucha TCP en primer plano; Ctrl+C detiene
  red job <host> [--request-id <id>] <programa> [args...]
                                 Envía un trabajo al servidor por TCP LAN/VPN
  red filter <host> <id|status|programa> <valor>
                                 Aplica los mismos filtros que en modo local
  red cancel <host> <id>         Solicita cancelar un trabajo remoto propio
  health [--json]                Resume scheduler, red (direccion/puerto), trabajos y errores
  logs                           Sigue eventos nuevos hasta Ctrl+C
  --version                      Muestra la version
  --help                         Muestra esta ayuda

Estados: QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED, INTERRUPTED

Ejemplos:
  hermes job sleep 30
  hermes job --request-id pago-42 sleep 30
  hermes filter id 1
  hermes filter status RUNNING
  hermes cancel 1
  hermes clean data
  hermes clean scheduler
  hermes configmax 3
  hermes configmax 5 --cola 2
  hermes logs
  hermes health
  hermes health --json

Codigos de salida: 0 exito, 1 error
  B hermes health --json: {
  "advertencias": [],
  "completo": true,
  "consultado_en": "2026-11-27 20:43:44",
  "errores_recientes": [],
  "limite_errores": 10,
  "lineas_invalidas": 0,
  "red": {
    "activo": false,
    "configurado": {
      "interfaz": "127.0.0.1",
      "puerto": 45820
    },
    "interfaz": null,
    "puerto": null
  },
  "servicio": {
    "activo": true,
    "nombre": "scheduler"
  },
  "trabajos": {
    "en_cola": 0,
    "en_ejecucion": 0
  }
}
PASS V4/AC4: humo --version/--help/job/filter/health en ambos binarios y schedulers bajo UID del usuario
  instalado hermes --version: [34mversion 0.3[0m
  instalado hermes job sleep 120: job ID: 2
PID: 13717
  instalado hermes cancel 2: [34mCancelación solicitada para el Job: 2[0m
PASS V5/AC5: make install en HOME temporal; binario igual, sin setuid/setgid; Job real ejecutado y cancelado sin root
  instalado hermes red job 127.0.0.1 true: job ID: 3
PID: pendiente (en cola)
PASS V6/AC6: binario instalado atiende TCP 127.0.0.1:46941 y ejecuta Job remoto sin privilegios
PASS V7/AC7: uninstall retira solo instalacion temporal; datos y src/ del origen conservados
  A hermes clean scheduler: [34mScheduler detenido correctamente.[0m
  B hermes clean scheduler: [34mScheduler detenido correctamente.[0m
PASS V8/AC8: servidor recogido, schedulers detenidos y puerto libre; sin procesos propios; clones/HOME eliminados al salir
PASS: RNF-01 RNF-02 RNF-03 TC-014 sin fallos.
Resultado: 0

Codigo de salida TC-014: 0
```
