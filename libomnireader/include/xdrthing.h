//
// Created by richard on 22/07/24.
//

#ifndef OMNIREADER_XDRTHING_H
#define OMNIREADER_XDRTHING_H

#include <cstring>
#include <string>
#include <cstdint>

class XDRImpl;

class XDRThing {

public:
    XDRThing();

    ~XDRThing();

    size_t get_float(float &output);
    size_t get_double(double &output);
    size_t get_int32(int &output);
    size_t get_uint32(unsigned int &output);
    size_t get_int64(int64_t &output);
    size_t get_uint64(uint64_t &output);
    bool is_big_endian() const;
    void set_stream(const char* new_src) { src = new_src; ptr = src; }
    void set_double_precision(bool toggle) { double_precision = toggle; };
    void set_is_2020(bool toggle) { is_2020 = toggle; };
private:
    XDRImpl* _impl;
    const char *src;  // base of buffer
    const char *ptr;  // current read head
    bool double_precision;
    bool is_2020;
};

#endif //OMNIREADER_XDRTHING_H
