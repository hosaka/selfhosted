"""Power supply form factors."""

from blocks.device import Device

FLEXATX = Device(
    name="FlexATX PSU",
    width=81.5,
    height=40.5,
    depth=150.0,  # the common length, some models are 100 or 125 mm
)
