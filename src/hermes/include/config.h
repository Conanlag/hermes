#ifndef CONFIG_H
#define CONFIG_H

#include <string>
#include <vector>

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
    std::string directorioDatos;
    std::string interfaz = "127.0.0.1";
    int puerto = 45820;
    std::vector<std::string> redesPermitidas = {"127.0.0.0/8"};
    bool reglasRedValidas = true;
};

/**
 * Lee config.json de manera tolerante a fallos.
 * Los campos ausentes usan sus valores predeterminados. Los inválidos generan
 * advertencias; concurrencia y cola se ajustan a sus límites históricos.
 */
// Crea config.json y config.lock si faltan, sin sobrescribir valores existentes.
void inicializarConfiguracion();
ConfiguracionSistema cargarConfiguracion();

// Validación compartida por lectura tolerante y actualización estricta.
bool interfazValida(const std::string& interfaz);
bool directorioDatosValido(const std::string& directorio);

/**
 * Actualiza y persiste de forma atómica las claves de config.json indicadas
 * por los indicadores activos. Los indicadores en false dejan la clave
 * existente intacta, y todas las claves modificadas se validan antes de
 * escribir, de modo que no queda una actualización a medias.
 *
 * @throws std::invalid_argument si algún valor está fuera de su rango.
 * @throws std::runtime_error si la configuración no se puede leer o guardar.
 */
struct CambiosConfiguracion {
    bool redesPermitidas = false;
    std::vector<std::string> valorRedesPermitidas;
    bool directorioDatos = false;
    std::string valorDirectorioDatos;
    bool interfaz = false;
    std::string valorInterfaz;
    bool puerto = false;
    int valorPuerto = 45820;
    bool trabajosMaximos = false;
    int valorTrabajosMaximos = 0;
    bool maxCola = false;
    int valorMaxCola = 0;
};

void actualizarConfiguracion(const CambiosConfiguracion& cambios);

/**
 * Equivale a actualizarConfiguracion() cambiando solo `trabajos_maximos`.
 *
 * @throws std::invalid_argument si el valor está fuera del rango permitido.
 * @throws std::runtime_error si la configuración no se puede leer o guardar.
 */
void establecerTrabajosMaximos(int trabajosMaximos);

/**
 * Equivale a actualizarConfiguracion() cambiando solo `max_cola`.
 *
 * @throws std::invalid_argument si el valor está fuera del rango permitido.
 * @throws std::runtime_error si la configuración no se puede leer o guardar.
 */
void establecerMaxCola(int maxCola);

} // namespace hermes

#endif
