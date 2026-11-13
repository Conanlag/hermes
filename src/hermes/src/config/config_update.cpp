#include "config.h"
#include "network_access.h"

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
        const std::string ruta = hermes::rutaConfiguracion("config.lock");
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

namespace {

void validarRango(
    int valor,
    int minimo,
    int maximo,
    const std::string& clave
) {
    if (valor < minimo || valor > maximo) {
        throw std::invalid_argument(
            clave + " debe estar entre " +
            std::to_string(minimo) + " y " +
            std::to_string(maximo) + "."
        );
    }
}

} // namespace

void actualizarConfiguracion(const CambiosConfiguracion& cambios) {
    // Se valida todo antes de abrir el archivo: si una de las claves está fuera
    // de rango, no se escribe ninguna.
    if (cambios.trabajosMaximos) {
        validarRango(
            cambios.valorTrabajosMaximos,
            MIN_TRABAJOS_MAXIMOS,
            MAX_TRABAJOS_MAXIMOS,
            "trabajos_maximos"
        );
    }

    if (cambios.maxCola) {
        validarRango(
            cambios.valorMaxCola,
            MIN_MAX_COLA,
            MAX_MAX_COLA,
            "max_cola"
        );
    }

    if (cambios.puerto) validarRango(cambios.valorPuerto, 1, 65535, "puerto");
    if (cambios.interfaz && !interfazValida(cambios.valorInterfaz))
        throw std::invalid_argument("interfaz debe ser una dirección IPv4 literal.");
    if (cambios.directorioDatos && !directorioDatosValido(cambios.valorDirectorioDatos))
        throw std::invalid_argument("directorio_datos debe ser una ruta absoluta.");

    if (cambios.redesPermitidas) {
        for (const auto& regla : cambios.valorRedesPermitidas)
            if (!reglaRedValida(regla))
                throw std::invalid_argument("redes_permitidas contiene una IP o red no permitida.");
    }

    BloqueoConfiguracion bloqueo;
    const std::string ruta = rutaConfiguracion();
    std::ifstream archivo(ruta);
    json datos = json::object();

    if (archivo.is_open()) {
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
    } else if (std::filesystem::exists(ruta)) {
        // El archivo existe pero no se puede leer: no se sobrescribe.
        throw std::runtime_error("No se pudo abrir config.json");
    }

    if (cambios.trabajosMaximos) {
        datos["trabajos_maximos"] = cambios.valorTrabajosMaximos;
    }

    if (cambios.maxCola) {
        datos["max_cola"] = cambios.valorMaxCola;
    }

    if (cambios.directorioDatos) datos["directorio_datos"] = cambios.valorDirectorioDatos;
    if (cambios.interfaz) datos["interfaz"] = cambios.valorInterfaz;
    if (cambios.puerto) datos["puerto"] = cambios.valorPuerto;
    if (cambios.redesPermitidas) datos["redes_permitidas"] = cambios.valorRedesPermitidas;
    guardarAtomico(ruta, datos);

    if (cambios.trabajosMaximos) {
        EventLog::log_event_system(
            EventLevel::INFO,
            "Configuración actualizada",
            {
                {"clave", "trabajos_maximos"},
                {"valor", cambios.valorTrabajosMaximos}
            }
        );
    }

    if (cambios.maxCola) {
        EventLog::log_event_system(
            EventLevel::INFO,
            "Configuración actualizada",
            {
                {"clave", "max_cola"},
                {"valor", cambios.valorMaxCola}
            }
        );
    }
}

void establecerTrabajosMaximos(int trabajosMaximos) {
    CambiosConfiguracion cambios;
    cambios.trabajosMaximos = true;
    cambios.valorTrabajosMaximos = trabajosMaximos;
    actualizarConfiguracion(cambios);
}

void establecerMaxCola(int maxCola) {
    CambiosConfiguracion cambios;
    cambios.maxCola = true;
    cambios.valorMaxCola = maxCola;
    actualizarConfiguracion(cambios);
}

} // namespace hermes
