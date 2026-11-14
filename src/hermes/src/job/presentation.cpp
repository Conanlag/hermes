#include "job_presentation.h"
#include "terminal.colors.h"
#include <iostream>
using nlohmann::json;
Job jobDesdeJson(const json& datos) {
    Job job{};
    job.job_id = datos.at("job_id").get<unsigned>();
    job.pid = datos.value("pid", 0);
    job.programa = datos.value("programa", std::string{});
    job.argumentos = datos.value("argumentos", std::vector<std::string>{});
    job.status = statusDesdeTexto(datos.value("status", std::string{}));
    job.codigoSalida = datos.value("codigo_salida", -1);
    job.mensajeError = datos.value("mensaje_error", std::string{});
    job.tiempo_recepcion = datos.value("tiempo_recepcion", std::string{});
    job.tiempo_inicio = datos.value("tiempo_inicio", std::string{});
    job.tiempo_terminacion = datos.value("tiempo_terminacion", std::string{});
    return job;
}
int mostrarAdmisionJob(const Job& job) {
    std::cout << "job ID: " << job.job_id << std::endl;
    if (job.solicitudDuplicada) {
        info("Solicitud duplicada; se reutiliza el Job existente.");
        return 0;
    }
    if (job.status == Status::FAILED) {
        error(job.mensajeError.empty() ? "No se pudo ejecutar el programa '" + job.programa + "'" : job.mensajeError);
        return 1;
    }
    if (job.pid > 0) std::cout << "PID: " << job.pid << std::endl;
    else std::cout << "PID: pendiente (en cola)" << std::endl;
    return 0;
}
void mostrarDetalleJob(const Job& job) {
    std::cout << "Job ID: " << job.job_id << '\n'
        << "PID: " << job.pid << '\n'
        << "Programa: " << job.programa << '\n'
        << "Estado: " << statusToString(job.status) << '\n'
        << "Codigo de salida: " << job.codigoSalida << '\n'
        << "Recepcion: " << job.tiempo_recepcion << '\n'
        << "Inicio: " << job.tiempo_inicio << '\n'
        << "Terminacion: " << job.tiempo_terminacion << '\n';
    if (!job.mensajeError.empty()) std::cout << "Mensaje de error: " << job.mensajeError << '\n';
    std::cout << "Argumentos: ";
    for (const auto& argumento : job.argumentos) std::cout << argumento << ' ';
    std::cout << std::endl;
}
void mostrarResumenJob(const json& job) {
    std::cout << "Job ID: ";
    if (job.contains("job_id")) std::cout << job["job_id"]; else std::cout << "N/A";
    std::cout << "\nPrograma: ";
    if (job.contains("programa")) std::cout << job["programa"]; else std::cout << "N/A";
    std::cout << "\nPID: ";
    if (job.contains("pid")) std::cout << job["pid"]; else std::cout << 0;
    std::cout << "\nEstado: ";
    if (job.contains("status")) std::cout << job["status"]; else std::cout << "QUEUED";
    std::cout << "\nArgumentos: ";
    if (job.contains("argumentos") && job["argumentos"].is_array())
        for (const auto& argumento : job["argumentos"]) std::cout << argumento << ' ';
    std::cout << "\n------------------------" << std::endl;
}

json jsonDesdeJob(const Job& job) {
    return {{"job_id", job.job_id}, {"pid", job.pid}, {"programa", job.programa},
        {"argumentos", job.argumentos}, {"status", statusToString(job.status)},
        {"codigo_salida", job.codigoSalida}, {"mensaje_error", job.mensajeError},
        {"tiempo_recepcion", job.tiempo_recepcion}, {"tiempo_inicio", job.tiempo_inicio},
        {"tiempo_terminacion", job.tiempo_terminacion}};
}
