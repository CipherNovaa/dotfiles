#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"
qs_ensure_cache "music"

STATE_FILE="$QS_RUN_MUSIC/eq_state.json"

# Default state (Now includes "pending": false)
if [ ! -f "$STATE_FILE" ]; then
    echo '{"b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0, "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0, "preset": "Flat", "pending": false, "enabled": true}' > "$STATE_FILE"
fi

apply_eq() {
    # Was: write an EasyEffects preset JSON + `easyeffects -l`. EasyEffects had to
    # be removed from the audio path -- as a service it always attaches itself to
    # the DEFAULT sink, so once the binaural surround sink became the default they
    # fed into each other and audio died. The EQ now lives as 10 peaking filters
    # at the end of the surround filter-chain, and this pushes the slider values
    # straight into it at runtime (no restart, no gap in playback).
    # surround_eq.py comes from github.com/CipherNovaa/pipewire-surround; without
    # it the sliders still save their state but change nothing.
    "$HOME/scripts/surround_eq.py" apply >/dev/null 2>&1 &
}

# Save state helper (Always sets pending to false because Presets apply instantly)
save_preset() {
    jq -n -c --arg b1 "$1" --arg b2 "$2" --arg b3 "$3" --arg b4 "$4" --arg b5 "$5" \
          --arg b6 "$6" --arg b7 "$7" --arg b8 "$8" --arg b9 "$9" --arg b10 "${10}" --arg p "${11}" \
       '{"b1": $b1, "b2": $b2, "b3": $b3, "b4": $b4, "b5": $b5, "b6": $b6, "b7": $b7, "b8": $b8, "b9": $b9, "b10": $b10, "preset": $p, "pending": false}' > "$STATE_FILE"
}

cmd=$1
arg1=$2
arg2=$3

case $cmd in
    "get")
        # Older state files predate the on/off toggle; default it to on.
        tmp=$(cat "$STATE_FILE")
        if ! echo "$tmp" | jq -e 'has("enabled")' >/dev/null 2>&1; then
            tmp=$(echo "$tmp" | jq -c '.enabled = true'); echo "$tmp" > "$STATE_FILE"
        fi
        echo "$tmp"
        ;;
    "toggle")
        # Flip the EQ in or out of circuit, keeping the slider values intact.
        tmp=$(cat "$STATE_FILE")
        # NB: do NOT use `.enabled // true` here -- jq's `//` treats `false` as
        # absent, so it reads back true when the EQ is off and the toggle sticks.
        updated=$(echo "$tmp" | jq -c '.enabled = ((.enabled != false) | not)')
        echo "$updated" > "$STATE_FILE"
        apply_eq
        ;;
    "set_band")
        # SLIDER MOVE: Set pending = true, Preset = Custom. DO NOT APPLY.
        tmp=$(cat "$STATE_FILE")
        updated=$(echo "$tmp" | jq -c --arg val "$arg2" ".b$arg1 = \$val | .preset = \"Custom\" | .pending = true")
        echo "$updated" > "$STATE_FILE"
        ;;
    "apply")
        # APPLY BUTTON: Set pending = false, then Apply.
        tmp=$(cat "$STATE_FILE")
        updated=$(echo "$tmp" | jq -c ".pending = false")
        echo "$updated" > "$STATE_FILE"
        apply_eq
        ;;
    "preset")
        # PRESET CLICK: Save values (pending=false) and Apply Instantly.
        case $arg1 in
            "Flat")    save_preset 0 0 0 0 0 0 0 0 0 0 "Flat" ;;
            "Bass")    save_preset 5 7 5 2 1 0 0 0 1 2 "Bass" ;;
            "Treble")  save_preset -2 -1 0 1 2 3 4 5 6 6 "Treble" ;;
            "Vocal")   save_preset -2 -1 1 3 5 5 4 2 1 0 "Vocal" ;;
            "Pop")     save_preset 2 4 2 0 1 2 4 2 1 2 "Pop" ;;
            "Rock")    save_preset 5 4 2 -1 -2 -1 2 4 5 6 "Rock" ;;
            "Jazz")    save_preset 3 3 1 1 1 1 2 1 2 3 "Jazz" ;;
            "Classic") save_preset 0 1 2 2 2 2 1 2 3 4 "Classic" ;;
        esac
        apply_eq
        ;;
esac
