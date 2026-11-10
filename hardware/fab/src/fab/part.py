"""Runs a part file and hands it off to f3d for rendering."""

import sys
import traceback
import types
from pathlib import Path

import f3d
from build123d import Part

f3d.Log.set_verbose_level(f3d.Log.VerboseLevel.WARN)

# How the interactive viewports look when rendering a part.
VIEW_OPTIONS = {
    "render.grid.enable": True,
    "ui.axis": True,
    "render.effect.antialiasing.mode": "fxaa",
}

FAB = Path(__file__).parent
_modules: dict[str, Path] = {}  # local modules the part files imported (e.g. blocks.*)
_watch: set[Path] = set()  # local files that went into a build, or into its error


class BuildError(Exception):
    """The part file failed."""


def _local(file: str, root: Path) -> bool:
    """A file is next to or under the part file and not the venv of fab own file."""
    f = Path(file)
    return (
        f.is_relative_to(root)
        and not f.is_relative_to(sys.prefix)
        and not f.is_relative_to(FAB)
    )


def _package(path: Path) -> tuple[str | None, Path]:
    names, directory = [], path.parent
    while (directory / "__init__.py").is_file():
        names.insert(0, directory.name)
        directory = directory.parent
    return ".".join(names) or None, directory


def build(path: Path, src: str | None = None) -> Part:
    """Run the part file or `src` in its place and return the last Part it made.

    The file runs with `__name__ == "__fab__".
    """
    path = Path(path).resolve()
    package, root = _package(path)
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))  # imports work like `python part.py`
    for name in _modules:
        sys.modules.pop(name, None)

    before = set(sys.modules)
    ns: dict[str, object] = {
        "__name__": "__fab__",
        "__file__": str(path),
        "__package__": package,
    }

    try:
        exec(compile(path.read_text() if src is None else src, str(path), "exec"), ns)
    except Exception as err:
        tb = traceback.TracebackException.from_exception(err)
        tb.stack = traceback.StackSummary.from_list(
            [f for f in tb.stack if _local(f.filename, root)]
        )

        # watch the files in the error too: a module that failed to import is not in sys.modules
        _watch.update(
            Path(f)
            for f in [*(f.filename for f in tb.stack), getattr(err, "filename", None)]
            if f and _local(f, root) and Path(f).is_file()
        )
        raise BuildError("".join(tb.format()).rstrip()) from None
    finally:
        for name in set(sys.modules) - before:
            file = getattr(sys.modules[name], "__file__", None)
            if file and _local(file, root):
                _modules[name] = Path(file)
                _watch.add(Path(file))

    # a `Part`, or anything holding one in .part, or a print object
    found = (
        v if isinstance(v, Part) else getattr(v, "part", None)
        for v in ns.values()
        if not isinstance(v, (type, types.ModuleType))
    )
    parts = [p for p in found if isinstance(p, Part)]
    if not parts:
        raise BuildError(
            f"{path.name} made no Part (or object with a .part, like a BuildPart)"
        )
    return parts[-1]


def title(part: Part, path: Path) -> str:
    """How fab refers to what is being shown."""
    return f"{part.label} ({path.name})" if part.label else path.name


def stamps(path: Path) -> dict[Path, int | None]:
    """Modification times of the part file and the local files its build used, to spot edits."""
    path = Path(path).resolve()
    return {f: f.stat().st_mtime_ns if f.exists() else None for f in (path, *_watch)}


def to_mesh(part: Part) -> f3d.Mesh:
    """Tessellate a build123d shape into an in-memory f3d mesh."""
    verts, tris = part.tessellate(0.02, 0.1)
    mesh = f3d.Mesh()
    mesh.points = [c for v in verts for c in (v.X, v.Y, v.Z)]
    mesh.face_sides = [3] * len(tris)
    mesh.face_indices = [i for t in tris for i in t]
    return mesh


def show(engine: f3d.Engine, mesh: f3d.Mesh, keep_camera: bool, name: str):
    """Replace the model in an f3d engine and its caption."""
    # adding a model refits the camera, preserve it here and restore if requested
    camera = engine.window.camera
    state = camera.state

    engine.scene.clear()
    engine.scene.add(mesh)
    engine.options.update({"ui.filename": True, "ui.filename_info": name})

    if keep_camera:
        camera.state = state
