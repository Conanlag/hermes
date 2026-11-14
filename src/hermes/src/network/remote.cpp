#include "network_remote.h"
#include "config.h"
#include "network_access.h"
#include "data_paths.h"
#include "job.h"
#include "job_presentation.h"
#include "cancel.h"
#include "validator.h"
#include "storage.h"
#include "timestamp.h"
#include <algorithm>
#include <fstream>
#include <limits>
#include <stdexcept>

namespace hermes {
using json = nlohmann::json;
namespace {
bool contiene(const std::vector<std::string>& lista, const std::string& valor) {
    return std::find(lista.begin(), lista.end(), valor) != lista.end();
}
json error(const char* codigo) { return {{"ok", false}, {"error", codigo}}; }
json exito(json resultado) { return {{"ok", true}, {"result", std::move(resultado)}}; }
bool entero(const json& datos, const char* clave, unsigned minimo, unsigned maximo) {
    return datos.contains(clave) && datos[clave].is_number_integer() &&
           datos[clave] >= minimo && datos[clave] <= maximo;
}
json proyectar(const json& job) {
    json salida = json::object();
    for (const char* clave : {"job_id", "pid", "status", "programa", "argumentos", "tiempo_recepcion",
         "tiempo_inicio", "tiempo_terminacion", "codigo_salida", "mensaje_error", "cancel_requested"})
        if (job.contains(clave)) salida[clave] = job[clave];
    return salida;
}
bool propio(const json& job, const std::string& identidad) {
    return job.value("propietario_remoto", std::string{}) == identidad;
}
}

ConfiguracionRemota cargarConfiguracionRemota() {
    ConfiguracionRemota config;
    const auto ruta = directorioDatosPredeterminado().parent_path() / "network/network.json";
    if (!std::filesystem::exists(ruta)) return config;
    std::ifstream archivo(ruta);
    if (!archivo) throw std::runtime_error("No se pudo leer network/network.json");
    json datos;
    archivo >> datos;
    if (!datos.is_object() || !datos.contains("habilitada") || !datos["habilitada"].is_boolean())
        throw std::runtime_error("network.json requiere habilitada booleana");
    if (!datos["habilitada"].get<bool>()) return config;
    config.habilitada = true;
    // Rechazar configuración TLS antigua, evitando un cambio silencioso de transporte.
    if (datos.contains("tls"))
        throw std::runtime_error("Quite tls de network.json y registre clientes por id y direcciones IPv4");
    const auto& clientes = datos.at("clientes");
    if (!clientes.is_array()) throw std::runtime_error("clientes debe ser una lista");
    for (const auto& cliente : clientes) {
        if (cliente.contains("sha256"))
            throw std::runtime_error("Los clientes ahora requieren id y direcciones IPv4, no sha256");
        const auto id = cliente.at("id").get<std::string>();
        if (!validarRequestId(id).esValido) throw std::runtime_error("ID de cliente inválido");
        const auto direcciones = cliente.at("direcciones").get<std::vector<std::string>>();
        if (direcciones.empty()) throw std::runtime_error("El cliente requiere al menos una IPv4");
        for (const auto& ip : direcciones) {
            if (!interfazValida(ip) || !reglaRedValida(ip))
                throw std::runtime_error("Cada dirección de cliente debe ser una IPv4 individual LAN/VPN o loopback");
            if (!config.identidades.emplace(ip, id).second)
                throw std::runtime_error("Una IPv4 no puede pertenecer a varios registros de cliente");
        }
        PermisosRemotos permisos;
        permisos.operaciones = cliente.at("operaciones").get<std::vector<std::string>>();
        permisos.programas = cliente.at("programas").get<std::vector<std::string>>();
        for (const auto& operacion : permisos.operaciones)
            if (!contiene({"submit", "query", "list", "cancel"}, operacion))
                throw std::runtime_error("Permiso de operación desconocido");
        for (const auto& programa : permisos.programas)
            if (!validarPrograma(programa).esValido || programa.find('\0') != std::string::npos)
                throw std::runtime_error("Los programas permitidos deben ser nombres o rutas válidos");
        if (!config.clientes.emplace(id, std::move(permisos)).second)
            throw std::runtime_error("Identidad de cliente duplicada");
    }
    return config;
}

json ejecutarOperacionRemota(const std::string& operacion, const json& params,
    const std::string& requestId, const std::string& identidad, const PermisosRemotos& permisos) {
    if (!contiene(permisos.operaciones, operacion)) return error("UNAUTHORIZED");
    try {
        if (operacion == "submit") {
            if (params.size() != 2 || !params.contains("programa") || !params["programa"].is_string() ||
                !params.contains("argumentos") || !params["argumentos"].is_array())
                return error("INVALID_PARAMS");
            const auto programa = params["programa"].get<std::string>();
            if (!validarPrograma(programa).esValido || programa.find('\0') != std::string::npos ||
                !contiene(permisos.programas, programa))
                return error("PROGRAM_NOT_ALLOWED");
            std::vector<std::string> argumentos;
            for (const auto& argumento : params["argumentos"]) {
                if (!argumento.is_string()) return error("INVALID_PARAMS");
                const auto valor = argumento.get<std::string>();
                if (valor.find('\0') != std::string::npos) return error("INVALID_PARAMS");
                argumentos.push_back(valor);
            }
            const auto config = cargarConfiguracion();
            auto job = crearJob(programa, argumentos, "red-" + identidad + "-" + requestId,
                                     config.trabajosMaximos, config.maxCola, identidad);
            esperarInicioJob(job);
            return exito({{"job_id", job.job_id}, {"duplicated", job.solicitudDuplicada}, {"job", jsonDesdeJob(job)}});
        }
        if (operacion == "list") {
            if (params.size() > 4 || (params.contains("after") && !entero(params, "after", 0, UINT32_MAX)) ||
                (params.contains("limit") && !entero(params, "limit", 1, 50))) return error("INVALID_PARAMS");
            for (auto it = params.begin(); it != params.end(); ++it)
                if (it.key() != "after" && it.key() != "limit" && it.key() != "tipo" && it.key() != "valor") return error("INVALID_PARAMS");
            const bool filtrada = params.contains("tipo") || params.contains("valor");
            std::string tipo, valor;
            if (filtrada) {
                if (!params.contains("tipo") || !params["tipo"].is_string() ||
                    !params.contains("valor") || !params["valor"].is_string()) return error("INVALID_PARAMS");
                tipo = params["tipo"].get<std::string>();
                valor = params["valor"].get<std::string>();
                if ((tipo != "status" && tipo != "programa") ||
                    (tipo == "status" && !validarStatusTexto(valor).esValido) ||
                    (tipo == "programa" && !validarPrograma(valor).esValido)) return error("INVALID_PARAMS");
            }
            unsigned after = params.value("after", 0U), limite = params.value("limit", 20U);
            json lista = json::array();
            for (const auto& job : leerJobsSeguros()) {
                if (!propio(job, identidad) || job.value("job_id", 0U) <= after) continue;
                if (filtrada && job.value(tipo, std::string{}) != valor) continue;
                lista.push_back(proyectar(job));
                after = job.at("job_id").get<unsigned>();
                if (lista.size() >= limite) break;
            }
            return exito({{"jobs", lista}, {"next_after", after}});
        }
        if (params.size() != 1 || !entero(params, "job_id", 1, UINT32_MAX)) return error("INVALID_PARAMS");
        const unsigned id = params["job_id"].get<unsigned>();
        if (operacion == "query") {
            for (const auto& job : leerJobsSeguros())
                if (job.value("job_id", 0U) == id && propio(job, identidad)) return exito(proyectar(job));
            return error("NOT_FOUND");
        }
        if (operacion == "cancel") {
            const auto cancelacion = cancelarJobDetallado(id, identidad);
            if (!cancelacion.exito) {
                auto respuesta = error(cancelacion.codigo == CodigoCancelacion::NO_EXISTE ? "NOT_FOUND" :
                    cancelacion.codigo == CodigoCancelacion::NO_CANCELABLE ? "NOT_CANCELABLE" : "JOB_OPERATION_FAILED");
                if (cancelacion.codigo == CodigoCancelacion::NO_CANCELABLE) respuesta["message"] = cancelacion.mensaje;
                return respuesta;
            }
            return exito({{"job_id", id}, {"cancel_requested", true},
                {"cancel_code", cancelacion.codigo == CodigoCancelacion::CANCELADO ? "CANCELADO" : "SOLICITUD_REGISTRADA"}});
        }
        return error("UNKNOWN_OPERATION");
    } catch (const std::exception& detalle) {
        auto respuesta = error("JOB_OPERATION_FAILED");
        respuesta["message"] = detalle.what();
        return respuesta;
    }
}
}
