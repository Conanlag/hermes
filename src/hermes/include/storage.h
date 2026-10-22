#ifndef STORAGE_H
#define STORAGE_H

#include <functional>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

json leerJobsSeguros();
bool modificarJobsSeguros(const std::function<bool(json&)>& funcion);

#endif