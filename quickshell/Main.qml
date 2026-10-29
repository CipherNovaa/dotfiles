// Dispatcher master overlay — single fullscreen layer-shell window that morphs
// between widgets in a StackView. Adapted from ilyamiro's Main.qml
// (github.com/ilyamiro/nixos-configuration), trimmed down: no NotificationServer, no preloader, no settings.json machinery
// (globalUiScale hardcoded 1.0). Widgets are looked up via WindowRegistry.js.
//
// IPC:
//   qs ipc call main handleCommand <toggle|open|close> <widget> <arg>
//   qs ipc call media|power toggle|show|hide   (compatibility shims → runCommand)
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "WindowRegistry.js" as Registry
import "notifications" as Notifs

PanelWindow {
    id: masterWindow
    color: "transparent"

    WlrLayershell.namespace: "qs-master"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    implicitWidth: masterWindow.screen ? masterWindow.screen.width : 1920
    implicitHeight: masterWindow.screen ? masterWindow.screen.height : 1080

    // Only mapped while a widget is open → desktop clicks pass through when idle.
    visible: isVisible

    // ── state ─────────────────────────────────────────────────────────────
    property string currentActive: "hidden"
    property bool   isVisible: false
    property string activeArg: ""
    property bool   disableMorph: false

    property int  morphDuration: 230
    property int  morphDurationSwitch: 210
    property int  exitDuration: 160

    property real animW: 1
    property real animH: 1
    property real animX: 0
    property real animY: 0
    property real targetW: 1
    property real targetH: 1

    readonly property real globalUiScale: 1.0

    // close callback handed to every widget so buttons/backdrops can dismiss
    property var closeFn: (function () { masterWindow.runCommand("close", "", ""); })

    // ── command routing (shared by the `main` IPC + the media/power shims) ──
    function runCommand(cmd, targetWidget, arg) {
        cmd = cmd || "";
        targetWidget = targetWidget || "";
        arg = arg || "";

        let isClosing = (masterWindow.currentActive !== "hidden" && !masterWindow.isVisible);
        let effectivelyActive = isClosing ? "hidden" : masterWindow.currentActive;

        if (cmd === "close") {
            switchWidget("hidden", "");
        } else if (cmd === "toggle" || cmd === "open") {
            delayedClear.stop();
            if (targetWidget === effectivelyActive) {
                let currentItem = widgetStack.currentItem;
                if (arg !== "" && currentItem && currentItem.activeMode !== undefined && currentItem.activeMode !== arg) {
                    currentItem.activeMode = arg;
                } else if (cmd === "toggle") {
                    switchWidget("hidden", "");
                }
            } else if (getLayout(targetWidget)) {
                switchWidget(targetWidget, arg);
            }
        }
    }

    IpcHandler {
        target: "main"
        function handleCommand(cmd: string, targetWidget: string, arg: string): void {
            masterWindow.runCommand(cmd, targetWidget, arg);
        }
        function forceReload(): void { Quickshell.reload(true); }
    }

    // Compatibility shims — keep `qs ipc call media|power …` (hyprland.lua + waybar)
    IpcHandler {
        target: "media"
        function toggle(): void { masterWindow.runCommand("toggle", "media", ""); }
        function show(): void   { masterWindow.runCommand("open", "media", ""); }
        function hide(): void   { masterWindow.runCommand("close", "", ""); }
    }
    IpcHandler {
        target: "power"
        function toggle(): void { masterWindow.runCommand("toggle", "power", ""); }
        function show(): void   { masterWindow.runCommand("open", "power", ""); }
        function hide(): void   { masterWindow.runCommand("close", "", ""); }
    }

    // ── notifications (quickshell is the notification daemon; replaces dunst) ─
    ListModel { id: globalNotificationHistory }
    ListModel { id: activePopupsModel }
    property var notifModel: globalNotificationHistory
    property var liveNotifs: ({})
    property int _popupCounter: 0
    property bool isStartup: true
    Timer { interval: 500; running: true; onTriggered: masterWindow.isStartup = false }

    function removePopup(uid) {
        for (let i = 0; i < activePopupsModel.count; i++) {
            if (activePopupsModel.get(i).uid === uid) { activePopupsModel.remove(i); break; }
        }
    }

    NotificationServer {
        id: globalNotificationServer
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: (n) => {
            // Drop flameshot's per-capture "grim/wlroots" Warning toast (it routes through
            // us since quickshell owns the notification bus). Keep its "Capture saved/copied"
            // Info notifications — so we filter on the Warning summary / grim body only.
            if (n.appName === "flameshot" && (n.summary === "Flameshot Warning"
                    || (n.body && n.body.indexOf("grim's screenshot component") !== -1))) {
                return;
            }
            n.tracked = true;
            let acts = [];
            if (n.actions) for (let i = 0; i < n.actions.length; i++)
                acts.push({ "id": n.actions[i].identifier || "", "text": n.actions[i].text || n.actions[i].name || "Action" });
            masterWindow._popupCounter++;
            let uid = masterWindow._popupCounter;
            masterWindow.liveNotifs[uid] = n;
            let d = {
                "appName":     n.appName  !== "" ? n.appName  : "System",
                "summary":     n.summary  !== "" ? n.summary  : "No Title",
                "body":        n.body     !== "" ? n.body     : "",
                "iconPath":    n.appIcon  !== "" ? n.appIcon  : "",
                "actionsJson": JSON.stringify(acts),
                "uid":         uid,
                "notif":       n
            };
            globalNotificationHistory.insert(0, d);
            if (!masterWindow.isStartup) { activePopupsModel.append(d); osdPopups.storeNotif(uid, n); }
        }
    }

    Notifs.NotificationPopups {
        id: osdPopups
        popupModel: activePopupsModel
        uiScale: masterWindow.globalUiScale
        onRemoveRequested: (uid) => masterWindow.removePopup(uid)
    }

    // ── click-out to close (behind the widget box) ──────────────────────────
    MouseArea {
        anchors.fill: parent
        enabled: masterWindow.isVisible
        onClicked: switchWidget("hidden", "")
    }

    // ── layout lookup (cached) ──────────────────────────────────────────────
    property var    _layoutCache: ({})
    property string _layoutCacheKey: ""

    function getLayout(name) {
        let key = name + "|" + masterWindow.width + "|" + masterWindow.height + "|" + masterWindow.globalUiScale;
        if (_layoutCacheKey === key) return _layoutCache[key];
        let result = Registry.getLayout(name, 0, 0, masterWindow.width, masterWindow.height, masterWindow.globalUiScale);
        _layoutCache = {};
        _layoutCache[key] = result;
        _layoutCacheKey = key;
        return result;
    }

    Connections {
        target: masterWindow
        function onWidthChanged()  { _layoutCacheKey = ""; handleNativeScreenChange(); }
        function onHeightChanged() { _layoutCacheKey = ""; handleNativeScreenChange(); }
    }

    function handleNativeScreenChange() {
        if (masterWindow.currentActive === "hidden") return;
        let t = getLayout(masterWindow.currentActive);
        if (!t) return;
        let ci = widgetStack.currentItem;
        let finalW = (ci && ci.targetMasterWidth  !== undefined) ? ci.targetMasterWidth  : t.w;
        let finalH = (ci && ci.targetMasterHeight !== undefined) ? ci.targetMasterHeight : t.h;
        let finalX = t.rx;
        if (ci && ci.targetMasterWidth !== undefined && finalW !== t.w) {
            finalX = Math.floor((masterWindow.width / 2) - (finalW / 2));
        }
        masterWindow.animX = finalX;
        masterWindow.animY = t.ry;
        masterWindow.animW = finalW;
        masterWindow.animH = finalH;
        masterWindow.targetW = finalW;
        masterWindow.targetH = finalH;
    }

    onIsVisibleChanged: { if (isVisible) widgetStack.forceActiveFocus(); }

    // ── animated bounding box + StackView ────────────────────────────────────
    Item {
        x: masterWindow.animX
        y: masterWindow.animY
        width:  masterWindow.animW
        height: masterWindow.animH
        clip: true

        Behavior on x      { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic } }
        Behavior on y      { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic } }
        Behavior on width  { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic } }
        Behavior on height { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic } }

        opacity: masterWindow.isVisible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: masterWindow.isVisible ? Easing.OutCubic : Easing.InCubic }
        }

        MouseArea { anchors.fill: parent }   // swallow clicks inside the widget box

        StackView {
            id: widgetStack
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: function (event) {
                switchWidget("hidden", "");
                event.accepted = true;
            }
            // Q also closes the active widget. Handled at the StackView level so
            // the event only reaches here after bubbling up un-accepted — i.e. it
            // does NOT fire while a text field (wifi password, search, etc.) has
            // focus, where 'q' should type normally.
            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Q) {
                    switchWidget("hidden", "");
                    event.accepted = true;
                }
            }
            onCurrentItemChanged: { if (currentItem) currentItem.forceActiveFocus(); }

            replaceEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: masterWindow.morphDurationSwitch; easing.type: Easing.OutQuint }
                    NumberAnimation { property: "scale";   from: 0.98; to: 1.0; duration: masterWindow.morphDurationSwitch; easing.type: Easing.OutCubic }
                }
            }
            replaceExit: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: masterWindow.morphDurationSwitch; easing.type: Easing.InQuint }
                    NumberAnimation { property: "scale";   from: 1.0; to: 0.98; duration: masterWindow.morphDurationSwitch; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // ── widget switching ──────────────────────────────────────────────────────
    function switchWidget(newWidget, arg) {
        delayedClear.stop();

        if (newWidget === "hidden") {
            if (currentActive !== "hidden") {
                masterWindow.morphDuration = masterWindow.exitDuration;
                masterWindow.disableMorph = false;
                masterWindow.animW = 1;
                masterWindow.animH = 1;
                masterWindow.isVisible = false;
                delayedClear.start();
            }
        } else {
            if (currentActive === "hidden" || !masterWindow.isVisible) {
                masterWindow.morphDuration = 230;
                masterWindow.disableMorph = false;
                let t = getLayout(newWidget);
                masterWindow.animX = t.rx;
                masterWindow.animY = t.ry;
                masterWindow.animW = t.w;
                masterWindow.animH = t.h;
                masterWindow.targetW = t.w;
                masterWindow.targetH = t.h;
            } else {
                masterWindow.morphDuration = masterWindow.morphDurationSwitch;
                masterWindow.disableMorph = false;
            }
            Qt.callLater(() => executeSwitch(newWidget, arg));
        }
    }

    function executeSwitch(newWidget, arg) {
        masterWindow.currentActive = newWidget;
        masterWindow.activeArg = arg;

        let t = getLayout(newWidget);
        masterWindow.animX = t.rx;
        masterWindow.animY = t.ry;
        masterWindow.animW = t.w;
        masterWindow.animH = t.h;
        masterWindow.targetW = t.w;
        masterWindow.targetH = t.h;

        widgetStack.replace(Qt.resolvedUrl(t.comp), {
            "layoutWidth":  t.w,
            "layoutHeight": t.h,
            "requestClose": masterWindow.closeFn
        });

        let ci = widgetStack.currentItem;
        if (ci) {
            if (ci.notifModel !== undefined) ci.notifModel = masterWindow.notifModel;
            if (ci.liveNotifs !== undefined) ci.liveNotifs = masterWindow.liveNotifs;
            if (ci.targetMasterWidth !== undefined) {
                masterWindow.animW = ci.targetMasterWidth;
                masterWindow.targetW = ci.targetMasterWidth;
                masterWindow.animX = Math.floor((masterWindow.width / 2) - (ci.targetMasterWidth / 2));
            }
            if (ci.targetMasterHeight !== undefined) {
                masterWindow.animH = ci.targetMasterHeight;
                masterWindow.targetH = ci.targetMasterHeight;
            }
        }
        masterWindow.isVisible = true;
    }

    Timer {
        id: delayedClear
        interval: 200
        onTriggered: {
            masterWindow.currentActive = "hidden";
            widgetStack.clear();
            masterWindow.disableMorph = false;
        }
    }
}
