import argparse
import importlib
import signal
import sys
from pathlib import Path


def main(argv=None):
    signal.signal(signal.SIGINT, signal.SIG_DFL)

    parser = argparse.ArgumentParser(
        prog="fab", description="Work with parametric rack parts."
    )
    sub = parser.add_subparsers(dest="command", required=True, metavar="command")

    sub.add_parser("preview", help="preview a part, rebuilds each time it is saved")

    sub.add_parser("edit", help="tune the part parameters next to a live viewport")

    cmd = sub.add_parser("render", help="render the part to an image next to its file")
    cmd.add_argument("--png", action="store_true", help="write <part>.png (default)")

    cmd = sub.add_parser(
        "export", help="write the part next to its file as STL and/or STEP"
    )
    cmd.add_argument("--stl", action="store_true", help="write <part>.stl (default)")
    cmd.add_argument("--step", action="store_true", help="write <part>.step")

    # all subcommands take a part file
    for cmd in sub.choices.values():
        cmd.add_argument("part", type=Path, help="Part file (.py)")
    args = parser.parse_args(argv)

    if not args.part.is_file():
        sub.choices[args.command].error(f"no such file: {args.part}")

    from .part import BuildError

    try:
        importlib.import_module(f"fab.{args.command}").run(args)
    except BuildError as err:
        sys.exit(f"{err}\nfab: {args.part.name} failed to build")
