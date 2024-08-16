cimport cython
from MDAnalysis.topology.base import squash_by
from MDAnalysis.core.topology import Topology
from MDAnalysis.core.topologyattrs import (
    Atomids,
    Atomnames,
    Atomtypes,
    Masses,
    Charges,
    Elements,
    Resids,
    Resnames,
    Moltypes,
    Molnums,
    Segids,
    ChainIDs,
    Bonds,
    Angles,
    Dihedrals,
    Impropers,
)

import numpy as np

from cython.operator cimport dereference
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from libcpp.string cimport string as stdstring
from libcpp.vector cimport vector
from libc.stdint cimport int64_t, uint64_t
from libcpp cimport bool as cbool
from libcpp.set cimport set as cset

from omnireader.tpxv cimport (
    tpxv,
    interaction_functions,
)


cdef extern from "omnireader.h":
    cppclass XDRImpl:
        pass

    cppclass XDRThing:
        XDRImpl *impl
        const char *src
        const char *ptr
        cbool double_precision
        cbool is_2020

        XDRThing()
        cbool is_big_endian() const
        void set_stream(const char* src)
        void set_double_precision(cbool toggle)
        cbool get_double_precision()
        void set_is_2020(cbool toggle)
        cbool get_bool()
        unsigned int get_ushort()
        unsigned int get_uchar()
        double get_real()
        float get_float()
        double get_double()
        int get_int32()
        unsigned int get_uint32()
        int64_t get_int64()
        uint64_t get_uint64()
        stdstring do_string()
        void skip_real(size_t n)
        void skip_int(size_t n)
        void skip_ushort(size_t n)
        void skip_bool(size_t n)

cdef extern from "tpr_settings.h":
    struct ftupdate:
        int fnvr
        int ftype
    ftupdate *ftupd
    int NFTUPD

    int N_INTERACTION_TYPES

    enum BondedType:
        unused
        bonds
        settle
        angles
        dihedrals
        impropers

    BondedType* interaction_roles

cdef extern from *:
    """const std::set<int> SUPPORTED_VERSIONS = {58, 73, 83, 100, 103, 110, 112, 116, 119, 122, 127, 129, 133};"""
    cset[int] SUPPORTED_VERSIONS


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
    cdef readonly uint64_t size_of_tpr_body


cdef struct Box:
    double box[9]
    double box_rel[9]
    double box_v[9]


cdef TpxHeader read_tpx_header(XDRThing& u):
    """Reads tpx header
    
    Also updates the XDRThing to follow flags in the header:
    - precision (toggles unpack_real behaviour)
    - is_2020
    """
    cdef TpxHeader header = TpxHeader()

    header.version_string = u.do_string()
    header.precision = u.get_int32()
    if header.precision == 8:
        u.set_double_precision(1)

    header.file_version = u.get_int32()

    if 77 <= header.file_version <= 79:
        u.skip_int(1)
        file_tag = u.do_string()

    if header.file_version >= 26:
        header.file_generation = u.get_int32()
    else:
        header.file_generation = 0

    if header.file_version >= 81:
        header.file_tag = u.do_string()
    else:
        # setting.TPX_TAG_RELEASE
        header.file_tag = b"release"

    header.natoms = u.get_int32()
    if header.file_version >= 28:
        header.ngtc = u.get_int32()
    else:
        header.ngtc = 0

    if header.file_version < 62:
        u.skip_int(1)  # idum
        u.skip_real(1)  # rdum

    if header.file_version >= 79:
        header.fep_state = u.get_int32()
    else:
        header.fep_state = 0

    header.lamb = u.get_real()

    header.bIr = u.get_int32()
    header.bTop = u.get_int32()
    header.bX = u.get_int32()
    header.bV = u.get_int32()
    header.bF = u.get_int32()
    header.bBox = u.get_int32()

    header.size_of_tpr_body = 0
    # setting.tpxc_addSizeField
    if header.file_version >= 119 and header.file_generation >= 27:
        header.size_of_tpr_body = u.get_int64()

    # finally update the unpacker if we're doing a gromacs 2020 tpr file
    if header.file_version >= 119 and header.file_generation >= 27:
        u.set_is_2020(1)

    return header


cdef vector[stdstring] do_symtab(XDRThing& up):
    cdef size_t i, symtab_nr
    cdef vector[stdstring] symtab
    cdef stdstring sym
    symtab_nr = up.get_int32()
    symtab = vector[stdstring]()
    symtab.reserve(symtab_nr)
    for i in range(symtab_nr):
        sym = up.do_string()
        symtab.push_back(sym)

    return symtab

cdef void do_iparams(XDRThing& up,
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
            up.skip_int(1)
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
            up.skip_int(1)
        elif  j == interaction_functions.F_RESTRDIHS:
            up.skip_real(2)
        elif j == interaction_functions.F_DISRES:
            up.skip_int(2)
            up.skip_real(4)
        elif j == interaction_functions.F_ORIRES:
            up.skip_int(3)
            up.skip_real(3)
        elif j == interaction_functions.F_DIHRES:
            if header.file_version < 72:
                up.skip_int(2)
            up.skip_real(3)
            if header.file_version >= 72:
                up.skip_real(3)
        elif j == interaction_functions.F_POSRES:
            # 4 x do_rvec
            up.skip_real(3 * 4)
        elif j == interaction_functions.F_FBPOSRES:
            up.skip_int(1)
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
            up.skip_int(1)
            up.skip_real(1)
        elif (j == interaction_functions.F_GB12 or
              j == interaction_functions.F_GB13 or
              j == interaction_functions.F_GB14):
            if header.file_version < 68:
                up.skip_real(4)
            up.skip_real(5)
        elif j == interaction_functions.F_CMAP:
            up.skip_int(2)
        else:
            raise ValueError


cdef void do_ffparams(XDRThing& up, TpxHeader header):
    """Currently just skips..."""
    cdef int i, j, ftype
    cdef int k0, k1
    cdef int atnr, ntypes
    cdef double reppow, fudgeQQ
    cdef vector[int] functype = vector[int]()

    atnr = up.get_int32()
    ntypes = up.get_int32()
    functype.reserve(ntypes)
    for i in range(ntypes):  # ndo_int
        functype.push_back(up.get_int32())

    if header.file_version >= 66:
        reppow = up.get_double()
    else:
        reppow = 12.0
    fudgeQQ = up.get_real()

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


cdef inline Atom do_atom(XDRThing& up):
    cdef Atom a = Atom()

    a.mass = up.get_real()
    a.charge = up.get_real()
    up.skip_real(2)
    a.type_ = up.get_ushort()
    up.skip_ushort(1)  # typeB
    a.ptype = up.get_int32()
    a.resind = up.get_int32()
    a.atomnumber = up.get_int32()

    return a

cdef void do_atoms(XDRThing& up,
                   TpxHeader header,
                   vector[Atom]& atoms,
                   vector[int]& atomnames,
                   vector[int]& type_,
                   vector[int]& typeB,
                   vector[int]& resnames):
    cdef int i
    cdef int nr, nres

    nr = up.get_int32()  # number of atoms in a particular molecule
    nres = up.get_int32()  # number of residues in a particular molecule

    atoms.reserve(nr)
    for i in range(nr):
        atoms.push_back(do_atom(up))

    # grab names, these are separate...
    atomnames.reserve(nr)
    for i in range(nr):
        atomnames.push_back(up.get_int32())

    # also separate arrays of atom type and typeB
    type_.reserve(nr)
    for i in range(nr):
        type_.push_back(up.get_int32())
    typeB.reserve(nr)
    for i in range(nr):
        typeB.push_back(up.get_int32())

    do_resinfo(up, header, nres, resnames)


cdef void do_resinfo(XDRThing& up,
                     TpxHeader header,
                     int nres,
                     vector[int]& resnames):
    cdef int i

    resnames.reserve(nres)

    if header.file_version < 63:
        for i in range(nres):
            resnames.push_back(up.get_int32())
    else:
        for i in range(nres):
            resnames.push_back(up.get_int32())
            up.get_int32()
            up.get_uchar()


cdef struct Ilist:
    int nr
    vector[int] iatoms


cdef vector[Ilist] do_ilists(XDRThing& up,
                             TpxHeader header):
    cdef int i, j, k0, k1, l
    cdef cbool bClear
    cdef int nr
    cdef vector[int] iatom
    cdef vector[Ilist] output

    output = vector[Ilist]()
    output.reserve(interaction_functions.F_NRE)

    for j in range(interaction_functions.F_NRE):
        bClear = False

        for i in range(NFTUPD):
            k0 = ftupd[i].fnvr
            k1 = ftupd[i].ftype
            if header.file_version < k0 and j == k1:
                bClear = True

        iatom = vector[int]()
        if bClear:
            nr = 0
        else:
            # do_ilist
            nr = up.get_int32()
            for l in range(nr):
                iatom.push_back(up.get_int32())

        output.push_back(Ilist(nr, iatom))

    return output


cdef void do_block(XDRThing& up):
    cdef int n

    n = up.get_int32()  # for cgs: charge groups
    up.skip_int(n + 1)


cdef void do_blocka(XDRThing& up):
    cdef int n1, n2

    n1 = up.get_int32()  # No. of atoms with excls
    n2 = up.get_int32()  # total times fo appearance of atoms for excls
    up.skip_int(n1 + 1)
    up.skip_int(n2)


cdef struct MolType:
    int name_idx
    vector[Atom] atoms
    vector[int] atomnames
    vector[int] types
    vector[int] typeBs
    vector[int] resname_indices
    vector[Ilist] ilists


cdef MolType do_moltype(XDRThing& up,
                        TpxHeader header):
    cdef vector[Atom] atoms
    cdef vector[int] atomnames, type_, typeB, resnames
    cdef vector[Ilist] ilists
    cdef int molname

    molname = up.get_int32()  # actually an int referencing the name elsewhere

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


cdef MolBlock do_molblock(XDRThing& up,
                          TpxHeader header):
    cdef int type_, nmol, natoms
    cdef int i, nposresA, nposresB

    type_ = up.get_int32()
    nmol = up.get_int32()
    natoms = up.get_int32()
    # for A then B, the number of posres coords and the coords
    # skip past these sections
    nposresA = up.get_int32()
    up.skip_real(nposresA)
    nposresB = up.get_int32()
    up.skip_real(nposresB)

    return MolBlock(type_, nmol, natoms)


cdef void skip_atom_types(XDRThing& up,
                          TpxHeader header):
    # skip through do_atomtypes
    cdef int ntypes

    ntypes = up.get_int32()
    if header.file_version < tpxv.tpxv_RemoveImplicitSolvation:
        # skip nr real values
        up.skip_real(ntypes)

    ntypes = up.get_int32()
    up.skip_int(ntypes)  # atomnumbers?

    if 60 <= header.file_version < 113:  # >=
        up.skip_real(ntypes)
        up.skip_real(ntypes)


cdef void skip_cmaps(XDRThing& up):
    # skips through do_cmap section
    cdef int ngrid, grid_spacing, nelem

    ngrid = up.get_int32()
    grid_spacing = up.get_int32()

    nelem = grid_spacing * grid_spacing
    up.skip_real(ngrid * nelem * 4)


cdef void skip_groups(XDRThing& up):
    # skips through do_groups
    cdef int i, ngroups

    # this is do_grps
    for i in range(10):
        ngroups = up.get_int32()
        up.skip_int(ngroups)

    ngroups = up.get_int32()  # number of group names
    up.skip_int(ngroups)  # skip group names

    for i in range(10):
        ngroups = up.get_int32()
        up.skip_bool(ngroups)


cdef struct MTop:
    int system_name
    vector[stdstring] symtab
    vector[MolType] moltypes
    vector[MolBlock] molblocks


cdef MTop do_mtop(XDRThing& up,
                   TpxHeader header):
    cdef vector[stdstring] symtab
    cdef int i, nmoltype, nmolblock, natoms
    cdef int64_t nexcl
    cdef MTop mtop = MTop()
    cdef cbool has_intermolecular_bonds

    mtop.symtab = do_symtab(up)

    mtop.system_name = up.get_int32()

    do_ffparams(up, header)

    nmoltype = up.get_int32()
    for i in range(nmoltype):
        mtop.moltypes.push_back(do_moltype(up, header))

    nmolblock = up.get_int32()
    for i in range(nmolblock):
        mtop.molblocks.push_back(do_molblock(up, header))

    # this next number should be natoms, so do a quick sanity check
    natoms = up.get_int32()
    if not natoms == header.natoms:
        raise ValueError("Post molblock natoms sanity check failed,. something is awry")

    return mtop


cdef void skip_post_mtop_section(XDRThing& up,
                                 TpxHeader header):
    # skips through section after do_mtop and before coordinates
    if header.file_version >= 103:  # intermolecular bonds added
        has_intermolecular_bonds = up.get_bool()
        if has_intermolecular_bonds:
            # do another ilists, but discard the result
            do_ilists(up, header)

    if header.file_version < 128:  # remove atom types
        skip_atom_types(up, header)

    if header.file_version >= 65:  # pre96version65
        skip_cmaps(up)

    skip_groups(up)

    if header.file_version >= 120:  # store nonbonded interaction excl
        nexcl = up.get_int64()
        up.skip_int(nexcl)


def read_coordinates(bytes data):
    """Returns box, positions and velocities (if present) from TPR data"""
    cdef XDRThing up
    cdef TpxHeader header
    cdef int i

    up.set_stream(data)

    header = read_tpx_header(up)
    if header.bBox:
        box = extract_box_info(up, header)
    else:
        box = None

    skip_berendsen_section(up, header)

    if header.bTop:
        do_mtop(up, header)

    skip_post_mtop_section(up, header)

    if header.bX:
        positions = extract_positions(up, header)
    else:
        positions = None

    if header.bV:
        velocities = extract_positions(up, header)
    else:
        velocities = None

    return box, positions, velocities


cdef Box extract_box_info(XDRThing& up,
                           TpxHeader header):
    # follow code in do_tpx_state_first
    cdef Box b = Box()
    cdef int i

    for i in range(9):
        b.box[i] = up.get_real()

    if header.file_version >= 51:  # pre96version51
        for i in range(9):
            b.box_rel[i] = up.get_real()

    for i in range(9):
        b.box_v[i] = up.get_real()

    if header.file_version < 56:  # pre96version56
        up.skip_real(9)

    return b


cdef void skip_berendsen_section(XDRThing& up,
                                 TpxHeader header):
    for i in range(header.ngtc):
        if header.file_version < 69:
            up.skip_real(1)
        up.skip_real(1)  # relevant to Berendsen tcoupl_lambda


def parse(bytes data, skip_top=False):
    """Create a MDA Topology from tpr file"""
    cdef XDRThing up
    cdef TpxHeader header
    cdef MTop mtop
    cdef int i

    up.set_stream(data)

    header = read_tpx_header(up)

    if header.bBox:
        extract_box_info(up, header)

    skip_berendsen_section(up, header)

    if header.bTop:
        mtop = do_mtop(up, header)
    else:
        raise ValueError

    if skip_top:
        return mtop

    topology = mtop_to_topology(mtop)

    return topology


def is_allowed_version(int i):
    cdef int ret
    ret = SUPPORTED_VERSIONS.count(i)

    return ret


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)  # for division on bond number lengths
def mtop_to_topology(MTop mtop):
    cdef int i, j, k, l
    cdef int atomidx, molnum, atom_start_ndx, res_start_ndx
    cdef int nbonds = 0, nangles = 0, ndihedrals = 0, nimpropers = 0
    cdef int bondidx = 0, angleidx = 0, dihedralidx = 0, improperidx = 0
    cdef int ilist_counter, settle_base  # for unpacking ilists
    cdef int nmol, natoms, moltype_idx, resind
    cdef str molname
    cdef MolType *moltype
    cdef Atom *atom
    cdef Ilist *ilist
    cdef object bonds, angles, dihedrals, impropers
    cdef int[::1] bonds_view, angles_view, dihedrals_view, impropers_view

    # calculate the number of atoms we are expecting so we can allocate arrays
    natoms = 0
    # nbonds - not actually nbonds, but how many indices to hold to record bonds, i.e. nbonds * 2
    for i in range(mtop.molblocks.size()):
        nmol = mtop.molblocks[i].nmol
        moltype_idx = mtop.molblocks[i].type_
        natoms += mtop.moltypes[i].atoms.size() * nmol

        for j in range(mtop.moltypes[moltype_idx].ilists.size()):
            # for each interactionlist
            # accumulate how many values are beind held
            if interaction_roles[j] == BondedType.bonds:
                nbonds += nmol * mtop.moltypes[moltype_idx].ilists[j].nr / 3 * 2
            elif interaction_roles[j] == BondedType.settle:
                # new settle, 3 indices giving 2 settle records
                k = mtop.moltypes[moltype_idx].ilists[j].nr
                if k == 2:  # todo: not sure this is right, old settle style
                    nbonds += nmol * 2
                else:
                    # k/4 is how many entries there are, type,i,j,k
                    # ij and ik are the bonds

                    nbonds += nmol * k #  is actually nmol * k / 4 * 2 * 2
            elif interaction_roles[j] == BondedType.angles:
                nangles += nmol * mtop.moltypes[moltype_idx].ilists[j].nr / 4 * 3
            elif interaction_roles[j] == BondedType.dihedrals:
                ndihedrals += nmol * mtop.moltypes[moltype_idx].ilists[j].nr / 5 * 4
            elif interaction_roles[j] == BondedType.impropers:
                nimpropers += nmol * mtop.moltypes[moltype_idx].ilists[j].nr / 5 * 4

    bonds = np.empty(nbonds, dtype=np.int32)
    angles = np.empty(nangles, dtype=np.int32)
    dihedrals = np.empty(ndihedrals, dtype=np.int32)
    impropers = np.empty(nimpropers, dtype=np.int32)
    bonds_view = bonds
    angles_view = angles
    dihedrals_view = dihedrals
    impropers_view = impropers

    atomids = np.empty(natoms, dtype=np.int32)
    segids = np.empty(natoms, dtype=object)
    chainIDs = np.empty(natoms, dtype=object)
    resids = np.empty(natoms, dtype=np.int32)
    resnames = np.empty(natoms, dtype=object)
    atomnames = np.empty(natoms, dtype=object)
    atomtypes = np.empty(natoms, dtype=object)
    moltypes = np.empty(natoms, dtype=object)
    molnums = np.empty(natoms, dtype=np.int32)
    charges = np.empty(natoms, dtype=np.float32)
    masses = np.empty(natoms, dtype=np.float32)
    elements = np.empty(natoms, dtype=object)

    atomidx = 0
    molnum = 0
    atom_start_ndx = 0
    res_start_ndx = 0
    # loop over all molblocks in tpr
    for i in range(mtop.molblocks.size()):
        moltype_idx = mtop.molblocks[i].type_
        moltype = & mtop.moltypes[moltype_idx]
        # grab the name of this mol
        molname = mtop.symtab[moltype.name_idx].decode('utf-8')
        segid = f'seg_{i}_{molname}'
        chainID = molname[14:] if molname.startswith('Protein_chain_') else molname

        # loop over the repeats of this given moltype
        for j in range(mtop.molblocks[i].nmol):
            # loop over the atoms in this moltype
            for k in range(moltype.atoms.size()):
                atom = & moltype.atoms[k]
                atomids[atomidx] = atomidx  # todo: atomkind.id + atom_start_ndx
                segids[atomidx] = segid
                chainIDs[atomidx] = chainID
                resind = atom.resind
                resids[atomidx] = resind + res_start_ndx
                resnames[atomidx] = mtop.symtab[moltype.resname_indices[resind]].decode('utf-8')
                atomnames[atomidx] = mtop.symtab[moltype.atomnames[k]].decode('utf-8')
                atomtypes[atomidx] = mtop.symtab[moltype.types[k]].decode('utf-8')
                moltypes[atomidx] = molname
                molnums[atomidx] = molnum
                charges[atomidx] = atom.charge
                masses[atomidx] = atom.mass
                elements[atomidx] = atom.atomnumber

                atomidx += 1

            # process ilists to form bonds
            for k in range(moltype.ilists.size()):
                ilist = & moltype.ilists[k]
                ilist_counter = 0
                if interaction_roles[k] == BondedType.bonds:
                    # bonds come in 3s, type,i,j -> ij
                    # discard type index
                    for l in dereference(ilist).iatoms:
                        if ilist_counter == 0:
                            # type
                            ilist_counter += 1
                        elif ilist_counter == 1:
                            # i
                            bonds_view[bondidx] = l + atom_start_ndx
                            bondidx += 1
                            ilist_counter += 1
                        else:  # ilist_counter == 2
                            # j
                            bonds_view[bondidx] = l + atom_start_ndx
                            bondidx += 1
                            ilist_counter = 0
                elif interaction_roles[k] == BondedType.settle:
                    # settle comes in two variants
                    # other variant is type,i,j,k unpacking to ij and ik
                    if ilist.nr == 2:
                        # TODO: legacy settle doesn't seem right
                        raise NotImplementedError
                    else:
                        for l in dereference(ilist).iatoms:
                            if ilist_counter == 0:
                                ilist_counter += 1
                            elif ilist_counter == 1:
                                settle_base = l
                                ilist_counter += 1
                            elif ilist_counter == 2:
                                bonds_view[bondidx] = settle_base + atom_start_ndx
                                bonds_view[bondidx+1] = l + atom_start_ndx
                                bondidx += 2
                                ilist_counter += 1
                            else:  # ilist_counter == 3
                                bonds_view[bondidx] = settle_base + atom_start_ndx
                                bonds_view[bondidx+1] = l + atom_start_ndx
                                bondidx += 2
                                ilist_counter = 0
                elif interaction_roles[k] == BondedType.angles:
                    # angles come in 4s, type,i,j,k
                    for l in dereference(ilist).iatoms:
                        if ilist_counter == 0:
                            # type
                            ilist_counter += 1
                        elif ilist_counter == 1:  # i
                            angles_view[angleidx] = l + atom_start_ndx
                            angleidx += 1
                            ilist_counter += 1
                        elif ilist_counter == 2:  # j
                            angles_view[angleidx] = l + atom_start_ndx
                            angleidx += 1
                            ilist_counter += 1
                        else:  # ilist_counter == 3  # k
                            angles_view[angleidx] = l + atom_start_ndx
                            angleidx += 1
                            ilist_counter = 0
                elif interaction_roles[k] == BondedType.dihedrals:
                    # both dihedrals and impropers come in 5s
                    for l in dereference(ilist).iatoms:
                        if ilist_counter == 0:
                            # type
                            ilist_counter += 1
                        elif ilist_counter == 1:  # i
                            dihedrals_view[dihedralidx] = l + atom_start_ndx
                            dihedralidx += 1
                            ilist_counter += 1
                        elif ilist_counter == 2:  # j
                            dihedrals_view[dihedralidx] = l + atom_start_ndx
                            dihedralidx += 1
                            ilist_counter += 1
                        elif ilist_counter == 3:  # k
                            dihedrals_view[dihedralidx] = l + atom_start_ndx
                            dihedralidx += 1
                            ilist_counter += 1
                        else:  # ilist_counter == 4  # l
                            dihedrals_view[dihedralidx] = l + atom_start_ndx
                            dihedralidx += 1
                            ilist_counter = 0
                elif interaction_roles[k] == BondedType.impropers:
                    for l in dereference(ilist).iatoms:
                        if ilist_counter == 0:
                            # type
                            ilist_counter += 1
                        elif ilist_counter == 1:  # i
                            impropers_view[improperidx] = l + atom_start_ndx
                            improperidx += 1
                            ilist_counter += 1
                        elif ilist_counter == 2:  # j
                            impropers_view[improperidx] = l + atom_start_ndx
                            improperidx += 1
                            ilist_counter += 1
                        elif ilist_counter == 3:  # k
                            impropers_view[improperidx] = l + atom_start_ndx
                            improperidx += 1
                            ilist_counter += 1
                        else:  # ilist_counter == 4  # l
                            impropers_view[improperidx] = l + atom_start_ndx
                            improperidx += 1
                            ilist_counter = 0

            atom_start_ndx += moltype.atoms.size()
            res_start_ndx += moltype.resname_indices.size()
            molnum += 1

    atomids = Atomids(atomids)
    atomnames = Atomnames(atomnames)
    atomtypes = Atomtypes(atomtypes)
    charges = Charges(charges)
    masses = Masses(masses)

    # todo: if tpr_resid_from_one:
    # resids += 1

    # Bonds/Angles/Torsions
    connection_attrs = [
        Bonds([tuple(row) for row in bonds.reshape(-1, 2)]),
        Angles([tuple(row) for row in angles.reshape(-1, 3)]),
        Dihedrals([tuple(row) for row in dihedrals.reshape(-1, 4)]),  # todo: check ordering on dihedrals
        Impropers([tuple(row) for row in impropers.reshape(-1, 4)]),  # todo: check ordering on impropers
    ]

    (residx, new_resids,
     (new_resnames,
      new_moltypes,
      new_molnums,
      perres_segids
      )
     ) = squash_by(resids,
                   resnames,
                   moltypes,
                   molnums,
                   segids)
    residueids = Resids(new_resids)
    residuenames = Resnames(new_resnames)
    residue_moltypes = Moltypes(new_moltypes)
    residue_molnums = Molnums(new_molnums)

    segidx, perseg_segids = squash_by(perres_segids)[:2]
    segids = Segids(perseg_segids)
    chainIDs = ChainIDs(chainIDs)

    top = Topology(
        len(atomids),
        len(new_resids),
        len(perseg_segids),
        attrs=[
            atomids,
            atomnames,
            atomtypes,
            charges,
            # elements,  # TODO: Check this
            masses,
            residueids,
            residuenames,
            residue_moltypes,
            residue_molnums,
            segids,
            chainIDs,
        ] + connection_attrs,
        atom_resindex=residx,
        residue_segindex=segidx,
    )

    return top, bonds


@cython.wraparound(False)
@cython.boundscheck(False)
cdef object extract_positions(XDRThing& up,
                              TpxHeader header):
    # not sure on precision so just create both views and handle later
    cdef int i, natoms
    cdef float[::1] singleprec_view
    cdef double[::1] doubleprec_view

    natoms = header.natoms

    if header.precision == 4:
        array = np.empty(natoms * 3, dtype=np.float32)
        singleprec_view = array

        for i in range(natoms * 3):
            singleprec_view[i] = up.get_float()
    else:
        array = np.empty(natoms * 3, dtype=np.float64)
        doubleprec_view = array

        for i in range(natoms * 3):
            doubleprec_view[i] = up.get_double()

    return array.reshape(-1, 3)
