#include "job.h"

#include <fstream>
#include <iostream>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <nlohmann/json.hpp>

using std::ifstream;
using std::ofstream;
using std::cerr;
using json = nlohmann::json;


Job crearJob(
    const string& programa,
    const vector<string>& argumentos
) {
    // ### Generar un ID por cada job creado ###

    const string archivoJobs = "data/jobs.json";

    json jobs = json::array();

    // Leer los jobs existentes
    ifstream archivoLectura(archivoJobs);

    if (archivoLectura.is_open()) {
        try {
            archivoLectura >> jobs;
        } catch (const json::parse_error&) {
            jobs = json::array();
        }

        archivoLectura.close();
    }

    // ### Buscar el siguiente job_id ###

    unsigned int siguienteId = 1;

    for (const auto& job : jobs) {
        if (job.contains("job_id") &&
            job["job_id"].is_number_unsigned()) {

            unsigned int id = job["job_id"];

            if (id >= siguienteId) {
                siguienteId = id + 1;
            }
        }
    }

    // ### Crear el proceso real ###

    pid_t pid = fork();

    if (pid < 0) {
        throw std::runtime_error("No se pudo crear el proceso");
    }

    // -------------------------------------------------
    // PROCESO HIJO
    // -------------------------------------------------

    if (pid == 0) {

        // Crear arreglo de argumentos para execvp()
        vector<char*> argumentosExec;

        argumentosExec.push_back(
            const_cast<char*>(programa.c_str())
        );

        for (const auto& argumento : argumentos) {
            argumentosExec.push_back(
                const_cast<char*>(argumento.c_str())
            );
        }

        // execvp necesita terminar el arreglo con nullptr
        argumentosExec.push_back(nullptr);

        // Ejecutar el programa real
        execvp(
            programa.c_str(),
            argumentosExec.data()
        );

        // Si execvp regresa, significa que ocurrió un error
        cerr << "Error: no se pudo ejecutar el programa: "
             << programa
             << std::endl;

        _exit(127);
    }

    // -------------------------------------------------
    // PROCESO PADRE
    // -------------------------------------------------

    Job job;

    job.job_id = siguienteId;
    job.pid = pid;
    job.programa = programa;
    job.argumentos = argumentos;

    // El proceso ya fue creado y está ejecutándose
    job.status = Status::RUNNING;


    // ### Crear representación JSON ###

    json nuevoJob;

    nuevoJob["job_id"] = job.job_id;
    nuevoJob["pid"] = job.pid;
    nuevoJob["programa"] = job.programa;
    nuevoJob["argumentos"] = job.argumentos;
    nuevoJob["status"] = statusToString(job.status);

    jobs.push_back(nuevoJob);


    // ### Guardar jobs.json ###

    ofstream archivoEscritura(archivoJobs);

    if (archivoEscritura.is_open()) {
        archivoEscritura << jobs.dump(4);
        archivoEscritura.close();
    }

    return job;
}