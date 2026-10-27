# Uso de inteligencia artificial

# 20. Automatización de Usabilidad TC-015 (RF-17, RNF-21, RNF-23)

## Objetivo
Auditar y estabilizar las pruebas de usabilidad y documentación (TC-015), identificando aserciones mal construidas basadas en expectativas de texto erróneas, y eliminando problemas de permisos al simular comandos de instalación.

---

## Prompt 1
```text
aca estan los pasos manuales:
[Muestra la salida real del binario C++ en consola, seguida del código del script viejo que arrojaba un falso FAIL en el Paso 3 y Paso 5].
```

---

## Resultado 1
Se contrastó la salida real de la aplicación con la lógica del script de Bash viejo. Se identificó un defecto de automatización (Aserción fantasma): el script exigía que el binario devolviera la cadena `"filter"` al fallar, pero el sistema emitía el mensaje óptimo `"ID mal formado: abc. Debe ser un numero entero positivo"`. Además, se diagnosticó que forzar `make install` desde un script de pruebas arrojaba errores de permisos (falsos negativos). Se generó un script ajustado a la verdadera salida del sistema.

---

# Modificaciones
**Estado de la resolución:** Aceptado tras conciliación entre prueba manual empírica y script de Bash.

**Revisión realizada:** Se validó que el código C++ respeta completamente el RF-17 y RNF-21, informando de forma clara al usuario el motivo del error y cómo corregirlo, y arrojando exitosamente el código `1` a nivel sistema.

---

## Implementación de feature
Se integró el script definitivo `TC-015.sh`. Alinea la evaluación automatizada con las impresiones literales del software en consola y delega el flujo de lectura del manual al operador de QA, evitando invasiones a los directorios protegidos del sistema.

---

## Modificación de archivo
- Reescritura táctica de `verif/scripts/TC-015.sh`.
- Actualización de `verif/test-cases/TC-015.md` documentando el hallazgo de la "Aserción fantasma" y declarando el `[ PASS ]` definitivo.

---

# Implementación final
```bash
bash verif/scripts/TC-015.sh
```

---

# Aprendizaje
**El riesgo del Hardcoding en Aserciones:** Los scripts de prueba que exigen cadenas de texto inamovibles que no provienen de los requisitos directos son un "anti-patrón". En este caso, exigir que la consola dijera "filter" causó que una prueba fallara a pesar de que el desarrollador había programado un mensaje de error mucho mejor y más útil. Las pruebas deben evaluar la *semántica* del resultado (que indique la causa y la solución), no obligar a la interfaz a usar palabras arbitrarias.