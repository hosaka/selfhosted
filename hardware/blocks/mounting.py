"""Mounting holes for the rack screws."""

from build123d import Pos, Sketch, SlotOverall, extrude

from .feature import Feature
from .rack import PANEL_THICKNESS, Rack, hole_ys


def mounting(
    rack: Rack,
    units: int = 1,
    thickness: float = PANEL_THICKNESS,
    slot_length: float = 10.7,
    slot_width: float = 6.7,
    washer: float = 0.0,
):
    """Sideways slots at `racks` rail holes in every U, through a `thickness` faceplate.

    The slots run sideways so the panel can shift to meet the railse. A `washer` is the
    thickness of an washer under the screw head, it is optional.
    """
    screw = rack.screw
    reach = (
        screw.length - washer - thickness
    )  # screw left past the faceplate, for the rail

    assert slot_width > screw.diameter, (
        f"{slot_width} mm slots are narrower than the {rack.name} screws"
    )
    assert reach >= screw.min_threads * screw.pitch, (
        f"a {thickness} mm faceplate leave {reach:.2f} mm of the {rack.name} screws for the rail, "
        f"need {screw.min_threads * screw.pitch:.2f} mm ({screw.min_threads} threads)"
    )

    slots = Sketch(
        Pos(x, y) * SlotOverall(slot_length, slot_width)
        for x in (-rack.hole_pitch / 2, rack.hole_pitch / 2)
        for y in hole_ys(units)
    )

    # 1 mm past both faces, so the cut never shares a face with the plate
    return Feature(cut=Pos(0, 0, -1) * extrude(slots, thickness + 2))


# demo preview for `fab edit` or `fab preview`
if __name__ == "__fab__":
    from racks.deskpi import RACKMATE_T2 as RACK

    from .faceplate import faceplate
    from .feature import compose

    UNITS = 2
    demo = compose(faceplate(RACK, UNITS), mounting(RACK, UNITS))
