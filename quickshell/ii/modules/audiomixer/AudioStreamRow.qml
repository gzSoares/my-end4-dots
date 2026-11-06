import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sysmonitor

/** One application stream (playback or recording): icon, volume, mute, and "send to" device chips. */
Rectangle {
    id: row

    required property PwNode node
    property var targets: []          // sinks (or sources) the stream can be moved to
    property bool isRecording: false
    signal moveTo(PwNode target)

    readonly property var props: node?.properties ?? ({})
    readonly property string appName: props["application.name"] || node?.description || node?.name || "Application"
    readonly property string mediaName: props["media.name"] ?? ""
    readonly property string iconName: (props["application.icon-name"] || props["application.process.binary"] || appName || "").toLowerCase()
    readonly property string iconPath: iconName.length > 0 ? Quickshell.iconPath(iconName, true) : ""
    readonly property real volume: node?.audio?.volume ?? 0
    readonly property bool muted: node?.audio?.muted ?? false
    property bool expanded: false

    PwNodeLinkTracker {
        id: links
        node: row.node
    }
    readonly property var currentTargets: {
        const out = [];
        const groups = links.linkGroups ?? [];
        for (let i = 0; i < groups.length; i++) {
            const g = groups[i];
            const other = row.isRecording ? g.source : g.target;
            if (other && out.indexOf(other.id) < 0)
                out.push(other.id);
        }
        return out;
    }
    readonly property string currentTargetName: {
        for (let i = 0; i < targets.length; i++)
            if (currentTargets.indexOf(targets[i].id) >= 0)
                return targets[i].description || targets[i].nickname || targets[i].name;
        return "";
    }

    implicitHeight: col.implicitHeight + 24
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // app icon
            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1
                Image {
                    id: appIcon
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    sourceSize: Qt.size(56, 56)
                    source: row.iconPath ? (row.iconPath.startsWith("/") ? "file://" + row.iconPath : row.iconPath) : ""
                    visible: status === Image.Ready
                    smooth: true
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: appIcon.status !== Image.Ready
                    text: row.isRecording ? "mic" : "music_note"
                    iconSize: 22
                    color: Appearance.m3colors.m3primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: row.appName
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: [row.mediaName, row.currentTargetName ? (row.isRecording ? "from " : "→ ") + row.currentTargetName : ""].filter(s => s.length > 0).join("  ·  ")
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
            }

            SysButton {
                visible: row.targets.length > 1
                icon: "swap_horiz"
                implicitHeight: 30
                implicitWidth: 30
                toggled: row.expanded
                color: row.expanded ? Appearance.m3colors.m3secondaryContainer : "transparent"
                onClicked: row.expanded = !row.expanded
            }
            SysButton {
                icon: row.muted ? "volume_off" : "volume_up"
                implicitHeight: 30
                implicitWidth: 30
                danger: row.muted
                color: row.muted ? Appearance.m3colors.m3errorContainer : "transparent"
                onClicked: if (row.node?.audio)
                    row.node.audio.muted = !row.node.audio.muted
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            SysSlider {
                Layout.fillWidth: true
                value: row.volume
                to: 1
                accent: row.muted ? Appearance.colors.colSubtext : Appearance.m3colors.m3tertiary
                onMoved: v => {
                    if (row.node?.audio)
                        row.node.audio.volume = v;
                }
            }
            StyledText {
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                text: Math.round(row.volume * 100) + "%"
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
            }
        }

        // send-to chips
        Flow {
            Layout.fillWidth: true
            visible: row.expanded
            spacing: 6
            StyledText {
                text: row.isRecording ? "Record from:" : "Play on:"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                height: 30
                verticalAlignment: Text.AlignVCenter
            }
            Repeater {
                model: row.targets
                delegate: SysButton {
                    required property var modelData
                    readonly property bool current: row.currentTargets.indexOf(modelData.id) >= 0
                    icon: current ? "check" : ""
                    text: modelData.description || modelData.nickname || modelData.name
                    implicitHeight: 30
                    toggled: current
                    onClicked: {
                        row.moveTo(modelData);
                        row.expanded = false;
                    }
                }
            }
        }
    }
}
