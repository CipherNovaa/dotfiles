#!/bin/bash
# lock-anchor.sh {ensure|drop|release} — keep Hyprland from having ZERO outputs
# while you're away.
#
# Why: while locked, the CRT is force-disconnected (lock-crt-sleep.sh) and after
# 30 min idle DP-3 is too (idle-dp-off.sh). With no output left, Hyprland 0.56.2
# segfaults the moment any window maps (Layout::Floating newTarget, 2026-10-14) —
# the session dies, the watchdog relaunches it in safe mode, and the tube stays
# dark. So before the last real screen goes dark we hold a headless stand-in
# output; windows that map meanwhile land on it and move back when it's removed.
#
#   ensure   create the anchor (if missing) and wait until Hyprland has it.
#            Exit 1 if it never appears -> callers must NOT darken the screen.
#            Remembers each real screen's active workspace for `release`.
#   drop     remove the anchor NOW, real output or not. idle-dp-on.sh calls it
#            right before relinking DP-3, so DP-3 wakes into an empty compositor
#            exactly as it did before the anchor existed. Woken WHILE the anchor
#            holds everything, DP-3's first modeset is refused ("page-flip is
#            awaiting"): with nothing retrying, the HKC panel falls into deep
#            sleep (power-button-only wake); with workspaces moved over, Hyprland
#            retries by removing + re-adding the output over ~2.5s, and the
#            keyboard bouncing between hyprlock's surfaces drops the blind-typed
#            password (WAYLAND_DEBUG trace, 2026-10-14). The zero-output gap left
#            is just the ~0.6s until DP-3 links.
#   release  safety net after unlock (lock-crt-sleep.sh): remove the anchor if
#            it's somehow still up (once a real output is back), then put each
#            screen back on the workspace it showed when the anchor went up.
set -u

ANCHOR=LOCKANCHOR
STATE=${XDG_RUNTIME_DIR:-/tmp}/lock-anchor.ws   # "<output> <active workspace id>" lines

has() { hyprctl monitors -j 2>/dev/null | jq -e "$1" >/dev/null 2>&1; }
anchored() { has "any(.[]; .name == \"$ANCHOR\")"; }
real_up() { has "any(.[]; .name != \"$ANCHOR\")"; }

wait_for() {   # wait_for <fn> <tries> — 0.2s apart
    local i
    for i in $(seq "$2"); do "$1" && return 0; sleep 0.2; done
    return 1
}

case "${1:-}" in
    ensure)
        anchored && exit 0   # already up: keep the workspaces saved when it went up
        hyprctl monitors -j 2>/dev/null | jq -r --arg a "$ANCHOR" \
            '.[] | select(.name != $a) | "\(.name) \(.activeWorkspace.id)"' > "$STATE"
        hyprctl output create headless "$ANCHOR" >/dev/null 2>&1
        wait_for anchored 15 || { logger -t lock-anchor "anchor never came up"; exit 1; }
        logger -t lock-anchor "anchor up"
        ;;
    drop)
        anchored || exit 0
        hyprctl output remove "$ANCHOR" >/dev/null 2>&1
        logger -t lock-anchor "anchor dropped for wake"
        ;;
    release)
        if anchored; then
            wait_for real_up 40 || { logger -t lock-anchor "no real output yet; keeping anchor"; exit 1; }
            hyprctl output remove "$ANCHOR" >/dev/null 2>&1
            logger -t lock-anchor "anchor released"
        fi
        [ -f "$STATE" ] || exit 0
        while read -r mon ws; do
            has "any(.[]; .name == \"$mon\")" && hyprctl dispatch "hl.dsp.focus({ workspace = \"$ws\" })" >/dev/null
        done < "$STATE"
        rm -f "$STATE"
        ;;
    *) echo "usage: lock-anchor.sh {ensure|drop|release}" >&2; exit 2 ;;
esac
