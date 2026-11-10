"""Export the part into a printable file format (STL, STEP etc.)"""

from pathlib import Path

from build123d import export_step, export_stl

from .part import build

WRITERS = {"stl": export_stl, "step": export_step}


def run(args):
    path: Path = args.part.resolve()
    part = build(path)
    for ext in [e for e in WRITERS if getattr(args, e)] or ["stl"]:
        out = path.with_suffix(f".{ext}")
        if not WRITERS[ext](part, str(out)):
            raise SystemExit(f"fab: could not write {out}")
        print(out)
