#pragma once

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <stdexcept>
#include <string>

namespace hermes {

inline std::string inicializarDatos() {
    const char* home = std::getenv("HOME");

    if (home == nullptr || home[0] == '\0') {
        throw std::runtime_error(
            "No se pudo determinar el directorio HOME del usuario"
        );
    }

    namespace fs = std::filesystem;

    const fs::path directorio =
        fs::path(home) / ".local" / "share" / "hermes" / "data";

    std::error_code error;
    fs::create_directories(directorio, error);

    if (error) {
        throw std::runtime_error(
            "No se pudo crear el directorio de datos de Hermes: "
            + error.message()
        );
    }

    const fs::path archivoJobs = directorio / "jobs.json";

    // Crear jobs.json solo si todavía no existe.
    if (!fs::exists(archivoJobs, error)) {
        if (error) {
            throw std::runtime_error(
                "No se pudo comprobar jobs.json: " + error.message()
            );
        }

        std::ofstream archivo(archivoJobs);

        if (!archivo) {
            throw std::runtime_error(
                "No se pudo crear jobs.json"
            );
        }

        archivo << "[]\n";

        if (!archivo) {
            throw std::runtime_error(
                "No se pudo inicializar jobs.json"
            );
        }
    }

    return directorio.string();
}

inline std::string rutaDatos(const std::string& nombreArchivo) {
    static const std::string directorio = inicializarDatos();

    return (std::filesystem::path(directorio) / nombreArchivo).string();
}

} // namespace hermes
