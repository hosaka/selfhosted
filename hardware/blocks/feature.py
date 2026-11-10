"""Features and how a print puts them together."""

from dataclasses import dataclass

from build123d import Part, Sketch


@dataclass
class Feature:
    """A piece of a print. Solids to add and voids to cut, if any."""

    add: Sketch | Part | None = None
    cut: Sketch | Part | None = None


def compose(*features):
    """Add every feature's solids, then cut every feature's voids.

    All cuts come after all addds, so a voidd always stays a void, whatever the order of
    the features is. A feature that needs something inside its own void (e.g. standoffs)
    leaves that out of the cut itself.
    """
    adds = [f.add for f in features if f.add is not None]
    cuts = [f.cut for f in features if f.cut is not None]
    part = adds[0]
    for add in adds[1:]:
        part += add
    for cut in cuts:
        part -= cut
    return part
