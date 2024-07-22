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
    virtual size_t get_int64(const char *src, long long &output) const = 0;
    virtual size_t get_uint64(const char *src, unsigned long long &output) const = 0;
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
    size_t get_int64(const char *src, long long &output) const final {
        return get_thing(src, output);
    }
    size_t get_uint64(const char *src, unsigned long long &output) const final {
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
    size_t get_int64(const char *src, long long &output) const final {
        return get_thing(src, output);
    }
    size_t get_uint64(const char *src, unsigned long long &output) const final {
        return get_thing(src, output);
    }
};


XDRThing::XDRThing() {
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

size_t XDRThing::get_float(const char *src, float &output) const {
    return _impl->get_float(src, output);
}
size_t XDRThing::get_double(const char *src, double &output) const {
    return _impl->get_double(src, output);
}
size_t XDRThing::get_int32(const char *src, int &output) const {
    return _impl->get_int32(src, output);
}
size_t XDRThing::get_uint32(const char *src, unsigned int &output) const {
    return _impl->get_uint32(src, output);
}
size_t XDRThing::get_int64(const char *src, long long &output) const {
    return _impl->get_int64(src, output);
}
size_t XDRThing::get_uint64(const char *src, unsigned long long &output) const {
    return _impl->get_uint64(src, output);
}