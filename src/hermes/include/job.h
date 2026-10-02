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
};


Job crearJob(
    const string& programa,
    const vector<string>& argumentos
);


bool actualizarEstadoJob(
    unsigned int jobId,
    Status nuevoEstado
);


bool actualizarResultadoJob(
    unsigned int jobId,
    Status nuevoEstado,
    int codigoSalida
);


bool marcarCancelacionSolicitada(
    unsigned int jobId
);


bool obtenerJobPorId(
    unsigned int jobId,
    Job& jobOut
);

#endif