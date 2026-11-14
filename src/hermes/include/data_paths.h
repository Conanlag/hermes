
#pragma once

#include "config.h"
#include <nlohmann/json.hpp>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <stdexcept>
#include <string>

namespace hermes {

// La configuración se resuelve sin inicializar datos ni emitir eventos:
// EventLog también utiliza rutaDatos().
inline std::filesystem::path directorioDatosPredeterminado() {
    const char* home = std::getenv("HOME");
    if (!home || !*home) throw std::runtime_error("No se pudo determinar HOME del usuario");
    return std::filesystem::path(home) / ".local/share/hermes/data";
}

inline std::string rutaConfiguracion(const std::string& nombre = "config.json") {
    namespace fs = std::filesystem;
    (void)directorioDatosPredeterminado(); // Validar HOME antes de construir rutas.
    const char* xdg = std::getenv("XDG_CONFIG_HOME");
    const fs::path base = xdg && fs::path(xdg).is_absolute()
        ? fs::path(xdg) : fs::path(std::getenv("HOME")) / ".config";
    const fs::path actual = base / "hermes";
    fs::create_directories(actual);
    return (actual / nombre).string();
}

inline std::string directorioDatosConfigurado() {
    std::ifstream archivo(rutaConfiguracion());
    try {
        nlohmann::json datos;
        if (archivo >> datos && datos.is_object() && datos.contains("directorio_datos") &&
            datos["directorio_datos"].is_string()) {
            const auto valor = datos["directorio_datos"].get<std::string>();
            if (directorioDatosValido(valor)) return valor;
        }
    } catch (const nlohmann::json::exception&) {
        // La lectura completa registra el diagnóstico sin recursión en EventLog.
    }
    return directorioDatosPredeterminado().string();
}

inline std::string inicializarDatos() {
    namespace fs = std::filesystem;
    const fs::path directorio = directorioDatosConfigurado();

    std::error_code error;
    fs::create_directories(directorio, error);

    if (error) {
        throw std::runtime_error(
            "No se pudo crear el directorio de datos: "
            + error.message()
        );
    }

    // Crear cada archivo solamente si no existe.
    const auto crearArchivoSiFalta =
        [](const fs::path& ruta, const std::string& contenido) {
            std::error_code ec;
            bool existe = fs::exists(ruta, ec);

            if (ec) {
                throw std::runtime_error(
                    "No se pudo comprobar " + ruta.string()
                );
            }

            if (!existe) {
                std::ofstream archivo(ruta);

                if (!archivo) {
                    throw std::runtime_error(
                        "No se pudo crear " + ruta.string()
                    );
                }

                archivo << contenido;

                if (!archivo) {
                    throw std::runtime_error(
                        "No se pudo inicializar " + ruta.string()
                    );
                }
            }
        };

    crearArchivoSiFalta(
        directorio / "jobs.json",
        "[]\n"
    );

    crearArchivoSiFalta(
        directorio / "jobs.lock",
        ""
    );

    crearArchivoSiFalta(
        directorio / "events.jsonl",
        ""
    );

    return directorio.string();
}

inline std::string rutaDatos(const std::string& nombreArchivo) {
    static const std::string directorio = inicializarDatos();

    return (
        std::filesystem::path(directorio) / nombreArchivo
    ).string();
}

// Solo en una copia de desarrollo: el binario instalado no crea enlaces
// dentro de ~/.local/bin. Git conserva los dos enlaces; cada copia los adapta
// al usuario y al directorio de datos efectivo al ejecutar Hermes.
inline void actualizarEnlacesDesarrollo() {
    namespace fs = std::filesystem;
    std::error_code ec;
    const auto ejecutable = fs::read_symlink("/proc/self/exe", ec);
    if (ec) return;
    const auto proyecto = ejecutable.parent_path();
    if (!fs::is_regular_file(proyecto / "Makefile") ||
        !fs::is_directory(proyecto / "include") || !fs::is_directory(proyecto / "src")) return;
    const auto enlazar = [](const fs::path& enlace, const fs::path& destino) {
        const auto estado = fs::symlink_status(enlace);
        if (fs::is_symlink(estado)) {
            if (fs::read_symlink(enlace) == destino) return;
            // Solo se elimina el enlace, nunca se recorre su destino.
            fs::remove(enlace);
        } else if (fs::exists(estado)) {
            throw std::runtime_error("Se conserva la ruta existente porque no es un enlace: " + enlace.string());
        }
        fs::create_directory_symlink(destino, enlace);
    };
    enlazar(proyecto / "data", fs::path(rutaDatos("jobs.json")).parent_path());
    enlazar(proyecto / "config", fs::path(rutaConfiguracion()).parent_path());
}

inline std::string rutaEventsLog() {
    return rutaDatos("events.jsonl");
}

} // namespace hermes
