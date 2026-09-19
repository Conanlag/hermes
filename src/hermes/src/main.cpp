#include <iostream>
#include <string>

// Librerias del proyecto
#include "version/version.h"

using std::cout;
using std::endl;
using std::string;






int main(int argc, char* argv[]) {

    if (argc < 2) {
        cout << "HERMES " << endl;
        return 0;
    }

    string comando = argv[1];

    if (comando == "--version") {
        return version();
    }

    cout << "Comando no reconocido: " << comando << endl;
    return 1;
}