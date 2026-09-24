#ifndef FILTER_H
#define FILTER_H

#include <string>

using std::string;

void filtrarPorId(unsigned int job_id);

void filtrarPorStatus(const string& status);

void filtrarPorPrograma(const string& programa);


#endif