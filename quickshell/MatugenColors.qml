// Live pywal palette — EVENT-DRIVEN (FileView watchChanges on ~/.cache/wal/colors.json).
// Keeps the source widgets' filename/type name (MatugenColors) so their
// `MatugenColors { id: _theme }` works unchanged, but reads the pywal cache
// instead of polling /tmp/qs_colors.json. Instantiated locally per widget.
//
// Exposes catppuccin-style names (base/text/surface*/accents) that the ported
// widgets expect, PLUS media/power aliases (bg/fg/card/accent/accent2/muted/err).
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ── catppuccin-style names (defaults = current palette as fallback) ──
    property color base:     "#0E171A"
    property color mantle:   "#0b1214"
    property color crust:    "#080d0f"
    property color text:     "#a9bec0"
    property color subtext0: "#768586"
    property color subtext1: "#98abad"
    property color surface0: "#0d1518"
    property color surface1: "#142025"
    property color surface2: "#768586"
    property color overlay0: "#768586"
    property color overlay1: "#8a9899"
    property color overlay2: "#9eaaab"
    property color blue:     "#4A5D61"
    property color sapphire: "#28585B"
    property color teal:     "#28585B"
    property color green:    "#28585B"
    property color peach:    "#5a6e5a"
    property color yellow:   "#5a6e5a"
    property color red:      "#304A4E"
    property color maroon:   "#3c5a5e"
    property color mauve:    "#4A5D61"
    property color pink:     "#5d7074"

    // ── media/power aliases ──
    property color bg:      base
    property color fg:      text
    property color card:    surface0
    property color accent:  blue
    property color accent2: green
    property color muted:   subtext0
    property color err:     red

    function load(txt) {
        try {
            const w = JSON.parse(txt);
            const bgc = w.special.background;
            const fgc = w.special.foreground;
            const c   = w.colors;

            base     = bgc;
            mantle   = Qt.darker(bgc, 1.15);
            crust    = Qt.darker(bgc, 1.3);
            text     = fgc;
            subtext1 = Qt.darker(fgc, 1.1);
            subtext0 = c.color8;
            surface0 = c.color0;
            surface1 = Qt.lighter(c.color0, 1.5);
            surface2 = c.color8;
            overlay0 = c.color8;
            overlay1 = Qt.lighter(c.color8, 1.2);
            overlay2 = Qt.lighter(c.color8, 1.4);
            red      = c.color1;
            maroon   = Qt.lighter(c.color1, 1.2);
            green    = c.color2;
            peach    = c.color3;
            yellow   = c.color3;
            blue     = c.color4;
            mauve    = c.color5;
            pink     = Qt.lighter(c.color5, 1.2);
            teal     = c.color6;
            sapphire = c.color6;
        } catch (e) { /* keep last good palette */ }
    }

    FileView {
        id: walFile
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.load(walFile.text())
    }
}
