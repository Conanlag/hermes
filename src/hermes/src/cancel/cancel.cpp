#include "cancel.h"

#include "job.h"
#include "process.h"

#include <fstream>

#include <nlohmann/json.hpp>

using std::ifstream;

using json = nlohmann::json;


bool cancelarJob(unsigned int jobId) {

    const string archivoJobs = "data/jobs.json";

    ifstream archivo(archivoJobs);

    if (!archivo.is_open()) {
        return false;
    }

    json jobs;

    try {

        archivo >> jobs;

    } catch (...) {

        return false;
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
             * El Job debe tener un PID válido.
             */
            if (
                !job.contains("pid") ||
                !job["pid"].is_number_integer()
            ) {

                return false;
            }


            /*
             * Solo podemos cancelar un proceso
             * que actualmente esté RUNNING.
             */
            if (
                !job.contains("status") ||
                job["status"] != "RUNNING"
            ) {

                return false;
            }


            int pid = job["pid"];


            /*
             * Registrar que se solicitó la cancelación.
             */
            if (!marcarCancelacionSolicitada(jobId)) {
                return false;
            }


            /*
             * Enviar SIGTERM al proceso real.
             */
            return terminarProceso(pid);
        }
    }

    /*
     * No se encontró el Job.
     */
    return false;
}