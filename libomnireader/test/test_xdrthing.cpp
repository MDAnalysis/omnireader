//
// Created by richard on 22/07/24.
//

#include <iostream>
#include "omnireader.h"


int main() {
    XDRThing x;

    char buffer[20];

    float a = 1.2;
    double b = 5.6;
    float c = 7.6;
    float d = 5.5;

    memcpy(buffer, &a, 4);
    memcpy(buffer + 4, &b, 8);
    memcpy(buffer + 12, &c, 4);
    memcpy(buffer + 16, &d, 4);

    size_t amt1, amt2, amt3, amt4;

    float a2, c2, d2;
    double b2;

    amt1 = x.get_float(buffer, a2);
    amt2 = x.get_double(buffer + 4, b2);
    amt3 = x.get_float(buffer + 12, c2);
    amt4 = x.get_float(buffer + 16, d2);

    std::cout << amt1 << " " << a2 << "\n";
    std::cout << amt2 << " " << b2 << "\n";
    std::cout << amt3 << " " << c2 << "\n";
    std::cout << amt4 << " " << d2 << "\n";
}