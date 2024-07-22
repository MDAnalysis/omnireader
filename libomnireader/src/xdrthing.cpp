//
// Created by richard on 22/07/24.
//
#include "xdrthing.h"

class XDRImpl {
public:
    virtual size_t get_double(const char *src, double &output) = 0;
    virtual size_t get_float(const char *src, float &output) = 0;
};

class LEImpl : public XDRImpl {
    size_t get_float(const char *src, float &output) final {
        output = *((float*)(src));

        return sizeof(float);
    }
    size_t get_double(const char *src, double &output) final {
        output = *((double*)(src));

        return sizeof(double);
    }
};

class BEImpl : public XDRImpl {
    size_t get_float(const char *src, float &output) final {
        char tmp[4];

        for (int i=0; i<4; i++) {
            tmp[i] = src[3-i];
        }

        output = *((float*)(tmp));

        return sizeof(float);
    }

    size_t get_double(const char *src, double &output) final {
        char tmp[8];

        for (int i=0; i<8; i++) {
            tmp[i] = src[7-i];
        }

        output = *((double*)(tmp));

        return sizeof(double);
    }
};


XDRThing::XDRThing() {
    // figure out endianness
    const int i=1;

    if (reinterpret_cast<const char *>(&i)[3] == 1) {
        _impl = new BEImpl();
    } else {
        _impl = new LEImpl();
    }
}

XDRThing::~XDRThing() {
    if (_impl)
        free (_impl);
}

size_t XDRThing::get_float(const char *src, float &output) {
    return _impl->get_float(src, output);
}

size_t XDRThing::get_double(const char *src, double &output) {
    return _impl->get_double(src, output);
}
