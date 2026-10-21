
#include "clean.h"
#include "storage.h"
#include "terminal.colors.h"

#include <string>

using namespace std;

int limpiarDatos() {
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
