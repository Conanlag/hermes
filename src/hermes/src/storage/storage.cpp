#include "storage.h"
#include "data_paths.h"
#include "event_log.h"

#include <atomic>
#include <cerrno>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <stdexcept>
#include <string>

#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>
#include <cstdint>


using namespace std;


namespace {
std::mutex mutexStorage;

constexpr const char* NOMBRE_JOBS = "jobs.json";
constexpr const char* NOMBRE_RESPALDO = "jobs.json.bak";

class BloqueoArchivo {
public:
    BloqueoArchivo() {
        ruta = hermes::rutaDatos("jobs.lock");
        descriptor = open(
            ruta.c_str(),
            O_RDWR | O_CREAT | O_CLOEXEC,
            0644
        );

        if (descriptor == -1) {
            throw runtime_error("No se pudo abrir jobs.lock");
        }

        if (flock(descriptor, LOCK_EX) == -1) {
            close(descriptor);
            descriptor = -1;
            throw runtime_error("No se pudo bloquear jobs.lock");
        }
    }

    ~BloqueoArchivo() {
        if (descriptor != -1) {
            flock(descriptor, LOCK_UN);
            close(descriptor);
        }
    }

    BloqueoArchivo(const BloqueoArchivo&) = delete;
    BloqueoArchivo& operator=(const BloqueoArchivo&) = delete;

private:
    int descriptor = -1;
    string ruta;
};

// Lee y valida un archivo de Jobs. Lanza si no existe, si no parsea o si no
// contiene un arreglo: quien llama decide si prueba el respaldo o aborta.
json leerArreglo(const string& ruta) {
    ifstream archivo(ruta);

    if (!archivo.is_open()) {
        throw runtime_error("No se pudo abrir " + ruta);
    }

    json jobs;
    archivo >> jobs;

    if (!jobs.is_array()) {
        throw runtime_error(ruta + " no contiene un arreglo");
    }

    return jobs;
}

bool archivoValido(const string& ruta) {
    try {
        leerArreglo(ruta);
        return true;
    } catch (...) {
        return false;
    }
}

void guardarAtomico(const json& jobs);

json leerSinBloqueo() {
    const string ruta = hermes::rutaDatos(NOMBRE_JOBS);
    const string respaldo = hermes::rutaDatos(NOMBRE_RESPALDO);

    string errorPrincipal;

    try {
        return leerArreglo(ruta);
    } catch (const exception& error) {
        errorPrincipal = error.what();
    }

    try {
        json jobs = leerArreglo(respaldo);

        hermes::EventLog::log_event_system(
            hermes::EventLevel::WARN,
            "jobs.json recuperado desde jobs.json.bak",
            {
                {"archivo", NOMBRE_JOBS},
                {"detalle", errorPrincipal}
            }
        );

        // El lock ya está tomado: se repara jobs.json desde el respaldo en la
        // misma transacción para que el estado se auto-cure y no se dependa
        // de un fallback permanente. Si la reparación falla, la lectura sigue
        // siendo válida y el siguiente arranque lo reintenta.
        try {
            guardarAtomico(jobs);
        } catch (...) {
            // El respaldo sigue disponible.
        }

        return jobs;
    } catch (const exception& errorRespaldo) {
        // Sin jobs.json ni respaldo válido no se inventa un arreglo vacío:
        // un estado vacío silencioso haría perder todos los Jobs.
        throw runtime_error(
            string("No se pudo leer jobs.json ni jobs.json.bak: ") +
            errorPrincipal + " / " + errorRespaldo.what()
        );
    }
}

void escribirTodo(int descriptor, const string& contenido) {
    size_t escrito = 0;

    while (escrito < contenido.size()) {
        const ssize_t n = write(
            descriptor,
            contenido.data() + escrito,
            contenido.size() - escrito
        );

        if (n == -1) {
            if (errno == EINTR) {
                continue;
            }

            const int error = errno;

            throw runtime_error(
                string("No se pudo escribir el archivo temporal: ") +
                strerror(error)
            );
        }

        if (n == 0) {
            // Sin progreso no hay bucle válido: se falla en vez de colgarse.
            throw runtime_error(
                "La escritura del archivo temporal no avanzó"
            );
        }

        escrito += static_cast<size_t>(n);
    }
}

// Hace durable la entrada de directorio creada por rename()/link(). Sin este
// fsync un corte de energía puede dejar el contenido escrito pero la entrada
// anterior, o incluso ninguna.
void sincronizarDirectorio(const string& ruta) {
    const string directorio =
        std::filesystem::path(ruta).parent_path().string();

    const int descriptor = open(
        directorio.c_str(),
        O_RDONLY | O_DIRECTORY | O_CLOEXEC
    );

    if (descriptor == -1) {
        const int error = errno;

        throw runtime_error(
            string("No se pudo abrir el directorio de datos: ") +
            strerror(error)
        );
    }

    if (fsync(descriptor) == -1) {
        const int error = errno;
        close(descriptor);

        throw runtime_error(
            string("No se pudo sincronizar el directorio de datos: ") +
            strerror(error)
        );
    }

    close(descriptor);
}

// Refresca jobs.json.bak a partir de jobs.json con link(): es atómico, no
// copia bytes y nunca deja una ventana en la que falte el archivo principal.
//
// Se omite si jobs.json no parsea. Reemplazar un respaldo válido con el
// contenido corrupto del archivo principal destruiría la única copia buena.
void actualizarRespaldo(const string& ruta, const string& respaldo) {
    if (!archivoValido(ruta)) {
        return;
    }

    if (unlink(respaldo.c_str()) == -1 && errno != ENOENT) {
        const int error = errno;

        throw runtime_error(
            string("No se pudo retirar jobs.json.bak: ") +
            strerror(error)
        );
    }

    if (link(ruta.c_str(), respaldo.c_str()) == -1) {
        if (errno == ENOENT) {
            // Primera escritura: todavía no hay jobs.json que respaldar.
            return;
        }

        const int error = errno;

        throw runtime_error(
            string("No se pudo crear jobs.json.bak: ") +
            strerror(error)
        );
    }
}

void guardarAtomico(const json& jobs) {
    const string ruta = hermes::rutaDatos(NOMBRE_JOBS);
    const string respaldo = hermes::rutaDatos(NOMBRE_RESPALDO);

    // PID + contador: dos escrituras concurrentes nunca comparten temporal
    // aunque compartan proceso. O_EXCL convierte cualquier colisión en error
    // en vez de en una escritura sobre un archivo ajeno.
    static std::atomic<unsigned long long> contador{0};

    const string temporal =
        ruta + ".tmp." + to_string(getpid()) + "." +
        to_string(contador.fetch_add(1));

    const string contenido = jobs.dump(4) + '\n';

    int descriptor = open(
        temporal.c_str(),
        O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC,
        0644
    );

    if (descriptor == -1) {
        const int error = errno;

        throw runtime_error(
            string("No se pudo crear el archivo temporal: ") +
            strerror(error)
        );
    }

    bool renombrado = false;

    try {
        escribirTodo(descriptor, contenido);

        if (fsync(descriptor) == -1) {
            const int error = errno;

            throw runtime_error(
                string("No se pudo sincronizar el archivo temporal: ") +
                strerror(error)
            );
        }

        if (close(descriptor) == -1) {
            const int error = errno;
            descriptor = -1;

            throw runtime_error(
                string("No se pudo cerrar el archivo temporal: ") +
                strerror(error)
            );
        }

        descriptor = -1;

        actualizarRespaldo(ruta, respaldo);

        if (rename(temporal.c_str(), ruta.c_str()) == -1) {
            const int error = errno;

            throw runtime_error(
                string("No se pudo actualizar jobs.json: ") +
                strerror(error)
            );
        }

        renombrado = true;

        sincronizarDirectorio(ruta);
    } catch (...) {
        if (descriptor != -1) {
            close(descriptor);
        }

        if (!renombrado) {
            unlink(temporal.c_str());
        }

        throw;
    }
}
} // namespace anónimo

json leerJobsSeguros() {
    lock_guard<std::mutex> guardia(mutexStorage);
    BloqueoArchivo bloqueo;
    return leerSinBloqueo();
}

bool modificarJobsSeguros(const std::function<bool(json&)>& funcion) {
    lock_guard<std::mutex> guardia(mutexStorage);
    BloqueoArchivo bloqueo;

    json jobs = leerSinBloqueo();

    if (!funcion(jobs)) {
        return false;
    }

    guardarAtomico(jobs);
    return true;
}

void limpiarTemporalesDeJobs() {
    lock_guard<std::mutex> guardia(mutexStorage);
    BloqueoArchivo bloqueo;

    namespace fs = std::filesystem;

    const fs::path ruta = hermes::rutaDatos(NOMBRE_JOBS);
    const fs::path directorio = ruta.parent_path();
    const string prefijo = ruta.filename().string() + ".tmp.";

    std::error_code error;
    fs::directory_iterator iterador(directorio, error);

    if (error) {
        throw runtime_error(
            "No se pudo inspeccionar el directorio de datos: " +
            error.message()
        );
    }

    for (const auto& entrada : iterador) {
        const string nombre = entrada.path().filename().string();

        if (nombre.rfind(prefijo, 0) != 0) {
            continue;
        }

        std::error_code errorEliminar;
        fs::remove(entrada.path(), errorEliminar);

        // Un temporal que no se puede borrar es inofensivo: no participa en
        // la lectura y se reintenta en el siguiente arranque. No se aborta
        // el arranque por él.
    }
}
