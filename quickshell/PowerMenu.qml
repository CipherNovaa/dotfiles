// Power menu widget — card row + arrow-key nav, ported from the earlier single-file
// shell.qml. Fills the fullscreen layout box; closes via requestClose (backdrop,
// Esc, or after running an action).
import QtQuick
import QtQuick.Layouts
import Quickshell

FocusScope {
    id: root
    focus: true

    property int  layoutWidth: 0
    property int  layoutHeight: 0
    property var  requestClose: (function () {})

    property int sel: 0
    readonly property var actions: [
        { label: "Shutdown", icon: "", cmd: ["systemctl", "poweroff"] },
        { label: "Reboot",   icon: "", cmd: ["systemctl", "reboot"] },
        { label: "Suspend",  icon: "", cmd: ["systemctl", "suspend"] },
        { label: "Log Out",  icon: "", cmd: ["loginctl", "terminate-user", ""] }
    ]

    MatugenColors { id: theme }

    function run(i) {
        const a = actions[i];
        if (a.label === "Log Out") Quickshell.execDetached(["hyprctl", "dispatch", "exit"]);
        else Quickshell.execDetached(a.cmd);
        root.requestClose();
    }

    Component.onCompleted: { sel = 0; root.forceActiveFocus(); }

    Keys.onPressed: function (e) {
        if (e.key === Qt.Key_Escape)      { root.requestClose(); e.accepted = true; }
        else if (e.key === Qt.Key_Left)   { sel = (sel + 3) % 4; e.accepted = true; }
        else if (e.key === Qt.Key_Right)  { sel = (sel + 1) % 4; e.accepted = true; }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { run(sel); e.accepted = true; }
    }

    // dim backdrop; click outside cards closes
    Rectangle {
        anchors.fill: parent
        color: theme.bg
        opacity: 0.55
        MouseArea { anchors.fill: parent; onClicked: root.requestClose() }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Session"
            color: theme.fg; font.bold: true; font.pixelSize: 18
            font.family: "Iosevka Nerd Font"
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18
            Repeater {
                model: root.actions
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    width: 120; height: 120; radius: 18
                    color: root.sel === index ? theme.accent : theme.card
                    border.color: root.sel === index ? theme.fg : theme.muted
                    border.width: 1
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.icon
                            color: root.sel === index ? theme.bg : theme.fg
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 34
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label
                            color: root.sel === index ? theme.bg : theme.fg
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onEntered: root.sel = index
                        onClicked: root.run(index)
                    }
                }
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "← → to move · Enter to select · Esc to cancel"
            color: theme.muted; font.pixelSize: 11
            font.family: "Iosevka Nerd Font"
        }
    }
}
