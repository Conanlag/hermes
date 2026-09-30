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
 * @param programa Nombre o ruta del programa.
 * @param argumentos Argumentos del programa.
 * @return PID del proceso creado.
 *
 * @throws std::runtime_error si fork() falla.
 */
pid_t iniciarProceso(
    const string& programa,
    const vector<string>& argumentos
);

/**
 * Espera a que termine un proceso.
 *
 * @param pid PID del proceso.
 * @param codigoSalida Código de salida del proceso.
 * @return true si terminó normalmente.
 */
bool esperarProceso(
    pid_t pid,
    int& codigoSalida
);

/**
 * Envía SIGTERM a un proceso.
 *
 * @param pid PID del proceso.
 * @return true si la señal fue enviada correctamente.
 */
bool terminarProceso(pid_t pid);

#endif