#!/bin/bash
sleep 0.3  # let playerctl update metadata after skip

TITLE=$(playerctl metadata title 2>/dev/null)
ARTIST=$(playerctl metadata artist 2>/dev/null)
ART_URL=$(playerctl metadata mpris:artUrl 2>/dev/null)

[[ -z "$TITLE" ]] && exit 0

# Handle local vs remote art
if [[ "$ART_URL" == file://* ]]; then
    ART="${ART_URL#file://}"
elif [[ -n "$ART_URL" ]]; then
    ART="/tmp/dunst-nowplaying-art.jpg"
    curl -s "$ART_URL" -o "$ART"
fi

notify-send \
    -i "$ART" \
    -t 3000 \
    -h string:x-dunst-stack-tag:nowplaying \
    -u low \
    "Now Playing" \
    "<b>$TITLE</b>\n$ARTIST"
