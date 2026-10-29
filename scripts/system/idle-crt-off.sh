#!/bin/bash
# idle-crt-off.sh — drop the CRT (HDMI-A-1) tube to standby on idle, UNLESS a
# video is actively playing. Only ever touches the CRT via the kernel sysfs
# force-disconnect path (crt-power); the main LED (DP-3) is never compositor-dpms'd
# because that reshuffles the shared CRTC pool and crashes the foreground session.

~/scripts/system/idle-media-active.sh && exit 0   # watching something -> keep it on
sudo -n /usr/local/bin/crt-power off 2>/dev/null
