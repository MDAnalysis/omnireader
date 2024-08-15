//
// Created by richard on 22/07/24.
//
#include "xdrthing.h"

class XDRImpl {
public:
    explicit XDRImpl(bool is_big_endian) : is_big_endian(is_big_endian) {};
    bool is_big_endian;
    virtual size_t get_double(const char *src, double &output) const = 0;
    virtual size_t get_float(const char *src, float &output) const = 0;
    virtual size_t get_int32(const char *src, int &output) const = 0;
    virtual size_t get_uint32(const char *src, unsigned int &output) const = 0;
    virtual size_t get_int64(const char *src, int64_t &output) const = 0;
    virtual size_t get_uint64(const char *src, uint64_t &output) const = 0;
};

class BEImpl : public XDRImpl {
    // inherit constructor
    using XDRImpl::XDRImpl;

    // can't make this virtual in the parent class
    // e.g. "template<typename T> virtual size_t get_thing(etc)" is a no go
    template <typename T>
    size_t get_thing(const char *src, T &output) const {
        output = *((T*)src);

        return sizeof(T);
    }

    size_t get_float(const char *src, float &output) const final {
        return get_thing(src, output);
    }
    size_t get_double(const char *src, double &output) const final {
        return get_thing(src, output);
    }
    size_t get_int32(const char *src, int &output) const final {
        return get_thing(src, output);
    }
    size_t get_uint32(const char *src, unsigned int &output) const final {
        return get_thing(src, output);
    }
    size_t get_int64(const char *src, int64_t &output) const final {
        return get_thing(src, output);
    }
    size_t get_uint64(const char *src, uint64_t &output) const final {
        return get_thing(src, output);
    }
};

class LEImpl : public XDRImpl {
    using XDRImpl::XDRImpl;

    template <typename T>
    size_t get_thing(const char *src, T &output) const {
        char tmp[sizeof(T)];

        for (size_t i=0; i<sizeof(T); i++) {
            tmp[i] = src[sizeof(T) - 1 - i];
        }

        output = *((T*)tmp);

        return sizeof(T);
    }

    size_t get_float(const char *src, float &output) const final {
        return get_thing(src, output);
    }
    size_t get_double(const char *src, double &output) const final {
        return get_thing(src, output);
    }
    size_t get_int32(const char *src, int &output) const final {
        return get_thing(src, output);
    }
    size_t get_uint32(const char *src, unsigned int &output) const final {
        return get_thing(src, output);
    }
    size_t get_int64(const char *src, int64_t &output) const final {
        return get_thing(src, output);
    }
    size_t get_uint64(const char *src, uint64_t &output) const final {
        return get_thing(src, output);
    }
};


XDRThing::XDRThing() : double_precision(false), is_2020(false), src(nullptr), ptr(nullptr) {
    // figure out endianness
    const int i=1;

    if (reinterpret_cast<const char *>(&i)[3] == 1) {
        _impl = new BEImpl(true);
    } else {
        _impl = new LEImpl(false);
    }
}

XDRThing::~XDRThing() {
    if (_impl)
        free (_impl);
}

bool XDRThing::is_big_endian() const { return _impl->is_big_endian; }

size_t XDRThing::get_float(float &output) {
    size_t s = _impl->get_float(ptr, output);
    ptr += s;
    return s;
}
size_t XDRThing::get_double(double &output) {
    size_t s = _impl->get_double(ptr, output);
    ptr += s;
    return s;
}
size_t XDRThing::get_int32(int &output) {
    size_t s = _impl->get_int32(ptr, output);
    ptr += s;
    return s;
}
size_t XDRThing::get_uint32(unsigned int &output) {
    size_t s = _impl->get_uint32(ptr, output);
    ptr += s;
    return s;
}
size_t XDRThing::get_int64(int64_t &output) {
    size_t s = _impl->get_int64(ptr, output);
    ptr += s;
    return s;
}
size_t XDRThing::get_uint64(uint64_t &output) {
    size_t s = _impl->get_uint64(ptr, output);
    ptr += s;
    return s;
}