# Uso de inteligencia artificial

# 19. Validación de Robustez TC-008 y Aislamiento de Fallos (RNF-08, RNF-09)

## Objetivo
Auditar el comportamiento del sistema ante comandos inválidos y fallos de procesos, depurando el script de automatización para evitar falsos negativos ocasionados por mal manejo de variables en Bash (Word-splitting) y tuberías destructivas, asegurando la supervivencia del servicio central.

---

## Prompt 1
```text
a ver, primero analiza el script viejo, dame el motivo porque fallaba (para anotarlo en el TC.md) y corrijelo
[Muestra el script antiguo con un bucle for para los comandos inválidos y tuberías directas en los procesos de background]
```

---

## Resultado 1
Se analizó el script y se detectaron dos errores estructurales ajenos al código C++:
1. **Word-splitting en Bash:** El script usaba un bucle `for` pasando variables sin escapar (`./hermes $CMD`). Esto provocaba que comandos complejos como `job ""` o `filter id abc` se rompieran antes de llegar al binario, arrojando resultados impredecibles.
2. **Interrupción por SIGPIPE:** El script volvía a usar la tubería `| grep` en el proceso `sleep 30`, matándolo instantáneamente y provocando que la aserción de `CANCELED` en el Paso 6 fallara. Se proporcionó un script robusto separando las aserciones y usando redirecciones (`> /tmp/`).

---

## Prompt 2
```text
aqui esta el resultado de hacer todo eso a mano:
[Muestra la salida de la terminal donde Hermes rechaza los comandos inválidos correctamente, y un error de Bash "1: command not found" al escribir accidentalmente `$?` como comando]
```

---

## Resultado 2
Se validó empíricamente que el programa C++ es invulnerable a entradas mal formadas. Se analizó el error `1: command not found` provocado por teclear `$?` sin `echo`, explicando que este accidente fue una prueba irrefutable de que el binario de C++ sí está manejando la excepción, imprimiendo su advertencia y devolviendo el código de error `1` al sistema operativo sin colapsar (no hubo *Segmentation Fault*).

---

## Prompt 3
```text
añade/cambia lo necesario a mi TC.md (sobre todo los errores corregidos)
[Muestra la corrida exitosa del nuevo script obteniendo el PASS legítimo para TC-008]
```

---

## Resultado 3
Se redactó la "Nota Técnica de QA" documentando formalmente la corrección de los dos falsos negativos del entorno de automatización, cambiando el veredicto a un `[PASS]` rotundo tras comprobar la solidez del sistema.

---

# Modificaciones
**Estado de la resolución:** Aceptado tras validación cruzada (manual y automatizada).

**Revisión realizada:** Se validó que el código C++ cumple rigurosamente con los atributos de calidad RNF-08 y RNF-09, aislando las peticiones inválidas y los procesos defectuosos sin que estos afecten a los trabajos sanos adyacentes ("testigos").

---

## Implementación de feature
Se integró el script definitivo `TC-008.sh`. Evalúa de forma aislada e individual cada comando de estrés para evadir comportamientos erráticos de la shell, y comprueba la continuidad operativa del sistema creando procesos post-fallo.

---

## Modificación de archivo
- Reemplazo de la lógica en `verif/scripts/TC-008.sh`.
- Actualización de `verif/test-cases/TC-008.md` cambiando el estado a `[ PASS ]` y documentando la depuración del entorno de pruebas.

---

# Implementación final
```bash
bash verif/scripts/TC-008.sh
```

---

# Aprendizaje
**El impacto de la Shell en las pruebas de sistema:** Las peculiaridades del lenguaje Bash (como el *Word-splitting* al no encomillar variables) pueden alterar silenciosamente los datos de prueba antes de que lleguen al sistema bajo evaluación. Un ingeniero de automatización de QA no solo debe entender el software que evalúa, sino dominar las sutilezas del entorno donde ejecutan sus scripts para no reportar bugs inexistentes.