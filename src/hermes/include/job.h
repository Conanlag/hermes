#ifndef JOB_H
#define JOB_H

#include <string>
#include <vector>

#include "status.h"

using std::string;
using std::vector;

struct Job {

    unsigned int job_id;

    int pid;

    string programa;

    vector<string> argumentos;

    Status status;

    std::string tiempo_recepcion;
    std::string tiempo_inicio;
    std::string tiempo_terminacion;

    int codigoSalida;
    std::string mensajeError;
    bool solicitudDuplicada = false;
    std::string request_id; // RNF-22: correlación solicitud-trabajo-logs
};


Job crearJob(
    const string& programa,
    const vector<string>& argumentos,
    const string& requestId = ""
);




bool marcarCancelacionSolicitada(
    unsigned int jobId
);


bool obtenerJobPorId(
    unsigned int jobId,
    Job& jobOut
);

#endif