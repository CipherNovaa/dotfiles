#!/bin/bash
# update-starship-colors.sh — rewrites starship palette from pywal colors

COLORS="$HOME/.cache/wal/colors.json"
TOML="$HOME/.config/starship.toml"

[ -f "$COLORS" ] || exit 0

# Extract pywal colors
c0=$(jq -r '.colors.color0' "$COLORS")
c1=$(jq -r '.colors.color1' "$COLORS")
c2=$(jq -r '.colors.color2' "$COLORS")
c3=$(jq -r '.colors.color3' "$COLORS")
c4=$(jq -r '.colors.color4' "$COLORS")
c5=$(jq -r '.colors.color5' "$COLORS")
bg=$(jq -r '.special.background' "$COLORS")
fg=$(jq -r '.special.foreground' "$COLORS")

# Rewrite the palette block in starship.toml
python3 - << EOF
import re

with open("$TOML", "r") as f:
    content = f.read()

new_palette = """[palettes.gruvbox_dark]
color_fg0 = '$fg'
color_bg1 = '$c0'
color_bg3 = '$c1'
color_blue = '$c4'
color_aqua = '$c2'
color_green = '$c2'
color_orange = '$c3'
color_purple = '$c5'
color_red = '$c1'
color_yellow = '$c3'
"""

# Replace existing palette block
content = re.sub(
    r'\[palettes\.gruvbox_dark\].*?(?=\n\[|\Z)',
    new_palette,
    content,
    flags=re.DOTALL
)

with open("$TOML", "w") as f:
    f.write(content)

print("Starship palette updated from pywal")
EOF
