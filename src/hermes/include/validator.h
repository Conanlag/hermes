#ifndef VALIDATOR_H
#define VALIDATOR_H

#include <string>

using std::string;

enum class CodigoValidacion {
    OK,
    VACIO,
    MALFORMADO,
    NO_AUTORIZADO
};

struct ResultadoValidacion {
    bool esValido;
    CodigoValidacion codigo;
    string mensaje;
};

ResultadoValidacion validarComando(const string& comando);

ResultadoValidacion validarPrograma(const string& programa);

ResultadoValidacion validarTipoFiltro(const string& tipoFiltro);

ResultadoValidacion validarIdTexto(const string& textoId);

ResultadoValidacion validarStatusTexto(const string& status);

#endif
