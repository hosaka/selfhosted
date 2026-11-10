"""Reusable pieces of 10" rack prints.

Every block works in the same frame and print orientation. The panel's front face is
Z = 0 plane (face down on the bed), X runs across the rack, Y runs up the rack, both
centered on the faceplate and the depth goes towards +Z.

Blocks return a Feature, solids to add, voids to cut. A print lists the features it needs
and `compose()` turns them into one part. Rack specific constants come from a `Rack` passed
in, defined in `racks/`. Prints only pass what they want to change.
"""
