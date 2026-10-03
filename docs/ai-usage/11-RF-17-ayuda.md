# Uso de inteligencia artificial

# 11. Ayuda de uso --help RF-17

## Objetivo

Implementamos RF-17 (comando `--help` con ayuda integrada y códigos de salida `0/1`) como módulo `help` espejo de `version`, conectándolo a la lista blanca del validador y a la rama del despachador, y actualizamos sus impactos (`TC-015` y guía de usuario).

---

## Prompt 1
```text
ayudame a implementar el RF-17: . El cliente deberá ofrecer ayuda de uso y códigos de salida adecuados para éxito y error. creando un comando --help, lee el AGENTS.md
```

---

## Resultado 1

Se siguió el plan de `AGENTS.md` por fases: Fase 1 con contrato `include/help.h` (`int mostrarAyuda();`) justificado como módulo propio espejo de `version`; Fase 2 con `src/help/help.cpp` (texto por `cout` plano, `return 0`, sin `try/catch` por no haber archivos); Fase 3 con lista blanca en `validator.cpp` (3 puntos) y rama en `main.cpp` junto a `--version`. Verificado en WSL: `--help → 0`, `foo → 1` con lista actualizada, `--version → 0` intacto.

---

## Prompt 2
```text
esto no cambia el "verif/test-cases/TC-015.md"? y la "docs/user-guide/user-guide.md"
```

---

## Resultado 2

Se detectaron dos impactos: `TC-015` seguía válido pero sin nombrar `--help` (se agregaron datos de entrada y paso 1 explícitos) y la guía listaba comandos sin `--help` y sin sección propia (se agregó a la lista y nueva `6.5 Hermes --help` con sintaxis y ejemplo).

---

# Modificaciones
**Estado de la resolución:** Aceptado tras verificación

**Revisión realizada:** Verificamos orden de integración (validador antes que rama, o `--help` moriría como no reconocido), firma espejo de `version`, `cout` plano vs `info()` de color, y salidas reales aportadas (`--help → 0`, `foo → 1`, `--version → 0`).

**Cambios aplicados:** Nuevo `include/help.h` + `src/help/help.cpp` (directorio `src/help/` creado), 3 ediciones en `validator.cpp`, include + rama en `main.cpp`, retoque `TC-015` y sección `6.5` en la guía. `Makefile` sin cambios (descubre por `find`).

**Prueba agregada:** `make clean && make` más `./hermes --help; echo $?`, `./hermes foo; echo $?`, `./hermes --version; echo $?` en WSL.

---

## Implementación de feature

Se integró el comando `--help` como documento vivo del CLI: describe los 7 comandos, estados, ejemplos y códigos sin leer disco, con salida `0` garantizada.

---

## Modificación de archivo

Nuevos `include/help.h` y `src/help/help.cpp`; modificados `src/validator/validator.cpp`, `src/main.cpp`, `verif/test-cases/TC-015.md` y `docs/user-guide/user-guide.md`.

---

# Implementación final

```bash
./hermes --help; echo $?
```

```text
HERMES - Gestor de trabajos en cola
...
Codigos de salida: 0 exito, 1 error
0
```

---

# Aprendizaje

Aprendimos que la ayuda debe vivir fuera del despachador para crecer sin ensuciarlo, que todo comando nuevo exige actualizar la lista blanca del validador (su comentario `IMPORTANTE` lo recuerda), y que cada feature arrastra impactos documentales (`TC` + guía) que hay que cazar en el mismo acto.
