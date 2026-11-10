"""A f3d window that rebuilds the part each time it is saved.

Editing a part, or a block it imports, will rebuild it swap it in, keeping the camera.
Build errors are printed to stdout and the window will keep the last working model.

Close the window, press Ctrl+Q or send a SIGINT to stop.
"""

import signal
import time

import f3d

from .part import VIEW_OPTIONS, BuildError, build, show, stamps, title, to_mesh


def run(args):
    path = args.part.resolve()

    engine = f3d.Engine.create()
    engine.options.update(VIEW_OPTIONS)
    engine.window.set_window_name(f"{path.name} - preview")  # while the print builds
    seen, has_model = None, False

    def poll(_state=None):
        nonlocal seen, has_model
        now = stamps(path)
        if now == seen or now[path] is None:  # unchaged or mid-save
            return
        start, stamp = time.perf_counter(), time.strftime("%H:%M:%S")
        try:
            part = build(path)
            mesh = to_mesh(part)
        except BuildError as e:
            print(
                f"{e}\n{stamp} build failed, keeping the last working model", flush=True
            )
            return
        finally:
            seen = stamps(path)  # after the build, there might be more files to watch

        model_title = title(part, path)
        show(engine, mesh, keep_camera=has_model, name=model_title)
        has_model = True
        engine.window.set_window_name(f"{model_title} - preview")
        engine.interactor.request_render()
        print(
            f"{stamp} built {title(part, path)} in {time.perf_counter() - start:.2f} s",
            flush=True,
        )

    poll()  # first build before the window opens, so it opens on the model
    engine.interactor.set_event_loop_user_callback(
        poll
    )  # then check the file every tick (1/30 s)

    # end the event loop when SIGINT is caught
    signal.signal(signal.SIGINT, lambda *_: engine.interactor.request_stop())
    engine.interactor.start()
