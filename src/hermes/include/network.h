#pragma once

namespace hermes {
// Servicio de escucha en primer plano; SIGINT/SIGTERM solicitan su cierre.
int iniciarServidorRed();
int configurarRedInteractiva();
int ejecutarClienteRed(int argc, char* argv[]);
}
