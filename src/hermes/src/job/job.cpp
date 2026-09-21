#include "job.h"
#include <fstream>
#include <nlohmann/json.hpp>

using std::ifstream;
using std::ofstream;
using json = nlohmann::json;


Job crearJob(
    const string& programa,
    const vector<string>& argumentos
){
    // Generar un ID por cada job creado
    const string archivoJobs = "data/jobs.json";

    json jobs = json::array();

    // Leer el anterior Id Desde el archivo
        ifstream archivoLectura(archivoJobs);

    if (archivoLectura.is_open()) {
        try {
            archivoLectura >> jobs;
        } catch (const json::parse_error&) {
            jobs = json::array();
        }
        archivoLectura.close();
    }
    // Buscar el siguiente job_id
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

    // Crear el job 
    Job job;
    job.job_id = siguienteId;
    job.programa = programa;
    job.argumentos = argumentos;
    job.status = Status::QUEUED;    


    // Crear representación JSON del nuevo job
    json nuevoJob;

    nuevoJob["job_id"] = job.job_id;
    nuevoJob["programa"] = job.programa;
    nuevoJob["argumentos"] = job.argumentos;
    nuevoJob["status"] = statusToString(job.status);

    // Agregarlo al arreglo
    jobs.push_back(nuevoJob);

    // Guardar el archivo JSON
    ofstream archivoEscritura(archivoJobs);

    if (archivoEscritura.is_open()) {
        archivoEscritura << jobs.dump(4);
        archivoEscritura.close();
    }

    return job;
}