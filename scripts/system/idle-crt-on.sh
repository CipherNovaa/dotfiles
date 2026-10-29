#!/bin/bash
# idle-crt-on.sh — relight the CRT, but ONLY if the session is unlocked.
#
# This is the fix for the tube burning the lock screen overnight: a spurious
# resume (stray input, audio, USB jitter) or a suspend/wake while still locked
# used to fire `crt-power on`, putting the lock screen back on the CRT. Now, if
# hyprlock is still up we leave the tube dark; lock-crt-sleep.sh relights it the
# moment you actually unlock.

pidof hyprlock >/dev/null 2>&1 && exit 0   # still locked -> keep the tube dark
sudo -n /usr/local/bin/crt-power on 2>/dev/null
