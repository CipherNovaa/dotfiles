#!/bin/bash
pkill -f "spicetify watch" 2>/dev/null
sleep 0.2
spicetify watch -s &
sleep 0.5
spotify-launcher &
