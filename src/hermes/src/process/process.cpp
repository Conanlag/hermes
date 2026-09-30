#include "process.h"

#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>

#include <cerrno>
#include <stdexcept>

using std::runtime_error;


pid_t iniciarProceso(
    const string& programa,
    const vector<string>& argumentos
) {

    pid_t pid = fork();

    if (pid < 0) {
        throw runtime_error(
            "No se pudo crear el proceso"
        );
    }

    // -------------------------------------------------
    // PROCESO HIJO
    // -------------------------------------------------

    if (pid == 0) {

        vector<char*> argumentosExec;

        argumentosExec.push_back(
            const_cast<char*>(programa.c_str())
        );

        for (const auto& argumento : argumentos) {

            argumentosExec.push_back(
                const_cast<char*>(argumento.c_str())
            );
        }

        argumentosExec.push_back(nullptr);

        execvp(
            programa.c_str(),
            argumentosExec.data()
        );

        /*
         * Si execvp() regresa significa que falló.
         *
         * No usamos iostreams aquí porque después de fork()
         * debemos mantener la lógica del hijo lo más simple
         * posible antes de terminarlo.
         */
        _exit(127);
    }

    // -------------------------------------------------
    // PROCESO PADRE
    // -------------------------------------------------

    return pid;
}


bool esperarProceso(
    pid_t pid,
    int& codigoSalida
) {

    int estado;

    pid_t resultado;

    do {

        resultado = waitpid(
            pid,
            &estado,
            0
        );

    } while (
        resultado == -1 &&
        errno == EINTR
    );

    if (resultado == -1) {
        return false;
    }

    /*
     * El proceso terminó normalmente mediante
     * exit() o return desde main().
     */
    if (WIFEXITED(estado)) {

        codigoSalida = WEXITSTATUS(estado);

        return true;
    }

    /*
     * El proceso terminó debido a una señal.
     *
     * Usamos un valor negativo para indicar
     * que no terminó mediante exit().
     */
    if (WIFSIGNALED(estado)) {

        codigoSalida = -WTERMSIG(estado);

        return true;
    }

    return false;
}


bool terminarProceso(pid_t pid) {

    if (pid <= 0) {
        return false;
    }

    return kill(pid, SIGTERM) == 0;
}