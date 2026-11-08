#ifndef CONFIG_H
#define CONFIG_H

namespace hermes {

constexpr int DEFAULT_TRABAJOS_MAXIMOS = 5;
constexpr int MIN_TRABAJOS_MAXIMOS = 1;
constexpr int MAX_TRABAJOS_MAXIMOS = 64;

// Cupos de espera (QUEUED) por encima de trabajos_maximos. Cero significa que
// no se admite cola de espera y que el excedente se rechaza, que es el
// comportamiento histórico descrito en ADR-008.
constexpr int DEFAULT_MAX_COLA = 0;
constexpr int MIN_MAX_COLA = 0;
constexpr int MAX_MAX_COLA = 256;

struct ConfiguracionSistema {
    int trabajosMaximos = DEFAULT_TRABAJOS_MAXIMOS;
    int maxCola = DEFAULT_MAX_COLA;
};

/**
 * Lee config.json de manera tolerante a fallos.
 * Si el archivo falta, está corrupto o tiene valores fuera de rango,
 * registra una advertencia en EventLog y retorna una configuración segura por defecto.
 */
ConfiguracionSistema cargarConfiguracion();

/**
 * Actualiza y persiste el máximo de trabajos configurado.
 *
 * @throws std::invalid_argument si el valor está fuera del rango permitido.
 * @throws std::runtime_error si la configuración no se puede leer o guardar.
 */
void establecerTrabajosMaximos(int trabajosMaximos);

} // namespace hermes

#endif
