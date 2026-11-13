#include "network.h"
#include "config.h"
#include "network_access.h"

#include <arpa/inet.h>
#include <cerrno>
#include <csignal>
#include <cstring>
#include <iostream>
#include <poll.h>
#include <stdexcept>
#include <sys/socket.h>
#include <unistd.h>

namespace {
volatile std::sig_atomic_t detener = 0;
void solicitarCierre(int) { detener = 1; }

class Descriptor {
public:
    explicit Descriptor(int valor) : valor(valor) {}
    ~Descriptor() { if (valor >= 0) close(valor); }
    Descriptor(const Descriptor&) = delete;
    Descriptor& operator=(const Descriptor&) = delete;
    int valor;
};

class Senales {
public:
    Senales() {
        struct sigaction accion{};
        accion.sa_handler = solicitarCierre;
        sigemptyset(&accion.sa_mask);
        if (sigaction(SIGINT, &accion, &anteriorInt) == -1)
            throw std::runtime_error("No se pudo instalar SIGINT");
        if (sigaction(SIGTERM, &accion, &anteriorTerm) == -1) {
            sigaction(SIGINT, &anteriorInt, nullptr);
            throw std::runtime_error("No se pudo instalar SIGTERM");
        }
    }
    ~Senales() {
        sigaction(SIGINT, &anteriorInt, nullptr);
        sigaction(SIGTERM, &anteriorTerm, nullptr);
    }
private:
    struct sigaction anteriorInt{}, anteriorTerm{};
};

void fallo(const char* operacion) {
    throw std::runtime_error(std::string(operacion) + ": " + std::strerror(errno));
}
}

namespace hermes {
int iniciarServidorRed() {
    try {
        const auto config = cargarConfiguracion();
        if (!config.reglasRedValidas)
            throw std::runtime_error("redes_permitidas inválida; corrija config.json antes de iniciar");
        sockaddr_in direccion{};
        direccion.sin_family = AF_INET;
        direccion.sin_port = htons(static_cast<unsigned short>(config.puerto));
        if (inet_pton(AF_INET, config.interfaz.c_str(), &direccion.sin_addr) != 1)
            throw std::runtime_error("Interfaz IPv4 inválida");

        Descriptor servidor(socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0));
        if (servidor.valor == -1) fallo("socket");
        int reutilizar = 1;
        if (setsockopt(servidor.valor, SOL_SOCKET, SO_REUSEADDR,
                       &reutilizar, sizeof(reutilizar)) == -1) fallo("setsockopt");
        if (bind(servidor.valor, reinterpret_cast<sockaddr*>(&direccion), sizeof(direccion)) == -1)
            fallo("No se pudo escuchar en la interfaz y puerto configurados");
        if (listen(servidor.valor, 10) == -1) fallo("listen");

        detener = 0;
        Senales senales;
        std::cout << "Hermes Red escuchando en " << config.interfaz << ':' << config.puerto
                  << " (primer plano; Ctrl+C para detener)" << std::endl;
        // Esta fase prueba la escucha; no recibe ni ejecuta instrucciones remotas.
        // Cada conexión recibe un diagnóstico acotado y se cierra sin bloquear.
        constexpr char respuesta[] =
            "{\"version\":1,\"ok\":false,\"error\":\"REMOTE_OPERATIONS_UNAVAILABLE\"}\n";
        while (!detener) {
            pollfd evento{servidor.valor, POLLIN, 0};
            const int resultado = poll(&evento, 1, 500);
            if (resultado < 0) {
                if (errno == EINTR) continue;
                fallo("poll");
            }
            if (evento.revents & (POLLERR | POLLHUP | POLLNVAL))
                throw std::runtime_error("Error en el socket de escucha");
            if (!(evento.revents & POLLIN)) continue;
            sockaddr_in origen{};
            socklen_t longitud = sizeof(origen);
            Descriptor cliente(accept4(servidor.valor, reinterpret_cast<sockaddr*>(&origen),
                                        &longitud, SOCK_CLOEXEC | SOCK_NONBLOCK));
            if (cliente.valor < 0) {
                if (errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK || errno == ECONNABORTED)
                    continue;
                fallo("accept");
            }
            char ip[INET_ADDRSTRLEN]{};
            if (!inet_ntop(AF_INET, &origen.sin_addr, ip, sizeof(ip)) ||
                !origenRedPermitido(ip, config.redesPermitidas)) {
                // Cierre antes de leer solicitudes o enviar información del servicio.
                continue;
            }
            // MSG_NOSIGNAL impide que un cliente desconectado termine el servicio.
            // El diagnóstico es informativo: no se garantiza su entrega completa.
            (void)send(cliente.valor, respuesta, sizeof(respuesta) - 1, MSG_NOSIGNAL);
        }
        std::cout << "Hermes Red detenido" << std::endl;
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "No se pudo iniciar o mantener Hermes Red: " << e.what() << '\n';
        return 1;
    }
}
}
