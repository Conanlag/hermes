#include "job.h"

#include "process.h"

#include <fstream>
#include <iostream>
#include <stdexcept>

#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/file.h>

#include <nlohmann/json.hpp>

using std::ifstream;
using std::ofstream;
using std::runtime_error;

using json = nlohmann::json;


namespace {

const string archivoJobs = "data/jobs.json";


json leerJobs() {

    json jobs = json::array();

    ifstream archivo(archivoJobs);

    if (!archivo.is_open()) {
        return jobs;
    }

    try {

        archivo >> jobs;

        if (!jobs.is_array()) {
            jobs = json::array();
        }

    } catch (const json::parse_error&) {

        jobs = json::array();
    }

    return jobs;
}


bool guardarJobs(const json& jobs) {

    ofstream archivo(archivoJobs);

    if (!archivo.is_open()) {
        return false;
    }

    archivo << jobs.dump(4);

    return archivo.good();
}


/*
 * Ejecuta una función mientras mantiene bloqueado jobs.json.
 *
 * Esto evita que dos procesos supervisores modifiquen
 * simultáneamente el archivo y se pisen los cambios.
 */
template <typename Funcion>
bool modificarJobs(Funcion funcion) {

    int descriptor = open(
        archivoJobs.c_str(),
        O_RDWR | O_CREAT,
        0644
    );

    if (descriptor == -1) {
        return false;
    }

    if (flock(descriptor, LOCK_EX) == -1) {

        close(descriptor);

        return false;
    }

    json jobs = leerJobs();

    bool resultado = funcion(jobs);

    if (resultado) {

        ofstream archivo(archivoJobs);

        if (!archivo.is_open()) {

            flock(descriptor, LOCK_UN);
            close(descriptor);

            return false;
        }

        archivo << jobs.dump(4);

        resultado = archivo.good();
    }

    flock(descriptor, LOCK_UN);

    close(descriptor);

    return resultado;
}


unsigned int obtenerSiguienteId(const json& jobs) {

    unsigned int siguienteId = 1;

    for (const auto& job : jobs) {

        if (
            job.contains("job_id") &&
            job["job_id"].is_number_unsigned()
        ) {

            unsigned int id = job["job_id"];

            if (id >= siguienteId) {
                siguienteId = id + 1;
            }
        }
    }

    return siguienteId;
}


/*
 * Actualiza un Job cuando termina el proceso.
 */
void supervisarJob(
    unsigned int jobId,
    const string& programa,
    const vector<string>& argumentos,
    int pipeEscritura
) {

    try {

        /*
         * El Job inicialmente está QUEUED.
         *
         * Ahora se crea el proceso real.
         */
        pid_t pid = iniciarProceso(
            programa,
            argumentos
        );

        /*
         * Mandamos el PID al proceso padre de Hermes.
         */
        write(
            pipeEscritura,
            &pid,
            sizeof(pid)
        );

        close(pipeEscritura);


        /*
         * El proceso ya existe y está ejecutándose.
         */
        actualizarEstadoJob(
            jobId,
            Status::RUNNING
        );


        /*
         * Esperamos al proceso real.
         */
        int codigoSalida = 0;

        bool procesoTermino = esperarProceso(
            pid,
            codigoSalida
        );

        if (!procesoTermino) {

            actualizarResultadoJob(
                jobId,
                Status::FAILED,
                -1
            );

            _exit(1);
        }


        /*
         * Revisamos si se solicitó una cancelación.
         */
        json jobs = leerJobs();

        bool cancelacionSolicitada = false;

        for (const auto& job : jobs) {

            if (
                job.contains("job_id") &&
                job["job_id"] == jobId
            ) {

                if (
                    job.contains("cancel_requested") &&
                    job["cancel_requested"].is_boolean()
                ) {

                    cancelacionSolicitada =
                        job["cancel_requested"];
                }

                break;
            }
        }


        if (cancelacionSolicitada) {

            actualizarResultadoJob(
                jobId,
                Status::CANCELED,
                codigoSalida
            );

        } else if (codigoSalida == 0) {

            actualizarResultadoJob(
                jobId,
                Status::SUCCEEDED,
                codigoSalida
            );

        } else {

            actualizarResultadoJob(
                jobId,
                Status::FAILED,
                codigoSalida
            );
        }

    } catch (...) {

        close(pipeEscritura);

        actualizarResultadoJob(
            jobId,
            Status::FAILED,
            -1
        );

        _exit(1);
    }

    _exit(0);
}

} // namespace


Job crearJob(
    const string& programa,
    const vector<string>& argumentos
) {

    /*
     * ---------------------------------------------
     * 1. Leer jobs existentes
     * ---------------------------------------------
     */

    json jobs = leerJobs();


    /*
     * ---------------------------------------------
     * 2. Generar ID
     * ---------------------------------------------
     */

    unsigned int siguienteId =
        obtenerSiguienteId(jobs);


    /*
     * ---------------------------------------------
     * 3. Crear representación inicial
     * ---------------------------------------------
     */

    Job job;

    job.job_id = siguienteId;

    /*
     * PID todavía no existe.
     */
    job.pid = 0;

    job.programa = programa;

    job.argumentos = argumentos;

    /*
     * El Job nace en QUEUED.
     */
    job.status = Status::QUEUED;

    job.codigoSalida = -1;


    /*
     * ---------------------------------------------
     * 4. Guardar QUEUED
     * ---------------------------------------------
     */

    json nuevoJob;

    nuevoJob["job_id"] =
        job.job_id;

    nuevoJob["pid"] =
        job.pid;

    nuevoJob["programa"] =
        job.programa;

    nuevoJob["argumentos"] =
        job.argumentos;

    nuevoJob["status"] =
        statusToString(job.status);

    nuevoJob["codigo_salida"] =
        job.codigoSalida;

    nuevoJob["cancel_requested"] =
        false;


    jobs.push_back(nuevoJob);


    if (!guardarJobs(jobs)) {

        throw runtime_error(
            "No se pudo guardar jobs.json"
        );
    }


    /*
     * ---------------------------------------------
     * 5. Crear pipe
     *
     * El supervisor nos enviará el PID real.
     * ---------------------------------------------
     */

    int pipefd[2];

    if (pipe(pipefd) == -1) {

        throw runtime_error(
            "No se pudo crear el pipe"
        );
    }


    /*
     * ---------------------------------------------
     * 6. Crear supervisor
     * ---------------------------------------------
     */

    pid_t supervisor = fork();

    if (supervisor < 0) {

        close(pipefd[0]);
        close(pipefd[1]);

        throw runtime_error(
            "No se pudo crear el supervisor"
        );
    }


    /*
     * ---------------------------------------------
     * SUPERVISOR
     * ---------------------------------------------
     */

    if (supervisor == 0) {

        close(pipefd[0]);

        supervisarJob(
            job.job_id,
            programa,
            argumentos,
            pipefd[1]
        );
    }


    /*
     * ---------------------------------------------
     * PROCESO PADRE DE HERMES
     * ---------------------------------------------
     */

    close(pipefd[1]);


    /*
     * Esperamos recibir el PID del proceso real.
     */
    pid_t pidReal = 0;

    ssize_t bytesLeidos = read(
        pipefd[0],
        &pidReal,
        sizeof(pidReal)
    );

    close(pipefd[0]);


    if (
        bytesLeidos != sizeof(pidReal) ||
        pidReal <= 0
    ) {

        throw runtime_error(
            "No se pudo obtener el PID del proceso"
        );
    }


    /*
     * Actualizamos el PID que verá el usuario.
     */
    job.pid = pidReal;


    /*
     * Importante:
     *
     * El supervisor ya pudo haber terminado
     * si el programa era extremadamente corto.
     *
     * Aun así, jobs.json tendrá el estado final
     * correspondiente.
     */
    modificarJobs(
        [&](json& jobsActualizados) {

            for (auto& item : jobsActualizados) {

                if (
                    item.contains("job_id") &&
                    item["job_id"] == job.job_id
                ) {

                    item["pid"] =
                        static_cast<int>(pidReal);

                    return true;
                }
            }

            return false;
        }
    );


    return job;
}


bool actualizarEstadoJob(
    unsigned int jobId,
    Status nuevoEstado
) {

    return modificarJobs(
        [&](json& jobs) {

            for (auto& job : jobs) {

                if (
                    job.contains("job_id") &&
                    job["job_id"] == jobId
                ) {

                    job["status"] =
                        statusToString(nuevoEstado);

                    return true;
                }
            }

            return false;
        }
    );
}


bool actualizarResultadoJob(
    unsigned int jobId,
    Status nuevoEstado,
    int codigoSalida
) {

    return modificarJobs(
        [&](json& jobs) {

            for (auto& job : jobs) {

                if (
                    job.contains("job_id") &&
                    job["job_id"] == jobId
                ) {

                    job["status"] =
                        statusToString(nuevoEstado);

                    job["codigo_salida"] =
                        codigoSalida;

                    return true;
                }
            }

            return false;
        }
    );
}


bool marcarCancelacionSolicitada(
    unsigned int jobId
) {

    return modificarJobs(
        [&](json& jobs) {

            for (auto& job : jobs) {

                if (
                    job.contains("job_id") &&
                    job["job_id"] == jobId
                ) {

                    /*
                     * Solo permitimos cancelar Jobs
                     * que estén actualmente ejecutándose.
                     */
                    if (
                        !job.contains("status") ||
                        job["status"] != "RUNNING"
                    ) {
                        return false;
                    }

                    job["cancel_requested"] = true;

                    return true;
                }
            }

            return false;
        }
    );
}