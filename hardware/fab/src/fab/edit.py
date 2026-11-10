"""Edit the part parameters in an interactable view next to a live f3d viewport.

Saving the part from the view writes the parameters back into the file.
Editing a part, or a block it imports, will rebuild and swap it in, keeping the camera.
"""

import ast
import signal
import time
from pathlib import Path

import f3d
from imgui_bundle import hello_imgui, imgui, immapp
from OpenGL import GL

from fab.part import VIEW_OPTIONS, BuildError, build, show, stamps, title, to_mesh

Act, Btn, Mod, Wheel = (
    f3d.Interactor.InputAction,
    f3d.Interactor.MouseButton,
    f3d.Interactor.InputModifier,
    f3d.Interactor.WheelDirection,
)

# (ctrl, shift) held -> f3d modifier
MODS = {
    (False, False): Mod.NONE,
    (True, False): Mod.CTRL,
    (False, True): Mod.SHIFT,
    (True, True): Mod.CTRL_SHIFT,
}

WINDOW_SIZE = (1400, 800)

# imgui key -> f3d key name, for f3d hotkeys (press F1 in the viewport for the list)
KEYS = {getattr(imgui.Key, c.lower()): c for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"}
KEYS |= {getattr(imgui.Key, f"_{d}"): d for d in "0123456789"}
KEYS |= {imgui.Key.enter: "Return", imgui.Key.space: "Space", imgui.Key.f1: "F1"}


def read_params(src):
    body = []
    for n in ast.parse(src).body:
        body.append(n)
        if isinstance(n, ast.If) and ast.unparse(n.test) == "__name__ == '__fab__'":
            body += n.body
    return {
        n.targets[0].id: n.value
        for n in body if isinstance(n, ast.Assign)
            and len(n.targets) == 1
            and isinstance(n.targets[0], ast.Name)
            and n.targets[0].id.isupper()
            and isinstance(n.value, ast.Constant)
            and type(n.value.value) in (int, float)
    }  # fmt: skip


def with_values(src, nodes, values):
    """`src` with each parameter's literal is replaced by its value.
    ast offsets are UTF-8 bytes
    """
    lines = src.splitlines(keepends=True)
    for name, n in sorted(
        nodes.items(), key=lambda kv: (kv[1].lineno, kv[1].col_offset), reverse=True
    ):
        b = lines[n.lineno - 1].encode()
        lines[n.lineno - 1] = (
            b[: n.col_offset] + repr(values[name]).encode() + b[n.end_col_offset :]
        ).decode()
    return "".join(lines)


class Viewport:
    """f3d drawing into a texture in ImGui owned GL context."""

    def __init__(self):
        # imported here, not at the top because imgui_bundle must be imported first, so glfw
        # loads imgui_bundle's own libglfw, the one that made the current GL context
        import glfw

        # f3d draws in that context, finding GL functions through GLFW (EGL or GLX alike)
        self.engine = f3d.Engine.create_external(
            lambda name: glfw.get_proc_address(name.decode())
        )
        self.engine.options.update(VIEW_OPTIONS)
        self.fbo, self.tex, self.depth = (
            GL.glGenFramebuffers(1),
            GL.glGenTextures(1),
            GL.glGenRenderbuffers(1),
        )
        self.size = None
        self.mesh = None  # next model to show
        self.has_model = False

    def show(self, mesh, name):
        # swapped in by draw(), where f3d can render into our texture
        self.mesh = (mesh, name)

    def draw(self, width, height, origin, scale, hovered):
        """Swap in a new model, pass on input and render into our texture.

        f3d renders during each of these, so our framebuffer stays bound throughout,
        otherwise f3d draws into the window behind ImGui (a ghost image).
        """
        GL.glBindFramebuffer(GL.GL_FRAMEBUFFER, self.fbo)
        if self.size != (width, height):
            self.resize(width, height)
        GL.glViewport(0, 0, width, height)

        if self.mesh is not None:
            mesh, name = self.mesh
            show(self.engine, mesh, keep_camera=self.has_model, name=name)
            self.mesh, self.has_model = None, True

        self.forward_input(origin, scale, hovered)

        self.engine.window.render()
        GL.glBindFramebuffer(GL.GL_FRAMEBUFFER, 0)

    def forward_input(self, origin, scale, hovered):
        """Pass ImGui's mouse and keys on to f3d.

        Positions are in framebuffer pixels from the viewport's top left. Presses
        only count over the viewport, mouse releases anywhere, so a drag can end
        outside it.
        """
        io, it = imgui.get_io(), self.engine.interactor
        it.trigger_mod_update(MODS[io.key_ctrl, io.key_shift])
        it.trigger_mouse_position(
            (io.mouse_pos.x - origin.x) * scale.x, (io.mouse_pos.y - origin.y) * scale.y
        )

        for i, button in enumerate((Btn.LEFT, Btn.RIGHT, Btn.MIDDLE)):
            if hovered and imgui.is_mouse_clicked(i):
                it.trigger_mouse_button(Act.PRESS, button)
            if imgui.is_mouse_released(i):
                it.trigger_mouse_button(Act.RELEASE, button)

        if hovered and io.mouse_wheel:
            it.trigger_mouse_wheel(
                Wheel.FORWARD if io.mouse_wheel > 0 else Wheel.BACKWARD
            )

        # f3d hotkeys, unless a text field has the keyboard
        if hovered and not io.want_text_input:
            for key, name in KEYS.items():
                if imgui.is_key_pressed(key, repeat=False):
                    it.trigger_keyboard_key(Act.PRESS, name)
                if imgui.is_key_released(key):
                    it.trigger_keyboard_key(Act.RELEASE, name)

    def resize(self, width, height):
        """(Re)allocate the texture f3d draws into and its depth buffer, on the bound framebuffer."""
        self.size = (width, height)

        GL.glBindTexture(GL.GL_TEXTURE_2D, self.tex)
        GL.glTexImage2D(
            GL.GL_TEXTURE_2D, 0, GL.GL_RGBA8, width, height, 0,
            GL.GL_RGBA, GL.GL_UNSIGNED_BYTE, None,
        )  # fmt: skip
        GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_LINEAR)
        GL.glFramebufferTexture2D(
            GL.GL_FRAMEBUFFER, GL.GL_COLOR_ATTACHMENT0, GL.GL_TEXTURE_2D, self.tex, 0
        )

        GL.glBindRenderbuffer(GL.GL_RENDERBUFFER, self.depth)
        GL.glRenderbufferStorage(
            GL.GL_RENDERBUFFER, GL.GL_DEPTH24_STENCIL8, width, height
        )
        GL.glFramebufferRenderbuffer(
            GL.GL_FRAMEBUFFER, GL.GL_DEPTH_STENCIL_ATTACHMENT,
            GL.GL_RENDERBUFFER, self.depth,
        )  # fmt: skip

        self.engine.window.size = (width, height)


class Editor:
    def __init__(self, path: Path):
        self.path = path
        self.view: Viewport | None = (
            None  # needs the GL context, so it is made on the first frame
        )
        self.seen = None
        self.title = path.name
        self.load()

    def load(self):
        self.src = self.path.read_text()
        self.mtime = self.path.stat().st_mtime_ns
        self.nodes = read_params(self.src)
        self.values = {k: n.value for k, n in self.nodes.items()}

        lines = self.src.splitlines()
        self.tips = {
            k: lines[n.lineno - 1]
            .encode()[n.end_col_offset :]
            .decode()
            .partition("#")[2]
            .strip()
            for k, n in self.nodes.items()
        }
        self.dirty = False
        self.pending = True

    def save(self):
        self.path.write_text(with_values(self.src, self.nodes, self.values))
        self.load()

    def rebuild(self):
        self.pending = False
        start = time.perf_counter()
        try:
            part = build(self.path, with_values(self.src, self.nodes, self.values))
            self.title = title(part, self.path)

            if self.view:
                self.view.show(to_mesh(part), self.title)

            self.status, self.error = (
                f"built in {time.perf_counter() - start:.2f}s",
                "",
            )
        except BuildError as err:
            self.status, self.error = (
                "build failed, showing the last successful build",
                str(err),
            )
        self.seen = stamps(self.path)

    def gui(self):
        """Rebuild if anything changed, then the two columns."""
        if self.view is None:
            self.view = Viewport()  # the GL context exists from the first frame on

        now = stamps(self.path)
        if now[self.path] not in (self.mtime, None):
            self.load()  # the part was saved from an editor: re-read its values
        elif now[self.path] is not None and now != self.seen:
            self.pending = True  # a block it imports changed
        if self.pending:
            self.rebuild()

        self.properties()
        imgui.same_line()
        self.viewport(self.view)

    def properties(self):
        """The parameters, Save and Revert, and how the last build went."""
        imgui.begin_child(
            "Properties",
            imgui.ImVec2(360, 0),
            imgui.ChildFlags_.borders | imgui.ChildFlags_.resize_x,
        )
        imgui.text(self.title)
        imgui.separator()

        for name, value in self.values.items():
            if type(value) is int:
                changed, value = imgui.input_int(name, value)
            else:
                changed, value = imgui.drag_float(
                    name, value, max(abs(value), 1) / 200, format="%.3f"
                )
                # imgui floats are 32-bit: save 4.1, not 4.099999904632568
                value = round(value, 3)
            if changed:
                self.values[name], self.dirty = value, True
            # rebuild at the end of a drag, Enter after typing, or a -/+ click
            if imgui.is_item_deactivated_after_edit() or (
                changed and not imgui.is_item_active()
            ):
                self.pending = True
            if self.tips[name]:
                imgui.set_item_tooltip(self.tips[name])
        imgui.separator()

        imgui.begin_disabled(not self.dirty)
        if imgui.button("Save"):
            self.save()
        imgui.same_line()
        if imgui.button("Revert"):
            self.load()
        imgui.end_disabled()

        imgui.text_disabled(self.status)
        if self.error:
            imgui.push_text_wrap_pos(0)
            imgui.text_colored(imgui.ImVec4(1, 0.4, 0.4, 1), self.error)
            imgui.pop_text_wrap_pos()
        imgui.end_child()

    def viewport(self, view: Viewport):
        """The f3d view, filling the rest of the window."""
        imgui.begin_child("Viewport")
        origin, size = imgui.get_cursor_screen_pos(), imgui.get_content_region_avail()
        scale = imgui.get_io().display_framebuffer_scale  # pixels per point, on HiDPI
        width, height = int(size.x * scale.x), int(size.y * scale.y)
        if width > 0 and height > 0:
            # an item under the image for the mouse, ImGui tells us when it is over
            # the view, and keeps a drag that starts here from going anywhere else
            buttons = imgui.ButtonFlags_.mouse_button_left
            buttons |= imgui.ButtonFlags_.mouse_button_right
            buttons |= imgui.ButtonFlags_.mouse_button_middle
            imgui.invisible_button("view", size, buttons)
            view.draw(width, height, origin, scale, imgui.is_item_hovered())

            imgui.set_cursor_screen_pos(origin)  # the image goes over the button
            # GL textures start at the bottom row, so flip it
            flip = imgui.ImVec2(0, 1), imgui.ImVec2(1, 0)
            imgui.image(imgui.ImTextureRef(view.tex), size, *flip)
        imgui.end_child()


def run(args):
    path: Path = args.part.resolve()
    editor = Editor(path)

    # SIGINT closes the window just like a close button does, shutdown imgui normally
    signal.signal(
        signal.SIGINT,
        lambda *_: setattr(hello_imgui.get_runner_params(), "app_shall_exit", True),
    )
    immapp.run(
        editor.gui,
        window_title=f"{path.name} - edit",
        window_size=WINDOW_SIZE,
        ini_disable=True,
    )
