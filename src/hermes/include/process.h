#ifndef PROCESS_H
#define PROCESS_H

#include <string>
#include <vector>
#include <sys/types.h>

using std::string;
using std::vector;

/**
 * Identidad mínima de un proceso Linux.
 *
 * boot_id descarta la reutilización de un PID tras reiniciar la máquina;
 * pidInicio (campo 22 de /proc/<pid>/stat) descarta la reutilización dentro
 * del mismo arranque; pgrp confirma que el grupo que se va a señalar es suyo;
 * sid identifica la sesión privada del demonio y permite reconocer a los
 * miembros del grupo cuando el líder ya no existe (Corte 1.1 de RF-13).
 */
struct IdentidadProceso {
    string bootId;
    unsigned long long pidInicio = 0;
    pid_t pgrp = 0;
    pid_t sid = 0;
};

/**
 * Lee /proc/sys/kernel/random/boot_id.
 *
 * @return true si el valor se leyó y no está vacío.
 */
bool leerBootId(string& bootId);

/**
 * Lee la identidad de un proceso desde /proc/<pid>/stat.
 *
 * @return false si el proceso no existe o el archivo no se puede interpretar.
 */
bool leerIdentidadProceso(pid_t pid, IdentidadProceso& identidad);

/**
 * Comprueba las tres condiciones de identidad de la sección 2.5:
 * boot_id actual == guardado, starttime == pid_inicio guardado y
 * pgrp del proceso == PID guardado.
 *
 * @return true solo si las tres coinciden.
 */
bool identidadCoincide(
    pid_t pid,
    const string& bootIdEsperado,
    unsigned long long pidInicioEsperado
);

/**
 * Indica si el proceso existe y no está en estado zombie ('Z').
 */
bool procesoVivo(pid_t pid);

/**
 * Resultado de comprobar los miembros vivos de un grupo sin líder.
 */
enum class EstadoGrupoProceso {
    Inexistente,
    Vivo,
    NoVerificable
};

/**
 * Comprueba si queda algún proceso vivo del grupo `pgid` que pertenezca a la
 * sesión `sid`.
 *
 * Se usa cuando el líder del grupo ya no existe: el `pgid` sigue siendo
 * válido mientras queden miembros, y el `sid` evita confundir el grupo con
 * un PID reciclado. Los zombies no cuentan como vivos.
 *
 * @return `Inexistente` si no quedan miembros vivos; `Vivo` si hay al menos
 *         uno; `NoVerificable` si /proc no se puede leer. En este último caso
 *         no se debe señalizar el grupo ni afirmar que terminó.
 */
EstadoGrupoProceso estadoGrupoProceso(pid_t pgid, pid_t sid);

/**
 * Envía una señal a un grupo de procesos completo.
 *
 * @return true si la señal se entregó o el grupo ya no existe.
 */
bool senalizarGrupoProceso(pid_t pgid, int senal);

/**
 * Termina un grupo de procesos: SIGTERM, ventana de gracia y SIGKILL.
 *
 * @return true si el grupo ya no está vivo al terminar.
 */
bool terminarGrupoProceso(pid_t pgid, int tiempoGraciaSegundos = 5);

/**
 * Crea un proceso Linux y ejecuta el programa indicado.
 *
 * El hijo se crea en su propio grupo de procesos (setpgid) y con
 * PR_SET_PDEATHSIG=SIGKILL. El stderr del proceso se redirige a un pipe para
 * que Hermes pueda procesarlo.
 *
 * @param programa Nombre o ruta del programa.
 * @param argumentos Argumentos del programa.
 * @param pipeStderr Descriptor de lectura del pipe de stderr.
 *
 * @return PID del proceso creado.
 *
 * @throws std::runtime_error si fork(), pipe() o exec fallan.
 */
pid_t iniciarProceso(
    const string& programa,
    const vector<string>& argumentos,
    int& pipeStderr
);


/**
 * Resultado detallado de la terminación de un proceso hijo (RF-29).
 */
struct ResultadoProceso {
    bool completado = false;
    bool salidoNormalmente = false;
    int codigoSalida = 0;
    bool terminadoPorSenal = false;
    int numeroSenal = 0;
    string nombreSenal;
    string descripcionSenal;
    bool coreDump = false;
};

/**
 * Obtiene el nombre simbólico de una señal POSIX (ej. SIGSEGV, SIGKILL).
 */
string obtenerNombreSenal(int senal);

/**
 * Espera a que termine un proceso con diagnóstico estructurado (RF-29).
 *
 * @param pid PID del proceso.
 * @param resultado Estructura donde se guarda el resultado detallado.
 *
 * @return true si se pudo cosechar y diagnosticar el proceso correctamente.
 */
bool esperarProceso(
    pid_t pid,
    ResultadoProceso& resultado
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

bool escalarCancelacionProceso(pid_t pid, int tiempoGraciaSegundos = 5);

#endif
