#ifndef RECOVERY_H
#define RECOVERY_H

namespace hermes {

/**
 * Comprueba que este proceso puede leer su propia identidad y el boot_id.
 *
 * Es la sonda de capacidad del arranque (paso 2 del flujo 2.3): sin ella no
 * se puede verificar un huérfano antes de señalarlo, así que es preferible
 * abortar a recuperar a ciegas. La usa el daemon y también `clean data`
 * cuando no hay un supervisor vivo (F12).
 *
 * @throws std::runtime_error si no se puede garantizar la recuperación.
 */
void verificarCapacidadDeRecuperacion();

/**
 * Reclasifica los Jobs que quedaron en RUNNING cuando el scheduler anterior
 * dejó de supervisarlos (RF-13).
 *
 * Clasifica cada fila según la tabla de la sección 2.4, verifica la identidad
 * de los huérfanos antes de señalarlos y termina los grupos verificados con
 * SIGTERM, una ventana de gracia de 5 s y SIGKILL.
 *
 * No muta jobs.json antes de actuar sobre el proceso. Es idempotente: si una
 * ejecución se corta entre la señal y la persistencia, la siguiente repite la
 * clasificación sin daño.
 *
 * @throws std::runtime_error si no se puede leer o escribir jobs.json.
 */
void recuperarTrabajosInterrumpidos();

} // namespace hermes

#endif
