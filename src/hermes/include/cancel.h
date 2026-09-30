#ifndef CANCEL_H
#define CANCEL_H

/**
 * Solicita la cancelación de un Job.
 *
 * @param jobId ID del Job que se desea cancelar.
 * @return true si la cancelación fue solicitada correctamente.
 */
bool cancelarJob(unsigned int jobId);

#endif