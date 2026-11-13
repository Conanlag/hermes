#include "config.h"
#include "data_paths.h"
#include "event_log.h"

#include <fstream>
#include <arpa/inet.h>
#include <algorithm>
#include <nlohmann/json.hpp>
#include <string>

using json = nlohmann::json;

namespace hermes {

bool interfazValida(const std::string& interfaz) {
    in_addr direccion{};
    return interfaz.find('\0') == std::string::npos &&
        inet_pton(AF_INET, interfaz.c_str(), &direccion) == 1;
}

bool directorioDatosValido(const std::string& directorio) {
    return !directorio.empty() && directorio.find('\0') == std::string::npos &&
        std::filesystem::path(directorio).is_absolute();
}

ConfiguracionSistema cargarConfiguracion() {
    ConfiguracionSistema config;

    config.directorioDatos = directorioDatosConfigurado();
    const std::string ruta = rutaConfiguracion();
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

    auto advertir = [&](const std::string& clave) {
        EventLog::log_event_system(EventLevel::WARN,
            "Valor inválido en config.json; se utiliza el valor por defecto",
            {{"archivo", ruta}, {"clave", clave}});
    };
    auto entero = [&](const char* clave, int minimo, int maximo, int& destino, bool ajustar) {
        if (!datos.contains(clave)) return;
        const auto& valor = datos[clave];
        if (!valor.is_number_integer()) { advertir(clave); return; }
        // Comparar antes de convertir evita desbordamientos de enteros JSON.
        if (valor < minimo) {
            advertir(clave);
            if (ajustar) destino = minimo;
        } else if (valor > maximo) {
            advertir(clave);
            if (ajustar) destino = maximo;
        } else destino = valor.get<int>();
    };
    entero("trabajos_maximos", MIN_TRABAJOS_MAXIMOS, MAX_TRABAJOS_MAXIMOS,
           config.trabajosMaximos, true);
    entero("puerto", 1, 65535, config.puerto, false);
    if (datos.contains("interfaz")) {
        if (datos["interfaz"].is_string() && interfazValida(datos["interfaz"].get<std::string>()))
            config.interfaz = datos["interfaz"].get<std::string>();
        else advertir("interfaz");
    }
    if (datos.contains("directorio_datos") &&
        (!datos["directorio_datos"].is_string() ||
         !directorioDatosValido(datos["directorio_datos"].get<std::string>())))
        advertir("directorio_datos");

    entero("max_cola", MIN_MAX_COLA, MAX_MAX_COLA, config.maxCola, true);

    return config;
}

} // namespace hermes
