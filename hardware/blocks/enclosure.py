"""A sleeve behind the faceplate that holds a device."""

from build123d import Align, Box, Pos

from .feature import Feature

FROM_FRONT = (Align.CENTER, Align.CENTER, Align.MIN)  # centred on x/y, starting at z


def enclosure(width, height, depth, x=0.0, y=0.0, wall=3.0, back_lip=3.0) -> Feature:
    """Walls around a device of `width` x `height`, `depth` deep from the panel's front face.

    X and Y place the opening on the faceplate, measured from its center.

    A `back_lip` wide rim around the back opening can be used to stop the device from
    sliding through, setting it to zero leaves the back open and a half of devicce height
    closes it.
    """
    walls = Pos(x, y, 0) * Box(
        width + 2 * wall, height + 2 * wall, depth + wall, align=FROM_FRONT
    )
    cut = Pos(x, y, -1) * Box(
        width, height, depth + 1, align=FROM_FRONT
    )  # from 1 mm in front of the panel
    if min(width, height) > 2 * back_lip:
        cut += Pos(x, y, depth - 1) * Box(
            width - 2 * back_lip, height - 2 * back_lip, wall + 2, align=FROM_FRONT
        )
    return Feature(add=walls, cut=cut)


# demo preview for `fab edit` or `fab preview`
if __name__ == "__fab__":
    from racks.deskpi import RACKMATE_T2 as RACK

    from .faceplate import faceplate
    from .feature import compose

    WIDTH = 120.0
    HEIGHT = 25.0
    DEPTH = 60.0
    X = 0.0
    Y = 0.0
    demo = compose(faceplate(RACK, 1), enclosure(WIDTH, HEIGHT, DEPTH, x=X, y=Y))
