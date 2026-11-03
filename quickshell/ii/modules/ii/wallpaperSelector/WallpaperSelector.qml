import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    Loader {
        id: wallpaperSelectorLoader
        active: GlobalStates.wallpaperSelectorOpen

        sourceComponent: PanelWindow {
            id: panelWindow
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
            property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
            // The screen is chosen before the window exists, so the picker is
            // sized for it from the first frame: the monitor it picks for, or
            // the focused one. Opened any other way, the compositor places it.
            screen: GlobalStates.wallpaperSelectorScreen

            // Drives the intro animation
            property bool shown: false

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:wallpaperSelector"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            // Full-screen overlay: the scrim dims the desktop and a click on it
            // closes the picker. The panel itself is centered.
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // On a portrait screen the panel takes the screen's width and a
            // fraction of its height instead of a fixed landscape size.
            readonly property bool portrait: panelWindow.height > panelWindow.width
            readonly property real gaps: Appearance.sizes.hyprlandGapsOut

            Component.onCompleted: {
                GlobalFocusGrab.addDismissable(panelWindow);
                panelWindow.shown = true;
            }
            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.wallpaperSelectorOpen = false;
                }
            }

            Rectangle {
                id: scrim
                anchors.fill: parent
                color: "#000000"
                opacity: panelWindow.shown ? 0.38 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.wallpaperSelectorOpen = false
            }

            WallpaperSelectorContent {
                id: content
                anchors.centerIn: parent
                monitorIsFocused: panelWindow.monitorIsFocused

                width: Math.min(1240, panelWindow.width - panelWindow.gaps * 4)
                height: panelWindow.portrait
                    ? Math.min(panelWindow.height * 0.6, 960)
                    : Math.min(640, panelWindow.height - panelWindow.gaps * 4)

                opacity: panelWindow.shown ? 1 : 0
                scale: panelWindow.shown ? 1 : 0.96
                transformOrigin: Item.Center
                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
                }
            }
        }
    }

    // A monitor's own picture is drawn by the background layer as a still,
    // so the picker leaves videos out while it chooses one.
    Binding {
        target: Wallpapers
        property: "imagesOnly"
        value: GlobalStates.wallpaperSelectorMonitor !== ""
    }

    // The monitor it was opened for can stop being one with a picture of its
    // own while the picker is up, by becoming the default monitor or being
    // unplugged. The picker closes then rather than refusing every pick, and
    // does not turn to the main wallpaper, where the next click would retheme.
    readonly property bool monitorTargetGone: GlobalStates.wallpaperSelectorOpen
        && GlobalStates.wallpaperSelectorMonitor !== ""
        && !MonitorWallpapers.isOtherMonitor(GlobalStates.wallpaperSelectorMonitor)
    onMonitorTargetGoneChanged: if (root.monitorTargetGone) GlobalStates.wallpaperSelectorOpen = false

    function toggleWallpaperSelector() {
        if (Config.options.wallpaperSelector.useSystemFileDialog) {
            Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode);
            return;
        }
        if (!GlobalStates.wallpaperSelectorOpen)
            GlobalStates.wallpaperSelectorScreen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null;
        GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen
    }

    IpcHandler {
        target: "wallpaperSelector"

        function toggle(): void {
            root.toggleWallpaperSelector();
        }

        function random(): void {
            Wallpapers.randomFromCurrentFolder();
        }
    }

    GlobalShortcut {
        name: "wallpaperSelectorToggle"
        description: "Toggle wallpaper selector"
        onPressed: {
            root.toggleWallpaperSelector();
        }
    }

    GlobalShortcut {
        name: "wallpaperSelectorRandom"
        description: "Select random wallpaper in current folder"
        onPressed: {
            Wallpapers.randomFromCurrentFolder();
        }
    }
}
