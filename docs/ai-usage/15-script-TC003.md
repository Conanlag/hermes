# Uso de inteligencia artificial

# 15. Script de validación TC-003 y Depuración de SIGPIPE

## Objetivo

Corregir y construir la versión definitiva de `verif/scripts/TC-003.sh` para auditar correctamente los estados y tiempos (RF-06, RF-07), eliminando "falsos defectos" generados por la gestión de procesos de Bash y asegurando que el script documente honestamente la excepción de alcance (Issue #15) en lugar de dar un falso `[PASS]`.

---

## Prompt 1
```text
le pedi a un agente que me ayudara a corregirlo pero creo que lo empeoro:
#!/bin/bash
# TC-003: Estados y tiempos (RF-06, RF-07)
[...]
Paso 5 FAIL (estado inicial: SUCCEEDED)
Paso 6 FAIL (cancelado sin CANCELED)
```

---

## Resultado 1

Se detectó que el agente anterior introdujo lógica excesivamente compleja (bloqueos temporales confusos y Python mezclado con Bash) que enmascaraba el verdadero comportamiento del sistema. Se propuso una versión más limpia, pero durante las iteraciones surgió una discrepancia: el código C++ funcionaba perfecto en pruebas manuales (`sleep 30` duraba 30 segundos), pero el script automatizado fallaba porque el proceso terminaba al instante.

---

## Prompt 2
```text
a ver, ya jale el .sh del TC-003 directo de main y github, pero me da esto... pero te demostre que hecho a mano desde clon limpio si funcionaba hasta que llegaba donde QUEUED, entonces que hago?
```

---

## Resultado 2

Se identificó la causa raíz: un problema estructural de Linux (`SIGPIPE` / Tuberías rotas). Al usar `| grep` en la creación de trabajos asíncronos (`./hermes job sleep 30 | grep ...`), `grep` se cerraba al encontrar el ID, destruyendo la tubería. Linux enviaba un `SIGPIPE` y asesinaba el proceso de C++ prematuramente, obligándolo a reportar `SUCCEEDED`.

Se reescribió el script eliminando las tuberías destructivas a favor de redirecciones de texto simples (`> /tmp/archivo.txt`), replicando con exactitud matemática la ejecución manual.

---

# Modificaciones
**Estado de la resolución:** Aceptado tras verificación

**Revisión realizada:** Se contrastó meticulosamente la ejecución manual en un entorno limpio contra la ejecución del script. Se aisló el problema en la gestión de pipes de Bash, eximiendo al código fuente en C++ de cualquier defecto de regresión funcional en la cancelación de trabajos.

**Cambios aplicados:**
- Eliminación de estructuras `| grep` directas sobre llamadas asíncronas.
- Uso de redirección de salidas a `/tmp/` para lectura posterior.
- Uso de validación embebida limpia en Python para asegurar la cronología (`recepción <= inicio <= terminación`).

**Prueba agregada:** Ejecutada y validada en WSL. El script ahora aprueba los pasos 1, 2, 3, 4 y 6, y arroja un `[FAIL]` honesto y esperado en el Paso 5 (estado `QUEUED`), enlazándolo correctamente al Issue #15.

---

## Implementación de feature

Se integró `verif/scripts/TC-003.sh` como una herramienta de auditoría automatizada robusta que revisa el ciclo de vida completo de un proceso (éxito, fallo y cancelación), audita los metadatos JSON y discrimina correctamente el alcance actual del proyecto.

---

## Modificación de archivo

Reescritura total de `verif/scripts/TC-003.sh`.

---

# Implementación final

```bash
bash verif/scripts/TC-003.sh
```

---

# Aprendizaje

Aprendimos una lección crítica de Sistemas Operativos: el uso de tuberías (`|`) con procesos asíncronos en Bash es peligroso. Si el consumidor de la tubería (como `grep`) termina rápido, Linux destruye el puente de comunicación y mata al proceso productor (`hermes`) con una señal `SIGPIPE`. Esto genera "bugs fantasma" en las pruebas que no existen en el código real. Guardar la salida en archivos temporales antes de inspeccionarla garantiza que las pruebas automatizadas no interfieran con la ejecución del software. Además, aprendimos que volver a las pruebas manuales paso a paso es la herramienta suprema para descubrir la verdad.

---

# Skill aplicado: `.atl\crear_scripts_validacion.md`

```markdown
# Skill: Automatizador de Pruebas Bash y Gestor de Resultados - JobRunner

## Contexto y Rol
Eres un Ingeniero de QA Automation en el proyecto "JobRunner". Tu tarea es leer la **Fase de Diseño** de un caso de prueba (TC-XXX.md), traducir los "Pasos reproducibles" a código Bash para cumplir con el RNF-20, y pre-llenar los resultados empíricos en la documentación asumiendo una ejecución exitosa que será supervisada por el usuario.

## Instrucciones de Generación
1. El usuario te proporcionará el texto completo de un caso de prueba (`TC-XXX.md`).
2. Generarás un bloque de código Bash automatizado que ejecute exactamente esos pasos (indicando que el script debe integrarse/guardarse en `C:\Users\alan\Desktop\CUCEI\Proyecto_Sistemas_Avanzados\ppl\verif\scripts\TC-XXX.sh`).
3. **Requisitos estrictos del código Bash:**
   - Crear el directorio de evidencias si no existe (`mkdir -p verif/results/`).
   - Imprimir el identificador del caso (ej. `echo "=== Ejecutando TC-001 ==="`).
   - Ejecutar los binarios/comandos simulando al cliente.
   - Capturar el código de salida (`$?`) y las salidas estándar (`stdout`/`stderr`).
   - Guardar TODA la salida de la prueba (logs de build, stdout, stderr) directamente en la carpeta `verif/results/` (ej. `verif/results/tc001.log`) en lugar de usar directorios temporales (`/tmp/`), asegurando que la evidencia persista.
   - Incluir condicionales (`if/else`) para comparar el resultado real con el "Resultado esperado" del TC.
   - Si coincide, imprimir `echo "[PASS] TC-XXX"`; si no, imprimir `echo "[FAIL] TC-XXX"`.
4. **Actualización Documental (Supervisada):** Además del código Bash, deberás generar:
   - La **Fase de Ejecución** del documento `TC-XXX.md` completamente rellenada. Redacta el "Resultado observado" asumiendo que todo fue exitoso, marca el estado como `PASS`, añade la evidencia apuntando a la ruta persistente (ej. `verif/results/tc001.log`) y deja el campo de responsable listo.
   - La fila en formato tabla Markdown para la `traceability-matrix.md`, cambiando el estado de "Pendiente" a "PASS" e indicando la evidencia generada por el script.
5. Estructura tu respuesta en tres bloques de código claros: 1) Código Bash, 2) Actualización TC-XXX.md, y 3) Actualización Matriz.
6. **Comando listo para el usuario:** cierra siempre con el comando exacto ya armado para ejecutar el script, en sus dos formas (el usuario trabaja en VS Code sobre Windows pero todo compila y corre en WSL): forma WSL `bash verif/scripts/TC-XXX.sh` (desde la raíz del repo) y forma PowerShell `wsl bash -c "cd /mnt/c/Users/alan/Desktop/CUCEI/Proyecto_Sistemas_Avanzados/ppl && bash verif/scripts/TC-XXX.sh"`. El `.sh` jamás se ejecuta directo en PowerShell.
```