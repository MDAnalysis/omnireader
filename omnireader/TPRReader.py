from omnireader.xdrfile import read_coordinates

from MDAnalysis.coordinates.base import SingleFrameReaderBase
import numpy as np


class TPRReader(SingleFrameReaderBase):
    format = 'TPR'
    units = {'time': None, 'length': 'Angstrom'}

    def _read_first_frame(self):
        with open(self.filename, 'rb') as f:
            data = f.read()

        box, positions, velocities = read_coordinates(data)
        if box is not None:
            arr = np.empty(9, dtype=np.float32)
            arr[:] = box['box']
            box = arr.reshape(-1, 3)

        if positions is not None:
            self.n_atoms = positions.shape[0]
        else:
            raise ValueError("Missing positions in file")

        self.ts = self._Timestep.from_coordinates(positions=positions,
                                                  velocities=velocities,
                                                  **self._ts_kwargs)
        self.ts.frame = 0
        self.ts.triclinic_dimensions = box
