#include "network_protocol.h"
#include "validator.h"
#include <nlohmann/json.hpp>
#include <stdexcept>

namespace hermes {
using json = nlohmann::json;
std::string errorProtocolo(const std::string& codigo) {
    return json({{"version", 1}, {"request_id", nullptr}, {"ok", false}, {"error", codigo}}).dump() + '\n';
}

std::string procesarSolicitudRedDetallada(const std::string& mensaje, const std::string& identidad,
    const PermisosRemotos* permisos, DetalleSolicitud& detalle) {
    detalle = DetalleSolicitud{};
    if (mensaje.size() > MAX_MENSAJE_RED) {
        detalle.procesada = true;
        detalle.error = "MESSAGE_TOO_LARGE";
        return errorProtocolo("MESSAGE_TOO_LARGE");
    }
    json solicitud;
    try {
        solicitud = json::parse(mensaje, [](int profundidad, json::parse_event_t, json&) {
            if (profundidad > 32) throw std::invalid_argument("Profundidad excesiva");
            return true;
        });
    } catch (const std::exception&) {
        detalle.procesada = true;
        detalle.error = "INVALID_JSON";
        return errorProtocolo("INVALID_JSON");
    }
    if (!solicitud.is_object()) {
        detalle.procesada = true;
        detalle.error = "INVALID_REQUEST";
        return errorProtocolo("INVALID_REQUEST");
    }
    if (!solicitud.contains("request_id") || !solicitud["request_id"].is_string()) {
        detalle.procesada = true;
        detalle.error = "INVALID_REQUEST_ID";
        return errorProtocolo("INVALID_REQUEST_ID");
    }
    const std::string id = solicitud["request_id"].get<std::string>();
    detalle.requestId = id;
    auto responder = [&](const char* codigo) {
        detalle.procesada = true;
        detalle.aceptada = false;
        detalle.error = codigo;
        return json({{"version", 1}, {"request_id", id}, {"ok", false}, {"error", codigo}}).dump() + '\n';
    };
    if (!validarRequestId(id).esValido) return responder("INVALID_REQUEST_ID");
    if (!solicitud.contains("version") || !solicitud["version"].is_number_integer())
        return responder("INVALID_VERSION");
    if (solicitud["version"] != 1) return responder("UNSUPPORTED_VERSION");
    if (!solicitud.contains("operation") || !solicitud["operation"].is_string())
        return responder("INVALID_OPERATION");
    if (!solicitud.contains("params") || !solicitud["params"].is_object())
        return responder("INVALID_PARAMS");
    const auto operacion = solicitud["operation"].get<std::string>();
    detalle.operacion = operacion;
    if (operacion == "ping") {
        if (!solicitud["params"].empty()) return responder("INVALID_PARAMS");
        detalle.procesada = true;
        detalle.aceptada = true;
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
        // El desenlace se conoce únicamente aquí; se propaga a server.cpp sin
        // alterar el sobre JSON ni la firma pública de procesarSolicitudRed.
        detalle.procesada = true;
        detalle.aceptada = resultado.value("ok", false);
        if (!detalle.aceptada) {
            detalle.error = resultado.value("error", std::string{});
            if (solicitud["params"].contains("job_id") && solicitud["params"]["job_id"].is_number_integer())
                detalle.jobId = solicitud["params"]["job_id"].get<unsigned>();
        } else if (resultado.contains("result") && resultado["result"].is_object() &&
                   resultado["result"].contains("job_id") &&
                   resultado["result"]["job_id"].is_number_integer()) {
            detalle.jobId = resultado["result"]["job_id"].get<unsigned>();
        }
        return serializado;
    }
    return responder("UNKNOWN_OPERATION");
}

std::string procesarSolicitudRed(const std::string& mensaje, const std::string& identidad,
    const PermisosRemotos* permisos) {
    DetalleSolicitud detalle;
    return procesarSolicitudRedDetallada(mensaje, identidad, permisos, detalle);
}
}
