#ifndef STATUS_H
#define STATUS_H 

#include <string>
using std::string;

enum class Status { // Crear categoria status con valores logicos de estados (estado 0, 1...)
      QUEUED,
      RUNNING,
      SUCCEEDED,
      FAILED,
      CANCELED,
      INTERRUPTED // Terminal: Hermes dejó de supervisar el Job; su resultado real es desconocido.
};


string statusToString(Status status);

// Convierte texto persistido a Status. Un valor desconocido NO se asume
// QUEUED: se trata como INTERRUPTED para fallar en cerrado (RNF-31).
Status statusDesdeTexto(const string& texto);

// Indica si el texto corresponde a un estado conocido del dominio.
bool statusEsTextoConocido(const string& texto);
#endif
