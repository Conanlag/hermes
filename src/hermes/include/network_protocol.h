#pragma once
#include <string>
#include "network_remote.h"
namespace hermes {
constexpr unsigned MAX_MENSAJE_RED = 16384;
std::string errorProtocolo(const std::string& codigo);
std::string procesarSolicitudRed(const std::string& mensaje,
    const std::string& identidad = "", const PermisosRemotos* permisos = nullptr);
}
