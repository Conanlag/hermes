# ERR-02 Hermes job no puede ejecutar programas con entradas de usuario adicionales
## Contexto: 
En el caso de ejecutar un programa que pida un input al usuario dentro del programa este pograma se terminara de manera automatica 
## Reproduccion: 

Guardar un codigo con entrada de usuario:
input.py
```
# Prueba input
print("--- FECHA DE NACIMIENTO ---")
dia_nac = int(input("Introduce el día de nacimiento (DD): "))
mes_nac = int(input("Introduce el mes de nacimiento (MM): "))
anio_nac = int(input("Introduce el año de nacimiento (AAAA): "))

print("\n--- FECHA ACTUAL ---")
dia_act = int(input("Introduce el día actual (DD): "))
mes_act = int(input("Introduce el mes actual (MM): "))
anio_act = int(input("Introduce el año actual (AAAA): "))

edad = anio_act - anio_nac

if (mes_act < mes_nac) or (mes_act == mes_nac and dia_act < dia_nac):
    edad -= 1  

print(f"\nTu edad exacta es: {edad} años.")

```
2. ejecutar el codigo 
```
hermes job python3 input.py
```
3. dara una salida con error
```--- FECHA DE NACIMIENTO ---
Introduce el día de nacimiento (DD): Traceback (most recent call last):
  File "/home/leo/tareas/proyecto/ppl/src/hermes/isa.py", line 3, in <module>
    dia_nac = int(input("Introduce el día de nacimiento (DD): "))
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
EOFError
```
y en jobs.json se vera lo siguiente:
```
    {
        "argumentos": [
            "input.py"
        ],
        "cancel_requested": false,
        "codigo_salida": 1,
        "job_id": 47,
        "pid": 24405,
        "programa": "python3",
        "status": "FAILED",
        "tiempo_inicio": "2026-10-02 12:41:44",
        "tiempo_recepcion": "2026-10-02 12:41:44",
        "tiempo_terminacion": "2026-10-02 12:41:44"
    }
```

## Posibles soluciones:
1. Acotar los tipos de programas que se pueden ejecutar. 
2. Desarrollar una solucion que pueda manejar entradas de usuarios de otros programas dentro de hermes.
