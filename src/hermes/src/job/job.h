#ifndef JOB_H
#define JOB_H

#include <string>
#include <vector>

using std::string;
using std::vector;

struct Job {
    unsigned int job_id;
    string programa;
    vector<string> argumentos;
};

Job crearJob(
    const string& programa,
    const vector<string>& argumentos
);

#endif