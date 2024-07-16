
from libcpp cimport bool
from libcpp.string cimport string as stdstring
from libcpp.memory cimport unique_ptr

import cython
import numpy as np

from omnireader.libomnireader cimport (
    Format, Reader, GetReader,
)


cdef class LineSupplier:
    cdef unique_ptr[Reader] r


    def __init__(self, str fname):
        if fname.endswith('bz2'):
            self.r = GetReader(Format.BZ2)
        elif fname.endswith('gz'):
            self.r = GetReader(Format.GZ)
        else:
            self.r = GetReader(Format.PlainText)

        if not self.r.get().open(bytes(fname, 'utf-8')):
            raise ValueError


    def get_line(self):
        cdef stdstring s = self.r.get().get_line()

        return s

    def advance(self):
        cdef bool ret
        ret = self.r.get().advance()

        return ret
