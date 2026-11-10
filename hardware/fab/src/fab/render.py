"""Draw the part from f3d isometric view into image files."""

from pathlib import Path

import f3d

from .part import build, to_mesh

SIZE = (1920, 1080)
FORMATS = {"png": f3d.Image.SaveFormat.PNG, "jpg": f3d.Image.SaveFormat.JPG}


def run(args):
    path: Path = args.part.resolve()
    mesh = to_mesh(build(path))

    engine = f3d.Engine.create(True)  # run offscreen
    engine.window.size = SIZE
    engine.options.update({"render.effect.antialiasing.mode": "ssaa"})
    engine.scene.add(mesh)
    engine.interactor.trigger_command("set_camera isometric")

    image = engine.window.render_to_image()

    for ext in [e for e in FORMATS if getattr(args, e)] or ["png"]:
        out = path.with_suffix(f".{ext}")
        image.save(str(out), FORMATS[ext])
        print(out)
