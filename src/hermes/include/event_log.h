#ifndef EVENT_LOG_H
#define EVENT_LOG_H

#include <string>

#include "nlohmann/json.hpp"

namespace hermes {

enum class EventLevel {
    DEBUG,
    INFO,
    WARN,
    ERROR
};

class EventLog {
public:
    EventLog() = delete;

    static bool log_event(unsigned int job_id,
                          EventLevel level,
                          const std::string &message,
                          const nlohmann::json &extra = nlohmann::json::object());

    static bool log_event_system(EventLevel level,
                                 const std::string &message,
                                 const nlohmann::json &extra = nlohmann::json::object());

    static std::string level_to_string(EventLevel level);
};

} // namespace hermes

#endif
