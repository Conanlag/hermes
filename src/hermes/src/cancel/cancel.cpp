#include "cancel.h"

#include "job.h"
#include "process.h"

#include <fstream>

#include <nlohmann/json.hpp>

using std::ifstream;

using json = nlohmann::json;


bool cancelarJob(unsigned int jobId) {

    return cancelarJobDetallado(jobId).exito;
}


ResultadoCancelacion cancelarJobDetallado(unsigned int jobId) {

    const string archivoJobs = "data/jobs.json";

    ifstream archivo(archivoJobs);

    if (!archivo.is_open()) {
        return {false, CodigoCancelacion::ERROR_LECTURA, "No se puede abrir: " + archivoJobs};
    }

    json jobs;

    try {

        archivo >> jobs;

    } catch (...) {

        return {false, CodigoCancelacion::ERROR_LECTURA, "Error al leer: " + archivoJobs};
    }


    /*
     * Buscar el Job solicitado.
     */
    for (const auto& job : jobs) {

        if (
            job.contains("job_id") &&
            job["job_id"] == jobId
        ) {

            /*
             * El Job debe indicar su estado.
             */
            if (
                !job.contains("status") ||
                !job["status"].is_string()
            ) {

                return {false, CodigoCancelacion::ERROR_LECTURA, "Estado ilegible para el Job."};
            }


            string estado = job["status"];


            /*
             * Job en cola: no hay proceso que matar.
             * Se marca CANCELED directo sin señal.
             */
            if (estado == "QUEUED") {

                if (
                    actualizarResultadoJob(
                        jobId,
                        Status::CANCELED,
                        -1
                    )
                ) {
                    return {true, CodigoCancelacion::CANCELADO, ""};
                }

                return {false, CodigoCancelacion::ERROR_LECTURA, "No se pudo actualizar el Job."};
            }


            /*
             * Solo los Jobs RUNNING llegan a la señal.
             */
            if (estado != "RUNNING") {

                return {false, CodigoCancelacion::NO_CANCELABLE, "El Job no se puede cancelar (estado: " + estado + "). Solo QUEUED o RUNNING."};
            }


            /*
             * El Job RUNNING debe tener un PID válido.
             */
            if (
                !job.contains("pid") ||
                (
                    !job["pid"].is_number_integer() &&
                    !job["pid"].is_number_unsigned()
                )
            ) {

                return {false, CodigoCancelacion::ERROR_LECTURA, "PID ilegible para el Job."};
            }


            int pid = job["pid"];


            /*
             * Registrar que se solicitó la cancelación.
             */
            if (!marcarCancelacionSolicitada(jobId)) {
                return {false, CodigoCancelacion::ERROR_LECTURA, "No se pudo registrar la cancelación."};
            }


            /*
             * Enviar SIGTERM al proceso real.
             */
            if (terminarProceso(pid)) {
                return {true, CodigoCancelacion::SOLICITUD_REGISTRADA, ""};
            }

            return {false, CodigoCancelacion::ERROR_LECTURA, "No se pudo enviar la señal al proceso."};
        }
    }

    /*
     * No se encontró el Job.
     */
    return {false, CodigoCancelacion::NO_EXISTE, "No existe el Job."};
}