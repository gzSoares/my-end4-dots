import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sysmonitor

/** One saved RDP connection: reachability, details, connect/disconnect, edit, duplicate, delete. */
Rectangle {
    id: card

    required property var conn
    property var session: null           // { started } when connected
    property var reachable: undefined    // true / false / undefined (checking)
    property bool hasPassword: false
    property real now: Date.now() / 1000
    signal connectRequested
    signal disconnectRequested
    signal showRequested
    signal editRequested
    signal duplicateRequested
    signal deleteRequested

    readonly property bool active: session !== null && session !== undefined
    property bool confirmDelete: false

    readonly property color statusColor: active ? Appearance.m3colors.m3primary : reachable === true ? "#6fd08c" : reachable === false ? Appearance.m3colors.m3outline : Appearance.m3colors.m3tertiary
    readonly property string statusText: active ? "Connected  ·  " + duration(now - session.started) : reachable === true ? "Online" : reachable === false ? "Unreachable" : "Checking…"

    function duration(s) {
        s = Math.max(0, Math.floor(s));
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : m > 0 ? `${m} min` : "just now";
    }
    function ago(ts) {
        if (!ts)
            return "Never used";
        const s = now - ts;
        if (s < 3600)
            return "Used " + Math.max(1, Math.floor(s / 60)) + " min ago";
        if (s < 86400)
            return "Used " + Math.floor(s / 3600) + " h ago";
        if (s < 86400 * 30)
            return "Used " + Math.floor(s / 86400) + " d ago";
        return "Used " + Qt.formatDate(new Date(ts * 1000), "dd/MM/yyyy");
    }

    implicitHeight: 176
    radius: Appearance.rounding.large
    color: active ? Appearance.m3colors.m3secondaryContainer : hover.hovered ? Qt.lighter(Appearance.colors.colLayer1, 1.12) : Appearance.colors.colLayer1
    border.width: 1
    border.color: active ? Appearance.m3colors.m3primary : Qt.rgba(Appearance.m3colors.m3outlineVariant.r, Appearance.m3colors.m3outlineVariant.g, Appearance.m3colors.m3outlineVariant.b, 0.35)
    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    readonly property color fg: active ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
    readonly property color dim: active ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colSubtext

    HoverHandler {
        id: hover
    }
    TapHandler {
        onDoubleTapped: card.active ? card.showRequested() : card.connectRequested()
    }
    Timer {
        id: delTimer
        interval: 3000
        onTriggered: card.confirmDelete = false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item {
                implicitWidth: 46
                implicitHeight: 46
                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: card.active ? Appearance.m3colors.m3primary : Qt.rgba(card.statusColor.r, card.statusColor.g, card.statusColor.b, 0.16)
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: card.active ? "cast_connected" : "desktop_windows"
                        iconSize: 24
                        color: card.active ? Appearance.m3colors.m3onPrimary : card.statusColor
                    }
                }
                Rectangle {
                    width: 13
                    height: 13
                    radius: 7
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: -2
                    color: card.statusColor
                    border.width: 2
                    border.color: card.color
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText {
                    Layout.fillWidth: true
                    text: card.conn.name
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: card.fg
                }
                StyledText {
                    Layout.fillWidth: true
                    text: (card.conn.user ? (card.conn.domain ? card.conn.domain + "\\" : "") + card.conn.user + "@" : "") + card.conn.host + (card.conn.port && card.conn.port !== 3389 ? ":" + card.conn.port : "")
                    elide: Text.ElideMiddle
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: card.dim
                }
            }
        }

        // chips
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [card.conn.group ? { i: "folder", t: card.conn.group } : null, { i: card.conn.display === "fullscreen" ? "fullscreen" : card.conn.display === "custom" ? "aspect_ratio" : "fit_screen", t: card.conn.display === "fullscreen" ? (card.conn.multimon ? "All monitors" : "Fullscreen") : card.conn.display === "custom" ? card.conn.width + "×" + card.conn.height : "Fit window" }, card.hasPassword ? { i: "key", t: "Saved" } : null, card.conn.shareFolder ? { i: "folder_shared", t: "Folder" } : null, card.conn.gateway ? { i: "vpn_lock", t: "Gateway" } : null].filter(x => x !== null)
                delegate: Rectangle {
                    required property var modelData
                    implicitHeight: 22
                    implicitWidth: chipRow.implicitWidth + 14
                    radius: 11
                    color: card.active ? Qt.rgba(0, 0, 0, 0.12) : Appearance.colors.colLayer2
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.i
                            iconSize: 13
                            color: card.dim
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.t
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: card.dim
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            ColumnLayout {
                spacing: 0
                StyledText {
                    text: card.statusText
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: card.active ? card.fg : card.statusColor
                }
                StyledText {
                    visible: !card.active
                    text: card.ago(card.conn.lastConnected)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: card.dim
                }
            }

            Item {
                Layout.fillWidth: true
            }
            SysButton {
                visible: !card.active
                icon: "edit"
                implicitWidth: 32
                implicitHeight: 32
                color: "transparent"
                onClicked: card.editRequested()
            }
            SysButton {
                visible: !card.active
                icon: "content_copy"
                implicitWidth: 32
                implicitHeight: 32
                color: "transparent"
                onClicked: card.duplicateRequested()
            }
            SysButton {
                visible: !card.active
                icon: "delete"
                text: card.confirmDelete ? "Delete?" : ""
                danger: card.confirmDelete
                implicitHeight: 32
                color: card.confirmDelete ? Appearance.m3colors.m3errorContainer : "transparent"
                onClicked: {
                    if (!card.confirmDelete) {
                        card.confirmDelete = true;
                        delTimer.restart();
                    } else {
                        card.confirmDelete = false;
                        card.deleteRequested();
                    }
                }
            }
            SysButton {
                visible: card.active
                icon: "open_in_new"
                text: "Show"
                implicitHeight: 34
                onClicked: card.showRequested()
            }
            SysButton {
                icon: card.active ? "close" : "play_arrow"
                text: card.active ? "Disconnect" : "Connect"
                tonal: !card.active
                danger: card.active
                implicitHeight: 34
                onClicked: card.active ? card.disconnectRequested() : card.connectRequested()
            }
        }
    }
}
