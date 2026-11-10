"""Edit the part parameters in an interactable view next to a live f3d viewport.

Saving the part from the view writes the parameters back into the file.
Editing a part, or a block it imports, will rebuild and swap it in, keeping the camera.
"""


def run(args):
    print("Editing...")
