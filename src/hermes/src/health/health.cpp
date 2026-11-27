#include "health.h"
#include "data_paths.h"
#include "event_log.h"
#include "storage.h"
#include "status.h"
#include "timestamp.h"
#include "network_status.h"

#include <cerrno>
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>
#include <iostream>
#include <stdexcept>

namespace hermes {
namespace {
bool schedulerActivo() {
    // El PID persistido puede estar obsoleto o reutilizado: el bloqueo es la
    // misma fuente de verdad que impide iniciar dos schedulers.
    const int fd = open(rutaDatos("scheduler.lock").c_str(), O_RDONLY | O_CLOEXEC);
    if (fd == -1) {
        if (errno == ENOENT) return false;
        throw std::runtime_error("No se pudo abrir scheduler.lock");
    }
    const int resultado = flock(fd, LOCK_EX | LOCK_NB);
    const int motivo = errno;
    close(fd); // Libera inmediatamente el bloqueo si se obtuvo.
    if (resultado == 0) return false;
    if (motivo == EWOULDBLOCK || motivo == EAGAIN) return true;
    throw std::runtime_error("No se pudo consultar scheduler.lock");
}
}

int mostrarSalud(bool formatoJson) {
    json resumen = {{"consultado_en", obtenerFechaHoraActual()},
                    {"servicio", {{"nombre", "scheduler"}, {"activo", nullptr}}},
                    {"red", nullptr},
                    {"trabajos", nullptr}, {"errores_recientes", nullptr},
                    {"limite_errores", 10}, {"lineas_invalidas", 0},
                    {"advertencias", json::array()}};
    bool completo = true;
    auto fallo = [&](const std::exception &e) {
        completo = false;
        resumen["advertencias"].push_back(detalleSeguro(e));
    };
    try {
        resumen["servicio"]["activo"] = schedulerActivo();
    } catch (const std::exception &e) { fallo(e); }
    try {
        resumen["red"] = consultarEstadoServidorRed();
    } catch (const std::exception &e) { fallo(e); }
    try {
        const auto jobs = leerJobsSeguros();
        std::size_t ejecutando = 0, cola = 0;
        for (const auto &job : jobs) {
            if (!job.is_object() || !job.contains("status") ||
                !job["status"].is_string() ||
                !statusEsTextoConocido(job["status"].get<std::string>())) {
                throw std::runtime_error("Hay trabajos con estado invalido; conteos no disponibles");
            }
            if (job["status"] == "RUNNING") ++ejecutando;
            if (job["status"] == "QUEUED") ++cola;
        }
        resumen["trabajos"] = {{"en_ejecucion", ejecutando}, {"en_cola", cola}};
        if (resumen["servicio"]["activo"] == false && ejecutando > 0) {
            resumen["advertencias"].push_back(
                "Scheduler inactivo con trabajos RUNNING persistidos; requieren recuperacion");
        }
    } catch (const std::exception &e) { fallo(e); }
    try {
        std::size_t invalidas = 0;
        resumen["errores_recientes"] = EventLog::recent_errors(10, invalidas);
        resumen["lineas_invalidas"] = invalidas;
        if (invalidas > 0) {
            completo = false;
            resumen["advertencias"].push_back("Se omitieron lineas invalidas de events.jsonl");
        }
    } catch (const std::exception &e) { fallo(e); }
    resumen["completo"] = completo;
    if (formatoJson) {
        std::cout << resumen.dump(2) << '\n';
    } else {
        const auto &activo = resumen["servicio"]["activo"];
        std::cout << "Salud de Hermes (" << resumen["consultado_en"].get<std::string>() << ")\n"
                  << "Servicio (scheduler): "
                  << (activo.is_null() ? "NO DISPONIBLE" : activo.get<bool>() ? "ACTIVO" : "INACTIVO") << '\n';
        if (resumen["red"].is_null()) {
            std::cout << "Servicio (Hermes Red): NO DISPONIBLE\n";
        } else {
            const auto &red = resumen["red"];
            std::cout << "Servicio (Hermes Red): "
                      << (red["activo"].get<bool>() ? "ACTIVO" : "INACTIVO") << '\n';
            if (red["activo"].get<bool>()) {
                std::cout << "  Escuchando en: " << red["interfaz"].get<std::string>()
                          << ':' << red["puerto"] << " (TCP)\n";
            }
            std::cout << "  Direccion configurada: "
                      << red["configurado"]["interfaz"].get<std::string>()
                      << ':' << red["configurado"]["puerto"] << '\n';
        }
        if (resumen["trabajos"].is_null()) {
            std::cout << "Trabajos en ejecucion: NO DISPONIBLE\nTrabajos en cola: NO DISPONIBLE\n";
        } else {
            std::cout << "Trabajos en ejecucion: " << resumen["trabajos"]["en_ejecucion"]
                      << "\nTrabajos en cola: " << resumen["trabajos"]["en_cola"] << '\n';
        }
        std::cout << "Errores recientes (ultimos 10 ERROR de la bitacora):\n";
        if (resumen["errores_recientes"].is_null()) std::cout << "  NO DISPONIBLE\n";
        else if (resumen["errores_recientes"].empty()) std::cout << "  Sin errores registrados\n";
        else for (const auto &evento : resumen["errores_recientes"]) {
            std::cout << "  " << evento["ts"].get<std::string>()
                      << " [job_id=" << evento["job_id"].get<std::string>() << "] "
                      << evento["message"].get<std::string>() << '\n';
        }
        for (const auto &aviso : resumen["advertencias"]) {
            std::cout << "Advertencia: " << aviso.get<std::string>() << '\n';
        }
    }
    return completo ? 0 : 1;
}
}
