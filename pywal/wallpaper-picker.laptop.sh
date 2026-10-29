#!/bin/bash
# wallpaper-picker.laptop.sh — awww + rofi wallpaper picker for Hyprland (laptop)
#
# Single-screen / laptop variant of wallpaper-picker.sh. The desktop version hard-codes DP-3 (main) + HDMI-A-1 (CRT) and has a Stream Deck; this
# box has neither. Outputs are discovered at runtime from `awww query` (the same
# way ~/scripts/system/launch-wallpaper.sh does it) so the internal panel (eDP-1)
# and any hot-plugged external display (TV over USB-C / HDMI, e.g. DP-2) both get
# painted without hard-coding names.

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
THUMB_DIR="$HOME/.cache/wallpaper-thumbs"
CACHE_MAIN="$HOME/.cache/wal/current-main"

mkdir -p "$THUMB_DIR"
mkdir -p "$(dirname "$CACHE_MAIN")"

# ── Ensure the awww daemon is alive ───────────────────────────────────────────
# It has no supervisor, so if it ever dies mid-session `awww img` fails with
# "socket not found" and the wallpaper silently never changes. Revive it here.
if ! awww query >/dev/null 2>&1; then
  setsid awww-daemon >/dev/null 2>&1 </dev/null & disown
  for _ in $(seq 1 20); do awww query >/dev/null 2>&1 && break; sleep 0.1; done
fi

# ── Thumbnail generation ──────────────────────────────────────────────────────
for f in "$WALLPAPER_DIR"/*.{gif,png,jpg,jpeg,webp,webm}; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  thumb="$THUMB_DIR/${name%.*}.png"
  if [[ ! -f "$thumb" ]]; then
    ffmpeg -y -i "$f" -vframes 1 -vf "scale=200:200:force_original_aspect_ratio=decrease" "$thumb" 2>/dev/null
  fi
done

# ── Rofi themes ───────────────────────────────────────────────────────────────
GRID_THEME='
    window {
        width: 900px;
        border-radius: 12px;
    }
    inputbar {
        padding: 12px;
        border-radius: 8px;
    }
    listview {
        columns: 4;
        lines: 3;
        spacing: 8px;
        padding: 8px;
    }
    element {
        orientation: vertical;
        border-radius: 8px;
        padding: 6px;
    }
    element-icon {
        size: 160px;
        border-radius: 6px;
    }
    element-text {
        horizontal-align: 0.5;
        padding: 4px 0 0 0;
    }
'

ACTION_THEME='
    window { width: 340px; border-radius: 12px; }
    inputbar { enabled: false; }
    listview { columns: 1; lines: 2; spacing: 4px; padding: 8px; }
    element { padding: 10px 12px; border-radius: 8px; }
'

# ── Helpers ───────────────────────────────────────────────────────────────────
launch_main() {
  # Paint every connected output. Names vary (eDP-1 internal, DP-2/HDMI-A-1 when
  # a TV is plugged in), so ask awww rather than hard-coding — same discovery the
  # laptop's launch-wallpaper.sh uses.
  local outputs o
  outputs=$(awww query 2>/dev/null | sed -n 's/^[: ]*\([A-Za-z0-9-]\+\):.*/\1/p')
  for o in $outputs; do
    awww img "$1" --outputs "$o" --transition-type grow --transition-pos center --transition-duration 1 --resize stretch
  done
  echo "$1" >"$CACHE_MAIN"
  ~/scripts/system/update-hyprlock-bg.sh &
}

apply_colors_from() {
  local thumb="$1"
  wal -i "$thumb" -n -q
  # Reload running kitty windows — they include the symlinked pywal colors,
  # but kitty only re-reads its config on SIGUSR1.
  pkill -USR1 -x kitty 2>/dev/null || true
  bash ~/scripts/system/update-gtk-theme.sh &
  pywalfox update 2>/dev/null &
  # Zen Browser: Zen ignores the Firefox theme API (pywalfox has no visible
  # effect on its custom chrome), so theme it via its own CSS variables in
  # userChrome. The autoconfig watcher in Zen's app dir picks the file up live.
  python3 ~/scripts/system/zen-pywal.py 2>/dev/null &
  # Firefox: copy rendered chrome CSS + update display color pref so the window
  # and pages never flash white before pywalfox's theme loads.
  # Firefox profile: set FF_PROFILE, else the first *.default-release found.
  FF_PROFILE="${FF_PROFILE:-$(ls -d "$HOME"/.mozilla/firefox/*.default-release "$HOME"/.config/mozilla/firefox/*.default-release 2>/dev/null | head -n1)}"
  if [ -d "$FF_PROFILE" ]; then
    mkdir -p "$FF_PROFILE/chrome"
    [ -f "$HOME/.cache/wal/userContent.css" ] && cp "$HOME/.cache/wal/userContent.css" "$FF_PROFILE/chrome/userContent.css"
    [ -f "$HOME/.cache/wal/userChrome.css" ]  && cp "$HOME/.cache/wal/userChrome.css"  "$FF_PROFILE/chrome/userChrome.css"
    # Update the fallback bg color pref to match the new pywal palette
    BG=$(python3 -c "import json; w=json.load(open('$HOME/.cache/wal/colors.json')); print(w['special']['background'])" 2>/dev/null)
    FG=$(python3 -c "import json; w=json.load(open('$HOME/.cache/wal/colors.json')); print(w['special']['foreground'])" 2>/dev/null)
    if [ -n "$BG" ] && [ -f "$FF_PROFILE/user.js" ]; then
      # Replace the color prefs in user.js with current pywal values
      sed -i "s|\"browser.display.background_color\", \"#[0-9a-fA-F]*\"|\"browser.display.background_color\", \"$BG\"|g" "$FF_PROFILE/user.js"
      sed -i "s|\"browser.display.foreground_color\", \"#[0-9a-fA-F]*\"|\"browser.display.foreground_color\", \"$FG\"|g" "$FF_PROFILE/user.js"
    fi
  fi
  # Discord: writes pywal-discord-default.theme.css into every detected client
  # (Vencord / Vesktop / BetterDiscord). Vencord & Vesktop hot-reload it live.
  pywal-discord -t default 2>/dev/null &
  # system24 (boxy theme) colour override — maps the pywal palette onto system24's
  # CSS variables so the boxy layout follows the wallpaper. Vesktop hot-reloads it.
  python3 ~/scripts/system/update-discord-system24.py 2>/dev/null &
  # Update yazi theme
  cp ~/.cache/wal/colors-yazi-theme.toml ~/.config/yazi/theme.toml 2>/dev/null
  # Reload nvim colorscheme in all running instances (neopywal re-reads colors.json)
  nvim --server ~/.local/state/nvim/nvim.pipe --remote-send ":colorscheme neopywal<CR>" 2>/dev/null
  # Godot: the pywal_theme addon inotify-polls colors.json and re-themes the editor
  # LIVE while it runs. If Godot is closed, stage the palette for the next launch.
  ~/scripts/system/update-godot-colors.sh &
  ~/scripts/system/update-starship-colors.sh
  # DeaDBeeF: the ddb_misc_pywal plugin inotify-watches ~/.cache/wal/colors.json
  # and re-themes the player LIVE with no restart. Nothing to do while it runs.
  # If it's not running, stage the palette into its config for next launch.
  if ! pgrep -x deadbeef-main >/dev/null; then
    bash ~/scripts/system/update-deadbeef-colors.sh 2>/dev/null
  fi
  ~/scripts/system/update-rgb.sh &
  # Lock screen colors (applied on its next launch)
  ~/scripts/system/update-hyprlock-colors.sh
  # Qt/KDE apps (Dolphin etc.) and Obsidian — both live-reload on file change
  ~/scripts/system/update-qt-colors.sh &
  ~/scripts/system/update-obsidian-colors.sh &
  ~/scripts/system/update-spicetify-colors.sh
  cat ~/.cache/wal/sequences
  cp ~/.cache/wal/colors-rofi-dark.rasi ~/.config/rofi/colors.rasi 2>/dev/null
  ~/scripts/system/gen-btop-theme.sh >/dev/null 2>&1
  pkill -USR2 btop 2>/dev/null || true
  # No dunst restart here: quickshell's NotificationServer owns
  # org.freedesktop.Notifications on this box (since 2026-06-11), so dunst can't
  # acquire the name and exits immediately. Quickshell reads colors.json via
  # FileView and re-themes live, so there's nothing to poke.
  pkill waybar 2>/dev/null
  sleep 0.2
  waybar &
  hyprctl reload >/dev/null 2>&1
  ACCENT=$(awk -F'"' '/color3/{print $4}' ~/.cache/wal/colors.json)
  ACCENT2=$(awk -F'"' '/color2/{print $4}' ~/.cache/wal/colors.json)
  hyprctl keyword general:col.active_border "rgba(${ACCENT:1}ee) rgba(${ACCENT2:1}ee) 45deg"
}

get_thumb() {
  echo "$THUMB_DIR/$(basename "${1%.*}").png"
}

# ── Step 1: Pick wallpaper ────────────────────────────────────────────────────
entries=()
for f in "$WALLPAPER_DIR"/*.{gif,png,jpg,jpeg,webp,webm}; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  thumb="$THUMB_DIR/${name%.*}.png"
  entries+=("${name}\0icon\x1f${thumb}")
done

chosen=$(printf "%b\n" "${entries[@]}" | rofi \
  -dmenu \
  -i \
  -p "Wallpaper" \
  -show-icons \
  -theme-str "$GRID_THEME")

[[ -z "$chosen" ]] && exit 0

SELECTED="$WALLPAPER_DIR/$chosen"
SELECTED_THUMB=$(get_thumb "$SELECTED")

# ── Step 2: Action menu ───────────────────────────────────────────────────────
action=$(printf \
  "Set Wallpaper\nColors Only" |
  rofi \
    -dmenu \
    -no-custom \
    -p "Apply to:" \
    -theme-str "$ACTION_THEME")

[[ -z "$action" ]] && exit 0

case "$action" in
"Set Wallpaper")
  launch_main "$SELECTED"
  apply_colors_from "$SELECTED_THUMB"
  ;;
"Colors Only")
  apply_colors_from "$SELECTED_THUMB"
  ;;
esac
