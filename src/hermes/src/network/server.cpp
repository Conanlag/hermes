#include "network.h"
#include "config.h"
#include "network_access.h"
#include "network_protocol.h"
#include "scheduler.h"
#include <chrono>
#include <memory>
#include <vector>
#include <algorithm>

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
        struct sigaction ignorar{};
        ignorar.sa_handler = SIG_IGN;
        sigemptyset(&ignorar.sa_mask);
        if (sigaction(SIGPIPE, &ignorar, &anteriorPipe) == -1) {
            sigaction(SIGINT, &anteriorInt, nullptr);
            sigaction(SIGTERM, &anteriorTerm, nullptr);
            throw std::runtime_error("No se pudo instalar SIGPIPE");
        }
    }
    ~Senales() {
        sigaction(SIGINT, &anteriorInt, nullptr);
        sigaction(SIGTERM, &anteriorTerm, nullptr);
        sigaction(SIGPIPE, &anteriorPipe, nullptr);
    }
private:
    struct sigaction anteriorInt{}, anteriorTerm{}, anteriorPipe{};
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
        const auto remota = cargarConfiguracionRemota();
        if (remota.habilitada) {
            // Antes de abrir sockets: el daemon no debe heredar conexiones TCP.
            iniciarSchedulerSiNecesario(config.trabajosMaximos);
        }
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
        using Reloj = std::chrono::steady_clock;
        struct Cliente {
            explicit Cliente(int fd) : socket(fd), limite(Reloj::now() + std::chrono::seconds(3)) {}
            Descriptor socket;
            short esperado = POLLIN;
            std::string identidad;
            const PermisosRemotos* permisos = nullptr;
            std::string entrada, salida;
            std::size_t enviado = 0;
            Reloj::time_point limite;
            bool cerrado = false;
        };
        std::vector<std::unique_ptr<Cliente>> clientes;
        while (!detener) {
            std::vector<pollfd> eventos{{servidor.valor, POLLIN, 0}};
            for (const auto& cliente : clientes)
                eventos.push_back({cliente->socket.valor,
                    cliente->esperado, 0});
            const int resultado = poll(eventos.data(), eventos.size(), 100);
            if (resultado < 0) {
                if (errno == EINTR) continue;
                fallo("poll");
            }
            if (eventos[0].revents & (POLLERR | POLLHUP | POLLNVAL))
                throw std::runtime_error("Error en el socket de escucha");
            auto responder = [](Cliente& cliente, std::string respuesta) {
                cliente.salida = std::move(respuesta);
                cliente.esperado = POLLOUT;
                cliente.limite = Reloj::now() + std::chrono::seconds(3);
            };
            for (std::size_t i = 0; i < clientes.size(); ++i) {
                auto& cliente = *clientes[i];
                const auto evento = eventos[i + 1].revents;
                if (evento & (POLLERR | POLLNVAL)) { cliente.cerrado = true; continue; }
                if (cliente.salida.empty() && (evento & (cliente.esperado | POLLHUP))) {
                    char buffer[4096];
                    const auto leidos = recv(cliente.socket.valor, buffer, sizeof(buffer), 0);
                    if (leidos > 0) {
                        cliente.entrada.append(buffer, static_cast<std::size_t>(leidos));
                        const auto fin = cliente.entrada.find('\n');
                        if ((fin == std::string::npos && cliente.entrada.size() > MAX_MENSAJE_RED) ||
                            (fin != std::string::npos && fin > MAX_MENSAJE_RED))
                            responder(cliente, errorProtocolo("MESSAGE_TOO_LARGE"));
                        else if (fin != std::string::npos)
                            responder(cliente, procesarSolicitudRed(cliente.entrada.substr(0, fin), cliente.identidad, cliente.permisos));
                    } else if (leidos == 0) {
                        responder(cliente, errorProtocolo("INCOMPLETE_MESSAGE"));
                    } else if (errno != EINTR && errno != EAGAIN && errno != EWOULDBLOCK)
                        cliente.cerrado = true;
                }
                if (!cliente.salida.empty() && (evento & cliente.esperado)) {
                    const auto enviados = send(cliente.socket.valor,
                        cliente.salida.data() + cliente.enviado,
                        cliente.salida.size() - cliente.enviado, MSG_NOSIGNAL);
                    if (enviados > 0) {
                        cliente.enviado += static_cast<std::size_t>(enviados);
                        if (cliente.enviado == cliente.salida.size()) cliente.cerrado = true;
                    } else if (enviados == 0 || (errno != EINTR && errno != EAGAIN && errno != EWOULDBLOCK))
                        cliente.cerrado = true;
                }
                if (Reloj::now() >= cliente.limite) {
                    if (cliente.salida.empty()) responder(cliente, errorProtocolo("REQUEST_TIMEOUT"));
                    else cliente.cerrado = true;
                }
            }
            clientes.erase(std::remove_if(clientes.begin(), clientes.end(),
                [](const auto& cliente) { return cliente->cerrado; }), clientes.end());
            if (eventos[0].revents & POLLIN) {
                sockaddr_in origen{};
                socklen_t longitud = sizeof(origen);
                Descriptor conexion(accept4(servidor.valor, reinterpret_cast<sockaddr*>(&origen),
                                           &longitud, SOCK_CLOEXEC | SOCK_NONBLOCK));
                if (conexion.valor < 0) {
                    if (errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK || errno == ECONNABORTED)
                        continue;
                    fallo("accept");
                }
                char ip[INET_ADDRSTRLEN]{};
                if (!inet_ntop(AF_INET, &origen.sin_addr, ip, sizeof(ip)) ||
                    !origenRedPermitido(ip, config.redesPermitidas) || clientes.size() >= 32)
                    continue;
                auto cliente = std::make_unique<Cliente>(conexion.valor);
                conexion.valor = -1;
                if (remota.habilitada) {
                    const auto identidad = remota.identidades.find(ip);
                    if (identidad != remota.identidades.end()) {
                        cliente->identidad = "tcp-" + identidad->second;
                        cliente->permisos = &remota.clientes.at(identidad->second);
                    }
                }
                clientes.push_back(std::move(cliente));
            }
        }
        std::cout << "Hermes Red detenido" << std::endl;
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "No se pudo iniciar o mantener Hermes Red: " << e.what() << '\n';
        return 1;
    }
}
}
