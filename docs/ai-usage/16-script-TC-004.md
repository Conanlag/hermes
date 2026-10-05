# Uso de inteligencia artificial

# 16. Script de validación TC-004 y Refinamiento de Aserciones en Bash

## Objetivo

Construir un script automatizado y estricto para validar las funciones de consulta y filtrado de la base de datos (RF-08, RF-09). El objetivo central fue eliminar los falsos defectos (falsos negativos) causados por un mal manejo de tuberías en bash y expectativas incorrectas sobre los códigos de salida de C++, sin caer en aserciones permisivas (falsos positivos).

---

## Prompt 1
```text
analiza el TC-004... [Muestra el Markdown con una contradicción: decía en el texto que había dado PASS pero el estado general estaba marcado como FAIL por miedo a errores previos].
```

---

## Resultado 1

Se identificó la contradicción documental. Se propuso crear un script nuevo usando redirecciones (`> /tmp/`) para evitar el `SIGPIPE` heredado del TC-003, y evaluar el programa limpiamente para poder declarar un `[PASS]` legítimo.

---

## Prompt 2
```text
este es el script viejo que tenia... y este su resultado: [FAIL] TC-004.
estaba mal el script viejo?
```

---

## Resultado 2

Se realizó una "autopsia" del script viejo y se detectaron dos fallos críticos ajenos a C++:
1. **SIGPIPE:** El uso de `| grep` volvía a matar el trabajo `sleep 30` antes de poder cancelarlo, dejando la lista `CANCELED` vacía.
2. **Trampa del código de salida:** El script exigía matemáticamente que el programa devolviera un código de error de sistema (`$? -eq 1`) cuando no encontraba un ID o programa. C++ imprimía el mensaje correcto pero terminaba con `return 0` (ejecución sin errores), lo que provocaba un fallo en la prueba automatizada. Se entregó una versión que solo leía la salida estándar (`stdout`).

---

## Prompt 3
```text
parece que ya, No modificaste el codigo para que diera un falso positivo? de verdad estas evaluando correctamente? [El usuario detecta que el paso 6 no tenía un 'if' estricto].
```

---

## Resultado 3

El usuario identificó exitosamente un exceso de permisividad (falso positivo intencional) introducido en el Paso 6 por falta de confirmación sobre la salida exacta del programa. Se corrigió inmediatamente introduciendo una aserción estricta (`if echo "$SALIDA_VACIA" | grep -qi "no se encontraron"; then`) garantizando que el `[PASS]` fuera 100% legítimo y auditable, sin regalar aprobaciones.

---

# Modificaciones

**Estado de la resolución:** Aceptado tras auditoría estricta cruzada (manual vs automatizada).

**Revisión realizada:** Se validó que las aserciones en Bash coincidieran exactamente con lo que el programa de consola imprime (`stdout`), eliminando la dependencia de códigos de error irrelevantes para búsquedas sin resultados. Se comprobó rigurosamente que no existieran aserciones suavizadas.

---

## Implementación de feature

Se integró un script automatizado `TC-004.sh` altamente confiable. El script crea el ecosistema de procesos en background evadiendo las interrupciones del SO, lanza las consultas por ID, status y programa, e intercepta la salida en pantalla para comprobar que los filtros agrupan correctamente y rechazan correctamente.

---

## Modificación de archivo

- Reescritura total de `verif/scripts/TC-004.sh` eliminando tuberías directas.
- Actualización del documento `verif/test-cases/TC-004.md` cambiando el estado a `[ PASS ]` y agregando la justificación técnica de la reparación.

---

# Implementación final

```bash
bash verif/scripts/TC-004.sh
```

---

# Aprendizaje

Se obtuvieron dos grandes aprendizajes de QA Automation:
1. **No exigir fallos de sistema para resultados lógicos vacíos:** Una consulta que no arroja resultados ("No se encontraron Jobs") no es un error de sistema (`exit 1`); es una ejecución exitosa (`exit 0`) con un resultado de negocio específico. Los scripts de prueba deben evaluar la respuesta semántica (`stdout`), no solo los códigos binarios del sistema operativo.
2. **El peligro de los falsos positivos:** Como ingenieros de QA, es preferible un script que falle agresivamente a uno que suavice las aserciones para que todo se vea verde. La intervención manual para endurecer el Paso 6 demostró el valor de revisar el código generado por IA con pensamiento crítico.