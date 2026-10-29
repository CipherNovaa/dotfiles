#!/bin/bash
# wallpaper-picker.sh — awww + rofi wallpaper picker for Hyprland

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
THUMB_DIR="$HOME/.cache/wallpaper-thumbs"
CACHE_MAIN="$HOME/.cache/wal/current-main"
CACHE_CRT="$HOME/.cache/wal/current-crt"
CACHE_SD="$HOME/.cache/wal/current-streamdeck"

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
    listview { columns: 1; lines: 5; spacing: 4px; padding: 8px; }
    element { padding: 10px 12px; border-radius: 8px; }
'

# ── Helpers ───────────────────────────────────────────────────────────────────
SD_PY="$HOME/.local/share/streamdeck-venv/bin/python"
launch_streamdeck() {
  [ -x "$SD_PY" ] || return 0
  # Remember the deck-specific choice so launch-wallpaper.sh restores *this* on
  # reboot instead of falling back to the main display wallpaper.
  echo "$1" >"$CACHE_SD"
  # Detached + single-instance (the script replaces any running copy itself)
  setsid "$SD_PY" ~/scripts/system/streamdeck-wallpaper.py "$1" >/dev/null 2>&1 &
}

launch_main() {
  awww img "$1" --outputs DP-3 --transition-type grow --transition-pos center --transition-duration 1 --resize stretch
  echo "$1" >"$CACHE_MAIN"
  ~/scripts/system/update-hyprlock-bg.sh &
  # NOTE: stream deck is intentionally NOT mirrored here — it stays isolated to
  # the explicit "Stream Deck" menu option only.
}

launch_crt() {
  awww img "$1" --outputs HDMI-A-1 --transition-type grow --transition-pos center --transition-duration 1 --resize stretch
  echo "$1" >"$CACHE_CRT"
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
  # userChrome. Regenerate that from the new palette; applies on Zen's next launch.
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
  # LIVE while it runs (like DeaDBeeF). If Godot is closed, stage the palette into
  # editor settings so the next launch is already themed.
  ~/scripts/system/update-godot-colors.sh &
  ~/scripts/system/update-starship-colors.sh
  # Blender: regenerate the "Pywal Theme" interface-theme preset from the new
  # palette (backgrounded — blenderwal.py shells out to `blender --version`,
  # which is slow). Staged for next launch: pick Preferences > Themes > Pywal
  # Theme once and Blender's UI follows the wallpaper from then on.
  python3 ~/scripts/blenderwal.py >/dev/null 2>&1 &
  # DeaDBeeF: the ddb_misc_pywal plugin inotify-watches ~/.cache/wal/colors.json
  # and re-themes the player LIVE (listview, oscilloscope, musical spectrum,
  # spectrogram, waveform — fg+bg) with no restart. Nothing to do while it runs.
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
  # Update Hyprland border color from pywal
  cat ~/.cache/wal/sequences
  cp ~/.cache/wal/colors-rofi-dark.rasi ~/.config/rofi/colors.rasi 2>/dev/null
  ~/scripts/system/gen-btop-theme.sh >/dev/null 2>&1
  ~/scripts/system/gen-btop-theme.sh >/dev/null 2>&1
  pkill -USR2 btop 2>/dev/null || true
  # dunst is dead code (Quickshell is the notification daemon) — launching it here
  # stole org.freedesktop.Notifications from Quickshell on every wallpaper change.
  pkill waybar 2>/dev/null
  sleep 0.2
  waybar &
  # The reload re-runs hyprland.lua, which reads colors.json and sets the active
  # border gradient itself (`hyprctl keyword` is dead on the Lua build).
  hyprctl reload >/dev/null 2>&1
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
  "Main Display\nCRT Display\nBoth Displays\nColors Only\nStream Deck" |
  rofi \
    -dmenu \
    -no-custom \
    -p "Apply to:" \
    -theme-str "$ACTION_THEME")

[[ -z "$action" ]] && exit 0

case "$action" in
"Main Display")
  launch_main "$SELECTED"
  apply_colors_from "$SELECTED_THUMB"
  ;;
"CRT Display")
  launch_crt "$SELECTED"
  apply_colors_from "$SELECTED_THUMB"
  ;;
"Both Displays")
  launch_main "$SELECTED"
  launch_crt "$SELECTED"
  apply_colors_from "$SELECTED_THUMB"
  ;;
"Colors Only")
  apply_colors_from "$SELECTED_THUMB"
  ;;
"Stream Deck")
  launch_streamdeck "$SELECTED"
  ;;
esac
