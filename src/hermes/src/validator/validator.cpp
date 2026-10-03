#include "validator.h"

#include <stdexcept>


// IMPORTANTE:
// Actualizar esta lista cuando se agreguen nuevos comandos.
ResultadoValidacion validarComando(const string& comando) {

    if (comando.empty()) {

        return {
            false,
            CodigoValidacion::VACIO,
            "Comando vacio. Comandos validos: job, filter, cancel, --version, --help"
        };
    }

    if (
        comando == "job" ||
        comando == "filter" ||
        comando == "cancel" ||
        comando == "--version" ||
        comando == "--help"
    ) {

        return {
            true,
            CodigoValidacion::OK,
            ""
        };
    }

    return {
        false,
        CodigoValidacion::NO_AUTORIZADO,
        "Comando no reconocido: " +
        comando +
        ". Comandos validos: job, filter, cancel, --version, --help"
    };
}


ResultadoValidacion validarPrograma(const string& programa) {

    if (programa.empty()) {

        return {
            false,
            CodigoValidacion::VACIO,
            "Programa vacio. Uso: hermes job <programa> [argumentos..]"
        };
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

        return {
            false,
            CodigoValidacion::VACIO,
            "ID vacio. Debe proporcionar un ID numerico."
        };
    }

    try {

        size_t pos = 0;

        unsigned long valor =
            std::stoul(
                textoId,
                &pos
            );


        /*
         * Verificar que todo el texto
         * haya sido convertido.
         */
        if (pos != textoId.size()) {

            return {
                false,
                CodigoValidacion::MALFORMADO,
                "ID mal formado: " +
                textoId +
                ". Debe ser un numero entero positivo."
            };
        }


        /*
         * Los IDs de Hermes comienzan en 1.
         */
        if (valor == 0) {

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

        return {
            false,
            CodigoValidacion::MALFORMADO,
            "ID mal formado: " +
            textoId +
            ". Debe ser un numero entero positivo."
        };

    } catch (const std::out_of_range&) {

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

        return {
            false,
            CodigoValidacion::VACIO,
            "Estado vacio. Estados validos: "
            "QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED"
        };
    }

    if (
        status == "QUEUED" ||
        status == "RUNNING" ||
        status == "SUCCEEDED" ||
        status == "FAILED" ||
        status == "CANCELED"
    ) {

        return {
            true,
            CodigoValidacion::OK,
            ""
        };
    }

    return {
        false,
        CodigoValidacion::NO_AUTORIZADO,
        "Estado no reconocido: " +
        status +
        ". Estados validos: "
        "QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED"
    };
}