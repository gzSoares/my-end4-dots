import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sysmonitor

/** One output (sink) or input (source) device: set default, volume, mute, keep-awake. */
Rectangle {
    id: row

    required property PwNode node
    property bool isDefault: false
    property bool isInput: false
    property bool keepAwake: false
    property bool canKeepAwake: !isInput
    signal makeDefault
    signal toggleKeepAwake

    readonly property var props: node?.properties ?? ({})
    readonly property string displayName: node?.description || node?.nickname || node?.name || "Unknown device"
    readonly property real volume: node?.audio?.volume ?? 0
    readonly property bool muted: node?.audio?.muted ?? false
    readonly property string deviceIcon: {
        if (isInput)
            return "mic";
        const n = (node?.name ?? "").toLowerCase();
        const ff = (props["device.form-factor"] ?? "").toLowerCase();
        if (n.includes("bluez") || ff === "headset" || ff === "headphone")
            return "headphones";
        if (n.includes("hdmi") || n.includes("displayport") || n.includes("dp-"))
            return "desktop_windows";
        if (n.includes("usb"))
            return "usb";
        return "speaker";
    }
    readonly property string kindText: {
        const n = (node?.name ?? "").toLowerCase();
        if (n.includes("bluez"))
            return "Bluetooth";
        if (n.includes("hdmi"))
            return "HDMI / DisplayPort";
        if (n.includes("usb"))
            return "USB";
        if (n.startsWith("alsa"))
            return "Built-in";
        return "Virtual";
    }

    implicitHeight: col.implicitHeight + 24
    radius: Appearance.rounding.normal
    color: isDefault ? Appearance.m3colors.m3secondaryContainer : Appearance.colors.colLayer2
    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    readonly property color fg: isDefault ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
    readonly property color dim: isDefault ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colSubtext

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
            spacing: 10

            // default "radio"
            Item {
                implicitWidth: 22
                implicitHeight: 22
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: row.isDefault ? "radio_button_checked" : "radio_button_unchecked"
                    iconSize: 22
                    color: row.isDefault ? Appearance.m3colors.m3primary : row.dim
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.makeDefault()
                }
            }
            MaterialSymbol {
                text: row.deviceIcon
                iconSize: 22
                color: row.fg
            }
            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: row.displayName
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: row.fg
                }
                StyledText {
                    Layout.fillWidth: true
                    text: row.kindText + (row.isDefault ? "  ·  default" : "") + (row.keepAwake ? "  ·  always awake" : "")
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: row.dim
                }
            }
            SysButton {
                visible: row.canKeepAwake
                icon: row.keepAwake ? "bolt" : "power_settings_new"
                implicitHeight: 30
                implicitWidth: 30
                toggled: row.keepAwake
                color: row.keepAwake ? Appearance.m3colors.m3primary : "transparent"
                tooltip: "Never suspend this output"
                onClicked: row.toggleKeepAwake()
            }
            SysButton {
                icon: row.muted ? (row.isInput ? "mic_off" : "volume_off") : (row.isInput ? "mic" : "volume_up")
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
                accent: row.muted ? Appearance.colors.colSubtext : Appearance.m3colors.m3primary
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
                color: row.fg
            }
        }
    }
}
