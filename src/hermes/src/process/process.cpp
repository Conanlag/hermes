#include "process.h"

#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>
#include <stdexcept>

pid_t iniciarProceso(
    const std::string& programa,
    const std::vector<std::string>& argumentos,
    int& pipeStderr
) {
    int pipefd[2];

    if (pipe(pipefd) == -1) {
        throw std::runtime_error("No se pudo crear el pipe");
    }

    pid_t pid = fork();

    if (pid == -1) {
        close(pipefd[0]);
        close(pipefd[1]);
        throw std::runtime_error("No se pudo crear el proceso");
    }

    if (pid == 0) {
        // El proceso hijo no necesita leer del pipe.
        close(pipefd[0]);

        // Abrir /dev/null para descartar stdout.
        int salidaNula = open("/dev/null", O_WRONLY);

        if (salidaNula == -1) {
            close(pipefd[1]);
            _exit(127);
        }

        // Descartar toda la salida estándar del programa.
        if (dup2(salidaNula, STDOUT_FILENO) == -1) {
            close(salidaNula);
            close(pipefd[1]);
            _exit(127);
        }

        // Capturar stderr para que Hermes decida qué errores mostrar.
        if (dup2(pipefd[1], STDERR_FILENO) == -1) {
            close(salidaNula);
            close(pipefd[1]);
            _exit(127);
        }

        close(salidaNula);
        close(pipefd[1]);

        // Preparar los argumentos para execvp.
        std::vector<char*> argv;
        argv.reserve(argumentos.size() + 2);

        argv.push_back(const_cast<char*>(programa.c_str()));

        for (const auto& argumento : argumentos) {
            argv.push_back(const_cast<char*>(argumento.c_str()));
        }

        argv.push_back(nullptr);

        execvp(programa.c_str(), argv.data());

        // Este mensaje solo se genera si execvp falla.
        int errorExec = errno;
        const char* descripcion = std::strerror(errorExec);

        dprintf(
            STDERR_FILENO,
            "No se pudo ejecutar el programa '%s': %s\n",
            programa.c_str(),
            descripcion
        );

        _exit(127);
    }

    // El proceso padre no escribe en el pipe.
    close(pipefd[1]);

    pipeStderr = pipefd[0];

    return pid;
}


bool esperarProceso(pid_t pid, int& codigoSalida) {
    int estado;

    while (true) {
        pid_t resultado = waitpid(pid, &estado, 0);

        if (resultado == -1) {
            if (errno == EINTR) {
                continue;
            }

            codigoSalida = -1;
            return false;
        }

        break;
    }

    if (WIFEXITED(estado)) {
        codigoSalida = WEXITSTATUS(estado);
        return true;
    }

    if (WIFSIGNALED(estado)) {
        codigoSalida = -WTERMSIG(estado);
        return true;
    }

    codigoSalida = -1;
    return false;
}


bool terminarProceso(pid_t pid) {
    if (kill(pid, SIGTERM) == 0) {
        return true;
    }

    return false;
}