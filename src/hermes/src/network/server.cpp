#include "network.h"
#include "config.h"
#include "network_access.h"
#include "network_protocol.h"
#include "scheduler.h"
#include "event_log.h"
#include <array>
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

using Reloj = std::chrono::steady_clock;

// Motivo de cierre de un cliente. Solo los motivos anómalos llegan a la
// bitácora: el cierre normal tras entregar la respuesta no se registra.
enum class Motivo : std::size_t {
    CierreNormal = 0,
    FinSinMensaje,
    TimeoutLectura,
    TimeoutEscritura,
    ErrorLectura,
    ErrorEscritura,
    ErrorSocket,
    ErrorInterno,
    OrigenRechazado,
    CupoExcedido,
    Total
};

constexpr std::size_t TOTAL_MOTIVOS = static_cast<std::size_t>(Motivo::Total);

const char* textoMotivo(Motivo motivo) {
    switch (motivo) {
        case Motivo::FinSinMensaje: return "FIN_SIN_MENSAJE";
        case Motivo::TimeoutLectura: return "TIMEOUT_LECTURA";
        case Motivo::TimeoutEscritura: return "TIMEOUT_ESCRITURA";
        case Motivo::ErrorLectura: return "ERROR_LECTURA";
        case Motivo::ErrorEscritura: return "ERROR_ESCRITURA";
        case Motivo::ErrorSocket: return "ERROR_SOCKET";
        case Motivo::ErrorInterno: return "ERROR_INTERNO";
        case Motivo::OrigenRechazado: return "ORIGEN_RECHAZADO";
        case Motivo::CupoExcedido: return "CUPO_EXCEDIDO";
        default: return "CIERRE_NORMAL";
    }
}

// Un aviso por motivo cada 60 s: EventLog hace open+flock+write+fsync+close
// por evento y el hilo de red no puede pagar ese coste por conexión rechazada.
bool avisoPermitido(Motivo motivo) {
    static std::array<Reloj::time_point, TOTAL_MOTIVOS> ultimo{};
    static std::array<bool, TOTAL_MOTIVOS> usado{};
    if (motivo == Motivo::CierreNormal) return false;
    const auto indice = static_cast<std::size_t>(motivo);
    const auto ahora = Reloj::now();
    if (usado[indice] && ahora - ultimo[indice] < std::chrono::seconds(60)) return false;
    usado[indice] = true;
    ultimo[indice] = ahora;
    return true;
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
        struct Cliente {
            explicit Cliente(int fd) : socket(fd), limite(Reloj::now() + std::chrono::seconds(3)) {}
            Descriptor socket;
            short esperado = POLLIN;
            std::string identidad;
            std::string ip;
            const PermisosRemotos* permisos = nullptr;
            std::string entrada, salida;
            std::size_t enviado = 0;
            Reloj::time_point limite;
            bool cerrado = false;
            Motivo motivo = Motivo::CierreNormal;
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
                cliente.enviado = 0;
                cliente.esperado = POLLOUT;
                cliente.limite = Reloj::now() + std::chrono::seconds(3);
            };
            // Error de cortesía: un solo intento de escritura y cierre inmediato.
            // Retener el descriptor esperando POLLOUT de un par desconectado agota
            // el cupo sin beneficio: el cliente oficial no interpreta
            // request_id: null (protocol.cpp:9 vs client.cpp:178).
            auto despedida = [](Cliente& cliente, const char* codigo, Motivo motivo) {
                cliente.salida = errorProtocolo(codigo);
                cliente.enviado = 0;
                if (!cliente.salida.empty())
                    (void)send(cliente.socket.valor, cliente.salida.data(),
                               cliente.salida.size(), MSG_NOSIGNAL);
                cliente.motivo = motivo;
                cliente.cerrado = true;
            };
            auto registrar = [](const Cliente& cliente) {
                if (!avisoPermitido(cliente.motivo)) return;
                EventLog::log_event_system(EventLevel::WARN, "Cliente desconectado", {
                    {"ip", cliente.ip},
                    {"motivo", textoMotivo(cliente.motivo)},
                    {"bytes_recibidos", cliente.entrada.size()}
                });
            };
            for (std::size_t i = 0; i < clientes.size(); ++i) {
                auto& cliente = *clientes[i];
                const auto evento = eventos[i + 1].revents;
                // Un fallo al atender a un cliente nunca puede terminar el
                // servicio: se cierra ese cliente y se sigue con el resto.
                try {
                    if (evento & (POLLERR | POLLNVAL)) {
                        cliente.motivo = Motivo::ErrorSocket;
                        cliente.cerrado = true;
                        continue;
                    }
                    // Hang up con respuesta pendiente: ya no hay par que lea.
                    if ((evento & POLLHUP) && !cliente.salida.empty()) {
                        cliente.motivo = Motivo::ErrorEscritura;
                        cliente.cerrado = true;
                        continue;
                    }
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
                            despedida(cliente, "INCOMPLETE_MESSAGE", Motivo::FinSinMensaje);
                        } else if (errno != EINTR && errno != EAGAIN && errno != EWOULDBLOCK) {
                            cliente.motivo = Motivo::ErrorLectura;
                            cliente.cerrado = true;
                        }
                    }
                    if (!cliente.cerrado && !cliente.salida.empty() && (evento & cliente.esperado)) {
                        const auto enviados = send(cliente.socket.valor,
                            cliente.salida.data() + cliente.enviado,
                            cliente.salida.size() - cliente.enviado, MSG_NOSIGNAL);
                        if (enviados > 0) {
                            cliente.enviado += static_cast<std::size_t>(enviados);
                            if (cliente.enviado == cliente.salida.size()) cliente.cerrado = true;
                        } else if (enviados == 0 || (errno != EINTR && errno != EAGAIN && errno != EWOULDBLOCK)) {
                            cliente.motivo = Motivo::ErrorEscritura;
                            cliente.cerrado = true;
                        }
                    }
                    if (!cliente.cerrado && Reloj::now() >= cliente.limite) {
                        if (cliente.salida.empty())
                            despedida(cliente, "REQUEST_TIMEOUT", Motivo::TimeoutLectura);
                        else {
                            cliente.motivo = Motivo::TimeoutEscritura;
                            cliente.cerrado = true;
                        }
                    }
                } catch (const std::exception& error) {
                    EventLog::log_event_system(EventLevel::ERROR, "Error interno al procesar cliente", {
                        {"ip", cliente.ip}, {"detalle", error.what()}
                    });
                    cliente.motivo = Motivo::ErrorInterno;
                    cliente.cerrado = true;
                } catch (...) {
                    EventLog::log_event_system(EventLevel::ERROR, "Error interno al procesar cliente", {
                        {"ip", cliente.ip}
                    });
                    cliente.motivo = Motivo::ErrorInterno;
                    cliente.cerrado = true;
                }
            }
            for (const auto& cliente : clientes) registrar(*cliente);
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
                if (!inet_ntop(AF_INET, &origen.sin_addr, ip, sizeof(ip)))
                    continue;
                if (!origenRedPermitido(ip, config.redesPermitidas)) {
                    if (avisoPermitido(Motivo::OrigenRechazado))
                        EventLog::log_event_system(EventLevel::WARN, "Conexión rechazada", {
                            {"ip", ip}, {"motivo", textoMotivo(Motivo::OrigenRechazado)}
                        });
                    continue;
                }
                if (clientes.size() >= 32) {
                    if (avisoPermitido(Motivo::CupoExcedido))
                        EventLog::log_event_system(EventLevel::WARN, "Conexión rechazada", {
                            {"ip", ip}, {"motivo", textoMotivo(Motivo::CupoExcedido)}
                        });
                    continue;
                }
                auto cliente = std::make_unique<Cliente>(conexion.valor);
                conexion.valor = -1;
                cliente->ip = ip;
                if (remota.habilitada) {
                    const auto identidad = remota.identidades.find(ip);
                    if (identidad != remota.identidades.end()) {
                        cliente->identidad = "tcp-" + remota.ambitosTrabajos.at(identidad->second);
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
