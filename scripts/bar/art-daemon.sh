#!/bin/bash
# art-daemon.sh — album art updater with YouTube support

CACHE="$HOME/.cache/bar_art.jpg"
LAST_URL="$HOME/.cache/bar_art_last_url"

# Clear on start if nothing playing
if ! playerctl status 2>/dev/null | grep -q "Playing\|Paused"; then
    rm -f "$CACHE"
fi

update_art() {
    local url="$1"
    [ -z "$url" ] && return

    if [[ "$url" == spotify:image:* ]]; then
        url="https://i.scdn.co/image/${url#spotify:image:}"
    fi

    local last=$(cat "$LAST_URL" 2>/dev/null)
    [ "$url" = "$last" ] && return

    if [[ "$url" == file://* ]]; then
        ffmpeg -y -i "${url#file://}" -an -vframes 1 -update 1 "$CACHE" &>/dev/null && echo "$url" > "$LAST_URL"
    elif [[ "$url" == http* ]] && [[ "$url" != *youtube* ]] && [[ "$url" != *youtu.be* ]]; then
        curl -s "$url" | ffmpeg -y -i pipe:0 -an -vframes 1 -update 1 "$CACHE" &>/dev/null && echo "$url" > "$LAST_URL"
    elif [[ "$url" == *"youtube.com"* ]] || [[ "$url" == *"youtu.be"* ]]; then
        local vid_id=$(echo "$url" | grep -oP '(?<=v=)[^&]+' | head -1)
        [ -z "$vid_id" ] && vid_id=$(echo "$url" | grep -oP '(?<=youtu.be/)[^?]+' | head -1)
        if [[ -n "$vid_id" ]]; then
            curl -s "https://img.youtube.com/vi/$vid_id/mqdefault.jpg" | \
                ffmpeg -y -i pipe:0 -vf "scale=26:26" -update 1 "$CACHE" &>/dev/null && echo "$url" > "$LAST_URL"
        fi
    fi
}

# Watch non-firefox players for artUrl changes
playerctl --player=DeaDBeeF,spotify --follow metadata mpris:artUrl 2>/dev/null | while read -r url; do
    if [ -z "$url" ]; then
        rm -f "$CACHE" "$LAST_URL"
    else
        update_art "$url"
    fi
done &

# Poll Firefox separately for YouTube URLs
while true; do
    firefox_url=$(playerctl --player=firefox metadata xesam:url 2>/dev/null)
    if [[ -n "$firefox_url" ]] && [[ "$firefox_url" == *youtube* ]]; then
        update_art "$firefox_url"
    elif [[ -z "$firefox_url" ]]; then
        # Firefox not playing — check if any player is active
        if ! playerctl status 2>/dev/null | grep -q "Playing\|Paused"; then
            rm -f "$CACHE"
        fi
    fi
    sleep 3
done
