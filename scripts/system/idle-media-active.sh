#!/bin/bash
# idle-media-active.sh — exit 0 if a *video-capable* player is actively Playing.
#
# Used by the idle timers so the session doesn't lock / the CRT tube doesn't sleep
# while you're watching something. Music-only players (spotify, deadbeef) are
# intentionally ignored: falling asleep to music still lets the screens lock and
# the tube sleep (otherwise overnight music = phosphor burn).
#
# This is a safety net layered on top of hypridle's dbus idle-inhibit handling
# (ignore_dbus_inhibit = false) for players that don't advertise an inhibitor.

VIDEO_RE='firefox|chromium|chrome|brave|thorium|librewolf|zen|mpv|vlc|celluloid|haruna|mplayer|codec'

for p in $(playerctl -l 2>/dev/null); do
    case "${p,,}" in
        *spotify*|*deadbeef*) continue ;;   # music players never defer the timers
    esac
    if echo "$p" | grep -qiE "$VIDEO_RE"; then
        [ "$(playerctl -p "$p" status 2>/dev/null)" = "Playing" ] && exit 0
    fi
done
exit 1
