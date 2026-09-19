#include "job.h"

Job crearJob(
    const string& programa,
    const vector<string>& argumentos
){
    static unsigned int siguienteId = 1;
    Job job;
    job.id = siguienteId++;
    job.programa = programa;
    job.argumentos = argumentos;

    return job;
}