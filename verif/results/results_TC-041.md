
## Ejecucion: 2026-11-19 21:20:31 -0600

```text
+ SERVIDOR_PID=
+ trap cleanup EXIT
+ [[ ! -x /mnt/c/Users/alan/Desktop/CUCEI/Proyecto_Sistemas_Avanzados/ppl/src/hermes/hermes ]]
+ cat
+ ESCENARIOS=(sin_delimitador excesiva nulo version sin_result sin_error json_roto)
+ ESPERADO=("cerró o rechazó la conexión" "Respuesta demasiado grande" "byte nulo" "version ausente o distinta de 1" "result ausente o no es objeto" "error ausente o vacío" "Respuesta inválida del servidor")
+ python3 /tmp/tmp.4NYkMYcsZ2/servidor_falso.py 45852 /tmp/tmp.4NYkMYcsZ2/listo sin_delimitador excesiva nulo version sin_result sin_error json_roto
+ SERVIDOR_PID=13155
++ seq 1 100
+ for _ in $(seq 1 100)
+ [[ -f /tmp/tmp.4NYkMYcsZ2/listo ]]
+ sleep 0.1
+ for _ in $(seq 1 100)
+ [[ -f /tmp/tmp.4NYkMYcsZ2/listo ]]
+ break
+ [[ ! -f /tmp/tmp.4NYkMYcsZ2/listo ]]
+ CLIENTE_LOG=/tmp/tmp.4NYkMYcsZ2/cliente.log
+ :
+ for indice in "${!ESCENARIOS[@]}"
+ escenario=sin_delimitador
+ esperado='cerró o rechazó la conexión'
+ estado=0
++ /mnt/c/Users/alan/Desktop/CUCEI/Proyecto_Sistemas_Avanzados/ppl/src/hermes/hermes red job 127.0.0.1 true
+ salida='Hermes Red: El servidor cerró o rechazó la conexión'
+ estado=1
+ printf '%s\n' 'Hermes Red: El servidor cerró o rechazó la conexión'
+ [[ 1 -eq 0 ]]
+ [[ Hermes Red: El servidor cerró o rechazó la conexión != *cerró o rechazó la conexión* ]]
+ printf '  %-16s -> %s\n' sin_delimitador 'Hermes Red: El servidor cerró o rechazó la conexión'
  sin_delimitador  -> Hermes Red: El servidor cerró o rechazó la conexión
+ for indice in "${!ESCENARIOS[@]}"
+ escenario=excesiva
+ esperado='Respuesta demasiado grande'
+ estado=0
++ /mnt/c/Users/alan/Desktop/CUCEI/Proyecto_Sistemas_Avanzados/ppl/src/hermes/hermes red job 127.0.0.1 true
+ salida='Hermes Red: Respuesta demasiado grande: excede el máximo de la red'
+ estado=1
+ printf '%s\n' 'Hermes Red: Respuesta demasiado grande: excede el máximo de la red'
+ [[ 1 -eq 0 ]]
+ [[ Hermes Red: Respuesta demasiado grande: excede el máximo de la red != *Respuesta demasiado grande* ]]
+ printf '  %-16s -> %s\n' excesiva 'Hermes Red: Respuesta demasiado grande: excede el máximo de la red'
  excesiva         -> Hermes Red: Respuesta demasiado grande: excede el máximo de la red
+ for indice in "${!ESCENARIOS[@]}"
+ escenario=nulo
+ esperado='byte nulo'
+ estado=0
++ /mnt/c/Users/alan/Desktop/CUCEI/Proyecto_Sistemas_Avanzados/ppl/src/hermes/hermes red job 127.0.0.1 true
+ salida='Hermes Red: Respuesta inválida del servidor: contiene un byte nulo'
+ estado=1
+ printf '%s\n' 'Hermes Red: Respuesta inválida del servidor: contiene un byte nulo'
+ [[ 1 -eq 0 ]]
+ [[ Hermes Red: Respuesta inválida del servidor: contiene un byte nulo != *byte nulo* ]]
+ printf '  %-16s -> %s\n' nulo 'Hermes Red: Respuesta inválida del servidor: contiene un byte nulo'
  nulo             -> Hermes Red: Respuesta inválida del servidor: contiene un byte nulo
+ for indice in "${!ESCENARIOS[@]}"
+ escenario=version
+ esperado='version ausente o distinta de 1'
+ estado=0
++ /mnt/c/Users/alan/Desktop/CUCEI/Proyecto_Sistemas_Avanzados/ppl/src/hermes/hermes red job 127.0.0.1 true
+ salida='Hermes Red: Respuesta inválida del servidor: version ausente o distinta de 1'
+ estado=1
+ printf '%s\n' 'Hermes Red: Respuesta inválida del servidor: version ausente o distinta de 1'
+ [[ 1 -eq 0 ]]
+ [[ Hermes Red: Respuesta inválida del servidor: version ausente o distinta de 1 != *version ausente o distinta de 1* ]]
+ printf '  %-16s -> %s\n' version 'Hermes Red: Respuesta inválida del servidor: version ausente o distinta de 1'
  version          -> Hermes Red: Respuesta inválida del servidor: version ausente o distinta de 1
+ for indice in "${!ESCENARIOS[@]}"
+ escenario=sin_result
+ esperado='result ausente o no es objeto'
+ estado=0
++ /mnt/c/Users/alan/Desktop/CUCEI/Proyecto_Sistemas_Avanzados/ppl/src/hermes/hermes red job 127.0.0.1 true
+ salida='Hermes Red: Respuesta inválida del servidor: result ausente o no es objeto'
+ estado=1
+ printf '%s\n' 'Hermes Red: Respuesta inválida del servidor: result ausente o no es objeto'
+ [[ 1 -eq 0 ]]
+ [[ Hermes Red: Respuesta inválida del servidor: result ausente o no es objeto != *result ausente o no es objeto* ]]
+ printf '  %-16s -> %s\n' sin_result 'Hermes Red: Respuesta inválida del servidor: result ausente o no es objeto'
  sin_result       -> Hermes Red: Respuesta inválida del servidor: result ausente o no es objeto
+ for indice in "${!ESCENARIOS[@]}"
+ escenario=sin_error
+ esperado='error ausente o vacío'
+ estado=0
++ /mnt/c/Users/alan/Desktop/CUCEI/Proyecto_Sistemas_Avanzados/ppl/src/hermes/hermes red job 127.0.0.1 true
+ salida='Hermes Red: Respuesta inválida del servidor: error ausente o vacío'
+ estado=1
+ printf '%s\n' 'Hermes Red: Respuesta inválida del servidor: error ausente o vacío'
+ [[ 1 -eq 0 ]]
+ [[ Hermes Red: Respuesta inválida del servidor: error ausente o vacío != *error ausente o vacío* ]]
+ printf '  %-16s -> %s\n' sin_error 'Hermes Red: Respuesta inválida del servidor: error ausente o vacío'
  sin_error        -> Hermes Red: Respuesta inválida del servidor: error ausente o vacío
+ for indice in "${!ESCENARIOS[@]}"
+ escenario=json_roto
+ esperado='Respuesta inválida del servidor'
+ estado=0
++ /mnt/c/Users/alan/Desktop/CUCEI/Proyecto_Sistemas_Avanzados/ppl/src/hermes/hermes red job 127.0.0.1 true
+ salida='Hermes Red: Respuesta inválida del servidor: [json.exception.parse_error.101] parse error at line 1, column 2: syntax error while parsing object key - invalid literal; last read: '\''{e'\''; expected string literal'
+ estado=1
+ printf '%s\n' 'Hermes Red: Respuesta inválida del servidor: [json.exception.parse_error.101] parse error at line 1, column 2: syntax error while parsing object key - invalid literal; last read: '\''{e'\''; expected string literal'
+ [[ 1 -eq 0 ]]
+ [[ Hermes Red: Respuesta inválida del servidor: [json.exception.parse_error.101] parse error at line 1, column 2: syntax error while parsing object key - invalid literal; last read: '{e'; expected string literal != *Respuesta inválida del servidor* ]]
+ printf '  %-16s -> %s\n' json_roto 'Hermes Red: Respuesta inválida del servidor: [json.exception.parse_error.101] parse error at line 1, column 2: syntax error while parsing object key - invalid literal; last read: '\''{e'\''; expected string literal'
  json_roto        -> Hermes Red: Respuesta inválida del servidor: [json.exception.parse_error.101] parse error at line 1, column 2: syntax error while parsing object key - invalid literal; last read: '{e'; expected string literal
+ echo 'PASS V1/AC1: las siete respuestas inválidas se rechazan con diagnóstico claro.'
PASS V1/AC1: las siete respuestas inválidas se rechazan con diagnóstico claro.
+ grep -qE 'json\.exception|type_error|\[json' /tmp/tmp.4NYkMYcsZ2/cliente.log
+ echo 'FAIL: se filtró una excepción cruda de JSON al usuario.'
FAIL: se filtró una excepción cruda de JSON al usuario.
+ cat /tmp/tmp.4NYkMYcsZ2/cliente.log
Hermes Red: El servidor cerró o rechazó la conexión
Hermes Red: Respuesta demasiado grande: excede el máximo de la red
Hermes Red: Respuesta inválida del servidor: contiene un byte nulo
Hermes Red: Respuesta inválida del servidor: version ausente o distinta de 1
Hermes Red: Respuesta inválida del servidor: result ausente o no es objeto
Hermes Red: Respuesta inválida del servidor: error ausente o vacío
Hermes Red: Respuesta inválida del servidor: [json.exception.parse_error.101] parse error at line 1, column 2: syntax error while parsing object key - invalid literal; last read: '{e'; expected string literal
+ exit 1
+ cleanup
+ [[ -n 13155 ]]
+ kill -0 13155
+ rm -rf /tmp/tmp.4NYkMYcsZ2
+ printf '```\n'
```

## Ejecucion: 2026-11-19 21:21:54 -0600

```text
  sin_delimitador  -> Hermes Red: El servidor cerró o rechazó la conexión
  excesiva         -> Hermes Red: Respuesta demasiado grande: excede el máximo de la red
  nulo             -> Hermes Red: Respuesta inválida del servidor: contiene un byte nulo
  version          -> Hermes Red: Respuesta inválida del servidor: version ausente o distinta de 1
  sin_result       -> Hermes Red: Respuesta inválida del servidor: result ausente o no es objeto
  sin_error        -> Hermes Red: Respuesta inválida del servidor: error ausente o vacío
  json_roto        -> Hermes Red: Respuesta inválida del servidor: JSON mal formado
PASS V1/AC1: las siete respuestas inválidas se rechazan con diagnóstico claro.
PASS V2/AC2: ninguna excepción cruda de JSON llega al usuario.
PASS: RNF-14 TC-041 sin fallos.
```

## Ejecucion: 2026-11-19 21:22:33 -0600

```text
  sin_delimitador  -> Hermes Red: El servidor cerró o rechazó la conexión
  excesiva         -> Hermes Red: Respuesta demasiado grande: excede el máximo de la red
  nulo             -> Hermes Red: Respuesta inválida del servidor: contiene un byte nulo
  version          -> Hermes Red: Respuesta inválida del servidor: version ausente o distinta de 1
  sin_result       -> Hermes Red: Respuesta inválida del servidor: result ausente o no es objeto
  sin_error        -> Hermes Red: Respuesta inválida del servidor: error ausente o vacío
  json_roto        -> Hermes Red: Respuesta inválida del servidor: JSON mal formado
PASS V1/AC1: las siete respuestas inválidas se rechazan con diagnóstico claro.
PASS V2/AC2: ninguna excepción cruda de JSON llega al usuario.
PASS: RNF-14 TC-041 sin fallos.
```
