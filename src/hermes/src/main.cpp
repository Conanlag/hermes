#include <iostream>
#include <string>

// Librerias del proyecto
#include "version.h"
#include "job.h"
#include "filter.h"
#include "validator.h"
#include "terminal.colors.h"
#include "cancel.h"
#include "help.h"
#include "scheduler.h"
#include "clean.h"
#include "event_log.h"
#include "config.h"

#include <thread>
#include <chrono>


using namespace std;
using namespace std::this_thread;
using namespace std::chrono;


int main(int argc, char* argv[]) {

    if (argc < 2) {
        cout << "HERMES " << endl;
        return 0;
    }

    string comando = argv[1]; // La clase string ya sabe como manejar ptr a char

    ResultadoValidacion rc = validarComando(comando);
    // Rechazar comando vacío / no autorizado
    if (!rc.esValido) {
        error(rc.mensaje);
        return 1;
    }

    if (comando == "--version") {
        return version();
    }

    if (comando == "--help") {
        return mostrarAyuda();
    }
    if (comando == "clean") {
    if (argc != 3 || string(argv[2]) != "data") {
        error("Uso: hermes clean data");
        return 1;
    }

    return limpiarDatos();
}


    try {
        const auto config = hermes::cargarConfiguracion();
        iniciarSchedulerSiNecesario(config.trabajosMaximos);
    } catch (const exception& e) {
        error("No se pudo iniciar el scheduler: ", e.what());
        return 1;
    }

    if (comando == "job") {
        if (argc < 3) {
            info(
                "Uso: hermes job [--request-id <id>] "
                "<programa> [argumentos..]"
            );
            return 1;
        }

        string requestId;
        int indicePrograma = 2;

        if (string(argv[2]) == "--request-id") {
            if (argc < 5) {
                error(
                    "Uso: hermes job --request-id <id> "
                    "<programa> [argumentos..]"
                );
                return 1;
            }

            ResultadoValidacion rr = validarRequestId(argv[3]);
            if (!rr.esValido) {
                error(rr.mensaje);
                return 1;
            }

            requestId = argv[3];
            indicePrograma = 4;
        }

        string programa = argv[indicePrograma];

        ResultadoValidacion rp = validarPrograma(programa);
        // Rechazar programa vacío / no valido.
        if (!rp.esValido) {
            error(rp.mensaje);
            return 1;
        }

        vector<string> argumentos;
        for (int i = indicePrograma + 1; i < argc; ++i) {
            argumentos.push_back(argv[i]);
        }

        Job job;
        try {
            job = crearJob(programa, argumentos, requestId);
        } catch (const exception& e) {
            error("No se pudo crear el Job: ", e.what());
            return 1;
        }

        if (job.solicitudDuplicada) {
            cout << "job ID: " << job.job_id << endl;
            info("Solicitud duplicada; se reutiliza el Job existente.");
            return 0;
        }

        for (int i = 0; i < 50; ++i) {
            obtenerJobPorId(job.job_id, job);

            if (job.pid > 0 || job.status == Status::FAILED) {
                break;
            }

            sleep_for(
                milliseconds(20)
            );
        }

        cout << "job ID: " << job.job_id << endl;

        if (job.status == Status::FAILED) {
            error(
                job.mensajeError.empty()
                    ? "No se pudo ejecutar el programa '" + programa + "'"
                    : job.mensajeError
            );

            return 1;
        }

        if (job.pid > 0) {
            cout << "PID: " << job.pid << endl;
        } else {
            cout << "PID: pendiente (en cola)" << endl;
        }

        return 0;        
    }
    
    if (comando == "cancel") {

    if (argc < 3) {
        info("Uso: hermes cancel <id>");
        return 1;
    }

    ResultadoValidacion ri =
        validarIdTexto(argv[2]);

    if (!ri.esValido) {
        error(ri.mensaje);
        return 1;
    }

    unsigned int id =
        static_cast<unsigned int>(
            stoul(argv[2])
        );

    hermes::EventLog::log_event(id, hermes::EventLevel::INFO, "Cancelación solicitada", {
        {"origen", "CLI"},
        {"accion", "SOLICITUD"}
    });

    ResultadoCancelacion cr = cancelarJobDetallado(id);

    if (!cr.exito) {
        if (cr.codigo == CodigoCancelacion::NO_EXISTE) {
            hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Petición inválida", {
                {"comando_intentado", "cancel"},
                {"job_id_intentado", id},
                {"motivo", "No existe el Job"}
            });
            error("No existe el Job ID: ", id);
        } else if (cr.codigo == CodigoCancelacion::NO_CANCELABLE) {
            hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Petición inválida", {
                {"comando_intentado", "cancel"},
                {"job_id_intentado", id},
                {"motivo", "cancelacion_sobre_trabajo_ya_finalizado"},
                {"estado_actual", "NO_CANCELABLE"}
            });
            error(cr.mensaje);
        } else {
            hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Petición inválida", {
                {"comando_intentado", "cancel"},
                {"job_id_intentado", id},
                {"motivo", "No se pudo cancelar el Job"}
            });
            error("No se pudo cancelar el Job: ", id, ". ", cr.mensaje);
        }
        return 1;
    }

    if (cr.codigo == CodigoCancelacion::CANCELADO) {
        info("Job cancelado: ", id);
    } else {
        info("Cancelación solicitada para el Job: ", id);
    }

    return 0;
}

    if (comando == "filter") {
        if (argc < 4) {
            info("Uso: hermes filter <id|status|programa> <valor>");
            return 1;
        }

        string tipoFiltro = argv[2];

        ResultadoValidacion rf = validarTipoFiltro(tipoFiltro);
        // Rechazar tipo de filtro vacío / no autorizado
        if (!rf.esValido) {
            error(rf.mensaje);
            warning("Filtros disponibles: id, status, programa");
            return 1;
        }

        if (tipoFiltro == "id") {

            ResultadoValidacion ri = validarIdTexto(argv[3]);
            // Rechazar id mal formado
            if (!ri.esValido) {
                error(ri.mensaje);
                return 1;
            }

            // Convertir str a uint (seguro, ya validado)
            unsigned int id = static_cast<unsigned int>(stoul(argv[3]));

            filtrarPorId(id);

        } else if (tipoFiltro == "status") {

            ResultadoValidacion rs = validarStatusTexto(argv[3]);
            // Rechazar status vacío / no autorizado en filtro
            if (!rs.esValido) {
                error(rs.mensaje);
                return 1;
            }
            filtrarPorStatus(argv[3]);

        } else if (tipoFiltro == "programa") {

            ResultadoValidacion rfp = validarPrograma(argv[3]);
            // Rechazar programa vacío en filtro
            if (!rfp.esValido) {
                error(rfp.mensaje);
                return 1;
            }
            filtrarPorPrograma(argv[3]);
        }

        return 0;
    }

    error("Comando no reconocido: ", comando);
    return 1;
}