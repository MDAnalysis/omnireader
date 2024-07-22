from libc.stdlib cimport malloc, free
from libc.string cimport memcpy

cdef extern from "omnireader.h":
    cppclass XDRThing:
        size_t get_float(const char *src, float &output)
        size_t get_double(const char *src, double &output)
        size_t get_int32(const char *src, int &output)
        size_t get_uint32(const char *src, unsigned int &output)
        size_t get_int64(const char *src, long long &output)
        size_t get_uint64(const char *src, unsigned long long &output)

cdef class XDRUnpacker:
    cdef XDRThing converter
    cdef char *buffer
    cdef char *ptr
    cdef int length

    def __cinit__(self):
        self.buffer = NULL
        self.ptr = NULL
        self.length = 0

    def __init__(self, bytes data):
        self._set_buffer(data, len(data))

    def __dealloc__(self):
        if self.buffer != NULL:
            free(self.buffer)

    cdef _set_buffer(self, const char* data, int size):
        # first copy the data to be owned by this object
        self.length = size
        if self.buffer != NULL:
            free(self.buffer)
        self.buffer = <char*> malloc(size * sizeof(char))
        if self.buffer is NULL:
            raise ValueError("Failed to allocate buffer")
        memcpy(self.buffer, data, size * sizeof(char))

        self.ptr = self.buffer

    def reset(self, bytes data):
        self._set_buffer(data, len(data))

    cpdef int get_position(self):
        return self.ptr - self.buffer

    cdef void set_position(self, int pos):
        self.ptr = self.buffer + pos

    def get_buffer(self) -> bytes:
        return b''

    def done(self) -> bool:
        return self.get_position() == self.length

    cpdef unsigned int unpack_uint(self):
        cdef unsigned int i=0
        cdef size_t ret

        ret = self.converter.get_uint32(self.ptr, i)

        self.ptr += ret

        return i

    cpdef int unpack_int(self):
        cdef int i=0
        cdef size_t ret

        ret = self.converter.get_int32(self.ptr, i)

        self.ptr += ret

        return i

    cpdef long long unpack_int64(self):
        cdef long long i=0
        cdef size_t ret

        ret = self.converter.get_int64(self.ptr, i)

        self.ptr += ret

        return i

    cpdef unsigned long long unpack_uint64(self):
        cdef unsigned long long i=0
        cdef size_t ret

        ret = self.converter.get_uint64(self.ptr, i)

        self.ptr += ret

        return i

    unpack_enum = unpack_int

    def unpack_bool(self) -> bool:
        pass

    def unpack_uhyper(self):
        pass

    cpdef float unpack_float(self):
        cdef float i=0
        cdef size_t ret

        ret = self.converter.get_float(self.ptr, i)

        self.ptr += ret

        return i

    cpdef double unpack_double(self):
        cdef double i=0
        cdef size_t ret

        ret = self.converter.get_double(self.ptr, i)

        self.ptr += ret

        return i

    def unpack_fstring(self):
        pass

    unpack_fopaque = unpack_fstring

    def unpack_string(self):
        pass

    unpack_opaque = unpack_string

    unpack_bytes = unpack_string

    def unpack_list(self, unpack_item):
        pass

    def unpack_farray(self, unpack_item):
        pass

    def unpack_array(self, unpack_item):
        pass
