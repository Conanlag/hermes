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

ResultadoValidacion validarObjetivoClean(const string& objetivo);

ResultadoValidacion validarPrograma(const string& programa);

ResultadoValidacion validarRequestId(const string& requestId);

ResultadoValidacion validarTipoFiltro(const string& tipoFiltro);

ResultadoValidacion validarIdTexto(const string& textoId);

ResultadoValidacion validarStatusTexto(const string& status);

ResultadoValidacion validarTrabajosMaximosTexto(const string& texto);

ResultadoValidacion validarMaxColaTexto(const string& texto);

// RNF-14: verificación estricta de UTF-8 y de bytes de control en textos que
// llegan por la red. No registra eventos: el llamador decide cómo reportarlo.
bool utf8Valido(const string& texto);

ResultadoValidacion validarTextoRed(const string& valor);

#endif
