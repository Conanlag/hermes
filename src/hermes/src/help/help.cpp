#include <iostream>

#include "help.h"

using std::cout;
using std::endl;

int mostrarAyuda() {
    cout << "HERMES - Gestor de trabajos en cola" << endl;
    cout << endl;
    cout << "Uso: hermes <comando> [argumentos..]" << endl;
    cout << endl;
    cout << "Comandos:" << endl;
    cout << "  job <programa> [argumentos..]  Crea un trabajo y devuelve su ID" << endl;
    cout << "  filter id <numero>             Muestra un trabajo por su ID" << endl;
    cout << "  filter status <ESTADO>         Lista trabajos por estado" << endl;
    cout << "  filter programa <nombre>       Lista trabajos por programa" << endl;
    cout << "  cancel <id>                    Cancela un trabajo en cola o en ejecucion" << endl;
    cout << "  --version                      Muestra la version" << endl;
    cout << "  --help                         Muestra esta ayuda" << endl;
    cout << endl;
    cout << "Estados: QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELED" << endl;
    cout << endl;
    cout << "Ejemplos:" << endl;
    cout << "  hermes job sleep 30" << endl;
    cout << "  hermes filter id 1" << endl;
    cout << "  hermes filter status RUNNING" << endl;
    cout << "  hermes cancel 1" << endl;
    cout << endl;
    cout << "Codigos de salida: 0 exito, 1 error" << endl;

    return 0;
}
