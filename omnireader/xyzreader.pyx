
from libcpp cimport bool
from libc.stdlib cimport atoi

import cython
import numpy as np


cdef extern from "omnireader.h" namespace "OmniReader":
    ctypedef enum Format:
        PlainText
        BZ2
        GZ

    cppclass Reader:
        Reader()
        bool open(const char* fname)
        const char* line_start()
        const char* line_end()
        bool advance()
        bool at_eof()

    Reader* GetReader(int f)


cdef extern from "fast_float.h" namespace "fast_float":
    cppclass from_chars_result[UC]:
        pass

    from_chars_result from_chars[T, UC](const UC *start, const UC* end, T& result)


def read_lines(fname):
    """Return all files from a given file"""
    cdef Reader* r

    if fname.endswith('bz2'):
        r = GetReader(Format.BZ2)
    elif fname.endswith('gz'):
        r = GetReader(Format.GZ)
    else:
        r = GetReader(Format.PlainText)

    if not r.open(fname.encode()):
        raise ValueError

    cdef const char* cline
    lines = []
    while not r.at_eof():
        cline = r.line_start()
        lines.append(cline)
        r.advance()

    del r

    return lines


cdef void find_starts(const char *start, const char *end,
                      int *where):
    cdef const char* ptr
    cdef bool saw_token = False

    ptr = start
    cdef int num=0
    cdef int max_breaks = 16
    for i in range(16):
        where[i] = -1

    while ptr < end:
        if saw_token:
            if ptr[0] == b' ':
                saw_token = False
        else:
            if ptr[0] != b' ':
                saw_token = True
                where[num] = ptr - start
                num += 1
                if num == max_breaks:
                    where[15] = -2
                    return
        ptr += 1


@cython.boundscheck(False)
@cython.wraparound(False)
def read_coords(fname):
    cdef Reader* r

    if fname.endswith('bz2'):
        r = GetReader(Format.BZ2)
    elif fname.endswith('gz'):
        r = GetReader(Format.GZ)
    else:
        r = GetReader(Format.PlainText)

    if not r.open(fname.encode()):
        raise ValueError

    cdef int natoms, i
    cdef float x, y, z
    cdef int starts[16]
    cdef const char* cline
    cdef const char* end

    cline = r.line_start()
    natoms = atoi(cline)
    r.advance()
    r.advance()  # comment line

    cdef object xyzarr
    xyzarr = np.empty(natoms * 3, dtype=np.float32)
    cdef float[::1] xyzarr_view = xyzarr
    cdef float tmpcoord


    for i in range(natoms):
        cline = r.line_start()
        end = r.line_end()
        find_starts(cline, end, starts)

        # starts[0] is element symbol
        # starts[1,2,3] are coordinates
        from_chars[float, char](cline + starts[1], end, tmpcoord)
        xyzarr_view[i*3 + 0] = tmpcoord
        from_chars[float, char](cline + starts[2], end, tmpcoord)
        xyzarr_view[i*3 + 1] = tmpcoord
        from_chars[float, char](cline + starts[3], end, tmpcoord)
        xyzarr_view[i*3 + 2] = tmpcoord

        r.advance()

    return xyzarr.reshape((natoms, 3))


cdef class XYZReader:
    cdef Reader *r

    def __cinit__(self):
        self.r = NULL

    def __init__(self, str fname):
        if fname.endswith('bz2'):
            self.r = GetReader(Format.BZ2)
        elif fname.endswith('gz'):
            self.r = GetReader(Format.GZ)
        else:
            self.r = GetReader(Format.PlainText)

        if not self.r.open(bytes(fname, 'utf-8')):
            raise ValueError

    def __dealloc__(self):
        if self.r != NULL:
            del self.r

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def read_coords_into(self, xyzarr):
        cdef float[::1] xyzarr_view = xyzarr.reshape(-1)
        cdef float tmpcoord
        cdef int i
        cdef int starts[16]
        cdef const char* cline
        cdef const char* end

        cline = self.r.line_start()
        natoms = atoi(cline)
        self.r.advance()
        self.r.advance()  # comment line in file

        for i in range(natoms):
            cline = self.r.line_start()
            end = self.r.line_end()
            find_starts(cline, end, starts)

            # starts[0] is element symbol
            # starts[1,2,3] are coordinates
            from_chars[float, char](cline + starts[1], end, tmpcoord)
            xyzarr_view[i * 3 + 0] = tmpcoord
            from_chars[float, char](cline + starts[2], end, tmpcoord)
            xyzarr_view[i * 3 + 1] = tmpcoord
            from_chars[float, char](cline + starts[3], end, tmpcoord)
            xyzarr_view[i * 3 + 2] = tmpcoord

            self.r.advance()

        return xyzarr.reshape((natoms, 3))

    def read_coords(self, natoms):
        cdef object xyzarr
        xyzarr = np.empty(natoms * 3, dtype=np.float32)

        return self.read_coords_into(xyzarr)

