#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════════════════
# trackball-mode — the TB550's wheel button: hold-to-scroll, except where an app
# needs a REAL middle button.
#
# hyprland.lua gives the Kensington TB550 libinput's on_button_down scrolling on
# BTN_MIDDLE (hold the wheel button + roll the ball = scroll). libinput then OWNS
# that button: a hold never reaches an app (it becomes scroll) and a quick click
# arrives as press+release at the same instant on release. So Aseprite's
# middle-drag pan zoomed instead, and Valheim's in-game middle never registered
# (its key-binding menu, which takes any event, still did) — 2026-10-16.
#
# One button can't be both, so this follows the FOCUSED window: in the apps
# below the trackball gets scroll_method "no_scroll" (the wheel button is a
# plain middle button again; the wheel itself still scrolls), everywhere else
# it is set back to on_button_down. Applied with `hyprctl eval hl.device{...}`
# (`hyprctl keyword` is dead on the Lua build) — the FULL device spec each
# time, mirroring the block in hyprland.lua; keep the two in step.
#
# Launched from hyprland.lua (hyprland.start). Log: ~/.cache/trackball-mode.log
# ═══════════════════════════════════════════════════════════════════════════════

import json
import os
import re
import socket
import subprocess
import time
from pathlib import Path

# Window classes (regex, case-insensitive) where the wheel button stays a real
# middle button. Add an app here and restart the script (or log out/in).
MIDDLE_APPS = [
    r"^aseprite$",          # middle-drag pans the canvas
    r"^blender$",           # middle-drag orbits / pans the viewport
    r"godot",               # middle-drag pans the 2D/3D editor
    r"^steam_app_\d+$",     # any Proton game
    r"^valheim",            # native Valheim (valheim.x86_64)
    r"^gamescope$",
]

DEVICE = {
    "name": "cx-tb550-2.4ghz-receiver-mouse",
    "accel_profile": "flat",
    "sensitivity": 0,
    "scroll_button": 274,
    "natural_scroll": False,
}

LOG = Path.home() / ".cache" / "trackball-mode.log"
_middle = [re.compile(p, re.I) for p in MIDDLE_APPS]


def log(msg):
    try:
        with open(LOG, "a") as f:
            f.write(f"[{time.strftime('%H:%M:%S')}] {msg}\n")
    except Exception:
        pass


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    return '"' + str(v).replace("\\", "\\\\").replace('"', '\\"') + '"'


def apply(method):
    spec = dict(DEVICE, scroll_method=method)
    body = ", ".join(f"{k} = {lua(v)}" for k, v in spec.items())
    r = subprocess.run(["hyprctl", "eval", "hl.device({ " + body + " })"],
                       capture_output=True, text=True, timeout=5)
    ok = r.returncode == 0 and r.stdout.strip() == "ok"
    log(f"scroll_method={method} {'ok' if ok else 'FAILED: ' + (r.stdout + r.stderr).strip()}")
    return ok


def wants_middle(cls):
    return any(p.search(cls or "") for p in _middle)


def active_class():
    try:
        r = subprocess.run(["hyprctl", "activewindow", "-j"],
                           capture_output=True, text=True, timeout=5)
        return (json.loads(r.stdout or "{}") or {}).get("class", "")
    except Exception:
        return ""


def socket2_path():
    rt = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        d = Path(rt) / "hypr"
        sigs = sorted(d.glob("*"), key=lambda p: p.stat().st_mtime, reverse=True)
        sig = sigs[0].name if sigs else ""
    return Path(rt) / "hypr" / sig / ".socket2.sock"


def main():
    current = None   # the method last applied

    def follow(cls, force=False):
        nonlocal current
        want = "no_scroll" if wants_middle(cls) else "on_button_down"
        if force or want != current:
            if apply(want):
                current = want
                log(f"  focus: {cls!r}")

    while True:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(str(socket2_path()))
            log("connected")
            follow(active_class(), force=True)
            buf = b""
            while True:
                chunk = s.recv(4096)
                if not chunk:
                    raise ConnectionError("socket closed")
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    ev, _, data = line.decode(errors="replace").partition(">>")
                    if ev == "activewindow":
                        follow(data.split(",", 1)[0])
                    elif ev == "configreloaded":
                        # a reload re-applies hyprland.lua's on_button_down
                        current = None
                        follow(active_class(), force=True)
        except Exception as e:
            log(f"reconnecting ({e})")
            time.sleep(2)


if __name__ == "__main__":
    main()
