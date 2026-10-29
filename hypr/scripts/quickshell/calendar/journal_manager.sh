#!/usr/bin/env bash
# Open a day's daily note in your Obsidian vault, creating it if missing.
#   journal_manager.sh [YYYY-MM-DD]      (no arg → today)
# Wired to the quickshell calendar: the journal button opens today; clicking a day
# cell opens that day (create-on-click, like the Obsidian Calendar plugin).
#
# Configure with environment variables (e.g. in quickshell.service):
#   OBSIDIAN_VAULT           vault folder      (default ~/Documents/Obsidian Vault)
#   OBSIDIAN_JOURNAL_DIR     dailies, relative to the vault  (default Journal)
#   OBSIDIAN_DAILY_TEMPLATE  optional template file; {{date}} is replaced by the day
set -u

VAULT_DIR="${OBSIDIAN_VAULT:-$HOME/Documents/Obsidian Vault}"
VAULT_NAME="$(basename "$VAULT_DIR")"
REL="${OBSIDIAN_JOURNAL_DIR:-Journal}"
TEMPLATE="${OBSIDIAN_DAILY_TEMPLATE:-}"

# Date: arg or today; must be YYYY-MM-DD (the calendar passes ISO dates).
DATE="${1:-$(date +%F)}"
case "$DATE" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) : ;;
    *) DATE="$(date +%F)" ;;
esac

JDIR="$VAULT_DIR/$REL"
FILE="$JDIR/$DATE.md"

mkdir -p "$JDIR"
if [ ! -f "$FILE" ]; then
    if [ -n "$TEMPLATE" ] && [ -f "$TEMPLATE" ]; then
        sed "s/{{date}}/$DATE/g" "$TEMPLATE" > "$FILE"
    else
        printf -- '---\ntype: daily\ndate: %s\n---\n\n# %s\n\n' "$DATE" "$DATE" > "$FILE"
    fi
fi

enc() { python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$1"; }
xdg-open "obsidian://open?vault=$(enc "$VAULT_NAME")&file=$(enc "$REL/$DATE")" >/dev/null 2>&1 &

# Raise + focus Obsidian so clicking a day jumps you into the note (like the Calendar
# plugin). The obsidian:// URI navigates but doesn't reliably pull focus across
# workspaces/monitors, so drive it explicitly via the Hypr socket. Retry ~4s to cover
# a cold start (Obsidian not yet running → window appears a beat after the URI fires).
python3 - <<'PY' &
import socket, os, json, time
sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
xdg = os.environ.get("XDG_RUNTIME_DIR")
if sig and xdg:
    sp = f"{xdg}/hypr/{sig}/.socket.sock"
    def cmd(c):
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sp); s.sendall(c.encode())
            buf = b""
            while True:
                ch = s.recv(65536)
                if not ch: break
                buf += ch
            s.close(); return buf
        except OSError:
            return b""
    # Lua-Hyprland: the socket wraps `dispatch <x>` as `return hl.dispatch(<x>)`, so only
    # the Lua API form works. focus by class handles both the desktop AppImage and the
    # laptop's electron build (both class=obsidian).
    deadline = time.time() + 4
    while time.time() < deadline:
        if "obsidian" in (json.loads(cmd("j/activewindow") or b"{}").get("class") or "").lower():
            break
        cmd('dispatch hl.dsp.focus({ window = "class:obsidian" })')
        time.sleep(0.35)
PY
