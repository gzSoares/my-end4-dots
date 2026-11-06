import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sysmonitor

/** One container: state, image, ports, live CPU sparkline/memory and actions. */
Rectangle {
    id: row

    required property var container
    property var cpuHistory: []
    property bool logsOpen: false
    signal action(string name)
    signal openLogs
    signal openTerminal

    readonly property string st: container.state
    readonly property bool running: st === "running"
    readonly property bool paused: st === "paused"
    property bool confirmRemove: false

    readonly property color stateColor: running ? Appearance.m3colors.m3primary : paused ? Appearance.m3colors.m3tertiary : Appearance.m3colors.m3outline
    readonly property string kindIcon: ({
            distrobox: "terminal",
            toolbox: "build",
            ollama: "smart_toy",
            pod: "workspaces"
        })[container.kind] || "deployed_code"

    implicitHeight: 74
    radius: Appearance.rounding.normal
    color: logsOpen ? Appearance.m3colors.m3secondaryContainer : hover.hovered ? Qt.lighter(Appearance.colors.colLayer2, 1.08) : Appearance.colors.colLayer2

    HoverHandler {
        id: hover
    }
    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: row.confirmRemove = false
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 12

        // kind icon with state dot
        Item {
            implicitWidth: 40
            implicitHeight: 40
            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: Qt.rgba(row.stateColor.r, row.stateColor.g, row.stateColor.b, 0.16)
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: row.kindIcon
                    iconSize: 22
                    color: row.stateColor
                }
            }
            Rectangle {
                width: 12
                height: 12
                radius: 6
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -2
                color: row.stateColor
                border.width: 2
                border.color: row.color
            }
        }

        // name / image / status
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            RowLayout {
                spacing: 8
                Layout.fillWidth: true
                StyledText {
                    text: row.container.name
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                    Layout.maximumWidth: 260
                }
                Rectangle {
                    visible: row.container.kind !== "container"
                    implicitHeight: 18
                    implicitWidth: kindText.implicitWidth + 12
                    radius: 9
                    color: Appearance.colors.colLayer1
                    StyledText {
                        id: kindText
                        anchors.centerIn: parent
                        text: row.container.kind
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: row.container.image
                elide: Text.ElideMiddle
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                text: [row.container.status].concat(row.container.ports).join("  ·  ")
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: row.running ? Appearance.m3colors.m3primary : Appearance.colors.colSubtext
            }
        }

        // live stats
        ColumnLayout {
            opacity: row.running ? 1 : 0
            spacing: 2
            Layout.preferredWidth: 110
            Layout.minimumWidth: 110
            Layout.maximumWidth: 110
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 26
                radius: 6
                color: Appearance.colors.colLayer1
                clip: true
                SysGraph {
                    anchors.fill: parent
                    values: row.cpuHistory
                    capacity: 30
                    showGrid: false
                    maxValue: 100
                    fillOpacity: 0.45
                }
            }
            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: row.container.cpu.toFixed(1) + "%"
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer1
                }
                Item {
                    Layout.fillWidth: true
                }
                StyledText {
                    text: formatBytes(row.container.mem)
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.m3colors.m3tertiary
                }
            }
        }

        // actions (fixed-width slot so the stats column lines up across rows)
        Item {
            Layout.preferredWidth: 256
            implicitHeight: 32
        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            SysButton {
                visible: !row.running && !row.paused
                icon: "play_arrow"
                tonal: true
                implicitHeight: 32
                implicitWidth: 32
                onClicked: row.action("start")
            }
            SysButton {
                visible: row.running
                icon: "stop"
                implicitHeight: 32
                implicitWidth: 32
                onClicked: row.action("stop")
            }
            SysButton {
                visible: row.running
                icon: "restart_alt"
                implicitHeight: 32
                implicitWidth: 32
                onClicked: row.action("restart")
            }
            SysButton {
                visible: row.running || row.paused
                icon: row.paused ? "resume" : "pause"
                implicitHeight: 32
                implicitWidth: 32
                onClicked: row.action(row.paused ? "unpause" : "pause")
            }
            SysButton {
                icon: "terminal"
                implicitHeight: 32
                implicitWidth: 32
                enabledState: row.running || row.container.kind === "distrobox" || row.container.kind === "toolbox"
                onClicked: row.openTerminal()
            }
            SysButton {
                icon: "article"
                implicitHeight: 32
                implicitWidth: 32
                toggled: row.logsOpen
                onClicked: row.openLogs()
            }
            SysButton {
                icon: "delete"
                text: row.confirmRemove ? "Remove?" : ""
                danger: row.confirmRemove
                implicitHeight: 32
                onClicked: {
                    if (!row.confirmRemove) {
                        row.confirmRemove = true;
                        confirmTimer.restart();
                    } else {
                        row.confirmRemove = false;
                        row.action("remove");
                    }
                }
            }
        }
        }
    }

    function formatBytes(b) {
        const u = ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (b >= 1024 && i < u.length - 1) {
            b /= 1024;
            i++;
        }
        return (i === 0 ? Math.round(b) : b.toFixed(b >= 100 ? 0 : 1)) + " " + u[i];
    }
}
