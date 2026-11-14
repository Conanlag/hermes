#include "network_protocol.h"
#include "validator.h"
#include <nlohmann/json.hpp>
#include <stdexcept>

namespace hermes {
using json = nlohmann::json;
std::string errorProtocolo(const std::string& codigo) {
    return json({{"version", 1}, {"request_id", nullptr}, {"ok", false}, {"error", codigo}}).dump() + '\n';
}

std::string procesarSolicitudRed(const std::string& mensaje, const std::string& identidad, const PermisosRemotos* permisos) {
    if (mensaje.size() > MAX_MENSAJE_RED) return errorProtocolo("MESSAGE_TOO_LARGE");
    json solicitud;
    try {
        solicitud = json::parse(mensaje, [](int profundidad, json::parse_event_t, json&) {
            if (profundidad > 32) throw std::invalid_argument("Profundidad excesiva");
            return true;
        });
    } catch (const std::exception&) {
        return errorProtocolo("INVALID_JSON");
    }
    if (!solicitud.is_object()) return errorProtocolo("INVALID_REQUEST");
    if (!solicitud.contains("request_id") || !solicitud["request_id"].is_string())
        return errorProtocolo("INVALID_REQUEST_ID");
    const std::string id = solicitud["request_id"].get<std::string>();
    if (!validarRequestId(id).esValido) return errorProtocolo("INVALID_REQUEST_ID");
    auto responder = [&](const char* codigo) {
        return json({{"version", 1}, {"request_id", id}, {"ok", false}, {"error", codigo}}).dump() + '\n';
    };
    if (!solicitud.contains("version") || !solicitud["version"].is_number_integer())
        return responder("INVALID_VERSION");
    if (solicitud["version"] != 1) return responder("UNSUPPORTED_VERSION");
    if (!solicitud.contains("operation") || !solicitud["operation"].is_string())
        return responder("INVALID_OPERATION");
    if (!solicitud.contains("params") || !solicitud["params"].is_object())
        return responder("INVALID_PARAMS");
    const auto operacion = solicitud["operation"].get<std::string>();
    if (operacion == "ping") {
        if (!solicitud["params"].empty()) return responder("INVALID_PARAMS");
        return json({{"version", 1}, {"request_id", id}, {"ok", true},
                     {"result", {{"message", "pong"}}}}).dump() + '\n';
    }
    if (operacion == "submit" || operacion == "query" || operacion == "list" || operacion == "cancel") {
        if (!permisos || identidad.empty()) return responder("UNAUTHORIZED");
        auto resultado = ejecutarOperacionRemota(operacion, solicitud["params"], id, identidad, *permisos);
        resultado["version"] = 1;
        resultado["request_id"] = id;
        auto serializado = resultado.dump() + '\n';
        if (serializado.size() > 262144) return responder("RESPONSE_TOO_LARGE");
        return serializado;
    }
    return responder("UNKNOWN_OPERATION");
}
}
