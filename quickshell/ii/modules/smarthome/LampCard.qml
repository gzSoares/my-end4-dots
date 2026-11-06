import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sysmonitor

/** Control card for one Tuya lamp: power, brightness, white temperature, colors, scenes. */
Rectangle {
    id: card

    required property var lamp
    property var wallpaperColors: []
    signal command(var cmd)

    readonly property bool online: lamp.online
    readonly property bool on: lamp.on && lamp.online
    readonly property color warm: "#ffb35c"
    readonly property color cool: "#d6e6ff"
    readonly property color lampColor: !on ? Appearance.m3colors.m3surfaceContainerHighest : lamp.mode === "color" ? lamp.color : Qt.rgba(warm.r + (cool.r - warm.r) * lamp.temp / 100, warm.g + (cool.g - warm.g) * lamp.temp / 100, warm.b + (cool.b - warm.b) * lamp.temp / 100, 1)
    readonly property string modeText: !online ? "Offline" : !lamp.on ? "Off" : lamp.mode === "color" ? "Color  ·  " + lamp.brightness + "%" : (lamp.temp < 30 ? "Warm white" : lamp.temp > 70 ? "Cool white" : "Neutral white") + "  ·  " + lamp.brightness + "%"

    readonly property var presets: ["#ff4d4d", "#ff9a3d", "#ffd84d", "#5bdc6e", "#3dd6d0", "#4d8bff", "#9a5bff", "#ff5bc8"]
    readonly property var scenes: [
        { key: "relax", label: "Relax", icon: "weekend" },
        { key: "read", label: "Read", icon: "menu_book" },
        { key: "focus", label: "Focus", icon: "center_focus_strong" },
        { key: "night", label: "Night", icon: "bedtime" },
        { key: "cinema", label: "Cinema", icon: "movie" },
        { key: "sunset", label: "Sunset", icon: "wb_twilight" }
    ]

    function send(cmd) {
        cmd.id = card.lamp.id;
        card.command(cmd);
    }

    implicitHeight: col.implicitHeight + 40
    radius: Appearance.rounding.large
    color: Appearance.colors.colLayer1
    border.width: 1
    border.color: Qt.rgba(Appearance.m3colors.m3outlineVariant.r, Appearance.m3colors.m3outlineVariant.g, Appearance.m3colors.m3outlineVariant.b, 0.35)
    clip: true

    // soft wash of the lamp's color from the top
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 220
        radius: card.radius
        opacity: card.on ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }
        }
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(card.lampColor.r, card.lampColor.g, card.lampColor.b, 0.22)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(card.lampColor.r, card.lampColor.g, card.lampColor.b, 0)
            }
        }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 16

        // ── header: big lamp button ─────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Rectangle {
                id: bulb
                implicitWidth: 84
                implicitHeight: 84
                radius: 42
                color: card.lampColor
                border.width: card.on ? 0 : 2
                border.color: Appearance.m3colors.m3outlineVariant
                opacity: card.online ? 1 : 0.5
                Behavior on color {
                    ColorAnimation {
                        duration: 300
                    }
                }
                scale: bulbMouse.pressed ? 0.94 : 1
                Behavior on scale {
                    NumberAnimation {
                        duration: 120
                    }
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: card.online ? "lightbulb" : "wifi_off"
                    iconSize: 40
                    color: card.on ? "#1a1a1a" : Appearance.colors.colSubtext
                }
                MouseArea {
                    id: bulbMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: card.online
                    onClicked: card.send({
                        cmd: "power",
                        on: !card.lamp.on
                    })
                }
            }

            ColumnLayout {
                Layout.maximumWidth: card.width - 240
                spacing: 2
                StyledText {
                    text: card.lamp.name
                    font.pixelSize: Appearance.font.pixelSize.huge
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: card.modeText
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: card.online ? Appearance.colors.colSubtext : Appearance.m3colors.m3error
                }
                StyledText {
                    visible: !card.online && card.lamp.error.length > 0
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: card.lamp.error
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
            }

            Item {
                Layout.fillWidth: true
            }
            SysSwitch {
                checked: card.lamp.on
                enabledState: card.online
                onToggled: on => card.send({
                    cmd: "power",
                    on: on
                })
            }
        }

        // ── controls (dimmed while off/offline) ─────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 14
            opacity: card.on ? 1 : 0.45
            enabled: card.online

            // brightness
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                MaterialSymbol {
                    text: "brightness_low"
                    iconSize: 20
                    color: Appearance.colors.colSubtext
                }
                SysSlider {
                    Layout.fillWidth: true
                    value: card.lamp.brightness
                    from: 1
                    to: 100
                    stepSize: 1
                    accent: card.on ? card.lampColor : Appearance.m3colors.m3primary
                    onMoved: v => card.send({
                        cmd: "brightness",
                        value: Math.round(v)
                    })
                }
                StyledText {
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                    text: card.lamp.brightness + "%"
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer1
                }
            }

            // white temperature
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                MaterialSymbol {
                    text: "thermostat"
                    iconSize: 20
                    color: Appearance.colors.colSubtext
                }
                SysSlider {
                    Layout.fillWidth: true
                    value: card.lamp.temp
                    from: 0
                    to: 100
                    stepSize: 1
                    useGradient: true
                    gradientFrom: card.warm
                    gradientTo: card.cool
                    onMoved: v => card.send({
                        cmd: "white",
                        temp: Math.round(v),
                        brightness: card.lamp.brightness
                    })
                }
                StyledText {
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                    text: card.lamp.mode === "white" ? (card.lamp.temp < 30 ? "warm" : card.lamp.temp > 70 ? "cool" : "mid") : "—"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            // hue
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                MaterialSymbol {
                    text: "palette"
                    iconSize: 20
                    color: Appearance.colors.colSubtext
                }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 12
                        radius: 6
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: "#ff0000"
                            }
                            GradientStop {
                                position: 0.17
                                color: "#ffff00"
                            }
                            GradientStop {
                                position: 0.33
                                color: "#00ff00"
                            }
                            GradientStop {
                                position: 0.5
                                color: "#00ffff"
                            }
                            GradientStop {
                                position: 0.67
                                color: "#0000ff"
                            }
                            GradientStop {
                                position: 0.83
                                color: "#ff00ff"
                            }
                            GradientStop {
                                position: 1.0
                                color: "#ff0000"
                            }
                        }
                    }
                    SysSlider {
                        anchors.fill: parent
                        value: card.lamp.mode === "color" ? Qt.color(card.lamp.color).hsvHue : 0
                        from: 0
                        to: 1
                        useGradient: true
                        gradientFrom: "transparent"
                        gradientTo: "transparent"
                        onMoved: v => card.send({
                            cmd: "color",
                            hex: Qt.hsva(Math.max(0, Math.min(0.999, v)), 1, 1, 1).toString(),
                            brightness: card.lamp.brightness
                        })
                    }
                }
                Item {
                    Layout.preferredWidth: 40
                }
            }

            // swatches
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: card.wallpaperColors.concat(card.presets)
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool fromWallpaper: index < card.wallpaperColors.length
                        width: 34
                        height: 34
                        radius: 17
                        color: modelData
                        border.width: swMouse.containsMouse ? 3 : fromWallpaper ? 2 : 0
                        border.color: fromWallpaper ? Appearance.m3colors.m3onSurface : Appearance.colors.colLayer2
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: parent.fromWallpaper
                            text: "wallpaper"
                            iconSize: 14
                            color: "#1a1a1a"
                        }
                        MouseArea {
                            id: swMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.send({
                                cmd: "color",
                                hex: String(parent.modelData),
                                brightness: Math.max(20, card.lamp.brightness)
                            })
                        }
                    }
                }
            }
        }

        // ── scenes (also turn the lamp on) ──────────────────────
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 8
            rowSpacing: 8
            enabled: card.online
            opacity: card.online ? 1 : 0.45
            Repeater {
                model: card.scenes
                delegate: SysButton {
                    required property var modelData
                    Layout.fillWidth: true
                    icon: modelData.icon
                    text: modelData.label
                    implicitHeight: 38
                    onClicked: card.send({
                        cmd: "scene",
                        name: modelData.key
                    })
                }
            }
        }
    }
}
