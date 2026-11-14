#pragma once
#include "job.h"
#include <nlohmann/json.hpp>
// Presentación común para CLI local y remoto.
int mostrarAdmisionJob(const Job& job);
void mostrarDetalleJob(const Job& job);
void mostrarResumenJob(const nlohmann::json& job);
Job jobDesdeJson(const nlohmann::json& datos);
nlohmann::json jsonDesdeJob(const Job& job);
