#ifndef STORAGE_H
#define STORAGE_H

#include <functional>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

json leerJobsSeguros();
bool modificarJobsSeguros(const std::function<bool(json&)>& funcion);

/**
 * Elimina los archivos `jobs.json.tmp.*` que dejaron ejecuciones muertas.
 *
 * Debe invocarse al arrancar y bajo `jobs.lock`: mientras el lock está
 * tomado ningún escritor vivo puede tener un temporal abierto, así que
 * cualquier temporal presente es basura de un proceso que murió.
 *
 * @throws std::runtime_error si no se puede inspeccionar el directorio.
 */
void limpiarTemporalesDeJobs();

#endif
