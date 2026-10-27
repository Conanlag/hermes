#include "status.h"

string statusToString(Status status) {

    switch (status) {

        case Status::QUEUED:
            return "QUEUED";

        case Status::RUNNING:
            return "RUNNING";

        case Status::SUCCEEDED:
            return "SUCCEEDED";

        case Status::FAILED:
            return "FAILED";

        case Status::CANCELED:
            return "CANCELED";

        case Status::INTERRUPTED:
            return "INTERRUPTED";
    }

    return "INTERRUPTED";
}

Status statusDesdeTexto(const string& texto) {

    if (texto == "QUEUED") {
        return Status::QUEUED;
    }

    if (texto == "RUNNING") {
        return Status::RUNNING;
    }

    if (texto == "SUCCEEDED") {
        return Status::SUCCEEDED;
    }

    if (texto == "FAILED") {
        return Status::FAILED;
    }

    if (texto == "CANCELED") {
        return Status::CANCELED;
    }

    if (texto == "INTERRUPTED") {
        return Status::INTERRUPTED;
    }

    // Fail-closed: un estado que no entendemos no puede reportarse como
    // pendiente ni reejecutarse. Se trata como interrumpido.
    return Status::INTERRUPTED;
}

bool statusEsTextoConocido(const string& texto) {
    return texto == "QUEUED" ||
           texto == "RUNNING" ||
           texto == "SUCCEEDED" ||
           texto == "FAILED" ||
           texto == "CANCELED" ||
           texto == "INTERRUPTED";
}
