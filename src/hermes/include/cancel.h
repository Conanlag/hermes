#ifndef CANCEL_H
#define CANCEL_H

#include <string>

using std::string;

enum class CodigoCancelacion {
    CANCELADO,
    SOLICITUD_REGISTRADA,
    NO_EXISTE,
    NO_CANCELABLE,
    ERROR_LECTURA
};

struct ResultadoCancelacion {
    bool exito;
    CodigoCancelacion codigo;
    string mensaje;
};

/**
 * Solicita la cancelación de un Job.
 *
 * @param jobId ID del Job que se desea cancelar.
 * @return true si la cancelación fue solicitada correctamente.
 */
bool cancelarJob(unsigned int jobId);

/**
 * Versión detallada con causa del resultado.
 *
 * - QUEUED → CANCELADO directo (sin señal).
 * - RUNNING → SOLICITUD_REGISTRADA (el supervisor confirma).
 * - Otro estado → NO_CANCELABLE con el estado actual.
 * - ID ausente → NO_EXISTE. Fallo de archivo → ERROR_LECTURA.
 */
ResultadoCancelacion cancelarJobDetallado(unsigned int jobId);

#endif