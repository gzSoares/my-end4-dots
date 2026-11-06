import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sysmonitor

/**
 * Floating quick switcher for RDP sessions — sits in the top-right corner of a session
 * window (geometry comes from Hyprland via the backend). Click a connection: opens it,
 * or brings its window to front.
 */
PanelWindow {
    id: sw

    required property var service     // the RemoteApp Scope (connections, sessions, send(), …)
    required property string windowId // connection id of the session window we sit on
    property bool expanded: false

    readonly property var geo: (service.sessionWindows || {})[windowId] || ({ x: 0, y: 0, w: 0, h: 0, monitor: "" })
    screen: {
        for (const s of Quickshell.screens)
            if (s.name === geo.monitor)
                return s;
        return Quickshell.screens[0];
    }
    visible: geo.w > 0

    WlrLayershell.namespace: "quickshell:remoteSwitcher"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        left: true
    }
    margins {
        top: Math.max(0, geo.y + 10)
        left: Math.max(0, geo.x + geo.w - implicitWidth - 10)
    }
    color: "transparent"
    implicitWidth: expanded ? 340 : 52
    implicitHeight: expanded ? Math.min(560, panel.implicitHeight + 24) : 52

    function collapseSoon() {
        collapseTimer.restart();
    }
    Timer {
        id: collapseTimer
        interval: 1400
        onTriggered: if (!area.containsMouse)
            sw.expanded = false
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onExited: sw.collapseSoon()
        onEntered: collapseTimer.stop()
    }

    // ── collapsed bubble ───────────────────────────────────────
    Rectangle {
        visible: !sw.expanded
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(Appearance.m3colors.m3primaryContainer.r, Appearance.m3colors.m3primaryContainer.g, Appearance.m3colors.m3primaryContainer.b, bubbleMouse.containsMouse ? 1 : 0.85)
        border.width: 1
        border.color: Appearance.m3colors.m3outlineVariant

        MaterialSymbol {
            anchors.centerIn: parent
            text: "connected_tv"
            iconSize: 24
            color: Appearance.m3colors.m3onPrimaryContainer
        }
        Rectangle {
            visible: sw.service.activeCount > 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: -2
            width: 20
            height: 20
            radius: 10
            color: Appearance.m3colors.m3primary
            StyledText {
                anchors.centerIn: parent
                text: sw.service.activeCount
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.Bold
                color: Appearance.m3colors.m3onPrimary
            }
        }
        MouseArea {
            id: bubbleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.expanded = true
        }
    }

    // ── expanded panel ─────────────────────────────────────────
    Rectangle {
        id: panelBg
        visible: sw.expanded
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Qt.rgba(Appearance.colors.colLayer1.r, Appearance.colors.colLayer1.g, Appearance.colors.colLayer1.b, 1)
        border.width: 1
        border.color: Appearance.m3colors.m3outlineVariant
        clip: true

        ColumnLayout {
            id: panel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MaterialSymbol {
                    text: "connected_tv"
                    iconSize: 20
                    color: Appearance.m3colors.m3primary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "Remote sessions"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                SysButton {
                    icon: "apps"
                    text: "App"
                    implicitHeight: 28
                    onClicked: {
                        sw.service.showApp();
                        sw.expanded = false;
                    }
                }
                SysButton {
                    icon: "open_in_full"
                    implicitWidth: 28
                    implicitHeight: 28
                    color: "transparent"
                    onClicked: {
                        sw.service.showApp();
                        sw.expanded = false;
                    }
                }
                SysButton {
                    icon: "close"
                    implicitWidth: 28
                    implicitHeight: 28
                    color: "transparent"
                    onClicked: sw.expanded = false
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(470, list.implicitHeight)
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: list
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: sw.service.sortedConnections
                        delegate: Rectangle {
                            id: item
                            required property var modelData
                            readonly property bool active: !!sw.service.sessions[modelData.id]
                            readonly property var reach: sw.service.reach[modelData.id]
                            readonly property color dot: active ? Appearance.m3colors.m3primary : reach === true ? "#6fd08c" : reach === false ? Appearance.m3colors.m3outline : Appearance.m3colors.m3tertiary
                            Layout.fillWidth: true
                            implicitHeight: 46
                            radius: Appearance.rounding.small
                            color: active ? Appearance.m3colors.m3secondaryContainer : itemMouse.containsMouse ? Appearance.colors.colLayer2 : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10
                                Rectangle {
                                    implicitWidth: 10
                                    implicitHeight: 10
                                    radius: 5
                                    color: item.dot
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: item.modelData.name
                                        elide: Text.ElideRight
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: Font.Medium
                                        color: item.active ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: item.modelData.host
                                        elide: Text.ElideMiddle
                                        font.family: Appearance.font.family.monospace
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: item.active ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colSubtext
                                    }
                                }
                                Rectangle {
                                    implicitHeight: 24
                                    implicitWidth: actionText.implicitWidth + 18
                                    radius: 12
                                    color: item.active ? Appearance.m3colors.m3primary : Appearance.colors.colLayer2
                                    RowLayout {
                                        id: actionText
                                        anchors.centerIn: parent
                                        spacing: 4
                                        MaterialSymbol {
                                            text: item.active ? "open_in_new" : "play_arrow"
                                            iconSize: 14
                                            color: item.active ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                                        }
                                        StyledText {
                                            text: item.active ? "Show" : "Open"
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            font.weight: Font.Medium
                                            color: item.active ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    sw.service.openOrFocus(item.modelData.id);
                                    sw.expanded = false;
                                }
                            }
                        }
                    }
                }
            }
            Item {
                implicitHeight: 2
            }
        }
    }
}
