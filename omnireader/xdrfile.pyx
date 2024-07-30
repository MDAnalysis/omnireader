cimport cython
from cython.operator cimport dereference

from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from libcpp.string cimport string as stdstring
from libcpp.vector cimport vector
from libcpp cimport bool as cbool
from libcpp.set cimport set as cset


cdef extern from "omnireader.h":
    cppclass XDRThing:
        cbool is_big_endian() const
        size_t get_float(const char *src, float &output) const
        size_t get_double(const char *src, double &output) const
        size_t get_int32(const char *src, int &output) const
        size_t get_uint32(const char *src, unsigned int &output) const
        size_t get_int64(const char *src, long long &output) const
        size_t get_uint64(const char *src, unsigned long long &output) const

cdef extern from "tpr_settings.h":
    cset[int] SUPPORTED_VERSIONS

    struct ftupdate:
        int fnvr
        int ftype
    ftupdate *ftupd
    int NFTUPD

    enum interaction_functions:
        F_BONDS
        F_G96BONDS
        F_MORSE
        F_CUBICBONDS
        F_CONNBONDS
        F_HARMONIC
        F_FENEBONDS
        F_TABBONDS
        F_TABBONDSNC
        F_RESTRBONDS
        F_ANGLES
        F_G96ANGLES
        F_RESTRANGLES
        F_LINEAR_ANGLES
        F_CROSS_BOND_BONDS
        F_CROSS_BOND_ANGLES
        F_UREY_BRADLEY
        F_QUARTIC_ANGLES
        F_TABANGLES
        F_PDIHS
        F_RBDIHS
        F_RESTRDIHS
        F_CBTDIHS
        F_FOURDIHS
        F_IDIHS
        F_PIDIHS
        F_TABDIHS
        F_CMAP
        F_GB12
        F_GB13
        F_GB14
        F_GBPOL
        F_NPSOLVATION
        F_LJ14
        F_COUL14
        F_LJC14_Q
        F_LJC_PAIRS_NB
        F_LJ
        F_BHAM
        F_LJ_LR
        F_BHAM_LR
        F_DISPCORR
        F_COUL_SR
        F_COUL_LR
        F_RF_EXCL
        F_COUL_RECIP
        F_LJ_RECIP
        F_DPD
        F_POLARIZATION
        F_WATER_POL
        F_THOLE_POL
        F_ANHARM_POL
        F_POSRES
        F_FBPOSRES
        F_DISRES
        F_DISRESVIOL
        F_ORIRES
        F_ORIRESDEV
        F_ANGRES
        F_ANGRESZ
        F_DIHRES
        F_DIHRESVIOL
        F_CONSTR
        F_CONSTRNC
        F_SETTLE
        F_VSITE1
        F_VSITE2
        F_VSITE2FD
        F_VSITE3
        F_VSITE3FD
        F_VSITE3FAD
        F_VSITE3OUT
        F_VSITE4FD
        F_VSITE4FDN
        F_VSITEN
        F_COM_PULL
        F_DENSITYFITTING
        F_EQM
        F_EPOT
        F_EKIN
        F_ETOT
        F_ECONSERVED
        F_TEMP
        F_VTEMP_NOLONGERUSED
        F_PDISPCORR
        F_PRES
        F_DHDL_CON
        F_DVDL
        F_DKDL
        F_DVDL_COUL
        F_DVDL_VDW
        F_DVDL_BONDED
        F_DVDL_RESTRAINT
        F_DVDL_TEMPERATURE
        F_NRE

    cdef struct InteractionKind:
        stdstring name
        stdstring description
        int natoms

    InteractionKind *interaction_types
    int N_INTERACTION_TYPES

cdef class XDRUnpacker:
    cdef XDRThing converter
    # todo: make this a stdstring?  essentially a smart pointer for bytes
    #       ptr would then be a size_t onto buffer.c_str()
    cdef char *buffer
    cdef char *ptr
    cdef int length
    cdef readonly cbool is_2020
    cdef readonly cbool double_prec

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

    cpdef stdstring read(self, int n):
        return stdstring(self.ptr, n)

    def reset(self, bytes data):
        self.double_prec = False
        self.is_2020 = False
        self._set_buffer(data, len(data))

    cpdef int get_position(self):
        return self.ptr - self.buffer

    cpdef void set_position(self, int pos):
        self.ptr = self.buffer + pos

    cpdef void set_is_2020(self, cbool i):
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

    cdef skip(self, size_t amount):
        """skip a number of bytes ahead
        
        saves doing byte swaps on stuff we're not going to look at
        """
        self.ptr += amount

    cpdef skip_real(self, int n):
        """skip n reals"""
        self.skip(n * 4)
        if self.double_prec:
            self.skip(n * 4)

    cdef skip_int32(self, int n):
        self.skip(n * 4)

    cdef skip_int64(self, int n):
        self.skip(n * 8)

    cdef skip_float(self, int n):
        self.skip(n * 4)

    cdef skip_double(self, int n):
        self.skip(n * 8)

    cdef skip_ushort(self, int n):
        if self.is_2020:
            self.skip(n * 2)
        else:
            self.skip(n * 4)


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


cdef class Box:
    cdef readonly double box[9]
    cdef readonly double box_rel[9]
    cdef readonly double box_v[9]


cpdef TpxHeader read_tpx_header(XDRUnpacker u):
    """Reads tpx header
    
    Also updates the XDRUnpacker to follow flags in the header:
    - precision (toggles unpack_real behaviour)
    - is_2020
    """
    cdef TpxHeader header = TpxHeader()

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


cdef vector[stdstring] do_symtab(XDRUnpacker up):
    cdef size_t i, symtab_nr
    cdef vector[stdstring] symtab
    cdef stdstring sym
    symtab_nr = up.unpack_int()
    symtab = vector[stdstring]()
    symtab.reserve(symtab_nr)
    for i in range(symtab_nr):
        sym = up.do_string()
        symtab.push_back(sym)

    return symtab

cdef void do_iparams(XDRUnpacker up,
                     TpxHeader header,
                     vector[int]& ftypes):
    """Skip past the various parameters
    
    We don't read any of these values, but we need to advance the file pointer
    past these values to get to the good bit
    """
    cdef int i, j

    for i in range(ftypes.size()):
        j = ftypes[i]

        # by the end of this you'll wish you had switch statements...
        # luckily the compiler will sort this out for us

        # TODO: Check and annotate with parameter names
        if (j == interaction_functions.F_ANGLES or
            j == interaction_functions.F_G96ANGLES or
            j == interaction_functions.F_BONDS or
            j == interaction_functions.F_G96BONDS or
            j == interaction_functions.F_IDIHS):
            # do_harm, i.e. rA, krA, rB, krB
            up.skip_real(4)
        elif j == interaction_functions.F_RESTRANGLES:
            up.skip_real(2)
        elif j == interaction_functions.F_LINEAR_ANGLES:
            up.skip_real(4)
        elif j == interaction_functions.F_FENEBONDS:
            up.skip_real(2)
        elif j == interaction_functions.F_RESTRBONDS:
            up.skip_real(8)
        elif (j == interaction_functions.F_TABBONDS or
              j == interaction_functions.F_TABBONDSNC or
              j == interaction_functions.F_TABANGLES or
              j == interaction_functions.F_TABDIHS):
            up.skip_real(1)
            up.skip_int32(1)
            up.skip_real(1)
        elif j == interaction_functions.F_CROSS_BOND_BONDS:
            up.skip_real(3)
        elif j == interaction_functions.F_CROSS_BOND_ANGLES:
            up.skip_real(4)
        elif j == interaction_functions.F_UREY_BRADLEY:
            up.skip_real(4)
            if header.file_version >= 79:
                up.skip_real(4)
        elif j == interaction_functions.F_QUARTIC_ANGLES:
            up.skip_real(6)
        elif j == interaction_functions.F_BHAM:
            up.skip_real(3)
        elif j == interaction_functions.F_MORSE:
            up.skip_real(3)
            if header.file_version >= 79:
                up.skip_real(3)
        elif j == interaction_functions.F_CUBICBONDS:
            up.skip_real(3)
        elif j == interaction_functions.F_CONNBONDS:
            pass
        elif j == interaction_functions.F_POLARIZATION:
            up.skip_real(1)
        elif j == interaction_functions.F_ANHARM_POL:
            up.skip_real(3)
        elif j == interaction_functions.F_WATER_POL:
            up.skip_real(6)
        elif j == interaction_functions.F_THOLE_POL:
            up.skip_real(3)
            if header.file_version < 127:  #  tpxv_RemoveTholeRfac
                up.skip_real(1)
        elif j == interaction_functions.F_LJ:
            up.skip_real(2)
        elif j == interaction_functions.F_LJ14:
            up.skip_real(4)
        elif j == interaction_functions.F_LJC14_Q:
            up.skip_real(5)
        elif j == interaction_functions.F_LJC_PAIRS_NB:
            up.skip_real(4)
        elif (j == interaction_functions.F_PIDIHS or
              j == interaction_functions.F_ANGRES or
              j == interaction_functions.F_ANGRESZ or
              j == interaction_functions.F_PDIHS):
            up.skip_real(4)
            up.skip_int32(1)
        elif  j == interaction_functions.F_RESTRDIHS:
            up.skip_real(2)
        elif j == interaction_functions.F_DISRES:
            up.skip_int32(2)
            up.skip_real(4)
        elif j == interaction_functions.F_ORIRES:
            up.skip_int32(3)
            up.skip_real(3)
        elif j == interaction_functions.F_DIHRES:
            if header.file_version < 72:
                up.skip_int32(2)
            up.skip_real(3)
            if header.file_version >= 72:
                up.skip_real(3)
        elif j == interaction_functions.F_POSRES:
            # 4 x do_rvec
            up.skip_real(3 * 4)
        elif j == interaction_functions.F_FBPOSRES:
            up.skip_int32(1)
            up.skip_real(3 + 2)  # do_rvec + 2
        elif j == interaction_functions.F_CBTDIHS:
            up.skip_real(6)  #  6 == NR_CBTDIHS
        elif j == interaction_functions.F_RBDIHS:
            up.skip_real(2 * 6)  # 6 == NR_RBDIHS
        elif j == interaction_functions.F_FOURDIHS:
            up.skip_real(2 * 6)  # 6 == NR_RBDIHS
        elif (j == interaction_functions.F_CONSTR or
              j == interaction_functions.F_CONSTRNC):
            up.skip_real(2)
        elif j == interaction_functions.F_SETTLE:
            up.skip_real(2)
        elif j == interaction_functions.F_VSITE1:
            pass
        elif (j == interaction_functions.F_VSITE2 or
              j == interaction_functions.F_VSITE2FD):
            up.skip_real(1)
        elif (j == interaction_functions.F_VSITE3 or
              j == interaction_functions.F_VSITE3FD or
              j == interaction_functions.F_VSITE3FAD):
            up.skip_real(2)
        elif (j == interaction_functions.F_VSITE3OUT or
              j == interaction_functions.F_VSITE4FD or
              j == interaction_functions.F_VSITE4FDN):
            up.skip_real(3)
        elif j == interaction_functions.F_VSITEN:
            up.skip_int32(1)
            up.skip_real(1)
        elif (j == interaction_functions.F_GB12 or
              j == interaction_functions.F_GB13 or
              j == interaction_functions.F_GB14):
            if header.file_version < 68:
                up.skip_real(4)
            up.skip_real(5)
        elif j == interaction_functions.F_CMAP:
            up.skip_int32(2)
        else:
            raise ValueError


cdef void do_ffparams(XDRUnpacker up, TpxHeader header):
    """Currently just skips..."""
    cdef int i, j
    cdef int k0, k1
    cdef int atnr, ntypes
    cdef double reppow, fudgeQQ
    cdef vector[int] functype = vector[int]()

    atnr = up.unpack_int()
    ntypes = up.unpack_int()
    functype.reserve(ntypes)
    for i in range(ntypes):  # ndo_int
        functype.push_back(up.unpack_int())

    if header.file_version >= 66:
        reppow = up.unpack_double()
    else:
        reppow = 12.0
    fudgeQQ = up.unpack_real()

    for i in range(ntypes):
        for j in range(NFTUPD):
            k0 = ftupd[j].fnvr
            k1 = ftupd[j].ftype

            if header.file_version < k0 and functype[i] >= k1:
                functype[i] += 1

    do_iparams(up, header, functype)


cdef struct Atom:
    double mass
    double charge
    # cdef double massB
    # cdef double chargeB
    int type_
    # cdef int typeB
    int ptype
    int resind
    int atomnumber


cdef inline Atom do_atom(XDRUnpacker up):
    cdef Atom a = Atom()

    a.mass = up.unpack_real()
    a.charge = up.unpack_real()
    up.skip_real(2)  # massB and chargeB
    a.type_ = up.unpack_ushort()
    up.skip_ushort(1)  # typeB
    a.ptype = up.unpack_int()
    a.resind = up.unpack_int()
    a.atomnumber = up.unpack_int()

    return a

cdef void do_atoms(XDRUnpacker up,
                   TpxHeader header,
                   vector[Atom]& atoms,
                   vector[int]& atomnames,
                   vector[int]& type_,
                   vector[int]& typeB,
                   vector[int]& resnames):
    cdef int i
    cdef int nr, nres
    cdef Atom a

    nr = up.unpack_int()  # number of atoms in a particular molecule
    nres = up.unpack_int()  # number of residues in a particular molecule

    atoms.reserve(nr)
    for i in range(nr):
        a = do_atom(up)
        atoms.push_back(a)

    # grab names, these are separate...
    atomnames.reserve(nr)
    for i in range(nr):
        atomnames.push_back(up.unpack_int())

    # also separate arrays of atom type and typeB
    type_.reserve(nr)
    for i in range(nr):
        type_.push_back(up.unpack_int())
    typeB.reserve(nr)
    for i in range(nr):
        typeB.push_back(up.unpack_int())

    do_resinfo(up, header, nres, resnames)


cdef void do_resinfo(XDRUnpacker up, TpxHeader header, int nres,
                     vector[int]& resnames):
    cdef int i

    resnames.reserve(nres)

    if header.file_version < 63:
        for i in range(nres):
            resnames.push_back(up.unpack_int())
    else:
        for i in range(nres):
            resnames.push_back(up.unpack_int())
            up.unpack_int()
            up.unpack_uchar()


cdef struct Ilist:
    int nr
    InteractionKind ik
    vector[int] iatoms


cdef vector[Ilist] do_ilists(XDRUnpacker up,
                             TpxHeader header):
    cdef int i, j, k0, k1, n, l
    cdef cbool bClear
    cdef vector[int] nr
    cdef vector[vector[int]] iatoms  # todo: could flatten this to vector[int] using nr array
    cdef vector[int] iatom
    cdef vector[Ilist] output

    nr = vector[int]()
    iatoms = vector[vector[int]]()

    for j in range(interaction_functions.F_NRE):
        bClear = False

        for i in range(NFTUPD):
            k0 = ftupd[i].fnvr
            k1 = ftupd[i].ftype
            if header.file_version < k0 and j == k1:
                bClear = True

        if bClear:
            nr.push_back(0)
            iatoms.push_back(vector[int]())
        else:
            # do_ilist
            n = up.unpack_int()
            nr.push_back(n)
            iatom = vector[int]()
            for l in range(n):
                iatom.push_back(up.unpack_int())
            iatoms.push_back(iatom)

    # todo: could be constructing this inside the above loops
    output = vector[Ilist]()
    output.reserve(nr.size())
    for i in range(nr.size()):
        output.push_back(Ilist(
            nr[i], dereference(interaction_types + i),  iatoms[i],
        ))

    return output


cdef void do_block(XDRUnpacker up):
    cdef int n

    n = up.unpack_int()  # for cgs: charge groups
    up.skip_int32(n + 1)


cdef void do_blocka(XDRUnpacker up):
    cdef int n1, n2

    n1 = up.unpack_int()  # No. of atoms with excls
    n2 = up.unpack_int()  # total times fo appearance of atoms for excls
    up.skip_int32(n1 + 1)
    up.skip_int32(n2)


cdef struct MolType:
    int name_idx
    vector[Atom] atoms
    vector[int] atom_indices
    vector[int] types
    vector[int] typeBs
    vector[int] resname_indices
    vector[Ilist] ilists


cdef MolType do_moltype(XDRUnpacker up,
                        TpxHeader header):
    cdef vector[Atom] atoms
    cdef vector[int] atomnames, type_, typeB, resnames
    cdef vector[Ilist] ilists
    cdef int molname

    molname = up.unpack_int()  # actually an int referencing the name elsewhere

    atoms = vector[Atom]()
    atomnames = vector[int]()
    type_ = vector[int]()
    typeB = vector[int]()
    resnames = vector[int]()
    do_atoms(up, header,
             atoms, atomnames, type_, typeB, resnames)

    ilists = do_ilists(up, header)

    do_block(up)
    do_blocka(up)

    return MolType(
        molname,
        atoms,
        atomnames,
        type_,
        typeB,
        resnames,
        ilists
    )


cdef struct MolBlock:
    int type_
    int nmol
    int natoms


cdef MolBlock do_molblock(XDRUnpacker up,
                          TpxHeader header):
    cdef int type_, nmol, natoms
    cdef int i, nposresA, nposresB

    type_ = up.unpack_int()
    nmol = up.unpack_int()
    natoms = up.unpack_int()
    # for A then B, the number of posres coords and the coords
    # skip past these sections
    nposresA = up.unpack_int()
    up.skip_real(nposresA)
    nposresB = up.unpack_int()
    up.skip_real(nposresB)

    return MolBlock(type_, nmol, natoms)


cdef struct MTop:
    int system_name
    vector[stdstring] symtab


cpdef MTop do_mtop(XDRUnpacker up,
                  TpxHeader header):
    cdef vector[stdstring] symtab
    cdef int i, nmoltype, nmolblock
    cdef MTop mtop = MTop()
    cdef MolType mt
    cdef MolBlock mb

    mtop.symtab = do_symtab(up)

    mtop.system_name = up.unpack_int()

    do_ffparams(up, header)

    # print('after ff_params at: ', up.get_position())

    nmoltype = up.unpack_int()
    for i in range(nmoltype):
        mt = do_moltype(up, header)
        # print(f'after mol {i} at pos {up.get_position()}')

    nmolblock = up.unpack_int()
    for i in range(nmolblock):
        mb = do_molblock(up, header)
        # print(f'after molblock {i} at pos {up.get_position()}')

    return mtop


cdef Box extract_box_info(XDRUnpacker up):
    cdef Box b = Box()
    cdef int i
    cdef double x

    for i in range(9):
        x = up.unpack_real()
        b.box[i] = x
    for i in range(9):
        x = up.unpack_real()
        b.box_rel[i] = x
    for i in range(9):
        x = up.unpack_real()
        b.box_v[i] = x

    return b


def parse(bytes data):
    cdef XDRUnpacker up
    cdef TpxHeader header
    cdef MTop mtop
    cdef Box box
    cdef int i

    up = XDRUnpacker(data)

    header = read_tpx_header(up)
    if header.bBox:
        box = extract_box_info(up)
    else:
        box = Box()

    for i in range(header.ngtc):
        if header.file_version < 69:
            up.skip_real(1)
        up.skip_real(1)  # relevant to Berendsen tcoupl_lambda

    if header.bTop:
        mtop = do_mtop(up, header)

    return header, box

def allowed_version(int i):
    cdef int ret
    ret = SUPPORTED_VERSIONS.count(i)

    return ret
