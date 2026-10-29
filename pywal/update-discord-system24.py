#!/usr/bin/env python3
"""Generate a system24 colour override from the current pywal palette.

system24 (the boxy Discord theme) exposes its colours as CSS variables
(--bg-1..4, --text-1..5, --accent-1..5, status colours). This writes an
override theme that points those at the pywal colours so the boxy layout
follows the wallpaper. Loaded after system24.theme.css in Vencord so it wins.
"""
import json, os, colorsys

CACHE = os.path.expanduser("~/.cache/wal/colors.json")
OUT = os.path.expanduser("~/.config/vesktop/themes/system24-pywal.css")


def _rgb(hexs):
    h = hexs.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _hex(r, g, b):
    return "#%02x%02x%02x" % (max(0, min(255, int(r))),
                              max(0, min(255, int(g))),
                              max(0, min(255, int(b))))


def lighten(hexs, amount):
    """Move a colour towards white in HLS space by `amount` (0..1)."""
    r, g, b = (c / 255 for c in _rgb(hexs))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    l = max(0.0, min(1.0, l + amount))
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return _hex(r * 255, g * 255, b * 255)


def main():
    if not os.path.exists(CACHE):
        return
    with open(CACHE) as f:
        w = json.load(f)
    bg = w["special"]["background"]
    fg = w["special"]["foreground"]
    c = w["colors"]

    # Background layers, darkest (main) -> lightest (clicked buttons).
    bg4 = bg
    bg3 = lighten(bg, 0.04)
    bg2 = lighten(bg, 0.08)
    bg1 = lighten(bg, 0.12)

    css = f""":root {{
    --colors: on;

    /* backgrounds (pywal) */
    --bg-1: {bg1};
    --bg-2: {bg2};
    --bg-3: {bg3};
    --bg-4: {bg4};

    /* text (pywal) */
    --text-0: {bg4};
    --text-1: {lighten(fg, 0.10)};
    --text-2: {fg};
    --text-3: {fg};
    --text-4: {lighten(bg, 0.42)};
    --text-5: {lighten(bg, 0.30)};

    /* accents (pywal) */
    --accent-1: {c['color4']};
    --accent-2: {c['color4']};
    --accent-3: {c['color4']};
    --accent-4: {lighten(c['color4'], 0.08)};
    --accent-5: {lighten(c['color4'], 0.14)};
    --accent-new: {c['color1']};

    /* status colours (pywal) */
    --online: {c['color2']};
    --dnd: {c['color1']};
    --idle: {c['color3']};
    --streaming: {c['color5']};
    --offline: {lighten(bg, 0.42)};
}}
"""
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        f.write(css)


if __name__ == "__main__":
    main()
