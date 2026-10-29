#!/bin/bash
# update-rgb.sh — sync OpenRGB devices to the pywal accent (color4)
# Called by wallpaper-picker.sh on every palette change.

COLORS="$HOME/.cache/wal/colors.json"
[ -f "$COLORS" ] || exit 0

command -v openrgb >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# pywal accent, with the leading # stripped (openrgb wants bare RRGGBB)
HEX=$(jq -r '.colors.color4' "$COLORS" | tr -d '#')
[ -n "$HEX" ] && [ "$HEX" != "null" ] || exit 0

# Device map (from `openrgb --list-devices`) — edit to match your own hardware:
#   0,1 ENE DRAM (RAM sticks)  — Static persists in hardware
#   2   Corsair Hydro H100i    — Direct only
#   3   ASUS ROG MAXIMUS XI    — motherboard ARGB header
#   4   Sony DualSense Edge    — Direct only, may be disconnected
# Missing devices fail silently via 2>/dev/null.
openrgb --device 0 --mode static --color "$HEX" 2>/dev/null  # RAM 1
openrgb --device 1 --mode static --color "$HEX" 2>/dev/null  # RAM 2
openrgb --device 2 --mode direct --color "$HEX" 2>/dev/null  # Corsair AIO
openrgb --device 3 --mode static --color "$HEX" 2>/dev/null  # MB ARGB
openrgb --device 4 --mode direct --color "$HEX" 2>/dev/null  # DualSense
