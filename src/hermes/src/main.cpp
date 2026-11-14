#include <iostream>
#include <string>

// Librerias del proyecto
#include "version.h"
#include "job.h"
#include "job_presentation.h"
#include "filter.h"
#include "validator.h"
#include "terminal.colors.h"
#include "cancel.h"
#include "help.h"
#include "scheduler.h"
#include "clean.h"
#include "event_log.h"
#include "config.h"
#include "data_paths.h"
#include "network.h"

#include <thread>
#include <chrono>


using namespace std;
using namespace std::this_thread;
using namespace std::chrono;


int main(int argc, char* argv[]) {
    try {
        hermes::inicializarConfiguracion();
        (void)hermes::rutaDatos("jobs.json");
        if (argc == 1) hermes::actualizarEnlacesDesarrollo();
    } catch (const std::exception& e) {
        error("No se pudo inicializar la configuración: ", e.what());
        return 1;
    }


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

    if (comando == "red") {
        if (argc == 3 && string(argv[2]) == "start") return hermes::iniciarServidorRed();
        return hermes::ejecutarClienteRed(argc, argv);
    }

    if (comando == "--version") {
        return version();
    }

    if (comando == "--help") {
        return mostrarAyuda();
    }
    if (comando == "logs") {
        if (argc != 2) {
            error("Uso: hermes logs");
            return 1;
        }

        return hermes::EventLog::watch_logs() ? 0 : 1;
    }

    if (comando == "clean") {
        const string objetivo = argc == 3 ? argv[2] : "";
        const ResultadoValidacion validacionClean =
            validarObjetivoClean(objetivo);
        if (!validacionClean.esValido || argc != 3) {
            error("Uso: hermes clean data | scheduler");
            return 1;
        }

        if (objetivo == "data") {
            return limpiarDatos();
        }

        return detenerSchedulerOrdenadamente();
    }

    if (comando == "configmax") {
        const string uso =
            "Uso: hermes configmax <N> | hermes configmax --cola <M> | "
            "hermes configmax <N> --cola <M> "
            "(N entre 1 y 64; M entre 0 y 256).";

        bool tieneTrabajosMaximos = false;
        bool tieneMaxCola = false;
        string valorTrabajosMaximos;
        string valorMaxCola;

        for (int i = 2; i < argc; ++i) {
            const string argumento = argv[i];

            if (argumento == "--cola") {
                if (tieneMaxCola || i + 1 >= argc) {
                    error(uso);
                    return 1;
                }

                valorMaxCola = argv[++i];
                tieneMaxCola = true;
                continue;
            }

            if (tieneTrabajosMaximos || argumento.rfind("--", 0) == 0) {
                error(uso);
                return 1;
            }

            valorTrabajosMaximos = argumento;
            tieneTrabajosMaximos = true;
        }

        if (!tieneTrabajosMaximos && !tieneMaxCola) {
            error(uso);
            return 1;
        }

        if (tieneTrabajosMaximos) {
            const ResultadoValidacion validacion =
                validarTrabajosMaximosTexto(valorTrabajosMaximos);
            if (!validacion.esValido) {
                error(validacion.mensaje);
                return 1;
            }
        }

        if (tieneMaxCola) {
            const ResultadoValidacion validacion =
                validarMaxColaTexto(valorMaxCola);
            if (!validacion.esValido) {
                error(validacion.mensaje);
                return 1;
            }
        }

        hermes::CambiosConfiguracion cambios;
        if (tieneTrabajosMaximos) {
            cambios.trabajosMaximos = true;
            cambios.valorTrabajosMaximos = std::stoi(valorTrabajosMaximos);
        }
        if (tieneMaxCola) {
            cambios.maxCola = true;
            cambios.valorMaxCola = std::stoi(valorMaxCola);
        }

        try {
            hermes::actualizarConfiguracion(cambios);
        } catch (const exception& e) {
            error("No se pudo actualizar la configuración: ", e.what());
            return 1;
        }

        if (tieneTrabajosMaximos) {
            info(
                "Máximo de trabajos simultáneos configurado en ",
                cambios.valorTrabajosMaximos,
                ". El cambio de workers se aplica al iniciar el scheduler."
            );
        }

        if (tieneMaxCola) {
            info(
                "Cupos de espera (max_cola) configurados en ",
                cambios.valorMaxCola,
                ". El cambio se aplica al iniciar el scheduler."
            );
        }

        warning(
            "Para aplicarlo ahora, ejecute 'hermes clean scheduler'; "
            "los trabajos en ejecución serán interrumpidos."
        );
        return 0;
    }

    hermes::ConfiguracionSistema config;
    try {
        config = hermes::cargarConfiguracion();
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
            job = crearJob(
                programa,
                argumentos,
                requestId,
                config.trabajosMaximos,
                config.maxCola
            );
        } catch (const exception& e) {
            error("No se pudo crear el Job: ", e.what());
            return 1;
        }

        esperarInicioJob(job);
        return mostrarAdmisionJob(job);
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