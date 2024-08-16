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
    XDRThing(const XDRThing& me) { abort(); }
    XDRThing& operator=(const XDRThing& me) { abort(); }
    ~XDRThing();

    // fundamental get operations defined in impl
    float get_float();
    double get_double();
    unsigned short get_uint16();
    int get_int32();
    unsigned int get_uint32();
    int64_t get_int64();
    uint64_t get_uint64();

    // derived operations
    bool get_bool() {
        if (is_2020) {
            bool output = *ptr++;
            return output;
        } else {
            return get_int32();
        }
    }
    unsigned char get_uchar() {
        if (is_2020) {
            unsigned char output = *ptr++;
            return output;
        } else {
            return get_int32();
        }
    }
    unsigned int get_ushort() {
        if (is_2020) {
            return get_uint16();
        } else {
            return get_uint32();
        }
    }
    double get_real() {
        if (double_precision) {
            return get_double();
        } else {
            return get_float();
        }
    }
    std::string do_string() {
        int i32;
        int64_t i64;
        std::string out;

        if (is_2020) {
            i64 = get_int64();

            out = std::string(ptr, i64);
            ptr += i64;
        } else {
            i32 = get_int32();  // yes really
            get_int32();

            out = std::string(ptr, i32);

            size_t j = (i32 + 3) / 4 * 4;
            ptr += j;
        }

        return out;
    }

    // skips
    void skip(size_t amount) {
        ptr += amount;
    }
    void skip_real(size_t n) {
        // skips n reals
        if (double_precision) {
            skip(n * 8);
        } else {
            skip(n * 4);
        }
    }
    void skip_int(size_t n) { skip(n * 4); }
    void skip_ushort(size_t n) {
        if (is_2020) {
            skip(n * 2);
        } else {
            skip( n * 4);
        }
    }
    void skip_bool(size_t n) {
        if (is_2020) {
            skip(n);
        } else {
            skip(n * 4);
        }
    }

    bool is_big_endian() const;
    void set_stream(const char* new_src) { src = new_src; ptr = src; }
    void set_double_precision(bool toggle) { double_precision = toggle; };
    bool get_double_precision() const { return double_precision; }
    void set_is_2020(bool toggle) { is_2020 = toggle; };
    bool get_is_2020() const { return is_2020; };
private:
    XDRImpl* _impl;
    const char *src;  // base of buffer
    const char *ptr;  // current read head
    bool double_precision;
    bool is_2020;
};

#endif //OMNIREADER_XDRTHING_H
