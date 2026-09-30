#include "job.h"
#include <fstream>
#include <nlohmann/json.hpp>

using std::ifstream;
using std::ofstream;
using json = nlohmann::json;

std::string obtenerFechaHoraActual() {
    auto now = std::chrono::system_clock::now();
    std::time_t now_c = std::chrono::system_clock::to_time_t(now);
    std::stringstream ss;
    ss << std::put_time(std::localtime(&now_c), "%Y-%m-%d %H:%M:%S");
    return ss.str();
}

Job crearJob(
    const string& programa,
    const vector<string>& argumentos
){
    // ### Generar un ID por cada job creado ###

    const string archivoJobs = "data/jobs.json"; // Ruta donde se lee el json con datos de jobs

    // Bloquear la escritura del archivo
    // Espera si otro proceso está leyendo/escribiendo
    int fd_candado = open("data/jobs.lock", O_CREAT | O_RDWR, 0666);
    if (fd_candado != -1) {
        flock(fd_candado, LOCK_EX);
    }


    json jobs = json::array(); // Creamos un arreglo json vacio en la RAM

    // Leer el anterior ID Desde el archivo
        ifstream archivoLectura(archivoJobs); // intenta abrir data/jobs.json para leerlo

    if (archivoLectura.is_open()) {
        try {
            archivoLectura >> jobs; // Leer el texto del archivo y lo inyecta en jobs
        } catch (const json::parse_error&) { // Si falla porque el contenido es invalido, inicializalo vacio de nuevo
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

    // ### Crear el job ###
    Job job;
    job.job_id = siguienteId;
    job.programa = programa;
    job.argumentos = argumentos;
    job.status = Status::QUEUED;
    // Guardar la fecha/hora en la que se crea/recibe el job
    job.tiempo_recepcion = obtenerFechaHoraActual();
    // Estos campos se llenarán más adelante por otro proceso
    job.tiempo_inicio = "";
    job.tiempo_terminacion = "";


    // ### Crear representación JSON del nuevo job ###
    json nuevoJob;

    nuevoJob["job_id"] = job.job_id;
    nuevoJob["programa"] = job.programa;
    nuevoJob["argumentos"] = job.argumentos;
    nuevoJob["status"] = statusToString(job.status);
    nuevoJob["tiempo_recepcion"] = job.tiempo_recepcion;
    nuevoJob["tiempo_inicio"] = job.tiempo_inicio;
    nuevoJob["tiempo_terminacion"] = job.tiempo_terminacion;

    // Agregarlo al arreglo
    jobs.push_back(nuevoJob);

    // ### Guardar el archivo JSON ###
    ofstream archivoEscritura(archivoJobs); // Si no existe, lo crea

    if (archivoEscritura.is_open()) {
        archivoEscritura << jobs.dump(4); // Traducir la estructura json de la libreria a un string
        archivoEscritura.close();
    }
    
    // Liberar el bloqueo del archivo
    if (fd_candado != -1) {
        flock(fd_candado, LOCK_UN);
        close(fd_candado);
    }

    return job;
}