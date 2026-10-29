#!/bin/bash
# update-godot-colors.sh — stage the current pywal palette into Godot's editor
# settings so the editor is themed on its NEXT launch.
#
# While Godot is running the in-editor addon (addons/pywal_theme) re-themes the
# UI live, so we skip then to avoid clobbering the file Godot rewrites on exit —
# exactly the pattern update-deadbeef-colors.sh uses for the player.

set -euo pipefail

COLORS_JSON="$HOME/.cache/wal/colors.json"
SETTINGS="$HOME/.config/godot/editor_settings-4.6.tres"

[ -f "$COLORS_JSON" ] || exit 0
[ -f "$SETTINGS" ] || exit 0

# Godot live-themes itself via the addon; don't fight its on-exit write.
if pgrep -x godot >/dev/null 2>&1; then
  exit 0
fi

python3 - "$COLORS_JSON" "$SETTINGS" <<'PY'
import json, re, sys, colorsys

colors_path, settings_path = sys.argv[1], sys.argv[2]

with open(colors_path) as f:
    w = json.load(f)

special = w.get("special", {})
cols = w.get("colors", {})
if not special or not cols:
    sys.exit(0)

def rgba(hex_str, a=1.0):
    h = hex_str.lstrip("#")
    r, g, b = (int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4))
    return f"Color({r:.6g}, {g:.6g}, {b:.6g}, {a:g})"

def rgb_tuple(hex_str):
    h = hex_str.lstrip("#")
    return tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4))

bg = special.get("background", "#101010")
fg = special.get("foreground", "#cccccc")

# Accent = most vivid (saturation*value) of colors 1..6, matching the addon.
accent = cols.get("color1", "#5294e2")
best = -1.0
for i in range(1, 7):
    c = cols.get(f"color{i}")
    if not c:
        continue
    r, g, b = rgb_tuple(c)
    _, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s * v > best:
        best, accent = s * v, c

hl = "text_editor/theme/highlighting/"
values = {
    "interface/theme/preset": '"Custom"',
    "interface/theme/base_color": rgba(bg),
    "interface/theme/accent_color": rgba(accent),
    hl + "background_color": rgba(bg),
    hl + "text_color": rgba(fg),
    hl + "caret_color": rgba(fg),
    hl + "line_number_color": rgba(fg, 0.4),
    hl + "safe_line_number_color": rgba(fg, 0.6),
    hl + "current_line_color": rgba(fg, 0.06),
    hl + "word_highlighted_color": rgba(fg, 0.08),
    hl + "selection_color": rgba(accent, 0.4),
    hl + "search_result_color": rgba(accent, 0.2),
    hl + "symbol_color": rgba(fg),
    hl + "keyword_color": rgba(cols.get("color1", "#ff6677")),
    hl + "control_flow_keyword_color": rgba(cols.get("color5", "#cc88dd")),
    hl + "base_type_color": rgba(cols.get("color4", "#66ddbb")),
    hl + "engine_type_color": rgba(cols.get("color6", "#88eecc")),
    hl + "user_type_color": rgba(cols.get("color3", "#aaddee")),
    hl + "function_color": rgba(cols.get("color4", "#55aaff")),
    hl + "member_variable_color": rgba(cols.get("color5", "#bbddff")),
    hl + "number_color": rgba(cols.get("color6", "#a0ffdd")),
    hl + "string_color": rgba(cols.get("color2", "#ffee99")),
    hl + "comment_color": rgba(cols.get("color8", "#888888"), 0.6),
    hl + "doc_comment_color": rgba(cols.get("color8", "#888888"), 0.8),
}

with open(settings_path) as f:
    lines = f.read().splitlines()

seen = set()
out = []
for line in lines:
    m = re.match(r"^([^=\s]+)\s*=", line)
    key = m.group(1) if m else None
    if key in values:
        out.append(f"{key} = {values[key]}")
        seen.add(key)
    else:
        out.append(line)

# Append any keys not already present, just after the [resource] header.
missing = [(k, v) for k, v in values.items() if k not in seen]
if missing:
    try:
        idx = out.index("[resource]") + 1
    except ValueError:
        idx = len(out)
    inject = [f"{k} = {v}" for k, v in missing]
    out[idx:idx] = inject

with open(settings_path, "w") as f:
    f.write("\n".join(out) + "\n")
PY
