#pragma once
#include <map>
#include <string>
#include <vector>
#include <nlohmann/json.hpp>
namespace hermes {
struct PermisosRemotos {
    std::vector<std::string> operaciones;
    std::vector<std::string> programas;
};
struct ConfiguracionRemota {
    bool habilitada = false;
    // La clave es la IPv4 observada por TCP, nunca un campo del JSON recibido.
    std::map<std::string, std::string> identidades;
    std::map<std::string, PermisosRemotos> clientes;
};
ConfiguracionRemota cargarConfiguracionRemota();
nlohmann::json ejecutarOperacionRemota(const std::string& operacion,
    const nlohmann::json& parametros, const std::string& requestId,
    const std::string& identidad, const PermisosRemotos& permisos);
}
