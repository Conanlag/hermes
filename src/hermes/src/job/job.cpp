#include "job.h"
#include "storage.h"
#include "timestamp.h"
#include <functional>
#include <cstdint>
#include <climits>

#include <stdexcept>
#include <string>

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
                throw std::runtime_error("Se agotaron los IDs disponibles");
            }
            siguiente = id + 1;
        }
    }

    return siguiente;
}

bool actualizarCampo(
    unsigned int id,
    const std::function<bool(json&)>& actualizar
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
    const vector<string>& argumentos
) {
    Job nuevo{};
    nuevo.pid = 0;
    nuevo.programa = programa;
    nuevo.argumentos = argumentos;
    nuevo.status = Status::QUEUED;
    nuevo.tiempo_recepcion = obtenerFechaHoraActual();
    nuevo.tiempo_inicio = "";
    nuevo.tiempo_terminacion = "";
    nuevo.codigoSalida = -1;

    bool guardado = modificarJobsSeguros([&](json& jobs) {
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

        jobs.push_back(item);
        return true;
    });

    if (!guardado) {
        throw std::runtime_error("No se pudo registrar el trabajo");
    }

    return nuevo;
}

bool actualizarEstadoJob(unsigned int jobId, Status nuevoEstado) {
    return actualizarCampo(jobId, [&](json& item) {
        item["status"] = statusToString(nuevoEstado);

        if (nuevoEstado == Status::RUNNING) {
            item["tiempo_inicio"] = obtenerFechaHoraActual();
        }

        return true;
    });
}

bool actualizarResultadoJob(
    unsigned int jobId,
    Status nuevoEstado,
    int codigoSalida
) {
    return actualizarCampo(jobId, [&](json& item) {
        item["status"] = statusToString(nuevoEstado);
        item["codigo_salida"] = codigoSalida;
        item["tiempo_terminacion"] = obtenerFechaHoraActual();
        return true;
    });
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