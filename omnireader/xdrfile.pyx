cimport cython
from cython.operator cimport dereference

from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from libcpp.string cimport string as stdstring
from libcpp cimport bool as cbool


cdef extern from "omnireader.h":
    cppclass XDRThing:
        cbool is_big_endian() const
        size_t get_float(const char *src, float &output) const
        size_t get_double(const char *src, double &output) const
        size_t get_int32(const char *src, int &output) const
        size_t get_uint32(const char *src, unsigned int &output) const
        size_t get_int64(const char *src, long long &output) const
        size_t get_uint64(const char *src, unsigned long long &output) const


cdef class XDRUnpacker:
    cdef XDRThing converter
    # todo: make this a stdstring?  essentially a smart pointer for bytes
    #       ptr would then be a size_t onto buffer.c_str()
    cdef char *buffer
    cdef char *ptr
    cdef int length
    cdef cbool is_2020
    cdef cbool double_prec

    def __cinit__(self):
        self.buffer = NULL
        self.ptr = NULL
        self.length = 0
        self.double_prec = False

    def __init__(self, bytes data):
        self._set_buffer(data, len(data))
        self.double_prec = False
        self.is_2020 = False

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
        self.double_prec = False
        self.is_2020 = False
        self._set_buffer(data, len(data))

    cpdef int get_position(self):
        return self.ptr - self.buffer

    cpdef void set_position(self, int pos):
        self.ptr = self.buffer + pos

    cpdef set_is_2020(self, cbool i):
        """Toggle 2020 behaviour

        This changes the working of:
         - do_string
           - pre 2020, two ints followed by fstring (see below)
           - post 2020, one int64 followed by fstring (see below)
         - unpack_fstring
           - post 2020 no longer padded to 4 byte boundary
         - unpack_ushort
           - post 2020 uses 2 bytes not 4
         - unpack_uchar
           - post 2020 uses 1 byte not 4 per char
        """
        self.is_2020 = i

    cpdef void set_is_double(self, cbool is_double):
        """Toggles the behaviour of unpack_real"""
        self.double_prec = is_double

    cpdef double unpack_real(self):
        if self.double_prec:
            return self.unpack_double()
        else:
            return self.unpack_float()

    cpdef stdstring do_string(self):
        """This is different to unpack_string."""
        cdef int i32
        cdef unsigned long long i64

        if self.is_2020:
            i64 = self.unpack_uint64()
            return self.unpack_fstring(i64)
        else:
            # this seems to mean there's a useless int before each string
            # as unpack_string reads the length itself
            i32 = self.unpack_int()
            return self.unpack_string()

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

    @cython.cdivision(True)  # we want floor division inside here
    cpdef stdstring unpack_fstring(self, int n):
        cdef int j

        s = stdstring(self.ptr, n)

        if self.is_2020:
            # this version seems to not pad strings to 4 byte boundaries
            j = n
        else:
            # advance pointer to multiple of n bytes
            j = (n + 3) / 4 * 4

        self.ptr += j

        return s

    unpack_fopaque = unpack_fstring

    cpdef stdstring unpack_string(self):
        cdef int i
        i = self.unpack_int()

        return self.unpack_fstring(i)

    unpack_opaque = unpack_string

    unpack_bytes = unpack_string

    def unpack_list(self, unpack_item):
        pass

    def unpack_farray(self, unpack_item):
        pass

    def unpack_array(self, unpack_item):
        pass

    cpdef char unpack_uchar(self):
        cdef char val
        cdef int i

        if self.is_2020:
            # these are one byte long
            val = self.ptr[0]
            self.ptr += 1
        else:
            # older version, 4 bytes per char
            i = self.unpack_int()
            val = i

        return val

    cpdef unsigned int unpack_ushort(self):
        cdef int i
        cdef unsigned short j
        cdef size_t ret
        cdef char tmp[2]

        if self.is_2020:
            # this uses 2 bytes per short, still in network (BE) representation
            if self.converter.is_big_endian():
                tmp[0] = self.ptr[1]
                tmp[1] = self.ptr[0]
            else:
                tmp[0] = self.ptr[0]
                tmp[1] = self.ptr[1]

            j = dereference(<unsigned short*>&tmp)

            self.ptr += 2

            return j
        else:
            return self.unpack_int()


cdef class TpxHeader:
    cdef readonly stdstring version_string
    cdef readonly int precision
    cdef readonly int file_version
    cdef readonly int file_generation
    cdef readonly stdstring file_tag
    cdef readonly int natoms
    cdef readonly int ngtc
    cdef readonly int fep_state
    cdef readonly double lamb
    cdef readonly int bIr
    cdef readonly int bTop
    cdef readonly int bX
    cdef readonly int bV
    cdef readonly int bF
    cdef readonly int bBox
    cdef readonly unsigned long long size_of_tpr_body

    def __init__(self):
        pass


cdef class Box:
    cdef readonly double box[3]
    cdef readonly double box_rel[3]
    cdef readonly double box_v[3]


cpdef TpxHeader read_tpx_header(XDRUnpacker u):
    """Reads tpx header
    
    Also updates the XDRUnpacker to follow flags in the header:
    - precision (toggles unpack_real behaviour)
    - is_2020
    """
    cdef TpxHeader header

    header = TpxHeader()

    header.version_string = u.do_string()
    header.precision = u.unpack_int()
    if header.precision == 8:
        u.set_is_double(True)

    header.file_version = u.unpack_int()

    if 77 <= header.file_version <= 79:
        u.unpack_int()
        file_tag = u.do_string()

    if header.file_version >= 26:
        header.file_generation = u.unpack_int()
    else:
        header.file_generation = 0

    if header.file_version >= 81:
        header.file_tag = u.do_string()
    else:
        # setting.TPX_TAG_RELEASE
        header.file_tag = b"release"

    header.natoms = u.unpack_int()
    if header.file_version >= 28:
        header.ngtc = u.unpack_int()
    else:
        header.ngtc = 0

    if header.file_version < 62:
        u.unpack_int()  # idum
        u.unpack_real()  # rdum

    if header.file_version >= 79:
        header.fep_state = u.unpack_int()
    else:
        header.fep_state = 0

    header.lamb = u.unpack_real()

    header.bIr = u.unpack_int()
    header.bTop = u.unpack_int()
    header.bX = u.unpack_int()
    header.bV = u.unpack_int()
    header.bF = u.unpack_int()
    header.bBox = u.unpack_int()

    header.size_of_tpr_body = 0
    # setting.tpxc_addSizeField
    if header.file_version >= 119 and header.file_generation >= 27:
        header.size_of_tpr_body = u.unpack_int64()

    # finally update the unpacker if we're doing a gromacs 2020 tpr file
    if header.file_version >= 119 and header.file_generation <= 27:
        u.set_is_2020(1)

    return header


cdef Box extract_box_info(XDRUnpacker up):
    cdef Box b = Box()
    cdef int i
    cdef double x

    for i in range(3):
        x = up.unpack_real()
        b.box[i] = x
    for i in range(3):
        x = up.unpack_real()
        b.box_rel[i] = x
    for i in range(3):
        x = up.unpack_real()
        b.box_v[i] = x

    return b


def parse(bytes data):
    cdef XDRUnpacker up
    cdef TpxHeader header
    cdef Box box

    up = XDRUnpacker(data)

    header = read_tpx_header(up)

    box = extract_box_info(up)

    return header, box
