# Uso de inteligencia artificial

# 17. Script de validación TC-005 y Depuración de Cancelaciones (RF-10)

## Objetivo

Construir y auditar el script automatizado para la cancelación de procesos en ejecución (TC-005), eliminando los falsos defectos ocasionados por la destrucción prematura de procesos en background y la malinterpretación de los códigos de salida de la aplicación.

---

## Prompt 1
```text
ahora analiza el TC-005:
[Muestra el caso de prueba donde el resultado dice PASS pero el Estado general se marcó con FAIL debido a la incertidumbre generada por el script automatizado previo].
```

---

## Resultado 1

Se identificó la contradicción documental. Se hipotetizó que el caso sufría exactamente los mismos "falsos defectos" de los scripts anteriores: muerte por SIGPIPE al crear el trabajo y aserciones rígidas de código de salida ($? -eq 1). Se proporcionó un script preliminar corregido usando redirecciones limpias.

---

## Prompt 2
```text
no he actualizado el .sh, primero esto haciendo los pasos a mano, mira:
./hermes job sleep 30
./hermes cancel 6
./hermes cancel 999999
[Muestra la salida manual donde el código C++ ejecuta la cancelación a la perfección e imprime los mensajes correctos de rechazo].
```

---

## Resultado 2

Se validó empíricamente mediante las pruebas manuales del usuario que el código fuente C++ cumplía el RF-10 a la perfección. Se comprobó que el programa maneja correctamente el paso a estado CANCELED con código -15 (SIGTERM), y el aislamiento del testigo.

---

## Prompt 3
```text
este es mi viejo .sh
[Muestra el código viejo y su salida: Paso 3 FAIL (10 no llegó a RUNNING)... Paso 7 FAIL]
```

---

## Resultado 3

Se realizó la autopsia del output del script viejo, comprobando matemáticamente el diagnóstico:
1. La tubería `| grep` mataba el proceso en background inmediatamente por SIGPIPE, por lo que jamás se registraba como RUNNING.
2. El Paso 7 exigía un exit 1 cuando el programa (correctamente) emitía el mensaje informativo con un exit 0.

---

## Prompt 4
```text
ok, este codigo no tiene falsos positivos?
[Muestra la corrida del nuevo script con resultado [PASS] TC-005]
aqui no hace falta agregar esto ? "No exige el [ $? -eq 1 ] en el Paso 7, solo busca que el texto de rechazo esté correcto."
```

---

## Resultado 4

Se confirmó que el nuevo script no contenía aserciones suaves ni falsos positivos; obligando al cumplimiento de múltiples condiciones estrictas (ej. "Estado: CANCELED" && "-15"). El usuario propuso exitosamente una mejora a la documentación técnica, agregando la aclaración sobre la remoción de la exigencia errónea del código 1, dejando evidencia del refinamiento en el criterio de aceptación.

---

# Modificaciones

**Estado de la resolución:** Aceptado tras validación empírica y automatizada cruzada.

**Revisión realizada:** Se validó que las aserciones del script Bash respetaran el ciclo de vida natural del proceso en Linux sin interrumpirlo prematuramente y se alinearan a los mensajes textuales reales del sistema, ignorando falsas alarmas provocadas por los códigos de retorno 0.

---

## Implementación de feature

Se integró un script automatizado `TC-005.sh` altamente confiable que aísla trabajos en background, valida estados concurrentes (RUNNING a CANCELED), respeta los procesos testigo (SUCCEEDED) y evalúa peticiones de rechazo de forma inteligente.

---

## Modificación de archivo

- Reescritura total de `verif/scripts/TC-005.sh`.
- Actualización de `verif/test-cases/TC-005.md` con el estado `[ PASS ]` y una nota técnica detallada sobre la corrección del falso positivo del script anterior (SIGPIPE y $?).

---

# Implementación final

```bash
bash verif/scripts/TC-005.sh
```

---

# Aprendizaje

1. **Testear el Test (Auditar las pruebas):** El hábito de realizar las pruebas paso a paso de forma manual demostró ser la herramienta definitiva para identificar cuándo un fallo proviene del código fuente y cuándo proviene del entorno de automatización (script).
2. **Robustez en aserciones compuestas:** Una buena prueba automatizada evita falsos positivos verificando múltiples variables clave simultáneamente (ej. validar que el estado cambie a CANCELED y que su código de salida corresponda estrictamente a una señal de interrupción -15).