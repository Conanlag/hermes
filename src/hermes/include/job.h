#ifndef JOB_H
#define JOB_H

#include <string>
#include <vector>
#include "status.h"

using std::string;
using std::vector;

struct Job {
    unsigned int job_id; // No puede haber jobs con id negativo
    int pid;             // PID del proceso Linux
    string programa;
    vector<string> argumentos;
    Status status;
};

Job crearJob(
    const string& programa,
    const vector<string>& argumentos
);

#endif