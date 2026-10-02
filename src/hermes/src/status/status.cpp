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
    }

    return "QUEUED";
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

    return Status::QUEUED;
}