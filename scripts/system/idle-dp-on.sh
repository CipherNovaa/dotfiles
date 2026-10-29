#!/bin/bash
# idle-dp-on.sh — wake the main monitor (DP-3) on resume so the lock screen is
# visible to type. Unlike the CRT (idle-crt-on.sh, kept dark while locked to
# avoid phosphor burn-in), the LCD has no burn-in cost and IS where hyprlock
# shows, so we relight it on any input even while still locked.

# Only while locked: unlocked, a dark desk is the remote's POWER in CRT mode
# (codec_screen.sh) — waking the desk is then POWER's job, not any keypress.
pidof hyprlock >/dev/null 2>&1 || exit 0
sudo -n /usr/local/bin/dp-power on 2>/dev/null
