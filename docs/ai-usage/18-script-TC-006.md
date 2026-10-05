# Uso de inteligencia artificial

# 18. Script de validación TC-006 y Corrección de Falsos Positivos de Diseño (RF-11)

## Objetivo
Asegurar que la automatización del TC-006 evalúe correctamente la captura y persistencia de `stdout`, `stderr` y códigos de salida mediante las herramientas de consulta del propio software, eliminando un error de diseño lógico en el script anterior que validaba el comportamiento en el momento equivocado.

---

## Prompt 1
```text
segun el script viejo que tengo es correcto:
[Muestra el script viejo y su salida con un PASS aparente evaluando la creación del job en lugar de la consulta filter]
```

---

## Resultado 1
Se identificó un falso positivo por error de diseño en el script de Bash. El script antiguo interceptaba la salida estándar y de error en el momento exacto de invocar `./hermes job`, en lugar de validar si el sistema realmente guardaba los datos para mostrarlos después en `./hermes filter`. Además, omitía aserciones críticas. Se proporcionó un script nuevo y estricto.

---

## Prompt 2
```text
nueva salida:
[Muestra la salida del nuevo script confirmando que todos los pasos dan OK y logran el PASS legítimo].
```

---

## Resultado 2
Se verificó empíricamente que la aplicación C++ cumple con los RF-11 y RF-07 a la perfección. La consulta posterior (`filter`) es capaz de recuperar los textos de ambos canales sin mezclarlos, así como los códigos de salida exactos.

---

# Modificaciones

**Estado de la resolución:** Aceptado tras auditoría arquitectónica del script de pruebas.

**Revisión realizada:** Se cambió el enfoque de la prueba automatizada de una "interceptación en tiempo de ejecución" a una "auditoría de persistencia y consulta", alineándose verdaderamente con los Requisitos Funcionales del sistema.

---

## Implementación de feature
Se integró un script `TC-006.sh` que aísla las salidas de creación (evitando tuberías) y evalúa estrictamente las respuestas del comando `filter id` para garantizar la captura de los flujos de texto y códigos de error (`exit 3`).

---

## Modificación de archivo
- Reescritura lógica de `verif/scripts/TC-006.sh`.
- Actualización de la Fase 2 en `verif/test-cases/TC-006.md`.

---

# Implementación final
```bash
bash verif/scripts/TC-006.sh
```

---

# Aprendizaje
**Falsos positivos de diseño:** Un caso de prueba automatizado puede dar un resultado exitoso pero estar evaluando el requisito incorrecto. Validar la "captura" de un texto no significa interceptarlo al vuelo desde Bash en la misma línea de comandos, sino confirmar que el software bajo prueba lo integró a su estado interno persistente y puede devolverlo al ser consultado.