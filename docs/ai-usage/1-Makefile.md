# Uso de inteligencia artificial

# 1. Hacer que el compilador makefile pueda compilar varios archivos .cpp sin necesidad de declararlos en el parametro SRC

## Objetivo: 
se generó un prompt para resolver como compilar de manera automatica cualquier archivo .cpp dentro de la carpeta ``` src/hermes/src ``` sin la necesidad de declararlo de manera manual en el parametro SRC. además pregunté dentro del código como acoplar comandos sin necesidad que todo estuviera en main.cpp

prompt:

```
quiero que Makefile compile todo mi proyecto tengo main.cpp y tengo pid-ppid.cpp
Por ahora declaro el src uno por uno
SRC = src/main.cpp src/pid-ppid.cpp

mi objetivo es que hermes sea un comando y me falta agregar parametros que regresen argumentos de por ejemplo viene en pid-ppid.cpp

por ejemplo que con hermes fork se ejecute pid-ppid.cpp
o hermes --version se ejecute version.cpp

este es makefile
CXX = g++

CXXFLAGS = -Wall -Wextra -std=c++17

TARGET = hermes

SRC = src/main.cpp src/pid-ppid.cpp src/version.cpp


INSTALL_DIR = $(HOME)/.local/bin

all: $(TARGET)

$(TARGET): $(SRC)

    $(CXX) $(CXXFLAGS) $(SRC) -o $(TARGET)

clean:

    rm -f $(TARGET)

install: $(TARGET)

    mkdir -p $(INSTALL_DIR)

    cp $(TARGET) $(INSTALL_DIR)/$(TARGET)

uninstall:

    rm -f $(INSTALL_DIR)/$(TARGET)

.PHONY: all clean install uninstall

Este mi main.cpp
#include <iostream>

int main() {
    std::cout << "HOLA ESTE ES EL INICIO DEL PROYECTO" << std::endl;

    return 0;
}
mi pid-ppid.cpp
#include <sys/wait.h> 
#include <unistd.h> 
 
#include <iostream> 
 
using std::cout; 
using std::endl; 
 
int proceso() {  
    fork(); 
    cout << "Hola estoy en pid-ppid.cpp" << endl; 
    return 0; 
} 
este es mi version.cpp
#include <iostream>

using std::cout;
using std::endl;

int version() { 
    cout << "version 0.1" << endl;
    return 0;
}
 ```

## Resultado recibido
```
Sí. Lo que necesitas realmente son **dos cosas separadas**:

1. Que el `Makefile` encuentre automáticamente todos los `.cpp` dentro de `src/`.
2. Que `main.cpp` sea el **punto de entrada** y, según el argumento (`fork`, `--version`, etc.), llame a la función correspondiente.

No necesitas generar un ejecutable diferente para cada `.cpp`. Lo ideal para `hermes` es compilar **todos los `.cpp` en un solo ejecutable**.

### 1. Estructura

Puedes tener:

```text
hermes/
├── Makefile
└── src/
    ├── main.cpp
    ├── pid-ppid.cpp
    └── version.cpp
```

### 2. `main.cpp`

Cambia tu `main.cpp` para recibir argumentos:

```cpp
#include <iostream>
#include <string>

int proceso();
int version();

int main(int argc, char* argv[]) {

    if (argc < 2) {
        std::cout << "HOLA ESTE ES EL INICIO DEL PROYECTO" << std::endl;
        return 0;
    }

    std::string comando = argv[1];

    if (comando == "fork") {
        return proceso();
    }

    if (comando == "--version") {
        return version();
    }

    std::cout << "Comando no reconocido: " << comando << std::endl;
    return 1;
}
```

Aquí:

```cpp
int proceso();
int version();
```

son las **declaraciones** de las funciones que están implementadas en los otros archivos.

Entonces:

```bash
hermes fork
```

termina llamando:

```cpp
proceso();
```

y:

```bash
hermes --version
```

termina llamando:

```cpp
version();
```

---

### 3. Tu `pid-ppid.cpp`

Puedes dejarlo así por ahora:

```cpp
#include <sys/wait.h>
#include <unistd.h>

#include <iostream>

using std::cout;
using std::endl;

int proceso() {
    fork();

    cout << "Hola estoy en pid-ppid.cpp" << endl;

    return 0;
}
```

Y `version.cpp`:

```cpp
#include <iostream>

using std::cout;
using std::endl;

int version() {
    cout << "version 0.1" << endl;
    return 0;
}
```

---

## 4. Makefile automático

En lugar de:

```makefile
SRC = src/main.cpp src/pid-ppid.cpp src/version.cpp
```

puedes hacer que Make encuentre todos los `.cpp` automáticamente:

```makefile
CXX = g++

CXXFLAGS = -Wall -Wextra -std=c++17

TARGET = hermes

SRC = $(wildcard src/*.cpp)

INSTALL_DIR = $(HOME)/.local/bin

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) $(SRC) -o $(TARGET)

clean:
	rm -f $(TARGET)

install: $(TARGET)
	mkdir -p $(INSTALL_DIR)
	cp $(TARGET) $(INSTALL_DIR)/$(TARGET)

uninstall:
	rm -f $(INSTALL_DIR)/$(TARGET)

.PHONY: all clean install uninstall
```

**Importante:** las líneas de comandos del Makefile deben comenzar con un **TAB**, no espacios.

La parte importante es:

```makefile
SRC = $(wildcard src/*.cpp)
```

Ahora si mañana agregas:

```text
src/
├── main.cpp
├── pid-ppid.cpp
├── version.cpp
├── memoria.cpp
└── procesos.cpp
```

Make automáticamente detectará:

```text
src/main.cpp
src/pid-ppid.cpp
src/version.cpp
src/memoria.cpp
src/procesos.cpp
```

No tendrás que modificar el Makefile.

---

## 5. Compilar

Desde:

```text
hermes/
```

ejecutas:

```bash
make
```

Obtendrás:

```text
hermes
```

Puedes probar:

```bash
./hermes
```

Resultado:

```text
HOLA ESTE ES EL INICIO DEL PROYECTO
```

Luego:

```bash
./hermes fork
```

y:

```text
Hola estoy en pid-ppid.cpp
Hola estoy en pid-ppid.cpp
```

Esto último ocurre porque estás haciendo:

```cpp
fork();
cout << ...
```

El proceso padre y el hijo continúan después del `fork()`, por eso ambos imprimen.

Y:

```bash
./hermes --version
```

produce:

```text
version 0.1
```

---

## 6. Después de `make install`

Como ya tienes:

```makefile
INSTALL_DIR = $(HOME)/.local/bin
```

puedes hacer:

```bash
make install
```

Esto instala:

```text
~/ .local/bin/hermes
```

realmente:

```text
/home/leo/.local/bin/hermes
```

sin `sudo`.

Si `~/.local/bin` está en tu `PATH`, podrás hacer directamente:

```bash
hermes fork
```

o:

```bash
hermes --version
```

---

### Una recomendación importante para tu proyecto

Como `hermes` va a crecer, **no te recomiendo hacer que `main.cpp` contenga toda la lógica de los comandos**.

La arquitectura que estás empezando a construir puede quedar así:

```text
hermes
   │
   ▼
main.cpp
   │
   ├── fork ──────► pid-ppid.cpp
   │
   ├── --version ─► version.cpp
   │
   ├── status ────► status.cpp
   │
   ├── run ───────► run.cpp
   │
   └── ...
```

`main.cpp` funciona como **dispatcher/router de comandos**, mientras que cada `.cpp` implementa su funcionalidad.

Más adelante incluso podemos llevarlo a algo más limpio:

```text
src/
├── main.cpp
├── commands/
│   ├── fork.cpp
│   ├── version.cpp
│   ├── status.cpp
│   └── run.cpp
├── process/
├── ipc/
├── network/
└── database/
```


## RESULTADOS

El resultado **no cumplió**  con lo pedido de manera completa. Los archivos que se encontraban en la carpeta de src pudieron compilarse correctamente sin embargo, probando archivos que estuvieran en carpetas hijas, no se compilaban. 

## Modificaciones

utilicé el comando find de Linux para que pudiera identificar todos los archivos con la extensión .cpp dentro


## Resultado modificado
```
SRC = $(shell find src -type f -name '*.cpp')
```

## Aprendizaje

El chat va a responder únicamente a la estructura que estas planteando dentro del proyecto, hay que declararle explicitamente las ubicaciones reales cada archivo para que pueda entender cual puede ser la solución que resuelve el problema de manera general.

