#include "storage.h"
#include "data_paths.h"

#include <fstream>
#include <mutex>
#include <stdexcept>
#include <string>

#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>
#include <cstdint>


namespace {
std::mutex mutexStorage;

class BloqueoArchivo {
public:
    BloqueoArchivo() {
        ruta = hermes::rutaDatos("jobs.lock");
        descriptor = open(ruta.c_str(), O_RDWR | O_CREAT, 0644);

        if (descriptor == -1) {
            throw std::runtime_error("No se pudo abrir jobs.lock");
        }

        if (flock(descriptor, LOCK_EX) == -1) {
            close(descriptor);
            descriptor = -1;
            throw std::runtime_error("No se pudo bloquear jobs.lock");
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
    std::string ruta;
};

json leerSinBloqueo() {
    std::ifstream archivo(hermes::rutaDatos("jobs.json"));

    if (!archivo.is_open()) {
        throw std::runtime_error("No se pudo abrir jobs.json");
    }

    json jobs;
    archivo >> jobs;

    if (!jobs.is_array()) {
        throw std::runtime_error("jobs.json no contiene un arreglo");
    }

    return jobs;
}

void guardarAtomico(const json& jobs) {
    const std::string ruta = hermes::rutaDatos("jobs.json");
    const std::string temporal =
        ruta + ".tmp." + std::to_string(getpid()) + "." +
        std::to_string(reinterpret_cast<std::uintptr_t>(&jobs));

    {
        std::ofstream archivo(temporal, std::ios::trunc);

        if (!archivo.is_open()) {
            throw std::runtime_error("No se pudo crear el archivo temporal");
        }

        archivo << jobs.dump(4) << '\n';
        archivo.flush();

        if (!archivo.good()) {
            archivo.close();
            unlink(temporal.c_str());
            throw std::runtime_error("No se pudo escribir el archivo temporal");
        }
    }

    if (rename(temporal.c_str(), ruta.c_str()) == -1) {
        unlink(temporal.c_str());
        throw std::runtime_error("No se pudo actualizar jobs.json");
    }
}
}

json leerJobsSeguros() {
    std::lock_guard<std::mutex> guardia(mutexStorage);
    BloqueoArchivo bloqueo;
    return leerSinBloqueo();
}

bool modificarJobsSeguros(const std::function<bool(json&)>& funcion) {
    std::lock_guard<std::mutex> guardia(mutexStorage);
    BloqueoArchivo bloqueo;

    json jobs = leerSinBloqueo();

    if (!funcion(jobs)) {
        return false;
    }

    guardarAtomico(jobs);
    return true;
}