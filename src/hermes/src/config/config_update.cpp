#include "config.h"

#include "data_paths.h"
#include "event_log.h"

#include <atomic>
#include <cerrno>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <stdexcept>
#include <string>

#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>

#include <nlohmann/json.hpp>

namespace {

using json = nlohmann::json;

class BloqueoConfiguracion {
public:
    BloqueoConfiguracion() {
        const std::string ruta = hermes::rutaDatos("config.lock");
        descriptor = open(
            ruta.c_str(),
            O_RDWR | O_CREAT | O_CLOEXEC,
            0644
        );

        if (descriptor == -1) {
            throw std::runtime_error("No se pudo abrir config.lock");
        }

        if (flock(descriptor, LOCK_EX) == -1) {
            const int error = errno;
            close(descriptor);
            descriptor = -1;
            throw std::runtime_error(
                std::string("No se pudo bloquear config.lock: ") +
                std::strerror(error)
            );
        }
    }

    ~BloqueoConfiguracion() {
        if (descriptor != -1) {
            flock(descriptor, LOCK_UN);
            close(descriptor);
        }
    }

    BloqueoConfiguracion(const BloqueoConfiguracion&) = delete;
    BloqueoConfiguracion& operator=(const BloqueoConfiguracion&) = delete;

private:
    int descriptor = -1;
};

void escribirTodo(int descriptor, const std::string& contenido) {
    std::size_t escrito = 0;

    while (escrito < contenido.size()) {
        const ssize_t resultado = write(
            descriptor,
            contenido.data() + escrito,
            contenido.size() - escrito
        );

        if (resultado == -1 && errno == EINTR) {
            continue;
        }

        if (resultado <= 0) {
            const int error = errno;
            throw std::runtime_error(
                std::string("No se pudo escribir config.json: ") +
                (resultado == 0 ? "escritura sin progreso" :
                                  std::strerror(error))
            );
        }

        escrito += static_cast<std::size_t>(resultado);
    }
}

void sincronizarDirectorio(const std::string& ruta) {
    const std::string directorio =
        std::filesystem::path(ruta).parent_path().string();
    const int descriptor = open(
        directorio.c_str(),
        O_RDONLY | O_DIRECTORY | O_CLOEXEC
    );

    if (descriptor == -1) {
        const int error = errno;
        throw std::runtime_error(
            std::string("No se pudo abrir el directorio de configuración: ") +
            std::strerror(error)
        );
    }

    if (fsync(descriptor) == -1) {
        const int error = errno;
        close(descriptor);
        throw std::runtime_error(
            std::string("No se pudo sincronizar el directorio de configuración: ") +
            std::strerror(error)
        );
    }

    close(descriptor);
}

void guardarAtomico(const std::string& ruta, const json& datos) {
    static std::atomic<unsigned long long> contador{0};
    const std::string temporal =
        ruta + ".tmp." + std::to_string(getpid()) + "." +
        std::to_string(contador.fetch_add(1));
    const std::string contenido = datos.dump(4) + '\n';
    int descriptor = open(
        temporal.c_str(),
        O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC,
        0644
    );

    if (descriptor == -1) {
        const int error = errno;
        throw std::runtime_error(
            std::string("No se pudo crear el archivo temporal de configuración: ") +
            std::strerror(error)
        );
    }

    bool renombrado = false;

    try {
        escribirTodo(descriptor, contenido);

        if (fsync(descriptor) == -1) {
            const int error = errno;
            throw std::runtime_error(
                std::string("No se pudo sincronizar config.json temporal: ") +
                std::strerror(error)
            );
        }

        if (close(descriptor) == -1) {
            const int error = errno;
            descriptor = -1;
            throw std::runtime_error(
                std::string("No se pudo cerrar config.json temporal: ") +
                std::strerror(error)
            );
        }
        descriptor = -1;

        if (rename(temporal.c_str(), ruta.c_str()) == -1) {
            const int error = errno;
            throw std::runtime_error(
                std::string("No se pudo reemplazar config.json: ") +
                std::strerror(error)
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

} // namespace

namespace hermes {

void establecerTrabajosMaximos(int trabajosMaximos) {
    if (trabajosMaximos < MIN_TRABAJOS_MAXIMOS ||
        trabajosMaximos > MAX_TRABAJOS_MAXIMOS) {
        throw std::invalid_argument(
            "trabajos_maximos debe estar entre " +
            std::to_string(MIN_TRABAJOS_MAXIMOS) + " y " +
            std::to_string(MAX_TRABAJOS_MAXIMOS) + "."
        );
    }

    BloqueoConfiguracion bloqueo;
    const std::string ruta = rutaDatos("config.json");
    std::ifstream archivo(ruta);

    if (!archivo.is_open()) {
        throw std::runtime_error("No se pudo abrir config.json");
    }

    json datos;
    try {
        archivo >> datos;
    } catch (const std::exception& error) {
        throw std::runtime_error(
            std::string("No se pudo interpretar config.json: ") +
            error.what()
        );
    }

    if (!datos.is_object()) {
        throw std::runtime_error(
            "config.json debe contener un objeto JSON."
        );
    }

    datos["trabajos_maximos"] = trabajosMaximos;
    guardarAtomico(ruta, datos);

    EventLog::log_event_system(
        EventLevel::INFO,
        "Configuración actualizada",
        {
            {"clave", "trabajos_maximos"},
            {"valor", trabajosMaximos}
        }
    );
}

} // namespace hermes
