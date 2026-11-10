"""The front plate of a rack print, without any mounting holes."""

from build123d import Axis, RectangleRounded, chamfer, extrude

from .feature import Feature
from .rack import PANEL_THICKNESS, Rack, panel_height


def faceplate(
    rack: Rack,
    units: int = 1,
    thickness: float = PANEL_THICKNESS,
    corner_radius: float = 3.0,
    front_chamfer: float = 0.5,
):
    """A rounded plate as wide as `rack` panels and `units` U tall, front face at Z = 0.

    Chamfer instead of fillet, because this edge sits on the print bed.
    """
    plate = extrude(
        RectangleRounded(rack.panel_width, panel_height(units), corner_radius),
        thickness,
    )
    if front_chamfer:
        plate = chamfer(plate.edges().group_by(Axis.Z)[0], front_chamfer)
    return Feature(add=plate)


# demo preview for `fab edit` or `fab preview`
if __name__ == "__fab__":
    from racks.deskpi import RACKMATE_T2 as RACK

    UNITS = 1
    demo = faceplate(RACK, UNITS).add
