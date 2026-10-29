#!/bin/bash
# audio-loopback.sh — mirror the Arctis (headset) audio to the monitor's audio
# output (pro-output-7) so the external hardware visualizer on that output sees
# the music.
#
# Uses pipewire-pulse `module-loopback` rather than the standalone `pw-loopback`
# binary: module-loopback routes strictly by source/sink *name*, so it captures
# the real stereo headset monitor instead of getting hijacked onto the Arctis
# *microphone* (which is what bare `pw-loopback -C <sink>` does). It also lives
# inside the daemon, so it survives independently of whatever launched it.
#
# Robust against late device init (the Arctis is wireless) and safe to re-run
# (it unloads any loopback it previously pointed at this output first).

# The per-output pro-output-* sinks only exist when the Nvidia HDMI card is in
# the pro-audio profile.
pactl set-card-profile alsa_card.pci-0000_01_00.1 pro-audio 2>/dev/null

# Wait (up to ~30s) for both endpoints, resolved by stable node *name*.
#   capture: the Arctis sink's stereo *.monitor SOURCE* (what's playing on the
#            headset) — NOT the sink and NOT the mono mic.
#   playback: the monitor's pro-output-7 SINK.
ARCTIS_MON=""
MONITOR=""
for _ in $(seq 1 30); do
    ARCTIS_MON=$(pactl list sources short | awk '/Arctis.*\.monitor/{print $2; exit}')
    MONITOR=$(pactl list sinks short | awk '/pro-output-7/{print $2; exit}')
    [ -n "$ARCTIS_MON" ] && [ -n "$MONITOR" ] && break
    sleep 1
done

if [ -z "$ARCTIS_MON" ] || [ -z "$MONITOR" ]; then
    echo "audio-loopback: endpoint not found (arctis_mon='$ARCTIS_MON' monitor='$MONITOR')" >&2
    exit 1
fi

# Drop any loopback a previous run pointed at this output, so re-runs don't stack.
pactl list modules short \
    | awk -F'\t' '$2=="module-loopback" && $3 ~ /pro-output-7/ {print $1}' \
    | xargs -r -n1 pactl unload-module 2>/dev/null

# Route the Arctis monitor -> monitor output. *_dont_move pins the endpoints so
# the session manager can't reroute them onto a default device.
pactl load-module module-loopback \
    source="$ARCTIS_MON" \
    sink="$MONITOR" \
    source_dont_move=true \
    sink_dont_move=true \
    latency_msec=60 >/dev/null
