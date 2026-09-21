#ifndef STATUS_H
#define STATUS_H 

#include <string>
using std::string;

enum class Status {
      QUEUED,
      RUNNING,
      SUCCEEDED,
      FAILED,
      CANCELED
};


string statusToString(Status status);
#endif
