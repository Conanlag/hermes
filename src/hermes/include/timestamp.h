#ifndef __TIMESTAMP_H__
#define __TIMESTAMP_H__

#include <chrono>
#include <ctime>
#include <iomanip>
#include <sstream>
#include <string>




inline std::string obtenerFechaHoraActual() {
    auto now = std::chrono::system_clock::now();
    std::time_t now_c = std::chrono::system_clock::to_time_t(now);
    std::stringstream ss;
    ss << std::put_time(std::localtime(&now_c), "%Y-%m-%d %H:%M:%S");
    return ss.str();
}

#endif // __TIMESTAMP_H__