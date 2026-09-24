#include "filter.h"

#include <fstream>
#include <iostream>
#include <nlohmann/json.hpp>

using std::ifstream;
using std::cout;
using std::endl;
using json = nlohmann::json;

const string archivoJobs = "data/jobs.json";

void filtrarPorId(unsigned int job_id){
    json jobs = json::array();

    ifstream archivoLectura(archivoJobs);

    if(!archivoLectura.is_open()){
        cout << "No se puede abrir" << archivoJobs << endl;
        return;
    }
    try{
        archivoLectura >> jobs;
    } catch(const json::parse_error&) {
        cout << "Error al leer" << archivoJobs << endl;
        archivoLectura.close();
        return;
    }
    archivoLectura.close();

    bool encontrado = false; 

    for (const auto& job : jobs){

        if (
            job.contains("job_id") 
            && job["job_id"].is_number_unsigned()
            && job["job_id"] == job_id
            ) {
                cout << "Job ID: "
                     << job["job_id"] << endl;

                cout << "Programa: "
                     << job["programa"] << endl;

                cout << "Estado: "
                     << job["status"] << endl;

                cout << "Argumentos: ";

                if (job.contains("argumentos") &&
                    job["argumentos"].is_array()
                ) {
                    for(const auto& argumento : job["argumentos"]){
                        cout << argumento << " ";
                    }
                }
                    cout << endl;

                    encontrado = true; 
                    break;

            }
        }
        
        if (!encontrado) {
            cout << "No se encontró el Job ID: "
                 << job_id << endl;
        }

}

