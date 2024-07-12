
from libcpp cimport bool as cbool
from libcpp.vector cimport vector
from libc.stdlib cimport atoi

import cython
import numpy as np

from omnireader.libomnireader cimport (
    PyUnicode_FromStringAndSize,
    Format, Reader, GetReader,
    from_chars,
    find_spans,
    SEEK_SET,
)


@cython.boundscheck(False)
@cython.wraparound(False)
def read_coords(fname):
    cdef Reader* r
    cdef nspans
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
    cdef vector[int] spans
    cdef const char* cline
    cdef const char* end

    cline = r.line_start()
    natoms = atoi(cline)
    r.advance()
    r.advance()  # comment line

    cdef object xyzarr
    xyzarr = np.empty(natoms * 3, dtype=np.float32)
    cdef float[::1] xyzarr_view = xyzarr
    cdef float tmpcoord = 0.0


    for i in range(natoms):
        cline = r.line_start()
        end = r.line_end()
        spans.clear()
        nspans = find_spans(cline, end, spans)

        # starts[0] is element symbol
        # starts[1,2,3] are coordinates
        from_chars[float, char](cline + spans[2], cline + spans[3], tmpcoord)
        xyzarr_view[i*3 + 0] = tmpcoord
        from_chars[float, char](cline + spans[4], cline + spans[5], tmpcoord)
        xyzarr_view[i*3 + 1] = tmpcoord
        from_chars[float, char](cline + spans[6], cline + spans[7], tmpcoord)
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

    def seek(self, unsigned long long pos):
        cdef cbool ok

        ok = self.r.seek(pos, SEEK_SET)

        if ok:
            return True
        else:
            return False

    def tell(self):
        return self.r.tell()

    def at_eof(self):
        cdef cbool ok

        ok = self.r.at_eof()

        return bool(ok)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def read_atom_names(self) -> list:
        cdef const char* cline
        cdef const char* end
        cdef int i, natoms
        cdef vector[int] spans
        cdef object name

        cline = self.r.line_start()
        natoms = atoi(cline)
        self.r.advance()
        self.r.advance()

        names = []
        for i in range(natoms):
            cline = self.r.line_start()
            end = self.r.line_end()
            find_spans(cline, end, spans)

            name = PyUnicode_FromStringAndSize(cline + spans[0], spans[1] - spans[0])
            names.append(name)

        return names

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def read_coords_into(self, xyzarr, header=True, n_atoms=0):
        cdef float[::1] xyzarr_view = xyzarr.reshape(-1)
        cdef float tmpcoord = 0.0
        cdef int i, natoms
        cdef vector[int] spans
        cdef const char* cline
        cdef const char* end

        if header:
            cline = self.r.line_start()
            natoms = atoi(cline)
            self.r.advance()
            self.r.advance()  # comment line in file
        else:
            natoms = n_atoms

        for i in range(natoms):
            cline = self.r.line_start()
            end = self.r.line_end()
            spans.clear()
            find_spans(cline, end, spans)

            # starts[0] is element symbol
            # starts[1,2,3] are coordinates
            from_chars[float, char](cline + spans[2], cline + spans[3], tmpcoord)
            xyzarr_view[i * 3 + 0] = tmpcoord
            from_chars[float, char](cline + spans[4], cline + spans[5], tmpcoord)
            xyzarr_view[i * 3 + 1] = tmpcoord
            from_chars[float, char](cline + spans[6], cline + spans[7], tmpcoord)
            xyzarr_view[i * 3 + 2] = tmpcoord

            self.r.advance()

        return xyzarr.reshape((-1, 3))

    def read_coords(self):
        cdef object xyzarr
        cline = self.r.line_start()
        natoms = atoi(cline)
        self.r.advance()
        self.r.advance()  # comment line in file

        xyzarr = np.empty(natoms * 3, dtype=np.float32)

        return self.read_coords_into(xyzarr, header=False, n_atoms=natoms)

