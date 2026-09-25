#include "filter.h"

#include <fstream>
#include <iostream>
#include <nlohmann/json.hpp>
#include "terminal.colors.h"

using std::ifstream;
using std::cout;
using std::endl;
using json = nlohmann::json;

const string archivoJobs = "data/jobs.json";


//Filtro por Id
void filtrarPorId(unsigned int job_id){
    json jobs = json::array();

    ifstream archivoLectura(archivoJobs);

    //buscar archivo
    if(!archivoLectura.is_open()){
        error("No se puede abrir: ", archivoJobs);
        return;
    }

    //leer archivo
    try{
        archivoLectura >> jobs;
    } catch(const json::parse_error&) {
        error("Error al leer: ", archivoJobs);

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

                //Recuperar informacion del job
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
            error("No se encontró el Job ID: ", job_id);
        }

}

//Filtro por Status

void filtrarPorStatus(const string& status){
    json jobs = json::array();
    
    ifstream archivoLectura(archivoJobs);
    
    //buscar archivo 
    if (!archivoLectura.is_open()) {
        cout << "No se pudo abrir " << archivoJobs << endl;
        error("No se puede abrir: ", archivoJobs);
        return;
    }

    //leer archivo
    try {
        archivoLectura >> jobs;
    } catch (const json::parse_error&) {
        cout << "Error al leer " << archivoJobs << endl;
        error("Error al leer: ", archivoJobs);

        archivoLectura.close();
        return;
    }

    archivoLectura.close();

    bool encontrado = false;

    for (const auto& job : jobs) {
        //Recuperar informacion

        if (job.contains("status") &&
            job["status"].is_string() &&
            job["status"] == status) {

            cout << "Job ID: "
                 << job["job_id"] << endl;

            cout << "Programa: "
                 << job["programa"] << endl;

            cout << "Estado: "
                 << job["status"] << endl;

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

//Filtro por programa

void filtrarPorPrograma(const string& programa){

     json jobs = json::array();
    
    ifstream archivoLectura(archivoJobs);
    
    //buscar archivo 
    if (!archivoLectura.is_open()) {
        error("No se pudo abrir", archivoJobs);
        return;
    }

    //leer archivo
    try {
        archivoLectura >> jobs;
    } catch (const json::parse_error&) {
        error("Error al leer: ", archivoJobs);
        archivoLectura.close();
        return;
    }

    archivoLectura.close();

    bool encontrado = false;

    for (const auto& job : jobs) {
        //Recuperar informacion

        if (job.contains("programa") &&
            job["programa"].is_string() &&
            job["programa"] == programa) {

            cout << "Job ID: "
                 << job["job_id"] << endl;

            cout << "Programa: "
                 << job["programa"] << endl;

            cout << "Estado: "
                 << job["status"] << endl;

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