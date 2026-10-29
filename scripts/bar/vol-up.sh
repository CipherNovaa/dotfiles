#!/bin/bash
VOL=$(pactl get-sink-volume @DEFAULT_SINK@ | awk '/Volume:/ {gsub(/%/,""); print $5}')
if [ "$VOL" -lt 100 ]; then
    pactl set-sink-volume @DEFAULT_SINK@ +5%
fi
