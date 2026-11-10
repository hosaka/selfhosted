# Cluster Hardware

This directory contains sources for cluster rack hardware that can be 3D printed or sent off to a manufacturer for fabrication. This includes parametric rack mounted enclosures, PCBs with BOMs and schematics and documentation that goes along with them.

As I do not own a 3D printer (yet), and my tools barely go beyond a good soldering station and a hot air gun, I tend to use the following services for manufacturing:

- [JLCPCB](https://jlcpcb.com)
- [Craftcloud](https://craftcloud3d.com/)

## Parametric Rack

While scouting for good rack mounted panels and enclosures made by a fantastic community of homelabbers I started making my own 3D printables using an excellent [build123d](https://github.com/gumyr/build123d) CAD programming library.

Runtime dependencies:
- `libglvnd` (libGL, libGLX, libEGL, libOpenGL)
- OpenGL driver (`mesa` or the NVIDIA driver)
- `libX11` plus `Xwayland` if running on Wayland
