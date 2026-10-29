#!/bin/bash
# update-deadbeef-colors.sh — stage pywal colors into DeaDBeeF's config.
#
# NOTE: while DeaDBeeF is RUNNING, the ddb_misc_pywal plugin applies the palette
# live (no restart) and this script is unnecessary. It exists only as a
# COLD-START fallback so a player launched later already shows the right colors.
# It mirrors the plugin's colour mapping exactly. Do NOT run it while the player
# is running (DeaDBeeF would overwrite the file on exit).

COLORS="$HOME/.cache/wal/colors.json"
CONFIG="$HOME/.config/deadbeef/config"

[ -f "$COLORS" ] || exit 0
[ -f "$CONFIG" ] || exit 0

# hex -> "R G B" in deadbeef's 16-bit scale (8-bit * 257)
hex_to_16bit() {
    local hex="${1#\#}"
    echo "$((16#${hex:0:2} * 257)) $((16#${hex:2:2} * 257)) $((16#${hex:4:2} * 257))"
}
# hex channel -> single 16-bit int
h16() { echo $((16#${1} * 257)); }

bg=$(jq -r '.special.background' "$COLORS"); fg=$(jq -r '.special.foreground' "$COLORS")
c0=$(jq -r '.colors.color0' "$COLORS"); c1=$(jq -r '.colors.color1' "$COLORS")
c3=$(jq -r '.colors.color3' "$COLORS"); c5=$(jq -r '.colors.color5' "$COLORS")

BG=$(hex_to_16bit "$bg"); FG=$(hex_to_16bit "$fg")
C0=$(hex_to_16bit "$c0"); C1=$(hex_to_16bit "$c1")
C3=$(hex_to_16bit "$c3"); C5=$(hex_to_16bit "$c5")

set_key() { # key, value (replaces existing line or appends)
    if grep -q "^$1 " "$CONFIG"; then
        sed -i "s/^$1 .*/$1 $2/" "$CONFIG"
    else
        echo "$1 $2" >> "$CONFIG"
    fi
}

# ---- listview ----
set_key gtkui.override_listview_colors 1
set_key gtkui.color.listview_even_row "$BG"
set_key gtkui.color.listview_odd_row "$C0"
set_key gtkui.color.listview_text "$FG"
set_key gtkui.color.listview_column_text "$FG"
set_key gtkui.color.listview_playing_text "$C3"
set_key gtkui.color.listview_group_text "$C3"
set_key gtkui.color.listview_selection "$C3"
set_key gtkui.color.listview_selected_text "$BG"
set_key gtkui.color.listview_cursor "$C3"

# ---- bar (seekbar/volume) ----
set_key gtkui.override_bar_colors 1
set_key gtkui.color.bar_background "$BG"
set_key gtkui.color.bar_foreground "$C3"

# ---- shared visualizer (oscilloscope/scope + musical spectrum) ----
set_key gtkui.vis.custom_background_color "$BG"
set_key gtkui.vis.custom_base_color "$FG"
set_key gtkui.vis.use_custom_background_color 1
set_key gtkui.vis.use_custom_base_color 1

# ---- spectrogram gradient: bg -> accents -> fg -> bg ----
set_key spectrogram.num_colors 7
set_key spectrogram.color.gradient_00 "$BG"
set_key spectrogram.color.gradient_01 "$C1"
set_key spectrogram.color.gradient_02 "$C3"
set_key spectrogram.color.gradient_03 "$C5"
set_key spectrogram.color.gradient_04 "$FG"
set_key spectrogram.color.gradient_05 "$C1"
set_key spectrogram.color.gradient_06 "$BG"

# ---- waveform seekbar (separate r/g/b 16-bit channel keys) ----
bgx="${bg#\#}"; fgx="${fg#\#}"; c3x="${c3#\#}"
set_key waveform.bg_color_r "$(h16 ${bgx:0:2})"; set_key waveform.bg_color_g "$(h16 ${bgx:2:2})"; set_key waveform.bg_color_b "$(h16 ${bgx:4:2})"
set_key waveform.fg_color_r "$(h16 ${c3x:0:2})"; set_key waveform.fg_color_g "$(h16 ${c3x:2:2})"; set_key waveform.fg_color_b "$(h16 ${c3x:4:2})"
set_key waveform.fg_rms_color_r "$(h16 ${fgx:0:2})"; set_key waveform.fg_rms_color_g "$(h16 ${fgx:2:2})"; set_key waveform.fg_rms_color_b "$(h16 ${fgx:4:2})"
set_key waveform.rlr_color_r "$(h16 ${c3x:0:2})"; set_key waveform.rlr_color_g "$(h16 ${c3x:2:2})"; set_key waveform.rlr_color_b "$(h16 ${c3x:4:2})"

echo "DeaDBeeF cold-start colors staged"
