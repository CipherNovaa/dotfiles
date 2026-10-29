#!/bin/bash
# NEC's monitor test-pattern utility (Windows) under wine, fullscreen on the CRT.
wine "${NEC_TEST_EXE:-$HOME/games/nec-testpattern/software/nec_test.exe}" &

sleep 1.5
ydotool key 194

sleep 1.5
hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen", window = "title:NEC Monitor Test Window" })'
