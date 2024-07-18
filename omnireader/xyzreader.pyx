
from libcpp cimport bool as cbool
from libcpp.vector cimport vector
from libc.stdlib cimport atoi

import cython
from MDAnalysis.coordinates.base import (
    Timestep,  # todo: cimport this
    ReaderBase,
)
import numpy as np
from typing import Optional

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


cdef class XYZFrameIter:
    """Reads from XYZ format files into numpy arrays"""
    cdef Reader *r
    cdef vector[size_t] _offsets
    cdef size_t current_frame
    cdef float[::1] coord_buffer  # todo: floating prec
    cdef readonly int n_atoms

    def __cinit__(self):
        self.r = NULL

    def __dealloc__(self):
        if self.r != NULL:
            del self.r

    def __init__(self, str fname):
        if fname.endswith('bz2'):
            self.r = GetReader(Format.BZ2)
        elif fname.endswith('gz'):
            self.r = GetReader(Format.GZ)
        else:
            self.r = GetReader(Format.PlainText)

        if not self.r.open(bytes(fname, 'utf-8')):
            raise ValueError("Failed to open file")

        self.current_frame = -1
        # quickly peek at n_atoms
        self.n_atoms = atoi(self.r.line_start())
        self.coord_buffer = np.empty((self.n_atoms * 3), dtype=np.float32)

    def get_coordinates(self):
        return np.array(self.coord_buffer).reshape(-1, 3)

    def seek(self, size_t frame):
        """Seek to a given frame"""
        cdef cbool ok
        cdef size_t byte_offset

        if frame < self._offsets.size():
            # if frame is within known extent of file
            byte_offset = self._offsets[frame]
            self.current_frame = frame - 1
        else:
            # otherwise load up last known offset and proceed inside the while loop
            byte_offset = self._offsets[self._offsets.size() - 1]
            # this is 0 based, so len(offsets)==1 then we've got first frame etc
            self.current_frame = self._offsets.size() - 1

        ok = self.r.seek(byte_offset, SEEK_SET)
        if not ok:
            raise ValueError("Failed to seek")
        # if frame was known, this while loop only executes once,
        # otherwise it walks through the trajectory frame by frame
        # the logic to save offsets is done inside read_next_frame
        while self.current_frame < frame:
            self.read_next_frame()

    def tell(self) -> int:
        return self.current_frame

    def at_eof(self) -> bool:
        cdef cbool ok

        ok = self.r.at_eof()

        return bool(ok)

    def read_next_frame(self):
        cdef size_t current_offset
        cdef cbool ok
        current_offset = self.r.tell()

        ok = self.read_coords_into(self.coord_buffer)
        if not ok:
            raise IndexError

        self.current_frame += 1
        self._log_offset(self.current_frame, current_offset)

        return self.coord_buffer

    cdef inline void _log_offset(self, size_t frameno, size_t offset):
        # log where a frame offset was
        # this saves the offsets the first time they are seen
        # it is assumed that frames are only ever accessed sequentially from 0
        if frameno >= self._offsets.size():
            self._offsets.push_back(offset)

    cdef int read_n_frames(self):
        cdef int lines_per_frame = self.n_atoms + 2
        cdef int nlines = 0
        cdef size_t frameno
        # keep track of file handle position and restore this once we're done
        cdef size_t current = self.r.tell()

        try:
            self.r.seek(0, SEEK_SET)
            while not self.r.at_eof():
                if not nlines % lines_per_frame:
                    self._log_offset(frameno, self.r.tell())
                    frameno += 1
                self.r.advance()
                nlines += 1
        finally:
            self.r.seek(current, SEEK_SET)

        return self._offsets.size()

    def reopen(self):
        self.r.seek(0, SEEK_SET)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def read_atom_names(self) -> list:
        """Grab atom names from the current frame"""
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
    @cython.cdivision(True)
    cpdef cbool read_coords_into(self, float[::1] xyzarr, cbool header=True):
        """Attempts to read coordinates into array, returns success

        Parameters
        ----------
        xyzarr : np array
          array to read into, modified in place. should be of size natoms * 3
        header : bool
          if the header should be read, default true

        Returns
        -------
        success : bool
          returns True if frame fully read.  If False, the state of xyzarr is
          unreliable and may be partially filled
        """
        cdef float tmpcoord = 0.0
        cdef int i, natoms, nfields
        cdef vector[int] spans
        cdef const char* cline
        cdef const char* end

        if self.r.at_eof():
            return False

        if header:
            cline = self.r.line_start()
            if cline == NULL:
                return False
            if not (self.r.advance() and  self.r.advance()):
                return False

        natoms = xyzarr.shape[0] / 3

        for i in range(natoms):
            cline = self.r.line_start()
            end = self.r.line_end()
            spans.clear()
            nfields = find_spans(cline, end, spans)

            if nfields < 4:
                return False

            # starts[0] is element symbol
            # starts[1,2,3] are coordinates
            from_chars[float, char](cline + spans[2], cline + spans[3], tmpcoord)
            xyzarr[i * 3 + 0] = tmpcoord
            from_chars[float, char](cline + spans[4], cline + spans[5], tmpcoord)
            xyzarr[i * 3 + 1] = tmpcoord
            from_chars[float, char](cline + spans[6], cline + spans[7], tmpcoord)
            xyzarr[i * 3 + 2] = tmpcoord

            if not self.r.advance():
                return False

        return True

    def read_coords(self):
        cdef object xyzarr
        cdef int natoms
        cline = self.r.line_start()
        natoms = atoi(cline)
        self.r.advance()
        self.r.advance()  # comment line in file

        xyzarr = np.empty((natoms * 3), dtype=np.float32)

        ok = self.read_coords_into(xyzarr, header=False)

        if ok:
            return xyzarr.reshape((-1, 3))


class XYZReader(ReaderBase):
    _xyziter: XYZFrameIter
    ts: Timestep
    _n_frames: Optional[int]
    format = 'XYZ'

    def __init__(self, str fname, **kwargs):
        super(XYZReader, self).__init__(fname, **kwargs)
        self._xyziter = XYZFrameIter(fname)
        self._n_frames = None
        self._xyziter.read_next_frame()
        self.ts = self._get_ts()

    @property
    def n_frames(self):
        # cache and lazily evaluate this
        if self._n_frames is None:
            self._n_frames = self._xyziter.read_n_frames()
        return self._n_frames

    @property
    def n_atoms(self):
        return self._xyziter.n_atoms

    def _reopen(self):
        self._xyziter.reopen()

    def _get_ts(self) -> Timestep:
        """Turn state of red into Timestep"""
        self.ts = Timestep.from_coordinates(
            positions=self._xyziter.get_coordinates()
        )
        self.ts.frame = self._xyziter.tell()

        return self.ts

    def _read_frame(self, frame):
        self._xyziter.seek(frame)

        return self._get_ts()

    def _read_next_timestep(self, ts=None) -> Timestep:
        self._xyziter.read_next_frame()

        return self._get_ts()
