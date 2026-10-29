#ifndef CONFIG_H
#define CONFIG_H

namespace hermes {

constexpr int DEFAULT_TRABAJOS_MAXIMOS = 5;
constexpr int MIN_TRABAJOS_MAXIMOS = 1;
constexpr int MAX_TRABAJOS_MAXIMOS = 64;

struct ConfiguracionSistema {
    int trabajosMaximos = DEFAULT_TRABAJOS_MAXIMOS;
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
