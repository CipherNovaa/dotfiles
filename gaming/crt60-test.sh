#!/bin/bash
# One-shot, self-reverting test: CRT (HDMI-A-1) -> 640x480@59.94 for 10 s, then back.
# Runs detached (setsid) so the restore happens even if the launching terminal dies.
# Result log: ~/.cache/crt60-test.log
LOG="$HOME/.cache/crt60-test.log"
setsid -f bash -c '
LOG="$1"
mon() { hyprctl monitors | grep -E "^Monitor|^\s+[0-9]+x[0-9]+@[0-9.]+ at"; }
{
  echo "== $(date +%T) before"; mon
  hyprctl eval "hl.monitor({ output = \"HDMI-A-1\", mode = \"640x480@59.94\", position = \"640x0\", scale = 1 })"
  sleep 3
  echo "== $(date +%T) during"; mon
  sleep 7
  hyprctl eval "hl.monitor({ output = \"HDMI-A-1\", mode = \"1280x1024@75\", position = \"0x0\", scale = 1 })"
  sleep 3
  echo "== $(date +%T) after"; mon
} > "$LOG" 2>&1
' _ "$LOG"
echo "test running (10 s) — watch the CRT; log: $LOG"
