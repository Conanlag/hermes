#include "job.h"
#include "storage.h"
#include "timestamp.h"
#include "event_log.h"
#include <functional>
#include <cstdint>
#include <climits>

#include <stdexcept>
#include <string>

using namespace std;


namespace {
unsigned int siguienteId(const json& jobs) {
    unsigned int siguiente = 1;

    for (const auto& item : jobs) {
        if (!item.contains("job_id") ||
            !item["job_id"].is_number_unsigned()) {
            continue;
        }

        unsigned int id = item["job_id"].get<unsigned int>();

        if (id >= siguiente) {
            if (id == UINT32_MAX) {
                throw runtime_error("Se agotaron los IDs disponibles");
            }
            siguiente = id + 1;
        }
    }

    return siguiente;
}

bool actualizarCampo(
    unsigned int id,
    const function<bool(json&)>& actualizar
) {
    try {
        return modificarJobsSeguros([&](json& jobs) {
            for (auto& item : jobs) {
                if (item.contains("job_id") &&
                    item["job_id"] == id) {
                    return actualizar(item);
                }
            }
            return false;
        });
    } catch (...) {
        return false;
    }
}
}

Job crearJob(
    const string& programa,
    const vector<string>& argumentos,
    const string& requestId,
    int trabajosMaximos
) {
    if (trabajosMaximos < 1) {
        throw invalid_argument(
            "La capacidad máxima debe ser mayor que cero"
        );
    }

    Job nuevo{};
    nuevo.pid = 0;
    nuevo.programa = programa;
    nuevo.argumentos = argumentos;
    nuevo.status = Status::QUEUED;
    nuevo.tiempo_recepcion = obtenerFechaHoraActual();
    nuevo.tiempo_inicio = "";
    nuevo.tiempo_terminacion = "";
    nuevo.codigoSalida = -1;
    nuevo.request_id = requestId;

    bool solicitudExistente = false;
    bool colaLlena = false;
    size_t trabajosActivos = 0;
    bool guardado = modificarJobsSeguros([&](json& jobs) {
        if (!requestId.empty()) {
            for (const auto& item : jobs) {
                if (!item.contains("request_id") ||
                    !item["request_id"].is_string() ||
                    item["request_id"].get<string>() != requestId) {
                    continue;
                }

                if (solicitudExistente) {
                    throw runtime_error(
                        "El identificador de solicitud ya tiene varios Jobs"
                    );
                }

                if (item.value("programa", string{}) != programa ||
                    item.value("argumentos", vector<string>{}) != argumentos) {
                    throw runtime_error(
                        "El identificador de solicitud ya fue usado "
                        "con otro programa o argumentos"
                    );
                }

                nuevo.job_id = item.value("job_id", 0U);
                nuevo.pid = item.value("pid", 0);
                nuevo.status = statusDesdeTexto(
                    item.value("status", string{"QUEUED"})
                );
                nuevo.tiempo_recepcion =
                    item.value("tiempo_recepcion", string{});
                nuevo.tiempo_inicio =
                    item.value("tiempo_inicio", string{});
                nuevo.tiempo_terminacion =
                    item.value("tiempo_terminacion", string{});
                nuevo.codigoSalida = item.value("codigo_salida", -1);
                nuevo.mensajeError = item.value("mensaje_error", string{});
                nuevo.solicitudDuplicada = true;
                if (item.contains("request_id") && item["request_id"].is_string()) {
                    nuevo.request_id = item["request_id"].get<string>();
                } else {
                    nuevo.request_id.clear();
                }
                solicitudExistente = true;
            }
        }

        if (solicitudExistente) {
            return false;
        }

        for (const auto& item : jobs) {
            if (!item.contains("status") || !item["status"].is_string()) {
                continue;
            }

            const string status = item["status"].get<string>();
            if (status == "QUEUED" || status == "RUNNING") {
                ++trabajosActivos;
            }
        }

        if (trabajosActivos >= static_cast<size_t>(trabajosMaximos)) {
            colaLlena = true;
            return false;
        }

        nuevo.job_id = siguienteId(jobs);

        json item;
        item["job_id"] = nuevo.job_id;
        item["pid"] = 0;
        item["programa"] = nuevo.programa;
        item["argumentos"] = nuevo.argumentos;
        item["status"] = "QUEUED";
        item["tiempo_recepcion"] = nuevo.tiempo_recepcion;
        item["tiempo_inicio"] = "";
        item["tiempo_terminacion"] = "";
        item["codigo_salida"] = -1;
        item["cancel_requested"] = false;
        if (!requestId.empty()) {
            item["request_id"] = requestId;
        }

        jobs.push_back(item);
        return true;
    });

    if (colaLlena) {
        nlohmann::json contexto;
        contexto["programa"] = programa;
        contexto["motivo_del_rechazo"] = "capacidad_de_trabajos_alcanzada";
        contexto["trabajos_activos"] = trabajosActivos;
        contexto["capacidad"] = trabajosMaximos;
        if (!requestId.empty()) {
            contexto["request_id"] = requestId;
        }
        const bool rechazoRegistrado = hermes::EventLog::log_event_system(
            hermes::EventLevel::WARN,
            "Solicitud rechazada: cola llena",
            contexto
        );
        string mensajeRechazo =
            "La cola está llena (" + to_string(trabajosActivos) +
            "/" + to_string(trabajosMaximos) +
            " trabajos activos). Intente de nuevo cuando haya espacio.";
        if (!rechazoRegistrado) {
            mensajeRechazo += " No se pudo registrar el rechazo en la bitácora.";
        }
        throw runtime_error(mensajeRechazo);
    }

    if (!guardado && !solicitudExistente) {
        throw runtime_error("No se pudo registrar el trabajo");
    }

    if (!solicitudExistente) {
        nlohmann::json ctxRecibido;
        ctxRecibido["programa"] = nuevo.programa;
        ctxRecibido["argumentos"] = nuevo.argumentos;
        if (!nuevo.request_id.empty()) {
            ctxRecibido["request_id"] = nuevo.request_id;
        }
        hermes::EventLog::log_event(nuevo.job_id, hermes::EventLevel::INFO, "Job recibido", ctxRecibido);
    } else {
        hermes::EventLog::log_event(nuevo.job_id, hermes::EventLevel::DEBUG, "Solicitud duplicada reutilizada", nlohmann::json::object());
    }

    return nuevo;
}


bool marcarCancelacionSolicitada(unsigned int jobId) {
    return actualizarCampo(jobId, [&](json& item) {
        if (!item.contains("status") ||
            item["status"] != "RUNNING") {
            return false;
        }

        item["cancel_requested"] = true;
        return true;
    });
}

bool obtenerJobPorId(unsigned int jobId, Job& jobOut) {
    try {
        json jobs = leerJobsSeguros();

        for (const auto& item : jobs) {
            if (!item.contains("job_id") ||
                item["job_id"] != jobId) {
                continue;
            }

            jobOut.job_id = jobId;
            jobOut.pid = item.value("pid", 0);
            jobOut.programa = item.value("programa", string{});
            jobOut.status = statusDesdeTexto(
                item.value("status", string{"QUEUED"})
            );
            jobOut.codigoSalida = item.value("codigo_salida", -1);
            jobOut.mensajeError = item.value("mensaje_error",string{});
            jobOut.tiempo_recepcion =
                item.value("tiempo_recepcion", string{});
            jobOut.tiempo_inicio =
                item.value("tiempo_inicio", string{});
            jobOut.tiempo_terminacion =
                item.value("tiempo_terminacion", string{});
            if (item.contains("request_id") && item["request_id"].is_string()) {
                jobOut.request_id = item["request_id"].get<string>();
            } else {
                jobOut.request_id.clear();
            }

            jobOut.argumentos.clear();

            if (item.contains("argumentos") &&
                item["argumentos"].is_array()) {
                for (const auto& argumento : item["argumentos"]) {
                    if (argumento.is_string()) {
                        jobOut.argumentos.push_back(
                            argumento.get<string>()
                        );
                    }
                }
            }

            return true;
        }
    } catch (...) {
        return false;
    }

    return false;
}