#include "process.h"

#include <unistd.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/prctl.h>
#include <fcntl.h>
#include <cerrno>
#include <chrono>
#include <cstdlib>
#include <thread>
#include <cstring>
#include <fstream>
#include <sstream>
#include <stdexcept>
#include <vector>
#include <signal.h>

using namespace std;
using namespace std::this_thread;
using namespace std::chrono;


extern char** environ;

namespace {

constexpr const char* RUTA_BOOT_ID =
    "/proc/sys/kernel/random/boot_id";

// Lee estado, pgrp, sesión y starttime de /proc/<pid>/stat.
//
// El campo comm (2) puede contener espacios y paréntesis, por eso se toma
// la subcadena posterior al último ')' en lugar de hacer un split ingenuo.
bool leerStatProceso(
    pid_t pid,
    char& estado,
    pid_t& pgrp,
    pid_t& sid,
    unsigned long long& pidInicio
) {
    if (pid <= 0) {
        return false;
    }

    ifstream archivo(
        "/proc/" + to_string(pid) + "/stat"
    );

    if (!archivo.is_open()) {
        return false;
    }

    string linea;
    getline(archivo, linea);

    const size_t cierreComm = linea.rfind(')');

    if (cierreComm == string::npos) {
        return false;
    }

    istringstream resto(linea.substr(cierreComm + 1));

    string textoEstado;
    long long ppid = 0;
    long long valorPgrp = 0;
    long long valorSid = 0;

    // Campos posteriores al comm: 3 state, 4 ppid, 5 pgrp, 6 session.
    if (!(resto >> textoEstado >> ppid >> valorPgrp >> valorSid)) {
        return false;
    }

    if (textoEstado.empty()) {
        return false;
    }

    // Se descartan los campos 7..21 para llegar al 22 (starttime).
    string descartado;

    for (int campo = 7; campo <= 21; ++campo) {
        if (!(resto >> descartado)) {
            return false;
        }
    }

    unsigned long long valorInicio = 0;

    if (!(resto >> valorInicio)) {
        return false;
    }

    estado = textoEstado[0];
    pgrp = static_cast<pid_t>(valorPgrp);
    sid = static_cast<pid_t>(valorSid);
    pidInicio = valorInicio;

    return true;
}

} // namespace anónimo

bool leerBootId(string& bootId) {
    ifstream archivo(RUTA_BOOT_ID);

    if (!archivo.is_open()) {
        return false;
    }

    string linea;
    getline(archivo, linea);

    while (!linea.empty() &&
           (linea.back() == '\n' || linea.back() == '\r')) {
        linea.pop_back();
    }

    if (linea.empty()) {
        return false;
    }

    bootId = linea;
    return true;
}

bool leerIdentidadProceso(pid_t pid, IdentidadProceso& identidad) {
    string bootId;

    if (!leerBootId(bootId)) {
        return false;
    }

    char estado = '\0';
    pid_t pgrp = 0;
    pid_t sid = 0;
    unsigned long long pidInicio = 0;

    if (!leerStatProceso(pid, estado, pgrp, sid, pidInicio)) {
        return false;
    }

    identidad.bootId = bootId;
    identidad.pidInicio = pidInicio;
    identidad.pgrp = pgrp;
    identidad.sid = sid;

    return true;
}

bool identidadCoincide(
    pid_t pid,
    const string& bootIdEsperado,
    unsigned long long pidInicioEsperado
) {
    if (pid <= 0 ||
        bootIdEsperado.empty() ||
        pidInicioEsperado == 0) {
        return false;
    }

    string bootIdActual;

    if (!leerBootId(bootIdActual) || bootIdActual != bootIdEsperado) {
        return false;
    }

    char estado = '\0';
    pid_t pgrp = 0;
    pid_t sid = 0;
    unsigned long long pidInicio = 0;

    if (!leerStatProceso(pid, estado, pgrp, sid, pidInicio)) {
        return false;
    }

    return pidInicio == pidInicioEsperado && pgrp == pid;
}

bool procesoVivo(pid_t pid) {
    char estado = '\0';
    pid_t pgrp = 0;
    pid_t sid = 0;
    unsigned long long pidInicio = 0;

    if (!leerStatProceso(pid, estado, pgrp, sid, pidInicio)) {
        return false;
    }

    // Un zombie ya no ejecuta nada; init (o el padre) lo recogerá.
    return estado != 'Z' && estado != 'X';
}

EstadoGrupoProceso estadoGrupoProceso(pid_t pgid, pid_t sid) {
    if (pgid <= 0 || sid <= 0) {
        return EstadoGrupoProceso::Inexistente;
    }

    DIR* directorio = opendir("/proc");

    if (directorio == nullptr) {
        // No se puede verificar el grupo: no se debe señalizar ni afirmar
        // que terminó.
        return EstadoGrupoProceso::NoVerificable;
    }

    bool encontrado = false;
    dirent* entrada = nullptr;

    while ((entrada = readdir(directorio)) != nullptr) {
        const string nombre = entrada->d_name;

        if (nombre.empty()) {
            continue;
        }

        char* fin = nullptr;
        const long valor = strtol(nombre.c_str(), &fin, 10);

        if (fin == nombre.c_str() || *fin != '\0' || valor <= 0) {
            continue;
        }

        char estado = '\0';
        pid_t pgrp = 0;
        pid_t sidProceso = 0;
        unsigned long long pidInicio = 0;

        if (!leerStatProceso(
                static_cast<pid_t>(valor),
                estado,
                pgrp,
                sidProceso,
                pidInicio)) {
            continue;
        }

        if (pgrp != pgid || sidProceso != sid) {
            continue;
        }

        if (estado == 'Z' || estado == 'X') {
            continue;
        }

        encontrado = true;
        break;
    }

    closedir(directorio);
    return encontrado
        ? EstadoGrupoProceso::Vivo
        : EstadoGrupoProceso::Inexistente;
}

bool senalizarGrupoProceso(pid_t pgid, int senal) {
    if (pgid <= 0) {
        return false;
    }

    if (kill(-pgid, senal) == 0) {
        return true;
    }

    return errno == ESRCH;
}

bool terminarGrupoProceso(pid_t pgid, int tiempoGraciaSegundos) {
    if (pgid <= 0 || tiempoGraciaSegundos < 0) {
        return false;
    }

    senalizarGrupoProceso(pgid, SIGTERM);

    for (int i = 0; i < tiempoGraciaSegundos * 10; ++i) {
        if (!procesoVivo(pgid)) {
            return true;
        }
        sleep_for(milliseconds(100));
    }

    senalizarGrupoProceso(pgid, SIGKILL);

    for (int i = 0; i < tiempoGraciaSegundos * 10; ++i) {
        if (!procesoVivo(pgid)) {
            return true;
        }
        sleep_for(milliseconds(100));
    }

    return !procesoVivo(pgid);
}

pid_t iniciarProceso(
    const string& programa,
    const vector<string>& argumentos,
    int& pipeStderr
) {
    int pipefd[2];

    // O_CLOEXEC evita que el pipe de stderr se herede en exec.
    // En el hijo, dup2 limpia el flag sobre el descriptor duplicado.
    if (pipe2(pipefd, O_CLOEXEC) == -1) {
        throw runtime_error("No se pudo crear el pipe");
    }

    int aux[2];

    // Pipe auxiliar para reportar el errno de exec al padre.
    if (pipe2(aux, O_CLOEXEC) == -1) {
        close(pipefd[0]);
        close(pipefd[1]);
        throw runtime_error("No se pudo crear el pipe auxiliar");
    }

    vector<char*> argv;
    argv.reserve(argumentos.size() + 2);
    argv.push_back(const_cast<char*>(programa.c_str()));

    for (const auto& argumento : argumentos) {
        argv.push_back(const_cast<char*>(argumento.c_str()));
    }

    argv.push_back(nullptr);

    const pid_t padre = getpid();
    const pid_t pid = fork();

    if (pid == -1) {
        close(pipefd[0]);
        close(pipefd[1]);
        close(aux[0]);
        close(aux[1]);
        throw runtime_error("No se pudo crear el proceso");
    }

    if (pid == 0) {
        // Hijo: solo llamadas seguras tras fork.
        close(aux[0]);
        close(pipefd[0]);

        // El demonio es multihilo: otro worker pudo tener jobs.json abierto
        // en el momento del fork. Ningún descriptor del rango habitual
        // (3..1023) debe sobrevivir al exec del Job (F1). fcntl es seguro
        // tras fork. El rango cubre los locks y jobs.json del demonio; si
        // se eleva RLIMIT_NOFILE, hay que ampliarlo.
        for (int descriptor = 3; descriptor < 1024; ++descriptor) {
            (void)fcntl(descriptor, F_SETFD, FD_CLOEXEC);
        }

        // Grupo propio para poder señalar al proceso y a sus nietos.
        setpgid(0, 0);

        // Si el demonio muere, el hijo no queda huérfano.
        prctl(PR_SET_PDEATHSIG, SIGKILL);

        // Cierra la carrera padre-muerto-antes-de-prctl: si el padre ya no
        // existe, el hijo debe morir en vez de quedar huérfano.
        if (getppid() != padre) {
            _exit(127);
        }

        int nulo = open("/dev/null", O_RDWR | O_CLOEXEC);

        if (nulo == -1) {
            int error = errno;
            (void)!write(aux[1], &error, sizeof(error));
            _exit(127);
        }

        dup2(nulo, STDIN_FILENO);
        dup2(nulo, STDOUT_FILENO);
        dup2(pipefd[1], STDERR_FILENO);

        if (nulo > STDERR_FILENO) {
            close(nulo);
        }

        if (pipefd[1] > STDERR_FILENO) {
            close(pipefd[1]);
        }

        execvp(programa.c_str(), argv.data());

        const int error = errno;
        (void)!write(aux[1], &error, sizeof(error));
        _exit(127);
    }

    // Padre.
    close(aux[1]);
    close(pipefd[1]);

    // Refuerza el grupo antes de que el hijo haga exec. Si el hijo ya hizo
    // exec o ya cambió de grupo, EACCES es esperado y no es un error.
    setpgid(pid, pid);

    int errorExec = 0;
    ssize_t leidos;

    do {
        leidos = read(aux[0], &errorExec, sizeof(errorExec));
    } while (leidos == -1 && errno == EINTR);

    close(aux[0]);

    if (leidos < 0) {
        close(pipefd[0]);
        kill(pid, SIGKILL);
        waitpid(pid, nullptr, 0);
        throw runtime_error("No se pudo comprobar el lanzamiento del proceso");
    }

    if (leidos > 0) {
        close(pipefd[0]);
        waitpid(pid, nullptr, 0);
        throw runtime_error(
            "No se pudo ejecutar el programa '" + programa +
            "': " + std::strerror(errorExec)
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

string obtenerNombreSenal(int senal) {
    switch (senal) {
        case SIGHUP: return "SIGHUP";
        case SIGINT: return "SIGINT";
        case SIGQUIT: return "SIGQUIT";
        case SIGILL: return "SIGILL";
        case SIGTRAP: return "SIGTRAP";
        case SIGABRT: return "SIGABRT";
        case SIGBUS: return "SIGBUS";
        case SIGFPE: return "SIGFPE";
        case SIGKILL: return "SIGKILL";
        case SIGUSR1: return "SIGUSR1";
        case SIGSEGV: return "SIGSEGV";
        case SIGUSR2: return "SIGUSR2";
        case SIGPIPE: return "SIGPIPE";
        case SIGALRM: return "SIGALRM";
        case SIGTERM: return "SIGTERM";
        case SIGCHLD: return "SIGCHLD";
        case SIGCONT: return "SIGCONT";
        case SIGSTOP: return "SIGSTOP";
        case SIGTSTP: return "SIGTSTP";
        case SIGTTIN: return "SIGTTIN";
        case SIGTTOU: return "SIGTTOU";
        case SIGURG: return "SIGURG";
        case SIGXCPU: return "SIGXCPU";
        case SIGXFSZ: return "SIGXFSZ";
        case SIGVTALRM: return "SIGVTALRM";
        case SIGPROF: return "SIGPROF";
        case SIGWINCH: return "SIGWINCH";
        case SIGIO: return "SIGIO";
        case SIGSYS: return "SIGSYS";
        default: return "SIG_" + std::to_string(senal);
    }
}

bool esperarProceso(pid_t pid, ResultadoProceso& resultado) {
    resultado = ResultadoProceso{};
    int estado = 0;

    while (true) {
        pid_t res = waitpid(pid, &estado, 0);

        if (res == -1) {
            if (errno == EINTR) {
                continue;
            }

            resultado.completado = false;
            resultado.codigoSalida = -1;
            return false;
        }

        break;
    }

    resultado.completado = true;

    if (WIFEXITED(estado)) {
        resultado.salidoNormalmente = true;
        resultado.codigoSalida = WEXITSTATUS(estado);
        return true;
    }

    if (WIFSIGNALED(estado)) {
        resultado.terminadoPorSenal = true;
        resultado.numeroSenal = WTERMSIG(estado);
        resultado.codigoSalida = -resultado.numeroSenal;
        resultado.nombreSenal = obtenerNombreSenal(resultado.numeroSenal);
        const char* desc = strsignal(resultado.numeroSenal);
        resultado.descripcionSenal = (desc != nullptr && desc[0] != '\0') ? desc : "señal desconocida";
#ifdef WCOREDUMP
        resultado.coreDump = WCOREDUMP(estado);
#endif
        return true;
    }

    resultado.codigoSalida = -1;
    return false;
}

bool esperarProceso(pid_t pid, int& codigoSalida) {
    ResultadoProceso res;
    bool exito = esperarProceso(pid, res);
    codigoSalida = res.codigoSalida;
    return exito;
}

bool terminarProceso(pid_t pid) {
    return pid > 0 && kill(pid, SIGTERM) == 0;
}
