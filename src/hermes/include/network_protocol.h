#pragma once
#include <string>
#include "network_remote.h"
namespace hermes {
constexpr unsigned MAX_MENSAJE_RED = 16384;
std::string errorProtocolo(const std::string& codigo);

// Desenlace de una solicitud ya interpretada. RF-28 lo usa para documentar si
// la operación se aceptó, se rechazó o no llegó a ejecutarse cuando el cliente
// corta la conexión. No forma parte del protocolo JSON.
struct DetalleSolicitud {
    bool procesada = false;
    bool aceptada = false;
    std::string requestId;
    std::string operacion;
    std::string error;
    unsigned jobId = 0;
};

std::string procesarSolicitudRedDetallada(const std::string& mensaje,
    const std::string& identidad, const PermisosRemotos* permisos,
    DetalleSolicitud& detalle);
std::string procesarSolicitudRed(const std::string& mensaje,
    const std::string& identidad = "", const PermisosRemotos* permisos = nullptr);
}
