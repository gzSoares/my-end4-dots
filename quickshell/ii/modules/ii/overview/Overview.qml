import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope

    // Dismiss in-surface (backdrop + Escape), not the shared focus grab: the
    // always-alive full-screen surface already captures outside clicks.

    // One overview per screen: surfaces are torn down and rebuilt with their
    // output, so a DP re-train across suspend/DPMS can't orphan the window.
    Variants {
        id: overviewVariants
        model: Quickshell.screens

    PanelWindow {
        id: panelWindow
        required property ShellScreen modelData
        screen: modelData
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
        property bool monitorIsFocused: ((Hyprland.focusedMonitor?.id ?? monitor?.id) === monitor?.id)

        // When Config.options.overview.keepSurfaceAlive is true (default),
        // the layer-shell surface stays allocated so every open is instant.
        // While closed, contentFade.opacity=0 hides the contents and an empty
        // mask Region routes all pointer input through to apps below.
        visible: (Config.options.overview.keepSurfaceAlive ?? true)
            || GlobalStates.overviewOpen
            || contentFade.opacity > 0

        // null mask = capture (open), empty Region = click-through (closed).
        // Gate on overviewOpen only, NOT the fade-out opacity — capturing while
        // contentFade fades out swallowed the next click (dead dock button).
        mask: (GlobalStates.overviewOpen && monitorIsFocused)
            ? null
            : passthroughRegion
        Region { id: passthroughRegion }

        WlrLayershell.namespace: "quickshell:overview"
        // Overlay layer so the surface stays visible above fullscreen apps.
        WlrLayershell.layer: WlrLayer.Overlay
        // Exclusive while open holds the keyboard (Escape, arrows).
        WlrLayershell.keyboardFocus: (GlobalStates.overviewOpen && monitorIsFocused) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        // Full-screen so the dim overlay covers app windows behind the overview.
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        // The surface lies under every place a click can land, bar and dock included.
        exclusionMode: ExclusionMode.Ignore

        Connections {
            target: GlobalStates
            function onOverviewOpenChanged() {
                // Take the keyboard so Escape and the arrows reach keyHandler.
                if (GlobalStates.overviewOpen)
                    Qt.callLater(() => keyHandler.forceActiveFocus());
            }
        }

        // Wraps all content so a single opacity animation fades everything together
        Item {
            id: contentFade
            anchors.fill: parent
            opacity: (GlobalStates.overviewOpen && panelWindow.monitorIsFocused) ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            // Backdrop: any click that does not land on a widget closes the overview.
            MouseArea {
                anchors.fill: parent
                enabled: GlobalStates.overviewOpen
                onClicked: GlobalStates.overviewOpen = false
            }

            // The corner that opened this cannot close it (the pointer stops
            // reaching the hot corner's surface while the overview is up), so
            // this answers in the same rectangle, on the same dwell.
            // Armed by leaving: the pointer is already in the corner when the
            // overview opens, and closing on that would shut it instantly.
            MouseArea {
                id: cornerClose
                z: 100
                x: 0
                y: 0
                width: Appearance.sizes.hotCornerWidth
                height: Appearance.sizes.hotCornerHeight
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                enabled: GlobalStates.overviewOpen
                    && (Config.options?.bar.hotCorners.trigger ?? "off") === "default"
                property bool armed: false
                onEnabledChanged: armed = enabled && !containsMouse
                onExited: {
                    cornerCloseDwell.stop();
                    armed = true;
                }
                onEntered: if (armed) cornerCloseDwell.restart()
                Timer {
                    id: cornerCloseDwell
                    interval: 50
                    onTriggered: {
                        GlobalStates.hotCornerTriggered();
                        GlobalStates.overviewOpen = false;
                    }
                }
            }

            // Keyboard: Escape closes, Left/Right switch workspace.
            Item {
                id: keyHandler
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.overviewOpen = false;
                    } else if (event.key === Qt.Key_Left) {
                        Hyprland.dispatch(`hl.dsp.focus({ workspace = "r-1" })`);
                    } else if (event.key === Qt.Key_Right) {
                        Hyprland.dispatch(`hl.dsp.focus({ workspace = "r+1" })`);
                    }
                }
            }

            // Centered on the real screen center (ignores bar/dock clearance).
            Loader {
                id: overviewLoader
                anchors.centerIn: parent
                active: GlobalStates.overviewOpen
                    && panelWindow.monitorIsFocused
                    && (Config?.options.overview.enable ?? true)
                sourceComponent: OverviewWidget {
                    screen: panelWindow.screen
                }
            }
        }   // end contentFade

    }   // end PanelWindow

    }   // end Variants

    IpcHandler {
        target: "search"

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function workspacesToggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
    }

    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles overview on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"

        onPressed: {
            GlobalStates.overviewOpen = false;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles overview on release"

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of overview being toggled on release. " + "This is necessary because GlobalShortcut.onReleased in quickshell triggers whether or not you press something else while holding the key. " + "To make sure this works consistently, use binditn = MODKEYS, catchall in an automatically triggered submap that includes everything."

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
        }
    }
}