//
// Created by richard on 22/07/24.
//

#ifndef OMNIREADER_XDRTHING_H
#define OMNIREADER_XDRTHING_H

#include <cstring>
#include <string>

class XDRImpl;

class XDRThing {

public:
    XDRThing();

    ~XDRThing();

    size_t get_float(const char* src, float &output);
    size_t get_double(const char *src, double &output);
    size_t get_int32(const char *src, int &output);
    size_t get_uint32(const char *src, unsigned int &output);
    size_t get_int64(const char *src, long long &output);
    size_t get_uint64(const char *src, unsigned long long &output);

private:
    XDRImpl* _impl;
};

#endif //OMNIREADER_XDRTHING_H
