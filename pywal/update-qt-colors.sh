#!/bin/bash
# update-qt-colors.sh — write the pywal palette into kdeglobals + Pywal.colors
# so KDE apps (Dolphin, etc.) follow the wallpaper.

COLORS="$HOME/.cache/wal/colors.json"
KDE="$HOME/.config/kdeglobals"
SCHEME_DIR="$HOME/.local/share/color-schemes"
DOLPHINRC="$HOME/.config/dolphinrc"
QT6CT_DIR="$HOME/.config/qt6ct"
[ -f "$COLORS" ] || exit 0

python3 - "$COLORS" "$KDE" "$SCHEME_DIR" "$DOLPHINRC" "$QT6CT_DIR" <<'PY'
import sys, json, configparser, os

colors_path, kde_path, scheme_dir, dolphinrc_path, qt6ct_dir = sys.argv[1:6]
with open(colors_path) as f:
    w = json.load(f)
sp, col = w["special"], w["colors"]

def rgb(hexs):
    h = hexs.lstrip("#")
    return f"{int(h[0:2],16)},{int(h[2:4],16)},{int(h[4:6],16)}"

def dim_fg(hexs, factor=0.55):
    h = hexs.lstrip("#")
    r, g, b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
    return f"{max(0,int(r*factor))},{max(0,int(g*factor))},{max(0,int(b*factor))}"

def alt_bg(hexs):
    h = hexs.lstrip("#")
    r, g, b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
    step = 18
    return f"{min(255,r+step)},{min(255,g+step)},{min(255,b+step)}"

bg    = rgb(sp["background"])
fg    = rgb(sp["foreground"])
fg_i  = dim_fg(sp["foreground"])
view  = bg
alt   = alt_bg(sp["background"])
sel   = rgb(col["color3"])
selfg = rgb(sp["background"])
hov   = rgb(col["color4"])
link  = rgb(col["color6"])
neg   = rgb(col["color1"])
pos   = rgb(col.get("color2", col["color6"]))

def write_sections(cp_or_sc, setsec_fn):
    setsec_fn("Colors:Window",
        BackgroundNormal=bg,   ForegroundNormal=fg,
        ForegroundInactive=fg_i, ForegroundActive=sel,
        DecorationFocus=sel,   DecorationHover=hov)
    setsec_fn("Colors:View",
        BackgroundNormal=view, ForegroundNormal=fg,
        BackgroundAlternate=alt,
        ForegroundInactive=fg_i, ForegroundActive=sel,
        ForegroundNegative=neg,  ForegroundPositive=pos,
        ForegroundNeutral=hov,
        DecorationFocus=sel,   DecorationHover=hov,
        ForegroundLink=link,   ForegroundVisited=link)
    # Colors:Header is used by Dolphin's toolbar/navigation bar — without it the
    # text can fall back to a dark default and become unreadable on dark backgrounds.
    setsec_fn("Colors:Header",
        BackgroundNormal=bg,   ForegroundNormal=fg,
        BackgroundAlternate=alt,
        ForegroundInactive=fg_i, ForegroundActive=sel,
        DecorationFocus=sel,   DecorationHover=hov)
    setsec_fn("Colors:Button",
        BackgroundNormal=view, ForegroundNormal=fg,
        ForegroundInactive=fg_i,
        DecorationFocus=sel,   DecorationHover=hov)
    setsec_fn("Colors:Selection",
        BackgroundNormal=sel,  ForegroundNormal=selfg,
        ForegroundInactive=fg_i,
        DecorationFocus=sel,   DecorationHover=hov)
    setsec_fn("Colors:Tooltip",
        BackgroundNormal=view, ForegroundNormal=fg)
    setsec_fn("Colors:Complementary",
        BackgroundNormal=bg, ForegroundNormal=fg, ForegroundInactive=fg_i)

# ── kdeglobals ──────────────────────────────────────────────────────────────
cp = configparser.ConfigParser()
cp.optionxform = str
if os.path.exists(kde_path):
    cp.read(kde_path)

def cp_set(name, **kv):
    if not cp.has_section(name):
        cp.add_section(name)
    for k, v in kv.items():
        cp.set(name, k, v)

write_sections(cp, cp_set)

if not cp.has_section("General"):
    cp.add_section("General")
cp.set("General", "ColorScheme", "Pywal")

with open(kde_path, "w") as f:
    cp.write(f, space_around_delimiters=False)

# ── ~/.local/share/color-schemes/Pywal.colors ──────────────────────────────
os.makedirs(scheme_dir, exist_ok=True)
sc = configparser.ConfigParser()
sc.optionxform = str

def sc_set(name, **kv):
    if not sc.has_section(name):
        sc.add_section(name)
    for k, v in kv.items():
        sc.set(name, k, v)

sc_set("ColorEffects:Disabled", Enable="false")
sc_set("ColorEffects:Inactive", Enable="false")
write_sections(sc, sc_set)

sc.add_section("General")
sc.set("General", "Name",            "Pywal")
sc.set("General", "ColorScheme",     "Pywal")
sc.set("General", "shadeSortColumn", "true")

with open(os.path.join(scheme_dir, "Pywal.colors"), "w") as f:
    sc.write(f, space_around_delimiters=False)

# ── dolphinrc ───────────────────────────────────────────────────────────────
dc = configparser.ConfigParser()
dc.optionxform = str
if os.path.exists(dolphinrc_path):
    dc.read(dolphinrc_path)
for sec in ("UiSettings", "General"):
    if not dc.has_section(sec):
        dc.add_section(sec)
    dc.set(sec, "ColorScheme", "Pywal")
with open(dolphinrc_path, "w") as f:
    dc.write(f, space_around_delimiters=False)

# ── qt6ct ───────────────────────────────────────────────────────────────────
# This is what actually makes Qt apps (Dolphin's file list, PCSX2, DuckStation)
# use the palette. Without a QPA platform theme the app-wide QPalette is never
# built, so only KColorScheme-aware chrome got themed while the QTreeView kept
# Qt's default light palette (white rows, dark/invisible text). qt6ct sets the
# full QPalette for every Qt6 app via QT_QPA_PLATFORMTHEME=qt6ct.
def _rgb_tuple(hexs):
    h = hexs.lstrip("#")
    return int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)

def argb(hexs):
    r, g, b = _rgb_tuple(hexs)
    return f"#ff{r:02x}{g:02x}{b:02x}"

def shift(hexs, d):
    r, g, b = _rgb_tuple(hexs)
    f = lambda v: max(0, min(255, v + d))
    return f"#ff{f(r):02x}{f(g):02x}{f(b):02x}"

bg_h   = sp["background"]
fg_h   = sp["foreground"]
sel_h  = col["color3"]
link_h = col["color6"]
alt_h  = "#%02x%02x%02x" % tuple(min(255, c+18) for c in _rgb_tuple(bg_h))
dim_h  = "#%02x%02x%02x" % tuple(int(c*0.55) for c in _rgb_tuple(fg_h))

# QPalette::ColorRole order as qt6ct serializes (indices 0..21).
roles = [
    argb(fg_h),        # 0  WindowText
    argb(bg_h),        # 1  Button
    shift(bg_h,  45),  # 2  Light
    shift(bg_h,  25),  # 3  Midlight
    shift(bg_h, -25),  # 4  Dark
    shift(bg_h, -12),  # 5  Mid
    argb(fg_h),        # 6  Text
    "#ffffffff",       # 7  BrightText
    argb(fg_h),        # 8  ButtonText
    argb(bg_h),        # 9  Base
    argb(bg_h),        # 10 Window
    "#ff000000",       # 11 Shadow
    argb(sel_h),       # 12 Highlight
    argb(bg_h),        # 13 HighlightedText
    argb(link_h),      # 14 Link
    argb(link_h),      # 15 LinkVisited
    argb(alt_h),       # 16 AlternateBase
    "#ff000000",       # 17 NoRole
    argb(bg_h),        # 18 ToolTipBase
    argb(fg_h),        # 19 ToolTipText
    argb(dim_h),       # 20 PlaceholderText
    argb(sel_h),       # 21 Accent
]
# disabled state: dim the text roles, keep structure
disabled = list(roles)
for i in (0, 6, 8, 19):
    disabled[i] = argb(dim_h)

os.makedirs(os.path.join(qt6ct_dir, "colors"), exist_ok=True)
scheme_file = os.path.join(qt6ct_dir, "colors", "Pywal.conf")
csc = configparser.ConfigParser()
csc.optionxform = str
csc.add_section("ColorScheme")
csc.set("ColorScheme", "active_colors",   ", ".join(roles))
csc.set("ColorScheme", "inactive_colors", ", ".join(roles))
csc.set("ColorScheme", "disabled_colors", ", ".join(disabled))
with open(scheme_file, "w") as f:
    csc.write(f, space_around_delimiters=False)

# qt6ct.conf — merge into any existing config, only touching the keys we own.
qc = configparser.ConfigParser()
qc.optionxform = str
qc_path = os.path.join(qt6ct_dir, "qt6ct.conf")
if os.path.exists(qc_path):
    qc.read(qc_path)
if not qc.has_section("Appearance"):
    qc.add_section("Appearance")
qc.set("Appearance", "style", "Breeze")
qc.set("Appearance", "color_scheme_path", scheme_file)
qc.set("Appearance", "custom_palette", "true")
with open(qc_path, "w") as f:
    qc.write(f, space_around_delimiters=False)
PY

# Broadcast KDE palette-change signal so running KDE apps reload their colors.
# Syntax: int32:VALUE (colon required — bare "int32 0" is silently malformed).
if command -v dbus-send >/dev/null 2>&1; then
  dbus-send --session --type=signal /KGlobalSettings \
    org.kde.KGlobalSettings.notifyChange int32:0 int32:0 2>/dev/null || true
fi

# Note: Dolphin is intentionally NOT killed/relaunched here. The qt6ct scheme is
# regenerated above, so the new pywal colours apply the next time Dolphin is
# opened — no disruptive auto-restart of an open file manager on every wallpaper
# change. The dbus signal above lets any KDE app that supports live reload update.

exit 0
