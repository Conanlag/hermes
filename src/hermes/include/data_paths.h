
#pragma once

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <stdexcept>
#include <string>

namespace hermes {

inline std::string inicializarDatos() {
    namespace fs = std::filesystem;

    const char* home = std::getenv("HOME");

    if (home == nullptr || home[0] == '\0') {
        throw std::runtime_error(
            "No se pudo determinar HOME del usuario"
        );
    }

    const fs::path directorio =
        fs::path(home) / ".local" / "share" / "hermes" / "data";

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
        directorio / "config.json",
        "{\n    \"trabajos_maximos\": 5\n}\n"
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

inline std::string rutaEventsLog() {
    return rutaDatos("events.jsonl");
}

} // namespace hermes
