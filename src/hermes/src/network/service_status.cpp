#include "network_status.h"
#include "config.h"
#include "data_paths.h"

#include <cerrno>
#include <fcntl.h>
#include <unistd.h>
#include <stdexcept>

namespace hermes {
namespace {
struct Descriptor {
    int valor;
    ~Descriptor() { if (valor >= 0) close(valor); }
};
}

RegistroServidorRed::RegistroServidorRed(const std::string& interfaz, int puerto) {
    Descriptor archivo{open(rutaDatos("network-service.lock").c_str(),
                            O_RDWR | O_CREAT | O_CLOEXEC, 0600)};
    if (archivo.valor == -1)
        throw std::runtime_error("No se pudo abrir el registro de Hermes Red");
    // Los locks POSIX pertenecen al proceso y no se heredan con fork(): un
    // proceso hijo no debe mantener activa la red tras la muerte del servidor.
    struct flock bloqueo{};
    bloqueo.l_type = F_WRLCK;
    bloqueo.l_whence = SEEK_SET;
    if (fcntl(archivo.valor, F_SETLK, &bloqueo) == -1)
        throw std::runtime_error("No se pudo registrar Hermes Red; otro servidor puede estar activo");
    const std::string registro = nlohmann::json({{"interfaz", interfaz}, {"puerto", puerto}}).dump();
    if (ftruncate(archivo.valor, 0) == -1)
        throw std::runtime_error("No se pudo preparar el registro de Hermes Red");
    std::size_t escrito = 0;
    while (escrito < registro.size()) {
        const auto n = write(archivo.valor, registro.data() + escrito, registro.size() - escrito);
        if (n == -1 && errno == EINTR) continue;
        if (n <= 0) throw std::runtime_error("No se pudo escribir el registro de Hermes Red");
        escrito += static_cast<std::size_t>(n);
    }
    descriptor = archivo.valor;
    archivo.valor = -1;
}

RegistroServidorRed::~RegistroServidorRed() {
    if (descriptor >= 0) close(descriptor);
}

nlohmann::json consultarEstadoServidorRed() {
    const auto config = cargarConfiguracion();
    nlohmann::json estado = {{"activo", false}, {"interfaz", nullptr}, {"puerto", nullptr},
        {"configurado", {{"interfaz", config.interfaz}, {"puerto", config.puerto}}}};
    Descriptor archivo{open(rutaDatos("network-service.lock").c_str(), O_RDONLY | O_CLOEXEC)};
    if (archivo.valor == -1) {
        if (errno == ENOENT) return estado;
        throw std::runtime_error("No se pudo consultar el registro de Hermes Red");
    }
    // Nunca se confía en la mera existencia del archivo: también queda tras SIGKILL.
    struct flock bloqueo{};
    bloqueo.l_type = F_WRLCK;
    bloqueo.l_whence = SEEK_SET;
    if (fcntl(archivo.valor, F_GETLK, &bloqueo) == -1)
        throw std::runtime_error("No se pudo consultar el bloqueo de Hermes Red");
    if (bloqueo.l_type == F_UNLCK) return estado;
    char contenido[1024];
    ssize_t n;
    do { n = pread(archivo.valor, contenido, sizeof(contenido), 0); }
    while (n == -1 && errno == EINTR);
    if (n <= 0 || n == static_cast<ssize_t>(sizeof(contenido)))
        throw std::runtime_error("Registro de Hermes Red no disponible; reintente la consulta");
    const auto registro = nlohmann::json::parse(contenido, contenido + n, nullptr, false);
    if (!registro.is_object() || !registro.contains("interfaz") ||
        !registro["interfaz"].is_string() ||
        !interfazValida(registro["interfaz"].get<std::string>()) ||
        !registro.contains("puerto") || !registro["puerto"].is_number_integer() ||
        registro["puerto"] < 1024 || registro["puerto"] > 65535)
        throw std::runtime_error("Registro de Hermes Red invalido; reintente la consulta");
    estado["activo"] = true;
    estado["interfaz"] = registro["interfaz"];
    estado["puerto"] = registro["puerto"];
    return estado;
}
}
