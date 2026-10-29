#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════════════════
# dolphin-crt60d — run the CRT at 59.94 Hz while a Dolphin game is on it.
#
# GameCube games (Melee) run at 59.94 fps. On the CRT's normal 75 Hz every 4th
# frame is held for two refreshes, a steady judder that makes the game feel slow.
# While a Dolphin game window sits on the CRT (HDMI-A-1), switch it to
# 640x480@59.94 (one refresh per game frame); when the game closes, restore the
# CRT's mode from ~/.config/hypr/hyprland.lua (single source of truth).
#
# Only restores a mode it set itself, so manual mode changes are left alone.
# Managed by systemd: dolphin-crt60d.service (graphical-session.target).
#
# Log: ~/.cache/dolphin-crt60d.log
# ═══════════════════════════════════════════════════════════════════════════════

import json
import os
import re
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path

CRT = "HDMI-A-1"
GAME_MODE = "640x480@59.94"
HYPR_CONF = Path.home() / ".config" / "hypr" / "hyprland.lua"
FALLBACK_RULE = 'hl.monitor({ output = "HDMI-A-1", mode = "1280x1024@75", position = "0x0", scale = 1 })'
LOG = Path.home() / ".cache" / "dolphin-crt60d.log"

state = {"switched": False}


def log(msg):
    try:
        with LOG.open("a") as f:
            f.write(f"{time.strftime('%F %T')} {msg}\n")
    except Exception:
        pass


# ── Hyprland helpers ─────────────────────────────────────────────────────────
def runtime_dir():
    return os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")


def instance_sig():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if sig:
        return sig
    hyprdir = Path(runtime_dir()) / "hypr"
    try:
        sigs = sorted(hyprdir.glob("*"), key=lambda p: p.stat().st_mtime, reverse=True)
        return sigs[0].name if sigs else None
    except Exception:
        return None


def socket2_path():
    sig = instance_sig()
    if not sig:
        return None
    return Path(runtime_dir()) / "hypr" / sig / ".socket2.sock"


def hyprctl_json(args):
    try:
        return json.loads(subprocess.check_output(["hyprctl", *args, "-j"], text=True))
    except Exception as e:
        log(f"hyprctl {args} failed: {e}")
        return []


def hypr_eval(lua):
    try:
        subprocess.run(["hyprctl", "eval", lua],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        log(f"eval failed: {e}")


# ── CRT modes ────────────────────────────────────────────────────────────────
def restore_rule():
    """The CRT's hl.monitor(...) line from hyprland.lua, verbatim."""
    try:
        m = re.search(r'hl\.monitor\(\{[^}]*output\s*=\s*"' + re.escape(CRT) + r'"[^}]*\}\)',
                      HYPR_CONF.read_text())
        if m:
            return m.group(0)
    except Exception as e:
        log(f"reading {HYPR_CONF} failed: {e}")
    return FALLBACK_RULE


def game_rule():
    """GAME_MODE, positioned so the CRT's right edge still meets the main monitor."""
    rule = restore_rule()
    width = int(re.search(r'mode\s*=\s*"(\d+)x', rule).group(1))
    x, y = map(int, re.search(r'position\s*=\s*"(-?\d+)x(-?\d+)"', rule).groups())
    game_w = int(GAME_MODE.split("x")[0])
    return (f'hl.monitor({{ output = "{CRT}", mode = "{GAME_MODE}", '
            f'position = "{x + width - game_w}x{y}", scale = 1 }})')


def crt_in_game_mode():
    for m in hyprctl_json(["monitors"]):
        if m["name"] == CRT:
            w, h = map(int, GAME_MODE.split("@")[0].split("x"))
            hz = float(GAME_MODE.split("@")[1])
            return m["width"] == w and m["height"] == h and abs(m["refreshRate"] - hz) < 0.1
    return False


# ── Game detection ───────────────────────────────────────────────────────────
def game_on_crt():
    """A Dolphin game window is open on the CRT.

    Dolphin's idle windows are titled plainly ("Dolphin 2609", "Graphics", ...);
    while a game runs its render window's title carries " | "-separated info.
    """
    crt_id = next((m["id"] for m in hyprctl_json(["monitors"]) if m["name"] == CRT), None)
    if crt_id is None:
        return False
    for c in hyprctl_json(["clients"]):
        if (c.get("class") == "dolphin-emu" and " | " in c.get("title", "")
                and c.get("monitor") == crt_id and c.get("mapped", True)):
            return True
    return False


def enter_game_mode():
    rule = game_rule()
    hypr_eval(rule)
    state["switched"] = True
    log(f"game on CRT -> {rule}")


def restore():
    rule = restore_rule()
    hypr_eval(rule)
    state["switched"] = False
    log(f"no game -> {rule}")


def reconcile():
    want = game_on_crt()
    if want and not crt_in_game_mode():
        enter_game_mode()
    elif not want and state["switched"]:
        restore()


def on_term(*_):
    if state["switched"]:
        restore()
    sys.exit(0)


def main():
    sp = socket2_path()
    if not sp or not sp.exists():
        log(f"socket2 not found ({sp}); exiting")
        sys.exit(1)

    signal.signal(signal.SIGTERM, on_term)
    log("dolphin-crt60d started")
    # A previous instance may have died mid-game: if the CRT is still in game
    # mode, adopt it so reconcile() restores it once no game is running.
    state["switched"] = crt_in_game_mode()
    reconcile()

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(str(sp))
    with s.makefile("r") as f:
        for line in f:
            ev = line.split(">>", 1)[0]
            # openwindow/closewindow = game window appears/disappears;
            # windowtitlev2 = Dolphin retitles when a game starts/stops;
            # movewindowv2 = window flung between monitors;
            # monitoraddedv2 = CRT re-hotplugged (its rule resets the mode).
            if ev in ("openwindow", "closewindow", "windowtitlev2", "movewindowv2", "monitoraddedv2"):
                time.sleep(0.15)  # let the window settle onto its monitor/ws
                try:
                    reconcile()
                except Exception as e:
                    log(f"event error on '{line.strip()}': {e}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        on_term()
    except Exception as e:
        log(f"fatal: {e}")
        raise
