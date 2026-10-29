.pragma library

// Scale helper — keeps the source's aspect-aware scaling so ported widgets
// (which call s()/getScale via Scaler.qml) size correctly on any monitor.
function getScale(mw, mh, userScale) {
    if (arguments.length === 2) {
        userScale = mh;
        mh = mw * (1080.0 / 1920.0);
    }

    if (mw <= 0 || mh <= 0) return 1.0;

    let rw = mw / 1920.0;
    let rh = mh / 1080.0;
    let r = Math.min(rw, rh);

    let baseScale = 1.0;
    if (r <= 1.0) {
        baseScale = Math.max(0.35, Math.pow(r, 0.85));
    } else {
        baseScale = Math.pow(r, 0.5);
    }

    return baseScale * (userScale !== undefined ? userScale : 1.0);
}

function s(val, scale) {
    return Math.round(val * scale);
}

// Widget layout registry. comp paths are relative to Main.qml.
function getLayout(name, mx, my, mw, mh, userScale) {
    let scale = getScale(mw, mh, userScale);

    let base = {
        // The original single-file popups, reimplemented as dispatcher widgets
        "media":     { w: s(300, scale), h: s(150, scale), rx: mw - s(306, scale), ry: s(6, scale),  comp: "MediaPopup.qml" },
        "power":     { w: mw,            h: mh,            rx: 0,                  ry: 0,            comp: "PowerMenu.qml" },

        // Top-left control center / notifications (battery + sliders + power profiles)
        "battery":   { w: s(801, scale), h: s(760, scale), rx: s(5, scale),         ry: s(60, scale), comp: "battery/BatteryPopup.qml" },

        // Top-right connection manager (wifi / ethernet / bluetooth) — ported from upstream
        "network":   { w: s(900, scale), h: s(700, scale), rx: mw - s(904, scale), ry: s(60, scale), comp: "network/NetworkPopup.qml" },

        // Top-right edge
        "music":     { w: s(700, scale), h: s(650, scale), rx: mw - s(705, scale), ry: s(60, scale), comp: "music/MusicPopup.qml" },

        // Centered large
        "focustime": { w: s(900, scale), h: s(700, scale), rx: Math.floor((mw/2)-(s(900, scale)/2)), ry: Math.floor((mh/2)-(s(700, scale)/2)), comp: "focustime/FocusTimePopup.qml" },

        // Top-centered wide
        "calendar":  { w: s(1450, scale), h: s(750, scale), rx: Math.floor((mw/2)-(s(1450, scale)/2)), ry: s(60, scale), comp: "calendar/CalendarPopup.qml" },

        // Utility — off-screen 1x1 "closed" state
        "hidden":    { w: 1, h: 1, rx: -5000 - mx, ry: -5000 - my, comp: "" }
    };

    if (!base[name]) return null;

    let t = base[name];
    t.x = mx + t.rx;
    t.y = my + t.ry;
    return t;
}

// Toast popup geometry for NotificationPopups.qml
function getPopupLayout(mw, mh, userScale) {
    if (arguments.length === 2) {
        userScale = mh;
        mh = mw * (1080.0 / 1920.0);
    }
    let scale = getScale(mw, mh, userScale);
    return {
        w: s(350, scale),
        marginTop: s(60, scale),
        marginRight: s(20, scale),
        spacing: s(12, scale),
        radius: s(14, scale),
        padding: s(12, scale)
    };
}
