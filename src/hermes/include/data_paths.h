#pragma once

#include <cstdlib>
#include <string>

namespace hermes {

inline std::string rutaDatos(const std::string& nombreArchivo) {
    const char* directorioConfigurado =
        std::getenv("HERMES_DATA_DIR");

    if (directorioConfigurado != nullptr &&
        directorioConfigurado[0] != '\0') {
        return std::string(directorioConfigurado)
            + "/" + nombreArchivo;
    }

    const char* home = std::getenv("HOME");

    if (home != nullptr && home[0] != '\0') {
        return std::string(home)
            + "/.local/share/hermes/data/"
            + nombreArchivo;
    }

    return std::string("data/") + nombreArchivo;
}

} // namespace hermes