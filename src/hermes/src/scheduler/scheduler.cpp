#include "scheduler.h"

#include "job.h"
#include "process.h"
#include "storage.h"
#include "timestamp.h"
#include "data_paths.h"

#include <chrono>
#include <cerrno>
#include <thread>
#include <vector>
#include <string>
#include <stdexcept>
#include <exception>

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
    vector<std::string> argumentos;
};

bool reservarTrabajo(TrabajoPendiente& trabajo) {
    bool reservado = false;

    modificarJobsSeguros([&](json& jobs) {
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

            trabajo.id = item["job_id"].get<unsigned int>();
            trabajo.programa =
                item["programa"].get<string>();

            trabajo.argumentos.clear();

            for (const auto& argumento : item["argumentos"]) {
                if (argumento.is_string()) {
                    trabajo.argumentos.push_back(
                        argumento.get<string>()
                    );
                }
            }

            item["status"] = "RUNNING";
            item["pid"] = 0;
            item["tiempo_inicio"] = obtenerFechaHoraActual();

            reservado = true;
            return true;
        }

        return false;
    });

    return reservado;
}

void guardarPid(unsigned int id, pid_t pid) {
    bool cancelar = false;

    modificarJobsSeguros([&](json& jobs) {
        for (auto& item : jobs) {
            if (!item.contains("job_id") ||
                item["job_id"] != id) {
                continue;
            }

            if (item["status"] != "RUNNING") {
                return false;
            }

            item["pid"] = static_cast<int>(pid);

            cancelar =
                item.contains("cancel_requested") &&
                item["cancel_requested"].is_boolean() &&
                item["cancel_requested"].get<bool>();

            return true;
        }

        return false;
    });

    // Si se pidió cancelar antes de guardar el PID,
    // terminar el proceso cuando su PID esté disponible.
    if (cancelar) {
        terminarProceso(pid);
    }
}

void finalizarTrabajo(
    unsigned int id,
    int codigoSalida,
    bool procesoValido
) {
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
            } else if (procesoValido && codigoSalida == 0) {
                item["status"] = "SUCCEEDED";
            } else {
                item["status"] = "FAILED";
            }

            item["codigo_salida"] = codigoSalida;
            item["tiempo_terminacion"] =
                obtenerFechaHoraActual();

            return true;
        }

        return false;
    });
}

void registrarFallo(
    unsigned int id,
    int codigoSalida,
    const string& mensaje
) {
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

            item["status"] = cancelar ? "CANCELED" : "FAILED";
            item["codigo_salida"] = codigoSalida;
            item["mensaje_error"] = mensaje;
            item["tiempo_terminacion"] =
                obtenerFechaHoraActual();

            return true;
        }

        return false;
    });
}

void trabajador() {
    while (true) {
        TrabajoPendiente trabajo;

        try {
            if (!reservarTrabajo(trabajo)) {
                sleep_for(
                    milliseconds(200)
                );
                continue;
            }

            int pipeStderr = -1;

            pid_t pid = iniciarProceso(
                trabajo.programa,
                trabajo.argumentos,
                pipeStderr
            );

            guardarPid(trabajo.id, pid);

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

            finalizarTrabajo(
                trabajo.id,
                codigoSalida,
                valido
            );

        } catch (const exception& e) {
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

            sleep_for(
            milliseconds(200)
            );

        } catch (...) {
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

            sleep_for(
                milliseconds(200)
            );
        }
    }
}

} // namespace anónimo

void ejecutarScheduler() {
    vector<thread> trabajadores;
    trabajadores.reserve(NUM_TRABAJADORES);

    for (int i = 0; i < NUM_TRABAJADORES; ++i) {
        trabajadores.emplace_back(trabajador);
    }

    for (auto& hilo : trabajadores) {
        hilo.join();
    }
}

void iniciarSchedulerSiNecesario() {
    const string rutaLock =
        hermes::rutaDatos("scheduler.lock");

    int descriptor = open(
        rutaLock.c_str(),
        O_RDWR | O_CREAT,
        0644
    );

    if (descriptor == -1) {
        throw runtime_error(
            "No se pudo abrir scheduler.lock"
        );
    }

    // Si otro scheduler ya posee el bloqueo, no iniciar otro.
    if (flock(descriptor, LOCK_EX | LOCK_NB) == -1) {
        close(descriptor);
        return;
    }

    pid_t pid = fork();

    if (pid == -1) {
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
    ejecutarScheduler();

    _exit(0);
}
