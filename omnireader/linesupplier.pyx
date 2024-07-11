
from libcpp cimport bool
from libcpp.string cimport string as stdstring

import cython
import numpy as np

from omnireader.libomnireader cimport (
    Format, Reader, GetReader,
)


cdef class LineSupplier:
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

    def get_line(self):
        cdef stdstring s = self.r.get_line()

        return s

    def advance(self):
        cdef bool ret
        ret = self.r.advance()

        return ret
