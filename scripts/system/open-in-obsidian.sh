#!/bin/bash
# open-in-obsidian.sh — open a file in Obsidian by ABSOLUTE PATH, which makes
# Obsidian jump to that note in whichever vault contains it.
# NOTE: Obsidian is vault-only. A file that isn't inside any registered vault
# cannot be opened here (Obsidian has no standalone/loose-file window) — use
# nvim/glow for those. Called by obsidian-file.desktop with %f (a single path).
[ -z "$1" ] && exit 0
f=$(realpath -- "$1" 2>/dev/null) || exit 0
enc=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$f")
exec "${OBSIDIAN_BIN:-obsidian}" \
     --ozone-platform=x11 --ozone-platform-hint=auto "obsidian://open?path=$enc"
