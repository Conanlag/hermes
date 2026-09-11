#include <iostream>
#include <string>

using std::cout;
using std::endl;

int proceso();
int version();

int main(int argc, char* argv[]) {

    if (argc < 2) {
        cout << "HOLA ESTE ES EL INICIO DEL PROYECTO" << endl;
        return 0;
    }

    std::string comando = argv[1];

    if (comando == "fork") {
        return proceso();
    }

    if (comando == "--version") {
        return version();
    }

    cout << "Comando no reconocido: " << comando << endl;
    return 1;
}