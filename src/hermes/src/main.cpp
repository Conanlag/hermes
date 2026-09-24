#include <iostream>
#include <string>

// Librerias del proyecto
#include "version.h"
#include "job.h"
#include "filter.h"

using std::cout;
using std::endl;
using std::string;
using std::vector;

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
            cout << "Uso: hermes Job <programa> [argumentos..]" << endl;
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

    cout << "Comando no reconocido: " << comando << endl;
    return 1;
}