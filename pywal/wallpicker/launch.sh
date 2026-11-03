#!/bin/bash
# Opens the wallpaper overlay on the focused screen, or closes it if it's already open.
DIR="$(dirname "$(readlink -f "$0")")"
QML="$DIR/shell.qml"

if pgrep -f "qs -p $QML" >/dev/null 2>&1; then
    pkill -f "qs -p $QML"
    exit 0
fi

WALLPICK_SCREEN=$(hyprctl monitors -j | python3 -c \
    "import json,sys; print(next((m['name'] for m in json.load(sys.stdin) if m['focused']), ''))")
export WALLPICK_SCREEN
exec qs -p "$QML"
