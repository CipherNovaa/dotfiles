#!/usr/bin/env bash
# Install the zen-pywal live-theme watcher into Zen's application directory.
#
# userChrome.css is only read at browser startup, so without this a wallpaper change
# only reaches Zen on its next launch. This drops an autoconfig script into the app dir
# which polls the profile's chrome/zen-pywal.css and re-registers it live.
#
# Needs root: the app dir is package-owned (zen-browser-bin). The two files we add are
# NOT tracked by pacman, so they survive `yay -Syu`; re-run this only if a Zen update
# ever removes them or the watcher source changes.
#
#   sudo ~/scripts/system/zen-pywal-autoconfig-install.sh [--uninstall]
set -euo pipefail

SRC="${SRC:-$(dirname "$(readlink -f "$0")")/zen-pywal-autoconfig.js}"
APP_DIR="${APP_DIR:-/opt/zen-browser-bin}"
CONFIG_NAME="zen-pywal-config.js"
PREF_FILE="$APP_DIR/defaults/pref/zen-pywal-prefs.js"
CONFIG_FILE="$APP_DIR/$CONFIG_NAME"

if [ "$(id -u)" -ne 0 ]; then
  echo "error: must run as root (the app dir is package-owned) — try:" >&2
  echo "  sudo $0 $*" >&2
  exit 1
fi

if [ ! -d "$APP_DIR" ]; then
  echo "error: Zen app dir not found at $APP_DIR" >&2
  echo "       (expected the zen-browser-bin package; set APP_DIR= to override)" >&2
  exit 1
fi

if [ "${1:-}" = "--uninstall" ]; then
  rm -f "$PREF_FILE" "$CONFIG_FILE"
  echo "removed $PREF_FILE"
  echo "removed $CONFIG_FILE"
  echo "done — restart Zen. userChrome.css still themes it at startup (no live reload)."
  exit 0
fi

[ -f "$SRC" ] || { echo "error: watcher source not found: $SRC" >&2; exit 1; }

# defaults/pref/*.js are read as default prefs at startup; this is what points the
# autoconfig loader at our script. sandbox_enabled=false is required for the script to
# reach Services/file APIs. obscure_value=0 means the file is plain (not byte-shifted).
install -Dm644 /dev/stdin "$PREF_FILE" <<EOF
// Installed by ~/scripts/system/zen-pywal-autoconfig-install.sh — points Zen's
// autoconfig loader at $CONFIG_NAME (the pywal live-theme watcher).
pref("general.config.filename", "$CONFIG_NAME");
pref("general.config.obscure_value", 0);
pref("general.config.sandbox_enabled", false);
EOF
echo "wrote $PREF_FILE"

install -Dm644 "$SRC" "$CONFIG_FILE"
echo "wrote $CONFIG_FILE"

echo
echo "installed. Restart Zen once to load the watcher; after that, wallpaper changes"
echo "re-theme Zen live (it polls <profile>/chrome/zen-pywal.css)."
