//
// Created by richard on 22/07/24.
//

#include <iostream>
#include "omnireader.h"


int main() {
    XDRThing x;

    char buffer[24];

    float a = 1.2;
    double b = 5.6;
    int c = 7;
    unsigned long long d = 1000;

    memcpy(buffer, &a, 4);
    memcpy(buffer + 4, &b, 8);
    memcpy(buffer + 12, &c, 4);
    memcpy(buffer + 16, &d, 8);

    size_t amt1, amt2, amt3, amt4;

    float a2;
    double b2;
    int c2;
    unsigned long long d2;

    amt1 = x.get_float(buffer, a2);
    amt2 = x.get_double(buffer + 4, b2);
    amt3 = x.get_int32(buffer + 12, c2);
    amt4 = x.get_uint64(buffer + 16, d2);

    std::cout << amt1 << " " << a2 << "\n";
    std::cout << amt2 << " " << b2 << "\n";
    std::cout << amt3 << " " << c2 << "\n";
    std::cout << amt4 << " " << d2 << "\n";
}