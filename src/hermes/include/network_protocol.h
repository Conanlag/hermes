#pragma once
#include <string>
#include "network_remote.h"
namespace hermes {
constexpr unsigned VERSION_PROTOCOLO = 1;
constexpr unsigned MAX_MENSAJE_RED = 16384;        // payload máximo de petición
constexpr unsigned MAX_RESPUESTA_RED = 262144;     // payload máximo de respuesta
constexpr int MAX_PROFUNDIDAD_JSON = 32;           // anidamiento máximo aceptado
constexpr unsigned MAX_OPERACION_RED = 32;         // longitud máxima de "operation"
std::string errorProtocolo(const std::string& codigo);

// Desenlace de una solicitud ya interpretada. RF-28 lo usa para documentar si
// la operación se aceptó, se rechazó o no llegó a ejecutarse cuando el cliente
// corta la conexión. No forma parte del protocolo JSON.
struct DetalleSolicitud {
    bool procesada = false;
    bool aceptada = false;
    bool formatoInvalido = false;  // rechazo de protocolo, no llegó al despachador
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
