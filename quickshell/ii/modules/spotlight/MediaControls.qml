import QtQuick

// Pill with the media controls: previous / play-pause / next.
// Usage: MediaControls { fg: ...; playing: ...; onAction: (cmd) => ... }
// cmd = "previous" | "play-pause" | "next"
Rectangle {
    id: pill

    property color fg: "#ffffff"
    property bool playing: false
    readonly property int animDuration: 100

    signal action(string cmd)

    height: 36
    width: row.width + 8
    radius: height / 2
    color: Qt.rgba(0, 0, 0, 0.20)
    border.color: Qt.rgba(1, 1, 1, 0.10)
    border.width: 1

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: ["previous", "play-pause", "next"]

            delegate: Item {
                id: btn

                readonly property string cmd: modelData
                readonly property bool isMain: cmd === "play-pause"
                // main button: filled with the text color, icon in the opposite color
                readonly property color iconColor: isMain
                    ? (Qt.color(pill.fg).hslLightness > 0.5 ? "#16181d" : "#ffffff")
                    : pill.fg

                width: isMain ? 32 : 28
                height: width
                scale: ma.pressed ? 0.9 : (ma.containsMouse ? 1.08 : 1.0)
                Behavior on scale { NumberAnimation { duration: pill.animDuration; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: btn.isMain ? pill.fg : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : "transparent")
                    opacity: btn.isMain && !ma.containsMouse ? 0.92 : 1.0
                    Behavior on color { ColorAnimation { duration: pill.animDuration } }
                    Behavior on opacity { NumberAnimation { duration: pill.animDuration } }
                }

                MediaGlyph {
                    anchors.centerIn: parent
                    kind: btn.isMain ? (pill.playing ? "pause" : "play") : btn.cmd
                    fg: btn.iconColor
                    opacity: btn.isMain || ma.containsMouse ? 1.0 : 0.85
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.action(btn.cmd)
                }
            }
        }
    }
}
