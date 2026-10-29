//@ pragma UseQApplication
// quickshell config — modular dispatcher shell (ported/adapted from
// github.com/ilyamiro/nixos-configuration, AGPL-3.0). Entrypoint only: the Main dispatcher owns the
// IPC + widget StackView. Live pywal theming lives in MatugenColors.qml.
//   qs ipc call main handleCommand <toggle|open|close> <widget> <arg>
//   qs ipc call media|power toggle   (compat shims; hyprland.lua + waybar use these)
import QtQuick
import Quickshell

ShellRoot {
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    Main {}
    VolumeOSD {}
}
