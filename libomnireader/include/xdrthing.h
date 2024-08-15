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

    // fundamental get operations defined in impl
    size_t get_float(float &output);
    size_t get_double(double &output);
    size_t get_uint16(unsigned short &output);
    size_t get_int32(int &output);
    size_t get_uint32(unsigned int &output);
    size_t get_int64(int64_t &output);
    size_t get_uint64(uint64_t &output);

    // derived operations
    size_t get_bool(bool &output) {
        if (is_2020) {
            output = ptr[0];
            ptr += 1;
            return 1;
        } else {
            int tmp;
            get_int32(tmp);
            output = tmp;

            return 4;
        }
    }
    size_t get_uchar(unsigned char &output) {
        if (is_2020) {
            output = ptr[0];
            ptr += 1;
            return 1;
        } else {
            int tmp;
            get_int32(tmp);
            output = tmp;

            ptr += 4;
            return 4;
        }
    }
    size_t get_ushort(unsigned int &output) {
        if (is_2020) {
            unsigned short tmp;
            get_uint16(tmp);
            output = tmp;

            ptr += 2;
            return 2;
        } else {
            get_uint32(output);

            ptr += 4;
            return 4;
        }
    }
    size_t get_real(double &output) {
        if (double_precision) {
            return get_double(output);
        } else {
            float tmp;
            size_t ret = get_float(tmp);
            output = tmp;
            return ret;
        }
    }
    std::string do_string() {
        int i32;
        int64_t i64;
        std::string out;

        if (is_2020) {
            get_int64(i64);

            out = std::string(ptr, i64);
            ptr += i64;
        } else {
            get_int32(i32);  // yes really
            get_int32(i32);

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
    void set_is_2020(bool toggle) { is_2020 = toggle; };
private:
    XDRImpl* _impl;
    const char *src;  // base of buffer
    const char *ptr;  // current read head
    bool double_precision;
    bool is_2020;
};

#endif //OMNIREADER_XDRTHING_H
