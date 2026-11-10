"""Drive form factors, lying flat with the connectors at the back."""

from blocks.device import Device

HDD_3_5 = Device(
    name='3.5" HDD',
    width=101.6,  # SFF-8301
    height=26.1,  # 1" drives
    depth=147.0,
)

SSD_2_5 = Device(
    name='2.5" SSD',
    width=69.85,  # SFF-8201
    height=7.0,  # most SSDs, 2.5" HDDs and some SSDs are 9.5
    depth=100.45,
)
