#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

# Self-discover the running Hyprland instance if the env var wasn't propagated to
# the systemd user session (laptop is non-uwsm; desktop uwsm doesn't always export it).
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    export HYPRLAND_INSTANCE_SIGNATURE="$(ls -1 "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" 2>/dev/null | head -n1)"
fi

exec python3 "$(dirname "$0")/focus_daemon.py"
