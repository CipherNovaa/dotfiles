#!/bin/bash
# update-hyprlock-bg.sh — render one static frame of the current MAIN wallpaper
# to a stable PNG for hyprlock. hyprlock can't animate GIFs and can't read the
# current-main pointer file (which holds a path string, not an image).

MAIN=$(cat "$HOME/.cache/wal/current-main" 2>/dev/null)
OUT="$HOME/.cache/wal/hyprlock-bg.png"

[ -n "$MAIN" ] && [ -f "$MAIN" ] || exit 0
command -v ffmpeg >/dev/null 2>&1 || exit 0

ffmpeg -y -i "$MAIN" -vframes 1 "$OUT" 2>/dev/null
