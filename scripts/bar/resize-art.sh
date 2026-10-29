#!/bin/bash
while inotifywait -e close_write /tmp/waybar-mediaplayer-art 2>/dev/null; do
    ffmpeg -y -i /tmp/waybar-mediaplayer-art \
        -vf "scale=26:26:force_original_aspect_ratio=decrease" \
        -update 1 /tmp/waybar-art-small.jpg 2>/dev/null
done
