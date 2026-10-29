#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Brutal Doom v22 launcher — solo + online + private-server, on the CRT.
#
# A rofi popup picks the mode. The actual game (GZDoom for solo, Zandronum for
# multiplayer) is forced onto the NEC CRT (HDMI-A-1 / workspace 11) by the
# window rules in hyprland.lua. The CRT is held at its native 1280x1024 (5:4)
# so the image fills the whole tube; if another app left it at a 4:3 mode, the
# launcher forces it back, then leaves it at 5:4 on exit.
# ─────────────────────────────────────────────────────────────────────────────
set -u

# ── Paths ───────────────────────────────────────────────────────────────────
# Bring your own files: the Brutal Doom pk3 (from ModDB) and the IWADs from your
# own copy of Doom / Doom II (e.g. the Steam release). Nothing is shipped here.
MOD="${BRUTAL_DOOM_PK3:-$HOME/games/brutal-doom/brutal22test6.pk3}"
IWAD_DIR="${DOOM_IWAD_DIR:-$HOME/games/doom-wads}"
DOOM1="$IWAD_DIR/DOOM.WAD"
DOOM2="$IWAD_DIR/DOOM2.WAD"

# ── CRT resolution handling ─────────────────────────────────────────────────
# The NEC XV17+ is a 5:4 tube; its native 1280x1024 fills the whole screen.
# Keep it there (don't drop to a 4:3 mode — that letterboxes the tube).
CRT_OUT="HDMI-A-1"
CRT_GAME_MODE="1280x1024@75"    # native 5:4 — fills the CRT fully
CRT_DESKTOP_MODE="1280x1024@75" # restore on exit (same; switch is a no-op safety)
CRT_W=1280
CRT_H=1024

# ── Multiplayer defaults ────────────────────────────────────────────────────
ZAN_PORT=10666
HOSTNAME_TAG="$(whoami)'s Brutal Doom"

notify() { command -v notify-send >/dev/null && notify-send -i applications-games "Brutal Doom" "$1"; echo "[brutal-doom] $1"; }

have() { command -v "$1" >/dev/null 2>&1; }

# Pick a rofi command consistent with the rest of the system.
menu() { rofi -dmenu -i -p "Brutal Doom" -theme-str 'window {width: 480px;}'; }
input() { rofi -dmenu -p "$1" -theme-str 'window {width: 480px;}'; }

crt_game()    { wlr-randr --output "$CRT_OUT" --mode "$CRT_GAME_MODE"    >/dev/null 2>&1; sleep 0.5; }
crt_restore() { wlr-randr --output "$CRT_OUT" --mode "$CRT_DESKTOP_MODE" >/dev/null 2>&1; }

# run_on_crt <cmd...> : force CRT to native 5:4, run, restore afterwards.
run_on_crt() {
  crt_game
  trap crt_restore EXIT INT TERM
  "$@"
  crt_restore
  trap - EXIT INT TERM
}

# ── Preflight ───────────────────────────────────────────────────────────────
if [[ ! -f "$MOD" ]]; then
  notify "Mod not found: $MOD"; exit 1
fi
if [[ ! -e "$DOOM2" || ! -e "$DOOM1" ]]; then
  notify "Doom WADs missing in $IWAD_DIR"; exit 1
fi

# ── Game-mode wrapper (max performance, if available) ───────────────────────
GAMEMODE=()
have gamemoderun && GAMEMODE=(gamemoderun)

# ── Launch helpers ──────────────────────────────────────────────────────────
solo() { # solo <iwad>
  if ! have gzdoom; then notify "GZDoom not installed — run the install command first."; exit 1; fi
  run_on_crt "${GAMEMODE[@]}" gzdoom -iwad "$1" -file "$MOD" \
    +vid_fullscreen 1 +vid_aspect 5 -width "$CRT_W" -height "$CRT_H"
}

browse_online() {
  if ! have doomseeker; then notify "Doomseeker not installed — run the install command first."; exit 1; fi
  if ! have zandronum; then notify "Zandronum not installed — run the install command first."; exit 1; fi
  # Doomseeker shows the server browser on the main monitor; when you join a
  # server it spawns Zandronum, which the window rules push to the CRT.
  run_on_crt doomseeker
}

host_private() { # host_private <iwad>
  if ! have zandronum; then notify "Zandronum not installed — run the install command first."; exit 1; fi
  local ip; ip="$(curl -s --max-time 4 https://api.ipify.org || echo '???')"
  notify "Hosting on  $ip:$ZAN_PORT  (UDP). Forward UDP $ZAN_PORT to this PC and give your friend that address. They need the same $(basename "$MOD")."
  run_on_crt "${GAMEMODE[@]}" zandronum -iwad "$1" -file "$MOD" \
    -host -port "$ZAN_PORT" \
    +sv_hostname "$HOSTNAME_TAG" \
    +cooperative 1 +sv_maxplayers 8 +sv_maxclients 8 \
    +skill 4 +map MAP01 \
    +sv_updatemaster 0 \
    +vid_fullscreen 1 -width "$CRT_W" -height "$CRT_H"
}

join_ip() {
  if ! have zandronum; then notify "Zandronum not installed — run the install command first."; exit 1; fi
  local target; target="$(input 'Friend IP (or IP:port)')"
  [[ -z "$target" ]] && exit 0
  [[ "$target" == *:* ]] || target="$target:$ZAN_PORT"
  run_on_crt "${GAMEMODE[@]}" zandronum -iwad "$DOOM2" -file "$MOD" \
    -connect "$target" \
    +vid_fullscreen 1 +vid_aspect 5 -width "$CRT_W" -height "$CRT_H"
}

# ── Menu ────────────────────────────────────────────────────────────────────
CHOICE="$(printf '%s\n' \
  " Solo — Doom II" \
  " Solo — Ultimate Doom" \
  " Online — browse servers" \
  " Host private co-op (Doom II)" \
  " Join a friend by IP" | menu)"

case "$CHOICE" in
  *"Solo — Doom II"*)        solo "$DOOM2" ;;
  *"Solo — Ultimate Doom"*)  solo "$DOOM1" ;;
  *"browse servers"*)        browse_online ;;
  *"Host private"*)          host_private "$DOOM2" ;;
  *"Join a friend"*)         join_ip ;;
  *) exit 0 ;;
esac
