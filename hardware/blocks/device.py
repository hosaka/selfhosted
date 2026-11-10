"""The dimentions of something a print holds, as devices/ and components/ describe them."""

from dataclasses import dataclass


@dataclass(frozen=True)
class Device:
    """A device size in mm, in the print frame.

    Spec sheets often say W x D x H, so mind the order. Clearances should be handled in the print.
    """

    name: str
    width: float  # across the rack
    height: float  # up the rack
    depth: float  # into the rack
