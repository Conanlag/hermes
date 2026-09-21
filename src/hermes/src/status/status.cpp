#include "status.h"

string statusToString(Status status) {

    switch (status)
    {
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