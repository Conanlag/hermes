#pragma once

#include <string>
#include <nlohmann/json.hpp>

namespace hermes {
// Mantiene el registro de escucha válido solamente durante la vida del servidor.
class RegistroServidorRed {
public:
    RegistroServidorRed(const std::string& interfaz, int puerto);
    ~RegistroServidorRed();
    RegistroServidorRed(const RegistroServidorRed&) = delete;
    RegistroServidorRed& operator=(const RegistroServidorRed&) = delete;
private:
    int descriptor = -1;
};

nlohmann::json consultarEstadoServidorRed();
}
