#include <iostream>
#include <string>

// Librerias del proyecto
#include "version.h"
#include "job.h"
#include "filter.h"
#include "validator.h"
#include "terminal.colors.h"
#include "cancel.h"


using std::cout;
using std::endl;
using std::string;
using std::vector;
using std::cerr;

int main(int argc, char* argv[]) {

    if (argc < 2) {
        cout << "HERMES " << endl;
        return 0;
    }

    string comando = argv[1]; // La clase string ya sabe como manejar ptr a char

    ResultadoValidacion rc = validarComando(comando);
    // Rechazar comando vacío / no autorizado
    if (!rc.esValido) {
        error(rc.mensaje);
        return 1;
    }

    if (comando == "--version") {
        return version();
    }

    if (comando == "job") {
        if (argc < 3) {
            info("Uso: hermes job <programa> [argumentos..]");
            return 1;
        }

        string programa = argv[2];

        ResultadoValidacion rp = validarPrograma(programa);
        // Rechazar programa vacío / no valido.
        if (!rp.esValido) {
            error(rp.mensaje);
            return 1;
        }

        vector<string> argumentos;
        for (int i = 3; i < argc; ++i) {
            argumentos.push_back(argv[i]);
        }

        Job job = crearJob(programa, argumentos);

        cout << "job ID: " << job.job_id << endl;
        cout << "PID: " << job.pid << endl;
        return 0;
    }
    if (comando == "cancel") {

    if (argc < 3) {
        info("Uso: hermes cancel <id>");
        return 1;
    }

    ResultadoValidacion ri =
        validarIdTexto(argv[2]);

    if (!ri.esValido) {
        error(ri.mensaje);
        return 1;
    }

    unsigned int id =
        static_cast<unsigned int>(
            std::stoul(argv[2])
        );

    if (!cancelarJob(id)) {

        error(
            "No se pudo cancelar el Job: ",
            id
        );

        return 1;
    }

    info(
        "Cancelación solicitada para el Job: ",
        id
    );

    return 0;
}

    if (comando == "filter") {
        if (argc < 4) {
            info("Uso: hermes filter <id|status|programa> <valor>");
            return 1;
        }

        string tipoFiltro = argv[2];

        ResultadoValidacion rf = validarTipoFiltro(tipoFiltro);
        // Rechazar tipo de filtro vacío / no autorizado
        if (!rf.esValido) {
            error(rf.mensaje);
            warning("Filtros disponibles: id, status, programa");
            return 1;
        }

        if (tipoFiltro == "id") {

            ResultadoValidacion ri = validarIdTexto(argv[3]);
            // Rechazar id mal formado
            if (!ri.esValido) {
                error(ri.mensaje);
                return 1;
            }

            // Convertir str a uint (seguro, ya validado)
            unsigned int id = static_cast<unsigned int>(std::stoul(argv[3]));

            filtrarPorId(id);

        } else if (tipoFiltro == "status") {

            ResultadoValidacion rs = validarStatusTexto(argv[3]);
            // Rechazar status vacío / no autorizado en filtro
            if (!rs.esValido) {
                error(rs.mensaje);
                return 1;
            }
            filtrarPorStatus(argv[3]);

        } else if (tipoFiltro == "programa") {

            ResultadoValidacion rfp = validarPrograma(argv[3]);
            // Rechazar programa vacío en filtro
            if (!rfp.esValido) {
                error(rfp.mensaje);
                return 1;
            }
            filtrarPorPrograma(argv[3]);
        }

        return 0;
    }

    error("Comando no reconocido: ", comando);
    return 1;
}