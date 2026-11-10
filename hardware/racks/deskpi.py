"""DeskPi racks."""

from blocks.rack import SCREW_10_32_X_5_16, Rack

RACKMATE_T2 = (
    Rack(  # DP-0048: 10", 12U, 281 x 260 mm outside, threaded rail holes for #10-32
        name="RackMate T2",
        screw=SCREW_10_32_X_5_16,
        opening=222.0,  # between the front posts
        depth=None,  # todo: front face of a front rail to back face of the rear rail
    )
)
