"""Shared rack measurements (EIA-310 heights) and the interface a rack model fullfills."""

from dataclasses import dataclass

from build123d import Align, Box, Part, Pos

U = 44.45  # rack unit, 1.75"
U_CLEARANCE = 0.79  # a panel is 1/32", shorter than its U span
HOLE_HEIGHTS = (6.35, 38.1)  # from the bottom (the the middle one is 22.225)
PANEL_THICKNESS = 4.0  # our default faceplate, not a standard per se


@dataclass(frozen=True)
class Screw:
    """Screws that hold panels to a rack's rails."""

    diameter: float  # major diameter
    length: float  # under the head
    pitch: float  # thread pitch
    min_threads: int = 3  # threads that must reach into the rail


SCREW_10_32_X_5_16 = Screw(
    diameter=4.83, length=7.94, pitch=25.4 / 32
)  # #10-32 x 5/16"


@dataclass(frozen=True)
class Rack:
    """A rack model. The defaults are a 10" rack.
    A 19" rack can override panel_width (482.6), hole_pitch (465.1) and opening (450).
    """

    name: str
    screw: Screw
    panel_width: float = 254.0  # for a 10" panel
    hole_pitch: float = 236.525  # center to center of the left and right rail holes
    opening: float = 222.25  # clear width between the rails, so behind the faceplate
    depth: float | None = (
        None  # front face of the front rails to back face of the rear rails or None if unknown
    )


def panel_height(units: int):
    return units * U - U_CLEARANCE


def hole_ys(units: int):
    """Rail hole heights, from the panel's vertical center."""
    return [u * U + h - units * U / 2 for u in range(units) for h in HOLE_HEIGHTS]


def check_fit(part: Part, rack: Rack, units: int, thickness=PANEL_THICKNESS):
    """Assert that everything behind the faceplate fits between the rack's rails and within its U span."""
    behind = part & Pos(0, 0, thickness + 0.01) * Box(
        1000, 1000, 1000, align=(Align.CENTER, Align.CENTER, Align.MIN)
    )
    if not behind.volume:
        return
    bb = behind.bounding_box()
    x, y = max(-bb.min.X, bb.max.X), max(-bb.min.Y, bb.max.Y)
    assert x <= rack.opening / 2, (
        f"behind the faceplate reaches {x:.1f} mm from the center, the {rack.name} rails leave {rack.opening / 2:.1f}"
    )
    assert y <= panel_height(units) / 2, (
        f"behind the faceplate reaches {y:.1f} mm up/down from the center, {units}U leaves {panel_height(units) / 2:.2f}"
    )
