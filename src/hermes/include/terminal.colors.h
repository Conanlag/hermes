#ifndef TERMINAL_COLORS_H
#define TERMINAL_COLORS_H

#include <iostream>

template <typename... Args>
void error(const Args&... args) {
    std::cerr << "\033[31m";
    (std::cerr << ... << args);
    std::cerr << "\033[0m" << std::endl;
}

template <typename... Args>
void warning(const Args&... args) {
    std::cerr << "\033[33m";
    (std::cerr << ... << args);
    std::cerr << "\033[0m" << std::endl;
}

template <typename... Args>
void info(const Args&... args) {
    std::cout << "\033[34m";
    (std::cout << ... << args);
    std::cout << "\033[0m" << std::endl;
}

#endif