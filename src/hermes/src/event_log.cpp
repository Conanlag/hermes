#include "event_log.h"

#include <iostream>
#include <stdexcept>
#include <string>
#include <unistd.h>
#include <fcntl.h>
#include <sys/file.h>
#include <cstring>
#include <cerrno>

#include "data_paths.h"
#include "timestamp.h"

namespace hermes {

std::string EventLog::level_to_string(EventLevel level) {
    switch (level) {
        case EventLevel::DEBUG:
            return "DEBUG";
        case EventLevel::INFO:
            return "INFO";
        case EventLevel::WARN:
            return "WARN";
        case EventLevel::ERROR:
            return "ERROR";
        default:
            return "INFO";
    }
}

static bool escribirLineaJsonl(const std::string &ruta, const nlohmann::json &entrada) {
    int fd = open(
        ruta.c_str(),
        O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC,
        0644
    );
    if (fd == -1) {
        return false;
    }

    if (flock(fd, LOCK_EX) == -1) {
        close(fd);
        return false;
    }

    std::string linea = entrada.dump() + "\n";
    ssize_t escrito = 0;
    const char *buf = linea.c_str();
    size_t restante = linea.size();
    while (restante > 0) {
        escrito = write(fd, buf, restante);
        if (escrito <= 0) {
            if (errno == EINTR) {
                continue;
            }
            flock(fd, LOCK_UN);
            close(fd);
            return false;
        }
        buf += escrito;
        restante -= static_cast<size_t>(escrito);
    }

    fsync(fd);
    flock(fd, LOCK_UN);
    close(fd);

    return true;
}

bool EventLog::log_event(unsigned int job_id,
                         EventLevel level,
                         const std::string &message,
                         const nlohmann::json &extra) {
    try {
        const std::string ruta = rutaEventsLog();

        nlohmann::json entrada;
        entrada["ts"] = obtenerFechaHoraActual();
        entrada["job_id"] = std::to_string(job_id);
        entrada["level"] = level_to_string(level);
        entrada["message"] = message;

        if (extra.is_object() && !extra.empty()) {
            entrada["context"] = extra;
        } else if (!extra.is_null() && !extra.is_object()) {
            entrada["context"] = extra;
        }

        if (!escribirLineaJsonl(ruta, entrada)) {
            std::cerr << "event_log: no se pudo escribir en events.jsonl" << std::endl;
            return false;
        }

        return true;
    } catch (const std::exception &e) {
        std::cerr << "event_log: " << e.what() << std::endl;
        return false;
    } catch (...) {
        std::cerr << "event_log: error desconocido" << std::endl;
        return false;
    }
}

bool EventLog::log_event_system(EventLevel level,
                                const std::string &message,
                                const nlohmann::json &extra) {
    try {
        const std::string ruta = rutaEventsLog();

        nlohmann::json entrada;
        entrada["ts"] = obtenerFechaHoraActual();
        entrada["job_id"] = nullptr;
        entrada["level"] = level_to_string(level);
        entrada["message"] = message;

        if (extra.is_object() && !extra.empty()) {
            entrada["context"] = extra;
        } else if (!extra.is_null() && !extra.is_object()) {
            entrada["context"] = extra;
        }

        if (!escribirLineaJsonl(ruta, entrada)) {
            std::cerr << "event_log: no se pudo escribir en events.jsonl" << std::endl;
            return false;
        }

        return true;
    } catch (const std::exception &e) {
        std::cerr << "event_log: " << e.what() << std::endl;
        return false;
    } catch (...) {
        std::cerr << "event_log: error desconocido" << std::endl;
        return false;
    }
}

} // namespace hermes
