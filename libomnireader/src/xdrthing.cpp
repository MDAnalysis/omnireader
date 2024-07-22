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
    // can't make this virtual in the parent class
    // e.g. "template<typename T> virtual size_t get_thing(etc)" is a no go
    template <typename T>
    size_t get_thing(const char *src, T &output) {
        output = *((T*)src);

        return sizeof(T);
    }

    size_t get_float(const char *src, float &output) final {
        return get_thing(src, output);
    }
    size_t get_double(const char *src, double &output) final {
        return get_thing(src, output);
    }
};

class BEImpl : public XDRImpl {
    template <typename T>
    size_t get_thing(const char *src, T &output) {
        char tmp[sizeof(T)];

        for (size_t i=0; i<sizeof(T); i++) {
            tmp[i] = src[sizeof(T) - 1 - i];
        }

        output = *((T*)tmp);

        return sizeof(T);
    }

    size_t get_float(const char *src, float &output) final {
        return get_thing(src, output);
    }

    size_t get_double(const char *src, double &output) final {
        return get_thing(src, output);
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
