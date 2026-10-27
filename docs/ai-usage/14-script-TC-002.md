# Uso de inteligencia artificial

# 14. Script de validación TC-002

## Objetivo

Ayudar a construir `verif/scripts/TC-002.sh` como réplica fiel de los pasos 1–6 de `verif/test-cases/TC-002.md` (RF-03), con la restricción del desarrollador de usar solo bash + `grep`, sin python.

---

## Prompt 1
```text
ayudame a modificar el .sh de verif\scripts\TC-002.sh, el test-case es correcto pero como en el proyecto todavia no manejamos concurrencia y ningun job se va a la fila, por eso fallaba, entonces solo replica los pasos del verif\test-cases\TC-002.md (si son correctos para verificar el RF-03) y ponlos en el script
```

---

## Resultado 1

Se reescribió `TC-002.sh` como espejo 1:1 del documento (compilar, anotar `M`, crear, `N = M + 1`, 7 campos, tipos) con aserción estricta de `QUEUED` tal como pide RF-03 y `FAIL` honesto con causa (Issue #15) cuando el supervisor ya promovió el Job.

---

## Prompt 2
```text
oye, pero entonces lo de python es necesario? solo manten en el .sh lo indicado para probar el TC-002
```

---

## Resultado 2

Se eliminó la dependencia de python3: como `jobs.json` se guarda con `dump(4)`, el script recorta con `awk` solo el bloque de la entrada `N` (hasta su `    }` de cierre) y verifica los 7 campos con `grep`. Los tipos los exige el propio patrón (números sin comillas, cadenas con comillas, booleano literal). Se documentó la limitación honesta: `grep` no es un parser JSON, pero basta para 7 campos fijos en formato tabulado.

---

# Modificaciones
**Estado de la resolución:** Aceptado tras verificación

**Revisión realizada:** Verificamos que cada paso del `.sh` correspondiera al mismo número del `.md` sin atajos ni tolerancias inventadas, y que la evidencia siguiera la guía vigente (`verif/results/`, nada en `/tmp`).

**Cambios aplicados:** Réplica fiel de pasos + versión bash-pura sin python tras la objeción del desarrollador.

**Prueba agregada:** Pendiente de ejecución en WSL (`bash verif/scripts/TC-002.sh`); el `FAIL` por falta de concurrencia queda asentado en TC-002 con Issue #15.

---

## Implementación de feature

Se integró `verif/scripts/TC-002.sh` como automatización mínima y fiel del caso: compila, crea, verifica orden, inspecciona el bloque `N` y dictamina `[PASS]/[FAIL]`.

---

## Modificación de archivo

Reescrito `verif/scripts/TC-002.sh` (dos iteraciones: réplica de pasos, luego simplificación sin python).

---

# Implementación final

```bash
bash verif/scripts/TC-002.sh
```

---

# Aprendizaje

Aprendimos que el mejor script es el que el desarrollador puede leer de corrido: si el caso se prueba con `grep` sobre un formato estable, python es peso muerto. Y que replicar el documento al pie de la letra —incluido su `FAIL` esperado— vale más que un script "inteligente" que perdona.

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
