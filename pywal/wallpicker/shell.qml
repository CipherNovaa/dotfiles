// Wallpaper picker overlay. Runs only while open: launch.sh starts it, it quits on close.
// All real work stays in wallpaper-picker.sh (--list and --apply), shared with the rofi menu.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: shell

    readonly property string script: Quickshell.env("HOME") + "/scripts/system/wallpaper-picker.sh"
    readonly property string statePath: Quickshell.env("HOME") + "/.cache/wallpick.json"
    readonly property string screenName: Quickshell.env("WALLPICK_SCREEN") || ""
    readonly property bool testMode: Quickshell.env("WALLPICK_TEST") === "1"

    // ── Palette from pywal ───────────────────────────────────────────────────
    property color cBg: "#0e171a"
    property color cFg: "#c8d6d8"
    property color cDim: "#768586"
    property color cAccent: "#6fd0c0"

    function readPalette(text) {
        try {
            const wal = JSON.parse(text);
            cBg = wal.special.background;
            cFg = wal.special.foreground;
            cDim = Qt.lighter(wal.colors.color8, 1.15);
            let best = null;
            for (let i = 1; i <= 6; i++) {
                const c = Qt.color(wal.colors["color" + i]);
                if (!best || c.hslSaturation > best.hslSaturation) best = c;
            }
            // Pywal accents can be too dark to read on a dark panel.
            cAccent = Qt.hsla(best.hslHue, Math.max(best.hslSaturation, 0.45),
                              Math.max(best.hslLightness, 0.62), 1);
        } catch (e) {}
    }

    FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: shell.readPalette(text())
    }

    // ── Data ─────────────────────────────────────────────────────────────────
    property var all: []
    property var monitors: []
    property var currents: ({})     // output name -> wallpaper path
    property bool hasDeck: false
    property string filter: "all"
    property string search: ""
    property var targets: ({})      // output name -> chosen
    property var savedTargets: null
    property bool stateChecked: false
    property bool targetsReady: false
    property bool selectionDone: false
    property bool targetDeck: false
    property bool recolor: true
    property int selected: 0
    property string previewPath: ""
    property bool listLoaded: false
    property bool currentsLoaded: false
    signal previewReady

    readonly property var view: {
        const q = search.toLowerCase();
        return all.filter(w => (filter === "all" || w.type === filter)
                               && (!q || w.name.toLowerCase().includes(q)));
    }
    readonly property var chosen: view.length ? view[Math.min(selected, view.length - 1)] : null

    function count(type) {
        return type === "all" ? all.length : all.filter(w => w.type === type).length;
    }
    function fileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
    function sizeText(bytes) {
        return bytes > 1048576 ? (bytes / 1048576).toFixed(1) + " MB" : Math.round(bytes / 1024) + " KB";
    }
    function outputLabel(name) {
        if (name === "HDMI-A-1" && monitors.some(m => m.name === "DP-3")) return "CRT";
        if (name === "DP-3") return "MAIN";
        if (name.startsWith("eDP")) return "LAPTOP";
        return name;
    }
    function chosenOutputs() {
        return monitors.filter(m => targets[m.name]).map(m => m.name);
    }
    function targetLabel() {
        const t = chosenOutputs().map(outputLabel);
        if (targetDeck && hasDeck) t.push("DECK");
        return t.join(" + ");
    }
    function canApply() {
        return !!chosen && (chosenOutputs().length > 0 || (targetDeck && hasDeck) || recolor);
    }
    function toggleTarget(name) {
        const next = Object.assign({}, targets);
        next[name] = !next[name];
        targets = next;
    }
    function reconcileTargets() {
        if (targetsReady || !monitors.length || !stateChecked) return;
        const next = {};
        let any = false;
        for (const m of monitors) {
            next[m.name] = !!(savedTargets && savedTargets[m.name]);
            any = any || next[m.name];
        }
        // First run, or a saved choice for screens that aren't connected now.
        if (!any) {
            const focused = monitors.find(m => m.focused) || monitors[0];
            next[focused.name] = true;
        }
        targets = next;
        targetsReady = true;
    }

    function select(i) {
        if (!view.length) return;
        selected = Math.max(0, Math.min(view.length - 1, i));
        grid.positionViewAtIndex(selected, GridView.Contain);
        previewDelay.restart();
    }
    function setFilter(name) {
        const keep = chosen ? chosen.path : "";
        filter = name;
        selectPath(keep);
    }
    function selectPath(path) {
        const i = view.findIndex(w => w.path === path);
        select(i >= 0 ? i : 0);
    }

    function apply() {
        if (!canApply()) return;
        const picked = chosenOutputs();
        if (targetDeck && hasDeck) picked.push("deck");
        const args = ["bash", script, "--apply", picked.join(",") || "none", chosen.path];
        if (!recolor) args.push("--no-recolor");
        const state = JSON.stringify({targets, deck: targetDeck, recolor});
        Quickshell.execDetached(["bash", "-c", 'printf %s "$1" > "$2"', "_", state, statePath]);
        if (testMode) {
            console.log("WOULD RUN: " + args.join(" "));
            return;
        }
        Quickshell.execDetached(args);
        Qt.quit();
    }

    function startupSelection() {
        if (selectionDone || !listLoaded || !monitors.length || !currentsLoaded) return;
        selectionDone = true;
        const focused = monitors.find(m => m.focused);
        selectPath(focused ? (currents[focused.name] || "") : "");
        previewPath = chosen ? chosen.path : "";
        previewReady();
    }

    Process {
        command: ["bash", shell.script, "--list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                shell.all = text.split("\n").filter(l => l.length).map(l => {
                    const f = l.split("\t");
                    return {name: f[0], path: f[1], thumb: f[2], type: f[3], bytes: Number(f[4])};
                });
                shell.listLoaded = true;
                shell.startupSelection();
            }
        }
    }
    Process {
        command: ["hyprctl", "monitors", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    shell.monitors = JSON.parse(text).sort((a, b) => a.x - b.x);
                } catch (e) {}
                shell.reconcileTargets();
                shell.startupSelection();
            }
        }
    }
    Process {
        command: ["bash", shell.script, "--current"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f[0] === "output") found[f[1]] = f[2];
                    else if (f[0] === "deck") shell.hasDeck = true;
                }
                shell.currents = found;
                shell.currentsLoaded = true;
                shell.startupSelection();
            }
        }
    }
    FileView {
        path: shell.statePath
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                shell.savedTargets = s.targets || null;
                shell.targetDeck = !!s.deck;
                shell.recolor = s.recolor !== false;
            } catch (e) {}
            shell.stateChecked = true;
            shell.reconcileTargets();
        }
        onLoadFailed: {
            shell.stateChecked = true;
            shell.reconcileTargets();
        }
    }

    // Loading a large GIF per keypress would make scrolling drag behind.
    Timer {
        id: previewDelay
        interval: 140
        onTriggered: {
            shell.previewPath = shell.chosen ? shell.chosen.path : "";
            shell.previewReady();
        }
    }

    // Test hooks, used without keyboard focus so nothing can type into the wrong place.
    IpcHandler {
        target: "wallpick"
        function selectIndex(i: int): void { shell.select(i); }
        function setFilter(name: string): void { shell.setFilter(name); }
        function setSearch(text: string): void { shell.search = text; shell.select(0); }
        function toggleOutput(name: string): void { shell.toggleTarget(name); }
        function toggleRecolor(): void { shell.recolor = !shell.recolor; }
        function applyNow(): void { shell.apply(); }
        function info(): string {
            return JSON.stringify({view: shell.view.length, selected: shell.selected,
                                   chosen: shell.chosen ? shell.chosen.name : "",
                                   targets: shell.targetLabel(), recolor: shell.recolor,
                                   filter: shell.filter, previewPath: shell.previewPath});
        }
        function quit(): void { Qt.quit(); }
    }

    // ── Shared pieces ────────────────────────────────────────────────────────
    component T: Text {
        font.family: "MGS1 Codec"
        font.pixelSize: 16
        font.letterSpacing: 1
        color: shell.cFg
        style: Text.Raised
        styleColor: "#000000"
        renderType: Text.NativeRendering
        elide: Text.ElideRight
    }

    component PreviewSlot: Item {
        id: slot
        property var entry: null
        property string fullPath: ""
        readonly property bool isGif: fullPath.endsWith(".gif")
        anchors.fill: parent
        opacity: 0
        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            source: slot.entry ? shell.fileUrl(slot.entry.thumb) : ""
            smooth: true
        }
        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 130 } }
            source: slot.fullPath && !slot.isGif ? shell.fileUrl(slot.fullPath) : ""
        }
        AnimatedImage {
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true
            playing: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 130 } }
            source: slot.fullPath && slot.isGif ? shell.fileUrl(slot.fullPath) : ""
        }
    }

    component Brackets: Item {
        property color tint: shell.cAccent
        property int arm: 12
        property int weight: 2
        anchors.fill: parent
        Rectangle { color: parent.tint; width: parent.arm; height: parent.weight; x: 0; y: 0 }
        Rectangle { color: parent.tint; width: parent.weight; height: parent.arm; x: 0; y: 0 }
        Rectangle { color: parent.tint; width: parent.arm; height: parent.weight; x: parent.width - width; y: 0 }
        Rectangle { color: parent.tint; width: parent.weight; height: parent.arm; x: parent.width - width; y: 0 }
        Rectangle { color: parent.tint; width: parent.arm; height: parent.weight; x: 0; y: parent.height - height }
        Rectangle { color: parent.tint; width: parent.weight; height: parent.arm; x: 0; y: parent.height - height }
        Rectangle { color: parent.tint; width: parent.arm; height: parent.weight; x: parent.width - width; y: parent.height - height }
        Rectangle { color: parent.tint; width: parent.weight; height: parent.arm; x: parent.width - width; y: parent.height - height }
    }

    component Tag: Rectangle {
        property string label: ""
        property color tint: shell.cAccent
        implicitWidth: tagText.implicitWidth + 10
        implicitHeight: 16
        color: tint
        Text {
            id: tagText
            anchors.centerIn: parent
            text: parent.label
            font.family: "MGS1 Codec"
            font.pixelSize: 12
            font.letterSpacing: 1
            renderType: Text.NativeRendering
            color: "#000000"
        }
    }

    component Chip: Item {
        id: chip
        property string name: ""
        property string label: ""
        readonly property bool active: shell.filter === name
        implicitWidth: chipText.implicitWidth + 18
        implicitHeight: 24
        Rectangle {
            anchors.fill: parent
            color: chip.active ? shell.cAccent : "transparent"
            border.width: 1
            border.color: chip.active ? shell.cAccent : Qt.alpha(shell.cDim, 0.6)
        }
        T {
            id: chipText
            anchors.centerIn: parent
            text: chip.label + " " + shell.count(chip.name)
            font.pixelSize: 14
            color: chip.active ? "#000000" : shell.cFg
            style: chip.active ? Text.Normal : Text.Raised
        }
        MouseArea { anchors.fill: parent; onClicked: shell.setFilter(chip.name) }
    }

    component Check: Item {
        id: check
        property string label: ""
        property string key: ""
        property bool on: false
        signal toggled
        implicitHeight: 26
        Rectangle {
            id: box
            width: 16; height: 16
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.width: 1
            border.color: check.on ? shell.cAccent : shell.cDim
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                color: shell.cAccent
                visible: check.on
            }
        }
        T {
            anchors.left: box.right
            anchors.leftMargin: 10
            anchors.right: keyHint.left
            anchors.verticalCenter: parent.verticalCenter
            text: check.label
            color: check.on ? shell.cFg : shell.cDim
        }
        T {
            id: keyHint
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: check.key
            font.pixelSize: 12
            color: shell.cDim
        }
        MouseArea { anchors.fill: parent; onClicked: check.toggled() }
    }

    // ── Window ───────────────────────────────────────────────────────────────
    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === shell.screenName) || Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "qs-wallpick"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: shell.testMode ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
            MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
        }

        Item {
            id: panel
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.92, 1500)
            height: Math.min(parent.height * 0.88, 920)
            focus: !searchBox.activeFocus
            opacity: 0
            scale: 0.985
            Component.onCompleted: { opacity = 1; scale = 1; forceActiveFocus(); }
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Keys.onPressed: event => {
                const rows = Math.max(1, Math.floor(grid.height / grid.cellHeight));
                const k = event.key;
                if (k === Qt.Key_Escape) Qt.quit();
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) shell.apply();
                else if (k === Qt.Key_Left || k === Qt.Key_H) shell.select(shell.selected - rows);
                else if (k === Qt.Key_Right || k === Qt.Key_L) shell.select(shell.selected + rows);
                else if (k === Qt.Key_Up || k === Qt.Key_K) shell.select(shell.selected - 1);
                else if (k === Qt.Key_Down || k === Qt.Key_J) shell.select(shell.selected + 1);
                else if (k === Qt.Key_PageUp) shell.select(shell.selected - rows * 6);
                else if (k === Qt.Key_PageDown) shell.select(shell.selected + rows * 6);
                else if (k === Qt.Key_Home) shell.select(0);
                else if (k === Qt.Key_End) shell.select(shell.view.length - 1);
                else if (k === Qt.Key_Tab) {
                    const order = ["all", "gif", "still", "live"];
                    shell.setFilter(order[(order.indexOf(shell.filter) + 1) % order.length]);
                }
                else if (k === Qt.Key_Slash) searchBox.forceActiveFocus();
                else if (k >= Qt.Key_1 && k <= Qt.Key_9 && shell.monitors[k - Qt.Key_1])
                    shell.toggleTarget(shell.monitors[k - Qt.Key_1].name);
                else if (k === Qt.Key_C) shell.recolor = !shell.recolor;
                else if (k === Qt.Key_D && shell.hasDeck) shell.targetDeck = !shell.targetDeck;
                else return;
                event.accepted = true;
            }

            MouseArea { anchors.fill: parent }  // clicks on the panel must not close it

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Qt.darker(shell.cBg, 1.35), 0.97)
                border.width: 1
                border.color: Qt.alpha(shell.cAccent, 0.45)
            }
            Brackets { arm: 22; weight: 3 }

            // ── Header ───────────────────────────────────────────────────────
            Item {
                id: header
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                height: 28
                T {
                    id: title
                    anchors.verticalCenter: parent.verticalCenter
                    text: "WALLPAPER"
                    font.pixelSize: 24
                    font.letterSpacing: 2
                    color: shell.cAccent
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Chip { name: "all"; label: "ALL" }
                    Chip { name: "gif"; label: "GIF" }
                    Chip { name: "still"; label: "STILL" }
                    Chip { name: "live"; label: "LIVE" }
                }
            }
            Rectangle {
                id: rule
                anchors { left: parent.left; right: parent.right; top: header.bottom; topMargin: 10; leftMargin: 18; rightMargin: 18 }
                height: 1
                color: Qt.alpha(shell.cAccent, 0.35)
            }

            // ── Thumbnails, along the bottom ─────────────────────────────────
            Item {
                id: strip
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 18 }
                height: Math.round(panel.height * 0.31)
                clip: true

                GridView {
                    id: grid
                    anchors.fill: parent
                    flow: GridView.FlowTopToBottom
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    cellHeight: Math.floor(height / 2)
                    cellWidth: Math.round(cellHeight * 1.45)
                    model: shell.view
                    cacheBuffer: cellWidth * 6
                    interactive: false

                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool isSelected: index === shell.selected
                        width: grid.cellWidth
                        height: grid.cellHeight

                        Item {
                            anchors.fill: parent
                            anchors.margins: 4
                            Image {
                                anchors.fill: parent
                                source: shell.fileUrl(cell.modelData.thumb)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.height: 240
                                smooth: true
                                opacity: cell.isSelected ? 1 : 0.72
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.width: 1
                                border.color: cell.isSelected ? shell.cAccent : Qt.alpha(shell.cDim, 0.35)
                            }
                            Brackets { visible: cell.isSelected; arm: 14; weight: 3 }
                            Row {
                                anchors { left: parent.left; bottom: parent.bottom; margins: 5 }
                                spacing: 3
                                Tag { visible: cell.modelData.type === "live"; label: "LIVE" }
                                Tag {
                                    visible: cell.modelData.type === "gif"
                                    label: "GIF"
                                    tint: Qt.alpha(shell.cFg, 0.75)
                                }
                            }
                            Row {
                                anchors { right: parent.right; top: parent.top; margins: 5 }
                                spacing: 3
                                Repeater {
                                    model: shell.monitors.filter(m => shell.currents[m.name] === cell.modelData.path)
                                    delegate: Tag {
                                        required property var modelData
                                        label: shell.outputLabel(modelData.name)
                                        tint: shell.cFg
                                    }
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: shell.select(cell.index)
                            onDoubleClicked: { shell.select(cell.index); shell.apply(); }
                        }
                    }

                    NumberAnimation {
                        id: scroll
                        target: grid
                        property: "contentX"
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            const from = scroll.running ? scroll.to : grid.contentX;
                            const delta = (event.angleDelta.y || event.angleDelta.x) / 120 * grid.cellWidth * 1.5;
                            const max = Math.max(0, grid.contentWidth - grid.width);
                            scroll.stop();
                            scroll.to = Math.max(0, Math.min(max, from - delta));
                            scroll.start();
                        }
                    }
                }
                T {
                    anchors.centerIn: parent
                    visible: !shell.view.length && shell.listLoaded
                    text: "NO MATCH"
                    color: shell.cDim
                }
                T {
                    anchors.centerIn: parent
                    visible: !shell.listLoaded
                    text: "READING WALLPAPERS"
                    color: shell.cDim
                }
            }
            Rectangle {
                id: stripRule
                anchors { left: parent.left; right: parent.right; bottom: strip.top; bottomMargin: 8; leftMargin: 18; rightMargin: 18 }
                height: 1
                color: Qt.alpha(shell.cAccent, 0.35)
            }

            // ── Right column: outputs, options, details ──────────────────────
            Column {
                id: side
                anchors { right: parent.right; top: rule.bottom; bottom: stripRule.top; rightMargin: 18; topMargin: 12; bottomMargin: 10 }
                width: 300
                spacing: 8

                T { text: "OUTPUTS"; color: shell.cAccent }

                Item {
                    id: layout
                    width: parent.width
                    height: 124
                    readonly property var known: shell.monitors
                    readonly property real minX: known.length ? Math.min(...known.map(m => m.x)) : 0
                    readonly property real minY: known.length ? Math.min(...known.map(m => m.y)) : 0
                    readonly property real totalW: known.length ? Math.max(...known.map(m => m.x + m.width)) - minX : 1
                    readonly property real totalH: known.length ? Math.max(...known.map(m => m.y + m.height)) - minY : 1
                    readonly property real unit: Math.min((width - 6 * (known.length - 1)) / totalW, height / totalH)

                    Repeater {
                        model: layout.known
                        delegate: Item {
                            id: mon
                            required property var modelData
                            required property int index
                            readonly property bool on: !!shell.targets[modelData.name]
                            readonly property string current: shell.currents[modelData.name] || ""
                            readonly property var currentEntry: shell.all.find(w => w.path === current)
                            x: (modelData.x - layout.minX) * layout.unit + index * 6
                            y: (modelData.y - layout.minY) * layout.unit
                            width: modelData.width * layout.unit
                            height: modelData.height * layout.unit

                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                fillMode: Image.Stretch
                                asynchronous: true
                                source: mon.on && shell.chosen ? shell.fileUrl(shell.chosen.thumb)
                                      : mon.currentEntry ? shell.fileUrl(mon.currentEntry.thumb) : ""
                                opacity: mon.on ? 1 : 0.35
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.width: mon.on ? 2 : 1
                                border.color: mon.on ? shell.cAccent : shell.cDim
                            }
                            Tag {
                                anchors { left: parent.left; bottom: parent.bottom; margins: 4 }
                                label: (mon.index + 1) + " " + shell.outputLabel(mon.modelData.name)
                                tint: mon.on ? shell.cAccent : shell.cDim
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: shell.toggleTarget(mon.modelData.name)
                            }
                        }
                    }
                }

                Item { width: 1; height: 4 }
                Check {
                    width: parent.width
                    label: "RECOLOR SYSTEM"
                    key: "C"
                    on: shell.recolor
                    onToggled: shell.recolor = !shell.recolor
                }
                Check {
                    width: parent.width
                    visible: shell.hasDeck
                    label: "STREAM DECK"
                    key: "D"
                    on: shell.targetDeck
                    onToggled: shell.targetDeck = !shell.targetDeck
                }

                Item {
                    id: applyButton
                    width: parent.width
                    height: 38
                    readonly property bool enabledNow: shell.canApply()
                    Rectangle {
                        anchors.fill: parent
                        color: applyButton.enabledNow ? shell.cAccent : "transparent"
                        border.width: 1
                        border.color: applyButton.enabledNow ? shell.cAccent : shell.cDim
                    }
                    T {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: !applyButton.enabledNow ? "PICK AN OUTPUT"
                              : shell.targetLabel() ? "APPLY TO " + shell.targetLabel() : "COLORS ONLY"
                        font.pixelSize: 16
                        color: applyButton.enabledNow ? "#000000" : shell.cDim
                        style: applyButton.enabledNow ? Text.Normal : Text.Raised
                    }
                    MouseArea { anchors.fill: parent; onClicked: shell.apply() }
                }

                Item { width: 1; height: 2 }
                T { text: "SEARCH"; color: shell.cAccent; font.pixelSize: 14 }
                Item {
                    width: parent.width
                    height: 26
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 1
                        border.color: searchBox.activeFocus ? shell.cAccent : Qt.alpha(shell.cDim, 0.6)
                    }
                    TextInput {
                        id: searchBox
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: "MGS1 Codec"
                        font.pixelSize: 14
                        color: shell.cFg
                        selectionColor: shell.cAccent
                        clip: true
                        onTextChanged: { shell.search = text; shell.select(0); }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (event.key === Qt.Key_Escape) text = "";
                                panel.forceActiveFocus();
                                event.accepted = true;
                            }
                        }
                    }
                    T {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !searchBox.text && !searchBox.activeFocus
                        text: "PRESS /"
                        font.pixelSize: 12
                        color: shell.cDim
                    }
                }

                Item { width: 1; height: 6 }
                Repeater {
                    model: [["H J K L", "MOVE"], ["ENTER", "APPLY"], ["TAB", "FILTER"], ["ESC", "CLOSE"]]
                    delegate: Item {
                        required property var modelData
                        width: side.width
                        height: 18
                        T {
                            anchors.left: parent.left
                            text: parent.modelData[0]
                            font.pixelSize: 12
                            color: shell.cAccent
                        }
                        T {
                            anchors.right: parent.right
                            text: parent.modelData[1]
                            font.pixelSize: 12
                            color: shell.cDim
                        }
                    }
                }
            }

            // ── Preview ──────────────────────────────────────────────────────
            Item {
                id: previewArea
                anchors { left: parent.left; right: side.left; top: rule.bottom; bottom: stripRule.top; leftMargin: 18; rightMargin: 18; topMargin: 12; bottomMargin: 10 }

                T {
                    id: nameLine
                    anchors { left: parent.left; right: typeLine.left; bottom: parent.bottom; rightMargin: 12 }
                    text: shell.chosen ? shell.chosen.name : ""
                    font.pixelSize: 16
                }
                T {
                    id: typeLine
                    anchors { right: parent.right; bottom: parent.bottom }
                    text: shell.chosen ? shell.chosen.type.toUpperCase() + "  " + shell.sizeText(shell.chosen.bytes) : ""
                    font.pixelSize: 14
                    color: shell.cDim
                }

                Item {
                    id: frame
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nameLine.top; bottomMargin: 8 }
                    clip: true

                    Rectangle { anchors.fill: parent; color: "#000000" }
                    PreviewSlot { id: slotA }
                    PreviewSlot { id: slotB }

                    property Item shown: slotA
                    property Item leaving: slotB

                    function showEntry(entry) {
                        if (!entry || (shown.entry && shown.entry.path === entry.path)) return;
                        fade.stop();
                        const incoming = leaving;
                        leaving = shown;
                        shown = incoming;
                        incoming.fullPath = "";
                        incoming.entry = entry;
                        incoming.scale = 1.025;
                        incoming.opacity = 0;
                        leaving.z = 1;
                        incoming.z = 2;
                        fade.start();
                    }

                    // A new selection takes over mid-fade, so fast scrolling never queues up.
                    ParallelAnimation {
                        id: fade
                        NumberAnimation {
                            target: frame.shown
                            property: "opacity"
                            to: 1
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: frame.shown
                            property: "scale"
                            to: 1
                            duration: 240
                            easing.type: Easing.OutCubic
                        }
                        onFinished: {
                            frame.leaving.opacity = 0;
                            frame.leaving.fullPath = "";
                        }
                    }

                    Connections {
                        target: shell
                        function onChosenChanged() { frame.showEntry(shell.chosen); }
                        function onPreviewReady() {
                            if (frame.shown.entry && frame.shown.entry.path === shell.previewPath)
                                frame.shown.fullPath = shell.previewPath;
                        }
                    }

                    Canvas {
                        anchors.fill: parent
                        z: 5
                        opacity: 0.16
                        onPaint: {
                            const c = getContext("2d");
                            c.clearRect(0, 0, width, height);
                            c.fillStyle = "#000000";
                            for (let y = 0; y < height; y += 3) c.fillRect(0, y, width, 1);
                        }
                    }
                    Tag {
                        anchors { left: parent.left; top: parent.top; margins: 10 }
                        z: 5
                        visible: !!shell.chosen && shell.chosen.type === "live"
                        label: "LIVE"
                    }
                    Brackets { arm: 18; weight: 2; z: 5 }
                }
            }
        }
    }
}
