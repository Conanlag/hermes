#include "network_access.h"
#include <arpa/inet.h>
#include <charconv>
#include <cstdint>

namespace {
struct Red { uint32_t base; uint32_t mascara; };
bool leer(const std::string& texto, Red& red) {
    if (texto.find('\0') != std::string::npos) return false;
    const auto barra = texto.find('/');
    const std::string ip = texto.substr(0, barra);
    int bits = 32;
    if (barra != std::string::npos) {
        const char* inicio = texto.data() + barra + 1;
        const char* fin = texto.data() + texto.size();
        const auto resultado = std::from_chars(inicio, fin, bits);
        if (resultado.ec != std::errc{} || resultado.ptr != fin || bits < 0 || bits > 32)
            return false;
    }
    in_addr direccion{};
    if (inet_pton(AF_INET, ip.c_str(), &direccion) != 1) return false;
    red.mascara = bits == 0 ? 0 : UINT32_MAX << (32 - bits);
    red.base = ntohl(direccion.s_addr) & red.mascara;
    return true;
}
bool contenida(const Red& red, const Red& limite) {
    return (red.mascara & limite.mascara) == limite.mascara &&
           (red.base & limite.mascara) == limite.base;
}
}

namespace hermes {
bool reglaRedValida(const std::string& regla) {
    Red red{};
    if (!leer(regla, red)) return false;
    for (const char* espacio : {"127.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12",
                                "192.168.0.0/16", "100.64.0.0/10"}) {
        Red limite{};
        leer(espacio, limite);
        if (contenida(red, limite)) return true;
    }
    return false;
}

bool origenRedPermitido(const std::string& origen, const std::vector<std::string>& reglas) {
    if (origen.find('/') != std::string::npos) return false;
    Red ip{};
    if (!leer(origen, ip)) return false;
    // Una lista inválida deniega todo, incluso si otra regla coincide.
    for (const auto& regla : reglas) if (!reglaRedValida(regla)) return false;
    for (const auto& regla : reglas) {
        Red red{};
        leer(regla, red);
        if (contenida(ip, red)) return true;
    }
    return false;
}
}
