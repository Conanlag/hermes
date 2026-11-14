#include "network.h"
#include "network_access.h"
#include "network_protocol.h"
#include "config.h"
#include "validator.h"
#include "job_presentation.h"
#include "terminal.colors.h"
#include <arpa/inet.h>
#include <netdb.h>
#include <fcntl.h>
#include <poll.h>
#include <unistd.h>
#include <charconv>
#include <chrono>
#include <csignal>
#include <iostream>
#include <stdexcept>
#include <sys/random.h>
#include <memory>

namespace {
using Reloj = std::chrono::steady_clock;
struct Socket {
    int fd = -1;
    ~Socket() { if (fd >= 0) close(fd); }
};
struct IgnorarPipe {
    struct sigaction anterior{};
    IgnorarPipe() {
        struct sigaction accion{};
        accion.sa_handler = SIG_IGN;
        sigemptyset(&accion.sa_mask);
        if (sigaction(SIGPIPE, &accion, &anterior)) throw std::runtime_error("No se pudo configurar SIGPIPE");
    }
    ~IgnorarPipe() { sigaction(SIGPIPE, &anterior, nullptr); }
};
void esperar(int fd, short eventos, Reloj::time_point limite) {
    while (true) {
        const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(limite - Reloj::now()).count();
        if (ms <= 0) throw std::runtime_error("Tiempo de conexión o respuesta agotado");
        pollfd evento{fd, eventos, 0};
        const int estado = poll(&evento, 1, static_cast<int>(ms));
        if (estado < 0 && errno == EINTR) continue;
        if (estado <= 0 || evento.revents & (POLLERR | POLLNVAL))
            throw std::runtime_error("La conexión no está disponible");
        return;
    }
}
unsigned numero(const char* texto, unsigned minimo) {
    unsigned valor = 0;
    const std::string cadena = texto;
    const auto resultado = std::from_chars(cadena.data(), cadena.data() + cadena.size(), valor);
    if (resultado.ec != std::errc{} || resultado.ptr != cadena.data() + cadena.size() || valor < minimo)
        throw std::invalid_argument("Identificador numérico inválido");
    return valor;
}
std::string requestId() {
    unsigned char bytes[16];
    std::size_t leidos = 0;
    while (leidos < sizeof(bytes)) {
        const auto cantidad = getrandom(bytes + leidos, sizeof(bytes) - leidos, 0);
        if (cantidad < 0 && errno == EINTR) continue;
        if (cantidad <= 0) throw std::runtime_error("No se pudo crear request_id");
        leidos += static_cast<std::size_t>(cantidad);
    }
    constexpr char hex[] = "0123456789abcdef";
    std::string id;
    for (auto c : bytes) { id += hex[c >> 4]; id += hex[c & 15]; }
    return id;
}
}

namespace hermes {
int ejecutarClienteRed(int argc, char* argv[]) {
    try {
        const std::string uso = "Uso: hermes red job <host> [--request-id <id>] <programa> [args...] | filter <host> <id|status|programa> <valor> | cancel <host> <id>";
        if (argc < 4) throw std::invalid_argument(uso);
        using json = nlohmann::json;
        const std::string operacion = argv[2], host = argv[3];
        json params = json::object();
        std::string id = requestId(), remota = operacion, tipoFiltro, valorFiltro;
        auto validar = [](const ResultadoValidacion& resultado) {
            if (!resultado.esValido) throw std::invalid_argument(resultado.mensaje);
        };
        if (operacion == "job") {
            if (argc < 5) throw std::invalid_argument(uso);
            int indice = 4;
            if (std::string(argv[4]) == "--request-id") {
                if (argc < 7) throw std::invalid_argument(uso);
                id = argv[5];
                validar(validarRequestId(id));
                indice = 6;
            }
            validar(validarPrograma(argv[indice]));
            params["programa"] = argv[indice];
            params["argumentos"] = json::array();
            for (int i = indice + 1; i < argc; ++i) params["argumentos"].push_back(argv[i]);
            remota = "submit";
        } else if (operacion == "cancel" && argc >= 5) {
            validar(validarIdTexto(argv[4]));
            params["job_id"] = numero(argv[4], 1);
        } else if (operacion == "filter" && argc >= 6) {
            tipoFiltro = argv[4];
            valorFiltro = argv[5];
            const auto validacionFiltro = validarTipoFiltro(tipoFiltro);
            if (!validacionFiltro.esValido) {
                error(validacionFiltro.mensaje);
                warning("Filtros disponibles: id, status, programa");
                return 1;
            }
            if (tipoFiltro == "id") {
                validar(validarIdTexto(valorFiltro));
                params["job_id"] = numero(argv[5], 1);
                remota = "query";
            } else {
                if (tipoFiltro == "status") validar(validarStatusTexto(valorFiltro));
                else validar(validarPrograma(valorFiltro));
                params["tipo"] = tipoFiltro;
                params["valor"] = valorFiltro;
                remota = "list";
            }
        } else throw std::invalid_argument(uso);
        auto enviar = [&]() -> json {
            const auto solicitud = json({{"version", 1}, {"request_id", id}, {"operation", remota}, {"params", params}}).dump() + '\n';
            if (solicitud.size() > MAX_MENSAJE_RED + 1) throw std::invalid_argument("Solicitud demasiado grande");
            addrinfo pistas{};
            pistas.ai_family = AF_INET;
            pistas.ai_socktype = SOCK_STREAM;
            addrinfo* resultado = nullptr;
            const auto puerto = std::to_string(cargarConfiguracion().puerto);
            if (getaddrinfo(host.c_str(), puerto.c_str(), &pistas, &resultado) != 0)
                throw std::runtime_error("No se pudo resolver el servidor");
            std::unique_ptr<addrinfo, decltype(&freeaddrinfo)> direcciones(resultado, freeaddrinfo);
            Socket socket;
            const auto limite = Reloj::now() + std::chrono::seconds(10);
            for (auto* direccion = resultado; direccion; direccion = direccion->ai_next) {
                char ip[INET_ADDRSTRLEN]{};
                const auto* ipv4 = reinterpret_cast<sockaddr_in*>(direccion->ai_addr);
                if (!inet_ntop(AF_INET, &ipv4->sin_addr, ip, sizeof(ip)) || !reglaRedValida(ip)) continue;
                socket.fd = ::socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
                if (socket.fd < 0) continue;
                const int conectado = connect(socket.fd, direccion->ai_addr, direccion->ai_addrlen);
                bool listo = conectado == 0;
                if (!listo && errno == EINPROGRESS) {
                    esperar(socket.fd, POLLOUT, limite);
                    int error = 0;
                    socklen_t longitud = sizeof(error);
                    listo = getsockopt(socket.fd, SOL_SOCKET, SO_ERROR, &error, &longitud) == 0 && error == 0;
                }
                if (listo) break;
                close(socket.fd);
                socket.fd = -1;
            }
            if (socket.fd < 0) throw std::runtime_error("No se pudo conectar a un servidor LAN/VPN");
            IgnorarPipe ignorar;
            std::size_t enviado = 0;
            while (enviado < solicitud.size()) {
                const auto cantidad = send(socket.fd, solicitud.data() + enviado,
                                           solicitud.size() - enviado, MSG_NOSIGNAL);
                if (cantidad > 0) enviado += static_cast<std::size_t>(cantidad);
                else if (cantidad < 0 && errno == EINTR) continue;
                else if (cantidad < 0 && (errno == EAGAIN || errno == EWOULDBLOCK))
                    esperar(socket.fd, POLLOUT, limite);
                else throw std::runtime_error("No se pudo enviar la solicitud al servidor");
            }
            std::string respuesta;
            while (respuesta.find('\n') == std::string::npos) {
                char buffer[4096];
                const auto cantidad = recv(socket.fd, buffer, sizeof(buffer), 0);
                if (cantidad > 0) respuesta.append(buffer, static_cast<std::size_t>(cantidad));
                else if (cantidad < 0 && errno == EINTR) continue;
                else if (cantidad < 0 && (errno == EAGAIN || errno == EWOULDBLOCK))
                    esperar(socket.fd, POLLIN, limite);
                else throw std::runtime_error("El servidor cerró o rechazó la conexión");
                if (respuesta.size() > 262144) throw std::runtime_error("Respuesta demasiado grande");
            }
            const auto recibida = json::parse(respuesta.substr(0, respuesta.find('\n')));
            if (!recibida.is_object() || recibida.value("request_id", std::string{}) != id ||
                recibida.value("version", 0) != 1 || !recibida.contains("ok") || !recibida["ok"].is_boolean())
                throw std::runtime_error("Respuesta inválida del servidor");
            return recibida;
        };
        bool encontrados = false;
        while (true) {
            const auto respuesta = enviar();
            if (!respuesta["ok"].get<bool>()) {
                const auto codigo = respuesta.value("error", std::string{});
                if (operacion == "filter" && tipoFiltro == "id" && (codigo == "NOT_FOUND" || codigo == "JOB_OPERATION_FAILED")) {
                    error("No se encontró el Job ID: ", params["job_id"]);
                    return 0; // El filtro local informa ausencia sin fallar el CLI.
                }
                if (operacion == "filter" && codigo == "JOB_OPERATION_FAILED") {
                    error("Error al leer jobs: ", respuesta.value("message", codigo));
                    return 0;
                }
                if (operacion == "cancel" && codigo == "NOT_FOUND") error("No existe el Job ID: ", params["job_id"]);
                else if (operacion == "job" && codigo == "JOB_OPERATION_FAILED")
                    error("No se pudo crear el Job: ", respuesta.value("message", codigo));
                else error(respuesta.value("message", codigo));
                return 1;
            }
            const auto& resultado = respuesta.at("result");
            if (operacion == "job") {
                auto job = jobDesdeJson(resultado.at("job"));
                job.solicitudDuplicada = resultado.at("duplicated").get<bool>();
                return mostrarAdmisionJob(job);
            }
            if (operacion == "cancel") {
                if (resultado.at("cancel_code") == "CANCELADO") info("Job cancelado: ", params["job_id"]);
                else info("Cancelación solicitada para el Job: ", params["job_id"]);
                return 0;
            }
            if (tipoFiltro == "id") { mostrarDetalleJob(jobDesdeJson(resultado)); return 0; }
            const auto& jobs = resultado.at("jobs");
            if (jobs.empty()) {
                if (!encontrados) {
                    if (tipoFiltro == "status") error("No se encontraron Jobs con estado: ", valorFiltro);
                    else error("No se encontraron Jobs con el programa indicado: ", valorFiltro);
                }
                return 0;
            }
            for (const auto& job : jobs) mostrarResumenJob(job);
            encontrados = true;
            const auto cursor = resultado.at("next_after").get<unsigned>();
            if (cursor <= params.value("after", 0U)) throw std::runtime_error("Cursor de respuesta inválido");
            params["after"] = cursor;
        }

    } catch (const std::invalid_argument& detalle) {
        error(detalle.what());
        return 1;
    } catch (const std::exception& error) {
        std::cerr << "Hermes Red: " << error.what() << '\n';
        return 1;
    }
}
}
