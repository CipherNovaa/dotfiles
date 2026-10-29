#!/bin/bash
# launch-wallpaper.sh — awww wallpaper launcher for Hyprland
# Restores last wallpapers set by wallpaper-picker on login

CACHE_MAIN="$HOME/.cache/wal/current-main"
CACHE_CRT="$HOME/.cache/wal/current-crt"

# First boot (nothing picked yet): fall back to the first image in WALLPAPER_DIR.
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
FIRST_WP=$(ls -1 "$WALLPAPER_DIR"/*.{gif,png,jpg,jpeg,webp} 2>/dev/null | head -n1)
MAIN_WP=$(cat "$CACHE_MAIN" 2>/dev/null || echo "$FIRST_WP")
CRT_WP=$(cat "$CACHE_CRT"  2>/dev/null || echo "$FIRST_WP")

mkdir -p "$HOME/.cache/wal"

# Wait for awww-daemon to be ready
timeout 10 bash -c 'until awww query DP-3 2>/dev/null; do sleep 0.2; done' 2>/dev/null

awww img "$MAIN_WP" --outputs DP-3 --transition-type none --resize stretch
awww img "$CRT_WP"  --outputs HDMI-A-1 --transition-type none --resize stretch

# Refresh the hyprlock static background to match the restored wallpaper
~/scripts/system/update-hyprlock-bg.sh &

# Restore the Stream Deck (desk piece) wallpaper if the venv exists.
# Prefer the deck-specific choice (set via the wallpaper picker's "Stream Deck"
# action); fall back to the main display wallpaper if none was ever set.
SD_PY="$HOME/.local/share/streamdeck-venv/bin/python"
CACHE_SD="$HOME/.cache/wal/current-streamdeck"
SD_WP=$(cat "$CACHE_SD" 2>/dev/null)
[ -n "$SD_WP" ] && [ -e "$SD_WP" ] || SD_WP="$MAIN_WP"
[ -x "$SD_PY" ] && setsid "$SD_PY" ~/scripts/system/streamdeck-wallpaper.py "$SD_WP" >/dev/null 2>&1 &
