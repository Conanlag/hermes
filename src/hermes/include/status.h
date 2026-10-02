#ifndef STATUS_H
#define STATUS_H 

#include <string>
using std::string;

enum class Status { // Crear categoria status con valores logicos de estados (estado 0, 1...)
      QUEUED,
      RUNNING,
      SUCCEEDED,
      FAILED,
      CANCELED
};


string statusToString(Status status);

Status statusDesdeTexto(const string& texto);
#endif
