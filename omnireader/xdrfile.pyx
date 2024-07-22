from libc.stdlib cimport malloc, free
from libc.string cimport memcpy

cdef extern from "xdr.h":
    cdef enum xdr_op:
        XDR_ENCODE=0
        XDR_DECODE=1
        XDR_FREE=2

    cppclass XDR:
        pass

    cdef void xdrmem_create(XDR *xdr, char* buf,
                            unsigned int size, xdr_op op)

    cdef int XDR_SETPOS(XDR *xdr, unsigned int pos)
    cdef int XDR_GETINT32(XDR *xdr, int *pos)
    # cdef int XDR_GET_U_INT32(XDR *xdr, unsigned int *pos)

cdef class XDRUnpacker:
    cdef XDR impl
    cdef char *buffer
    cdef char *ptr
    cdef int length

    def __cinit__(self):
        self.buffer = NULL
        self.ptr = NULL
        self.length = 0

    def __init__(self, bytes data):
        cdef size_t n

        self._set_buffer(data, len(data))
        self.ptr = self.buffer

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
        # next initialise the XDR object
        xdrmem_create(&self.impl, self.buffer, self.length, xdr_op.XDR_DECODE)

    def reset(self, bytes data):
        self._set_buffer(data, len(data))

    cpdef int get_position(self):
        return self.ptr - self.buffer

    cdef void set_position(self, unsigned int pos):
        cdef unsigned int i
        cdef unsigned int j=44
        i = XDR_SETPOS(&self.impl, j)

    def get_buffer(self) -> bytes:
        return b''

    def done(self) -> bool:
        return self.get_position() == self.length

    def unpack_uint(self) -> int:
        pass

    def unpack_int(self) -> int:
        cdef int i
        cdef int ret = 0

        i = XDR_GETINT32(&self.impl, &ret)

        return ret

    def unpack_uint64(self) -> int:
        pass

    unpack_enum = unpack_int

    def unpack_bool(self) -> bool:
        pass

    def unpack_uhyper(self):
        pass

    def unpack_float(self) -> float:
        pass

    def unpack_double(self) -> float:
        pass

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
