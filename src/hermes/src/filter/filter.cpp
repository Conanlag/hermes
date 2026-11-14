#include "filter.h"
#include "job.h"
#include "job_presentation.h"
#include "status.h"
#include "storage.h"

#include <iostream>
#include <nlohmann/json.hpp>
#include "terminal.colors.h"

using std::cout;
using std::endl;
using json = nlohmann::json;

// ### Filtro por Id ###
void filtrarPorId(unsigned int job_id){
    // Separación de responsabilidades: job provee el dato, filter presenta.
    Job job;

    if (!obtenerJobPorId(job_id, job)) {
        error("No se encontró el Job ID: ", job_id);
        return;
    }

    mostrarDetalleJob(job);
}

// ### Filtro por Status ###

void filtrarPorStatus(const string& status){
    json jobs;

    try {
        jobs = leerJobsSeguros();
    } catch (const std::exception& e) {
        error("Error al leer jobs: ", e.what());
        return;
    }

    bool encontrado = false;

    for (const auto& job : jobs) {
        // Recuperar informacion

        if (job.contains("status") &&
            job["status"].is_string() &&
            job["status"] == status) {

            mostrarResumenJob(job);

            encontrado = true;
        }
    }

    if (!encontrado) {
        error("No se encontraron Jobs con estado: ", status);
    }

}

// ### Filtro por programa ###

void filtrarPorPrograma(const string& programa){
    json jobs;

    try {
        jobs = leerJobsSeguros();
    } catch (const std::exception& e) {
        error("Error al leer jobs: ", e.what());
        return;
    }

    bool encontrado = false;

    for (const auto& job : jobs) {
        // Recuperar informacion

        if (job.contains("programa") &&
            job["programa"].is_string() &&
            job["programa"] == programa) {

            mostrarResumenJob(job);

            encontrado = true;
        }
    }

    if (!encontrado) {
        error("No se encontraron Jobs con el programa indicado: ", programa);
    }

}