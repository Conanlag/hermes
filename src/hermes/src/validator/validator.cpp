
#include "validator.h"
#include "event_log.h"

#include <stdexcept>

using namespace std;

// IMPORTANTE:
// Actualizar esta lista cuando se agreguen nuevos comandos.
ResultadoValidacion validarComando(const string& comando) {

    if (comando.empty()) {

        hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Rechazo de Validación", {
            {"comando_intentado", comando},
            {"motivo_del_rechazo", "Comando vacio"}
        });

        return {
            false,
            CodigoValidacion::VACIO,
            "Comando vacio. Comandos validos: "
            "job, filter, cancel, clean, --version, --help"
        };
    }

    if (
        comando == "job" ||
        comando == "filter" ||
        comando == "cancel" ||
        comando == "clean" ||
        comando == "--version" ||
        comando == "--help"
    ) {

        return {
            true,
            CodigoValidacion::OK,
            ""
        };
    }

    hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Rechazo de Validación", {
        {"comando_intentado", comando},
        {"motivo_del_rechazo", "Comando no reconocido"}
    });

    return {
        false,
        CodigoValidacion::NO_AUTORIZADO,
        "Comando no reconocido: " +
        comando +
        ". Comandos validos: "
        "job, filter, cancel, clean, --version, --help"
    };
}


ResultadoValidacion validarPrograma(const string& programa) {

    if (programa.empty()) {

        hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Rechazo de Validación", {
            {"comando_intentado", "job"},
            {"programa_intentado", programa},
            {"motivo_del_rechazo", "Programa vacio"}
        });

        return {
            false,
            CodigoValidacion::VACIO,
            "Programa vacio. Uso: hermes job "
            "[--request-id <id>] <programa> [argumentos..]"
        };
    }

    return {
        true,
        CodigoValidacion::OK,
        ""
    };
}

ResultadoValidacion validarRequestId(const string& requestId) {
    if (requestId.empty() || requestId.size() > 128) {
        hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Rechazo de Validación", {
            {"comando_intentado", "job"},
            {"request_id_intentado", requestId},
            {"motivo_del_rechazo", "Tamaño o formato inválido de request-id"}
        });
        return {
            false,
            CodigoValidacion::MALFORMADO,
            "El identificador de solicitud debe tener entre 1 y 128 caracteres."
        };
    }

    for (unsigned char caracter : requestId) {
        const bool valido =
            (caracter >= 'a' && caracter <= 'z') ||
            (caracter >= 'A' && caracter <= 'Z') ||
            (caracter >= '0' && caracter <= '9') ||
            caracter == '-' ||
            caracter == '_' ||
            caracter == '.' ||
            caracter == ':';

        if (!valido) {
            hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Rechazo de Validación", {
                {"comando_intentado", "job"},
                {"request_id_intentado", requestId},
                {"motivo_del_rechazo", "Caracteres inválidos en request-id"}
            });
            return {
                false,
                CodigoValidacion::MALFORMADO,
                "El identificador de solicitud solo admite letras, "
                "numeros, punto, guion y guion bajo."
            };
        }
    }

    return {
        true,
        CodigoValidacion::OK,
        ""
    };
}


ResultadoValidacion validarTipoFiltro(
    const string& tipoFiltro
) {

    if (tipoFiltro.empty()) {

        hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Rechazo de Validación", {
            {"comando_intentado", "filter"},
            {"tipo_filtro_intentado", tipoFiltro},
            {"motivo_del_rechazo", "Tipo de filtro vacio"}
        });

        return {
            false,
            CodigoValidacion::VACIO,
            "Tipo de filtro vacio. Filtros validos: id, status, programa"
        };
    }

    if (
        tipoFiltro == "id" ||
        tipoFiltro == "status" ||
        tipoFiltro == "programa"
    ) {

        return {
            true,
            CodigoValidacion::OK,
            ""
        };
    }

    hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Rechazo de Validación", {
        {"comando_intentado", "filter"},
        {"tipo_filtro_intentado", tipoFiltro},
        {"motivo_del_rechazo", "Filtro no reconocido"}
    });

    return {
        false,
        CodigoValidacion::NO_AUTORIZADO,
        "Filtro no reconocido: " +
        tipoFiltro +
        ". Filtros validos: id, status, programa"
    };
}


ResultadoValidacion validarIdTexto(
    const string& textoId
) {

    if (textoId.empty()) {

        hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Rechazo de Validación", {
            {"comando_intentado", "cancel"},
            {"id_intentado", textoId},
            {"motivo_del_rechazo", "ID vacio"}
        });

        return {
            false,
            CodigoValidacion::VACIO,
            "ID vacio. Debe proporcionar un ID numerico."
        };
    }

    // Valida que solo contenga caracteres numéricos.
    for (char caracter : textoId) {
        if (caracter < '0' || caracter > '9') {
            hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Rechazo de Validación", {
                {"comando_intentado", "cancel"},
                {"id_intentado", textoId},
                {"motivo_del_rechazo", "ID mal formado"}
            });
            return {
                false,
                CodigoValidacion::MALFORMADO,
                "ID mal formado: " +
                textoId +
                ". Debe ser un numero entero positivo."
            };
        }
    }

    try {

        size_t pos = 0;

        unsigned long valor = std::stoul(
            textoId,
            &pos
        );

        // Verificar que todo el texto haya sido convertido.
        if (pos != textoId.size()) {

            hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Rechazo de Validación", {
                {"comando_intentado", "cancel"},
                {"id_intentado", textoId},
                {"motivo_del_rechazo", "ID mal formado"}
            });

            return {
                false,
                CodigoValidacion::MALFORMADO,
                "ID mal formado: " +
                textoId +
                ". Debe ser un numero entero positivo."
            };
        }

        // Los IDs de Hermes comienzan en 1.
        if (valor == 0) {

            hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Rechazo de Validación", {
                {"comando_intentado", "cancel"},
                {"id_intentado", textoId},
                {"motivo_del_rechazo", "ID fuera de rango"}
            });

            return {
                false,
                CodigoValidacion::MALFORMADO,
                "ID mal formado: debe ser mayor a 0."
            };
        }

        return {
            true,
            CodigoValidacion::OK,
            ""
        };

    } catch (const std::invalid_argument&) {

        hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Rechazo de Validación", {
            {"comando_intentado", "cancel"},
            {"id_intentado", textoId},
            {"motivo_del_rechazo", "ID mal formado"}
        });

        return {
            false,
            CodigoValidacion::MALFORMADO,
            "ID mal formado: " +
            textoId +
            ". Debe ser un numero entero positivo."
        };

    } catch (const std::out_of_range&) {

        hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Rechazo de Validación", {
            {"comando_intentado", "cancel"},
            {"id_intentado", textoId},
            {"motivo_del_rechazo", "ID fuera de rango"}
        });

        return {
            false,
            CodigoValidacion::MALFORMADO,
            "ID fuera de rango: " +
            textoId +
            "."
        };
    }
}


ResultadoValidacion validarStatusTexto(
    const string& status
) {

    if (status.empty()) {

        hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Rechazo de Validación", {
            {"comando_intentado", "filter"},
            {"status_intentado", status},
            {"motivo_del_rechazo", "Estado vacio"}
        });

        return {
            false,
            CodigoValidacion::VACIO,
            "Estado vacio. Estados validos: "
            "QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED, INTERRUPTED"
        };
    }

    if (
        status == "QUEUED" ||
        status == "RUNNING" ||
        status == "SUCCEEDED" ||
        status == "FAILED" ||
        status == "CANCELED" ||
        status == "INTERRUPTED"
    ) {

        return {
            true,
            CodigoValidacion::OK,
            ""
        };
    }

    hermes::EventLog::log_event_system(hermes::EventLevel::WARN, "Rechazo de Validación", {
        {"comando_intentado", "filter"},
        {"status_intentado", status},
        {"motivo_del_rechazo", "Estado no reconocido"}
    });

    return {
        false,
        CodigoValidacion::NO_AUTORIZADO,
        "Estado no reconocido: " +
        status +
        ". Estados validos: "
        "QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED, INTERRUPTED"
    };
}
