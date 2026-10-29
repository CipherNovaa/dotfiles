#!/bin/bash
# gamemode-toggle.sh — desktop gaming mode for Hyprland (quickshell stack).
#
# Suspends the rice (compositor eye-candy + every background eater of GPU/VRAM/CPU)
# and maxes out the GPU/CPU, then restores everything cleanly on the second press.
# Bound to SUPER+F10 in hyprland.lua. Desktop-only — the laptop has no game-mode bind.
#
# Rewritten 2026-06-11 for the current stack: the old version still killed dunst /
# player-popup.py / restarted deadbeef by the wrong name, and restored gaps to the
# wrong values, which is what broke the wallpaper + waybar on toggle-off.

STATEFILE="$HOME/.cache/gamemode-active"

# notify-send only works while quickshell (the notif daemon) is alive, so we fire the
# "ON" toast *before* killing it and the "OFF" toast *after* bringing it back.
notify() { command -v notify-send >/dev/null && notify-send -t 2500 "$1" "$2" 2>/dev/null; }

enable_gamemode() {
    notify "🎮 Game Mode ON" "Suspending rice · maxing GPU/CPU"
    sleep 0.4   # let the toast paint before the notif daemon dies
    echo 1 > "$STATEFILE"

    # ── Kill the rice + background eaters (free GPU, VRAM and CPU) ──────────────
    systemctl --user stop quickshell.service            2>/dev/null  # widgets + notifs + OSD
    systemctl --user stop keybr-dash-supervisor.service 2>/dev/null  # respawns keybr if left
    pkill -f "keybr"           2>/dev/null   # the chromium keybr practice instance (heavy)
    pkill -x waybar            2>/dev/null
    pkill -f "deadbeef"        2>/dev/null   # deadbeef / deadbeef-main
    pkill -f "art-daemon.sh"   2>/dev/null
    pkill -f "resize-art.sh"   2>/dev/null
    pkill -x openrgb           2>/dev/null
    pkill -x nm-applet         2>/dev/null
    pkill -x awww-daemon       2>/dev/null   # wallpaper daemon (kills the wallpaper)

    # ── Compositor eye-candy off ───────────────────────────────────────────────
    # `hyprctl keyword` is dead on the Lua build — set options with hl.config via eval.
    # Opacity 1.0 also matters: a translucent game window can't be direct-scanned-out.
    hyprctl eval 'hl.config({ animations = { enabled = false }, decoration = { blur = { enabled = false }, shadow = { enabled = false }, active_opacity = 1.0, inactive_opacity = 1.0 }, general = { gaps_in = 0, gaps_out = 0 } })' >/dev/null 2>&1

    # ── CPU: performance power profile (no sudo; remembers what to restore) ────
    # intel_pstate only has performance/powersave governors, and sudo can't prompt
    # from a keybind — power-profiles-daemon is the no-password way in.
    powerprofilesctl get > "$STATEFILE" 2>/dev/null
    powerprofilesctl set performance 2>/dev/null

    # Nvidia: nothing to do — the driver ramps up under load on its own, and the old
    # nvidia-settings/nvidia-smi lines were silent no-ops (X-only / needed sudo).
    # Per-game gamemode (renice, ioprio) needs `gamemoderun %command%` in the game's
    # Steam launch options; a daemon started here can't attach to games.

    echo "Game mode enabled"
}

disable_gamemode() {
    # ── Restore the power profile that was active before game mode ─────────────
    prev=$(cat "$STATEFILE" 2>/dev/null)
    case "$prev" in performance|balanced|power-saver) powerprofilesctl set "$prev" 2>/dev/null ;; esac
    rm -f "$STATEFILE"

    # ── Compositor eye-candy back on ───────────────────────────────────────────
    # A reload re-runs hyprland.lua, so every value comes back exactly as configured
    # (no hand-copied numbers to drift out of sync).
    hyprctl reload >/dev/null 2>&1

    # ── Bring the rice back (mirrors the hyprland.lua autostart block) ──────────
    awww-daemon >/dev/null 2>&1 &
    sleep 0.5
    "$HOME/scripts/system/launch-wallpaper.sh" >/dev/null 2>&1 &
    waybar                                      >/dev/null 2>&1 &
    "$HOME/scripts/system/launch-deadbeef.sh"   >/dev/null 2>&1 &
    "$HOME/scripts/bar/art-daemon.sh"           >/dev/null 2>&1 &
    "$HOME/scripts/bar/resize-art.sh"           >/dev/null 2>&1 &
    openrgb --server                            >/dev/null 2>&1 &
    nm-applet                                   >/dev/null 2>&1 &
    "$HOME/scripts/keybr-launch"                >/dev/null 2>&1 &
    systemctl --user start quickshell.service   2>/dev/null

    sleep 0.6
    notify "🖥️ Game Mode OFF" "Rice restored"
    echo "Game mode disabled"
}

if [ -f "$STATEFILE" ]; then
    disable_gamemode
else
    enable_gamemode
fi
