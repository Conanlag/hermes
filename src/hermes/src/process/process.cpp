#include "process.h"

#include <spawn.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <cerrno>
#include <chrono>
#include <thread>
#include <cstring>
#include <stdexcept>
#include <vector>
#include <signal.h>

using namespace std;
using namespace std::this_thread;
using namespace std::chrono;


extern char** environ;

pid_t iniciarProceso(
    const string& programa,
    const vector<string>& argumentos,
    int& pipeStderr
) {
    int pipefd[2];

    if (pipe(pipefd) == -1) {
        throw runtime_error("No se pudo crear el pipe");
    }

    posix_spawn_file_actions_t acciones;

    int error = posix_spawn_file_actions_init(&acciones);

    if (error != 0) {
        close(pipefd[0]);
        close(pipefd[1]);
        throw runtime_error(
            "No se pudieron inicializar las acciones del proceso"
        );
    }

    auto limpiar = [&]() {
        posix_spawn_file_actions_destroy(&acciones);
        close(pipefd[0]);
        close(pipefd[1]);
    };

    error = posix_spawn_file_actions_addclose(
        &acciones, pipefd[0]
    );

    if (error == 0) {
        error = posix_spawn_file_actions_addopen(
            &acciones, STDOUT_FILENO, "/dev/null", O_WRONLY, 0
        );
    }

    if (error == 0) {
        error = posix_spawn_file_actions_adddup2(
            &acciones, pipefd[1], STDERR_FILENO
        );
    }

    if (error == 0) {
        error = posix_spawn_file_actions_addclose(
            &acciones, pipefd[1]
        );
    }

    if (error != 0) {
        limpiar();
        throw runtime_error(
            "No se pudieron configurar los descriptores del proceso"
        );
    }

    vector<char*> argv;
    argv.reserve(argumentos.size() + 2);
    argv.push_back(const_cast<char*>(programa.c_str()));

    for (const auto& argumento : argumentos) {
        argv.push_back(const_cast<char*>(argumento.c_str()));
    }

    argv.push_back(nullptr);

    pid_t pid = -1;

    error = posix_spawnp(
        &pid,
        programa.c_str(),
        &acciones,
        nullptr,
        argv.data(),
        environ
    );

    posix_spawn_file_actions_destroy(&acciones);
    close(pipefd[1]);

    if (error != 0) {
        close(pipefd[0]);
        throw runtime_error(
            "No se pudo ejecutar el programa '" + programa +
            "': " + std::strerror(error)
        );
    }

    pipeStderr = pipefd[0];
    return pid;
}
bool escalarCancelacionProceso(pid_t pid, int tiempoGraciaSegundos) {
    if (pid <= 0 || tiempoGraciaSegundos < 0) {
        return false;
    }

    // Solicitar terminación normal.
    if (kill(pid, SIGTERM) == -1 && errno != ESRCH) {
        return false;
    }

    // Esperar el periodo de gracia sin recoger el proceso:
    // waitpid() sigue siendo responsabilidad del trabajador.
    for (int i = 0; i < tiempoGraciaSegundos * 10; ++i) {
        if (kill(pid, 0) == -1 && errno == ESRCH) {
            return true;
        } sleep_for(
            milliseconds(100)
        );
    }

    // Si sigue existiendo, solicitar terminación forzada.
    if (kill(pid, SIGKILL) == -1 && errno != ESRCH) {
        return false;
    }

    return true;
}

bool esperarProceso(pid_t pid, int& codigoSalida) {
    int estado = 0;

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
    return pid > 0 && kill(pid, SIGTERM) == 0;
}