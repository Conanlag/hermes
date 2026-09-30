#include "process.h"

#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>

#include <cerrno>
#include <cstring>
#include <stdexcept>

using std::runtime_error;


pid_t iniciarProceso(
    const string& programa,
    const vector<string>& argumentos,
    int& pipeStderr
) {

    /*
     * Pipe utilizado para capturar el stderr
     * del proceso que vamos a ejecutar.
     *
     * pipeStderr[0] -> lectura
     * pipeStderr[1] -> escritura
     */
    int pipefd[2];

    if (pipe(pipefd) == -1) {

        throw runtime_error(
            "No se pudo crear el pipe de stderr"
        );
    }


    pid_t pid = fork();

    if (pid < 0) {

        close(pipefd[0]);
        close(pipefd[1]);

        throw runtime_error(
            "No se pudo crear el proceso"
        );
    }


    // -------------------------------------------------
    // PROCESO HIJO
    // -------------------------------------------------

    if (pid == 0) {

        /*
         * El hijo no necesita leer del pipe.
         */
        close(pipefd[0]);


        /*
         * Redirigir stderr hacia el pipe.
         *
         * A partir de aquí, todo lo que el programa
         * escriba en stderr llegará al supervisor.
         */
        if (dup2(
            pipefd[1],
            STDERR_FILENO
        ) == -1) {

            _exit(127);
        }


        /*
         * Ya tenemos stderr conectado al pipe,
         * por lo que podemos cerrar el descriptor
         * original.
         */
        close(pipefd[1]);


        /*
         * Construir los argumentos para execvp().
         */
        vector<char*> argumentosExec;

        argumentosExec.push_back(
            const_cast<char*>(
                programa.c_str()
            )
        );

        for (const auto& argumento : argumentos) {

            argumentosExec.push_back(
                const_cast<char*>(
                    argumento.c_str()
                )
            );
        }

        argumentosExec.push_back(nullptr);


        /*
         * Ejecutar el programa.
         */
        execvp(
            programa.c_str(),
            argumentosExec.data()
        );


        /*
         * Si execvp() regresa significa que
         * no pudo ejecutar el programa.
         *
         * Como stderr ya está conectado al pipe,
         * este mensaje será recibido por Hermes.
         *
         * No usamos error() aquí porque error()
         * escribiría nuevamente en stderr y queremos
         * terminar correctamente el proceso hijo.
         */
        const char* mensaje =
            std::strerror(errno);

        dprintf(
            STDERR_FILENO,
            "No se pudo ejecutar el programa '%s': %s\n",
            programa.c_str(),
            mensaje
        );


        /*
         * 127 indica que el programa no pudo
         * ser ejecutado.
         */
        _exit(127);
    }


    // -------------------------------------------------
    // PROCESO PADRE
    // -------------------------------------------------

    /*
     * El padre no escribe en el pipe.
     */
    close(pipefd[1]);


    /*
     * Devolvemos al proceso que llamó a esta función
     * el descriptor utilizado para leer stderr.
     */
    pipeStderr = pipefd[0];


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

        codigoSalida =
            WEXITSTATUS(estado);

        return true;
    }


    /*
     * El proceso terminó debido a una señal.
     */
    if (WIFSIGNALED(estado)) {

        codigoSalida =
            -WTERMSIG(estado);

        return true;
    }


    return false;
}


bool terminarProceso(
    pid_t pid
) {

    if (pid <= 0) {

        return false;
    }

    return kill(
        pid,
        SIGTERM
    ) == 0;
}