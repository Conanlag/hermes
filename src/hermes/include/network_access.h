#pragma once
#include <string>
#include <vector>

namespace hermes {
// Una IP sin prefijo equivale a /32. Solo admite subredes completas de
// loopback, RFC1918 y espacio compartido usado por algunas VPN.
bool reglaRedValida(const std::string& regla);
bool origenRedPermitido(const std::string& origen,
                        const std::vector<std::string>& reglas);
}
