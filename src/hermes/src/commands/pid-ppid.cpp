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
