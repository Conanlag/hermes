#include "event_log.h"

#include <chrono>
#include <cctype>
#include <csignal>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>
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

// ---------------------------------------------------------------------------
// RNF-15: redacción de secretos antes de persistir la bitácora
// ---------------------------------------------------------------------------

namespace {

const char *const MARCA_REDACTADA = "[REDACTED]";

const char *const TERMINOS_SENSIBLES[] = {
    "secret", "token", "password", "passwd", "pwd", "apikey", "auth",
    "authorization", "credential", "credentials", "privatekey", "cert",
    "tls", "sha256", "cookie", "session", "bearer"
};

std::string minusculas(const std::string &texto) {
    std::string salida = texto;
    for (char &caracter : salida) {
        caracter = static_cast<char>(
            std::tolower(static_cast<unsigned char>(caracter)));
    }
    return salida;
}

// Clave sin separadores ni comillas: `api_key` y `apiKey` colapsan en `apikey`.
std::string compactaClave(const std::string &clave) {
    std::string salida;
    for (char caracter : minusculas(clave)) {
        if (caracter == '"' || caracter == '\'' || caracter == '_' ||
            caracter == '-' || caracter == '.') {
            continue;
        }
        salida.push_back(caracter);
    }
    return salida;
}

// Parte la clave por separadores y por cambios de minúscula a mayúscula, para
// que `request_id` no active la regla de `id` ni `identidad` la de `auth`.
std::vector<std::string> tokensClave(const std::string &clave) {
    std::vector<std::string> tokens;
    std::string actual;
    bool anteriorMinuscula = false;

    for (char caracter : clave) {
        if (caracter == '"' || caracter == '\'' || caracter == '_' ||
            caracter == '-' || caracter == '.') {
            if (!actual.empty()) {
                tokens.push_back(minusculas(actual));
                actual.clear();
            }
            anteriorMinuscula = false;
            continue;
        }

        const unsigned char byte = static_cast<unsigned char>(caracter);
        if (std::isupper(byte) && anteriorMinuscula && !actual.empty()) {
            tokens.push_back(minusculas(actual));
            actual.clear();
        }
        anteriorMinuscula = std::islower(byte) || std::isdigit(byte);
        actual.push_back(caracter);
    }

    if (!actual.empty()) {
        tokens.push_back(minusculas(actual));
    }
    return tokens;
}

bool esBanderaConocida(const std::string &palabra) {
    if (minusculas(palabra) == "-p") {
        return true;
    }
    return claveSensible(palabra);
}

// Bandera que espera su valor en el siguiente elemento: `--password`,
// `password:` o, en arreglos de argumentos, `password`.
bool esBanderaSuelta(const std::string &palabra) {
    if (palabra.empty()) {
        return false;
    }
    if (palabra.find('=') != std::string::npos) {
        return false;
    }
    if (palabra.back() == ':') {
        return false;
    }
    return esBanderaConocida(palabra);
}

std::string redactarSegmento(const std::string &texto,
                             bool aceptarBanderaSinGuion) {
    std::string salida;
    salida.reserve(texto.size() + 16);

    std::size_t indice = 0;
    bool redactarSiguiente = false;
    const std::size_t total = texto.size();

    while (indice < total) {
        const std::size_t inicioEspacios = indice;
        while (indice < total &&
               std::isspace(static_cast<unsigned char>(texto[indice]))) {
            ++indice;
        }
        salida.append(texto, inicioEspacios, indice - inicioEspacios);
        if (indice >= total) {
            break;
        }

        std::size_t fin = indice;
        while (fin < total &&
               !std::isspace(static_cast<unsigned char>(texto[fin]))) {
            ++fin;
        }
        const std::string palabra = texto.substr(indice, fin - indice);
        indice = fin;

        if (redactarSiguiente) {
            salida += MARCA_REDACTADA;
            redactarSiguiente = false;
            continue;
        }

        const std::size_t igual = palabra.find('=');
        if (igual != std::string::npos && igual > 0) {
            const std::string clave = palabra.substr(0, igual);
            if (claveSensible(clave)) {
                salida += clave;
                salida += "=";
                salida += MARCA_REDACTADA;
                continue;
            }
        }

        if (!palabra.empty() && palabra.back() == ':') {
            const std::string clave = palabra.substr(0, palabra.size() - 1);
            if (claveSensible(clave)) {
                salida += palabra;
                redactarSiguiente = true;
                continue;
            }
        }

        const bool empiezaConGuion = palabra.size() > 1 && palabra[0] == '-';
        if ((empiezaConGuion || aceptarBanderaSinGuion) &&
            esBanderaConocida(palabra)) {
            salida += palabra;
            redactarSiguiente = true;
            continue;
        }

        if (minusculas(palabra) == "bearer") {
            salida += palabra;
            redactarSiguiente = true;
            continue;
        }

        salida += palabra;
    }

    return salida;
}

} // namespace

bool claveSensible(const std::string &clave) {
    if (clave.empty()) {
        return false;
    }

    const std::string compacta = compactaClave(clave);
    if (compacta == "ambitotrabajos" || compacta == "apikey" ||
        compacta == "privatekey") {
        return true;
    }

    for (const std::string &token : tokensClave(clave)) {
        for (const char *termino : TERMINOS_SENSIBLES) {
            if (token == termino) {
                return true;
            }
        }
    }
    return false;
}

std::string redactarTexto(const std::string &texto) {
    return redactarSegmento(texto, false);
}

nlohmann::json redactarContexto(const nlohmann::json &valor) {
    if (valor.is_object()) {
        nlohmann::json salida = nlohmann::json::object();
        for (auto it = valor.begin(); it != valor.end(); ++it) {
            if (claveSensible(it.key())) {
                salida[it.key()] = MARCA_REDACTADA;
            } else {
                salida[it.key()] = redactarContexto(it.value());
            }
        }
        return salida;
    }

    if (valor.is_array()) {
        nlohmann::json salida = nlohmann::json::array();
        bool redactarSiguiente = false;
        for (const auto &elemento : valor) {
            if (redactarSiguiente) {
                salida.push_back(MARCA_REDACTADA);
                redactarSiguiente = false;
                continue;
            }
            if (elemento.is_string() &&
                esBanderaSuelta(elemento.get<std::string>())) {
                salida.push_back(elemento.get<std::string>());
                redactarSiguiente = true;
                continue;
            }
            salida.push_back(redactarContexto(elemento));
        }
        return salida;
    }

    if (valor.is_string()) {
        return redactarSegmento(valor.get<std::string>(), true);
    }

    return valor;
}

std::string paraRegistro(const std::string &texto, std::size_t maximo) {
    static const char *const HEX = "0123456789ABCDEF";

    std::string limpio;
    limpio.reserve(texto.size());

    for (char caracter : redactarTexto(texto)) {
        const unsigned char byte = static_cast<unsigned char>(caracter);
        if (byte < 0x20 || byte == 0x7F) {
            limpio += "\\x";
            limpio.push_back(HEX[byte >> 4]);
            limpio.push_back(HEX[byte & 0x0F]);
        } else {
            limpio.push_back(caracter);
        }
    }

    if (limpio.size() > maximo) {
        limpio.resize(maximo);
        limpio += "...";
    }
    return limpio;
}

std::string detalleSeguro(const std::exception &error) {
    const std::string texto = error.what() == nullptr ? "" : error.what();
    const std::string revisado = minusculas(texto);

    if (revisado.find("[json.") != std::string::npos ||
        revisado.find("parse error") != std::string::npos ||
        revisado.find("syntax error") != std::string::npos) {
        return "excepcion de formato JSON (detalle omitido)";
    }

    return paraRegistro(texto, 160);
}

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
        entrada["message"] = redactarTexto(message);

        if (!extra.is_null() && !(extra.is_object() && extra.empty())) {
            entrada["context"] = redactarContexto(extra);
        }

        if (!escribirLineaJsonl(ruta, entrada)) {
            std::cerr << "event_log: no se pudo escribir en events.jsonl" << std::endl;
            return false;
        }

        return true;
    } catch (const std::exception &e) {
        std::cerr << "event_log: " << detalleSeguro(e) << std::endl;
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
        entrada["message"] = redactarTexto(message);

        if (!extra.is_null() && !(extra.is_object() && extra.empty())) {
            entrada["context"] = redactarContexto(extra);
        }

        if (!escribirLineaJsonl(ruta, entrada)) {
            std::cerr << "event_log: no se pudo escribir en events.jsonl" << std::endl;
            return false;
        }

        return true;
    } catch (const std::exception &e) {
        std::cerr << "event_log: " << detalleSeguro(e) << std::endl;
        return false;
    } catch (...) {
        std::cerr << "event_log: error desconocido" << std::endl;
        return false;
    }
}

} // namespace hermes
