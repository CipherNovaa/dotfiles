#!/bin/bash
export DISPLAY=:0
export WAYLAND_DISPLAY=wayland-1
# The Typing of the Dead (PC) at 640x480, stretched by gamescope to the 5:4 CRT.
cd "${TTOTD_DIR:-$HOME/games/ttotd}" && gamescope -w 640 -h 480 -W 1280 -H 1024 -S stretch -f --force-windows-fullscreen -- wine Tod_e.exe -fullscreen &

GAMESCOPE_PID=$!

sleep 2
ydotool key 28:1
sleep 0.1
ydotool key 28:0

wait $GAMESCOPE_PID
ydotool key 28:0
