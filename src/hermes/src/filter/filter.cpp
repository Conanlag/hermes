#include "filter.h"
#include "job.h"
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

    cout << "Job ID: "
         << job.job_id << endl;

    cout << "PID: "
         << job.pid << endl;

    cout << "Programa: "
         << job.programa << endl;

    cout << "Estado: "
         << statusToString(job.status) << endl;

    cout << "Codigo de salida: "
         << job.codigoSalida << endl;

    cout << "Recepcion: "
         << job.tiempo_recepcion << endl;

    cout << "Inicio: "
         << job.tiempo_inicio << endl;

    cout << "Terminacion: "
         << job.tiempo_terminacion << endl;

    cout << "Argumentos: ";

    for (const auto& argumento : job.argumentos) {
        cout << argumento << " ";
    }

    cout << endl;
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

            cout << "Job ID: ";
            if (job.contains("job_id")) {
                cout << job["job_id"];
            } else {
                cout << "N/A";
            }
            cout << endl;

            cout << "Programa: ";
            if (job.contains("programa")) {
                cout << job["programa"];
            } else {
                cout << "N/A";
            }
            cout << endl;

            cout << "PID: ";
            if (job.contains("pid")) {
                cout << job["pid"];
            } else {
                cout << 0;
            }
            cout << endl;

            cout << "Estado: ";
            if (job.contains("status")) {
                cout << job["status"];
            } else {
                cout << "QUEUED";
            }
            cout << endl;

            cout << "Argumentos: ";

            if (job.contains("argumentos") &&
                job["argumentos"].is_array()) {

                for (const auto& argumento : job["argumentos"]) {
                    cout << argumento << " ";
                }
            }

            cout << endl;
            cout << "------------------------" << endl;

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

            cout << "Job ID: ";
            if (job.contains("job_id")) {
                cout << job["job_id"];
            } else {
                cout << "N/A";
            }
            cout << endl;

            cout << "Programa: ";
            if (job.contains("programa")) {
                cout << job["programa"];
            } else {
                cout << "N/A";
            }
            cout << endl;

            cout << "PID: ";
            if (job.contains("pid")) {
                cout << job["pid"];
            } else {
                cout << 0;
            }
            cout << endl;

            cout << "Estado: ";
            if (job.contains("status")) {
                cout << job["status"];
            } else {
                cout << "QUEUED";
            }
            cout << endl;

            cout << "Argumentos: ";

            if (job.contains("argumentos") &&
                job["argumentos"].is_array()) {

                for (const auto& argumento : job["argumentos"]) {
                    cout << argumento << " ";
                }
            }

            cout << endl;
            cout << "------------------------" << endl;

            encontrado = true;
        }
    }

    if (!encontrado) {
        error("No se encontraron Jobs con el programa indicado: ", programa);
    }

}