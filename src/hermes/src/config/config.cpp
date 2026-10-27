#include "config.h"
#include "data_paths.h"
#include "event_log.h"

#include <fstream>
#include <nlohmann/json.hpp>
#include <string>

using json = nlohmann::json;

namespace hermes {

ConfiguracionSistema cargarConfiguracion() {
    ConfiguracionSistema config;

    const std::string ruta = rutaDatos("config.json");
    std::ifstream archivo(ruta);

    if (!archivo.is_open()) {
        EventLog::log_event_system(
            EventLevel::WARN,
            "No se pudo abrir config.json; se utiliza la configuración por defecto",
            {
                {"archivo", ruta},
                {"trabajos_maximos", config.trabajosMaximos}
            }
        );
        return config;
    }

    json datos;

    try {
        archivo >> datos;
    } catch (const std::exception& e) {
        EventLog::log_event_system(
            EventLevel::WARN,
            "Error al parsear config.json; se utiliza la configuración por defecto",
            {
                {"archivo", ruta},
                {"detalle", e.what()},
                {"trabajos_maximos", config.trabajosMaximos}
            }
        );
        return config;
    }

    if (!datos.is_object()) {
        EventLog::log_event_system(
            EventLevel::WARN,
            "config.json no contiene un objeto JSON; se utiliza la configuración por defecto",
            {
                {"archivo", ruta},
                {"trabajos_maximos", config.trabajosMaximos}
            }
        );
        return config;
    }

    if (!datos.contains("trabajos_maximos") ||
        !datos["trabajos_maximos"].is_number_integer()) {
        EventLog::log_event_system(
            EventLevel::WARN,
            "Llave 'trabajos_maximos' ausente o no entera en config.json",
            {
                {"archivo", ruta},
                {"trabajos_maximos", config.trabajosMaximos}
            }
        );
        return config;
    }

    const int valor = datos["trabajos_maximos"].get<int>();

    if (valor < MIN_TRABAJOS_MAXIMOS) {
        EventLog::log_event_system(
            EventLevel::WARN,
            "Valor de 'trabajos_maximos' inferior al mínimo permitido; ajustando al límite inferior",
            {
                {"valor_leido", valor},
                {"valor_ajustado", MIN_TRABAJOS_MAXIMOS}
            }
        );
        config.trabajosMaximos = MIN_TRABAJOS_MAXIMOS;
    } else if (valor > MAX_TRABAJOS_MAXIMOS) {
        EventLog::log_event_system(
            EventLevel::WARN,
            "Valor de 'trabajos_maximos' superior al límite seguro; ajustando al límite superior",
            {
                {"valor_leido", valor},
                {"valor_ajustado", MAX_TRABAJOS_MAXIMOS}
            }
        );
        config.trabajosMaximos = MAX_TRABAJOS_MAXIMOS;
    } else {
        config.trabajosMaximos = valor;
    }

    return config;
}

} // namespace hermes
