// Media popup widget — YT-Music-style vinyl spinner, ported from the earlier single-file
// shell.qml into the dispatcher. Loaded into the StackView; fills the layout box.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.Mpris

Item {
    id: root

    // dispatcher-injected props
    property int  layoutWidth: 300
    property int  layoutHeight: 150
    property var  requestClose: (function () {})

    MatugenColors { id: theme }

    // Sticky reference to whichever player we last resolved to, so the popup
    // doesn't flip-flop between sources when more than one player is open.
    property var preferred: null

    // active MPRIS player. Priority:
    //   1. the sticky player, if it still exists and is playing
    //   2. otherwise the first player that is playing
    //   3. otherwise the sticky player, even if paused
    //   4. otherwise the first available player
    readonly property MprisPlayer player: {
        const ps = Mpris.players.values;
        if (ps.length === 0) return null;
        if (root.preferred && ps.indexOf(root.preferred) >= 0 && root.preferred.isPlaying)
            return root.preferred;
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i];
        if (root.preferred && ps.indexOf(root.preferred) >= 0) return root.preferred;
        return ps[0];
    }

    // Remember the resolved player so the choice above stays stable.
    onPlayerChanged: if (player) preferred = player;

    function fmtTime(sec) {
        if (!sec || sec < 0) sec = 0;
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Timer {
        running: root.player && root.player.isPlaying
        interval: 1000; repeat: true
        onTriggered: posText.text = root.fmtTime(root.player ? root.player.position : 0)
                                    + " - " + root.fmtTime(root.player ? root.player.length : 0)
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: theme.bg
        border.color: theme.accent
        border.width: 1
        opacity: 0.96

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            // spinning vinyl record with circular album art
            Item {
                id: artBox
                Layout.preferredWidth: 100
                Layout.preferredHeight: 100
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    color: "#141414"; border.color: theme.muted; border.width: 1
                }
                Repeater {
                    model: [0.86, 0.70, 0.54]
                    delegate: Rectangle {
                        required property var modelData
                        anchors.centerIn: parent
                        width: artBox.width * modelData; height: width; radius: width / 2
                        color: "transparent"
                        border.color: Qt.rgba(1, 1, 1, 0.05); border.width: 1
                    }
                }
                Item {
                    id: spinner
                    anchors.centerIn: parent
                    width: 88; height: 88
                    transformOrigin: Item.Center
                    RotationAnimation on rotation {
                        running: root.player && root.player.isPlaying
                        from: 0; to: 360; duration: 6000; loops: Animation.Infinite
                    }
                    Image {
                        id: art
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                        visible: false
                    }
                    Rectangle {
                        id: artMask
                        anchors.fill: parent; radius: width / 2
                        visible: false; layer.enabled: true
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: art
                        maskEnabled: true
                        maskSource: artMask
                        visible: art.status === Image.Ready
                    }
                    Rectangle {
                        anchors.fill: parent; radius: width / 2
                        color: theme.accent2
                        visible: art.status !== Image.Ready
                    }
                }
                Rectangle {
                    anchors.centerIn: parent; width: 14; height: 14; radius: 7
                    color: theme.bg; border.color: theme.muted; border.width: 1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    Layout.fillWidth: true; elide: Text.ElideRight
                    text: root.player ? root.player.trackTitle : "Nothing playing"
                    color: theme.fg; font.pixelSize: 15; font.bold: true
                    font.family: "Iosevka Nerd Font"
                }
                Text {
                    Layout.fillWidth: true; elide: Text.ElideRight
                    text: root.player ? root.player.trackArtist : ""
                    color: theme.muted; font.pixelSize: 12
                    font.family: "Iosevka Nerd Font"
                }
                Text {
                    id: posText
                    text: root.fmtTime(root.player ? root.player.position : 0)
                          + " - " + root.fmtTime(root.player ? root.player.length : 0)
                    color: theme.accent; font.pixelSize: 12
                    font.family: "Iosevka Nerd Font"
                }

                RowLayout {
                    Layout.topMargin: 4
                    spacing: 10
                    Repeater {
                        model: [
                            { ic: "", act: "prev" },
                            { ic: "5", act: "rw" },
                            { ic: "play",     act: "toggle" },
                            { ic: "5", act: "ff" },
                            { ic: "", act: "next" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isPlay: modelData.act === "toggle"
                            width: isPlay ? 36 : 26
                            height: width; radius: width / 2
                            color: isPlay ? theme.accent : (ma.containsMouse ? theme.accent : theme.card)
                            Text {
                                anchors.centerIn: parent
                                text: modelData.ic === "play"
                                      ? (root.player && root.player.isPlaying ? "" : "")
                                      : modelData.ic
                                color: (parent.isPlay || ma.containsMouse) ? theme.bg : theme.fg
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: modelData.act === "rw" || modelData.act === "ff" ? 11 : 14
                            }
                            MouseArea {
                                id: ma; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    const p = root.player; if (!p) return;
                                    switch (modelData.act) {
                                        case "prev":   p.previous(); break;
                                        case "next":   p.next(); break;
                                        case "toggle": p.togglePlaying(); break;
                                        case "rw":     if (p.canSeek) p.position = Math.max(0, p.position - 5); break;
                                        case "ff":     if (p.canSeek) p.position = Math.min(p.length, p.position + 5); break;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
