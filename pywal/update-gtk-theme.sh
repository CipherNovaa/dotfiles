#!/bin/bash
# update-gtk-theme.sh — regenerates oomox GTK theme from pywal colors

COLORS="$HOME/.cache/wal/colors.json"
[ -f "$COLORS" ] || exit 0

bash ~/oomox-gtk-theme/change_color.sh -o wal-theme <(python3 -c "
import json
with open('$COLORS') as f:
    c = json.load(f)
colors = c['colors']
special = c['special']
bg = special['background'][1:]
fg = special['foreground'][1:]
c1 = colors['color1'][1:]
c3 = colors['color3'][1:]
print('BG=' + bg)
print('FG=' + fg)
print('HDR_BG=' + bg)
print('HDR_FG=' + fg)
print('TXT_BG=' + bg)
print('TXT_FG=' + fg)
print('SEL_BG=' + c3)
print('SEL_FG=' + fg)
print('BTN_BG=' + c1)
print('BTN_FG=' + fg)
print('ROUNDNESS=4')
print('GRADIENT=0.0')
") 2>/dev/null

# Force GTK to reload theme
gsettings set org.gnome.desktop.interface gtk-theme 'FlatColor' 2>/dev/null
sleep 0.1
gsettings set org.gnome.desktop.interface gtk-theme 'wal-theme' 2>/dev/null
