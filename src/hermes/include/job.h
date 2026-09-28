#ifndef JOB_H
#define JOB_H

#include <string>
#include <vector>
#include <chrono>
#include <ctime>
#include "status.h"

using std::string;
using std::vector;

struct Job {
    unsigned int job_id;
    string programa;
    vector<string> argumentos;
    Status status;
    std::string tiempo_recepcion;
    std::string tiempo_inicio;
    std::string tiempo_terminacion;
};

Job crearJob(
    const string& programa,
    const vector<string>& argumentos
);

#endif