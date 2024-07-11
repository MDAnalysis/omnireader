# cython: language_level=3, boundscheck=False, embed_signature=True, c_string_type=unicode, c_string_encoding=default
from libc.string cimport strchr
from libc.stdlib cimport atoi, atof
from libcpp cimport bool
from libcpp.string cimport string as stdstring
from cython.operator import dereference
cimport cython

import numpy as np
from MDAnalysis.core.topologyattrs import (
    Atomnames,
    Atomtypes,
    Atomids,
    Masses,
    Resids,
    Resnames,
    Resnums,
    Segids,
)
from MDAnalysis.core.topology import Topology
from MDAnalysis.topology.base import TopologyReaderBase, change_squash
from MDAnalysis.topology import guessers

from omnireader.libomnireader cimport (
    PyUnicode_FromStringAndSize,
    strtoint,
    Format, Reader, GetReader,
)


cdef object stripwhitespace(const char* ptr, const char* end):
    # strips whitespace from both the start and end of ptr
    cdef int length
    cdef char letter
    cdef const char* ptr2
    # first advance start pointer to first non-whitespace character
    while (ptr < end):
        letter = dereference(ptr)
        if (letter != 11) and (letter != 32):  # tab or space
            break
        ptr += 1

    ptr2 = ptr
    while (ptr2 < end):
        letter = dereference(ptr2)
        if (letter == 11) or (letter == 32):
            break
        ptr2 += 1
    # set length to the distance between these
    length = ptr2 - ptr

    return PyUnicode_FromStringAndSize(ptr, length)


cdef class GROReader:
    cdef Reader* r

    def __cinit__(self):
        self.r = NULL
    
    def __init__(self, str fname):
        if fname.endswith('bz2'):
            self.r = GetReader(Format.BZ2)
        elif fname.endswith('gz'):
            self.r = GetReader(Format.GZ)
        else:
            self.r = GetReader(Format.PlainText)

        if not self.r.open(fname):
            raise ValueError

    def __dealloc__(self):
        if (self.r != NULL):
            del self.r
        
    @cython.wraparound(False)
    @cython.boundscheck(False)
    def read_coords(self):
        cdef const char* lptr
        cdef int i, cs, natoms
        cdef float tmp
        cdef const char* ptr

        self.r.advance()
        lptr = self.r.line_start()
        natoms = atoi(lptr)
        self.r.advance()

        out = np.empty(natoms * 3, dtype=np.float32, order='C')
        cdef float [::1] coords = out

        i = 0
        while not self.r.at_eof():
            lptr = self.r.line_start()

            if (i == 0):  # find spacing between coordinates
                cs = (strchr(lptr + 25, 46) - (lptr + 25)) + 1  # 46 == .
            
            ptr = lptr + 20
            
            coords[i * 3 + 0] = atof(ptr)
            coords[i * 3 + 1] = atof(ptr + cs)
            coords[i * 3 + 2] = atof(ptr + cs*2)
            
            i += 1
            if i == natoms:
                break
            self.r.advance()

        return out.reshape(-1, 3)

    @cython.wraparound(False)
    @cython.boundscheck(False)
    def parse_topology(self):
        cdef stdstring l
        cdef int natoms, i
        cdef const char* ptr
        cdef unsigned int[::1] resids_view
        cdef object[::1] resnames_view
        cdef object[::1] names_view
        cdef unsigned int[::1] indices_view
        
        self.r.advance()
        ptr = self.r.line_start()
        self.r.advance()
        natoms = atoi(ptr)

        resids = np.empty(natoms, dtype=np.uint32)
        resnames = np.empty(natoms, dtype=object)
        names = np.empty(natoms, dtype=object)
        indices = np.empty(natoms, dtype=np.uint32)

        resids_view = resids
        resnames_view = resnames
        names_view = names
        indices_view = indices

        cdef const char* lptr
        # [:5], [5:10], [10:15], [15:20]
        i = 0
        while not self.r.at_eof():
            lptr = self.r.line_start()

            resids_view[i] = strtoint(lptr, lptr + 5)
            resnames_view[i] = stripwhitespace(lptr + 5, lptr + 10)
            names_view[i] = stripwhitespace(lptr + 10, lptr + 15)
            indices_view[i] = strtoint(lptr + 15, lptr + 20)

            i += 1
            if (i == natoms):
                break
            self.r.advance()

        return resids, resnames, names, indices

    def to_topology(self):
        resids, resnames, names, indices = self.parse_topology()
        # Check all lines had names
        if not np.all(names):
            missing = np.where(names == '')
            raise IOError("Missing atom name on line: {0}"
                          "".format(missing[0][0] + 3))  # 2 header, 1 based

        # Fix wrapping of resids (if we ever saw a wrap)
        if np.any(resids == 0):
            # find places where resid hit zero again
            wraps = np.where(resids == 0)[0]
            # group these places together:
            # find indices of first 0 in each block of zeroes
            # 1) find large changes in index, (ie non sequential blocks)
            diff = np.diff(wraps) != 1
            # 2) make array of where 0-blocks start
            starts = np.hstack([wraps[0], wraps[1:][diff]])

            # remove 0 in starts, ie the first residue **can** be 0
            if starts[0] == 0:
                starts = starts[1:]

            # for each resid after a wrap, add 100k (5 digit wrap)
            for s in starts:
                resids[s:] += 100000

        # Guess types and masses
        atomtypes = guessers.guess_types(names)
        masses = guessers.guess_masses(atomtypes)

        residx, (new_resids, new_resnames) = change_squash(
                                (resids, resnames), (resids, resnames))

        # new_resids is len(residues)
        # so resindex 0 has resid new_resids[0]
        attrs = [
            Atomnames(names),
            Atomids(indices),
            Atomtypes(atomtypes, guessed=True),
            Resids(new_resids),
            Resnums(new_resids.copy()),
            Resnames(new_resnames),
            Masses(masses, guessed=True),
            Segids(np.array(['SYSTEM'], dtype=object))
        ]

        top = Topology(n_atoms=len(names), n_res=len(new_resids), n_seg=1,
                       attrs=attrs,
                       atom_resindex=residx,
                       residue_segindex=None)

        return top
