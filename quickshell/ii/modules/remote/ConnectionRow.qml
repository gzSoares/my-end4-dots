import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sysmonitor

/** Compact list row for one RDP connection (list view of the Remote Desktop app). */
Rectangle {
    id: row

    required property var conn
    property var session: null
    property var reachable: undefined
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
    readonly property string statusText: active ? "Connected · " + duration(now - session.started) : reachable === true ? "Online" : reachable === false ? "Unreachable" : "Checking…"
    readonly property color fg: active ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
    readonly property color dim: active ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colSubtext

    function duration(s) {
        s = Math.max(0, Math.floor(s));
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : m > 0 ? `${m} min` : "just now";
    }
    function displayText() {
        const d = row.conn.display;
        if (d === "fullscreen")
            return row.conn.multimon ? "All monitors" : "Fullscreen";
        if (d === "custom")
            return row.conn.width + "×" + row.conn.height;
        return "Fit window";
    }

    implicitHeight: 58
    radius: Appearance.rounding.normal
    color: active ? Appearance.m3colors.m3secondaryContainer : hover.hovered ? Qt.lighter(Appearance.colors.colLayer1, 1.12) : Appearance.colors.colLayer1
    border.width: active ? 1 : 0
    border.color: Appearance.m3colors.m3primary

    HoverHandler {
        id: hover
    }
    TapHandler {
        onDoubleTapped: row.active ? row.showRequested() : row.connectRequested()
    }
    Timer {
        id: delTimer
        interval: 3000
        onTriggered: row.confirmDelete = false
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 12

        Item {
            implicitWidth: 34
            implicitHeight: 34
            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: row.active ? Appearance.m3colors.m3primary : Qt.rgba(row.statusColor.r, row.statusColor.g, row.statusColor.b, 0.16)
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: row.active ? "cast_connected" : "desktop_windows"
                    iconSize: 19
                    color: row.active ? Appearance.m3colors.m3onPrimary : row.statusColor
                }
            }
            Rectangle {
                width: 11
                height: 11
                radius: 6
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -2
                color: row.statusColor
                border.width: 2
                border.color: row.color
            }
        }

        // name
        StyledText {
            Layout.preferredWidth: 200
            text: row.conn.name
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.DemiBold
            color: row.fg
        }
        // user@host
        StyledText {
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            text: (row.conn.user ? (row.conn.domain ? row.conn.domain + "\\" : "") + row.conn.user + "@" : "") + row.conn.host + (row.conn.port && row.conn.port !== 3389 ? ":" + row.conn.port : "")
            elide: Text.ElideMiddle
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: row.dim
        }
        // group + display
        StyledText {
            Layout.preferredWidth: 110
            visible: row.width > 900
            text: row.conn.group || "—"
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: row.dim
        }
        StyledText {
            Layout.preferredWidth: 96
            visible: row.width > 780
            text: row.displayText()
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: row.dim
        }
        Item {
            visible: row.width > 700
            implicitWidth: 16
            implicitHeight: 16
            MaterialSymbol {
                anchors.centerIn: parent
                visible: row.hasPassword
                text: "key"
                iconSize: 15
                color: row.dim
            }
        }
        // status
        StyledText {
            Layout.preferredWidth: 130
            text: row.statusText
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Medium
            color: row.active ? row.fg : row.statusColor
        }

        // actions (fixed slot so columns line up)
        Item {
            Layout.preferredWidth: 250
            implicitHeight: 34
            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                SysButton {
                    visible: !row.active
                    icon: "edit"
                    implicitWidth: 30
                    implicitHeight: 30
                    color: "transparent"
                    onClicked: row.editRequested()
                }
                SysButton {
                    visible: !row.active
                    icon: "content_copy"
                    implicitWidth: 30
                    implicitHeight: 30
                    color: "transparent"
                    onClicked: row.duplicateRequested()
                }
                SysButton {
                    visible: !row.active
                    icon: "delete"
                    text: row.confirmDelete ? "Delete?" : ""
                    danger: row.confirmDelete
                    implicitHeight: 30
                    color: row.confirmDelete ? Appearance.m3colors.m3errorContainer : "transparent"
                    onClicked: {
                        if (!row.confirmDelete) {
                            row.confirmDelete = true;
                            delTimer.restart();
                        } else {
                            row.confirmDelete = false;
                            row.deleteRequested();
                        }
                    }
                }
                SysButton {
                    visible: row.active
                    icon: "open_in_new"
                    text: "Show"
                    implicitHeight: 32
                    onClicked: row.showRequested()
                }
                SysButton {
                    icon: row.active ? "close" : "play_arrow"
                    text: row.active ? "Disconnect" : "Connect"
                    tonal: !row.active
                    danger: row.active
                    implicitHeight: 32
                    onClicked: row.active ? row.disconnectRequested() : row.connectRequested()
                }
            }
        }
    }
}
