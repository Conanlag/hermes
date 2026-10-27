
#include "clean.h"
#include "storage.h"
#include "data_paths.h"
#include "recovery.h"
#include "terminal.colors.h"

#include <exception>
#include <string>

#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>

using namespace std;

namespace {

// Mantiene `scheduler.lock` durante toda la limpieza cuando no hay un daemon.
//
// No basta con recuperar y soltar: un daemon podría arrancar entre la
// recuperación y el borrado. Con el lock tomado hasta el final, la operación
// ve un estado estable. Si ya hay un daemon, no se recupera: sus Jobs RUNNING
// están vivos y la limpieza debe rechazarse.
class BloqueoScheduler {
public:
    BloqueoScheduler() {
        const string ruta = hermes::rutaDatos("scheduler.lock");

        descriptor = open(
            ruta.c_str(),
            O_RDWR | O_CREAT | O_CLOEXEC,
            0644
        );

        if (descriptor == -1) {
            return;
        }

        unicoSupervisor = flock(descriptor, LOCK_EX | LOCK_NB) == 0;
    }

    ~BloqueoScheduler() {
        if (descriptor == -1) {
            return;
        }

        if (unicoSupervisor) {
            flock(descriptor, LOCK_UN);
        }

        close(descriptor);
    }

    bool abierto() const {
        return descriptor != -1;
    }

    bool sinDaemon() const {
        return unicoSupervisor;
    }

private:
    int descriptor = -1;
    bool unicoSupervisor = false;
};

} // namespace anónimo

int limpiarDatos() {
    BloqueoScheduler bloqueo;

    if (!bloqueo.abierto()) {
        error("No se pudo abrir scheduler.lock.");
        return 1;
    }

    if (bloqueo.sinDaemon()) {
        // F12: `clean data` se ejecuta antes de iniciar el scheduler, así que
        // sin este paso nadie reconciliaría las filas RUNNING de una caída y
        // el comando quedaría bloqueado para siempre. La recuperación es la
        // misma del arranque, bajo el lock que acabamos de tomar.
        try {
            hermes::verificarCapacidadDeRecuperacion();
            limpiarTemporalesDeJobs();
            hermes::recuperarTrabajosInterrumpidos();
        } catch (const exception& e) {
            error(
                "No se pudo recuperar el estado antes de limpiar: ",
                e.what()
            );
            return 1;
        }
    }

    bool hayTrabajosActivos = false;

    try {
        bool resultado = modificarJobsSeguros(
            [&](json& jobs) {
                // No limpiar si existen trabajos pendientes o ejecutándose.
                for (const auto& job : jobs) {
                    string status =
                        job.value("status", std::string{});

                    if (status == "QUEUED" || status == "RUNNING") {
                        hayTrabajosActivos = true;
                        return true;
                    }
                }

                // Mantener el archivo y reiniciar el historial.
                jobs = json::array();
                return true;
            }
        );

        if (hayTrabajosActivos) {
            error(
                "No se pueden limpiar los datos: "
                "hay trabajos pendientes o en ejecución."
            );
            return 1;
        }

        if (!resultado) {
            error("No se pudo limpiar el historial de trabajos.");
            return 1;
        }

        info("Historial de trabajos limpiado correctamente.");
        return 0;

    } catch (const exception& e) {
        error("Error al limpiar los datos: ", e.what());
        return 1;
    }
}
