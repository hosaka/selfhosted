"""Blank 10" rack panel. A faceplate with mounting holes."""

from blocks.panel import Panel
from racks.deskpi import RACKMATE_T2 as RACK

RACK_UNITS = 1
THICKNESS = 4.0

panel = Panel(f"Blank {RACK_UNITS}U", RACK, units=RACK_UNITS, thickness=THICKNESS)
