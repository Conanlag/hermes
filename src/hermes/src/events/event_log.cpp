#include "event_log.h"

#include <chrono>
#include <csignal>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <thread>
#include <unistd.h>
#include <fcntl.h>
#include <sys/file.h>
#include <cstring>
#include <cerrno>

#include "data_paths.h"
#include "timestamp.h"

namespace hermes {

namespace {

volatile std::sig_atomic_t detenerWatcherLogs = 0;

void manejarInterrupcionLogs(int) {
    detenerWatcherLogs = 1;
}

std::string campoEvento(const nlohmann::json &evento,
                        const std::string &campo,
                        const std::string &valorPredeterminado) {
    if (!evento.contains(campo)) {
        return valorPredeterminado;
    }

    const nlohmann::json &valor = evento.at(campo);
    if (valor.is_null()) {
        return "null";
    }
    if (valor.is_string()) {
        return valor.get<std::string>();
    }
    return valor.dump();
}

std::string limpiarCampo(const std::string &valor) {
    std::string resultado;
    resultado.reserve(valor.size());

    for (char caracter : valor) {
        if (caracter == '|') {
            resultado += "\\|";
        } else if (caracter == '\n') {
            resultado += "\\n";
        } else if (caracter == '\r') {
            resultado += "\\r";
        } else {
            resultado += caracter;
        }
    }

    return resultado;
}

bool imprimirEvento(const std::string &linea, std::size_t numeroLinea) {
    nlohmann::json evento;
    try {
        evento = nlohmann::json::parse(linea);
    } catch (const std::exception &e) {
        std::cerr << "logs: JSON invalido en la linea "
                  << numeroLinea << ": " << e.what() << std::endl;
        return false;
    }

    if (!evento.is_object()) {
        std::cerr << "logs: la linea " << numeroLinea
                  << " no contiene un objeto JSON" << std::endl;
        return false;
    }

    std::cout << "| hermes | ("
              << limpiarCampo(campoEvento(evento, "ts", "-")) << ") "
              << "[" << limpiarCampo(campoEvento(evento, "level", "-")) << "] "
              << "[job_id="
              << limpiarCampo(campoEvento(evento, "job_id", "-")) << "] "
              << limpiarCampo(campoEvento(evento, "message", "-"));
    if (evento.contains("context")) {
        std::cout << " " << limpiarCampo(evento.at("context").dump());
    }
    std::cout << std::endl;
    return true;
}

} // namespace

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

bool EventLog::watch_logs() {
    std::string ruta;
    try {
        ruta = rutaEventsLog();
    } catch (const std::exception &e) {
        std::cerr << "logs: no se pudo localizar la bitácora: "
                  << e.what() << std::endl;
        return false;
    }

    std::ifstream archivo(ruta);
    if (!archivo) {
        std::cerr << "logs: no se pudo abrir la bitácora: "
                  << ruta << std::endl;
        return false;
    }

    archivo.seekg(0, std::ios::end);
    if (!archivo) {
        std::cerr << "logs: no se pudo posicionar en la bitácora: "
                  << ruta << std::endl;
        return false;
    }

    std::cout << "| hermes | observando logs nuevos (Ctrl+C para salir)"
              << std::endl;
    detenerWatcherLogs = 0;
    const auto manejadorAnterior =
        std::signal(SIGINT, manejarInterrupcionLogs);
    if (manejadorAnterior == SIG_ERR) {
        std::cerr << "logs: no se pudo instalar el manejador de Ctrl+C"
                  << std::endl;
        return false;
    }

    std::string linea;
    std::string lineaPendiente;
    std::size_t numeroLinea = 0;
    bool exito = true;
    while (!detenerWatcherLogs) {
        archivo.clear();
        while (std::getline(archivo, linea)) {
            if (archivo.eof()) {
                lineaPendiente += linea;
                break;
            }

            ++numeroLinea;
            lineaPendiente += linea;
            if (!lineaPendiente.empty() &&
                !imprimirEvento(lineaPendiente, numeroLinea)) {
                exito = false;
                break;
            }
            lineaPendiente.clear();
        }

        if (!exito || archivo.bad()) {
            if (exito) {
                std::cerr << "logs: error al leer la bitacora: "
                          << ruta << std::endl;
            }
            exito = false;
            break;
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    std::signal(SIGINT, manejadorAnterior);
    std::cout << std::endl;
    return exito;
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
