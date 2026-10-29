#!/bin/bash
# lock-crt-sleep.sh — lock the session and sleep ONLY the CRT (HDMI-A-1).
#
# Why: while locked we don't want the CRT tube burning the lock screen into the
# phosphor, so we power the tube down to standby. But we must NEVER touch the
# main monitor (DP-3): the two outputs share a 2-CRTC pool, and any *compositor*
# dpms/disable makes aquamarine tear down BOTH outputs to reshuffle CRTCs — that
# momentary release of DP-3's CRTC blanks main and kills the foreground terminal.
# Proven in hyprland.log.
#
# THE SAFE PATH: don't ask the compositor to power-cycle the CRT. Make the KERNEL
# report the CRT connector disconnected (sysfs force-status). aquamarine then
# takes the clean per-output path — "Skipping connector DP-3, has crtc 199 and is
# connected" — so main is never touched. See root/crt-power.

set -u

# Sleep/wake the CRT via the privileged helper. Tolerant: if the helper isn't
# installed yet, we still lock (the tube just won't sleep) rather than failing.
crt() {
    if command -v crt-power >/dev/null 2>&1; then
        sudo -n /usr/local/bin/crt-power "$1" 2>/dev/null \
            || echo "lock-crt-sleep: crt-power $1 failed (sudoers drop-in installed?)" >&2
    else
        echo "lock-crt-sleep: crt-power not installed; skipping CRT $1" >&2
    fi
}

dp() { sudo -n /usr/local/bin/dp-power "$1" 2>/dev/null; }
lit() { local f; for f in /sys/class/drm/card*-"$1"/status; do [ "$(cat "$f" 2>/dev/null)" = connected ]; return; done; return 1; }

# Don't stack a second lock if one is already up.
if pidof hyprlock >/dev/null 2>&1; then
    exit 0
fi

# Put back exactly what was lit (a remote's POWER key may have the tube in standby,
# or the desk monitor dark while a player runs on the CRT).
crt_was=0; lit HDMI-A-1 && crt_was=1
desk_was=0; lit DP-3 && desk_was=1

[ "$desk_was" = 0 ] && dp on      # the lock needs a screen to show on
[ "$crt_was" = 1 ] && crt off     # force CRT connector disconnected -> tube drops to standby
hyprlock                          # blocks here until the password is accepted
[ "$crt_was" = 1 ] && crt on      # re-detect connector -> Hyprland reapplies the monitor rule
                                  # (codec, if it lived on the tube, goes back to it)
[ "$desk_was" = 1 ] && ! lit DP-3 && dp on   # idle-dp-on.sh missed the wake
[ "$desk_was" = 0 ] && dp off     # CRT mode again: the desk dark
exit 0
