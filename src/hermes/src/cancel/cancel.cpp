#include "cancel.h"

#include "storage.h"
#include "process.h"
#include "timestamp.h"

#include <string>

ResultadoCancelacion cancelarJobDetallado(unsigned int jobId) {
    bool encontrado = false;
    bool canceladoEnCola = false;
    bool solicitudRegistrada = false;
    int pid = 0;
    std::string estado;

    try {
        modificarJobsSeguros([&](json& jobs) {
            for (auto& item : jobs) {
                if (!item.contains("job_id") ||
                    item["job_id"] != jobId) {
                    continue;
                }

                encontrado = true;
                estado = item.value("status", std::string{});

                if (estado == "QUEUED") {
                    item["status"] = "CANCELED";
                    item["codigo_salida"] = -1;
                    item["tiempo_terminacion"] =
                        obtenerFechaHoraActual();

                    canceladoEnCola = true;
                    return true;
                }

                if (estado == "RUNNING") {
                    item["cancel_requested"] = true;
                    pid = item.value("pid", 0);
                    solicitudRegistrada = true;
                    return true;
                }

                return false;
            }

            return false;
        });
    } catch (const std::exception& e) {
        return {
            false,
            CodigoCancelacion::ERROR_LECTURA,
            e.what()
        };
    }

    if (!encontrado) {
        return {
            false,
            CodigoCancelacion::NO_EXISTE,
            "No existe el Job."
        };
    }

    if (canceladoEnCola) {
        return {
            true,
            CodigoCancelacion::CANCELADO,
            ""
        };
    }

    if (solicitudRegistrada) {
        // PID 0 significa que el trabajador todavía no ha guardado
        // el PID. El scheduler detectará la solicitud al guardarlo.
        if (pid > 0) {
            // Si el proceso terminó justo antes de la señal,
            // el scheduler actualizará el estado definitivo.
            terminarProceso(pid);
        }

        return {
            true,
            CodigoCancelacion::SOLICITUD_REGISTRADA,
            ""
        };
    }

    return {
        false,
        CodigoCancelacion::NO_CANCELABLE,
        "El Job no se puede cancelar (estado: " +
            estado + "). Solo QUEUED o RUNNING."
    };
}

bool cancelarJob(unsigned int jobId) {
    return cancelarJobDetallado(jobId).exito;
}