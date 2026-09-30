#ifndef PROCESS_H
#define PROCESS_H

#include <string>
#include <vector>
#include <sys/types.h>

using std::string;
using std::vector;

/**
 * Crea un proceso Linux y ejecuta el programa indicado.
 *
 * El stderr del proceso se redirige a un pipe para que
 * Hermes pueda procesarlo.
 *
 * @param programa Nombre o ruta del programa.
 * @param argumentos Argumentos del programa.
 * @param pipeStderr Descriptor de lectura del pipe de stderr.
 *
 * @return PID del proceso creado.
 *
 * @throws std::runtime_error si fork() o pipe() fallan.
 */
pid_t iniciarProceso(
    const string& programa,
    const vector<string>& argumentos,
    int& pipeStderr
);


/**
 * Espera a que termine un proceso.
 *
 * @param pid PID del proceso.
 * @param codigoSalida Código de salida del proceso.
 *
 * @return true si se pudo obtener correctamente
 *         el resultado del proceso.
 */
bool esperarProceso(
    pid_t pid,
    int& codigoSalida
);


/**
 * Envía SIGTERM a un proceso.
 *
 * @param pid PID del proceso.
 *
 * @return true si la señal fue enviada correctamente.
 */
bool terminarProceso(
    pid_t pid
);

#endif