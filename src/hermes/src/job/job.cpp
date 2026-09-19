#include "job.h"
#include <fstream>

using std::ifstream;
using std::ofstream;

Job crearJob(
    const string& programa,
    const vector<string>& argumentos
){
    // Generar un ID por cada job creado
    const string archivoId = "data/job_id";
    
    unsigned int siguienteId = 1;

    // Leer el anterior Id Desde el archivo
        ifstream archivoLectura(archivoId);

    if (archivoLectura.is_open()) {
        archivoLectura >> siguienteId;
        archivoLectura.close();
    }

    // Crear el job 
    Job job;
    job.id = siguienteId;
    job.programa = programa;
    job.argumentos = argumentos;


    // Guardar el siguiente ID
    ofstream archivoEscritura(archivoId);

    if (archivoEscritura.is_open()) {
        archivoEscritura << siguienteId + 1;
        archivoEscritura.close();
    }

    return job;
}