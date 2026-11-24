#include "network_protocol.h"
#include "validator.h"
#include <nlohmann/json.hpp>
#include <stdexcept>

namespace hermes {
using json = nlohmann::json;

namespace {
// El callback de profundidad de nlohmann comparte el tipo de excepción con el
// resto de errores de parseo; un tipo propio permite responder TOO_DEEP sin
// confundirlo con INVALID_JSON.
struct ProfundidadExcesiva : std::exception {
    const char* what() const noexcept override { return "Profundidad excesiva"; }
};

// RNF-14: solo estas claves son válidas en el nivel superior del sobre.
bool claveSuperiorConocida(const std::string& clave) {
    return clave == "version" || clave == "request_id" ||
           clave == "operation" || clave == "params";
}
}

std::string errorProtocolo(const std::string& codigo) {
    return json({{"version", VERSION_PROTOCOLO}, {"request_id", nullptr}, {"ok", false}, {"error", codigo}}).dump() + '\n';
}

std::string procesarSolicitudRedDetallada(const std::string& mensaje, const std::string& identidad,
    const PermisosRemotos* permisos, DetalleSolicitud& detalle) {
    detalle = DetalleSolicitud{};
    // Rechazo previo a disponer de un request_id válido: el sobre de error no
    // puede citar el identificador del cliente.
    auto rechazo = [&](const char* codigo) {
        detalle.procesada = true;
        detalle.formatoInvalido = true;
        detalle.error = codigo;
        return errorProtocolo(codigo);
    };
    if (mensaje.size() > MAX_MENSAJE_RED) return rechazo("MESSAGE_TOO_LARGE");
    if (mensaje.find('\0') != std::string::npos) return rechazo("NUL_BYTE");
    if (!utf8Valido(mensaje)) return rechazo("INVALID_UTF8");
    json solicitud;
    try {
        solicitud = json::parse(mensaje, [](int profundidad, json::parse_event_t, json&) {
            if (profundidad > MAX_PROFUNDIDAD_JSON) throw ProfundidadExcesiva{};
            return true;
        });
    } catch (const ProfundidadExcesiva&) {
        return rechazo("TOO_DEEP");
    } catch (const std::exception&) {
        return rechazo("INVALID_JSON");
    }
    if (!solicitud.is_object()) return rechazo("INVALID_REQUEST");
    for (auto it = solicitud.begin(); it != solicitud.end(); ++it)
        if (!claveSuperiorConocida(it.key())) return rechazo("INVALID_REQUEST");
    if (!solicitud.contains("request_id") || !solicitud["request_id"].is_string())
        return rechazo("INVALID_REQUEST_ID");
    const std::string id = solicitud["request_id"].get<std::string>();
    detalle.requestId = id;
    auto responder = [&](const char* codigo) {
        detalle.procesada = true;
        detalle.aceptada = false;
        detalle.error = codigo;
        return json({{"version", VERSION_PROTOCOLO}, {"request_id", id}, {"ok", false}, {"error", codigo}}).dump() + '\n';
    };
    // Rechazo de protocolo con request_id ya interpretado.
    auto rechazoConId = [&](const char* codigo) {
        detalle.formatoInvalido = true;
        return responder(codigo);
    };
    if (!validarRequestId(id).esValido) return rechazoConId("INVALID_REQUEST_ID");
    if (!solicitud.contains("version") || !solicitud["version"].is_number_integer())
        return rechazoConId("INVALID_VERSION");
    if (solicitud["version"] != static_cast<int>(VERSION_PROTOCOLO))
        return rechazoConId("UNSUPPORTED_VERSION");
    if (!solicitud.contains("operation") || !solicitud["operation"].is_string())
        return rechazoConId("INVALID_OPERATION");
    const auto operacion = solicitud["operation"].get<std::string>();
    if (operacion.empty() || operacion.size() > MAX_OPERACION_RED)
        return rechazoConId("INVALID_OPERATION");
    if (!solicitud.contains("params") || !solicitud["params"].is_object())
        return rechazoConId("INVALID_PARAMS");
    detalle.operacion = operacion;
    if (operacion == "ping") {
        if (!solicitud["params"].empty()) return rechazoConId("INVALID_PARAMS");
        detalle.procesada = true;
        detalle.aceptada = true;
        return json({{"version", VERSION_PROTOCOLO}, {"request_id", id}, {"ok", true},
                     {"result", {{"message", "pong"}}}}).dump() + '\n';
    }
    if (operacion == "submit" || operacion == "query" || operacion == "list" || operacion == "cancel") {
        if (!permisos || identidad.empty()) return responder("UNAUTHORIZED");
        auto resultado = ejecutarOperacionRemota(operacion, solicitud["params"], id, identidad, *permisos);
        resultado["version"] = VERSION_PROTOCOLO;
        resultado["request_id"] = id;
        auto serializado = resultado.dump() + '\n';
        if (serializado.size() > MAX_RESPUESTA_RED) return responder("RESPONSE_TOO_LARGE");
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
    return rechazoConId("UNKNOWN_OPERATION");
}

std::string procesarSolicitudRed(const std::string& mensaje, const std::string& identidad,
    const PermisosRemotos* permisos) {
    DetalleSolicitud detalle;
    return procesarSolicitudRedDetallada(mensaje, identidad, permisos, detalle);
}
}
