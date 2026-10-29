#!/usr/bin/env python3
"""
keybind_manager.py — view / search Hyprland keybinds and detect conflicts.

Two sources are merged:
  • `hyprctl binds -j`  → authoritative list of ACTIVE binds (modmask+key+submap).
                          This is what conflict detection runs on — it can't lie.
  • ~/.config/hypr/hyprland.lua → human-readable LABELS for each bind, since the
                          live dispatcher just reports "__lua" with a numeric arg.

Front-ends call the engine here. `--rofi` is the included one (pywal-themed);
a quickshell widget can consume `--json`.

Usage:
  keybind_manager.py --rofi        # interactive picker (default action: open file at line)
  keybind_manager.py --conflicts   # print only conflicting binds
  keybind_manager.py --list        # plain text table
  keybind_manager.py --json        # machine-readable (for quickshell)
"""
import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
LUA = os.path.join(HOME, ".config/hypr/hyprland.lua")

# Hyprland/X11 modmask bits.
MOD_BITS = [(64, "SUPER"), (4, "CTRL"), (8, "ALT"), (1, "SHIFT")]
# Canonical mod ordering for combo strings.
MOD_ORDER = {"SUPER": 0, "CTRL": 1, "ALT": 2, "SHIFT": 3}


def mods_from_mask(mask):
    return [name for bit, name in MOD_BITS if mask & bit]


def canon(mods, key):
    """Canonical combo string, e.g. 'SUPER+SHIFT+C'. Key kept verbatim but
    case-normalized for single letters so 'c' and 'C' match across sources."""
    mods = sorted(set(mods), key=lambda m: MOD_ORDER.get(m, 9))
    k = key
    if len(k) == 1 and k.isalpha():
        k = k.upper()
    return "+".join(mods + [k])


# ── active binds (authoritative) ──────────────────────────────────────────────
def active_binds():
    out = subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True)
    data = json.loads(out.stdout)
    binds = []
    for b in data:
        mods = mods_from_mask(b.get("modmask", 0))
        key = b.get("key") or (f"code:{b['keycode']}" if b.get("keycode") else "")
        if not key:
            continue
        binds.append({
            "combo": canon(mods, key),
            "mods": mods,
            "key": key,
            "submap": b.get("submap", "") or "global",
            "mouse": b.get("mouse", False),
            "locked": b.get("locked", False),
        })
    return binds


# ── lua label parsing (best-effort) ───────────────────────────────────────────
VARS = {}


def _load_vars(text):
    for m in re.finditer(r'local\s+(terminal|menu|fileManager)\s*=\s*"([^"]*)"', text):
        VARS[m.group(1)] = m.group(2)


def _keyspec_to_combo(spec):
    """Turn a lua key spec into a canonical combo, or None if it's loop-generated
    (contains a variable like `key` we can't statically resolve)."""
    spec = spec.strip()
    spec = spec.replace("mainMod", '"SUPER"')
    # Reject specs that still interpolate a non-string variable (e.g. `.. key`).
    parts = [p.strip() for p in spec.split("..")]
    pieces = []
    for p in parts:
        m = re.fullmatch(r'"([^"]*)"', p)
        if not m:
            return None  # unresolved variable -> loop-generated, skip literal match
        pieces.append(m.group(1))
    raw = "".join(pieces)  # e.g. 'SUPER + SHIFT + C' or '+ Print'
    toks = [t for t in re.split(r'\s*\+\s*', raw) if t]
    mods, key = [], None
    for t in toks:
        if t in MOD_ORDER:
            mods.append(t)
        else:
            key = t
    if not key:
        return None
    return canon(mods, key)


def _action_label(action):
    a = action.strip()
    m = re.search(r'exec_cmd\(\s*"([^"]*)"\s*\)', a)
    if m:
        return m.group(1)
    m = re.search(r'exec_cmd\(\s*home\s*\.\.\s*"([^"]*)"', a)
    if m:
        return "~" + m.group(1)
    m = re.search(r'exec_cmd\(\s*"([^"]*)"\s*\.\.\s*home\s*\.\.\s*"([^"]*)"', a)
    if m:
        return f"{m.group(1)}~{m.group(2)}"
    m = re.search(r'exec_cmd\(\s*(terminal|menu|fileManager)\s*\)', a)
    if m:
        return VARS.get(m.group(1), m.group(1))
    if "window.close" in a:
        return "Close window"
    if "window.fullscreen" in a:
        return "Fullscreen"
    if "window.float" in a:
        return "Toggle floating"
    if "window.drag" in a:
        return "Drag window (mouse)"
    if "window.resize" in a:
        return "Resize window (mouse)"
    if "layout(" in a:
        m = re.search(r'layout\("([^"]*)"', a)
        return f"Layout: {m.group(1)}" if m else "Layout"
    m = re.search(r'focus\(\{\s*direction\s*=\s*"([^"]*)"', a)
    if m:
        return f"Focus {m.group(1)}"
    m = re.search(r'window\.move\(\{\s*direction\s*=\s*"([^"]*)"', a)
    if m:
        return f"Move window {m.group(1)}"
    if "focus({ monitor" in a or "focus({monitor" in a:
        return "Focus monitor"
    if "window.move({ monitor" in a or "window.move({monitor" in a:
        return "Move window to monitor"
    if "focus({ workspace" in a or "focus({workspace" in a:
        return "Focus workspace"
    if "window.move({ workspace" in a or "window.move({workspace" in a:
        return "Move window to workspace"
    if a.startswith("function"):
        return "(inline function)"
    return a[:60]


def _split_top_comma(seg):
    """Index of the first comma at paren-depth 0, ignoring string contents."""
    depth, instr = 0, None
    for i, ch in enumerate(seg):
        if instr:
            if ch == instr:
                instr = None
            continue
        if ch in "\"'":
            instr = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            return i
    return None


def lua_labels():
    """Map canonical combo -> (label, line). Each hl.bind() call is read as a
    paren-balanced unit, so single- and multi-line binds parse the same way."""
    try:
        src = open(LUA).read().splitlines()
    except OSError:
        return {}, {}
    _load_vars("\n".join(src))
    labels, lines = {}, {}
    i, n = 0, len(src)
    while i < n:
        line = src[i]
        m = re.search(r'hl\.bind[lem]?\(', line)
        if not m:
            i += 1
            continue
        start_line = i + 1                     # 1-based for editor jump
        buf = line[m.end():]                   # text right after the opening (
        depth = 1
        # Accumulate until the bind's own parens balance.
        j = i
        while True:
            d, instr = 0, None
            for ch in buf:
                if instr:
                    if ch == instr:
                        instr = None
                    continue
                if ch in "\"'":
                    instr = ch
                elif ch in "([{":
                    d += 1
                elif ch in ")]}":
                    d -= 1
            depth = 1 + d
            if depth <= 0 or j + 1 >= n:
                break
            j += 1
            buf += "\n" + src[j]
        i = j + 1
        cut = _split_top_comma(buf)
        if cut is None:
            continue
        combo = _keyspec_to_combo(buf[:cut])
        if not combo:
            continue
        labels[combo] = _action_label(buf[cut + 1:])
        lines[combo] = start_line
    return labels, lines


# ── merge + conflicts ─────────────────────────────────────────────────────────
def build():
    binds = active_binds()
    labels, lines = lua_labels()
    # synthetic labels for loop-generated workspace binds
    for b in binds:
        if b["combo"] not in labels:
            k = b["key"]
            if "SUPER" in b["mods"] and "SHIFT" in b["mods"] and (k.isdigit() or k == "grave"):
                labels[b["combo"]] = "Move window to workspace " + (k if k.isdigit() else "11")
            elif "SUPER" in b["mods"] and (k.isdigit() or k == "grave"):
                labels[b["combo"]] = "Focus workspace " + (k if k.isdigit() else "11")
    for b in binds:
        b["label"] = labels.get(b["combo"], "—")
        b["line"] = lines.get(b["combo"])

    # conflicts: same combo within the same submap bound to >1 distinct label
    groups = {}
    for b in binds:
        groups.setdefault((b["submap"], b["combo"]), []).append(b)
    conflicts = {}
    for key, grp in groups.items():
        distinct = {g["label"] for g in grp}
        if len(grp) > 1 and len(distinct) > 1:
            conflicts[key] = grp
    for b in binds:
        b["conflict"] = (b["submap"], b["combo"]) in conflicts
    return binds, conflicts


# ── front-ends ────────────────────────────────────────────────────────────────
def fmt_row(b):
    flag = "  CONFLICT" if b["conflict"] else ""
    sm = "" if b["submap"] == "global" else f" [{b['submap']}]"
    return f"{b['combo']:<22} {b['label']}{sm}{flag}"


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "--list"
    binds, conflicts = build()
    binds.sort(key=lambda b: (not b["conflict"], b["combo"]))

    if mode == "--json":
        print(json.dumps({"binds": binds,
                          "conflicts": [list(k) for k in conflicts]}, indent=2))
        return

    if mode == "--conflicts":
        if not conflicts:
            print("No conflicts.")
            return
        for (sm, combo), grp in conflicts.items():
            print(f"{combo} ({sm}):")
            for g in grp:
                ln = f"  (hyprland.lua:{g['line']})" if g["line"] else ""
                print(f"    → {g['label']}{ln}")
        return

    if mode == "--rofi":
        rows = [fmt_row(b) for b in binds]
        header = f"{len(conflicts)} conflict(s)" if conflicts else "no conflicts"
        proc = subprocess.run(
            ["rofi", "-dmenu", "-i", "-p", "keybinds",
             "-mesg", f"Hyprland keybinds — {header}"],
            input="\n".join(rows), capture_output=True, text=True)
        sel = proc.stdout.strip()
        if not sel:
            return
        combo = sel.split()[0]
        b = next((x for x in binds if x["combo"] == combo and x["line"]), None)
        if b and b["line"]:
            subprocess.run(["kitty", "-e", "nvim", f"+{b['line']}", LUA])
        return

    # --list
    for b in binds:
        print(fmt_row(b))
    print(f"\n{len(binds)} binds, {len(conflicts)} conflict(s).")


if __name__ == "__main__":
    main()
