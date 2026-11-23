# Uso de inteligencia artificial

# 46. Implementación de RF-22: desconexión del cliente sin afectar al servicio

## Objetivo

Cerrar un hueco de robustez en el subsistema de red de Hermes. RF-22 exige que la desconexión de un cliente —ordenada, abrupta o por simple silencio— no termine el proceso servidor y no corrompa `jobs.json`. La auditoría previa del módulo de red (`CONTEXTO-RED-ACTUAL.md`) había documentado el modelo pero nunca lo había contrastado contra ese requisito concreto, y RF-22 figuraba `Pendiente` en la matriz de trazabilidad sin documento de especificación.

El trabajo cubrió dos fases: auditar el código real contra el requisito y proponer un diseño fundamentado, y después implementar ese diseño con pruebas automatizadas que demostraran cada criterio de aceptación.

---

## Prompt 1
```text
Actúa como arquitecto técnico supervisor (gentle-orchestrator) en modo estrictamente de solo lectura y diseño. Tu objetivo es auditar el código existente contra la especificación de RF-22 — Desconexión del cliente sin afectar al servicio: El sistema deberá manejar desconexiones del cliente sin terminar el servicio ni corromper trabajos, y diseñar una propuesta de solución concreta y fundamentada para resolverlo (sin modificar ningún archivo todavía ni crear pruebas en esta iteración).

Contexto base obligatorio
Antes de analizar el código o formular la propuesta, lee íntegramente:
docs/technical-guide/2-Nucleo del proyecto/CONTEXTO-RED-ACTUAL.md (línea base de arquitectura, protocolo, ciclo de vida de sockets y deuda técnica).

Fase 1: Auditoría y verificación del código existente
Aunque CONTEXTO-RED-ACTUAL.md documenta mecanismos ya presentes en la capa de red, verifica directamente en el código fuente cómo se comporta el sistema hoy ante cada escenario de desconexión:
-Ciclo de vida de sockets y bucle de eventos (src/hermes/src/network/server.cpp):
-Revisa poll(), manejo de eventos (POLLIN, POLLOUT, POLLERR, POLLHUP, POLLNVAL), recv() == 0, errores de socket (EPIPE, ECONNRESET, EAGAIN, EWOULDBLOCK), manejo de SIGPIPE/MSG_NOSIGNAL, timeouts de 3 s en lectura/escritura y liberación de descriptores (Cliente/Descriptor).
-Verifica qué ocurre cuando el cliente envía FIN prematuro sin salto de línea (actualmente se intenta responder INCOMPLETE_MESSAGE por POLLOUT) o corta con RST en mitad de lectura o escritura.
-Procesamiento de solicitudes y persistencia (protocol.cpp, remote.cpp, job.cpp, cancel.cpp):
-Verifica en protocol.cpp y remote.cpp qué pasa si el cliente se desconecta antes de completar el mensaje vs. después de ejecutar submit o cancel.
-Inspecciona crearJob() y la espera síncrona esperarInicioJob() en src/hermes/src/job/job.cpp (líneas 306-313), comprobando si un corte del cliente durante esa ventana puede bloquear el hilo de poll(), dejar estados inconsist
```

> Nota de fidelidad: el registro de la sesión truncó el prompt a 2003 caracteres. El texto cortado pedía además evaluar si esa ventana podía dejar estados inconsistentes en `jobs.json` y solicitar una propuesta de diseño con alternativas y riesgos.

---

## Resultado 1

La IA produjo una auditoría de solo lectura que verificó el código contra el requisito y formalizó siete criterios de aceptación (**AC1–AC7**): contención de excepciones por cliente, integridad de `jobs.json`, independencia respecto al *scheduler*, no fuga de descriptores, *liveness* del bucle bajo desconexiones masivas, liberación del slot en el mismo ciclo de `poll()` y registro del evento anómalo.

Encontró **ocho brechas** verificadas contra fuente:

| ID | Brecha | Evidencia en código |
|---|---|---|
| **B1** | La única frontera de excepción estaba fuera del bucle de clientes: una excepción de atención terminaba el proceso entero | `server.cpp:194` |
| **B2** | `INCOMPLETE_MESSAGE` se intentaba entregar por `POLLOUT` reteniendo el descriptor hasta ~6 s | `server.cpp:146-147,156-157` |
| **B3** | El timeout renovaba el plazo en lugar de cerrar, permitiendo retención indefinida con actividad | `server.cpp:171-174` |
| **B4** | `responder()` no reiniciaba `enviado`, así que una segunda solicitud en la misma conexión enviaba desde un desplazamiento incorrecto | `server.cpp:124-128` |
| **B5** | `esperarInicioJob()` dormía hasta 1 s dentro del hilo de `poll()` en cada `submit` | `remote.cpp:163` → `job.cpp:306-313` |
| **B6** | `flock()` bloqueante sin plazo | `storage.cpp:43`, `event_log.cpp:195` |
| **B7** | Pérdida silenciosa de una respuesta si el `RST` llega con datos en vuelo | `remote.cpp:212-216` |
| **B8** | Cero llamadas a `EventLog` en todo `src/hermes/src/network/` | búsqueda en el módulo |

Sobre esa base propuso cuatro caminos: **(A)** frontera de excepción por cliente con cierre determinista y cortesía de un intento; **(B)** respuesta diferida con estado por cliente; **(C)** `epoll` con pool de hilos; **(D)** mantener `esperarInicioJob` y solo acotar el plazo. Recomendó **A**, descartó B por añadir una máquina de estados por conexión sin resolver el bloqueo de cabeza de línea, descartó C por multiplicar la complejidad de concurrencia sobre un servidor de un solo hilo y descartó D por dejar el *head-of-line blocking* intacto.

Declaró además cuatro riesgos (R1 `flock` sin plazo fuera de alcance; R2 pérdida silenciosa en `RST`; R3 `cancel` remoto no idempotente; R4 coste de `fsync` de `EventLog`), un plan de verificación V1–V10 y una lista de 15 tareas.

---

## Prompt 2
```text
Autorizo pero primero, documenta todo tus hallazgos y tareas por realizar AL COMPLETO (todo lo que me pusiste aqui) en un .md donde hagas una "to-do list" de todos estos cambios en una tabla donde se registre si ya se implemento o no. primero realiza ese .md y despues preguntame si inciamos con el plan que creaste.
```

---

## Resultado 2

La IA creó el documento con el requisito formalizado, la matriz de cumplimiento AC1–AC7, las brechas B1–B8 con cita `archivo:línea`, la comparativa de alternativas, el diseño de los **seis cambios** concretos, los riesgos, el plan V1–V10 y la tabla de **16 tareas** (`T-00`…`T-15`) con columnas de estado y evidencia.

Añadió una regla de marcado explícita: una tarea solo pasa a `Hecho` cuando existe evidencia observada registrada —comando ejecutado y resultado—, nunca por haber escrito el código. Terminó preguntando si se iniciaba la implementación.

---

## Prompt 3
```text
si, empieza paso por paso y cuando quede completo lo marcas como "completado"
```

---

## Resultado 3

La IA implementó los seis cambios y los verificó de forma incremental.

**Código.** En `server.cpp` introdujo un `enum class Motivo` con diez valores y un centinela `Total`, una función `textoMotivo()` para la representación textual, una ventana de aviso `avisoPermitido()` con dos `std::array` estáticos indexados por motivo, el campo `ip` en `Cliente`, el reinicio de `enviado` en `responder()`, el helper `despedida()` de un solo `send()`, la frontera `try/catch` por iteración del bucle, el cierre explícito para `POLLERR`/`POLLNVAL`/`POLLHUP` y el rechazo en `accept4()` con bitácora. En `remote.cpp` eliminó la llamada a `esperarInicioJob(job)` de la rama `submit`.

**Pruebas.** Creó cinco scripts bash con Python embebido, cada uno con `HOME` temporal, `network.json` que autoriza `127.0.0.1`, servidor en segundo plano y limpieza por `trap EXIT` que mata primero el servidor, después el proceso que sostiene `scheduler.lock` y solo entonces borra el directorio temporal.

**Ejecución.** Compiló con `make hermes` sin advertencias y ejecutó las cinco pruebas en WSL, todas en `PASS`.

---

# Modificaciones

**Estado de la resolución:** **[Modificado]** — la IA entregó código correcto y verificado, pero la propuesta inicial contenía dos deficiencias que se detectaron y corrigieron durante la ejecución.

**Revisión realizada:** La auditoría se comprobó abriendo los archivos citados uno por uno. El diagnóstico de fondo se sostiene: `server.cpp` tenía su `try` fuera del bucle, `responder()` no reiniciaba `enviado`, el timeout renovaba `limite` en lugar de cerrar, y `esperarInicioJob()` bloqueaba el hilo de `poll()` hasta 1 s por `submit`. La clasificación de las brechas por severidad también resistió la revisión: B1 y B5 eran las únicas capaces de degradar el servicio completo; B2, B3 y B4 degradaban a un cliente concreto.

La revisión humana encontró dos defectos en el entregable de la IA:

1. **Colisión de numeración en los casos de prueba.** La IA creó los cinco scripts como `TC-025`…`TC-029` después de inspeccionar solo `verif/scripts/`, donde el último caso presente era `TC-024`. No consultó `verif/test-cases/test-cases.md`, que ya referenciaba un `TC-025` como el caso de RF-05 —sin script asociado, pero reservado en el índice—. Los cinco archivos se renumeraron a `TC-030`…`TC-034`, incluidos sus `.md` y sus archivos de resultados. La lección es que la fuente de verdad de la numeración de casos es el índice, no el directorio de scripts.

2. **Objetivo de compilación equivocado.** La IA propuso `make all` para verificar la compilación. Esa regla ejecuta el binario, que sin un `HOME` válido falla al resolver el enlace `data/`. Se corrigió a `make hermes`, que compila sin ejecutar. El diseño de las pruebas ya usaba `HOME` temporal, así que la corrección fue localizada, pero el primer comando propuesto no era utilizable tal cual.

Además, dos invocaciones de shell iniciales fallaron por escapes entre PowerShell y WSL (`$((n+5))` se expandía en PowerShell en lugar de en bash, y una comilla mal cerrada producía `unexpected EOF`). No afectaron al código entregado, pero costaron iteraciones evitables y se resolvieron simplificando los comandos a operaciones sin aritmética de shell.

Ninguna de las dos deficiencias llegó al entregable final: ambas se detectaron ejecutando, no leyendo.

**Cambios aplicados:**

- `server.cpp`: `#include "event_log.h"` y `<array>`; `using Reloj = std::chrono::steady_clock`; `enum class Motivo` + `TOTAL_MOTIVOS` + `textoMotivo()` + `avisoPermitido()` en el espacio anónimo; `std::string ip` y `Motivo motivo` en `Cliente`; reinicio de `enviado` en `responder()`; helper `despedida()`; `registrar()`; `try/catch` por cliente; cierre explícito por evento; rechazo con bitácora en `accept4()`.
- `remote.cpp`: supresión de `esperarInicioJob(job)` en la rama `submit`, con comentario explicativo del *head-of-line blocking*.
- Renumeración `TC-025`…`TC-029` → `TC-030`…`TC-034` en scripts, casos y resultados.
- `make all` → `make hermes` como comando de verificación de compilación.

**Prueba agregada:**

Las cinco pruebas se ejecutaron en WSL Ubuntu sobre un `HOME` temporal, con salida guardada en `verif/results/`.

- **TC-030** (`FIN`, `RST` y `SIGKILL` con mensaje parcial tras un `submit`): los tres escenarios en `PASS`; servicio vivo, `ping` posterior correcto, `jobs.json` válido y Jobs aceptados en estado terminal.
- **TC-031** (40 desconexiones de un byte; cliente lento; corte durante un `list`): `ping` posterior en **57 ms**, cliente lento expulsado en **3.0 s** con `REQUEST_TIMEOUT`, servicio intacto tras el corte.
- **TC-032** (100 ciclos de conexión/desconexión): descriptores **5 → 5**, sin archivos `jobs.json.tmp.*`.
- **TC-033** (5 desconexiones anómalas + un `ping` normal): exactamente **1** aviso `FIN_SIN_MENSAJE`; el `ping` no añadió ruido; sin `ERROR_INTERNO`.
- **TC-034** (`hermes red job` remoto y reenvío con el mismo `request_id`): admisión en **21 ms** con `PID: pendiente (en cola)`, duplicado detectado, Job `1` en `SUCCEEDED`.
- Compilación: `make hermes` sin advertencias bajo `-Wall -Wextra`.

---

## Implementación de feature

**Contención de la desconexión por cliente.** El bucle de `poll()` atiende a cada cliente dentro de su propio `try/catch`. Un fallo en la atención de un cliente —incluida una excepción no capturada por `procesarSolicitudRed()`— cierra ese descriptor y registra `ERROR_INTERNO`; el bucle continúa con el resto y el proceso servidor nunca termina por esta vía.

**Cierre determinista con motivo.** Cada desconexión se clasifica en un `enum class Motivo` de diez valores y se cierra en el mismo ciclo en que se detecta. El cierre normal tras entregar la respuesta no genera ninguna entrada; los anómalos sí, con la IP, el motivo y los bytes recibidos.

**Cortesía de un intento.** Cuando el par ya no existe, el servidor escribe el sobre de error con un único `send(..., MSG_NOSIGNAL)` y cierra el descriptor sin esperar `POLLOUT`. Esto elimina la retención de hasta 6 s que agotaba el cupo de 32 conexiones.

**Ventana de aviso.** Para no pagar el `fsync` de `EventLog` por conexión rechazada, cada motivo se registra como máximo una vez cada 60 s, con estado estático por proceso.

**Admisión remota sin espera.** La rama `submit` de `remote.cpp` deja de esperar al *scheduler*: responde en cuanto el Job queda persistido, con `pid: 0` y estado `QUEUED`. El cliente oficial ya representaba ese caso como `PID: pendiente (en cola)`.

---

## Modificación de archivo

### `src/hermes/src/network/server.cpp`

```cpp
using Reloj = std::chrono::steady_clock;

// Motivo de cierre de un cliente. Solo los motivos anómalos llegan a la
// bitácora: el cierre normal tras entregar la respuesta no se registra.
enum class Motivo : std::size_t {
    CierreNormal = 0,
    FinSinMensaje,
    TimeoutLectura,
    TimeoutEscritura,
    ErrorLectura,
    ErrorEscritura,
    ErrorSocket,
    ErrorInterno,
    OrigenRechazado,
    CupoExcedido,
    Total
};

constexpr std::size_t TOTAL_MOTIVOS = static_cast<std::size_t>(Motivo::Total);

// Un aviso por motivo cada 60 s: EventLog hace open+flock+write+fsync+close
// por evento y el hilo de red no puede pagar ese coste por conexión rechazada.
bool avisoPermitido(Motivo motivo) {
    static std::array<Reloj::time_point, TOTAL_MOTIVOS> ultimo{};
    static std::array<bool, TOTAL_MOTIVOS> usado{};
    if (motivo == Motivo::CierreNormal) return false;
    const auto indice = static_cast<std::size_t>(motivo);
    const auto ahora = Reloj::now();
    if (usado[indice] && ahora - ultimo[indice] < std::chrono::seconds(60)) return false;
    usado[indice] = true;
    ultimo[indice] = ahora;
    return true;
}
```

```cpp
struct Cliente {
    explicit Cliente(int fd) : socket(fd), limite(Reloj::now() + std::chrono::seconds(3)) {}
    Descriptor socket;
    short esperado = POLLIN;
    std::string identidad;
    std::string ip;
    const PermisosRemotos* permisos = nullptr;
    std::string entrada, salida;
    std::size_t enviado = 0;
    Reloj::time_point limite;
    bool cerrado = false;
    Motivo motivo = Motivo::CierreNormal;
};
```

```cpp
auto responder = [](Cliente& cliente, std::string respuesta) {
    cliente.salida = std::move(respuesta);
    cliente.enviado = 0;
    cliente.esperado = POLLOUT;
    cliente.limite = Reloj::now() + std::chrono::seconds(3);
};
// Error de cortesía: un solo intento de escritura y cierre inmediato.
auto despedida = [](Cliente& cliente, const char* codigo, Motivo motivo) {
    cliente.salida = errorProtocolo(codigo);
    cliente.enviado = 0;
    if (!cliente.salida.empty())
        (void)send(cliente.socket.valor, cliente.salida.data(),
                   cliente.salida.size(), MSG_NOSIGNAL);
    cliente.motivo = motivo;
    cliente.cerrado = true;
};
auto registrar = [](const Cliente& cliente) {
    if (!avisoPermitido(cliente.motivo)) return;
    EventLog::log_event_system(EventLevel::WARN, "Cliente desconectado", {
        {"ip", cliente.ip},
        {"motivo", textoMotivo(cliente.motivo)},
        {"bytes_recibidos", cliente.entrada.size()}
    });
};
```

```cpp
for (std::size_t i = 0; i < clientes.size(); ++i) {
    auto& cliente = *clientes[i];
    const auto evento = eventos[i + 1].revents;
    // Un fallo al atender a un cliente nunca puede terminar el
    // servicio: se cierra ese cliente y se sigue con el resto.
    try {
        if (evento & (POLLERR | POLLNVAL)) {
            cliente.motivo = Motivo::ErrorSocket;
            cliente.cerrado = true;
            continue;
        }
        // Hang up con respuesta pendiente: ya no hay par que lea.
        if ((evento & POLLHUP) && !cliente.salida.empty()) {
            cliente.motivo = Motivo::ErrorEscritura;
            cliente.cerrado = true;
            continue;
        }
        if (cliente.salida.empty() && (evento & (cliente.esperado | POLLHUP))) {
            char buffer[4096];
            const auto leidos = recv(cliente.socket.valor, buffer, sizeof(buffer), 0);
            if (leidos > 0) {
                cliente.entrada.append(buffer, static_cast<std::size_t>(leidos));
                const auto fin = cliente.entrada.find('\n');
                if ((fin == std::string::npos && cliente.entrada.size() > MAX_MENSAJE_RED) ||
                    (fin != std::string::npos && fin > MAX_MENSAJE_RED))
                    responder(cliente, errorProtocolo("MESSAGE_TOO_LARGE"));
                else if (fin != std::string::npos)
                    responder(cliente, procesarSolicitudRed(cliente.entrada.substr(0, fin), cliente.identidad, cliente.permisos));
            } else if (leidos == 0) {
                despedida(cliente, "INCOMPLETE_MESSAGE", Motivo::FinSinMensaje);
            } else if (errno != EINTR && errno != EAGAIN && errno != EWOULDBLOCK) {
                cliente.motivo = Motivo::ErrorLectura;
                cliente.cerrado = true;
            }
        }
        if (!cliente.cerrado && Reloj::now() >= cliente.limite) {
            if (cliente.salida.empty())
                despedida(cliente, "REQUEST_TIMEOUT", Motivo::TimeoutLectura);
            else {
                cliente.motivo = Motivo::TimeoutEscritura;
                cliente.cerrado = true;
            }
        }
    } catch (const std::exception& error) {
        EventLog::log_event_system(EventLevel::ERROR, "Error interno al procesar cliente", {
            {"ip", cliente.ip}, {"detalle", error.what()}
        });
        cliente.motivo = Motivo::ErrorInterno;
        cliente.cerrado = true;
    } catch (...) {
        EventLog::log_event_system(EventLevel::ERROR, "Error interno al procesar cliente", {
            {"ip", cliente.ip}
        });
        cliente.motivo = Motivo::ErrorInterno;
        cliente.cerrado = true;
    }
}
for (const auto& cliente : clientes) registrar(*cliente);
clientes.erase(std::remove_if(clientes.begin(), clientes.end(),
    [](const auto& cliente) { return cliente->cerrado; }), clientes.end());
```

```cpp
char ip[INET_ADDRSTRLEN]{};
if (!inet_ntop(AF_INET, &origen.sin_addr, ip, sizeof(ip)))
    continue;
if (!origenRedPermitido(ip, config.redesPermitidas)) {
    if (avisoPermitido(Motivo::OrigenRechazado))
        EventLog::log_event_system(EventLevel::WARN, "Conexión rechazada", {
            {"ip", ip}, {"motivo", textoMotivo(Motivo::OrigenRechazado)}
        });
    continue;
}
if (clientes.size() >= 32) {
    if (avisoPermitido(Motivo::CupoExcedido))
        EventLog::log_event_system(EventLevel::WARN, "Conexión rechazada", {
            {"ip", ip}, {"motivo", textoMotivo(Motivo::CupoExcedido)}
        });
    continue;
}
auto cliente = std::make_unique<Cliente>(conexion.valor);
conexion.valor = -1;
cliente->ip = ip;
```

### `src/hermes/src/network/remote.cpp`

```cpp
const auto config = cargarConfiguracion();
auto job = crearJob(programa, argumentos, "red-" + identidad + "-" + requestId,
                         config.trabajosMaximos, config.maxCola, identidad);
// Sin espera al scheduler: el hilo de poll() no puede bloquearse hasta
// 1 s por submit (head-of-line blocking). El Job ya está persistido y
// el cliente tolera pid 0 ("PID: pendiente (en cola)").
return exito({{"job_id", job.job_id}, {"duplicated", job.solicitudDuplicada}, {"job", jsonDesdeJob(job)}});
```

---

# Implementación final

**1. Desconexión ordenada tras un `submit`.** El cliente recibe la admisión, cierra la conexión y el servidor no escribe nada en la bitácora:

```text
job ID: 7
PID: pendiente (en cola)
```

El Job queda `QUEUED` y el *scheduler*, en otro proceso, lo lleva a `SUCCEEDED`.

**2. Cliente que corta con `RST` a mitad de un mensaje.** El servidor sigue en primer plano y responde `ping` normalmente. La bitácora registra:

```json
{"context":{"bytes_recibidos":76,"ip":"127.0.0.1","motivo":"ERROR_SOCKET"},"job_id":null,"level":"WARN","message":"Cliente desconectado","ts":"2026-11-18 20:29:15"}
```

**3. Cliente que nunca completa el mensaje.** A los ~3 s recibe el sobre de error y el slot se libera en el mismo ciclo:

```json
{"error":"REQUEST_TIMEOUT","ok":false,"request_id":null,"version":1}
```

```json
{"context":{"bytes_recibidos":33,"ip":"127.0.0.1","motivo":"TIMEOUT_LECTURA"},"job_id":null,"level":"WARN","message":"Cliente desconectado","ts":"2026-11-18 20:29:40"}
```

**4. Ráfaga de desconexiones.** Cinco conexiones que envían `{` y cierran la escritura producen **una sola** entrada, no cinco:

```json
{"context":{"bytes_recibidos":1,"ip":"127.0.0.1","motivo":"FIN_SIN_MENSAJE"},"job_id":null,"level":"WARN","message":"Cliente desconectado","ts":"2026-11-18 20:31:07"}
```

**5. Origen no autorizado.** La conexión se cierra sin respuesta y queda constancia:

```json
{"context":{"ip":"127.0.0.1","motivo":"ORIGEN_RECHAZADO"},"job_id":null,"level":"WARN","message":"Conexión rechazada","ts":"2026-11-18 20:29:41"}
```

**6. Salida de la suite de verificación** (`bash verif/scripts/TC-030.sh`):

```text
Arrancando 'hermes red start' con HOME temporal...
PASS V1: FIN tras submit; servicio vivo y jobs.json consistente.
PASS V2: RST tras submit; servicio vivo y sin Jobs parciales.
PASS V3: SIGKILL con mensaje parcial; servicio vivo y sin Jobs parciales.
PASS V4/AC3: los Jobs aceptados alcanzaron estado terminal.
PASS: RF-22 T-09 (V1-V3) sin fallos.
```

---

# Aprendizaje

**Sobre C++ y el modelo de sockets.** Este trabajo dejó clara una distinción que es fácil pasar por alto: el bucle de eventos no es una *feature*, es la estructura de control del proceso. Añadir código dentro de él sin pensar en el alcance de las excepciones convierte cualquier `throw` de terceros en una caída del servicio; mover el `try` un nivel hacia dentro fue un cambio de dos líneas con consecuencias arquitectónicas. Igualmente instructivo fue separar el plazo de lectura del de escritura: un solo *timeout* parecía suficiente hasta que se razonó que retener una respuesta que nadie va a leer no tiene sentido. Y `MSG_NOSIGNAL` en cada `send()` no es cosmética: sin él, un par desconectado entrega `SIGPIPE` y el proceso muere sin pasar por ningún `catch`.

**Sobre arquitectura.** La decisión de no tocar `storage.cpp` ni `scheduler.cpp` fue tan importante como los cambios que sí se hicieron. La atomicidad de `jobs.json` y la independencia de proceso del *scheduler* ya garantizaban dos de los siete criterios; reescribirlas para "integrar" el nuevo comportamiento habría introducido riesgo en código que ya cumplía. Delimitar el alcance con evidencia —y no por comodidad— es una decisión técnica de primer orden.

**Sobre verificación.** Las dos deficiencias que tuvo este trabajo las detectó la ejecución, no la lectura. La colisión de numeración de casos existía porque se inspeccionó el directorio de scripts y no el índice de casos; el `make all` fallaba porque nadie había ejecutado ese comando. La regla de marcar una tarea como completada solo con evidencia observada no es burocracia: es el mecanismo que hace visibles estos errores antes de que lleguen al entregable.

**Sobre Prompt Engineering.** El resultado mejoró de forma medible cuando el prompt fijó el alcance por fase: primero auditar en solo lectura y sin tocar archivos, después documentar la lista de tareas, después implementar. Sin esa separación, la IA tiende a escribir código antes de haber entendido el problema, y las auditorías se convierten en refactorizaciones disfrazadas. La instrucción de citar `archivo:línea` en cada hallazgo fue igual de decisiva: obligó a verificar contra fuente en lugar de repetir lo que ya decía `CONTEXTO-RED-ACTUAL.md`, y permitió comprobar después, una por una, cada afirmación del informe.
