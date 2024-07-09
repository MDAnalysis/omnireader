
from libcpp cimport bool
from libcpp.string cimport string as stdstring
from libc.stdlib cimport atoi, atof

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
        stdstring getline()
        bool at_eof()
        void seek()
        unsigned long long tell()

    Reader* GetReader(int f)


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

    cdef stdstring cline
    lines = []
    while not r.at_eof():
        cline = r.getline()
        lines.append(cline)

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

    cline = r.getline()
    natoms = atoi(cline.c_str())
    r.getline()  # comment line in file

    cdef object xyzarr
    xyzarr = np.empty(natoms * 3, dtype=np.float32)
    cdef float[::1] xyzarr_view = xyzarr
    cdef float tmpcoord

    cdef const char* cstrline
    for i in range(natoms):
        cline = r.getline()
        cstrline = cline.c_str()
        find_starts(cstrline, cstrline + cline.length(), starts)

        # starts[0] is element symbol
        # starts[1,2,3] are coordinates
        tmpcoord = atof(cstrline + starts[1])
        xyzarr_view[i*3 + 0] = tmpcoord
        tmpcoord = atof(cstrline + starts[2])
        xyzarr_view[i*3 + 1] = tmpcoord
        tmpcoord = atof(cstrline + starts[3])
        xyzarr_view[i*3 + 2] = tmpcoord

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

        cline = self.r.getline()
        natoms = atoi(cline.c_str())
        self.r.getline()  # comment line in file
        cdef const char* cstrline
        for i in range(natoms):
            cline = self.r.getline()
            cstrline = cline.c_str()
            find_starts(cstrline, cstrline + cline.length(), starts)

            # starts[0] is element symbol
            # starts[1,2,3] are coordinates
            tmpcoord = atof(cstrline + starts[1])
            xyzarr_view[i*3 + 0] = tmpcoord
            tmpcoord = atof(cstrline + starts[2])
            xyzarr_view[i*3 + 1] = tmpcoord
            tmpcoord = atof(cstrline + starts[3])
            xyzarr_view[i*3 + 2] = tmpcoord

        return xyzarr.reshape((natoms, 3))

    def read_coords(self, natoms):
        cdef object xyzarr
        xyzarr = np.empty(natoms * 3, dtype=np.float32)

        return self.read_coords_into(xyzarr)

