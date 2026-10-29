#!/bin/bash
# idle-dp-off.sh — sleep the MAIN monitor (DP-3, HKC 27E3Q) on idle, but ONLY
# while the session is locked. That gate is the whole point: the main LED must
# never blank during normal (unlocked) work — only once you've locked and walked
# away. Darkens via the kernel sysfs force-disconnect path (dp-power), NEVER
# compositor dpms — that reshuffles the shared CRTC pool and crashes the
# foreground session. Wakes via idle-dp-on.sh. Works around the HKC 27E3Q DDC/DPMS bug.

pidof hyprlock >/dev/null 2>&1 || exit 0        # only sleep DP-3 while locked
sudo -n /usr/local/bin/dp-power off 2>/dev/null
