#include <iostream>
#include <string>

// Librerias del proyecto
#include "version.h"
#include "job.h"
#include "filter.h"
#include "terminal.colors.h"

using std::cout;
using std::endl;
using std::string;
using std::vector;
using std::cerr;

// Funcion principal 
int main(int argc, char* argv[]) {

    if (argc < 2) {
        cout << "HERMES " << endl;
        return 0;
    }

    string comando = argv[1];

    if (comando == "--version") {
        return version();
    }

    if (comando == "job") {
        if (argc < 3) {
            info("Uso: hermes Job <programa> [argumentos..]");
            return 1;
        }

        string programa = argv[2];

        vector<string> argumentos;
        for (int i = 3; i < argc; ++i) {
            argumentos.push_back(argv[i]);
        }

        Job job = crearJob(programa, argumentos);

        cout << "Job ID: " << job.job_id << endl;
        return 0;
    }

    if (comando == "filter") {

        if (argc < 4) {
            info("Uso: hermes Job <programa> [argumentos..]");
            return 1;
        }

        string tipoFiltro = argv[2];

        if (tipoFiltro == "id") {

            unsigned int id = std::stoul(argv[3]);

            filtrarPorId(id);

        } else if (tipoFiltro == "status") {

            filtrarPorStatus(argv[3]);
        
            
        } else if (tipoFiltro == "programa") {

            filtrarPorPrograma(argv[3]);

        } else {

            error("Filtro no reconocido: ", tipoFiltro);

            warning("Filtros disponibles: id, status, programa");

            return 1;
        }

        return 0;
    }



    error("Comando no reconocido: ", comando);
    return 1; 
}