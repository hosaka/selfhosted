"""A Panel, takes up a U of space at the front or at the back of a rack.

An accessory is everything else that can be mounted somehow (i.e. supports, cable comb).
"""

from dataclasses import dataclass, field

from build123d import Part

from .faceplate import faceplate
from .feature import Feature, compose
from .mounting import mounting
from .rack import PANEL_THICKNESS, Rack, check_fit


@dataclass
class Print:
    """Anything printed for a rack. It builds when made, so a print file errors point
    at the line that produced them.
    """

    name: str
    rack: Rack
    part: Part = field(init=False, repr=False)

    def __post_init__(self):
        self.part = self.build()
        self.part.label = self.name  # fab's title, also the name in an export file

    def build(self) -> Part:
        raise NotImplementedError


@dataclass
class Panel(Print):
    """Fills `units` of U at the front or the back of a rack. A faceplate with mounting
    holes, plus the print own features (enclosure, cut-outs, etc.), checked to fit the
    rack when built.
    """

    units: int = 1
    thickness: float = PANEL_THICKNESS
    features: list[Feature] = field(default_factory=list)

    def build(self):
        part = compose(
            faceplate(self.rack, self.units, self.thickness),
            mounting(self.rack, self.units, self.thickness),
            *self.features,
        )
        check_fit(part, self.rack, self.units, self.thickness)
        return part


@dataclass
class Accessory(Print):
    """Anything else for the rack, made of its features."""

    features: list[Feature] = field(default_factory=list)

    def build(self):
        return compose(*self.features)
