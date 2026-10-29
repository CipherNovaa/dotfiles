// Volume OSD — standalone bottom-center overlay, auto-shows ~1.5s on a volume/mute
// change. Driven by the event-driven audio watcher (audio_wait.sh → audio_fetch.sh)
// rather than polling. Sibling of Main in shell.qml (not a dispatcher widget).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: osd
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-volume-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Float over everything; never reserve screen space (otherwise showing the OSD
    // shoves every tiled window up by implicitHeight). See "volume lifts the screen" bug.
    exclusionMode: ExclusionMode.Ignore

    anchors { bottom: true }
    margins { bottom: 90 }
    implicitWidth: 300
    implicitHeight: 60
    visible: shown

    readonly property string watchersDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers"

    property int     volume: 0
    property string  icon: "󰕾"
    property bool    muted: false
    property bool    ready: false   // suppress the OSD on the very first fetch
    property bool    shown: false

    MatugenColors { id: theme }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osd.shown = false
    }

    function apply(txt) {
        try {
            const d = JSON.parse(txt);
            const newVol = parseInt(d.volume);
            const newMuted = (d.is_muted === "true");
            const changed = (newVol !== osd.volume) || (newMuted !== osd.muted);
            osd.volume = newVol;
            osd.icon = d.icon;
            osd.muted = newMuted;
            // codec's player shows the change on its own OSD while it is up.
            if (osd.ready && changed && d.codec_owns !== "true") {
                osd.shown = true;
                hideTimer.restart();
            }
            osd.ready = true;
        } catch (e) { /* ignore malformed */ }
    }

    // FETCH: query current audio state, then arm the waiter
    Process {
        id: fetchProc
        command: ["bash", osd.watchersDir + "/audio_fetch.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                osd.apply(this.text);
                waitProc.running = false;
                waitProc.running = true;
            }
        }
    }

    // WAIT: blocks on `pactl subscribe` until a sink/server event, then exits
    Process {
        id: waitProc
        command: ["bash", osd.watchersDir + "/audio_wait.sh"]
        onExited: { fetchProc.running = false; fetchProc.running = true; }
    }

    Component.onCompleted: fetchProc.running = true

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: theme.bg
        border.color: theme.accent
        border.width: 1
        opacity: 0.97

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 14

            Text {
                text: osd.muted ? "󰝟" : osd.icon
                color: osd.muted ? theme.muted : theme.accent
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 24
            }

            Rectangle {  // track
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: theme.card
                Rectangle {  // fill
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    width: parent.width * Math.max(0, Math.min(100, osd.volume)) / 100
                    radius: 4
                    color: osd.muted ? theme.muted : theme.accent
                    Behavior on width { NumberAnimation { duration: 120 } }
                }
            }

            Text {
                text: osd.volume + "%"
                color: theme.fg
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 14
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
