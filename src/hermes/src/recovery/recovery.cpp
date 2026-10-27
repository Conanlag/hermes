#include "recovery.h"

#include "storage.h"
#include "process.h"
#include "status.h"
#include "timestamp.h"
#include "event_log.h"

#include <nlohmann/json.hpp>

#include <chrono>
#include <cstddef>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

#include <signal.h>
#include <unistd.h>

using namespace std;
using namespace std::this_thread;
using namespace std::chrono;

namespace {

struct Clasificacion {
    size_t indice = 0;
    unsigned int jobId = 0;
    string motivo;
    string mensaje;
    bool procesoTerminado = false;
    bool requiereTerminacion = false;
    bool verificarGrupo = false;
    bool grupoNoVerificable = false;
    pid_t pid = 0;
    pid_t sid = 0;

    // Un grupo verificado se comprueba por sus miembros (mismo pgrp y misma
    // sesión), no solo por el líder. Las filas antiguas sin `sid` conservan
    // la comprobación por PID.
    bool sigueVivo() const {
        if (!verificarGrupo) {
            return procesoVivo(pid);
        }

        // NoVerificable se trata como vivo para no afirmar una terminación
        // que no se pudo comprobar.
        return estadoGrupoProceso(pid, sid) !=
               EstadoGrupoProceso::Inexistente;
    }
};

string detalleMotivo(const string& motivo) {
    if (motivo == "sin_pid") {
        return "no había un PID verificable";
    }

    if (motivo == "sin_identidad") {
        return "la fila no guarda identidad de proceso (boot_id/pid_inicio)";
    }

    if (motivo == "pid_reutilizado") {
        return "el PID guardado ya no pertenece al Job";
    }

    if (motivo == "estado_desconocido") {
        return "el estado persistido no es reconocido";
    }

    return "el servicio dejó de supervisar el Job";
}

string mensajeInterrupcion(const string& motivo) {
    return "Trabajo interrumpido por reinicio o caída del scheduler: " +
           detalleMotivo(motivo) +
           ". No se reejecutó automáticamente.";
}

bool leerPid(const json& item, long long& pid) {
    if (!item.contains("pid") ||
        !item["pid"].is_number_integer()) {
        return false;
    }

    pid = item["pid"].get<long long>();
    return true;
}

bool leerIdentidadGuardada(
    const json& item,
    unsigned long long& pidInicio,
    string& bootId
) {
    if (!item.contains("pid_inicio")) {
        return false;
    }

    if (!item["pid_inicio"].is_number_unsigned() &&
        !item["pid_inicio"].is_number_integer()) {
        return false;
    }

    const long long inicio = item["pid_inicio"].get<long long>();

    if (inicio <= 0) {
        return false;
    }

    if (!item.contains("boot_id") ||
        !item["boot_id"].is_string()) {
        return false;
    }

    bootId = item["boot_id"].get<string>();

    if (bootId.empty()) {
        return false;
    }

    pidInicio = static_cast<unsigned long long>(inicio);
    return true;
}

bool leerSidGuardado(const json& item, pid_t& sid) {
    if (!item.contains("sid") ||
        !item["sid"].is_number_integer()) {
        return false;
    }

    const long long valor = item["sid"].get<long long>();

    if (valor <= 0) {
        return false;
    }

    sid = static_cast<pid_t>(valor);
    return true;
}

bool algunProcesoVivo(const vector<Clasificacion*>& pendientes) {
    for (const auto* clasificacion : pendientes) {
        if (clasificacion->sigueVivo()) {
            return true;
        }
    }

    return false;
}

// Termina un lote de huérfanos con UNA sola ventana de gracia compartida,
// para que N huérfanos cuesten ~5 s y no N x 5 s (sección 2.5).
void terminarHuerfanos(vector<Clasificacion*>& pendientes) {
    if (pendientes.empty()) {
        return;
    }

    for (auto* clasificacion : pendientes) {
        senalizarGrupoProceso(clasificacion->pid, SIGTERM);
    }

    const auto finGracia = steady_clock::now() + seconds(5);

    while (steady_clock::now() < finGracia &&
           algunProcesoVivo(pendientes)) {
        sleep_for(milliseconds(100));
    }

    for (auto* clasificacion : pendientes) {
        if (clasificacion->sigueVivo()) {
            senalizarGrupoProceso(clasificacion->pid, SIGKILL);
        }
    }

    const auto finForzado = steady_clock::now() + seconds(5);

    while (steady_clock::now() < finForzado &&
           algunProcesoVivo(pendientes)) {
        sleep_for(milliseconds(100));
    }

    for (auto* clasificacion : pendientes) {
        clasificacion->procesoTerminado =
            !clasificacion->sigueVivo();
    }
}

void aplicarClasificacion(
    json& item,
    const Clasificacion& clasificacion,
    const string& ahora
) {
    item["status"] = "INTERRUPTED";
    item["codigo_salida"] = -1;
    item["tiempo_terminacion"] = ahora;
    item["mensaje_error"] = clasificacion.mensaje;
    item["motivo"] = clasificacion.motivo;
    item["proceso_terminado"] = clasificacion.procesoTerminado;
    item["recuperado_en"] = ahora;
}

} // namespace anónimo

namespace hermes {

void verificarCapacidadDeRecuperacion() {
    IdentidadProceso identidad;

    if (!leerIdentidadProceso(getpid(), identidad)) {
        EventLog::log_event_system(
            EventLevel::ERROR,
            "Error interno del daemon",
            {
                {"funcion", "sonda de capacidad"},
                {"detalle", "no se pudo leer /proc/self/stat o boot_id"}
            }
        );

        throw runtime_error(
            "No se puede garantizar la recuperación: "
            "no se pudo leer la identidad del propio proceso"
        );
    }
}

void recuperarTrabajosInterrumpidos() {
    vector<Clasificacion> clasificaciones;

    modificarJobsSeguros([&](json& jobs) {
        clasificaciones.clear();

        const string ahora = obtenerFechaHoraActual();

        for (size_t indice = 0; indice < jobs.size(); ++indice) {
            if (!jobs[indice].is_object()) {
                continue;
            }

            json& item = jobs[indice];

            string textoStatus;
            bool statusConocido = false;

            if (item.contains("status") && item["status"].is_string()) {
                textoStatus = item["status"].get<string>();
                statusConocido = statusEsTextoConocido(textoStatus);
            }

            Clasificacion clasificacion;
            clasificacion.indice = indice;
            clasificacion.jobId = item.value("job_id", 0U);

            if (!statusConocido) {
                clasificacion.motivo = "estado_desconocido";
                clasificacion.mensaje =
                    mensajeInterrupcion(clasificacion.motivo);
                clasificaciones.push_back(clasificacion);
                continue;
            }

            // QUEUED sigue pendiente y los estados terminales quedan intactos.
            if (textoStatus != "RUNNING") {
                continue;
            }

            long long pid = 0;

            if (!leerPid(item, pid) || pid <= 0) {
                clasificacion.motivo = "sin_pid";
                clasificacion.mensaje =
                    mensajeInterrupcion(clasificacion.motivo);
                clasificaciones.push_back(clasificacion);
                continue;
            }

            clasificacion.pid = static_cast<pid_t>(pid);

            unsigned long long pidInicio = 0;
            string bootId;

            if (!leerIdentidadGuardada(item, pidInicio, bootId)) {
                clasificacion.motivo = "sin_identidad";
                clasificacion.mensaje =
                    mensajeInterrupcion(clasificacion.motivo);
                clasificaciones.push_back(clasificacion);
                continue;
            }

            pid_t sidGuardado = 0;
            const bool haySid = leerSidGuardado(item, sidGuardado);

            if (!procesoVivo(clasificacion.pid)) {
                // El líder ya no existe. Los nietos que sobrevivieron a
                // PDEATHSIG siguen en el grupo y en la sesión privada del
                // demonio; se terminan si ambos identificadores coinciden.
                string bootActual;
                const bool mismaBoot =
                    leerBootId(bootActual) && bootActual == bootId;

                EstadoGrupoProceso estadoGrupo =
                    EstadoGrupoProceso::Inexistente;

                if (mismaBoot && haySid) {
                    estadoGrupo = estadoGrupoProceso(
                        clasificacion.pid,
                        sidGuardado
                    );
                }

                clasificacion.motivo = "caida";
                clasificacion.mensaje =
                    mensajeInterrupcion(clasificacion.motivo);

                if (estadoGrupo == EstadoGrupoProceso::Vivo) {
                    clasificacion.requiereTerminacion = true;
                    clasificacion.verificarGrupo = true;
                    clasificacion.sid = sidGuardado;
                } else if (estadoGrupo ==
                           EstadoGrupoProceso::NoVerificable) {
                    // No se señaliza un grupo que no se pudo verificar y
                    // tampoco se afirma que terminó.
                    clasificacion.grupoNoVerificable = true;
                } else {
                    // Sin líder y sin miembros verificables del grupo no
                    // hay nada que señalar. Las filas antiguas sin `sid`
                    // conservan el comportamiento anterior: no se puede
                    // verificar el grupo y no se señaliza.
                    clasificacion.procesoTerminado = true;
                }

                clasificaciones.push_back(clasificacion);
                continue;
            }

            if (!identidadCoincide(
                    clasificacion.pid,
                    bootId,
                    pidInicio)) {
                // Regla dura: si la identidad no coincide, no se envía señal.
                clasificacion.motivo = "pid_reutilizado";
                clasificacion.procesoTerminado = true;
                clasificacion.mensaje =
                    mensajeInterrupcion(clasificacion.motivo);
                clasificaciones.push_back(clasificacion);
                continue;
            }

            clasificacion.motivo = "caida";
            clasificacion.requiereTerminacion = true;

            if (haySid) {
                // También durante la terminación se comprueba el grupo
                // completo: el líder puede morir antes que sus nietos.
                clasificacion.verificarGrupo = true;
                clasificacion.sid = sidGuardado;
            }

            clasificacion.mensaje =
                mensajeInterrupcion(clasificacion.motivo);
            clasificaciones.push_back(clasificacion);
        }

        vector<Clasificacion*> verificados;

        for (auto& clasificacion : clasificaciones) {
            if (clasificacion.requiereTerminacion) {
                verificados.push_back(&clasificacion);
            }
        }

        // Primero se actúa sobre el proceso; después se persiste el estado.
        terminarHuerfanos(verificados);

        for (const auto& clasificacion : clasificaciones) {
            aplicarClasificacion(
                jobs[clasificacion.indice],
                clasificacion,
                ahora
            );
        }

        return !clasificaciones.empty();
    });

    for (const auto& clasificacion : clasificaciones) {
        nlohmann::json contexto;
        contexto["motivo"] = clasificacion.motivo;
        contexto["proceso_terminado"] = clasificacion.procesoTerminado;

        if (clasificacion.pid > 0) {
            contexto["pid"] = static_cast<int>(clasificacion.pid);
        }

        EventLog::log_event(
            clasificacion.jobId,
            EventLevel::INFO,
            "Trabajo interrumpido",
            contexto
        );

        if ((clasificacion.requiereTerminacion ||
             clasificacion.grupoNoVerificable) &&
            !clasificacion.procesoTerminado) {
            // RNF-10 se mantiene (nunca RUNNING), pero RNF-30 queda como
            // excepción explícita y auditable, no silenciosa.
            EventLog::log_event(
                clasificacion.jobId,
                EventLevel::ERROR,
                "Huérfano no terminado",
                contexto
            );
        }
    }
}

} // namespace hermes
