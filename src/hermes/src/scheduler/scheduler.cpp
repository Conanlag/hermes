
#include "scheduler.h"

#include "job.h"
#include "process.h"
#include "recovery.h"
#include "storage.h"
#include "timestamp.h"
#include "data_paths.h"
#include "event_log.h"

#include <chrono>
#include <cerrno>
#include <condition_variable>
#include <map>
#include <mutex>
#include <thread>
#include <vector>
#include <string>
#include <stdexcept>
#include <exception>
#include <cstring>
#include <utility>

#include <fcntl.h>
#include <sys/file.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <signal.h>

using namespace std;
using namespace std::this_thread;
using namespace std::chrono;

namespace {

constexpr int NUM_TRABAJADORES = 5;

struct TrabajoPendiente {
    unsigned int id = 0;
    string programa;
    vector<string> argumentos;
};

bool reservarTrabajo(TrabajoPendiente& trabajo) {
    unsigned int idReservado = 0;
    string programaReservado;
    vector<string> argumentosReservados;

    const bool reservado = modificarJobsSeguros([&](json& jobs) {
        for (auto& item : jobs) {
            if (!item.contains("status") ||
                item["status"] != "QUEUED") {
                continue;
            }

            if (!item.contains("job_id") ||
                !item.contains("programa") ||
                !item.contains("argumentos") ||
                !item["argumentos"].is_array()) {
                continue;
            }

            idReservado = item["job_id"].get<unsigned int>();
            programaReservado =
                item["programa"].get<string>();

            argumentosReservados.clear();

            for (const auto& argumento : item["argumentos"]) {
                if (argumento.is_string()) {
                    argumentosReservados.push_back(
                        argumento.get<string>()
                    );
                }
            }

            item["status"] = "RUNNING";
            item["pid"] = 0;
            item["tiempo_inicio"] = obtenerFechaHoraActual();

            return true;
        }

        return false;
    });

    if (!reservado) {
        return false;
    }

    // F5: el trabajo solo se publica al llamador cuando la reserva quedó
    // persistida. Si modificarJobsSeguros lanza, `trabajo.id` sigue en 0 y el
    // catch del trabajador no puede marcar FAILED una fila que en disco
    // todavía es QUEUED.
    trabajo.id = idReservado;
    trabajo.programa = std::move(programaReservado);
    trabajo.argumentos = std::move(argumentosReservados);

    return true;
}

// Persiste el PID y la identidad del proceso recién creado.
//
// La identidad (boot_id + starttime) es lo que permite a la recuperación
// distinguir "nuestro Job" de un PID reciclado por el sistema. Se devuelve al
// llamador para registrarla en el mapa de activos sin volver a leer /proc.
//
// @return false si no quedó una fila RUNNING que supervise el proceso.
bool guardarPid(
    unsigned int id,
    pid_t pid,
    IdentidadProceso& identidad,
    bool& hayIdentidad
) {
    bool cancelar = false;

    identidad = IdentidadProceso{};
    hayIdentidad = leerIdentidadProceso(pid, identidad);

    bool guardado = false;

    try {
        guardado = modificarJobsSeguros([&](json& jobs) {
            for (auto& item : jobs) {
                if (!item.contains("job_id") ||
                    item["job_id"] != id) {
                    continue;
                }

                if (item["status"] != "RUNNING") {
                    return false;
                }

                item["pid"] = static_cast<int>(pid);

                if (hayIdentidad) {
                    item["boot_id"] = identidad.bootId;
                    item["pid_inicio"] =
                        static_cast<unsigned long long>(
                            identidad.pidInicio
                        );
                    item["sid"] = static_cast<int>(identidad.sid);
                }

                cancelar =
                    item.contains("cancel_requested") &&
                    item["cancel_requested"].is_boolean() &&
                    item["cancel_requested"].get<bool>();

                return true;
            }

            return false;
        });
    } catch (...) {
        guardado = false;
    }

    if (!guardado) {
        // F4: sin fila que supervise el PID, dejarlo vivo produce un
        // huérfano que nadie puede reconciliar. Se termina el proceso y el
        // trabajador registrará el fallo.
        //
        // Solo se señala el grupo si la identidad leída confirma que el
        // pgrp es suyo; si no, se mata únicamente el PID exacto que se
        // acaba de crear. Nunca se señala un grupo no verificado.
        if (hayIdentidad && identidad.pgrp == pid) {
            terminarGrupoProceso(pid);
        } else {
            kill(pid, SIGKILL);
        }

        return false;
    }

    hermes::EventLog::log_event(id, hermes::EventLevel::INFO, "Transición a RUNNING", {
        {"pid", static_cast<int>(pid)}
    });

    if (!hayIdentidad) {
        hermes::EventLog::log_event(id, hermes::EventLevel::WARN, "Identidad de proceso no verificable", {
            {"pid", static_cast<int>(pid)}
        });
    }

    // Si se pidió cancelar antes de guardar el PID,
    // terminar el proceso cuando su PID esté disponible.
    if (cancelar) {
        terminarProceso(pid);
        hermes::EventLog::log_event(id, hermes::EventLevel::DEBUG, "Cancelación solicitada antes de iniciar ejecución", {
            {"pid", static_cast<int>(pid)}
        });
    }

    return true;
}

void finalizarTrabajo(
    unsigned int id,
    int codigoSalida,
    bool procesoValido
) {
    bool fueCancelado = false;
    bool fueExitoso = false;
    bool fueFallido = false;
    int signalNumber = 0;

    if (procesoValido && codigoSalida < 0) {
        signalNumber = -codigoSalida;
    }

    modificarJobsSeguros([&](json& jobs) {
        for (auto& item : jobs) {
            if (!item.contains("job_id") ||
                item["job_id"] != id) {
                continue;
            }

            bool cancelar =
                item.contains("cancel_requested") &&
                item["cancel_requested"].is_boolean() &&
                item["cancel_requested"].get<bool>();

            if (cancelar) {
                item["status"] = "CANCELED";
                fueCancelado = true;
            } else if (procesoValido && codigoSalida == 0) {
                item["status"] = "SUCCEEDED";
                fueExitoso = true;
            } else {
                item["status"] = "FAILED";
                fueFallido = true;
            }

            item["codigo_salida"] = codigoSalida;
            item["tiempo_terminacion"] =
                obtenerFechaHoraActual();

            return true;
        }

        return false;
    });

    if (fueCancelado) {
        hermes::EventLog::log_event(id, hermes::EventLevel::INFO, "Cancelación exitosa", {
            {"estado_previo", "RUNNING"},
            {"exit_code", codigoSalida}
        });
    } else if (fueExitoso) {
        hermes::EventLog::log_event(id, hermes::EventLevel::INFO, "Transición a SUCCEEDED", {
            {"exit_code", codigoSalida}
        });
    } else if (fueFallido) {
        nlohmann::json ctx;
        ctx["exit_code"] = codigoSalida;
        if (signalNumber > 0) {
            ctx["signal_number"] = signalNumber;
        }
        hermes::EventLog::log_event(id, hermes::EventLevel::ERROR, "Transición a FAILED", ctx);
    }
}

void registrarFallo(
    unsigned int id,
    int codigoSalida,
    const string& mensaje
) {
    bool fueCancelado = false;
    bool actualizado = false;

    modificarJobsSeguros([&](json& jobs) {
        for (auto& item : jobs) {
            if (!item.contains("job_id") ||
                item["job_id"] != id) {
                continue;
            }

            // F5: solo se registra un fallo sobre la fila que el scheduler
            // tiene realmente en RUNNING. Si la reserva no se persistió, la
            // fila sigue QUEUED y marcarla FAILED convertiría en fallo un
            // trabajo que nunca se ejecutó; si ya es terminal, su resultado
            // real no se sobrescribe.
            if (!item.contains("status") ||
                !item["status"].is_string() ||
                item["status"].get<string>() != "RUNNING") {
                continue;
            }

            bool cancelar =
                item.contains("cancel_requested") &&
                item["cancel_requested"].is_boolean() &&
                item["cancel_requested"].get<bool>();

            item["status"] = cancelar ? "CANCELED" : "FAILED";
            item["codigo_salida"] = codigoSalida;
            item["mensaje_error"] = mensaje;
            item["tiempo_terminacion"] =
                obtenerFechaHoraActual();
            fueCancelado = cancelar;
            actualizado = true;

            return true;
        }

        return false;
    });

    if (!actualizado) {
        return;
    }

    if (fueCancelado) {
        hermes::EventLog::log_event(id, hermes::EventLevel::INFO, "Cancelación exitosa", {
            {"estado_previo", "RUNNING"},
            {"exit_code", codigoSalida},
            {"detalle", mensaje}
        });
    } else {
        nlohmann::json ctx;
        ctx["exit_code"] = codigoSalida;
        ctx["detalle"] = mensaje;
        ctx["errno"] = errno;
        hermes::EventLog::log_event(id, hermes::EventLevel::ERROR, "Error interno del daemon", ctx);
    }
}

// --- Cierre ordenado (Corte 3 de RF-13, sección 2.5) ---
//
// El handler de señal solo escribe un flag `sig_atomic_t`: no puede tomar
// mutex, tocar JSON ni llamar a funciones que no sean async-signal-safe. El
// coordinador es un hilo único que señaliza los grupos del registro, espera a
// que los workers recojan a sus hijos y persiste el estado INTERRUPTED. Así
// una sola transacción escribe el estado final y no hay dos escritores
// compitiendo por la misma fila.

struct TrabajoActivo {
    pid_t pid = 0;
    pid_t pgid = 0;
    pid_t sid = 0;
    bool grupoVerificado = false;
    bool interrumpido = false;
    bool procesoTerminado = false;
};

// Protege la ventana reservar -> spawn -> registrar: el coordinador lo toma
// antes de cerrar la puerta, de modo que ningún Job queda iniciado pero fuera
// del registro.
std::mutex mutexArranque;

// Protege el mapa de activos y la condición de "todos recogidos".
std::mutex mutexActivos;
std::condition_variable cvActivos;
std::map<unsigned int, TrabajoActivo> activos;

bool apagadoSolicitado = false;

volatile sig_atomic_t banderaApagado = 0;

void manejarSenalApagado(int) {
    banderaApagado = 1;
}

void instalarHandlersDeApagado() {
    struct sigaction accion;

    std::memset(&accion, 0, sizeof(accion));
    accion.sa_handler = manejarSenalApagado;
    sigemptyset(&accion.sa_mask);
    // SA_RESTART conserva el comportamiento de read()/waitpid(): el
    // coordinador termina el grupo y el worker recoge al hijo sin tratar un
    // EINTR como fallo.
    accion.sa_flags = SA_RESTART;

    sigaction(SIGTERM, &accion, nullptr);
    sigaction(SIGINT, &accion, nullptr);
}

void registrarTrabajoActivo(
    unsigned int id,
    pid_t pid,
    const IdentidadProceso& identidad,
    bool hayIdentidad
) {
    TrabajoActivo activo;
    activo.pid = pid;
    activo.pgid = pid;
    activo.sid = hayIdentidad ? identidad.sid : 0;

    // Solo se señala el grupo si su pgrp es el PID que acabamos de crear; si
    // no, la terminación se limita al PID exacto.
    activo.grupoVerificado = hayIdentidad && identidad.pgrp == pid;

    std::lock_guard<std::mutex> bloqueo(mutexActivos);
    activos[id] = activo;
}

// Retira el trabajo del registro y devuelve si el coordinador lo marcó para
// interrumpir. El worker usa ese valor para no competir por la escritura del
// estado final: el coordinador es el único autor de `motivo=apagado`.
bool desregistrarTrabajoActivo(unsigned int id) {
    std::lock_guard<std::mutex> bloqueo(mutexActivos);

    auto encontrado = activos.find(id);

    if (encontrado == activos.end()) {
        return false;
    }

    const bool interrumpido = encontrado->second.interrumpido;
    activos.erase(encontrado);

    if (activos.empty()) {
        cvActivos.notify_all();
    }

    return interrumpido;
}

void senalizarTrabajoActivo(const TrabajoActivo& activo, int senal) {
    if (activo.grupoVerificado) {
        senalizarGrupoProceso(activo.pgid, senal);
        return;
    }

    kill(activo.pid, senal);
}

bool trabajoActivoSigueVivo(const TrabajoActivo& activo) {
    if (activo.grupoVerificado && activo.sid > 0) {
        // NoVerificable se trata como vivo: no se afirma una terminación
        // que no se pudo comprobar.
        return estadoGrupoProceso(activo.pgid, activo.sid) !=
               EstadoGrupoProceso::Inexistente;
    }

    return procesoVivo(activo.pid);
}

bool algunActivoVivo(
    const std::map<unsigned int, TrabajoActivo>& pendientes
) {
    for (const auto& entrada : pendientes) {
        if (trabajoActivoSigueVivo(entrada.second)) {
            return true;
        }
    }

    return false;
}

// Termina el lote con UNA sola ventana de gracia compartida, igual que la
// recuperación: N Jobs cuestan ~5 s, no N x 5 s.
void terminarActivos(
    std::map<unsigned int, TrabajoActivo>& pendientes
) {
    if (pendientes.empty()) {
        return;
    }

    for (auto& entrada : pendientes) {
        senalizarTrabajoActivo(entrada.second, SIGTERM);
    }

    const auto finGracia = steady_clock::now() + seconds(5);

    while (steady_clock::now() < finGracia &&
           algunActivoVivo(pendientes)) {
        sleep_for(milliseconds(100));
    }

    for (auto& entrada : pendientes) {
        if (trabajoActivoSigueVivo(entrada.second)) {
            senalizarTrabajoActivo(entrada.second, SIGKILL);
        }
    }

    const auto finForzado = steady_clock::now() + seconds(5);

    while (steady_clock::now() < finForzado &&
           algunActivoVivo(pendientes)) {
        sleep_for(milliseconds(100));
    }

    for (auto& entrada : pendientes) {
        entrada.second.procesoTerminado =
            !trabajoActivoSigueVivo(entrada.second);
    }
}

// Único escritor del estado final durante el apagado: una sola transacción
// para todos los Jobs que seguían activos.
void persistirInterrumpidosPorApagado(
    const std::map<unsigned int, TrabajoActivo>& pendientes
) {
    if (pendientes.empty()) {
        return;
    }

    const string ahora = obtenerFechaHoraActual();
    bool escrituraFallida = false;
    string detalleError;

    try {
        modificarJobsSeguros([&](json& jobs) {
            for (auto& item : jobs) {
                if (!item.is_object() ||
                    !item.contains("job_id")) {
                    continue;
                }

                const unsigned int id =
                    item["job_id"].get<unsigned int>();

                auto encontrado = pendientes.find(id);

                if (encontrado == pendientes.end()) {
                    continue;
                }

                // Nunca se pisa un estado terminal: su resultado real ya
                // está escrito y no pertenece a este apagado.
                if (!item.contains("status") ||
                    !item["status"].is_string() ||
                    item["status"].get<string>() != "RUNNING") {
                    continue;
                }

                item["status"] = "INTERRUPTED";
                item["codigo_salida"] = -1;
                item["tiempo_terminacion"] = ahora;
                item["mensaje_error"] =
                    "Trabajo interrumpido por el apagado ordenado del "
                    "scheduler. No se reejecutó automáticamente.";
                item["motivo"] = "apagado";
                item["proceso_terminado"] =
                    encontrado->second.procesoTerminado;
            }

            return true;
        });
    } catch (const exception& e) {
        escrituraFallida = true;
        detalleError = e.what();
    } catch (...) {
        escrituraFallida = true;
        detalleError = "error desconocido";
    }

    for (const auto& entrada : pendientes) {
        try {
            if (escrituraFallida) {
                hermes::EventLog::log_event(
                    entrada.first,
                    hermes::EventLevel::ERROR,
                    "No se pudo persistir el estado INTERRUPTED durante el apagado",
                    { {"detalle", detalleError} }
                );
            } else if (!entrada.second.procesoTerminado) {
                hermes::EventLog::log_event(
                    entrada.first,
                    hermes::EventLevel::ERROR,
                    "El grupo no terminó durante el apagado",
                    { {"pid", static_cast<int>(entrada.second.pid)} }
                );
            } else {
                hermes::EventLog::log_event(
                    entrada.first,
                    hermes::EventLevel::INFO,
                    "Trabajo interrumpido por apagado",
                    {
                        {"pid", static_cast<int>(entrada.second.pid)},
                        {"motivo", "apagado"}
                    }
                );
            }
        } catch (...) {
            // La bitácora no debe impedir el apagado.
        }
    }
}

void coordinarApagado() {
    while (banderaApagado == 0) {
        sleep_for(milliseconds(50));
    }

    std::map<unsigned int, TrabajoActivo> pendientes;

    {
        // Toma la puerta de arranque: cuando este bloque termina, cualquier
        // worker que despierte verá el apagado y no iniciará otro Job.
        std::lock_guard<std::mutex> bloqueoArranque(mutexArranque);
        apagadoSolicitado = true;

        std::lock_guard<std::mutex> bloqueoActivos(mutexActivos);

        for (auto& entrada : activos) {
            entrada.second.interrumpido = true;
            pendientes.emplace(entrada.first, entrada.second);
        }
    }

    terminarActivos(pendientes);

    {
        // Los workers recogen a sus hijos y retiran su entrada. El
        // coordinador espera para ser el único escritor del estado final.
        std::unique_lock<std::mutex> bloqueo(mutexActivos);
        cvActivos.wait_for(bloqueo, seconds(5), [] {
            return activos.empty();
        });
    }

    persistirInterrumpidosPorApagado(pendientes);
}

void trabajador() {
    while (true) {
        TrabajoPendiente trabajo;
        int pipeStderr = -1;
        pid_t pid = -1;
        bool procesoRegistrado = false;

        std::unique_lock<std::mutex> bloqueoArranque(mutexArranque);

        // La puerta se cierra bajo `mutexArranque`: o este worker ya inició y
        // registró su Job, o el coordinador ya marcó el apagado y el worker
        // sale sin reservar nada nuevo.
        if (apagadoSolicitado) {
            return;
        }

        try {
            if (!reservarTrabajo(trabajo)) {
                bloqueoArranque.unlock();
                sleep_for(milliseconds(200));
                continue;
            }

            pid = iniciarProceso(
                trabajo.programa,
                trabajo.argumentos,
                pipeStderr
            );

            IdentidadProceso identidad;
            bool hayIdentidad = false;

            if (!guardarPid(
                    trabajo.id,
                    pid,
                    identidad,
                    hayIdentidad)) {
                // El proceso ya fue terminado al no poder registrarse.
                // Se recoge para no dejar un zombie y se reporta el fallo
                // en lugar de afirmar una transición a RUNNING.
                close(pipeStderr);

                int codigoDescartado = -1;
                esperarProceso(pid, codigoDescartado);

                try {
                    registrarFallo(
                        trabajo.id,
                        -1,
                        "No se pudo registrar el PID del proceso; "
                        "se terminó para no dejarlo sin supervisión."
                    );
                } catch (...) {
                    // No terminar el trabajador por un error
                    // al guardar el resultado.
                }

                bloqueoArranque.unlock();
                continue;
            }

            registrarTrabajoActivo(
                trabajo.id,
                pid,
                identidad,
                hayIdentidad
            );

            procesoRegistrado = true;
            bloqueoArranque.unlock();

        } catch (const exception& e) {
            const bool teniaReserva = trabajo.id != 0;
            bloqueoArranque.unlock();

            if (pid > 0 && !procesoRegistrado) {
                // El spawn ocurrió pero el registro falló: sin una entrada en
                // el mapa, el apagado no podría terminar este grupo.
                kill(pid, SIGKILL);

                int codigoDescartado = -1;
                esperarProceso(pid, codigoDescartado);
            }

            if (teniaReserva) {
                try {
                    // posix_spawnp devuelve el error de lanzamiento
                    // mediante una excepción. ENOENT corresponde a 127.
                    const string mensaje = e.what();

                    int codigoSalida =
                        mensaje.find("No such file or directory") !=
                        string::npos
                        ? 127
                        : -1;

                    registrarFallo(
                        trabajo.id,
                        codigoSalida,
                        mensaje
                    );
                } catch (...) {
                    // No terminar el trabajador por un error
                    // al guardar el resultado.
                }
            }

            sleep_for(milliseconds(200));
            continue;

        } catch (...) {
            const bool teniaReserva = trabajo.id != 0;
            bloqueoArranque.unlock();

            if (pid > 0 && !procesoRegistrado) {
                kill(pid, SIGKILL);

                int codigoDescartado = -1;
                esperarProceso(pid, codigoDescartado);
            }

            if (teniaReserva) {
                try {
                    registrarFallo(
                        trabajo.id,
                        -1,
                        "Error interno desconocido del scheduler"
                    );
                } catch (...) {
                    // No terminar el trabajador por un error
                    // al guardar el resultado.
                }
            }

            sleep_for(milliseconds(200));
            continue;
        }

        try {
            // Consumir stderr evita que el proceso se bloquee
            // si escribe demasiado en el pipe.
            char buffer[512];

            while (true) {
                ssize_t n = read(
                    pipeStderr,
                    buffer,
                    sizeof(buffer)
                );

                if (n == 0) {
                    break;
                }

                if (n < 0) {
                    if (errno == EINTR) {
                        continue;
                    }

                    break;
                }
            }

            close(pipeStderr);

            int codigoSalida = -1;
            bool valido = esperarProceso(pid, codigoSalida);

            const bool interrumpido =
                desregistrarTrabajoActivo(trabajo.id);

            procesoRegistrado = false;

            if (interrumpido) {
                // El coordinador de apagado es el único escritor del estado
                // INTERRUPTED: el worker solo recoge al hijo y sale.
                return;
            }

            finalizarTrabajo(
                trabajo.id,
                codigoSalida,
                valido
            );

        } catch (const exception& e) {
            if (procesoRegistrado) {
                // El hijo seguía bajo supervisión cuando falló la lectura o
                // la espera: se termina, se recoge y se retira del registro
                // antes de reportar el fallo.
                kill(pid, SIGKILL);

                int codigoDescartado = -1;
                esperarProceso(pid, codigoDescartado);

                desregistrarTrabajoActivo(trabajo.id);
                procesoRegistrado = false;
            }

            if (trabajo.id != 0) {
                try {
                    // posix_spawnp devuelve el error de lanzamiento
                    // mediante una excepción. ENOENT corresponde a 127.
                    const string mensaje = e.what();

                    int codigoSalida =
                        mensaje.find("No such file or directory") !=
                        string::npos
                        ? 127
                        : -1;

                    registrarFallo(
                        trabajo.id,
                        codigoSalida,
                        mensaje
                    );
                } catch (...) {
                    // No terminar el trabajador por un error
                    // al guardar el resultado.
                }
            }

            sleep_for(milliseconds(200));

        } catch (...) {
            if (procesoRegistrado) {
                kill(pid, SIGKILL);

                int codigoDescartado = -1;
                esperarProceso(pid, codigoDescartado);

                desregistrarTrabajoActivo(trabajo.id);
                procesoRegistrado = false;
            }

            if (trabajo.id != 0) {
                try {
                    registrarFallo(
                        trabajo.id,
                        -1,
                        "Error interno desconocido del scheduler"
                    );
                } catch (...) {
                    // No terminar el trabajador por un error
                    // al guardar el resultado.
                }
            }

            sleep_for(milliseconds(200));
        }
    }
}

} // namespace anónimo

void ejecutarScheduler() {
    instalarHandlersDeApagado();

    // El coordinador observa el flag y, cuando llega SIGTERM/SIGINT, señaliza
    // los grupos, espera a los workers y persiste el estado final.
    std::thread coordinador(coordinarApagado);

    vector<thread> trabajadores;
    trabajadores.reserve(NUM_TRABAJADORES);

    for (int i = 0; i < NUM_TRABAJADORES; ++i) {
        trabajadores.emplace_back(trabajador);
    }

    for (auto& hilo : trabajadores) {
        hilo.join();
    }

    coordinador.join();
}

void iniciarSchedulerSiNecesario() {
    const string rutaLock =
        hermes::rutaDatos("scheduler.lock");

    int descriptor = open(
        rutaLock.c_str(),
        O_RDWR | O_CREAT | O_CLOEXEC,
        0644
    );

    if (descriptor == -1) {
        hermes::EventLog::log_event_system(hermes::EventLevel::ERROR, "Error interno del daemon", {
            {"funcion", "open"},
            {"archivo", "scheduler.lock"},
            {"errno", errno},
            {"detalle", std::strerror(errno)}
        });
        throw runtime_error(
            "No se pudo abrir scheduler.lock"
        );
    }

    // Si otro scheduler ya posee el bloqueo, no iniciar otro.
    // Tampoco se recupera: hay un daemon vivo supervisando el estado.
    if (flock(descriptor, LOCK_EX | LOCK_NB) == -1) {
        close(descriptor);
        return;
    }

    // Somos el único supervisor posible. La recuperación ocurre aquí, en el
    // proceso CLI y antes del fork, para que sea síncrona respecto al comando
    // y ningún `filter` observe filas RUNNING que ya no tienen dueño.
    try {
        hermes::verificarCapacidadDeRecuperacion();
        // Paso 3 del flujo de arranque (2.3): ningún temporal de una
        // ejecución muerta participa en la lectura ni se acumula.
        limpiarTemporalesDeJobs();
        hermes::recuperarTrabajosInterrumpidos();
    } catch (const exception& e) {
        hermes::EventLog::log_event_system(hermes::EventLevel::ERROR, "Error interno del daemon", {
            {"funcion", "arranque del scheduler"},
            {"detalle", e.what()}
        });

        flock(descriptor, LOCK_UN);
        close(descriptor);

        throw runtime_error(
            "No se pudo recuperar el estado antes de iniciar el scheduler"
        );
    }

    pid_t pid = fork();

    if (pid == -1) {
        hermes::EventLog::log_event_system(hermes::EventLevel::ERROR, "Error interno del daemon", {
            {"funcion", "fork"},
            {"errno", errno},
            {"detalle", std::strerror(errno)}
        });
        flock(descriptor, LOCK_UN);
        close(descriptor);

        throw runtime_error(
            "No se pudo iniciar el scheduler"
        );
    }

    if (pid > 0) {
        // El daemon conserva el bloqueo del archivo.
        close(descriptor);
        return;
    }

    if (setsid() == -1) {
        _exit(1);
    }

    int nulo = open("/dev/null", O_RDWR);

    if (nulo != -1) {
        dup2(nulo, STDIN_FILENO);
        dup2(nulo, STDOUT_FILENO);
        dup2(nulo, STDERR_FILENO);

        if (nulo > STDERR_FILENO) {
            close(nulo);
        }
    }

    // El descriptor de scheduler.lock permanece abierto
    // en el daemon durante la ejecución del scheduler.
    // Se abrió con O_CLOEXEC, así que los Jobs hijos no lo heredan y un
    // huérfano no puede retener el lock tras la muerte del demonio (F1).

    ejecutarScheduler();

    _exit(0);
}
