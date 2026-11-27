#ifndef EVENT_LOG_H
#define EVENT_LOG_H

#include <string>
#include <cstddef>

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

    static bool watch_logs();

    // Últimos ERROR en orden de escritura, del más reciente al más antiguo.
    // Omite líneas malformadas y la última línea si aún no está completa.
    static nlohmann::json recent_errors(std::size_t limite,
                                        std::size_t &lineasInvalidas);

    static std::string level_to_string(EventLevel level);
};

// RNF-15: la bitácora nunca debe exponer secretos ni contenido sensible de
// configuración. Estas funciones se aplican antes de serializar el evento, de
// modo que ningún punto de registro pueda saltarse la redacción.

// Indica si el nombre de una clave (en cualquier combinación de mayúsculas y
// minúsculas, con "_" o "-") designa un dato sensible.
bool claveSensible(const std::string &clave);

// Redacta patrones de secreto dentro de una cadena libre: `clave=valor`,
// `--bandera valor`, `-p valor` y `Bearer valor`.
std::string redactarTexto(const std::string &texto);

// Recorre objetos y arreglos aplicando la redacción por clave sensible y, en
// los arreglos, ocultando el elemento que sigue a una bandera sensible.
nlohmann::json redactarContexto(const nlohmann::json &valor);

// Texto de una excepción apto para bitácora: sin fragmentos de parser JSON,
// sin secretos y acotado en longitud.
std::string detalleSeguro(const std::exception &error);

// Cadena acotada y con bytes de control escapados, para registrar entradas no
// confiables sin permitir inyección de texto en la bitácora.
std::string paraRegistro(const std::string &texto, std::size_t maximo = 64);

} // namespace hermes

#endif
