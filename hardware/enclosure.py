"""Enclosure with faceplate, mounting holes and a sleeve a device slides into."""

from blocks.enclosure import enclosure
from blocks.panel import Panel
from racks.deskpi import RACKMATE_T2 as RACK

RACK_UNITS = 1
THICKNESS = 4.0

WIDTH = 176.4  # the device, inside the sleeve
HEIGHT = 24.5
DEPTH = 66.0  # from the panel's front face to the back lip
X = 0.0  # opening centre, from the panel centre
Y = 0.0
WALL = 3.0
BACK_LIP = 3.0  # lip at the back, 0 leaves the back open

panel = Panel(
    f"Enclosure {RACK_UNITS}U",
    RACK,
    units=RACK_UNITS,
    thickness=THICKNESS,
    features=[enclosure(WIDTH, HEIGHT, DEPTH, x=X, y=Y, wall=WALL, back_lip=BACK_LIP)],
)
