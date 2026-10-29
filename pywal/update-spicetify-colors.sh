#!/bin/bash
# update-spicetify-colors.sh — regenerate the spicetify "Pywal" theme's colour
# scheme from the current pywal palette, in realtime.
#
# The Pywal theme folder carries the `text` theme's layout (user.css, a TUI/
# spotify-tui look by darkthemer) so the colours below use the *text theme's*
# colour keys (accent / banner / border-* / highlight / main-elevated / …),
# not the minimal generic-Spotify keys the old version wrote. We keep our own
# copy of the layout in this folder so a `spicetify-themes` package update can't
# clobber it. To set up: copy Themes/text/user.css from spicetify-themes
# (github.com/spicetify/spicetify-themes, MIT) into ~/.config/spicetify/Themes/Pywal/.

COLORS="$HOME/.cache/wal/colors.json"
THEME_DIR="$HOME/.config/spicetify/Themes/Pywal"
COLOR_INI="$THEME_DIR/color.ini"

[ -f "$COLORS" ] || exit 0
mkdir -p "$THEME_DIR"

python3 - "$COLORS" "$COLOR_INI" <<'PY'
import sys, json

colors_path, out_path = sys.argv[1], sys.argv[2]
with open(colors_path) as f:
    w = json.load(f)
sp, col = w["special"], w["colors"]

def t(hexs):
    h = hexs.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

def hx(r, g, b):
    f = lambda v: max(0, min(255, int(round(v))))
    return f"{f(r):02x}{f(g):02x}{f(b):02x}"

def lighten(hexs, amount):
    r, g, b = t(hexs)
    return hx(r + amount, g + amount, b + amount)

def blend(a, b, k):
    # k=0 -> a, k=1 -> b
    ar, ag, ab = t(a); br, bg_, bb = t(b)
    return hx(ar + (br - ar) * k, ag + (bg_ - ag) * k, ab + (bb - ab) * k)

bg  = sp["background"]
fg  = sp["foreground"]
acc = col["color3"]      # color3 is the established system-wide pywal accent
c8  = col["color8"]

scheme = {
    # base surfaces
    "main":              bg,
    "main-elevated":     lighten(bg, 14),     # cards / elevated panels
    "highlight":         lighten(bg, 26),     # hovered / selected-row background
    # text
    "text":              fg,
    "subtext":           blend(fg, bg, 0.45), # dimmed secondary text
    "header":            blend(fg, bg, 0.50), # section headers / muted labels
    # accent family
    "accent":            acc,
    "accent-active":     lighten(acc, 30),
    "accent-inactive":   bg,
    "banner":            acc,                  # ascii banner colour
    # borders (the text theme is all boxes)
    "border-active":     acc,
    "border-inactive":   c8,
    # buttons
    "button-active":     acc,
    "button-disabled":   blend(fg, bg, 0.25),
    # notifications
    "notification":       acc,
    "notification-error": col["color1"],
}

width = max(len(k) for k in scheme)
lines = ["[Pywal]"]
for k, v in scheme.items():
    lines.append(f"{k.ljust(width)} = {v.lstrip('#').upper()}")
with open(out_path, "w") as f:
    f.write("\n".join(lines) + "\n")
PY

# Live-reload colours in a running Spotify (spicetify watch picks this up).
# -n = don't rebuild the JS, colours only — keeps it instant.
spicetify refresh -n 2>/dev/null &
