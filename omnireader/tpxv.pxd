
cdef enum interaction_functions:
    F_BONDS,
    F_G96BONDS,
    F_MORSE,
    F_CUBICBONDS,
    F_CONNBONDS,
    F_HARMONIC,
    F_FENEBONDS,
    F_TABBONDS,
    F_TABBONDSNC,
    F_RESTRBONDS,
    F_ANGLES,
    F_G96ANGLES,
    F_RESTRANGLES,
    F_LINEAR_ANGLES,
    F_CROSS_BOND_BONDS,
    F_CROSS_BOND_ANGLES,
    F_UREY_BRADLEY,
    F_QUARTIC_ANGLES,
    F_TABANGLES,
    F_PDIHS,
    F_RBDIHS,
    F_RESTRDIHS,
    F_CBTDIHS,
    F_FOURDIHS,
    F_IDIHS,
    F_PIDIHS,
    F_TABDIHS,
    F_CMAP,
    F_GB12,
    F_GB13,
    F_GB14,
    F_GBPOL,
    F_NPSOLVATION,
    F_LJ14,
    F_COUL14,
    F_LJC14_Q,
    F_LJC_PAIRS_NB,
    F_LJ,
    F_BHAM,
    F_LJ_LR,
    F_BHAM_LR,
    F_DISPCORR,
    F_COUL_SR,
    F_COUL_LR,
    F_RF_EXCL,
    F_COUL_RECIP,
    F_LJ_RECIP,
    F_DPD,
    F_POLARIZATION,
    F_WATER_POL,
    F_THOLE_POL,
    F_ANHARM_POL,
    F_POSRES,
    F_FBPOSRES,
    F_DISRES,
    F_DISRESVIOL,
    F_ORIRES,
    F_ORIRESDEV,
    F_ANGRES,
    F_ANGRESZ,
    F_DIHRES,
    F_DIHRESVIOL,
    F_CONSTR,
    F_CONSTRNC,
    F_SETTLE,
    F_VSITE1,
    F_VSITE2,
    F_VSITE2FD,
    F_VSITE3,
    F_VSITE3FD,
    F_VSITE3FAD,
    F_VSITE3OUT,
    F_VSITE4FD,
    F_VSITE4FDN,
    F_VSITEN,
    F_COM_PULL,
    F_DENSITYFITTING,
    F_EQM,
    F_EPOT,
    F_EKIN,
    F_ETOT,
    F_ECONSERVED,
    F_TEMP,
    F_VTEMP_NOLONGERUSED,
    F_PDISPCORR,
    F_PRES,
    F_DHDL_CON,
    F_DVDL,
    F_DKDL,
    F_DVDL_COUL,
    F_DVDL_VDW,
    F_DVDL_BONDED,
    F_DVDL_RESTRAINT,
    F_DVDL_TEMPERATURE,
    F_NRE


cdef enum tpxv:
    tpxv_Pre96Version51 = 51,
    tpxv_Pre96Version53 = 53,
    tpxv_Pre96Version56 = 56,
    tpxv_Pre96Version57,
    tpxv_Pre96Version58,
    tpxv_Pre96Version59,
    tpxv_Pre96Version60,
    tpxv_Pre96Version61,
    tpxv_Pre96Version62,
    tpxv_Pre96Version63,
    tpxv_Pre96Version64,
    tpxv_Pre96Version65,
    tpxv_Pre96Version66,
    tpxv_Pre96Version67,
    tpxv_Pre96Version68,
    tpxv_Pre96Version69,
    tpxv_Pre96Version70,
    tpxv_Pre96Version71,
    tpxv_Pre96Version72,
    tpxv_Pre96Version73,
    tpxv_Pre96Version74,
    tpxv_Pre96Version76 = 76,
    tpxv_Pre96Version77,
    tpxv_Pre96Version78,
    tpxv_Pre96Version79,
    tpxv_Pre96Version80,
    tpxv_Pre96Version81,
    tpxv_Pre96Version82,
    tpxv_Pre96Version83,
    tpxv_Pre96Version90 = 90,
    tpxv_Pre96Version92 = 92,
    tpxv_Pre96Version93,
    tpxv_Pre96Version94,
    tpxv_Pre96Version95,
    tpxv_ComputationalElectrophysiology = 96, # < support for ion/water position swaps (computational electrophysiology) */
    tpxv_Use64BitRandomSeed, # < change ld_seed from int to int64_t */
    tpxv_RestrictedBendingAndCombinedAngleTorsionPotentials, # < potentials for supporting coarse-grained force fields */
    tpxv_InteractiveMolecularDynamics, # < interactive molecular dynamics (IMD) */
    tpxv_RemoveObsoleteParameters1,    # < remove optimize_fft, dihre_fc, nstcheckpoint */
    tpxv_PullCoordTypeGeom,            # < add pull type and geometry per group and flat-bottom */
    tpxv_PullGeomDirRel,               # < add pull geometry direction-relative */
    tpxv_IntermolecularBondeds, # < permit inter-molecular bonded interactions in the topology */
    tpxv_CompElWithSwapLayerOffset, # < added parameters for improved CompEl setups */
    tpxv_CompElPolyatomicIonsAndMultipleIonTypes, # < CompEl now can handle polyatomic ions and more than two types of ions */
    tpxv_RemoveAdress,                            # < removed support for AdResS */
    tpxv_PullCoordNGroup,               # < add ngroup to pull coord */
    tpxv_RemoveTwinRange,               # < removed support for twin-range interactions */
    tpxv_ReplacePullPrintCOM12,         # < Replaced print-com-1, 2 with pull-print-com */
    tpxv_PullExternalPotential,         # < Added pull type external potential */
    tpxv_GenericParamsForElectricField, # < Introduced KeyValueTree and moved electric field parameters */
    tpxv_AcceleratedWeightHistogram, # < sampling with accelerated weight histogram method (AWH) */
    tpxv_RemoveImplicitSolvation,    # < removed support for implicit solvation */
    tpxv_PullPrevStepCOMAsReference, # < Enabled using the COM of the pull group of the last frame as reference for PBC */
    tpxv_MimicQMMM,   # < Introduced support for MiMiC QM/MM interface */
    tpxv_PullAverage, # < Added possibility to output average pull force and position */
    tpxv_GenericInternalParameters, # < Added internal parameters for mdrun modules*/
    tpxv_VSite2FD,                  # < Added 2FD type virtual site */
    tpxv_AddSizeField, # < Added field with information about the size of the serialized tpr file in bytes, excluding the header */
    tpxv_StoreNonBondedInteractionExclusionGroup, # < Store the non bonded interaction exclusion group in the topology */
    tpxv_VSite1,                                  # < Added 1 type virtual site */
    tpxv_MTS,                                     # < Added multiple time stepping */
    tpxv_RemovedConstantAcceleration, # < Removed support for constant acceleration NEMD. */
    tpxv_TransformationPullCoord,     # < Support for transformation pull coordinates */
    tpxv_SoftcoreGapsys,              # < Added gapsys softcore function */
    tpxv_ReaddedConstantAcceleration, # < Re-added support for constant acceleration NEMD. */
    tpxv_RemoveTholeRfac,             # < Remove unused rfac parameter from thole listed force */
    tpxv_RemoveAtomtypes,             # < Remove unused atomtypes parameter from mtop */
    tpxv_EnsembleTemperature,         # < Add ensemble temperature settings */
    tpxv_AwhGrowthFactor,             # < Add AWH growth factor */
    tpxv_MassRepartitioning,          # < Add mass repartitioning */
    tpxv_AwhTargetMetricScaling,      # < Add AWH friction optimized target distribution */
    tpxv_VerletBufferPressureTol,     # < Add Verlet buffer pressure tolerance */
    tpxv_Count                        # < the total number of tpxv versions */
