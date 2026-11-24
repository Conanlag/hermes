#include "network.h"
#include "network_remote.h"
#include "network_access.h"
#include "data_paths.h"
#include "config.h"
#include "event_log.h"
#include "validator.h"
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <fcntl.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
#include <cerrno>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <vector>
#include <algorithm>
#include <cctype>

namespace {
using json = nlohmann::json;
namespace fs = std::filesystem;
class ColorAzul {
public:
    ColorAzul() { std::cout << "\033[34m"; }
    ~ColorAzul() { std::cout << "\033[0m" << std::flush; }
};
void hint(const std::string& equipo, const std::string& comando, const std::string& copiar) {
    std::cout << "\033[34m\nAyuda — " << equipo << ":\n  " << comando
              << "\n  " << copiar << '\n';
}
std::string comandoIPWindows(const std::string& destino) {
    return "Find-NetRoute -RemoteIPAddress " + destino +
        " | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress";
}
std::string comandoIPLinux(const std::string& destino) {
    return "ip -4 route get " + destino +
        R"( | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')";
}

std::string preguntar(const std::string& texto, const std::string& defecto = "") {
    std::cout << "\033[34m" << texto << (defecto.empty() ? "" : " [" + defecto + "]") << ": " << std::flush;
    std::string valor;
    if (!std::getline(std::cin, valor)) throw std::runtime_error("Entrada terminada; asistente cancelado");
    const auto inicio = valor.find_first_not_of(" \t\r");
    if (inicio == std::string::npos) return defecto;
    return valor.substr(inicio, valor.find_last_not_of(" \t\r") - inicio + 1);
}
bool confirmar(const std::string& texto) {
    while (true) {
        const auto valor = preguntar(texto + " [y/n]");
        if (valor == "y" || valor == "Y" || valor == "yes" || valor == "s" || valor == "S" || valor == "si" || valor == "sí") return true;
        if (valor.empty() || valor == "n" || valor == "N" || valor == "no") return false;
        std::cout << "Escriba y o n.\n";
    }
}
std::string pedirIP(const std::string& texto, const std::string& defecto = "") {
    while (true) {
        const auto ip = preguntar(texto, defecto);
        if (hermes::interfazValida(ip) && hermes::reglaRedValida(ip)) return ip;
        std::cout << "Use una IPv4 privada, de loopback o VPN (sin /prefijo); no se permiten direcciones públicas.\n";
    }
}
std::vector<std::string> interfaces() {
    std::vector<std::string> ips;
    ifaddrs* lista = nullptr;
    if (getifaddrs(&lista) != 0) throw std::runtime_error("No se pudieron consultar las interfaces de red");
    std::ifstream rutas("/proc/net/route");
    std::string linea, interfazPrincipal;
    std::getline(rutas, linea);
    while (std::getline(rutas, linea)) {
        std::istringstream campos(linea);
        std::string nombre, destino;
        if (campos >> nombre >> destino && destino == "00000000") { interfazPrincipal = nombre; break; }
    }
    for (auto* entrada = lista; entrada; entrada = entrada->ifa_next) {
        if (!entrada->ifa_addr || entrada->ifa_addr->sa_family != AF_INET) continue;
        char ip[INET_ADDRSTRLEN]{};
        const auto* addr = reinterpret_cast<sockaddr_in*>(entrada->ifa_addr);
        if (inet_ntop(AF_INET, &addr->sin_addr, ip, sizeof(ip)) && hermes::reglaRedValida(ip)) {
            if (interfazPrincipal == entrada->ifa_name) ips.insert(ips.begin(), ip);
            else ips.emplace_back(ip);
        }
    }
    freeifaddrs(lista);
    return ips;
}
std::string gateway() {
    std::ifstream archivo("/proc/net/route");
    std::string linea;
    std::getline(archivo, linea);
    while (std::getline(archivo, linea)) {
        std::istringstream campos(linea);
        std::string interfaz, destino, puerta;
        if (!(campos >> interfaz >> destino >> puerta) || destino != "00000000") continue;
        try {
            const auto valor = std::stoul(puerta, nullptr, 16);
            return std::to_string(valor & 255) + "." + std::to_string((valor >> 8) & 255) + "." +
                   std::to_string((valor >> 16) & 255) + "." + std::to_string((valor >> 24) & 255);
        } catch (...) { return ""; }
    }
    return "";
}
json leer(const fs::path& ruta) {
    std::ifstream archivo(ruta);
    json datos;
    if (!archivo || !(archivo >> datos) || !datos.is_object())
        throw std::runtime_error("No se pudo leer un objeto JSON de " + ruta.string());
    return datos;
}
class Lock {
    int fd;
public:
    explicit Lock(const fs::path& ruta) : fd(open(ruta.c_str(), O_CREAT | O_RDWR | O_CLOEXEC, 0600)) {
        if (fd < 0) throw std::runtime_error("No se pudo abrir network.lock");
        if (flock(fd, LOCK_EX) != 0) { close(fd); throw std::runtime_error("No se pudo bloquear network.lock"); }
    }
    ~Lock() { close(fd); }
    Lock(const Lock&) = delete;
    Lock& operator=(const Lock&) = delete;
};
void guardar(const fs::path& ruta, const std::string& contenido) {
    std::string temporal = ruta.string() + ".setup-XXXXXX";
    int fd = mkstemp(temporal.data());
    if (fd < 0) throw std::runtime_error("No se pudo preparar " + ruta.string());
    try {
        struct stat previo{};
        if (stat(ruta.c_str(), &previo) == 0 && fchmod(fd, previo.st_mode & 0777) != 0)
            throw std::runtime_error("No se pudieron conservar permisos");
        std::size_t posicion = 0;
        while (posicion < contenido.size()) {
            const auto n = write(fd, contenido.data() + posicion, contenido.size() - posicion);
            if (n < 0 && errno == EINTR) continue;
            if (n <= 0) throw std::runtime_error("No se pudo escribir " + ruta.string());
            posicion += static_cast<std::size_t>(n);
        }
        if (fsync(fd) != 0) throw std::runtime_error("No se pudo sincronizar " + ruta.string());
        const auto resultado = close(fd);
        fd = -1;
        if (resultado != 0 || rename(temporal.c_str(), ruta.c_str()) != 0)
            throw std::runtime_error("No se pudo publicar " + ruta.string());
    } catch (...) {
        if (fd >= 0) close(fd);
        unlink(temporal.c_str());
        throw;
    }
}
// Ejecución con argv separados; nunca se usa system() ni un shell Linux.
std::string ejecutar(const std::vector<std::string>& args, bool capturar = false) {
    int tubos[2] = {-1, -1};
    if (capturar && pipe2(tubos, O_CLOEXEC) != 0) throw std::runtime_error("No se pudo crear el canal de salida");
    const auto pid = fork();
    if (pid < 0) {
        if (capturar) { close(tubos[0]); close(tubos[1]); }
        throw std::runtime_error("No se pudo ejecutar la herramienta de Windows");
    }
    if (pid == 0) {
        if (capturar) { close(tubos[0]); dup2(tubos[1], STDOUT_FILENO); close(tubos[1]); }
        std::vector<char*> argv;
        for (const auto& arg : args) argv.push_back(const_cast<char*>(arg.c_str()));
        argv.push_back(nullptr);
        execvp(argv[0], argv.data());
        _exit(127);
    }
    std::string salida;
    if (capturar) {
        close(tubos[1]);
        char bloque[1024];
        while (true) {
            const auto n = read(tubos[0], bloque, sizeof(bloque));
            if (n > 0) { if (salida.size() < 16384) salida.append(bloque, static_cast<std::size_t>(n)); }
            else if (n < 0 && errno == EINTR) continue;
            else break;
        }
        close(tubos[0]);
    }
    int estado = 0;
    while (waitpid(pid, &estado, 0) < 0) if (errno != EINTR) throw std::runtime_error("No se pudo esperar la herramienta");
    if (!WIFEXITED(estado) || WEXITSTATUS(estado) != 0)
        throw std::runtime_error("La herramienta " + args.front() + " falló o se canceló; revise su salida");
    while (!salida.empty() && (salida.back() == '\n' || salida.back() == '\r')) salida.pop_back();
    return salida;
}
bool usaProxyWindows() {
    std::ifstream archivo("/proc/sys/kernel/osrelease");
    std::string kernel;
    std::getline(archivo, kernel);
    std::transform(kernel.begin(), kernel.end(), kernel.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    if (!std::getenv("WSL_INTEROP") && kernel.find("microsoft") == std::string::npos) return false;
    std::string modo;
    try { modo = ejecutar({"wslinfo", "--networking-mode"}, true); }
    catch (const std::exception&) {
        std::cout << "WSL detectado; se usará el acceso por proxy NAT de Windows.\n";
        return true;
    }
    if (modo == "mirrored") return false;
    if (modo == "nat") return true;
    throw std::runtime_error("El modo WSL detectado (" + modo + ") no está soportado por este asistente");
}
std::string ipWindowsDetectada() {
    try {
        const auto ip = ejecutar({"powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
                                  comandoIPWindows("1.1.1.1")}, true);
        if (hermes::interfazValida(ip) && hermes::reglaRedValida(ip)) return ip;
    } catch (const std::exception&) {}
    return "";
}
std::string psQuote(const std::string& valor) {
    std::string salida = "'";
    for (char c : valor) salida += c == '\'' ? "''" : std::string(1, c);
    return salida + "'";
}
std::string scriptWindows(const std::string& id, const std::string& peer, const std::string& windows,
                          const std::string& interfaz, int puerto) {
    const auto port = std::to_string(puerto);
    const auto nombre = "Hermes-" + port + "-" + id;
    return "$ErrorActionPreference = 'Stop'\ntry {\n"
        "  Set-Service iphlpsvc -StartupType Automatic\n  Start-Service iphlpsvc\n"
        "  & netsh.exe interface portproxy set v4tov4 listenaddress=" + windows + " listenport=" + port +
        " connectaddress=" + interfaz + " connectport=" + port + "\n"
        "  if ($LASTEXITCODE -ne 0) {\n"
        "    & netsh.exe interface portproxy add v4tov4 listenaddress=" + windows + " listenport=" + port +
        " connectaddress=" + interfaz + " connectport=" + port + "\n"
        "    if ($LASTEXITCODE -ne 0) { throw 'No se pudo configurar portproxy' }\n  }\n"
        "  $rule = Get-NetFirewallRule -Name '" + nombre + "' -ErrorAction SilentlyContinue\n"
        "  if (-not $rule) {\n"
        "    New-NetFirewallRule -Name '" + nombre + "' -DisplayName 'Hermes " + id +
        "' -Direction Inbound -Action Allow -Protocol TCP -LocalPort " + port + " -LocalAddress " + windows +
        " -RemoteAddress " + peer + " -Profile Any | Out-Null\n  } else {\n"
        "    $rule | Set-NetFirewallRule -Enabled True -Direction Inbound -Action Allow -Profile Any\n"
        "    $rule | Get-NetFirewallPortFilter | Set-NetFirewallPortFilter -Protocol TCP -LocalPort " + port + "\n"
        "    $rule | Get-NetFirewallAddressFilter | Set-NetFirewallAddressFilter -LocalAddress " + windows +
        " -RemoteAddress " + peer + "\n  }\n"
        "  $listener = Get-NetTCPConnection -State Listen -LocalPort " + port +
        " -ErrorAction SilentlyContinue | Where-Object { $_.LocalAddress -eq '" + windows + "' }\n"
        "  if (-not $listener) { Restart-Service iphlpsvc }\n"
        "  Get-Service iphlpsvc\n  & netsh.exe interface portproxy show v4tov4\n"
        "  $listener = Get-NetTCPConnection -State Listen -LocalPort " + port +
        " -ErrorAction SilentlyContinue | Where-Object { $_.LocalAddress -eq '" + windows + "' }\n"
        "  if (-not $listener) { throw 'El proxy todavía no escucha en la IP de Windows' }\n"
        "  Write-Host 'Proxy y regla de firewall preparados. Falta iniciar Hermes y probar desde el cliente.'\n"
        "  exit 0\n} catch {\n  Write-Error $_ -ErrorAction Continue\n  exit 1\n}\n";
}
}

namespace hermes {
int configurarRedInteractiva() {
    ColorAzul color;
    bool configGuardada = false;
    try {
        std::cout << "Hermes Red setup — ejecutar en el servidor (PC A).\n"
                  << "Un solo asistente: detectaremos el entorno y pediremos las direcciones actuales.\n"
                  << "No use IP de VMware, Bluetooth o adaptadores desconectados.\n"
                  << "Cada pregunta incluye un comando para obtener el dato correcto.\n";
        const auto config = cargarConfiguracion();
        if (!config.reglasRedValidas) throw std::runtime_error("Corrija redes_permitidas antes de ejecutar setup");
        const auto ruta = directorioRed() / "network.json";
        const auto original = leer(ruta);
        auto propuesta = original;
        if (!propuesta.contains("clientes") || !propuesta["clientes"].is_array())
            throw std::runtime_error("network.json requiere una lista clientes válida");
        const bool wsl = usaProxyWindows();
        std::cout << (wsl ? "Detectado WSL NAT: configuraremos el proxy y firewall de Windows.\n" :
                           "Detectado acceso directo: configuraremos Hermes en la interfaz local.\n");
        // Primero PC A: detectar las tres direcciones y confirmarlas juntas.
        const auto ips = interfaces();
        if (ips.empty()) throw std::runtime_error("No hay interfaces IPv4 disponibles");
        std::string interfaz = ips.front();
        for (const auto& ip : ips) if (ip.rfind("127.", 0) != 0) { interfaz = ip; break; }
        std::string windows = wsl ? ipWindowsDetectada() : "";
        std::string origen = wsl ? gateway() : "";
        auto localValida = [&](const std::string& ip) {
            return std::find(ips.begin(), ips.end(), ip) != ips.end();
        };
        auto corregirServidor = [&]() {
            if (wsl) {
                hint("PowerShell de ESTA PC A", comandoIPWindows("1.1.1.1"),
                     "Copie la IP LAN actual de Windows; no una IP VMware.");
                windows = pedirIP("IP LAN de Windows de esta PC A", windows);
            }
            hint("WSL/Linux de ESTA PC A", comandoIPLinux(wsl ? windows : "1.1.1.1"),
                 "Copie la IP local de la interfaz que usará el servidor, sin máscara.");
            do {
                interfaz = pedirIP(wsl ? "IP interna de este WSL (PC A)" : "IP de escucha de PC A", interfaz);
                if (!localValida(interfaz)) std::cout << "La IP no está asignada a este equipo.\n";
            } while (!localValida(interfaz));
            if (wsl) {
                hint("WSL de ESTA PC A", "ip -4 route show default | awk '/default/ {print $3; exit}'",
                     "Copie el gateway interno de WSL, no el gateway Wi-Fi de Windows.");
                origen = pedirIP("Gateway PC-A / origen de Windows hacia WSL", origen);
            }
        };
        std::cout << "\nPaso 1 — Configuración de PC-A\n";
        if (wsl) {
            hint("PowerShell de PC A, si necesita comprobar la IP", comandoIPWindows("1.1.1.1"),
                 "La dirección detectada se propone abajo; no se usa una IP antigua del archivo.");
            hint("WSL de PC A", comandoIPLinux(windows.empty() ? "1.1.1.1" : windows),
                 "Devuelve la IP interna de WSL.");
            hint("WSL de PC A", "ip -4 route show default | awk '/default/ {print $3; exit}'",
                 "Devuelve el gateway interno de PC A.");
            if (!interfazValida(windows) || !reglaRedValida(windows) ||
                !interfazValida(origen) || !reglaRedValida(origen)) corregirServidor();
        }
        while (true) {
            std::cout << "\n";
            if (wsl) std::cout << "IP LAN de Windows de esta PC A [" << windows << "]\n";
            std::cout << (wsl ? "IP interna de este WSL (PC A) [" : "IP de escucha de PC A [") << interfaz << "]\n";
            if (wsl) std::cout << "Gateway PC-A / origen de Windows hacia WSL [" << origen << "]\n";
            if (confirmar("¿Estas son las direcciones que quiere configurar?")) break;
            std::cout << "Corrija las direcciones de PC A; Ctrl+D cancela el asistente.\n";
            corregirServidor();
        }
        std::cout << "\nPaso 2 — Registrar la otra computadora\n";
        std::string id;
        while (true) {
            id = preguntar("Nombre/ID de la otra computadora (por ejemplo PC-B o PC-C)");
            const auto validacion = validarRequestId(id);
            if (validacion.esValido && (!wsl || id != "gateway-PC-A")) break;
            std::cout << (validacion.esValido ? "gateway-PC-A identifica el acceso común del servidor, no otro equipo." : validacion.mensaje) << '\n';
        }
        if (wsl)
            hint("PowerShell de LA OTRA computadora", comandoIPWindows(windows),
                 "Copie su IP LAN actual; esta IP se autoriza en su propia regla de firewall.");
        else
            hint("Linux de LA OTRA computadora", comandoIPLinux(interfaz),
                 "Copie la IP con la que ese equipo llega al servidor.");
        const auto peer = pedirIP("IP LAN de la otra computadora (" + id + ")");
        if (!wsl) origen = peer;
        const std::string registro = wsl ? "gateway-PC-A" : id;
        json* cliente = nullptr;
        for (auto& actual : propuesta["clientes"]) {
            if (!actual.is_object()) throw std::runtime_error("Registro de cliente inválido");
            const auto actualId = actual.value("id", std::string{});
            bool tieneOrigen = false;
            if (actual.contains("direcciones")) for (const auto& ip : actual["direcciones"]) if (ip == origen) tieneOrigen = true;
            if (actualId == registro || tieneOrigen) {
                if (cliente && cliente != &actual) throw std::runtime_error("Hay registros de gateway incompatibles; revise network.json");
                if (!wsl && actualId != id) throw std::runtime_error("La dirección ya está registrada para " + actualId);
                cliente = &actual;
            }
        }
        if (!cliente) {
            propuesta["clientes"].push_back({{"id", registro}, {"direcciones", json::array()},
                {"operaciones", {"submit", "query", "list", "cancel"}},
                {"programas", {"sleep", "true", "false", "echo", "ls", "yes", "time", "bash",
                    "/usr/bin/sleep", "/usr/bin/true", "/usr/bin/false", "/usr/bin/echo", "/usr/bin/ls",
                    "/usr/bin/yes", "/usr/bin/time", "/bin/bash", "/usr/bin/bash"}}});
            cliente = &propuesta["clientes"].back();
        }
        if (!cliente->contains("direcciones") || !(*cliente)["direcciones"].is_array())
            throw std::runtime_error("Las direcciones del registro existente no son válidas");
        if (wsl) {
            const auto anteriorId = cliente->at("id").get<std::string>();
            if (anteriorId != registro) {
                if (!cliente->contains("ambito_trabajos")) (*cliente)["ambito_trabajos"] = anteriorId;
                std::cout << "Se renombrará " << anteriorId << " a gateway-PC-A conservando su historial.\n";
            }
            (*cliente)["id"] = registro;
            (*cliente)["tipo"] = "gateway";
        }
        bool existe = false;
        for (const auto& ip : (*cliente)["direcciones"]) if (ip == origen) existe = true;
        if (!existe) (*cliente)["direcciones"].push_back(origen);
        // Los equipos se guardan por separado del único origen que ve WSL.
        if (!propuesta.contains("equipos")) propuesta["equipos"] = json::array();
        if (!propuesta["equipos"].is_array()) throw std::runtime_error("equipos debe ser una lista");
        json* equipo = nullptr;
        for (auto& actual : propuesta["equipos"]) {
            if (!actual.is_object()) throw std::runtime_error("Registro de equipo inválido");
            if (actual.value("id", std::string{}) == id) equipo = &actual;
            else if (actual.value("ip_lan", std::string{}) == peer)
                throw std::runtime_error("La IP LAN ya pertenece al equipo " + actual.value("id", std::string{}));
        }
        if (!equipo) { propuesta["equipos"].push_back({{"id", id}}); equipo = &propuesta["equipos"].back(); }
        (*equipo)["ip_lan"] = peer;
        (*equipo)["acceso"] = registro;
        (*equipo)["regla_firewall"] = "Hermes-" + std::to_string(config.puerto) + "-" + id;
        if (!propuesta.contains("servidor")) propuesta["servidor"] = json::object();
        auto& servidor = propuesta["servidor"];
        if (!servidor.is_object()) throw std::runtime_error("servidor debe ser un objeto");
        servidor["id"] = "PC-A";
        servidor["interfaz"] = interfaz;
        servidor["puerto"] = config.puerto;
        servidor["modo"] = wsl ? "wsl-nat" : "directo";
        if (wsl) { servidor["ip_windows"] = windows; servidor["gateway_wsl"] = origen; }
        if (wsl) std::cout << "Gateway común de PC A: " << origen << ". Cada equipo conserva su regla de firewall.\n"
                          << "Los equipos detrás del proxy comparten el ámbito de trabajos del gateway.\n";
        propuesta["habilitada"] = true;
        (void)interpretarConfiguracionRemota(propuesta);
        const auto script = wsl ? scriptWindows(id, peer, windows, interfaz, config.puerto) : "";
        std::string nombreArchivo = id;
        for (auto& c : nombreArchivo) if (c == ':') c = '_';
        const auto archivoPS = directorioRed() / ("setup-windows-" + nombreArchivo + ".ps1");
        std::cout << "\nCambios propuestos:\n  Equipo: " << id << "\n  Escucha: " << interfaz << ':' << config.puerto
                  << "\n  Origen permitido en Hermes: " << origen << "\n"
                  << "  Se conservan otros clientes, permisos existentes, concurrencia, cola y directorio.\n"
                  << "  La red quedará habilitada. Nuevos registros pueden usar bash/time para lanzar otros programas.\n"
                  << "  Permisos del registro:\n" << cliente->dump(2) << '\n';
        if (wsl) std::cout << "\nPowerShell propuesto (IP Helper automático; posible reinicio si el proxy no escucha):\n"
                          << script << '\n';
        if (!confirmar("Guardar esta configuración")) { std::cout << "Cancelado; no se guardaron cambios de setup.\n"; return 0; }
        {
            Lock bloqueo(directorioRed() / "network.lock");
            if (leer(ruta) != original) throw std::runtime_error("network.json cambió mientras se respondía; repita setup");
            fs::copy_file(ruta, ruta.string() + ".setup.bak", fs::copy_options::skip_existing);
            const auto rutaConfig = rutaConfiguracion();
            fs::copy_file(rutaConfig, rutaConfig + ".setup.bak", fs::copy_options::skip_existing);
            if (wsl) guardar(archivoPS, script);
            CambiosConfiguracion cambios;
            cambios.interfaz = true;
            cambios.valorInterfaz = interfaz;
            cambios.agregarRedesPermitidas = {origen};
            actualizarConfiguracion(cambios);
            configGuardada = true;
            guardar(ruta, propuesta.dump(4) + '\n');
        }
        std::cout << "Configuración guardada. Respaldos iniciales: config.json.setup.bak y network.json.setup.bak.\n";
        if (wsl) {
            std::cout << "Archivo PowerShell revisable: " << archivoPS << '\n';
            if (confirmar("Aplicar ahora proxy y firewall de Windows (Windows solicitará administrador)")) {
                const auto winpath = ejecutar({"wslpath", "-w", archivoPS.string()}, true);
                if (winpath.empty() || winpath.find_first_of("\"\r\n`") != std::string::npos)
                    throw std::runtime_error("Ruta Windows no válida; ejecute el archivo revisado desde PowerShell administrador");
                const auto argumentos = "-NoProfile -ExecutionPolicy Bypass -File \"" + winpath + "\"";
                const auto comando = "$ErrorActionPreference='Stop'; try { $p=Start-Process -FilePath powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList " +
                    psQuote(argumentos) + "; exit $p.ExitCode } catch { Write-Error $_ -ErrorAction Continue; exit 1 }";
                ejecutar({"powershell.exe", "-NoProfile", "-Command", comando});
                std::cout << "Windows informó que el proxy y el firewall quedaron preparados.\n";
            } else std::cout << "Windows pendiente. Abra PowerShell administrador y ejecute el .ps1 indicado\n"
                            << "usando su ruta Windows (obténgala con wslpath -w).\n";
        }
        const auto destino = wsl ? windows : interfaz;
        std::cout << "Siguiente: iniciar/reiniciar ./hermes red start en PC A.\n"
                  << "Desde " << id << ": ./hermes red job " << destino << " sleep 30\n"
                  << "Desde PowerShell del otro equipo: Test-NetConnection " << destino << " -Port " << config.puerto << '\n'
                  << "El cliente debe usar ese mismo puerto. No se ha comprobado aún la conexión desde el otro equipo.\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Setup: " << detalleSeguro(error) << '\n';
        if (configGuardada) std::cerr << "Ya se guardó config.json; revise network.json y los respaldos. Windows podría seguir pendiente.\n";
        return 1;
    }
}
}
