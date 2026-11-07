import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import QtMultimedia
import QtQuick.Shapes
import QtQuick.Effects
import qs.services
import qs.modules.common


PanelWindow {
    id: root

    // =====================================================================
    //  BUILT-IN COMPONENTS (inline, so the whole Spotlight lives in this one file)
    // =====================================================================

    component SiriOrb: Item {
        id: orb
        property real size: 26
        property color accentColor: "#5E5CE6"
        property bool active: false
        property bool showRing: true
        implicitWidth: size
        implicitHeight: size

        Rectangle {
            anchors.centerIn: parent
            width: orb.size * 0.9; height: orb.size * 0.9
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, orb.size * 0.077)
            border.color: orb.active ? Qt.rgba(0.6, 0.3, 1.0, 0.7) : Qt.rgba(0.5, 0.3, 0.9, 0.25)
            SequentialAnimation on scale {
                running: orb.active; loops: Animation.Infinite
                NumberAnimation { to: 1.15; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.90; duration: 800; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on opacity {
                running: orb.active; loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.00; duration: 800; easing.type: Easing.InOutSine }
            }
            Behavior on border.color { ColorAnimation { duration: 300 } }
        }

        Rectangle {
            id: core
            anchors.centerIn: parent
            width: orb.size * 0.72; height: orb.size * 0.72
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00B4FF" }
                GradientStop { position: 0.5; color: "#5E5CE6" }
                GradientStop { position: 1.0; color: "#BF5AF2" }
            }
            RotationAnimation on rotation {
                running: orb.active; loops: Animation.Infinite
                from: 0; to: 360; duration: 3000
            }
            SequentialAnimation on scale {
                running: orb.visible; loops: Animation.Infinite
                NumberAnimation { to: orb.active ? 1.12 : 1.03; duration: orb.active ? 600 : 1600; easing.type: Easing.InOutSine }
                NumberAnimation { to: orb.active ? 0.94 : 0.98; duration: orb.active ? 600 : 1600; easing.type: Easing.InOutSine }
            }
            opacity: orb.active ? 1.0 : 0.7
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        Rectangle {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -orb.size * 0.115
            width: core.width * 0.5; height: core.height * 0.35
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.35)
            opacity: orb.active ? 0.6 : 0.3
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        Rectangle {
            anchors.centerIn: parent
            width: orb.size; height: orb.size
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0.8, 0.5, 1.0, 0.6)
            visible: orb.active && orb.showRing
            opacity: orb.active ? 1.0 : 0.0
            RotationAnimation on rotation {
                running: orb.active; loops: Animation.Infinite
                from: 0; to: 360; duration: 1500
            }
        }
    }

    // Document icon (white page, folded corner, blue title line + gray text lines)
    // or a folder when `folder` is true. Drawn as vector curves, crisp at any size.
    // Needs Qt 6.6+ (Shape.CurveRenderer).
    component SpotlightFileIcon: Item {
        id: icon

        property bool folder: false
        property color pageColor: "#F3F4F7"
        property color foldColor: "#C9CCD6"
        property color titleColor: "#4F86E8"
        property color lineColor: "#A9AEBB"
        property color folderBack: "#3E8EF0"
        property color folderFront: "#64B0FF"

        implicitWidth: 28
        implicitHeight: 28
        readonly property real u: width / 28

        // ---- document
        Shape {
            visible: !icon.folder
            width: 28; height: 28
            scale: icon.u
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true

            ShapePath {   // page
                strokeColor: Qt.rgba(0, 0, 0, 0.16); strokeWidth: 0.7
                fillColor: icon.pageColor
                PathSvg { path: "M7 2 H17 L23 8 V24 A2 2 0 0 1 21 26 H7 A2 2 0 0 1 5 24 V4 A2 2 0 0 1 7 2 Z" }
            }
            ShapePath {   // folded corner
                strokeColor: "transparent"
                fillColor: icon.foldColor
                PathSvg { path: "M17 2 V6 A2 2 0 0 0 19 8 H23 Z" }
            }
            ShapePath {   // title line
                strokeColor: icon.titleColor; strokeWidth: 1.9
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M8.5 13 H19.5" }
            }
            ShapePath {   // text lines
                strokeColor: icon.lineColor; strokeWidth: 1.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M8.5 17 H19.5 M8.5 20.5 H15.5" }
            }
        }

        // ---- folder
        Shape {
            visible: icon.folder
            width: 28; height: 28
            scale: icon.u
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true

            ShapePath {   // back + tab
                strokeColor: "transparent"
                fillColor: icon.folderBack
                PathSvg { path: "M3 8 A2 2 0 0 1 5 6 H11 L14 9 H23 A2 2 0 0 1 25 11 V22 A2 2 0 0 1 23 24 H5 A2 2 0 0 1 3 22 Z" }
            }
            ShapePath {   // front
                strokeColor: "transparent"
                fillColor: icon.folderFront
                PathSvg { path: "M3 12 A2 2 0 0 1 5 10 H23 A2 2 0 0 1 25 12 V22 A2 2 0 0 1 23 24 H5 A2 2 0 0 1 3 22 Z" }
            }
        }
    }

    // Magnifying-glass icon (line art, vector — crisp at any size).
    // Needs Qt 6.6+ (Shape.CurveRenderer).
    component SpotlightSearchIcon: Item {
        id: icon

        property color color: "#ffffff"

        implicitWidth: 18
        implicitHeight: 18

        Shape {
            width: 24; height: 24
            scale: icon.width / 24
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true

            ShapePath {
                strokeColor: icon.color
                strokeWidth: 2.1
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M3 11a8 8 0 1 0 16 0a8 8 0 1 0 -16 0 M21 21l-4.35-4.35" }
            }
        }
    }

    // Media icon drawn with vector paths: crisp at any scale (the old Canvas blurred on HiDPI).
    // kind: "play" | "pause" | "previous" | "next"
    component SpotlightMediaGlyph: Item {
        id: glyph

        property string kind: "play"
        property color fg: "#ffffff"

        width: 14
        height: 14

        readonly property string pathData: {
            switch (kind) {
            case "previous": return "M2.2 2.7 H3.8 V11.3 H2.2 Z M11.8 2.7 V11.3 L5.4 7 Z";
            case "next":     return "M10.2 2.7 H11.8 V11.3 H10.2 Z M2.2 2.7 V11.3 L8.6 7 Z";
            case "pause":    return "M3.6 2.6 H5.8 V11.4 H3.6 Z M8.2 2.6 H10.4 V11.4 H8.2 Z";
            default:         return "M4.4 2.4 V11.6 L11.6 7 Z";
            }
        }

        Shape {
            width: 14
            height: 14
            scale: glyph.width / 14
            transformOrigin: Item.TopLeft
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: glyph.fg
                strokeColor: glyph.fg
                strokeWidth: 1.4
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap
                PathSvg { path: glyph.pathData }
            }
        }
    }

    // Line-art weather icon (24x24 icon paths, scaled to the item's width).
    // Needs Qt 6.6+ (Shape.CurveRenderer).
    // kind: clear | clear-night | partly | partly-night | cloud | fog | drizzle | rain | snow | storm
    component SpotlightWeatherGlyph: Item {
        id: glyph

        property string kind: "cloud"
        property color fg: "#ffffff"
        readonly property color sunColor: "#FF9F0A"
        readonly property color moonColor: "#A9A6F0"

        implicitWidth: 24
        implicitHeight: 24

        // icon paths (Feather / Lucide, 24x24 viewBox)
        readonly property string pSun: "M7 12a5 5 0 1 0 10 0a5 5 0 1 0 -10 0 M12 1v2 M12 21v2 M4.22 4.22l1.42 1.42 M18.36 18.36l1.42 1.42 M1 12h2 M21 12h2 M4.22 19.78l1.42-1.42 M18.36 5.64l1.42-1.42"
        readonly property string pMoon: "M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"
        readonly property string pPartSun: "M12 2v2 M4.93 4.93l1.41 1.41 M20 12h2 M19.07 4.93l-1.41 1.41 M15.947 12.65a4 4 0 0 0-5.925-4.128"
        readonly property string pPartCloud: "M13 22H7a5 5 0 1 1 4.9-6H13a3 3 0 0 1 0 6Z"
        readonly property string pCloud: "M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z"
        readonly property string pFog: "M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242 M16 17H7 M17 21H9"
        readonly property string pDrizzle: "M8 19v2 M8 13v2 M16 19v2 M16 13v2 M12 21v2 M12 15v2 M20 16.58A5 5 0 0 0 18 7h-1.26A8 8 0 1 0 4 15.25"
        readonly property string pRain: "M16 13v8 M8 13v8 M12 15v8 M20 16.58A5 5 0 0 0 18 7h-1.26A8 8 0 1 0 4 15.25"
        readonly property string pSnow: "M20 17.58A5 5 0 0 0 18 8h-1.26A8 8 0 1 0 4 16.25 M8 16h.01 M8 20h.01 M12 18h.01 M12 22h.01 M16 16h.01 M16 20h.01"
        readonly property string pStorm: "M19 16.9A5 5 0 0 0 18 7h-1.26a8 8 0 1 0-11.62 9 M13 11l-4 6h6l-4 6"

        // sun / moon part (drawn in orange or lavender)
        readonly property string accentPath: {
            switch (kind) {
            case "clear":        return pSun;
            case "clear-night":  return pMoon;
            case "partly":       return pPartSun;
            case "partly-night": return pMoon;
            default:             return "M0 0";
            }
        }
        // cloud / precipitation part (drawn in fg)
        readonly property string mainPath: {
            switch (kind) {
            case "partly":
            case "partly-night": return pPartCloud;
            case "cloud":        return pCloud;
            case "fog":          return pFog;
            case "drizzle":      return pDrizzle;
            case "rain":         return pRain;
            case "snow":         return pSnow;
            case "storm":        return pStorm;
            default:             return "M0 0";
            }
        }
        readonly property color accentColor: kind.indexOf("night") >= 0 ? moonColor : sunColor
        // the small moon behind the cloud in "partly-night"
        readonly property real accentScale: kind === "partly-night" ? 0.62 : 1.0
        readonly property real u: width / 24

        Shape {
            x: kind === "partly-night" ? 10.5 * glyph.u : 0
            y: kind === "partly-night" ? 1.0 * glyph.u : 0
            width: 24; height: 24
            scale: glyph.u * glyph.accentScale
            transformOrigin: Item.TopLeft
            // curves are rendered at the final resolution (no intermediate bitmap, so no pixelation)
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true
            ShapePath {
                strokeColor: glyph.accentColor
                strokeWidth: 1.8 / glyph.accentScale
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: glyph.accentPath }
            }
        }

        Shape {
            width: 24; height: 24
            scale: glyph.u
            transformOrigin: Item.TopLeft
            // curves are rendered at the final resolution (no intermediate bitmap, so no pixelation)
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true
            ShapePath {
                strokeColor: glyph.fg
                strokeWidth: 1.8
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: glyph.mainPath }
            }
        }
    }

    // Pill with the media controls: previous / play-pause / next.
    // Usage: SpotlightMediaControls { fg: ...; playing: ...; onAction: (cmd) => ... }
    // cmd = "previous" | "play-pause" | "next"
    component SpotlightMediaControls: Rectangle {
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

                    SpotlightMediaGlyph {
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

    // Volume card: speaker button (mute), draggable bar and percentage. Display-only row.
    component SpotlightVolumeCard: Item {
        id: vcard

        property real level: 0            // 0..1
        property bool isMuted: false
        property bool dragging: false
        property string fontFamily: "sans-serif"
        property color fg: Qt.rgba(1, 1, 1, 0.92)
        property color dim: Qt.rgba(1, 1, 1, 0.55)
        property color accent: "#0A84FF"
        property color panel: Qt.rgba(1, 1, 1, 0.06)
        property color panelBorder: Qt.rgba(1, 1, 1, 0.10)
        property string speakerPath: ""
        property string hint: ""
        property bool muteEnabled: true
        property bool dimmed: false
        property string valueText: ""
        property real cornerRadius: 18

        signal levelChosen(real value)
        signal muteToggled()

        Rectangle {
            anchors.fill: parent
            radius: vcard.cornerRadius
            color: vcard.panel
            border.color: vcard.panelBorder
            border.width: 1
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18; anchors.rightMargin: 18
            anchors.topMargin: 8; anchors.bottomMargin: 26
            spacing: 14

            Item {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; Layout.alignment: Qt.AlignVCenter
                Shape {
                    anchors.centerIn: parent
                    width: 24; height: 24
                    scale: 26 / 24
                    opacity: vcard.isMuted ? 0.5 : 0.95
                    preferredRendererType: Shape.CurveRenderer
                    antialiasing: true
                    ShapePath {
                        strokeColor: vcard.fg; strokeWidth: 2; fillColor: "transparent"
                        capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                        PathSvg { path: vcard.speakerPath }
                    }
                }
                Shape {
                    anchors.centerIn: parent
                    width: 24; height: 24
                    scale: 26 / 24
                    visible: vcard.isMuted
                    preferredRendererType: Shape.CurveRenderer
                    antialiasing: true
                    ShapePath {
                        strokeColor: vcard.fg; strokeWidth: 2; fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathSvg { path: "M3 3L21 21" }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: vcard.muteEnabled
                    cursorShape: vcard.muteEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: vcard.muteToggled()
                }
            }

            Item {
                id: track
                Layout.fillWidth: true; Layout.preferredHeight: 28; Layout.alignment: Qt.AlignVCenter
                readonly property real shown: vcard.isMuted ? 0 : vcard.level

                opacity: vcard.dimmed ? 0.4 : 1.0

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 8; radius: 4
                    color: Qt.rgba(1, 1, 1, 0.16)
                    Rectangle {
                        width: parent.width * track.shown; height: parent.height; radius: 4
                        color: vcard.accent
                    }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(parent.width - width, parent.width * track.shown - width / 2))
                    width: 18; height: 18; radius: 9
                    color: "white"
                    border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.18)
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    function pick(mx) { vcard.levelChosen(Math.max(0, Math.min(1, mx / width))); }
                    onPressed: (mouse) => { vcard.dragging = true; pick(mouse.x); }
                    onPositionChanged: (mouse) => { if (pressed) pick(mouse.x); }
                    onReleased: vcard.dragging = false
                    onCanceled: vcard.dragging = false
                }
            }

            Text {
                Layout.preferredWidth: 60; Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: vcard.valueText !== "" ? vcard.valueText : (vcard.isMuted ? "Muted" : Math.round(vcard.level * 100) + "%")
                font { family: vcard.fontFamily; pixelSize: 15; weight: Font.DemiBold }
                color: vcard.fg
            }
        }

        Text {
            anchors.left: parent.left; anchors.leftMargin: 18
            anchors.bottom: parent.bottom; anchors.bottomMargin: 9
            text: vcard.hint
            font { family: vcard.fontFamily; pixelSize: 11 }
            color: vcard.dim
        }
    }

    // Power profile card: one chip per profile + battery. Display-only row.
    component SpotlightPowerCard: Item {
        id: pcard

        property var profiles: []          // [{ id, label }]
        property string current: ""
        property string batteryText: ""
        property string fontFamily: "sans-serif"
        property color fg: Qt.rgba(1, 1, 1, 0.92)
        property color dim: Qt.rgba(1, 1, 1, 0.55)
        property color accent: "#0A84FF"
        property color panel: Qt.rgba(1, 1, 1, 0.06)
        property color panelBorder: Qt.rgba(1, 1, 1, 0.10)
        property real cornerRadius: 18

        signal profileChosen(string id)

        Rectangle {
            anchors.fill: parent
            radius: pcard.cornerRadius
            color: pcard.panel
            border.color: pcard.panelBorder
            border.width: 1
        }

        Row {
            id: chips
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.topMargin: 14
            height: 40
            spacing: 10

            Repeater {
                model: pcard.profiles
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool isCurrent: modelData.id === pcard.current
                    width: (chips.width - (pcard.profiles.length - 1) * chips.spacing) / Math.max(1, pcard.profiles.length)
                    height: chips.height
                    radius: 12
                    color: isCurrent ? pcard.accent : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: isCurrent ? Qt.rgba(1, 1, 1, 0.25) : pcard.panelBorder

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font { family: pcard.fontFamily; pixelSize: 14; weight: Font.DemiBold }
                        color: isCurrent ? "white" : pcard.fg
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pcard.profileChosen(modelData.id)
                    }
                }
            }
        }

        Text {
            anchors.centerIn: chips
            visible: pcard.profiles.length === 0
            text: "power-profiles-daemon is not available"
            font { family: pcard.fontFamily; pixelSize: 13 }
            color: pcard.dim
        }

        Text {
            anchors.left: parent.left; anchors.leftMargin: 18
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
            text: (pcard.batteryText !== "" ? "Battery " + pcard.batteryText + "  \u00B7  " : "") + "\u2190 \u2192 switch profile"
            font { family: pcard.fontFamily; pixelSize: 11 }
            color: pcard.dim
        }
    }

    // QR card: the code on a white tile with a caption. Display-only row.
    component SpotlightQrCard: Item {
        id: qcard

        property string source: ""
        property string label: ""
        property bool busy: false
        property string error: ""
        property string fontFamily: "sans-serif"
        property color fg: Qt.rgba(1, 1, 1, 0.92)
        property color dim: Qt.rgba(1, 1, 1, 0.55)
        property color panel: Qt.rgba(1, 1, 1, 0.06)
        property color panelBorder: Qt.rgba(1, 1, 1, 0.10)
        property real cornerRadius: 18

        Rectangle {
            anchors.fill: parent
            radius: qcard.cornerRadius
            color: qcard.panel
            border.color: qcard.panelBorder
            border.width: 1
        }

        Rectangle {
            id: qrBox
            anchors.top: parent.top; anchors.topMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            width: 200; height: 200; radius: 12
            color: "white"

            Image {
                anchors.fill: parent; anchors.margins: 6
                source: (!qcard.busy && qcard.error === "") ? qcard.source : ""
                fillMode: Image.PreserveAspectFit
                smooth: false; cache: false; asynchronous: true
            }
            Text {
                anchors.centerIn: parent
                width: parent.width - 24
                visible: qcard.busy || qcard.error !== ""
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                text: qcard.error !== "" ? qcard.error : "Generating\u2026"
                font { family: qcard.fontFamily; pixelSize: 13 }
                color: "#333333"
            }
        }

        Text {
            anchors.top: qrBox.bottom; anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 36
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            text: qcard.label
            font { family: qcard.fontFamily; pixelSize: 13; weight: Font.DemiBold }
            color: qcard.fg
        }

        Text {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 9
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Scan with your phone camera"
            font { family: qcard.fontFamily; pixelSize: 11 }
            color: qcard.dim
        }
    }

    // Weather card: current conditions, 12-hour outlook and footer.
    // info = { city, country, temp, desc, kind, high, low, feels, summary, url,
    //          hours: [{ label, temp, kind }] }   (hours[0] is "Now")
    component SpotlightWeatherCard: Item {
        id: card

        property var info: null
        property string fontFamily: "sans-serif"
        property color fg: Qt.rgba(1, 1, 1, 0.92)
        property color muted: Qt.rgba(1, 1, 1, 0.55)
        property color panel: Qt.rgba(1, 1, 1, 0.06)
        property color panelBorder: Qt.rgba(1, 1, 1, 0.10)
        property real cornerRadius: 18

        signal openBrowser()

        Rectangle {
            anchors.fill: parent
            radius: card.cornerRadius
            color: card.panel
            border.color: card.panelBorder
            border.width: 1
        }

        // ---- current conditions
        SpotlightWeatherGlyph {
            id: mainIcon
            x: 18; y: 14
            width: 46; height: 46
            kind: card.info ? card.info.kind : "cloud"
            fg: card.fg
        }
        Text {
            id: tempText
            anchors.left: mainIcon.right; anchors.leftMargin: 10
            anchors.verticalCenter: mainIcon.verticalCenter
            text: card.info ? card.info.temp + "\u00b0" : ""
            color: card.fg
            font { family: card.fontFamily; pixelSize: 40; weight: Font.Light }
        }
        Column {
            anchors.left: tempText.right; anchors.leftMargin: 18
            anchors.verticalCenter: mainIcon.verticalCenter
            spacing: 2
            Text {
                text: card.info ? card.info.desc : ""
                color: card.fg
                font { family: card.fontFamily; pixelSize: 15; weight: Font.DemiBold }
            }
            Text {
                text: card.info ? "High " + card.info.high + "\u00b0  \u00b7  Low " + card.info.low
                                  + "\u00b0  \u00b7  Feels like " + card.info.feels + "\u00b0" : ""
                color: card.muted
                font { family: card.fontFamily; pixelSize: 12 }
            }
        }
        Column {
            anchors.right: parent.right; anchors.rightMargin: 18
            anchors.verticalCenter: mainIcon.verticalCenter
            spacing: 2
            Text {
                anchors.right: parent.right
                width: Math.min(implicitWidth, 150)
                elide: Text.ElideRight
                text: card.info ? card.info.city : ""
                color: card.fg
                font { family: card.fontFamily; pixelSize: 15; weight: Font.DemiBold }
            }
            Text {
                anchors.right: parent.right
                width: Math.min(implicitWidth, 150)
                elide: Text.ElideRight
                text: card.info ? card.info.country : ""
                color: card.muted
                font { family: card.fontFamily; pixelSize: 12 }
            }
        }

        // ---- summary
        Text {
            x: 18; y: 74
            text: card.info ? card.info.summary : ""
            color: card.muted
            font { family: card.fontFamily; pixelSize: 12 }
        }

        // ---- hourly outlook
        Row {
            id: hoursRow
            x: 18; y: 98
            width: card.width - 36
            height: 58
            Repeater {
                model: card.info ? card.info.hours : []
                delegate: Item {
                    width: hoursRow.width / 7
                    height: hoursRow.height
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        text: modelData.label
                        color: card.muted
                        font { family: card.fontFamily; pixelSize: 11 }
                    }
                    SpotlightWeatherGlyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 17
                        width: 22; height: 22
                        kind: modelData.kind
                        fg: card.fg
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 43
                        text: modelData.temp + "\u00b0"
                        color: card.fg
                        font { family: card.fontFamily; pixelSize: 12; weight: Font.DemiBold }
                    }
                }
            }
        }

        // ---- footer
        Text {
            x: 18
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
            text: "Open-Meteo"
            color: card.muted
            font { family: card.fontFamily; pixelSize: 10 }
        }
        Text {
            id: browserLink
            anchors.right: parent.right; anchors.rightMargin: 18
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
            text: "Open in browser \u2197"
            color: linkMA.containsMouse ? card.fg : card.muted
            font { family: card.fontFamily; pixelSize: 10 }
            Behavior on color { ColorAnimation { duration: 100 } }
            MouseArea {
                id: linkMA
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.openBrowser()
            }
        }
    }

    // Hoisted out of SpotlightModeMorphSurface: inline components cannot be nested.
    component SpotlightShapeBlurRegion: Item {
        required property vector4d shape
        property real inset: 0
        x: shape.x - width / 2
        y: shape.y - height / 2
        width: Math.max(0, shape.z - inset * 2)
        height: Math.max(0, shape.w - inset * 2)
        property real radius: Math.min(width, height) / 2
        visible: width > 0 && height > 0
    }

    component SpotlightModeMorphSurface: Item {
        id: morphRoot

        required property real railProgress
        required property real mainLeft
        required property real collapsedMainWidth
        required property real expandedMainWidth
        required property real shapeCenterY
        required property real shapeHeight
        required property real buttonDiameter
        required property real buttonGap
        required property real blurEdgeInset

        property color surfaceColor: Qt.rgba(1, 1, 1, 0.15)
        property color shadowColor: Qt.rgba(0, 0, 0, 0.15)
        readonly property var blurRegionItems: [mainBlurRegion, button0BlurRegion, button1BlurRegion,
            button2BlurRegion, button3BlurRegion, neck0BlurRegion, neck1BlurRegion, neck2BlurRegion,
            neck3BlurRegion]

        // The pill leads the motion; the trailing buttons follow with progressively
        // slower responses. Continuous damping avoids stops between authored poses.
        readonly property real mainWidth: interpolate(collapsedMainWidth, expandedMainWidth, response(0, 6.2, 7.5, 0.4))
        readonly property real mainCenterX: mainLeft + mainWidth / 2
        readonly property real mainRight: mainLeft + mainWidth
        readonly property real expandedMainRight: mainLeft + expandedMainWidth
        readonly property vector4d mainShape: Qt.vector4d(mainCenterX, shapeCenterY, mainWidth, shapeHeight)
        readonly property var buttonShapes: [buttonShape(0), buttonShape(1), buttonShape(2), buttonShape(3)]
        readonly property var travelDelays: [0.06, 0.036, 0.032, 0.03]
        readonly property var travelDecays: [7.2, 5.4, 5.4, 5.4]
        readonly property var travelFrequencies: [8.9, 6.2, 5.35, 5.0]
        readonly property var growthRates: [3.8, 3.1, 2.7, 2.5]

        function smoothstep(value) {
            const progress = Math.max(0, Math.min(1, value));
            return progress * progress * (3 - 2 * progress);
        }

        function stage(start, end) {
            return smoothstep((morphRoot.railProgress - start) / (end - start));
        }

        function interpolate(from, to, progress) {
            return from + (to - from) * progress;
        }

        // Normalize the damped response at the endpoint so interruption/reversal
        // remains a pure function of railProgress and the final layout is exact.
        function response(delay, decay, frequency, phase) {
            const time = Math.max(0, Math.min(1, morphRoot.railProgress) - delay);
            const end = 1 - delay;
            const value = 1 - Math.exp(-decay * time) * (Math.cos(frequency * time) + phase * Math.sin(frequency * time));
            const terminal = 1 - Math.exp(-decay * end) * (Math.cos(frequency * end) + phase * Math.sin(frequency * end));
            return value / terminal;
        }

        function buttonGrowth(index) {
            if (index === 0)
                return response(0.055, 10.5, 10.5, 1);
            const rate = morphRoot.growthRates[index - 1];
            return response(0, rate, rate, 0);
        }

        function buttonCenterX(index) {
            const diameter = morphRoot.buttonDiameter;
            const emergence = diameter * 0.3 * (buttonGrowth(0) - 1);
            const firstCenter = morphRoot.expandedMainRight + morphRoot.buttonGap + diameter / 2 + emergence;
            if (index === 0)
                return firstCenter;
            const decay = morphRoot.travelDecays[index - 1];
            const frequency = morphRoot.travelFrequencies[index - 1];
            const travel = response(morphRoot.travelDelays[index - 1], decay, frequency, decay / frequency);
            return firstCenter + index * (diameter + morphRoot.buttonGap) * travel;
        }

        function buttonShape(index) {
            const diameter = morphRoot.buttonDiameter * buttonGrowth(index);
            return Qt.vector4d(buttonCenterX(index), morphRoot.shapeCenterY, diameter, diameter);
        }

        function buttonBlend(index) {
            const shape = morphRoot.buttonShapes[index];
            // Suppress blending while one lobe is still buried in another; this
            // keeps the pill from inflating as the chain emerges. The same short
            // fade follows each lobe, so receding buttons cannot reconnect later.
            const previous = index === 0 ? morphRoot.mainShape : morphRoot.buttonShapes[index - 1];
            const previousCenter = index === 0 ? morphRoot.mainRight - morphRoot.shapeHeight / 2 : previous.x;
            const radii = (Math.min(previous.z, previous.w) + Math.min(shape.z, shape.w)) / 2;
            const separation = radii > 0 ? Math.abs(shape.x - previousCenter) / radii : 0;
            const exposed = smoothstep((separation - 0.5) / 0.5);
            const release = stage(0.27 + index * 0.063, 0.47 + index * 0.063);
            return Math.min(shape.z, shape.w, morphRoot.buttonDiameter) * 0.78 * exposed * (1 - release);
        }

        function iconProgress(index) {
            return stage(0.36 + index * 0.025, 0.55 + index * 0.025);
        }

        // A conservative blur-only rectangle inside the natural SDF neck.
        function neckBlurShape(index) {
            const shape = morphRoot.buttonShapes[index];
            const previous = index === 0 ? morphRoot.mainShape : morphRoot.buttonShapes[index - 1];
            const previousX = index === 0 ? morphRoot.mainRight - morphRoot.shapeHeight / 2 : previous.x;
            const radius = Math.min(shape.z, shape.w, previous.z, previous.w) / 2;
            const distance = Math.abs(shape.x - previousX);
            const reach = radius + buttonBlend(index) / 4;
            const halfHeight = Math.max(0, Math.min(radius, Math.sqrt(Math.max(0, reach * reach - distance * distance / 4))) - morphRoot.blurEdgeInset);
            return Qt.vector4d((previousX + shape.x) / 2, morphRoot.shapeCenterY, distance, halfHeight * 2);
        }

        ShaderEffect {
            id: surfaceSource

            anchors.fill: parent
            visible: false

            property vector2d resolution: Qt.vector2d(width, height)
            property color fillColor: morphRoot.surfaceColor
            property vector4d mainShape: morphRoot.mainShape
            property vector4d button0Shape: morphRoot.buttonShapes[0]
            property vector4d button1Shape: morphRoot.buttonShapes[1]
            property vector4d button2Shape: morphRoot.buttonShapes[2]
            property vector4d button3Shape: morphRoot.buttonShapes[3]
            property vector4d blends: Qt.vector4d(morphRoot.buttonBlend(0), morphRoot.buttonBlend(1), morphRoot.buttonBlend(2), morphRoot.buttonBlend(3))

            fragmentShader: "shaders/spotlight_mode_field.frag.qsb"
        }

        MultiEffect {
            anchors.fill: surfaceSource
            source: surfaceSource
            opacity: morphRoot.surfaceColor.a
            autoPaddingEnabled: false
            shadowEnabled: false
        }

        SpotlightShapeBlurRegion {
            id: mainBlurRegion
            shape: morphRoot.mainShape
            inset: morphRoot.blurEdgeInset
        }

        SpotlightShapeBlurRegion {
            id: button0BlurRegion
            shape: morphRoot.buttonShapes[0]
            inset: morphRoot.blurEdgeInset
        }

        SpotlightShapeBlurRegion {
            id: button1BlurRegion
            shape: morphRoot.buttonShapes[1]
            inset: morphRoot.blurEdgeInset
        }

        SpotlightShapeBlurRegion {
            id: button2BlurRegion
            shape: morphRoot.buttonShapes[2]
            inset: morphRoot.blurEdgeInset
        }

        SpotlightShapeBlurRegion {
            id: button3BlurRegion
            shape: morphRoot.buttonShapes[3]
            inset: morphRoot.blurEdgeInset
        }

        SpotlightShapeBlurRegion {
            id: neck0BlurRegion
            shape: morphRoot.neckBlurShape(0)
            inset: 0
            radius: 0
        }

        SpotlightShapeBlurRegion {
            id: neck1BlurRegion
            shape: morphRoot.neckBlurShape(1)
            inset: 0
            radius: 0
        }

        SpotlightShapeBlurRegion {
            id: neck2BlurRegion
            shape: morphRoot.neckBlurShape(2)
            inset: 0
            radius: 0
        }

        SpotlightShapeBlurRegion {
            id: neck3BlurRegion
            shape: morphRoot.neckBlurShape(3)
            inset: 0
            radius: 0
        }
    }

    // =====================================================================
    //  BUILT-IN SERVICES (were singletons; now plain objects owned by the window)
    // =====================================================================

    Scope {
        id: spotlightController
        property bool spotlightOpen: false

        // Fire-and-forget: every call spawns its own process, so commands fired
        // back to back never overwrite each other.
        function run(cmd) {
            Quickshell.execDetached(["bash", "-c", cmd]);
        }

        function requestAction(name) {
            if (name === "restart") run("systemctl reboot");
            else if (name === "shutdown") run("systemctl poweroff");
            else if (name === "logout") run("hyprctl dispatch exit");
            else if (name === "lock") run("hyprlock");
            else if (name === "sleep") run("systemctl suspend");
        }

        IpcHandler {
            target: "spotlight"
            function toggle() { spotlightController.spotlightOpen = !spotlightController.spotlightOpen; }
            function open() { spotlightController.spotlightOpen = true; }
            function close() { spotlightController.spotlightOpen = false; }
        }
    }

    Scope {
        id: spotlightApps

        property var apps: []
        property var appsById: ({})
        property bool ready: false

        function refresh() {
            const list = [];
            const byId = {};
            const seenNames = {};
            for (const e of DesktopEntries.applications.values) {
                if (e.noDisplay) continue;
                const name = e.name || e.id || "";
                if (!name) continue;
                const exec = e.execString || "";
                let displayName = name;
                // Flatpak apps get a "(flatpak)" tag after their name
                const _ep = String(exec).split(/\s+/).filter(Boolean);
                let _ei = 0;
                while (_ei < _ep.length && (_ep[_ei] === "env" || _ep[_ei].indexOf("=") > 0)) _ei++;
                if (String(_ep[_ei] || "").split("/").pop() === "flatpak" && _ep[_ei + 1] === "run")
                    displayName = name + " (flatpak)";
                // For Telegram, always show just "Telegram" regardless of duplicates
                // The Flatpak vs system distinction is handled by launchOrFocus
                const isTelegram = /telegram/i.test(name);
                if (!isTelegram && seenNames[displayName]) {
                    const idx = ++seenNames[displayName];
                    displayName = displayName + " #" + idx;
                } else if (!isTelegram) {
                    seenNames[displayName] = 1;
                }
                const entry = {
                    name: displayName,
                    id: e.id || "",
                    icon: Quickshell.iconPath(e.icon || "", "image-missing"),
                    exec: exec,
                    category: e.genericName || "",
                    terminal: e.runInTerminal === true
                };
                list.push(entry);
                if (entry.id) byId[entry.id] = entry;
            }
            list.sort((a, b) => a.name.localeCompare(b.name));
            spotlightApps.apps = list;
            spotlightApps.appsById = byId;
            spotlightApps.ready = true;
        }

        function search(query) {
            query = (query || "").trim().toLowerCase();
            if (!query) return spotlightApps.apps.slice();
            const out = [];
            for (const a of spotlightApps.apps) {
                if (a.name.toLowerCase().includes(query) ||
                    (a.id || "").toLowerCase().includes(query) ||
                    (a.category || "").toLowerCase().includes(query)) {
                    out.push(a);
                }
            }
            return out;
        }

        // Match quality for ranking: exact > prefix > word prefix > substring > id > category.
        function matchScore(a, q) {
            const n = (a.name || "").toLowerCase();
            if (!q) return 0;
            if (n === q) return 100;
            if (n.startsWith(q)) return 80;
            if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 60;
            if (n.includes(q)) return 40;
            if ((a.id || "").toLowerCase().includes(q)) return 20;
            return 10;
        }

        function launch(execString) {
            // Terminal=true entries have no window of their own: let Quickshell start them in a terminal.
            const hit = spotlightApps.apps.find(a => a.exec === execString);
            if (hit && hit.terminal) {
                try {
                    for (const de of DesktopEntries.applications.values) {
                        if (de.id === hit.id && typeof de.execute === "function") { de.execute(); return; }
                    }
                } catch (e) { /* fall back to the plain command */ }
            }
            const cleaned = (execString || "").replace(/[ \t]+%\w/g, "").trim();
            if (!cleaned) return;
            // Handle WAYLAND_DISPLAY prefix for Flatpak apps
            let env = "";
            let cmd = cleaned;
            if (cleaned.startsWith("WAYLAND_DISPLAY=")) {
                const spaceIdx = cleaned.indexOf(" ");
                if (spaceIdx > 0) {
                    env = cleaned.slice(0, spaceIdx + 1);
                    cmd = cleaned.slice(spaceIdx + 1);
                }
            }
            if (!env && cmd.includes("flatpak run")) {
                env = "WAYLAND_DISPLAY=wayland-1 ";
            }
            // Fire-and-forget: each launch is its own process, so back-to-back launches never collide
            Quickshell.execDetached(["bash", "-c", env + cmd + " </dev/null >/dev/null 2>&1 & disown"]);
        }

        // DesktopEntries is itself a lazily-created singleton that scans in the background, so
        // `applications` is empty right after first access. `DesktopEntries.applications` is a constant
        // model: `onApplicationsChanged` never fires, the model's own `valuesChanged` does.
        // Debounced because the model can emit many times while the scan runs.
        Timer {
            id: _refreshDebounce
            interval: 150
            repeat: false
            onTriggered: spotlightApps.refresh()
        }

        Connections {
            target: DesktopEntries.applications
            function onValuesChanged() { _refreshDebounce.restart(); }
        }

        Component.onCompleted: {
            // Always refresh once: harmless if the list is still empty, and fills `ready`/`apps`
            // immediately when the entries were already loaded.
            spotlightApps.refresh();
        }
    }

    Scope {
        id: spotlightActions

        // Shell snippet shared by the OCR commands: private temp files (umask 077) and
        // $langs = installed subset of por+eng+jpn (falls back to eng)
        readonly property string _ocrLangs:
            "umask 077; langs=$(tesseract --list-langs 2>/dev/null | tail -n +2 | grep -E '^(por|eng|jpn)$' | paste -sd+); [ -n \"$langs\" ] || langs=eng\n"

        property var aliases: ({})
        property string historyPath: Quickshell.env("HOME") + "/.cache/spotlight-ai-history.json"

        function shellQuote(s) {
            return "'" + String(s).replace(/'/g, "'\\''") + "'";
        }

        // #6 Block sites
        function blockSites(sites, minutes) {
            const list = Array.isArray(sites) ? sites : [sites];
            const clean = list
                .map(s => String(s).replace(/^https?:\/\//, "").replace(/\/.*$/, "").trim().toLowerCase())
                .filter(s => /^[a-z0-9.-]+$/.test(s));
            if (!clean.length) return "❌ No valid sites";
            const mins = Math.max(1, parseInt(minutes) || 60);
            const tag = "# spotlight-block-" + Date.now();
            const lines = clean.map(s => "0.0.0.0 " + s + " " + tag).join("\n");
            // Unlock: filter into a temp file first, then copy (never read and truncate /etc/hosts at once)
            const unlock = "t=$(mktemp) && grep -v '" + tag + "' /etc/hosts > \"$t\" && sudo -n cp \"$t\" /etc/hosts; rm -f \"$t\"";
            const cmd = "echo " + shellQuote(lines + "\n") + " | sudo -n tee -a /etc/hosts >/dev/null "
                      + "&& systemd-run --user --quiet --collect --on-active=" + (mins * 60) + "s "
                      + "bash -c " + shellQuote(unlock)
                      + " || notify-send 'Spotlight' 'Could not edit /etc/hosts (sudo needs a passwordless rule)' 2>/dev/null";
            spotlightController.run(cmd);
            return "🚫 Blocked: " + clean.join(", ") + " for " + mins + " min";
        }

        // #11 Aliases
        function createAlias(name, actions) {
            const a = Object.assign({}, spotlightActions.aliases);
            a[name] = actions;
            spotlightActions.aliases = a;
            const json = JSON.stringify(a, null, 2);
            spotlightController.run(
                "mkdir -p ~/.config/spotlight && printf '%s' " + shellQuote(json)
                + " > ~/.config/spotlight/aliases.json"
            );
            return "🔗 Alias created: " + name;
        }

        // #12 Screenshot + OCR
        function runScreenshotOcr(selectArea) {
            _ocrProc.selectArea = !!selectArea;
            _ocrProc.running = true;
        }
        Process {
            id: _ocrProc
            running: false
            property bool selectArea: false

            command: ["bash", "-c", selectArea
                ? `${spotlightActions._ocrLangs}prev=$(mktemp); had=0
                   if wl-paste --list-types 2>/dev/null | grep -q '^text/plain'; then
                       wl-paste --no-newline --type text/plain > "$prev" 2>/dev/null && had=1
                   fi
                   printf '' | wl-copy 2>/dev/null
                   qs -c ii ipc call region screenshot
                   for i in $(seq 1 60); do
                       sleep 0.25
                       wl-paste --list-types 2>/dev/null | grep -q '^image/' && break
                   done
                   f="$(mktemp --suffix=.png)"
                   wl-paste --type image > "$f" 2>/dev/null
                   [ "$had" = 1 ] && wl-copy < "$prev"
                   rm -f "$prev"
                   if [ -s "$f" ]; then
                       tesseract "$f" stdout -l "$langs" 2>/dev/null
                       rm -f "$f"
                   else
                       rm -f "$f"
                       echo "No image captured"
                   fi`
                : `${spotlightActions._ocrLangs}f="/tmp/spotlight-ocr-$(date +%s).png"; grim "$f" 2>/dev/null && tesseract "$f" stdout -l "$langs" 2>/dev/null; rm -f "$f"`]
                    stdout: StdioCollector { onStreamFinished: spotlightActions.screenshotOcrReady(text.trim()) }
                }
            signal screenshotOcrReady(string ocrText)

        // Web page -> { ok, title, url, text } (used by /sum and the web_summary intent -> pageReady)
        function fetchPage(url) {
            _pageProc.url = String(url || "");
            _pageProc.running = true;
        }
        Process {
            id: _pageProc
            running: false
            property string url: ""
            environment: ({ SPOTLIGHT_URL: url })
            command: ["bash", "-c", `f=$(mktemp)
    curl -sL --max-time 15 --max-filesize 5000000 --proto '=http,https' --proto-redir '=http,https' -A 'Mozilla/5.0' -o "$f" "$SPOTLIGHT_URL" 2>/dev/null
    python3 - "$f" "$SPOTLIGHT_URL" <<'PYEOF'
    import sys, re, json, html
    path, url = sys.argv[1], sys.argv[2]
    try:
        raw = open(path, "rb").read().decode("utf-8", "replace")
    except Exception:
        raw = ""
    if not raw.strip():
        print(json.dumps({"ok": False, "url": url, "error": "Couldn't download the link"}))
        sys.exit(0)
    m = re.search(r"<title[^>]*>(.*?)</title>", raw, re.S | re.I)
    title = " ".join(html.unescape(m.group(1)).split()) if m else ""
    t = re.sub(r"<script[^>]*>.*?</script>", " ", raw, flags=re.S | re.I)
    t = re.sub(r"<style[^>]*>.*?</style>", " ", t, flags=re.S | re.I)
    t = re.sub(r"<[^>]+>", " ", t)
    t = " ".join(html.unescape(t).split())
    print(json.dumps({"ok": True, "title": title, "url": url, "text": t[:6000]}))
    PYEOF
    rm -f "$f"
    `]
            stdout: StdioCollector {
                onStreamFinished: {
                    let page;
                    try { page = JSON.parse(text.trim()); }
                    catch (e) { page = { ok: false, url: _pageProc.url, error: "Couldn't read the link" }; }
                    spotlightActions.pageReady(page);
                }
            }
        }
        signal pageReady(var page)

        // #18 Persistent memory
        function saveHistory(historyJson) {
            // Keep the payload well under the ~128 KB per-argument limit; drop the oldest messages first.
            let data = historyJson;
            try {
                const arr = JSON.parse(historyJson);
                while (arr.length > 2 && JSON.stringify(arr).length > 30000) arr.shift();
                data = JSON.stringify(arr);
            } catch (e) {}
            const f = "~/.cache/spotlight-ai-history.json";
            spotlightController.run("umask 077; mkdir -p ~/.cache && printf '%s' " + shellQuote(data)
                                    + " > " + f + " && chmod 600 " + f);
        }

        function loadHistory() { _loadHist.running = true; }
        Process {
            id: _loadHist
            running: false
            command: ["bash", "-c", "cat ~/.cache/spotlight-ai-history.json 2>/dev/null || echo '[]'"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try { spotlightActions.historyReady(JSON.parse(text.trim() || "[]")); }
                    catch (e) { spotlightActions.historyReady([]); }
                }
            }
        }
        signal historyReady(var history)

        // #21 Focus mode
        function enterFocusMode(minutes) {
            const mins = Math.max(1, parseInt(minutes) || 120);
            const sites = ["twitter.com", "x.com", "reddit.com", "youtube.com",
                           "instagram.com", "tiktok.com", "facebook.com"];
            spotlightActions.blockSites(sites, mins);
            const dnd = "if command -v makoctl >/dev/null; then makoctl mode -s dnd; "
                      + "elif command -v swaync-client >/dev/null; then swaync-client -d -sw; "
                      + "elif command -v dunstctl >/dev/null; then dunstctl set-paused true; fi";
            spotlightController.run(dnd);
            return "🎯 Focus mode: " + mins + " min · DND · sites blocked";
        }

        // #22 Meeting mode
        function enterMeetingMode() {
            const dnd = "if command -v makoctl >/dev/null; then makoctl mode -s dnd; "
                      + "elif command -v swaync-client >/dev/null; then swaync-client -d -sw; "
                      + "elif command -v dunstctl >/dev/null; then dunstctl set-paused true; fi";
            spotlightController.run(dnd);
            return "🎤 Meeting mode · notifications muted";
        }

        // #23 Briefing
        function runBriefing(city) { _briefingProc.city = String(city || ""); _briefingProc.running = true; }
        Process {
            id: _briefingProc
            running: false
            property string city: ""
            command: ["bash", "-c", `
                echo "## Weather"
                curl -s --max-time 5 "https://wttr.in/${encodeURIComponent(city)}?format=%c+%t+(feels+like+%f)+·+humidity+%h" 2>/dev/null || echo "unavailable"
                echo ""
                echo "## Today"
                date "+%A, %B %d, %Y — %H:%M"
                echo ""
                echo "## Now playing"
                playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null || echo "nothing"
            `]
            stdout: StdioCollector { onStreamFinished: spotlightActions.briefingReady(text.trim()) }
        }
        signal briefingReady(string text)

        // #7 PDF
        function summarizePdf(path) { _pdfProc.path = path; _pdfProc.running = true; }
        Process {
            id: _pdfProc
            running: false
            property string path: ""
            command: ["bash", "-c", "pdftotext -l 20 " + shellQuote(path) + " - 2>/dev/null | head -c 8000"]
            stdout: StdioCollector { onStreamFinished: spotlightActions.pdfReady(text.trim()) }
        }
        signal pdfReady(string text)

        // Load aliases on startup
        Process {
            id: _loadAliases
            running: true
            command: ["bash", "-c", "cat ~/.config/spotlight/aliases.json 2>/dev/null || echo '{}'"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try { spotlightActions.aliases = JSON.parse(text.trim() || "{}"); }
                    catch (e) { spotlightActions.aliases = {}; }
                }
            }
        }
    }


    // =====================================================================
    //  WINDOW
    // =====================================================================
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: root._shown
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "macos:spotlight"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root._shown
        ? (root._screenshotSelecting ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
        : WlrKeyboardFocus.None

    // =====================================================================
    //  CONFIGURATION
    // =====================================================================
    property string terminal: "kitty"
    property bool aiAutoQuestion: true
    property bool showSysStats: true
    property string weatherCity: "Itapira"
    property bool aiPersistentHistory: false

    readonly property string hermesUrl: Quickshell.env("HERMES_URL") || "http://127.0.0.1:8642"
    readonly property string hermesKey: Quickshell.env("HERMES_API_KEY") || ""
    readonly property string hermesModel: Quickshell.env("HERMES_MODEL") || "hermes-agent"

    readonly property var bangs: ({
        yt:    ["YouTube",        "https://www.youtube.com/results?search_query="],
        gh:    ["GitHub",         "https://github.com/search?q="],
        maps:  ["Google Maps",    "https://www.google.com/maps/search/"],
        wiki:  ["Wikipedia",      "https://pt.wikipedia.org/w/index.php?search="],
        pt:    ["Wiktionary",     "https://pt.wiktionary.org/w/index.php?search="],
        stack: ["Stack Overflow", "https://stackoverflow.com/search?q="],
        aur:   ["AUR",            "https://aur.archlinux.org/packages?K="],
        aw:    ["ArchWiki",       "https://wiki.archlinux.org/index.php?search="],
        gi:    ["Google Images", "https://www.google.com/search?tbm=isch&q="],
        imdb:  ["IMDb",           "https://www.imdb.com/find/?q="],
        ddg:   ["DuckDuckGo",     "https://duckduckgo.com/?q="]
    })

    // Icons for the /commands list (24x24 stroke paths). Command name -> icon key in cmdGlyphAlias.
    readonly property var cmdGlyphPaths: ({
        "apps": "M3 3h7v7H3z M14 3h7v7h-7z M14 14h7v7h-7z M3 14h7v7H3z",
        "files": "M3 7a2 2 0 0 1 2 -2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2z",
        "clipboard": "M9 3h6a1 1 0 0 1 1 1v1H8V4a1 1 0 0 1 1 -1z M8 5H6a2 2 0 0 0 -2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2V7a2 2 0 0 0 -2 -2h-2",
        "actions": "M13 2L4 14h7l-1 8 9 -12h-7z",
        "wallpaper": "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2V5a2 2 0 0 1 2 -2z M10.5 8.5a1.5 1.5 0 1 1 -3 0a1.5 1.5 0 1 1 3 0 M21 15l-5 -5L5 21",
        "theme": "M12 17a5 5 0 1 0 0 -10a5 5 0 0 0 0 10z M12 2v2 M12 20v2 M4.93 4.93l1.41 1.41 M17.66 17.66l1.41 1.41 M2 12h2 M20 12h2 M6.34 17.66l-1.41 1.41 M19.07 4.93l-1.41 1.41",
        "bar": "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2V5a2 2 0 0 1 2 -2z M3 9h18",
        "settings": "M9.99 4.98 L10.47 2.32 L13.53 2.32 L14.01 4.98 L15.54 5.62 L17.76 4.07 L19.93 6.24 L18.38 8.46 L19.02 9.99 L21.68 10.47 L21.68 13.53 L19.02 14.01 L18.38 15.54 L19.93 17.76 L17.76 19.93 L15.54 18.38 L14.01 19.02 L13.53 21.68 L10.47 21.68 L9.99 19.02 L8.46 18.38 L6.24 19.93 L4.07 17.76 L5.62 15.54 L4.98 14.01 L2.32 13.53 L2.32 10.47 L4.98 9.99 L5.62 8.46 L4.07 6.24 L6.24 4.07 L8.46 5.62 Z M15 12a3 3 0 1 1 -6 0a3 3 0 1 1 6 0",
        "volume": "M11 5L6 9H2v6h4l5 4z M19.07 4.93a10 10 0 0 1 0 14.14 M15.54 8.46a5 5 0 0 1 0 7.07",
        "dnd": "M13.73 21a2 2 0 0 1 -3.46 0 M18.63 13A17.89 17.89 0 0 1 18 8 M6.26 6.26A5.86 5.86 0 0 0 6 8c0 7 -3 9 -3 9h14 M18 8a6 6 0 0 0 -9.33 -5 M1 1l22 22",
        "music": "M9 18V5l12 -2v13 M9 18a3 3 0 1 1 -6 0a3 3 0 1 1 6 0 M21 16a3 3 0 1 1 -6 0a3 3 0 1 1 6 0",
        "screen": "M4 4h16a2 2 0 0 1 2 2v9a2 2 0 0 1 -2 2H4a2 2 0 0 1 -2 -2V6a2 2 0 0 1 2 -2z M8 21h8 M12 17v4",
        "translate": "M5 8l6 6 M4 14l6 -6 2 -3 M2 5h12 M7 2h1 M22 22l-5 -10 -5 10 M14 18h6",
        "record": "M22 12a10 10 0 1 1 -20 0a10 10 0 1 1 20 0 M15 12a3 3 0 1 1 -6 0a3 3 0 1 1 6 0",
        "color": "M12 2.69l5.66 5.66a8 8 0 1 1 -11.31 0z",
        "windows": "M4 4h16a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2H4a2 2 0 0 1 -2 -2V6a2 2 0 0 1 2 -2z M2 9h20 M6 6.5h.01 M10 6.5h.01",
        "wifi": "M5 12.55a11 11 0 0 1 14.08 0 M1.42 9a16 16 0 0 1 21.16 0 M8.53 16.11a6 6 0 0 1 6.95 0 M12 20h.01",
        "bluetooth": "M6.5 6.5l11 11L12 23V1l5.5 5.5 -11 11",
        "search": "M3 11a8 8 0 1 0 16 0a8 8 0 1 0 -16 0 M21 21l-4.35 -4.35",
        "ai": "M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9 -5.1L5 10l5.1 -1.9z M19 16l.7 1.8 1.8.7 -1.8.7L19 21l-.7 -1.8 -1.8 -.7 1.8 -.7z",
        "new": "M21 15a2 2 0 0 1 -2 2H7l-4 4V5a2 2 0 0 1 2 -2h14a2 2 0 0 1 2 2z M12 7v6 M9 10h6",
        "note": "M14 2H6a2 2 0 0 0 -2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2V8z M14 2v6h6 M16 13H8 M16 17H8 M10 9H8",
        "sum": "M17 10H3 M21 6H3 M21 14H3 M17 18H3",
        "todo": "M9 11l3 3L22 4 M21 12v7a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2V5a2 2 0 0 1 2 -2h11",
        "calendar": "M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2V6a2 2 0 0 1 2 -2z M16 2v4 M8 2v4 M3 10h18",
        "notes": "M12 20h9 M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1 -4z",
        "bell": "M18 8A6 6 0 0 0 6 8c0 7 -3 9 -3 9h18s-3 -2 -3 -9 M13.73 21a2 2 0 0 1 -3.46 0",
        "timer": "M10 2h4 M12 14l3 -3 M20 14a8 8 0 1 1 -16 0a8 8 0 1 1 16 0",
        "lock": "M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2v-7a2 2 0 0 1 2 -2z M7 11V7a5 5 0 0 1 10 0v4",
        "moon": "M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z",
        "restart": "M23 4v6h-6 M20.49 15a9 9 0 1 1 -2.12 -9.36L23 10",
        "power": "M18.36 6.64a9 9 0 1 1 -12.73 0 M12 2v10",
        "logout": "M9 21H5a2 2 0 0 1 -2 -2V5a2 2 0 0 1 2 -2h4 M16 17l5 -5 -5 -5 M21 12H9",
        "web": "M22 12a10 10 0 1 1 -20 0a10 10 0 1 1 20 0 M2 12h20 M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1 -4 10 15.3 15.3 0 0 1 -4 -10 15.3 15.3 0 0 1 4 -10z",
        "maps": "M21 10c0 7 -9 13 -9 13s-9 -6 -9 -13a9 9 0 0 1 18 0z M15 10a3 3 0 1 1 -6 0a3 3 0 1 1 6 0",
        "calc": "M6 2h12a2 2 0 0 1 2 2v16a2 2 0 0 1 -2 2H6a2 2 0 0 1 -2 -2V4a2 2 0 0 1 2 -2z M8 6h8 M8 10h.01 M12 10h.01 M16 10h.01 M8 14h.01 M12 14h.01 M16 14h.01 M8 18h.01 M12 18h.01 M16 18h.01",
        "trend": "M22 7l-8.5 8.5 -5 -5L2 17 M16 7h6v6",
        "emoji": "M22 12a10 10 0 1 1 -20 0a10 10 0 1 1 20 0 M8 14s1.5 2 4 2 4 -2 4 -2 M9 9h.01 M15 9h.01",
        "menu": "M8 6h13 M8 12h13 M8 18h13 M3 6h.01 M3 12h.01 M3 18h.01",
        "camera": "M23 19a2 2 0 0 1 -2 2H3a2 2 0 0 1 -2 -2V8a2 2 0 0 1 2 -2h4l2 -3h6l2 3h4a2 2 0 0 1 2 2z M17 13a5 5 0 1 1 -10 0a5 5 0 1 1 10 0",
        "mic": "M12 2a3 3 0 0 0 -3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0 -3 -3z M19 10v2a7 7 0 0 1 -14 0v-2 M12 19v3 M8 22h8",
        "bulb": "M9 18h6 M10 22h4 M12 2a7 7 0 0 0 -4 12.7V17h8v-2.3A7 7 0 0 0 12 2z",
        "trash": "M3 6h18 M19 6v14a2 2 0 0 1 -2 2H7a2 2 0 0 1 -2 -2V6 M8 6V4a2 2 0 0 1 2 -2h4a2 2 0 0 1 2 2v2 M10 11v6 M14 11v6",
        "edit": "M17 3a2.828 2.828 0 1 1 4 4L7.5 20.5 2 22l1.5 -5.5L17 3z",
        "external": "M18 13v6a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2V8a2 2 0 0 1 2 -2h6 M15 3h6v6 M10 14L21 3",
        "folder": "M22 19a2 2 0 0 1 -2 2H4a2 2 0 0 1 -2 -2V5a2 2 0 0 1 2 -2h5l2 3h9a2 2 0 0 1 2 2z",
        "copy": "M20 9H11a2 2 0 0 0 -2 2v9a2 2 0 0 0 2 2h9a2 2 0 0 0 2 -2v-9a2 2 0 0 0 -2 -2z M5 15H4a2 2 0 0 1 -2 -2V4a2 2 0 0 1 2 -2h9a2 2 0 0 1 2 2v1",
        "link": "M10 13a5 5 0 0 0 7.54 .54l3 -3a5 5 0 0 0 -7.07 -7.07l-1.72 1.71 M14 11a5 5 0 0 0 -7.54 -.54l-3 3a5 5 0 0 0 7.07 7.07l1.71 -1.71",
        "grid": "M3 3h7v7H3z M14 3h7v7h-7z M14 14h7v7h-7z M3 14h7v7H3z",
        "keyboard": "M2 6h20a1 1 0 0 1 1 1v10a1 1 0 0 1 -1 1H2a1 1 0 0 1 -1 -1V7a1 1 0 0 1 1 -1z M6 10h.01 M10 10h.01 M14 10h.01 M18 10h.01 M8 14h8",
        "default": "M4 17l6 -6 -6 -6 M12 19h8"
    })
    readonly property var cmdGlyphAlias: ({
        "event": "calendar", "lembrar": "bell", "sleep": "moon", "shutdown": "power"
    })
    // Action rows (not /commands) that borrow an icon through their iconKey.
    // "web" (magnifier), "ai" (orb) and "calc" (swatch) are left out on purpose: they already draw their own icon.
    readonly property var rowGlyphKeys: ["lock", "moon", "restart", "power", "logout", "timer", "bell", "note", "settings", "music"]
    function rowGlyphPath(item) {
        if (!item) return "";
        if (item.kind === "cmd") return root.cmdGlyphPath(item.name);
        if (item.kind === "menu") return root.cmdGlyphPaths[item.iconKey] || root.cmdGlyphPaths["default"];
        if (item.kind === "wifi") return root.cmdGlyphPaths["wifi"];
        if (item.kind === "bt") return root.cmdGlyphPaths["bluetooth"];
        if (item.kind === "kproc") return root.cmdGlyphPaths["windows"];
        if (item.kind === "usb") return root.cmdGlyphPaths["files"];
        if (item.kind === "fact" || item.kind === "fapp") return root.cmdGlyphPaths[item.iconKey] || root.cmdGlyphPaths["default"];
        if (item.kind === "key") return root.cmdGlyphPaths["keyboard"];
        if (item.kind === "calc" && item.iconKey === "trend") return root.cmdGlyphPaths["trend"];
        if (item.kind !== "action") return "";
        if (item.category === "System control") {
            const n = String(item.name || "").toLowerCase();
            let k = "settings";
            if (/volume|mudo|mute/.test(n)) k = "volume";
            else if (/brightness|brilho/.test(n)) k = "theme";
            else if (n.indexOf("bluetooth") === 0) k = "bluetooth";
            else if (/wi-?fi/.test(n)) k = "wifi";
            else if (/do not disturb/.test(n)) k = "dnd";
            return root.cmdGlyphPaths[k];
        }
        if (item.iconKey === "web") {
            // rows that already draw the magnifier keep it; the rest (open URL, bangs...) get a globe
            const act = item.action || "";
            if (act.indexOf("web:") === 0 || item.category === "Site shortcut" || item.category === "Google Maps") return "";
            return root.cmdGlyphPaths["web"];
        }
        if (root.rowGlyphKeys.indexOf(item.iconKey) >= 0)
            return root.cmdGlyphPaths[item.iconKey] || "";
        return "";
    }
    function cmdGlyphPath(name) {
        const n = String(name || "").replace(/^\//, "").toLowerCase();
        const key = root.cmdGlyphAlias[n] || n;
        return root.cmdGlyphPaths[key] || root.cmdGlyphPaths["default"];
    }

    readonly property var slashCommands: [
        { kind: "cmd", name: "/apps",       category: "Switch to Applications",         action: "mode:apps" },
        { kind: "cmd", name: "/files",      category: "Switch to Files",                action: "mode:files" },
        { kind: "cmd", name: "/clipboard",  category: "Switch to Clipboard",            action: "mode:clipboard" },
        { kind: "cmd", name: "/actions",    category: "Switch to Actions",              action: "mode:actions" },
        { kind: "cmd", name: "/wallpaper",  category: "Change wallpaper (ii)",          action: "ipc:wallpaperSelector:toggle" },
        { kind: "cmd", name: "/theme",       category: "Toggle light/dark theme (ii)",   action: "ipc:theme:toggleLightDark" },
        { kind: "cmd", name: "/bar",        category: "Show/hide bar (ii)",             action: "ipc:bar:toggle" },
        { kind: "cmd", name: "/translate",  category: "Translate screen area (OCR + Hermes)", action: "ocrtr:" },
        { kind: "cmd", name: "/record",     category: "Record screen (ii)",             action: "ipc:region:record" },
        { kind: "cmd", name: "/color",      category: "Color picker (copies hex)",      action: "colorpick:" },
        { kind: "cmd", name: "/windows",    category: "Switch between open windows",    action: "mode:windows" },
        { kind: "cmd", name: "/wifi",       category: "Wi-Fi networks",                 action: "mode:wifi" },
        { kind: "cmd", name: "/bluetooth",  category: "Paired Bluetooth devices",       action: "mode:bluetooth" },
        { kind: "cmd", name: "/menu",       category: "Command menu (power, network, capture...)", action: "mode:menu" },
        { kind: "cmd", name: "/kill",       category: "Kill a process (CPU and RAM)",             action: "mode:kill" },
        { kind: "cmd", name: "/usb",        category: "External drives (mount / eject)",          action: "mode:usb" },
        { kind: "cmd", name: "/keys",       category: "Hyprland keyboard shortcuts",              action: "mode:keys" },
        { kind: "cmd", name: "/search",     category: "Search inside files (ripgrep)",  action: "search:" },
        { kind: "cmd", name: "/ai",         category: "Ask Hermes Agent",               action: "ai:" },
        { kind: "cmd", name: "/new",        category: "New AI conversation",            action: "ai-new:" },
        { kind: "cmd", name: "/sum",        category: "Summarize a web page or PDF",    action: "sum:" },
        { kind: "cmd", name: "/todo",       category: "Add a ToDo task",                action: "todo:" },
        { kind: "cmd", name: "/event",      category: "Add a calendar event",           action: "todo:" },
        { kind: "cmd", name: "/lembrar",    category: "Create a reminder with alarm",    action: "lembrar:" },
        { kind: "cmd", name: "/timer",      category: "Start a timer (shows in bar)",   action: "timer:" },
        { kind: "cmd", name: "/lock",       category: "Lock Screen",                    action: "sys:lock" },
        { kind: "cmd", name: "/sleep",      category: "Sleep",                          action: "sys:sleep" },
        { kind: "cmd", name: "/restart",    category: "Restart",                        action: "sys:restart" },
        { kind: "cmd", name: "/shutdown",   category: "Shut Down",                      action: "sys:shutdown" },
        { kind: "cmd", name: "/logout",     category: "Log Out",                        action: "sys:logout" },
        { kind: "cmd", name: "/web",        category: "Search the Web",                 action: "web:" },
        { kind: "cmd", name: "/maps",       category: "Search a place on Google Maps",  action: "maps:" },
        { kind: "cmd", name: "/calc",       category: "Calculator",                     action: "calc:" }
    ]

    // Structured intents detected in AI prompts (order matters).
    readonly property var _intentRules: [
        // Anchored at the start and tied to an explicit object ("task", "timer"...),
        // so ordinary questions that merely contain "new" or "add" are not hijacked.
        ["lembrar",     s => /^(?:please\s+|por favor\s+)?(?:(?:lembrar|lembre|lembre-se|me lembre|defina|agende)\s+(?:me\s+)?(?:de\s+)?)/i.test(s) || /^(?:remind me to|remind me|set a reminder for)\b/i.test(s)],
        ["todo",       s => /^(?:please\s+|por favor\s+)?(?:(?:create|add|new|make)\s+(?:a\s+|an\s+)?(?:new\s+)?(?:task|to-?do|reminder)\b|(?:crie|criar|adicione|adicionar|adiciona|nova|novo)\s+(?:uma?\s+)?(?:nova\s+|novo\s+)?(?:tarefa|lembrete|to-?do)\b|(?:anote|anotar)\b|remind me to\b|me\s+lembr(?:e|ar)\s+de\b)/i.test(s)],
        ["timer",      s => /\d/.test(s)
                            && /^(?:please\s+|por favor\s+)?(?:(?:set|start)\s+(?:a\s+)?(?:[\w-]+\s+){0,2}?(?:timer|pomodoro)\b|timer\b|pomodoro\b|remind me in\s+\d+|me\s+avise\s+em\s+\d+|(?:inicie|iniciar|inicia|coloque|ponha)\s+(?:um\s+)?(?:timer|cronometro|temporizador)\b)/i.test(s)],
        ["alias",      s => /^(?:please\s+|por favor\s+)?(?:create|new|make|crie|criar|novo|nova)\s+(?:an?\s+|um\s+|uma\s+)?(?:new\s+|novo\s+|nova\s+)?(?:shortcut|atalho)\b/i.test(s)],
        ["block",      s => /^(?:please\s+|por favor\s+)?(?:block|bloqueie|bloquear|bloqueia)\s+(?:(?:the\s+|o\s+)?sites?\s+)?[\w.-]+\.[a-z]{2,}/i.test(s)],
        ["web",        s => /^(?:please\s+|por favor\s+)?(?:summari[sz]e|analy[sz]e|resuma|resumir|analise|analisa)\b.*(?:https?:\/\/\S+|\b(?:link|url|site|page)\b)/i.test(s)
                            || /^what does (?:this|that) (?:link|url|site|page)\b/i.test(s)],
        ["pdf",        s => /^(?:please\s+|por favor\s+)?(?:summari[sz]e|analy[sz]e|resuma|resumir|analise|analisa)\s+(?:(?:the|this|that|o|esse|esta|este)\s+)?(?:pdf|document|documento)\b/i.test(s)]
    ]

    readonly property var emojiList: [
        { e: "😀", n: "grinning" }, { e: "😃", n: "smiley" }, { e: "😄", n: "smile" },
        { e: "😁", n: "grin" }, { e: "😆", n: "laughing" }, { e: "😅", n: "sweat smile" },
        { e: "😂", n: "joy" }, { e: "🤣", n: "rofl" }, { e: "😊", n: "blush" },
        { e: "😇", n: "innocent" }, { e: "🙂", n: "slight smile" }, { e: "😉", n: "wink" },
        { e: "😍", n: "heart eyes" }, { e: "🥰", n: "smiling hearts" }, { e: "😘", n: "kiss" },
        { e: "😋", n: "yum" }, { e: "😎", n: "sunglasses" }, { e: "🤔", n: "thinking" },
        { e: "😐", n: "neutral" }, { e: "😑", n: "expressionless" }, { e: "😶", n: "no mouth" },
        { e: "🙄", n: "eye roll" }, { e: "😏", n: "smirk" }, { e: "😴", n: "sleeping" },
        { e: "😢", n: "cry" }, { e: "😭", n: "sob" }, { e: "😡", n: "angry" },
        { e: "🤬", n: "cursing" }, { e: "🤯", n: "exploding head" }, { e: "🥶", n: "cold" },
        { e: "🥵", n: "hot" }, { e: "😱", n: "scream" }, { e: "🤪", n: "zany" },
        { e: "👋", n: "wave" }, { e: "👌", n: "ok" }, { e: "✌️", n: "victory" },
        { e: "🤞", n: "crossed fingers" }, { e: "👍", n: "thumbs up" }, { e: "👎", n: "thumbs down" },
        { e: "👏", n: "clap" }, { e: "🙌", n: "raised hands" }, { e: "🤝", n: "handshake" },
        { e: "🙏", n: "pray" }, { e: "💪", n: "muscle" }, { e: "❤️", n: "red heart" },
        { e: "🧡", n: "orange heart" }, { e: "💛", n: "yellow heart" }, { e: "💚", n: "green heart" },
        { e: "💙", n: "blue heart" }, { e: "💜", n: "purple heart" }, { e: "🖤", n: "black heart" },
        { e: "💔", n: "broken heart" }, { e: "✨", n: "sparkles" }, { e: "⭐", n: "star" },
        { e: "🔥", n: "fire" }, { e: "💯", n: "hundred" }, { e: "✅", n: "check" },
        { e: "❌", n: "x" }, { e: "🎉", n: "party" }, { e: "🎊", n: "confetti" },
        { e: "💻", n: "laptop" }, { e: "📱", n: "phone" }, { e: "💡", n: "bulb" },
        { e: "🔒", n: "lock" }, { e: "🔑", n: "key" }, { e: "🎵", n: "music" },
        { e: "📷", n: "camera" }, { e: "🎮", n: "game" }, { e: "🚀", n: "rocket" },
        { e: "☕", n: "coffee" }, { e: "🍕", n: "pizza" }, { e: "🍔", n: "burger" },
        { e: "🐱", n: "cat" }, { e: "🐶", n: "dog" }, { e: "🦊", n: "fox" },
        { e: "🐻", n: "bear" }, { e: "🐼", n: "panda" }, { e: "🐸", n: "frog" }
    ]

    readonly property var _imgExts:   ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"]
    readonly property var _textExts:  ["txt", "md", "json", "qml", "js", "ts", "py", "sh", "conf", "yaml", "yml", "xml", "html", "css", "c", "cpp", "h", "lua", "toml", "ini", "log"]
    readonly property var _videoExts: ["mp4", "mkv", "webm", "avi", "mov", "m4v", "flv"]
    readonly property var _audioExts: ["mp3", "flac", "wav", "ogg", "opus", "m4a", "aac"]

    // =====================================================================
    //  THEME / GEOMETRY
    // =====================================================================
    readonly property color glassBg:        Qt.rgba(0.13, 0.15, 0.17, 0.66)
    readonly property color glassBorder:    Qt.rgba(1, 1, 1, 0.20)
    readonly property color glassHighlight: Qt.rgba(1, 1, 1, 0.10)
    readonly property color selectionBg:    Qt.rgba(0.05, 0.45, 0.85, 0.62)
    readonly property color selectionBorder: "transparent"
    readonly property color hoverBg:        Qt.rgba(1, 1, 1, 0.08)
    readonly property color divider:        Qt.rgba(1, 1, 1, 0.10)
    readonly property color headerFg:       Qt.rgba(1, 1, 1, 0.45)
    readonly property color sFg:            Qt.rgba(1, 1, 1, 0.92)
    readonly property color sFgDim:         Qt.rgba(1, 1, 1, 0.55)
    readonly property color placeholderFg:  Qt.rgba(1, 1, 1, 0.40)
    readonly property color accent:         "#0A84FF"

    // White-alpha, animation and font tokens — tweak here
    readonly property color white12: Qt.rgba(1, 1, 1, 0.12)
    readonly property color white14: Qt.rgba(1, 1, 1, 0.14)
    readonly property color white28: Qt.rgba(1, 1, 1, 0.28)
    readonly property color white06: Qt.rgba(1, 1, 1, 0.06)
    readonly property color white90: Qt.rgba(1, 1, 1, 0.9)
    readonly property color white85: Qt.rgba(1, 1, 1, 0.85)
    readonly property color white35: Qt.rgba(1, 1, 1, 0.35)
    readonly property color white25: Qt.rgba(1, 1, 1, 0.25)
    readonly property color white18: Qt.rgba(1, 1, 1, 0.18)
    readonly property color white10: Qt.rgba(1, 1, 1, 0.10)
    readonly property real weatherH: 192
    readonly property real volumeH: 84
    readonly property real powerH: 104
    readonly property real qrH: 284
    readonly property int maxVisibleRows: 10
    readonly property int animFast: 100
    readonly property int animMed:  140
    readonly property int animSlow: 200
    // First installed font from the list (font.families doesn't exist in every Qt version)
    function pickFont(list) {
        const have = Qt.fontFamilies();
        for (let i = 0; i < list.length; i++) if (have.indexOf(list[i]) >= 0) return list[i];
        return list[list.length - 1];
    }
    readonly property string fontDisplay: root.pickFont(["SF Pro Display", "Inter", "Noto Sans", "Cantarell", "sans-serif"])
    readonly property string fontText:    root.pickFont(["SF Pro Text", "Inter", "Noto Sans", "Cantarell", "sans-serif"])

    readonly property real panelWidth: 680
    readonly property real panelRadius: 22
    readonly property real panelPad: 0         // glass margin around the search pill (0 = pill flush with the panel edges)
    readonly property real listPad: 8         // side/bottom margin of the list
    readonly property real listGap: 6         // gap between the search row and the list
    readonly property real searchH: 56
    readonly property real circleSize: 56
    readonly property real circlesGap: 8
    readonly property real rowH: 44
    readonly property real headerH: 22
    readonly property real iconSize: 28
    readonly property real footerH: 46         // footer: settings button + key hints
    readonly property real stripH: 0

    // =====================================================================
    //  STATE
    // =====================================================================
    // -- Interface / navigation
    property bool _shown: false
    property bool _opened: false
    property string query: ""
    property string mode: "search"
    property string _pendingMode: ""
    property int selectedIndex: 0
    property bool _userNavigated: false
    property var items: []
    property var results: []
    property string _buildSig: ""
    property var selectedItem: (root.items.length ? root.items[root.selectedIndex] : null)
    readonly property string selectedKey: root.itemKey(root.selectedItem)
    property bool slashMode: root.query.startsWith("/")
    property string placeholderText: "Search or Ask"

    // -- Animation
    property real panelOpacity: 0.0
    property real panelScale: 0.96
    property real panelYOffset: 12
    property bool circlesVisible: false
    property bool circlesLocked: false
    property real railProgress: 0.0
    property bool railOpen: root.railProgress > 0.001

    // -- Per-mode data
    property var fileItems: []
    property var recentItems: []
    property string browseDir: ""
    property var clipItems: []
    // Pinned clipboard entries (persisted by the helper in ~/.local/share/quickshell/spotlight-clip-pins)
    property var clipPins: []
    property var _clipQueue: []

    // Pinned entries are reordered by holding one for 750 ms, then dragging it
    // up or down while the others make room. Positions are in the list's own
    // (content) coordinates; every pinned row is rowH tall and they sit together.
    property string pinDragH: ""
    property int pinDragFrom: -1
    property int pinDragTarget: -1
    property real pinDragStartY: 0
    property real pinDragDelta: 0
    property bool pinDragJustEnded: false
    Timer { id: pinDragSettle; interval: 80; onTriggered: root.pinDragJustEnded = false }

    function pinIndexOf(h) {
        const pins = root.clipPins || [];
        for (let i = 0; i < pins.length; i++) if (pins[i].h === h) return i;
        return -1;
    }
    function beginPinDrag(h, contentY) {
        const idx = root.pinIndexOf(h);
        if (idx < 0 || (root.clipPins || []).length < 2) return false;
        root.pinDragH = h;
        root.pinDragFrom = idx;
        root.pinDragTarget = idx;
        root.pinDragStartY = contentY;
        root.pinDragDelta = 0;
        return true;
    }
    function updatePinDrag(contentY) {
        if (root.pinDragH === "") return;
        const last = (root.clipPins || []).length - 1;
        const lo = -root.pinDragFrom * root.rowH, hi = (last - root.pinDragFrom) * root.rowH;
        root.pinDragDelta = Math.max(lo, Math.min(hi, contentY - root.pinDragStartY));
        root.pinDragTarget = Math.max(0, Math.min(last, Math.round(root.pinDragFrom + root.pinDragDelta / root.rowH)));
    }
    function endPinDrag() {
        if (root.pinDragH === "") return;
        const h = root.pinDragH, from = root.pinDragFrom, to = root.pinDragTarget;
        root.pinDragH = "";
        root.pinDragFrom = -1;
        root.pinDragTarget = -1;
        root.pinDragDelta = 0;
        root.pinDragJustEnded = true;
        pinDragSettle.restart();
        if (from < 0 || to < 0 || from === to) return;
        // Show the new order at once; the helper saves it and confirms
        const pins = (root.clipPins || []).slice();
        pins.splice(to, 0, pins.splice(from, 1)[0]);
        root.clipPins = pins;
        root.scheduleRebuild();
        root.clipOp("move", h + ":" + to);
    }
    // Helper used for: history listing ("hist"), pin / unpin / pins
    readonly property string _clipPy: `import sys, os, json, hashlib, subprocess, time

op = sys.argv[1] if len(sys.argv) > 1 else 'list'
arg = sys.argv[2] if len(sys.argv) > 2 else ''
pdir = os.path.expanduser('~/.local/share/quickshell/spotlight-clip-pins')
jf = os.path.join(pdir, 'pins.json')

def load():
    try:
        with open(jf) as f:
            data = json.load(f)
        return data if isinstance(data, list) else []
    except Exception:
        return []

def save(pins):
    os.makedirs(pdir, exist_ok=True)
    tmp = jf + '.tmp'
    with open(tmp, 'w') as f:
        json.dump(pins, f)
    os.replace(tmp, jf)

def run(cmd, data=None):
    return subprocess.run(cmd, input=data, capture_output=True).stdout

def mime_of(data):
    return run(['file', '--brief', '--mime-type', '-'], data).decode('utf-8', 'replace').strip()

def ext_of(mime):
    e = mime.split('/')[-1].replace('jpeg', 'jpg').replace('svg+xml', 'svg')
    return e if e.isalnum() else 'img'

if op == 'pin':
    data = run(['cliphist', 'decode', arg])
    if data:
        h = hashlib.sha1(data).hexdigest()[:16]
        pins = load()
        if not any(p.get('h') == h for p in pins):
            os.makedirs(pdir, exist_ok=True)
            mime = mime_of(data)
            if mime.startswith('image/'):
                path = os.path.join(pdir, h + '.' + ext_of(mime))
                with open(path, 'wb') as f:
                    f.write(data)
                pins.insert(0, {'h': h, 'image': True, 'path': path, 'mime': mime, 'ts': int(time.time())})
            else:
                path = os.path.join(pdir, h + '.txt')
                with open(path, 'wb') as f:
                    f.write(data)
                text = ' '.join(data.decode('utf-8', 'replace').split())
                pins.insert(0, {'h': h, 'image': False, 'path': path, 'text': text[:200], 'mime': 'text/plain', 'ts': int(time.time())})
            save(pins)
    print(json.dumps(load()))
elif op == 'unpin':
    keep = []
    for p in load():
        if p.get('h') == arg:
            try:
                os.remove(p.get('path', ''))
            except Exception:
                pass
        else:
            keep.append(p)
    save(keep)
    print(json.dumps(keep))
elif op == 'move':
    # arg is "<hash>:<new position>"
    mh, _, to = arg.rpartition(':')
    pins = load()
    cur = [i for i, p in enumerate(pins) if p.get('h') == mh]
    if cur and to.isdigit():
        pins.insert(max(0, min(len(pins) - 1, int(to))), pins.pop(cur[0]))
        save(pins)
    print(json.dumps(load()))
elif op == 'pins':
    print(json.dumps(load()))
else:
    cache = os.path.expanduser('~/.cache/quickshell/spotlight-clipboard')
    os.makedirs(cache, exist_ok=True)
    out = []
    lines = run(['cliphist', 'list']).decode('utf-8', 'replace').split(chr(10))[:30]
    for line in lines:
        if not line.strip():
            continue
        cid, _, preview = line.partition(chr(9))
        cid = cid.strip()
        if not cid:
            continue
        data = run(['cliphist', 'decode', cid])
        h = hashlib.sha1(data).hexdigest()[:16]
        mime = mime_of(data)
        if mime.startswith('image/'):
            path = os.path.join(cache, cid + '.' + ext_of(mime))
            if not os.path.exists(path):
                with open(path, 'wb') as f:
                    f.write(data)
            out.append({'id': cid, 'text': mime + ' image', 'isImage': True, 'imagePath': path, 'h': h})
        else:
            out.append({'id': cid, 'text': preview.strip(), 'isImage': False, 'imagePath': '', 'h': h})
    print(json.dumps({'history': out, 'pins': load()}))
`
    property string _clipPrevKey: ""
    property var windowItems: []
    property var wifiItems: []
    property var btItems: []

    // -- Command menu (/menu): nested tree from menu.jsonc (user) or menu.default.json (fallback)
    property string _menuUserText: ""
    property string _menuDefaultText: ""
    property var menuTree: []
    property var menuFlat: []
    property var menuStack: []          // folder nodes from the root down to the current level
    property string menuPendingId: ""   // row waiting for a second Enter (confirm: true)

    // -- Wi-Fi / Bluetooth picker
    property string netPassFor: ""          // SSID waiting for a password ("" = normal typing)
    property string netPass: ""             // what is typed meanwhile; it never goes into root.query (no AI, no lookups)
    property string netPassReturnText: ""
    property string _netWordShown: ""       // "wifi" | "bluetooth" while that bare keyword is typed

    // -- Volume card (typing "volume")
    property real volLevel: 0
    property bool volMuted: false
    property bool volDragging: false
    property double _volHold: 0             // ignore polled values until this time (ms), so the bar does not jump back
    readonly property bool volCardShown: root.results.some(r => r.kind === "volume")

    // -- Brightness card (typing "brightness" / "brilho"): controls the monitor this Spotlight is open on,
    //    through the shell's Brightness service (brightnessctl for the laptop panel, ddcutil for external monitors)
    readonly property var brightMonitor: Brightness.getMonitorForScreen(root.screen)
    readonly property real brightLevel: brightMonitor ? brightMonitor.brightness : 0
    readonly property bool brightControllable: !!brightMonitor
        && (brightMonitor.isDdc || /^(eDP|LVDS|DSI)/i.test(root.screen ? root.screen.name : ""))
    readonly property bool brightCardShown: root.results.some(r => r.kind === "brightness")

    // -- Microphone card ("mic")
    property real micLevel: 0
    property bool micMuted: false
    property bool micDragging: false
    property double _micHold: 0
    readonly property bool micCardShown: root.results.some(r => r.kind === "mic")

    // -- Bedroom light card ("luz"): scripts/lamp/lamp.py talks to the bulb over the local network
    property real lampLevel: 0.5
    property bool lampOn: false
    property bool lampDragging: false
    property bool lampKnown: false          // true once the bulb has answered
    property string lampError: ""
    property double _lampHold: 0            // ignore polled values until this time (ms), so the bar does not jump back
    property int _lampTarget: 50
    readonly property bool lampCardShown: root.results.some(r => r.kind === "lamp")
    readonly property string lampScript: Quickshell.shellPath("scripts/lamp/lamp.py").toString().replace(/^file:\/\//, "")

    // -- Night light card ("noite"): shell's Hyprsunset service, temperature kept in the shell config
    readonly property bool nightActive: Hyprsunset.temperatureActive
    readonly property int nightTemp: Hyprsunset.colorTemperature
    readonly property real nightLevel: Math.max(0, Math.min(1, (6000 - nightTemp) / 3500))   // 0 = 6000K (neutral), 1 = 2500K (warm)
    property int _nightTarget: 5000
    readonly property bool nightCardShown: root.results.some(r => r.kind === "night")

    // -- Power profile card ("energia")
    property var ppProfiles: []
    property string ppCurrent: ""
    property double _ppHold: 0
    readonly property bool powerCardShown: root.results.some(r => r.kind === "power")
    readonly property string powerBatteryText: Battery.available
        ? (Math.round(Battery.percentage * 100) + "%" + (Battery.isCharging ? " \u00B7 charging" : (Battery.isPluggedIn ? " \u00B7 plugged in" : "")))
        : ""

    // -- QR card ("qr text" / "wifi qr")
    property string _qrWanted: ""       // "" | "wifi" | "t:<text>"
    property string _qrRanFor: ""
    property string _qrOut: ""
    property int _qrSeq: 0
    property string qrFile: ""
    property string qrLabel: ""
    property bool qrBusy: false
    property string qrError: ""
    readonly property bool qrCardShown: root.results.some(r => r.kind === "qr")

    // -- /kill and /usb lists
    property var killList: []
    property var usbItems: []
    property string _extraShown: ""     // "kill" | "usb" | "keys" while that bare keyword is typed

    // -- File actions panel (Ctrl+K on a file) and rename
    property var fileActFor: null            // { path, name, isDirectory } while the panel is open
    property string fileActStage: "actions"  // "actions" | "apps" (Open with...)
    property string fileActPending: ""       // "trash" while waiting for the second Enter
    property var fileOpenWith: []            // [{ id, name, file }]
    property string renameFor: ""            // path being renamed ("" = normal typing)
    property string renameText: ""
    property string renameReturnText: ""

    // -- /keys
    property var keysItems: []
    property var contentResults: []
    property string _lastContentQuery: ""
    property var procItems: []
    property string _procKey: ""
    property var usageCounts: ({})
    property var _cache: ({})

    // -- Inline tools
    // Native MPRIS (no polling), Spotify only: every other player is ignored.
    // Prefers a Spotify player that is playing, otherwise the first one with a track.
    function isSpotify(pl) {
        const id = ((pl.dbusName || "") + " " + (pl.identity || "") + " " + (pl.desktopEntry || "")).toLowerCase();
        return id.indexOf("spotify") >= 0;
    }
    readonly property var mprisPlayer: {
        const list = Mpris.players.values;
        let fallback = null;
        for (let i = 0; i < list.length; i++) {
            const pl = list[i];
            if (!root.isSpotify(pl)) continue;
            if (pl.isPlaying) return pl;
            if (!fallback && (pl.trackTitle || "") !== "") fallback = pl;
        }
        return fallback;
    }
    readonly property string nowPlayingText: {
        const pl = root.mprisPlayer;
        if (!pl) return "";
        const title = pl.trackTitle || "";
        const artist = pl.trackArtist || "";
        return (artist && title) ? artist + " - " + title : (title || artist);
    }
    readonly property string nowPlayingStatus: root.mprisPlayer ? (root.mprisPlayer.isPlaying ? "Playing" : "Paused") : ""
    readonly property string nowPlayingArt: root.mprisPlayer ? (root.mprisPlayer.trackArtUrl || "") : ""
    onNowPlayingTextChanged: root.rebuildIfShown()
    onNowPlayingStatusChanged: root.rebuildIfShown()
    property string sysStatsText: ""
    property string weatherText: ""      // error / fallback text
    property var weatherData: null       // structured data for the weather card
    property string _wxLastCity: ""
    property string timeText: ""
    property string _timeKey: ""
    property string dictText: ""
    property string batteryText: ""
    property string ipText: ""
    property string currencyText: ""
    property var _pendingCurrency: null
    property string passText: ""
    property string _passKey: ""
    property int _passWanted: 0
    property var devResult: ({ q: "", text: "", label: "" })
    property string _devQ: ""
    property var quoteResult: ({ q: "", loading: false, text: "", sub: "", raw: "" })
    property string _quoteQ: ""
    property var _pendingQuote: null
    property string _devLabel: ""

    // -- Request counters (discard stale responses)
    property int _fdReq: 0
    property int _rgReq: 0
    property int _psReq: 0
    property int _devReq: 0
    property int _wxReq: 0
    property int _timeReq: 0
    property int _aiReq: 0
    property var _wxGeoXhr: null
    property var _wxDataXhr: null
    property var _timeXhr: null
    property var _aiXhr: null

    // -- Preview
    property string previewPath: ""
    property string previewKind: ""
    property string previewText: ""
    property string previewThumbPath: ""
    property real previewNatW: 0
    property real previewNatH: 0
    property string _previewKeyShown: ""
    property var _pendingPreview: ({ for: "", path: "", kind: "" })
    readonly property bool previewAudioPlaying: audioLoader.item ? audioLoader.item.playing : false
    readonly property var previewBox: {
        const k = root.previewKind;
        if (k === "text" || k === "markdown") return { w: 420, h: 660 };
        if (k === "pdf" || k === "image" || k === "video") return root.previewSizeLarge();
        return root.previewSize();
    }

    // -- AI
    property string aiText: ""
    property string _lastAiQuery: ""
    property bool aiLoading: false
    property string _pendingAiPrompt: ""
    property int _aiRetries: 0
    property var aiHistory: []
    property bool aiConversationMode: false
    property bool _internalNext: false      // the next runHermes() call carries untrusted/internal content
    property bool _lastInternal: false
    property string _aiIntent: ""           // structured intent of the request in flight
    readonly property bool aiErrored: root.aiText.startsWith("No response")
                                     || root.aiText.startsWith("Hermes Agent:")
                                     || root.aiText.startsWith("Error querying")

    // -- Screen capture / OCR
    property bool _screenshotSelecting: false
    property string _ocrMode: "analyze"   // "analyze" | "translate"
    property string _ocrLang: "pt"
    property string _resumeFocus: ""

    // -- Body height (evaluated once per change)
    property bool hasBody: (root.mode !== "search"
            || root.query.length > 0
            || root.items.length > 0
            || root.nowPlayingText.length > 0)
        && !(root.railOpen && root.query.length === 0)
    readonly property real resultsHeight: root.computeResultsHeight()
    // framed = glass panel with padding around the search pill (only when there is a list; otherwise just the pill)
    readonly property bool framed: root.hasBody
    property real bodyPad: root.framed ? root.panelPad : 0
    Behavior on bodyPad { NumberAnimation { duration: root.animMed; easing.type: Easing.OutCubic } }
    readonly property real panelTotalH: root.searchH + root.bodyPad * 2 + (root.hasBody ? root.listGap + root.resultsHeight + root.footerH + root.listPad : 0)

    // Footer key hints: what Enter does for the selected item, plus the shortcuts that really exist
    readonly property var footerHints: {
        const it = root.selectedItem;
        const out = [];
        let enter = "Open";
        if (it) {
            switch (it.kind) {
                case "clip": case "calc": case "emoji": case "info": enter = "Copy"; break;
                case "proc":   enter = "Quit"; break;
                case "window": enter = "Focus"; break;
                case "wifi":   enter = it.active ? "Connected" : ((it.secure && !it.saved) ? "Enter password" : "Connect"); break;
                case "bt":     enter = it.connected ? "Disconnect" : (it.paired ? "Connect" : "Pair & connect"); break;
                case "kproc":  enter = "Terminate"; break;
                case "usb":    enter = it.mp ? "Eject" : "Mount"; break;
                case "fact":   enter = (it.act === "with") ? "Choose" : ((it.act === "rename") ? "Rename" : "Run"); break;
                case "fapp":   enter = "Open"; break;
                case "key":    enter = "Copy shortcut"; break;
                case "menu":   enter = it.isFolder ? "Open" : (it.confirm ? "Run (confirm)" : "Run"); break;
                case "media":  enter = "Play/Pause"; break;
            }
        }
        out.push({ k: "\u21B5", t: enter });
        if (it && it.kind === "file") out.push({ k: "Shift \u21B5", t: "Actions" });
        if (it && it.kind === "file") out.push({ k: "Ctrl \u21B5", t: "Open folder" });
        if (it && it.kind === "file") out.push({ k: "Ctrl C", t: "Copy path" });
        if (it && it.kind === "wifi" && it.secure) out.push({ k: "Shift \u21B5", t: "New password" });
        if (it && it.kind === "bt" && it.paired) out.push({ k: "Shift \u21B5", t: "Forget" });
        if (it && it.kind === "kproc") out.push({ k: "Shift \u21B5", t: "Force kill" });
        if (it && it.kind === "usb" && it.mp) out.push({ k: "Shift \u21B5", t: "Open folder" });
        if (it && it.kind === "clip" && root.mode === "clipboard") out.push({ k: "Ctrl P", t: it.pinned ? "Unpin" : "Pin" });
        if (it && it.kind === "clip" && it.pinned && (root.clipPins || []).length > 1 && root.mode === "clipboard") out.push({ k: "Hold", t: "Reorder" });
        if (root.mode === "menu" && root.menuStack.length > 0) out.push({ k: "Bksp", t: "Back" });
        out.push({ k: "Tab", t: "Modes" });
        return out;
    }

    // =====================================================================
    //  BASIC UTILITIES
    // =====================================================================
    function pad2(n) { return n < 10 ? "0" + n : String(n); }
    function hasOwn(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }

    // Spotlight temp directory (per user); cleanup only removes old files
    readonly property string tmpDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/spotlight"
    function tmpPrep(prefix) {
        const d = root.shellQuote(root.tmpDir);
        return "mkdir -p " + d + " && find " + d + " -name " + root.shellQuote(prefix + "_*") + " -mmin +5 -delete 2>/dev/null; ";
    }
    function shellQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
    function urlq(s) { return encodeURIComponent(String(s)).replace(/'/g, "%27"); }

    function xdgOpenCmd(target) {
        return "setsid nohup env XDG_RUNTIME_DIR=/run/user/$(id -u) " +
               "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus " +
               "xdg-open " + root.shellQuote(target) + " </dev/null >/dev/null 2>&1";
    }
    // Opens the current config's settings.qml (<config>/settings.qml) and closes Spotlight
    function openSettingsApp() {
        spotlightController.run("qs -p " + root.shellQuote(Quickshell.shellPath("settings.qml")) + " --no-duplicate");
        spotlightController.spotlightOpen = false;
    }

    function xdgOpen(target) { spotlightController.run(root.xdgOpenCmd(target) + " &"); }

    function fileUrl(path) {
        if (!path) return "";
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function openUrl(u) {
        let ok = false;
        try { ok = Qt.openUrlExternally(u); } catch (e) { }
        if (!ok) {
            spotlightController.run(
                "(" + root.xdgOpenCmd(u) + ") || gio open " + root.shellQuote(u) + " >/dev/null 2>&1 &"
            );
        }
    }

    function copyText(s) {
        spotlightController.run("printf '%s' " + root.shellQuote(s) + " | wl-copy 2>/dev/null || true");
    }

    function notify(msg, critical) {
        spotlightController.run("notify-send " + (critical ? "-u critical " : "") + "'Spotlight' " + root.shellQuote(msg));
    }

    function rebuildIfShown() { if (root._shown) root.scheduleRebuild(); }

    function mediaControl(cmd) {
        const pl = root.mprisPlayer;
        if (!pl) return;
        if (cmd === "previous") pl.previous();
        else if (cmd === "next") pl.next();
        else if (pl.canTogglePlaying) pl.togglePlaying();
        else if (pl.isPlaying) pl.pause();
        else pl.play();
    }

    function splitPath(p) {
        const i = p.lastIndexOf("/");
        return { name: i >= 0 ? p.slice(i + 1) : p, dir: i > 0 ? p.slice(0, i) : "~" };
    }

    function _msg(role, content, label) {
        return { role: role, content: content, label: label || "", ts: Qt.formatTime(new Date(), "hh:mm") };
    }

    function abortXhr(x) { if (x) { try { x.abort(); } catch (e) { } } }

    function httpJson(url, timeoutMs, cb) {
        const x = new XMLHttpRequest();
        x.timeout = timeoutMs;
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            let data = null;
            try { data = JSON.parse(x.responseText); } catch (e) { data = null; }
            cb(data, x);
        };
        x.open("GET", url);
        x.send();
        return x;
    }

    // -- In-memory cache (in-place mutation, no object copy on every write)
    function cacheGet(key, ttlMs) {
        const c = root._cache[key];
        if (!c) return null;
        if (Date.now() - c.t > ttlMs) return null;
        return c.v;
    }

    function cacheSet(key, value) {
        const c = root._cache;
        c[key] = { v: value, t: Date.now() };
        const keys = Object.keys(c);
        if (keys.length > 200) {
            keys.sort((a, b) => c[a].t - c[b].t);
            for (let i = 0; i < keys.length - 150; i++) delete c[keys[i]];
        }
    }

    // -- Usage count (also in-place)
    function itemKey(it) {
        if (!it) return "";
        return it.kind + ":" + (it.path || it.exec || it.address || it.action || it.id || it.text || it.name || "");
    }

    function recordUsage(key) {
        const counts = root.usageCounts;
        counts[key] = (counts[key] || 0) + 1;
        const keys = Object.keys(counts);
        if (keys.length > 600) {
            const fk = keys.filter(k => k.startsWith("file:")).sort((a, b) => counts[a] - counts[b]);
            for (let i = 0; i < keys.length - 500 && i < fk.length; i++) delete counts[fk[i]];
        }
        _saveUsage.command = ["bash", "-c", "mkdir -p ~/.cache && printf '%s' " + root.shellQuote(JSON.stringify(counts)) + " > ~/.cache/spotlight-usage.json"];
        _saveUsage.running = true;
    }

    function usageOf(key) { return root.usageCounts[key] || 0; }

    // =====================================================================
    //  TIMER / REMINDERS / TODO / EVENTS
    // =====================================================================
    function startTimer(secs, label) {
        const n = parseInt(secs);
        if (isNaN(n) || n <= 0) return;
        TimerService.setCountdownTime(n);
        TimerService.toggleCountdown();
        root.notify("Timer started (" + label + ")");
    }

    // Local reminder timer — independent from TimerService (no bar UI).
    // Plays the same alarm sound as the bar timer (TimerService.refreshCountdown).
    Component {
        id: localReminderComponent
        Timer {
            property double endMs: 0
            property string msg: ""
            interval: 200
            repeat: true
            running: true
            onTriggered: {
                if (Date.now() >= endMs) {
                    running = false;
                    Audio.playSystemSound("alarm-clock-elapsed");
                    Quickshell.execDetached(["notify-send", "Lembrete", msg, "-a", "Shell", "-u", "critical"]);
                    destroy();
                }
            }
        }
    }

    function scheduleLocalReminder(seconds, text) {
        const secs = parseInt(seconds);
        if (isNaN(secs) || secs <= 0) return;
        localReminderComponent.createObject(root, { endMs: Date.now() + secs * 1000, msg: String(text) });
        const target = new Date(Date.now() + secs * 1000);
        const now = new Date();
        const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        const sameDay = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
        const clock = root.pad2(target.getHours()) + ":" + root.pad2(target.getMinutes());
        let when;
        if (sameDay(target, now)) when = "às " + clock;
        else if (sameDay(target, tomorrow)) when = "amanhã às " + clock;
        else when = root.pad2(target.getDate()) + "/" + root.pad2(target.getMonth() + 1) + " às " + clock;
        root.notify("⏰ Lembrete agendado para " + when + ": " + text);
    }

    function scheduleReminder(whenStr, text) {
        const env = "DISPLAY=:0 WAYLAND_DISPLAY=wayland-1 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus XDG_RUNTIME_DIR=/run/user/$(id -u)";
        const script = env + ' notify-send -a "Shell Reminder" "$1"';
        spotlightController.run(
            "systemd-run --user --quiet --collect --on-calendar=" + root.shellQuote(whenStr) +
            " --timer-property=AccuracySec=1s" +
            " bash -c " + root.shellQuote(script) + " _ " + root.shellQuote(text)
        );
    }

    function parseTodoInput(raw) {
        let text = String(raw).trim();
        const pad = root.pad2;
        let hh = -1, mm = 0;
        let hasDate = false, dY = 0, dM = 0, dD = 0;
        const timeRe = /\s+(?:(?:[àa]s|at)\s+(\d{1,2})(?::(\d{2})|h(\d{2})?)?|(\d{1,2})(?::(\d{2})|h(\d{2})?))$/i;
        const dateRe = /\s+(?:(\d{4})-(\d{1,2})-(\d{1,2})|(\d{1,2})\/(\d{1,2})(?:\/(\d{4}))?)$/;
        for (let pass = 0; pass < 2; pass++) {
            if (hh < 0) {
                const tm = text.match(timeRe);
                if (tm) {
                    const h = parseInt(tm[1] ?? tm[4]);
                    const mi = parseInt(tm[2] ?? tm[3] ?? tm[5] ?? tm[6] ?? "0");
                    if (h >= 0 && h <= 23 && mi >= 0 && mi <= 59) {
                        hh = h; mm = mi;
                        text = text.slice(0, text.length - tm[0].length).trim();
                    }
                }
            }
            if (!hasDate) {
                const dm = text.match(dateRe);
                if (dm) {
                    const iso = !!dm[1];
                    const mo = parseInt(iso ? dm[2] : dm[5]);
                    const d = parseInt(iso ? dm[3] : dm[4]);
                    const now = new Date();
                    let y = iso ? parseInt(dm[1]) : (dm[6] ? parseInt(dm[6]) : now.getFullYear());
                    if (!iso && !dm[6] && new Date(y, mo - 1, d, 23, 59) < now) y += 1;
                    const check = new Date(Date.UTC(y, mo - 1, d, 12));
                    if (mo >= 1 && mo <= 12 && check.getUTCMonth() === mo - 1 && check.getUTCDate() === d) {
                        hasDate = true; dY = y; dM = mo; dD = d;
                        text = text.slice(0, text.length - dm[0].length).trim();
                    }
                }
            }
        }
        let remindAt = "", remindMs = 0, timeStr = "";
        if (hh >= 0) {
            const now = new Date();
            let target;
            if (hasDate) target = new Date(dY, dM - 1, dD, hh, mm);
            else {
                target = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hh, mm);
                if (target <= now) target.setDate(target.getDate() + 1);
            }
            dY = target.getFullYear(); dM = target.getMonth() + 1; dD = target.getDate();
            hasDate = true;
            timeStr = pad(hh) + ":" + pad(mm);
            remindAt = dY + "-" + pad(dM) + "-" + pad(dD) + " " + timeStr + ":00";
            remindMs = target.getTime();
        }
        let dueStr = "", dueLabel = "";
        if (hasDate) {
            dueStr = dY + "-" + pad(dM) + "-" + pad(dD);
            dueLabel = pad(dD) + "/" + pad(dM) + "/" + dY + (timeStr ? " " + timeStr : "");
        }
        return { text: text, dueStr: dueStr, dueLabel: dueLabel, remindAt: remindAt, remindMs: remindMs };
    }

    function parseEventInput(raw) {
        let text = String(raw).trim();
        let duration = 60;
        const dm = text.match(/\s+(?:por|for)\s+(\d+)\s*(h|hora|horas|hour|hours|min|m)$/i);
        if (dm) {
            const n = parseInt(dm[1]);
            const u = dm[2].toLowerCase();
            duration = (u === "h" || u === "hora" || u === "horas" || u === "hour" || u === "hours") ? n * 60 : n;
            if (duration <= 0) duration = 60;
            text = text.slice(0, text.length - dm[0].length).trim();
        }
        const t = root.parseTodoInput(text);
        return { text: t.text, dueStr: t.dueStr, dueLabel: t.dueLabel, remindAt: t.remindAt, remindMs: t.remindMs, duration: duration };
    }

    function todoActionItem(t) {
        return {
            kind: "action",
            name: "Add to ToDo: \u201c" + t.text + "\u201d" + (t.dueLabel ? " \u00b7 " + t.dueLabel : ""),
            action: "addtodo:",
            todoText: t.text,
            todoDue: t.dueStr,
            todoRemind: t.remindAt,
            todoRemindMs: t.remindMs,
            iconKey: "note",
            category: t.remindAt ? "ToDo \u00b7 will remind you on time" : "ToDo"
        };
    }

    function addTodoFromItem(e) {
        let due = undefined;
        if (e.todoDue) {
            const p = e.todoDue.split("-").map(Number);
            due = new Date(Date.UTC(p[0], p[1] - 1, p[2], 12));
        }
        Todo.addTask(e.todoText, due);
        if (e.todoRemind && e.todoRemindMs > Date.now()) {
            root.scheduleReminder(e.todoRemind, e.todoText);
            root.notify("Added to ToDo \u00b7 aviso agendado");
        } else {
            root.notify("Added to ToDo");
        }
    }

    // ---- launch an app, or focus its window when it is already open (Shift = always launch a new instance)
    function _wmNorm(v) { return String(v || "").toLowerCase().replace(/[^a-z0-9]/g, ""); }

    // Names the app may use as its window app-id / class
    function _appKeys(e) {
        const keys = [];
        const add = (v) => { const n = root._wmNorm(v); if (n.length >= 3 && keys.indexOf(n) < 0) keys.push(n); };
        const parts = String(e.exec || "").split(/\s+/).filter(Boolean);
        let i = 0;
        while (i < parts.length && (parts[i] === "env" || parts[i].indexOf("=") > 0)) i++;
        const isFlatpak = (String(parts[i] || "").split("/").pop() === "flatpak" && parts[i + 1] === "run");
        if (isFlatpak) {
            // For Flatpak apps, only use the Flatpak app ID as key
            // Don't use wmClass (shared with system version) or generic executable name
            for (let j = i + 2; j < parts.length; j++) {
                if (parts[j].charAt(0) === "-") continue;
                add(parts[j]); add(parts[j].split(".").pop());
                break;
            }
            if (e.id) { add(e.id); add(String(e.id).replace(/\.desktop$/, "").split(".").pop()); }
        } else {
            // System apps: use wmClass, executable name, and desktop ID
            add(e.wmClass);
            if (e.id) { add(e.id); add(String(e.id).replace(/\.desktop$/, "").split(".").pop()); }
            add(e.name);
            if (parts[i]) {
                add(parts[i].split("/").pop());
            }
        }
        return keys;
    }

    // Best open window (from `hyprctl clients -j`) for this app: class / initialClass first, title as a last resort
    function findOpenWindow(e, list) {
        const keys = root._appKeys(e);
        if (!keys.length) return null;
        let best = null, bestScore = 0;
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            let score = 0;
            for (const cand of [w.cls, w.icls]) {
                const id = root._wmNorm(cand);
                if (!id) continue;
                const last = root._wmNorm(String(cand).split(".").pop());
                for (const k of keys) {
                    if (id === k || last === k) score = Math.max(score, 3);
                    else if (k.length >= 5 && (id.indexOf(k) >= 0 || (id.length >= 5 && k.indexOf(id) >= 0))) score = Math.max(score, 2);
                }
            }
            if (score === 0) {
                const t = root._wmNorm(w.title);
                for (const k of keys) if (k.length >= 5 && t.indexOf(k) >= 0) { score = 1; break; }
            }
            if (score > bestScore) { best = w; bestScore = score; }
        }
        return best;
    }

    // Already open -> jump to its workspace and focus it; otherwise launch (Shift always launches a new one).
    // The window list is read at click time, so it is never stale.
    property var _pendingApp: null
    function launchOrFocus(e, forceNew) {
        // Telegram (both system and Flatpak): always launch new instance to allow multiple accounts
        const isTelegram = /telegram/i.test(e.exec || "") || /telegram/i.test(e.name || "");
        // Flatpak apps with shared WMClass: always launch new instance
        const parts = String(e.exec || "").split(/\s+/).filter(Boolean);
        let i = 0;
        while (i < parts.length && (parts[i] === "env" || parts[i].indexOf("=") > 0)) i++;
        const isFlatpak = (String(parts[i] || "").split("/").pop() === "flatpak" && parts[i + 1] === "run");
        if (isTelegram || isFlatpak || forceNew || _focusProbe.running) {
            // Pass Wayland display for Flatpak apps
            const env = isFlatpak ? "WAYLAND_DISPLAY=wayland-1 " : "";
            spotlightApps.launch(env + e.exec);
            return;
        }
        root._pendingApp = e;
        _focusProbe.running = true;
    }

    // Focuses a window by address and VERIFIES it became the active one.
    // Waits for Spotlight to close first (its layer surface would otherwise steal the focus back),
    // tries the classic dispatcher and then the Lua-era one, and notifies if both fail.
    function focusWindowReliably(w, label) {
        const addr = String(w.address);
        if (!/^0x[0-9a-fA-F]+$/.test(addr)) return;
        const title = root.shellQuote("Couldn't focus " + (label || w.cls));
        const body = root.shellQuote("window class: " + w.cls + " (" + addr + ")");
        const cmd =
            "sleep 0.2; a=" + addr + "; " +
            "chk() { hyprctl activewindow -j 2>/dev/null | grep -q \"\\\"address\\\": \\\"$a\\\"\"; }; " +
            "hyprctl dispatch focuswindow \"address:$a\" >/dev/null 2>&1; sleep 0.05; chk && exit 0; " +
            "hyprctl dispatch \"hl.dsp.focus({ window = \\\"address:$a\\\" })\" >/dev/null 2>&1; sleep 0.05; chk && exit 0; " +
            "notify-send -a Spotlight " + title + " " + body;
        spotlightController.run(cmd);
    }

    Process {
        id: _focusProbe
        running: false
        command: ["bash", "-c", "hyprctl clients -j 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const e = root._pendingApp;
                root._pendingApp = null;
                if (!e) return;
                let list = [];
                try {
                    list = JSON.parse(text).map(w => ({ title: w.title || "", address: w.address, cls: w.class || "", icls: w.initialClass || "" }));
                } catch (err) { list = []; }
                const w = root.findOpenWindow(e, list);
                if (w && w.address) root.focusWindowReliably(w, e.name);
                else spotlightApps.launch(e.exec);
            }
        }
    }

    // =====================================================================
    //  PARSERS / CONVERTERS (color, calc, units, system controls)
    // =====================================================================
    function bangItem(q) {
        const m = q.match(/^([a-z]+)\s+(.+)$/i);
        if (!m) return null;
        const key = m[1].toLowerCase();
        if (!root.hasOwn(root.bangs, key)) return null;
        const b = root.bangs[key];
        const term = m[2].trim();
        if (!term) return null;
        return { kind: "action", name: b[0] + ": \u201c" + term + "\u201d", action: "open:" + b[1] + encodeURIComponent(term), iconKey: "web", category: "Site shortcut" };
    }

    function colorItem(q) {
        const m = q.match(/^#([0-9a-f]{3}|[0-9a-f]{6})$/i);
        if (!m) return null;
        let h = m[1];
        if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
        const r = parseInt(h.slice(0, 2), 16), g = parseInt(h.slice(2, 4), 16), b = parseInt(h.slice(4, 6), 16);
        const rn = r / 255, gn = g / 255, bn = b / 255;
        const mx = Math.max(rn, gn, bn), mn = Math.min(rn, gn, bn);
        const l = (mx + mn) / 2, d = mx - mn;
        let hue = 0, sat = 0;
        if (d > 0) {
            sat = d / (1 - Math.abs(2 * l - 1));
            if (mx === rn) hue = ((gn - bn) / d) % 6;
            else if (mx === gn) hue = (bn - rn) / d + 2;
            else hue = (rn - gn) / d + 4;
            hue = Math.round(hue * 60);
            if (hue < 0) hue += 360;
        }
        const hex = "#" + h.toLowerCase();
        return { kind: "calc", swatch: hex, raw: hex, iconKey: "calc",
                 name: hex.toUpperCase() + " \u2192 rgb(" + r + ", " + g + ", " + b + ") \u00b7 hsl(" + hue + ", " + Math.round(sat * 100) + "%, " + Math.round(l * 100) + "%)",
                 category: "Color \u2014 click to copy hex" };
    }

    function sysControlItems(ql) {
            const out = [];
            const add = (name, cmd) => out.push({ kind: "action", action: "shell", cmd: cmd, name: name, category: "System control", iconKey: "shortcut" });
            const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
            let m;
        
            // Trigger OSD when typing "volume" alone
            // (typing "volume" alone now shows the volume card instead of the OSD row)
        
            if ((m = ql.match(/^(?:volume|vol|som)\s*([+-])?\s*(\d{1,3})$/))) {
            const n = clamp(parseInt(m[2]), 0, 150);
            const fb = "; notify-send -t 1500 Volume \"$(wpctl get-volume @DEFAULT_AUDIO_SINK@)\"";
            if (m[1]) add("Volume " + m[1] + n + "%", "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ " + n + "%" + m[1] + fb + "; qs -c ii ipc call osdVolume trigger");
            else add("Volume: " + n + "%", "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ " + n + "%" + fb + "; qs -c ii ipc call osdVolume trigger");

            // Auto-execute when query is exactly "volume N" (no +/-)
            if (!m[1]) {
                const cmd = "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ " + n + "%" + fb + "; qs -c ii ipc call osdVolume trigger";
                spotlightController.run(cmd);
            }
        } else if (/^(mudo|mute|silenciar)$/.test(ql)) {
                add("Alternar mudo", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle; qs -c ii ipc call osdVolume trigger");
            } else if ((m = ql.match(/^(?:brilho|brightness|bright)\s*([+-])?\s*(\d{1,3})$/))) {
            const n = clamp(parseInt(m[2]), m[1] ? 0 : 1, 100);
            if (m[1]) add("Brightness " + m[1] + n + "%", "brightnessctl set " + n + "%" + m[1]);
            else add("Brightness: " + n + "%", "brightnessctl set " + n + "%");
        } else if ((m = ql.match(/^wifi\s+(on|off|ligar|desligar)$/))) {
            const on = (m[1] === "on" || m[1] === "ligar");
            add("Wi-Fi " + (on ? "on" : "off"), "nmcli radio wifi " + (on ? "on" : "off"));
        } else if ((m = ql.match(/^(?:bluetooth|bt)\s+(on|off|ligar|desligar)$/))) {
            const on = (m[1] === "on" || m[1] === "ligar");
            add("Bluetooth " + (on ? "on" : "off"), "bluetoothctl power " + (on ? "on" : "off"));
        } else if (/^(n[ãa]o perturbe|do not disturb|dnd|silencioso|silent)$/.test(ql)) {
            add("Toggle Do Not Disturb",
                "if command -v makoctl >/dev/null; then " +
                "  m=$(makoctl mode | grep -q '^dnd$' && echo default || echo dnd); makoctl mode -s \"$m\"; " +
                "elif command -v swaync-client >/dev/null; then swaync-client -d; " +
                "elif command -v dunstctl >/dev/null; then dunstctl set-paused toggle; " +
                "fi");
        } else if ((m = ql.match(/^(?:luz|l[a\u00e2]mpada|lampada|lamp)(?:\s+(.*))?$/))) {
            // Bedroom bulb, over the local network (scripts/lamp/lamp.py, needs tinytuya
            // and ~/.config/ii-lamp/devices.json). "luz" alone offers the usual choices.
            const arg = (m[1] || "").trim();
            const script = Quickshell.shellPath("scripts/lamp/lamp.py").toString().replace(/^file:\/\//, "");
            const lamp = (name, args) => add(name, "python3 \"" + script + "\" " + args);
            const colors = { vermelha: "vermelha", vermelho: "vermelha", red: "red", verde: "verde", green: "green",
                azul: "azul", blue: "blue", amarela: "amarela", amarelo: "amarela", yellow: "yellow",
                laranja: "laranja", orange: "orange", roxa: "roxa", roxo: "roxa", purple: "purple",
                rosa: "rosa", pink: "pink", ciano: "ciano", cyan: "cyan" };
            const temps = { quente: "quente", warm: "warm", neutra: "neutra", neutro: "neutra", neutral: "neutral",
                fria: "fria", frio: "fria", cool: "cool" };
            let n;
            if (arg === "") {
                lamp("Alternar luz do quarto", "toggle");
                lamp("Acender luz", "on");
                lamp("Apagar luz", "off");
                lamp("Luz com brilho 50%", "brightness 50");
            } else if (/^(on|ligar|liga|acender|acende)$/.test(arg)) {
                lamp("Acender luz", "on");
            } else if (/^(off|desligar|desliga|apagar|apaga)$/.test(arg)) {
                lamp("Apagar luz", "off");
            } else if (/^(toggle|alternar|inverter)$/.test(arg)) {
                lamp("Alternar luz do quarto", "toggle");
            } else if ((n = arg.match(/^(\d{1,3})\s*%?$/))) {
                const pct = clamp(parseInt(n[1]), 1, 100);
                lamp("Luz com brilho " + pct + "%", "brightness " + pct);
            } else if (temps[arg]) {
                lamp("Luz branca " + arg, "temp " + temps[arg]);
            } else if (colors[arg]) {
                lamp("Luz " + arg, "color " + colors[arg]);
            } else if (/^#[0-9a-f]{6}$/.test(arg)) {
                lamp("Luz na cor " + arg, "color " + arg);
            }
        }
        return out;
    }

    function evalMath(q) {
        if (!/^[0-9+\-*/%.()\s]+$/.test(q)) return null;
        try {
            const r = Function('"use strict";return (' + q + ')')();
            if (typeof r !== "number" || !isFinite(r)) return null;
            return r;
        } catch (e) { return null; }
    }

    function convertUnits(q) {
        const s = q.trim().toLowerCase().replace(/,/g, ".");
        const m = s.match(/^(-?[\d.]+)\s*([a-zçãõáéíóúâêô°\/]+)\s+(?:in|to|em|para|->|=)\s+([a-zçãõáéíóúâêô°\/]+)$/);
        if (!m) return null;
        const val = parseFloat(m[1]);
        if (isNaN(val)) return null;
        const alias = {
            milha: "mi", milhas: "mi", mile: "mi", miles: "mi", libra: "lb", libras: "lb", pound: "lb", pounds: "lb", lbs: "lb",
            metro: "m", metros: "m", meter: "m", meters: "m",
            "quilômetro": "km", "quilômetros": "km", quilometro: "km", quilometros: "km", kilometer: "km", kilometers: "km",
            "centímetro": "cm", "centímetros": "cm", centimetro: "cm", centimetros: "cm",
            "milímetro": "mm", "milímetros": "mm", milimetro: "mm", milimetros: "mm",
            polegada: "in", polegadas: "in", inch: "in", inches: "in", pol: "in",
            "pé": "ft", "pés": "ft", pe: "ft", pes: "ft", feet: "ft", foot: "ft",
            jarda: "yd", jardas: "yd", yard: "yd", yards: "yd",
            quilo: "kg", quilos: "kg", kilo: "kg", kilos: "kg", quilograma: "kg", quilogramas: "kg",
            grama: "g", gramas: "g", tonelada: "t", toneladas: "t",
            "onça": "oz", "onças": "oz", onca: "oz", oncas: "oz", ounce: "oz", ounces: "oz",
            litro: "l", litros: "l", liter: "l", liters: "l", litre: "l", litres: "l",
            "galão": "gal", galao: "gal", "galões": "gal", galoes: "gal", gallon: "gal", gallons: "gal",
            "xícara": "cup", xicara: "cup", cups: "cup",
            celsius: "c", "°c": "c", fahrenheit: "f", "°f": "f", kelvin: "k",
            "km/h": "kmh", kph: "kmh", kmph: "kmh", "m/s": "ms",
            byte: "b", bytes: "b", kilobyte: "kb", kilobytes: "kb", megabyte: "mb", megabytes: "mb",
            gigabyte: "gb", gigabytes: "gb", terabyte: "tb", terabytes: "tb"
        };
        const cats = {
            len:   { mm: 0.001, cm: 0.01, m: 1, km: 1000, "in": 0.0254, ft: 0.3048, yd: 0.9144, mi: 1609.344 },
            mass:  { mg: 1e-6, g: 0.001, kg: 1, t: 1000, oz: 0.028349523, lb: 0.45359237 },
            vol:   { ml: 0.001, l: 1, gal: 3.785411784, cup: 0.2365882365, floz: 0.0295735296 },
            data:  { b: 1, kb: 1e3, mb: 1e6, gb: 1e9, tb: 1e12, kib: 1024, mib: 1048576, gib: 1073741824, tib: 1099511627776 },
            speed: { kmh: 1 / 3.6, mph: 0.44704, ms: 1, kn: 0.514444 }
        };
        const names = { kmh: "km/h", ms: "m/s", c: "\u00b0C", f: "\u00b0F", k: "K", floz: "fl oz" };
        const norm = (u) => root.hasOwn(alias, u) ? alias[u] : u;
        const label = (u) => root.hasOwn(names, u) ? names[u] : u;
        const fmt = (v) => String(parseFloat(v.toPrecision(8)));
        const from = norm(m[2]), to = norm(m[3]);
        const temps = ["c", "f", "k"];
        if (temps.indexOf(from) >= 0 && temps.indexOf(to) >= 0) {
            const c = from === "c" ? val : from === "f" ? (val - 32) * 5 / 9 : val - 273.15;
            const r = to === "c" ? c : to === "f" ? c * 9 / 5 + 32 : c + 273.15;
            return fmt(r) + " " + label(to);
        }
        for (const cat of Object.keys(cats)) {
            const t = cats[cat];
            if (root.hasOwn(t, from) && root.hasOwn(t, to)) return fmt(val * t[from] / t[to]) + " " + label(to);
        }
        return null;
    }

    function urlTarget(q) {
        const t = q.trim();
        if (!t || /\s/.test(t)) return "";
        try {
            const u = new URL(/^https?:\/\//i.test(t) ? t : "https://" + t);
            const host = u.hostname;
            if (!host.includes(".")) return "";
            const tld = host.split(".").pop();
            if (tld.length < 2) return "";
            return u.toString();
        } catch (e) { return ""; }
    }

    function looksLikeUrl(t) {
        return /^(https?:\/\/|www\.)\S+$/i.test(t) || /^[\w-]+(\.[\w-]+)+(\/\S*)?$/.test(t);
    }

    function langName(c) {
        const n = { en: "English", pt: "Brazilian Portuguese", es: "Spanish", fr: "French", de: "German", it: "Italian",
                    ja: "Japanese", ko: "Korean", zh: "Chinese", ru: "Russian", ar: "Arabic", nl: "Dutch", pl: "Polish", tr: "Turkish" };
        const k = c.toLowerCase();
        return root.hasOwn(n, k) ? n[k] : c;
    }

    // =====================================================================
    //  INLINE TOOLS (weather, time, dictionary, currency, battery, IP, etc.)
    // =====================================================================
    function wxDescribe(code) {
        const m = {
            0: ["\u2600\ufe0f", "Clear sky"], 1: ["\ud83c\udf24\ufe0f", "Mostly clear"],
            2: ["\u26c5", "Partly cloudy"], 3: ["\u2601\ufe0f", "Overcast"],
            45: ["\ud83c\udf2b\ufe0f", "Fog"], 48: ["\ud83c\udf2b\ufe0f", "Fog"],
            51: ["\ud83c\udf26\ufe0f", "Light drizzle"], 53: ["\ud83c\udf26\ufe0f", "Drizzle"], 55: ["\ud83c\udf26\ufe0f", "Heavy drizzle"],
            61: ["\ud83c\udf27\ufe0f", "Light rain"], 63: ["\ud83c\udf27\ufe0f", "Rain"], 65: ["\ud83c\udf27\ufe0f", "Heavy rain"],
            66: ["\ud83c\udf27\ufe0f", "Freezing rain"], 67: ["\ud83c\udf27\ufe0f", "Heavy freezing rain"],
            71: ["\ud83c\udf28\ufe0f", "Light snow"], 73: ["\ud83c\udf28\ufe0f", "Snow"], 75: ["\ud83c\udf28\ufe0f", "Heavy snow"],
            80: ["\ud83c\udf26\ufe0f", "Rain showers"], 81: ["\ud83c\udf27\ufe0f", "Heavy showers"], 82: ["\u26c8\ufe0f", "Violent showers"],
            95: ["\u26c8\ufe0f", "Thunderstorm"], 96: ["\u26c8\ufe0f", "Thunderstorm with hail"], 99: ["\u26c8\ufe0f", "Thunderstorm with heavy hail"]
        };
        return m[code] || ["\ud83c\udf21\ufe0f", "—"];
    }

    function wxKind(code, isDay) {
        if (code === 0 || code === 1) return isDay ? "clear" : "clear-night";
        if (code === 2) return isDay ? "partly" : "partly-night";
        if (code === 3) return "cloud";
        if (code === 45 || code === 48) return "fog";
        if (code >= 51 && code <= 57) return "drizzle";
        if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return "rain";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow";
        if (code >= 95) return "storm";
        return "cloud";
    }

    function wxHourLabel(timeStr) {
        const h = parseInt(timeStr.substr(11, 2), 10);
        return ((h % 12) || 12) + (h < 12 ? "am" : "pm");
    }

    // v: string (error text) or object (weather card data)
    function _setWeather(v) {
        if (typeof v === "string") { root.weatherData = null; root.weatherText = v; }
        else { root.weatherText = ""; root.weatherData = v; }
        root.rebuildIfShown();
    }

    function fetchWeather(city, preferBR) {
            // Known major cities - prefer the famous one
            const majorCities = {
                "londres": { country: "GB", english: "London" }, "london": { country: "GB", english: "London" },
                "toquio": { country: "JP", english: "Tokyo" }, "tokyo": { country: "JP", english: "Tokyo" }, "tóquio": { country: "JP", english: "Tokyo" },
                "paris": { country: "FR", english: "Paris" },
                "nova york": { country: "US", english: "New York" }, "new york": { country: "US", english: "New York" },
                "roma": { country: "IT", english: "Rome" }, "rome": { country: "IT", english: "Rome" },
                "madrid": { country: "ES", english: "Madrid" },
                "berlim": { country: "DE", english: "Berlin" }, "berlin": { country: "DE", english: "Berlin" },
                "moscu": { country: "RU", english: "Moscow" }, "moscou": { country: "RU", english: "Moscow" }, "moscow": { country: "RU", english: "Moscow" },
                "pequim": { country: "CN", english: "Beijing" }, "beijing": { country: "CN", english: "Beijing" },
                "shangai": { country: "CN", english: "Shanghai" }, "shanghai": { country: "CN", english: "Shanghai" },
                "hong kong": { country: "HK", english: "Hong Kong" },
                "singapura": { country: "SG", english: "Singapore" }, "singapore": { country: "SG", english: "Singapore" },
                "dubai": { country: "AE", english: "Dubai" },
                "sydney": { country: "AU", english: "Sydney" },
                "toronto": { country: "CA", english: "Toronto" },
                "vancouver": { country: "CA", english: "Vancouver" },
                "montreal": { country: "CA", english: "Montreal" },
                "los angeles": { country: "US", english: "Los Angeles" },
                "chicago": { country: "US", english: "Chicago" },
                "buenos aires": { country: "AR", english: "Buenos Aires" },
                "cidade do mexico": { country: "MX", english: "Mexico City" }, "mexico city": { country: "MX", english: "Mexico City" },
                "bangkok": { country: "TH", english: "Bangkok" },
                "seul": { country: "KR", english: "Seoul" }, "seoul": { country: "KR", english: "Seoul" },
            };
            const cityLower = city.toLowerCase().trim();
            const majorCity = majorCities[cityLower];
            const preferredCountry = majorCity ? majorCity.country : null;
            const englishName = majorCity ? majorCity.english : city;
            const cacheSuffix = preferredCountry ? preferredCountry.toLowerCase() : (preferBR ? "br" : "any");
            const cacheKey = "wx3:" + cityLower + ":" + cacheSuffix;
            const cached = root.cacheGet(cacheKey, 5 * 60 * 1000);
            if (cached) { root._setWeather(cached); return; }

            const req = ++root._wxReq;
            root.abortXhr(root._wxGeoXhr);
            root.abortXhr(root._wxDataXhr);

            // Search by English name for major cities to get correct result
            const searchName = majorCity ? englishName : city;
            root._wxGeoXhr = root.httpJson(
                "https://geocoding-api.open-meteo.com/v1/search?count=10&language=en&name=" + encodeURIComponent(searchName),
                10000,
                function (geo) {
                    if (req !== root._wxReq) return;
                    const list = (geo && geo.results) || [];
                    let place = null;
                    if (preferredCountry) {
                        place = list.find(r => r.country_code === preferredCountry) || list[0] || null;
                    } else if (preferBR) {
                        place = list.find(r => r.country_code === "BR") || list[0] || null;
                    } else {
                        place = list[0] || null;
                    }
                    if (!place) { root._setWeather("City not found: " + city); return; }

                root._wxDataXhr = root.httpJson(
                    "https://api.open-meteo.com/v1/forecast?latitude=" + place.latitude + "&longitude=" + place.longitude +
                    "&current=temperature_2m,apparent_temperature,weather_code,is_day" +
                    "&hourly=temperature_2m,weather_code,precipitation_probability,is_day" +
                    "&daily=temperature_2m_max,temperature_2m_min" +
                    "&forecast_days=3&timezone=auto&temperature_unit=celsius",
                    10000,
                    function (wd) {
                        if (req !== root._wxReq) return;
                        try {
                            const c = wd.current, hr = wd.hourly, dl = wd.daily;
                            let i0 = hr.time.findIndex(t => t.substr(0, 13) === c.time.substr(0, 13));
                            if (i0 < 0) i0 = 0;

                            // "Now" + every 2 hours ahead
                            const hours = [{ label: "Now", temp: Math.round(c.temperature_2m), kind: root.wxKind(c.weather_code, c.is_day === 1) }];
                            for (let k = 1; k <= 6; k++) {
                                const i = i0 + 2 * k;
                                if (i >= hr.time.length) break;
                                hours.push({ label: root.wxHourLabel(hr.time[i]), temp: Math.round(hr.temperature_2m[i]),
                                             kind: root.wxKind(hr.weather_code[i], hr.is_day[i] === 1) });
                            }

                            // precipitation outlook from now until the end of tomorrow
                            const curHour = parseInt(c.time.substr(11, 2), 10);
                            const last = Math.min(hr.time.length - 1, i0 + (24 - curHour) + 23);
                            let maxP = 0, minT = 1e9;
                            for (let i = i0; i <= last; i++) {
                                maxP = Math.max(maxP, hr.precipitation_probability[i] || 0);
                                minT = Math.min(minT, hr.temperature_2m[i]);
                            }
                            const noun = minT <= 2 ? "rain/snow" : "rain";
                            const summary = maxP < 20 ? "Low " + noun + " chance through tomorrow"
                                          : maxP < 50 ? "Possible " + noun + " (up to " + Math.round(maxP) + "%) through tomorrow"
                                          : "High " + noun + " chance (" + Math.round(maxP) + "%) through tomorrow";

                            const data = {
                                city: place.name,
                                country: place.country || "",
                                temp: Math.round(c.temperature_2m),
                                desc: root.wxDescribe(c.weather_code)[1],
                                kind: root.wxKind(c.weather_code, c.is_day === 1),
                                high: Math.round(dl.temperature_2m_max[0]),
                                low: Math.round(dl.temperature_2m_min[0]),
                                feels: Math.round(c.apparent_temperature),
                                summary: summary,
                                hours: hours,
                                url: "https://www.google.com/search?q=" + encodeURIComponent("weather " + place.name)
                            };
                            root.cacheSet(cacheKey, data);
                            root._setWeather(data);
                        } catch (e) { root._setWeather("Couldn't get the weather"); }
                    });
            });
    }

    function checkWeather() {
        const s = root.query.trim().toLowerCase();
        if (s === "clima" || s === "weather" || s.startsWith("clima ") || s.startsWith("weather ")) {
            const typed = s.replace(/^(clima|weather)\s*/, "").replace(/^(em|in|de|para|no|na|do|da|for)\s+/, "").trim();
            if (/^(em|in|de|para|no|na|do|da|for)$/.test(typed)) return;
            const city = typed || root.weatherCity;
            const key = city + "|" + (typed ? "1" : "0");
            
            // Known major cities - prefer the famous one
            const majorCities = {
                "londres": { country: "GB", english: "London" }, "london": { country: "GB", english: "London" },
                "toquio": { country: "JP", english: "Tokyo" }, "tokyo": { country: "JP", english: "Tokyo" }, "tóquio": { country: "JP", english: "Tokyo" },
                "paris": { country: "FR", english: "Paris" },
                "nova york": { country: "US", english: "New York" }, "new york": { country: "US", english: "New York" },
                "roma": { country: "IT", english: "Rome" }, "rome": { country: "IT", english: "Rome" },
                "madrid": { country: "ES", english: "Madrid" },
                "berlim": { country: "DE", english: "Berlin" }, "berlin": { country: "DE", english: "Berlin" },
                "moscu": { country: "RU", english: "Moscow" }, "moscou": { country: "RU", english: "Moscow" }, "moscow": { country: "RU", english: "Moscow" },
                "pequim": { country: "CN", english: "Beijing" }, "beijing": { country: "CN", english: "Beijing" },
                "shangai": { country: "CN", english: "Shanghai" }, "shanghai": { country: "CN", english: "Shanghai" },
                "hong kong": { country: "HK", english: "Hong Kong" },
                "singapura": { country: "SG", english: "Singapore" }, "singapore": { country: "SG", english: "Singapore" },
                "dubai": { country: "AE", english: "Dubai" },
                "sydney": { country: "AU", english: "Sydney" },
                "toronto": { country: "CA", english: "Toronto" },
                "vancouver": { country: "CA", english: "Vancouver" },
                "montreal": { country: "CA", english: "Montreal" },
                "los angeles": { country: "US", english: "Los Angeles" },
                "chicago": { country: "US", english: "Chicago" },
                "buenos aires": { country: "AR", english: "Buenos Aires" },
                "cidade do mexico": { country: "MX", english: "Mexico City" }, "mexico city": { country: "MX", english: "Mexico City" },
                "bangkok": { country: "TH", english: "Bangkok" },
                "seul": { country: "KR", english: "Seoul" }, "seoul": { country: "KR", english: "Seoul" },
            };
            const cityLower = city.toLowerCase().trim();
            const majorCity = majorCities[cityLower];
            const preferredCountry = majorCity ? majorCity.country : null;
            
            // For major cities, always clear stale cache and weather data to force re-fetch
            if (preferredCountry) {
                const oldCacheKey = "wx3:" + cityLower + ":any";
                const oldCacheKeyBr = "wx3:" + cityLower + ":br";
                if (root._cache[oldCacheKey]) delete root._cache[oldCacheKey];
                if (root._cache[oldCacheKeyBr]) delete root._cache[oldCacheKeyBr];
                // Clear in-memory weather data to force fresh fetch
                root.weatherText = "";
                root.weatherData = null;
                root._wxLastCity = "";
            }
            
            if (key === root._wxLastCity && (root.weatherText || root.weatherData)) return;
            root._wxLastCity = key;
            root.fetchWeather(city, !typed);
        } else if (root.weatherText !== "" || root.weatherData) {
            root._wxReq++;
            root._wxLastCity = "";
            root.weatherText = "";
            root.weatherData = null;
        }
    }

    function checkDefine() {
        const s = root.query.trim().toLowerCase();
        const m = s.match(/^(define|significado|meaning)\s+(.+)$/);
        if (m && m[2]) {
            const pt = m[1] === "significado";
            const lang = pt ? "pt-BR" : "en";
            const word = m[2].trim().replace(pt ? /[^a-zà-ú-]/g : /[^a-z-]/g, "");
            if (!word) { if (root.dictText !== "") root.dictText = ""; return; }
            const cacheKey = "dict:" + lang + ":" + word;
            const cached = root.cacheGet(cacheKey, 24 * 60 * 60 * 1000);
            if (cached !== null) { root.dictText = cached; root.rebuildIfShown(); return; }
            _dict.exec(["bash", "-c", "curl -s --max-time 10 'https://api.dictionaryapi.dev/api/v2/entries/" + lang + "/" + root.urlq(word) + "' 2>/dev/null"]);
        } else if (root.dictText !== "") {
            root.dictText = "";
        }
    }

    function curCode(x) {
        const alias = { dolar: "usd", "d\u00f3lar": "usd", dolares: "usd", "d\u00f3lares": "usd", real: "brl", reais: "brl",
                        euro: "eur", euros: "eur", iene: "jpy", ienes: "jpy" };
        const known = "usd brl eur gbp jpy btc cad aud chf cny inr mxn ars clp cop pen uyu krw rub try zar sek nok dkk pln czk huf ils aed sar sgd hkd nzd thb idr php vnd egp ngn".split(" ");
        if (root.hasOwn(alias, x)) return alias[x];
        return known.indexOf(x) >= 0 ? x : "";
    }

    function checkCurrency() {
        const s = root.query.trim().toLowerCase().replace(",", ".");
        const m = s.match(/^([\d.]+)\s*([a-z\u00e9\u00f3]{3,8})\s+(?:in|to|em|para)\s+([a-z\u00e9\u00f3]{3,8})$/);
        const from = m ? root.curCode(m[2]) : "";
        const to = m ? root.curCode(m[3]) : "";
        if (!m || !from || !to) { if (root.currencyText) root.currencyText = ""; return; }
        const cacheKey = "cur:" + from + ":" + to + ":" + m[1];
        const cached = root.cacheGet(cacheKey, 10 * 60 * 1000);
        if (cached !== null) { root.currencyText = cached; root.rebuildIfShown(); return; }
        root._pendingCurrency = { val: parseFloat(m[1]), from: from.toUpperCase(), to: to.toUpperCase() };
        _currency.exec(["bash", "-c", "curl -s --max-time 10 'https://api.exchangerate-api.com/v4/latest/" + from.toUpperCase() + "' 2>/dev/null"]);
    }

    // ---- "dolar hoje", "euro hoje", "bitcoin hoje"... -> quote in BRL (AwesomeAPI)
    function quoteTarget(name) {
        const T = (pair, label) => ({ pair: pair, label: label });
        const map = {
            "dolar": T("USD-BRL", "D\u00f3lar"), "d\u00f3lar": T("USD-BRL", "D\u00f3lar"), "dolares": T("USD-BRL", "D\u00f3lar"),
            "d\u00f3lares": T("USD-BRL", "D\u00f3lar"), "usd": T("USD-BRL", "D\u00f3lar"),
            "dolar turismo": T("USD-BRLT", "D\u00f3lar Turismo"), "d\u00f3lar turismo": T("USD-BRLT", "D\u00f3lar Turismo"),
            "dolar canadense": T("CAD-BRL", "D\u00f3lar Canadense"), "d\u00f3lar canadense": T("CAD-BRL", "D\u00f3lar Canadense"),
            "dolar australiano": T("AUD-BRL", "D\u00f3lar Australiano"), "d\u00f3lar australiano": T("AUD-BRL", "D\u00f3lar Australiano"),
            "euro": T("EUR-BRL", "Euro"), "euros": T("EUR-BRL", "Euro"), "eur": T("EUR-BRL", "Euro"),
            "libra": T("GBP-BRL", "Libra"), "libras": T("GBP-BRL", "Libra"), "gbp": T("GBP-BRL", "Libra"),
            "iene": T("JPY-BRL", "Iene"), "ienes": T("JPY-BRL", "Iene"), "jpy": T("JPY-BRL", "Iene"),
            "yuan": T("CNY-BRL", "Yuan"), "cny": T("CNY-BRL", "Yuan"),
            "franco": T("CHF-BRL", "Franco Su\u00ed\u00e7o"), "franco suico": T("CHF-BRL", "Franco Su\u00ed\u00e7o"),
            "franco su\u00ed\u00e7o": T("CHF-BRL", "Franco Su\u00ed\u00e7o"), "chf": T("CHF-BRL", "Franco Su\u00ed\u00e7o"),
            "peso argentino": T("ARS-BRL", "Peso Argentino"), "ars": T("ARS-BRL", "Peso Argentino"),
            "peso chileno": T("CLP-BRL", "Peso Chileno"), "clp": T("CLP-BRL", "Peso Chileno"),
            "peso mexicano": T("MXN-BRL", "Peso Mexicano"), "mxn": T("MXN-BRL", "Peso Mexicano"),
            "peso uruguaio": T("UYU-BRL", "Peso Uruguaio"), "uyu": T("UYU-BRL", "Peso Uruguaio"),
            "bitcoin": T("BTC-BRL", "Bitcoin"), "btc": T("BTC-BRL", "Bitcoin"),
            "ethereum": T("ETH-BRL", "Ethereum"), "eth": T("ETH-BRL", "Ethereum"), "ether": T("ETH-BRL", "Ethereum"),
            "litecoin": T("LTC-BRL", "Litecoin"), "ltc": T("LTC-BRL", "Litecoin"),
            "dogecoin": T("DOGE-BRL", "Dogecoin"), "doge": T("DOGE-BRL", "Dogecoin"),
            "xrp": T("XRP-BRL", "XRP"), "ripple": T("XRP-BRL", "XRP"),
            "usdt": T("USDT-BRL", "Tether (USDT)"), "tether": T("USDT-BRL", "Tether (USDT)")
        };
        if (root.hasOwn(map, name)) return map[name];
        const c = root.curCode(name);          // any other known 3-letter code -> CODE-BRL
        if (c && c !== "brl") return T(c.toUpperCase() + "-BRL", c.toUpperCase());
        return null;
    }

    function fmtBR(v, dec) {
        const neg = v < 0;
        const parts = Math.abs(v).toFixed(dec).split(".");
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ".");
        return (neg ? "-" : "") + parts.join(",");
    }

    function checkQuote() {
        const s = root.query.trim().toLowerCase().replace(/\s+/g, " ");
        const m = s.match(/^(.+?) (?:hoje|agora|today|now)$/)
               || s.match(/^(?:cota[c\u00e7][a\u00e3]o|pre[c\u00e7]o|valor) (?:d[oae]s? )?(.+)$/);
        const t = m ? root.quoteTarget(m[1].trim()) : null;
        if (!t) {
            if (root.quoteResult.q) root.quoteResult = { q: "", loading: false, text: "", sub: "", raw: "" };
            root._quoteQ = "";
            return;
        }
        if (root._quoteQ === s) return;
        root._quoteQ = s;
        const cached = root.cacheGet("quote:" + t.pair, 60 * 1000);
        if (cached) {
            root.quoteResult = { q: s, loading: false, text: cached.text, sub: cached.sub, raw: cached.raw };
            root.rebuildIfShown();
            return;
        }
        root.quoteResult = { q: s, loading: true, text: "Buscando cota\u00e7\u00e3o: " + t.label + "\u2026", sub: "", raw: "" };
        root._pendingQuote = { q: s, pair: t.pair, label: t.label };
        // Optional API key (no cache, real-time): ~/.config/spotlight/awesomeapi.key
        _quote.exec(["bash", "-c", "k=$(cat ~/.config/spotlight/awesomeapi.key 2>/dev/null); "
            + "curl -s --max-time 10 ${k:+-H \"x-api-key: $k\"} 'https://economia.awesomeapi.com.br/json/last/" + t.pair + "' 2>/dev/null"]);
    }

    function checkBattery() {
        const s = root.query.trim().toLowerCase();
        if (s === "bateria" || s === "battery") _battery.running = true;
        else if (root.batteryText) root.batteryText = "";
    }

    function checkMyIp() {
        const s = root.query.trim().toLowerCase();
        if (s === "meu ip" || s === "my ip") _ipInfo.running = true;
        else if (root.ipText) root.ipText = "";
    }

    function checkPassword() {
        const s = root.query.trim().toLowerCase();
        const m = s.match(/^(senha|password)\s*(\d+)?$/);
        if (!m) { if (root.passText) root.passText = ""; root._passKey = ""; return; }
        if (root._passKey === s) return;
        root._passKey = s;
        const len = Math.max(4, Math.min(64, parseInt(m[2] || "16")));
        root._passWanted = len;
        _pass.exec(["bash", "-c", "LC_ALL=C tr -dc 'A-Za-z0-9!@#$%&*' </dev/urandom | head -c " + len]);
    }

    // -- Time in another city
    function fetchTime(city) {
        const cacheKey = "time:" + city.toLowerCase();
        const cached = root.cacheGet(cacheKey, 30 * 1000);
        if (cached) { root.timeText = cached; root.rebuildIfShown(); return; }

        // Show immediate loading feedback
        root.timeText = "🔍 Searching for " + city + "...";
        root.rebuildIfShown();

        // Translate common Portuguese city names to English for the API
        const cityMap = {
            "londres": "London",
            "toquio": "Tokyo",
            "tokyo": "Tokyo",
            "nova york": "New York",
            "new york": "New York",
            "sao paulo": "Sao Paulo",
            "são paulo": "Sao Paulo",
            "rio de janeiro": "Rio de Janeiro",
            "paris": "Paris",
            "berlim": "Berlin",
            "madrid": "Madrid",
            "roma": "Rome",
            "pequim": "Beijing",
            "beijing": "Beijing",
            "moscu": "Moscow",
            "moscou": "Moscow",
            "dubai": "Dubai",
            "singapura": "Singapore",
            "sydney": "Sydney",
            "los angeles": "Los Angeles",
            "chicago": "Chicago",
            "toronto": "Toronto",
            "vancouver": "Vancouver",
            "montreal": "Montreal",
            "buenos aires": "Buenos Aires",
            "cidade do mexico": "Mexico City",
            "mexico city": "Mexico City",
            "bangkok": "Bangkok",
            "seul": "Seoul",
            "seoul": "Seoul",
            "hong kong": "Hong Kong",
            "shangai": "Shanghai",
            "shanghai": "Shanghai",
        };
        const apiCity = cityMap[city.toLowerCase()] || city;

        const req = ++root._timeReq;
        root.abortXhr(root._timeXhr);
        const fail = (msg) => { root.timeText = msg; root.rebuildIfShown(); };

        // Use English for geocoding (works better for international cities)
        root._timeXhr = root.httpJson(
            "https://geocoding-api.open-meteo.com/v1/search?count=3&language=en&name=" + encodeURIComponent(apiCity),
            10000,
            function (geo) {
                if (req !== root._timeReq) return;
                const place = (geo && geo.results && geo.results[0]) || null;
                if (!place) { fail("City not found: " + city); return; }

                root._timeXhr = root.httpJson(
                    "https://api.open-meteo.com/v1/forecast?latitude=" + place.latitude + "&longitude=" + place.longitude + "&current=temperature_2m&timezone=auto",
                    10000,
                    function (data) {
                        if (req !== root._timeReq) return;
                        const tzName = (data && data.timezone) || "";
                        if (!data || typeof data.utc_offset_seconds !== "number") {
                            root.fetchTimezoneFallback(city, place, req, cacheKey);
                            return;
                        }
                        root.renderTime(place, tzName, data.utc_offset_seconds, cacheKey);
                    });
            });
    }

    function fetchTimezoneFallback(city, place, req, cacheKey) {
        const gmtOffset = Math.round(-place.longitude / 15);
        const gmtSign = gmtOffset >= 0 ? "+" : "-";
        root._timeXhr = root.httpJson(
            "https://worldtimeapi.org/api/timezone/Etc/GMT" + gmtSign + Math.abs(gmtOffset),
            10000,
            function (data) {
                if (req !== root._timeReq) return;
                try {
                    if (!data || !data.utc_offset) throw new Error("no utc_offset");
                    const sign = data.utc_offset[0] === "-" ? -1 : 1;
                    const [hh, mm] = data.utc_offset.slice(1).split(":").map(Number);
                    root.renderTime(place, data.timezone || "", sign * (hh * 3600 + mm * 60), cacheKey);
                } catch (e) {
                    root.timeText = "Could not get time for " + city;
                    root.rebuildIfShown();
                }
            });
    }

    function renderTime(place, tzName, utcOffsetSeconds, cacheKey) {
        const now = new Date();
        const localOffsetSec = -now.getTimezoneOffset() * 60;
        const there = new Date(now.getTime() + utcOffsetSeconds * 1000);
        const wd = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][there.getUTCDay()];
        const timeStr = root.pad2(there.getUTCHours()) + ":" + root.pad2(there.getUTCMinutes());
        const dateStr = wd + " " + root.pad2(there.getUTCDate()) + "/" + root.pad2(there.getUTCMonth() + 1);
        const diffH = (utcOffsetSeconds - localOffsetSec) / 3600;
        const diffStr = diffH === 0 ? "same time zone as you"
                      : (diffH > 0 ? "+" : "") + (Number.isInteger(diffH) ? diffH : diffH.toFixed(1)) + "h from you";
        const where = place.name + (place.admin1 ? ", " + place.admin1 : "") + (place.country ? ", " + place.country : "");
        const tzSuffix = tzName ? " (" + tzName + ")" : "";
        const txt = where + ": " + timeStr + " \u00b7 " + dateStr + " \u00b7 " + diffStr + tzSuffix;
        root.timeText = txt;
        if (cacheKey) root.cacheSet(cacheKey, txt);
        root.rebuildIfShown();
    }

    function checkTime() {
        const s = root.query.trim().toLowerCase();
        const m = s.match(/^(?:que\s+)?(?:hora|horas|time)\s+(?:em|in|de|no|na|do|da|for)\s+(.+)$/);
        if (!m) {
            // Only clear if the query no longer looks like a time query at all
            if (root.timeText && !/(?:que\s+)?(?:hora|horas|time)\s+(?:em|in|de|no|na|do|da|for)\s/.test(s)) {
                root._timeReq++;
                root._timeKey = "";
                root.timeText = "";
            }
            return;
        }
        const city = m[1].trim();
        if (!city || (root._timeKey === city && root.timeText)) return;
        root._timeKey = city;
        root.fetchTime(city);
    }

    // -- Processes (kill)
    function checkKill() {
        const m = root.query.trim().match(/^(?:kill|matar|encerrar|pkill)\s+(\S.*)$/i);
        if (!m) {
            if (root.procItems.length) root.procItems = [];
            root._procKey = "";
            return;
        }
        const name = m[1].trim();
        if (root._procKey === name) return;
        root._procKey = name;
        const id = ++root._psReq;
        _ps.exec(["bash", "-c", "echo " + id + "; ps -u \"$USER\" -o pid=,rss=,comm= --sort=-rss | grep -i -F -- " + root.shellQuote(name) + " | head -12"]);
    }

    // -- Dev tools (uuid, base64, hashes)
    function checkDev() {
        const q = root.query.trim();
        let kind = "", arg = "", m;
        if (q.toLowerCase() === "uuid") kind = "uuid";
        else if ((m = q.match(/^(?:base64d|b64d|debase64)\s+(.+)$/i))) { kind = "b64d"; arg = m[1]; }
        else if ((m = q.match(/^(?:base64|b64)\s+(.+)$/i))) { kind = "b64e"; arg = m[1]; }
        else if ((m = q.match(/^(sha256|sha1|sha512|md5|hash)\s+(.+)$/i))) {
            kind = m[1].toLowerCase() === "hash" ? "sha256" : m[1].toLowerCase();
            arg = m[2];
        }
        if (!kind) {
            if (root.devResult.q) root.devResult = { q: "", text: "", label: "" };
            root._devQ = "";
            return;
        }
        if (root._devQ === q && root.devResult.q === q) return;
        let cmd = "", label = "";
        if (kind === "uuid") { cmd = "cat /proc/sys/kernel/random/uuid"; label = "UUID v4"; }
        else if (kind === "b64e") { cmd = "printf '%s' " + root.shellQuote(arg) + " | base64 -w0"; label = "Base64"; }
        else if (kind === "b64d") { cmd = "printf '%s' " + root.shellQuote(arg) + " | base64 -d 2>/dev/null"; label = "Base64 decoded"; }
        else { cmd = "printf '%s' " + root.shellQuote(arg) + " | " + kind + "sum | cut -d' ' -f1"; label = kind.toUpperCase(); }
        root._devQ = q;
        root._devLabel = label;
        const id = ++root._devReq;
        _dev.exec(["bash", "-c", "echo " + id + "; " + cmd]);
    }

    function checkContentSearch() {
        const m = root.query.trim().match(/^\/buscar\s+(.+)$/i);
        if (m && m[1].trim()) {
            const term = m[1].trim();
            if (term !== root._lastContentQuery) {
                root._lastContentQuery = term;
                root.runContentSearch(term);
            }
        } else {
            root._lastContentQuery = "";
        }
    }

    function runSideEffects() {
        root.checkWeather();
        root.checkDefine();
        root.checkCurrency();
        root.checkQuote();
        root.checkBattery();
        root.checkMyIp();
        root.checkPassword();
        root.checkAI();
        root.checkContentSearch();
        root.checkTime();
        root.checkKill();
        root.checkDev();
    }

    // =====================================================================
    //  FILE SEARCH
    // =====================================================================
    function parseFdLines(lines) {
        const out = [];
        const seen = {};
        for (const line of lines) {
            if (!line) continue;
            const tab = line.indexOf("\t");
            const isDirectory = tab >= 0 && line.slice(0, tab) === "d";
            let p = tab >= 0 ? line.slice(tab + 1) : line;
            p = p.replace(/\/+$/, "");
            if (!p || seen[p]) continue;
            seen[p] = true;
            const sp = root.splitPath(p);
            out.push({ name: sp.name, path: p, dir: sp.dir, isDirectory: isDirectory });
        }
        return out;
    }

    function runFd() {
        if (root.slashMode || root.mode === "menu" || root.query.trim().length < 2 || root.aiPromptFor(root.query.trim()) !== "") {
            root.fileItems = [];
            root.scheduleRebuild();
            return;
        }
        const q = root.query.trim();
        const id = ++root._fdReq;
        _fd.exec(["bash", "-c",
            "echo " + id + "; " +
            "Q=" + root.shellQuote(q.toLowerCase()) + "; " +
            "fd -i -F -d 5 -- \"$Q\" ~ 2>/dev/null | head -80 | while IFS= read -r p; do " +
            "  if [ -d \"$p\" ]; then printf 'd\\t%s\\n' \"$p\"; else printf 'f\\t%s\\n' \"$p\"; fi; " +
            "done; " +
            "fd -i -F -t d -d 4 -- \"$Q\" ~ 2>/dev/null | head -5 | while IFS= read -r d; do " +
            "  fd . \"$d\" -d 1 2>/dev/null | head -40 | while IFS= read -r p; do " +
            "    if [ -d \"$p\" ]; then printf 'd\\t%s\\n' \"$p\"; else printf 'f\\t%s\\n' \"$p\"; fi; " +
            "  done; " +
            "done"
        ]);
    }

    function runContentSearch(term) {
        if (!term) return;
        const id = ++root._rgReq;
        _rg.exec(["bash", "-c", "echo " + id + "; timeout 2 rg -l -i -F --max-count 1 --max-filesize 1M -g '!node_modules' -g '!.git' -e " + root.shellQuote(term) + " ~ 2>/dev/null | head -12"]);
    }

    function runRecents() {
        _recents.exec(["bash", "-c",
            "cd " + (root.browseDir !== "" ? root.shellQuote(root.browseDir) : "~") + " 2>/dev/null || exit 0; " +
            "pwd; " +
            "{ ls -1 --group-directories-first 2>/dev/null; " +
            "  ls -1A --group-directories-first 2>/dev/null | grep '^\\.'; " +
            "} | head -300 | while IFS= read -r n; do " +
            "  p=\"$PWD/$n\"; " +
            "  if [ -d \"$p\" ]; then printf 'd\\t%s\\n' \"$p\"; else printf 'f\\t%s\\n' \"$p\"; fi; " +
            "done"
        ]);
    }

    function runClip() {
        _clip.command = ["python3", "-c", root._clipPy, "hist"];
        _clip.running = true;
    }

    // Pin / unpin run one at a time through a small queue
    function clipOp(op, arg) { root._clipQueue.push([op, String(arg || "")]); root._clipNext(); }
    function _clipNext() {
        if (_clipPinProc.running || root._clipQueue.length === 0) return;
        const job = root._clipQueue.shift();
        _clipPinProc.command = ["python3", "-c", root._clipPy, job[0], job[1]];
        _clipPinProc.running = true;
    }
    function toggleClipPin(it) {
        if (!it || it.kind !== "clip") return;
        if (it.pinned) root.clipOp("unpin", it.h || "");
        else if (/^\d+$/.test(it.id || "")) root.clipOp("pin", it.id);
    }
    function clearClipboard() { _clipClear.running = true; }

    function runInTerminal(command) {
        terminalProcess.commandText = command;
        terminalProcess.running = true;
    }

    function browseUp() {
        const i = root.browseDir.lastIndexOf("/");
        root.browseDir = i > 0 ? root.browseDir.slice(0, i) : "/";
        root.selectedIndex = 0;
        root.runRecents();
    }

    function naturalCompare(a, b) {
        const re = /(\d+)|(\D+)/g;
        const pa = String(a).match(re) || [];
        const pb = String(b).match(re) || [];
        const len = Math.max(pa.length, pb.length);
        for (let i = 0; i < len; i++) {
            const xa = pa[i], xb = pb[i];
            if (xa === undefined) return -1;
            if (xb === undefined) return 1;
            if (xa !== xb) {
                const na = /^\d/.test(xa), nb = /^\d/.test(xb);
                if (na && nb) {
                    const ia = parseInt(xa, 10), ib = parseInt(xb, 10);
                    if (ia !== ib) return ia - ib;
                    if (xa.length !== xb.length) return xa.length - xb.length;
                } else {
                    const c = xa.toLowerCase().localeCompare(xb.toLowerCase());
                    if (c !== 0) return c;
                }
            }
        }
        return 0;
    }

    function sortFileResults(arr, q) {
        const ql = q.trim().toLowerCase();
        let targetDir = null;
        for (const f of arr) {
            if (!f.isDirectory) continue;
            const n = f.name.toLowerCase();
            if (n === ql) { targetDir = f; break; }
            if (!targetDir && n.startsWith(ql)) targetDir = f;
        }
        if (!targetDir) {
            return arr.slice().sort((a, b) => {
                const da = a.isDirectory ? 1 : 0;
                const db = b.isDirectory ? 1 : 0;
                if (da !== db) return db - da;
                const ua = root.usageOf("file:" + a.path), ub = root.usageOf("file:" + b.path);
                if (ua !== ub) return ub - ua;
                return root.naturalCompare(a.name, b.name);
            });
        }
        const prefix = targetDir.path + "/";
        const groupOf = (f) => f === targetDir ? 0 : (f.path.startsWith(prefix) ? 1 : 2);
        return arr.slice().sort((a, b) => {
            const ga = groupOf(a), gb = groupOf(b);
            if (ga !== gb) return ga - gb;
            if (ga === 2) {
                const da = a.isDirectory ? 1 : 0;
                const db = b.isDirectory ? 1 : 0;
                if (da !== db) return db - da;
            }
            return root.naturalCompare(a.name, b.name);
        });
    }

    // =====================================================================
    //  AI (HERMES AGENT)
    // =====================================================================
    function structuredIntent(p) {
        const s = String(p).toLowerCase();
        for (const r of root._intentRules) if (r[1](s)) return r[0];
        return "";
    }

    function buildSystemPrompt(intent, nowStr) {
        const base = "Reply in English, briefly and directly, unless the user writes in or asks for another language.";
        const extra = {
            lembrar: `\nThe user wants to create a reminder with alarm. Current date/time: ${nowStr}. REPLY ONLY with JSON:\n{"action":"add_reminder","text":"...","due":"YYYY-MM-DD HH:MM"}`,
            todo: `\nThe user wants to create a task. Current date: ${nowStr}. REPLY ONLY with JSON:\n{"action":"add_todo","text":"...","due":"YYYY-MM-DD HH:MM"}`,
            timer: `\nThe user wants a timer. REPLY ONLY with JSON:\n{"action":"start_timer","seconds":N,"label":"..."}`,
            alias: `\nThe user wants to create a shortcut. REPLY ONLY with JSON:\n{"action":"create_alias","name":"...","actions":["..."]}`,
            block: `\nThe user wants to block sites. REPLY ONLY with JSON:\n{"action":"block_sites","sites":["..."],"minutes":N}`,
            focus: `\nThe user wants focus mode. REPLY ONLY with JSON:\n{"action":"focus_mode","minutes":N}`,
            web: `\nThe user wants to summarize a link. REPLY ONLY with JSON:\n{"action":"web_summary","url":"<url>"}`,
            pdf: `\nThe user wants to summarize a PDF. REPLY ONLY with JSON:\n{"action":"pdf_summary","path":"<path>"}`
        };
        return base + (extra[intent] ? extra[intent] : "");
    }

    function pushHistory(role, content, label) {
        const h = root.aiHistory.slice();
        h.push(root._msg(role, content, label));
        while (h.length > 20) h.shift();
        root.aiHistory = h;
        if (role === "assistant" && root.aiPersistentHistory) spotlightActions.saveHistory(JSON.stringify(root.aiHistory));
    }

    function aiFail(msg) {
        root.aiText = msg;
        root.aiLoading = false;
        root.rebuildIfShown();
    }

    // Resets the "same question" cache and sends an internal prompt.
    function runInternalAi(prompt, label) {
        root._lastAiQuery = "";
        root._internalNext = true;
        root.runHermes(prompt, false, label);
    }

    function runHermes(prompt, isRetry, label) {
        isRetry = !!isRetry;
        if (!isRetry) root._lastInternal = root._internalNext;
        root._internalNext = false;
        if (!prompt) return;
        if (!root.hermesKey) {
            root.aiFail("Hermes Agent: set HERMES_API_KEY in the environment");
            return;
        }
        if (!isRetry && prompt === root._lastAiQuery && root.aiText && !root.aiLoading) return;

        if (!isRetry) root._aiRetries = 0;
        root._lastAiQuery = prompt;
        root.aiLoading = true;
        root.aiText = "Thinking…";

        if (!isRetry) {
            const h = root.aiHistory.slice();
            h.push(root._msg("user", prompt, label));
            while (h.length > 20) h.shift();
            root.aiHistory = h;
        }
        const history = root.aiHistory.slice();

        const now = new Date();
        const nowStr = now.getFullYear() + "-" + root.pad2(now.getMonth() + 1) + "-" + root.pad2(now.getDate())
                     + " " + root.pad2(now.getHours()) + ":" + root.pad2(now.getMinutes());
        const internal = root._lastInternal || /^Translate the following text/.test(prompt);
        const intent = internal ? "" : root.structuredIntent(prompt);
        root._aiIntent = intent;
        const sysContent = root.buildSystemPrompt(intent, nowStr);

        const req = ++root._aiReq;
        root.abortXhr(root._aiXhr);
        const xhr = new XMLHttpRequest();
        root._aiXhr = xhr;

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (req !== root._aiReq) return;
            let answer = "";
            try {
                const data = JSON.parse(xhr.responseText);
                const msg = data.choices && data.choices[0] && data.choices[0].message;
                if (msg && msg.content) {
                    answer = String(msg.content)
                        .replace(/<think>[\s\S]*?<\/think>/g, "")
                        .replace(/^[\s\S]*<\/think>/, "")
                        .trim();
                }
                if (!answer) {
                    if (data.error) answer = "Hermes Agent error: " + (data.error.message || data.error);
                    else answer = "No AI response";
                }
            } catch (e) {
                if (xhr.status === 0) {
                    if (!isRetry && root._aiRetries < 1) {
                        root._aiRetries++;
                        root.aiLoading = false;
                        _aiRetryTimer.prompt = prompt;
                        _aiRetryTimer.restart();
                        return;
                    }
                    answer = "No response from Hermes Agent (gateway stopped or timeout)";
                }
                else if (xhr.status === 401) answer = "Hermes Agent: invalid key (API_SERVER_KEY)";
                else answer = "Error querying the AI (HTTP " + xhr.status + ")";
            }
            root.finishAi(answer, prompt, req);
        };

        xhr.open("POST", root.hermesUrl + "/v1/chat/completions");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.hermesKey);
        xhr.timeout = 60000;
        xhr.send(JSON.stringify({
            model: root.hermesModel,
            stream: false,
            messages: [
                { role: "system", content: sysContent },
                ...history.map(m => ({ role: m.role, content: m.content }))
            ]
        }));
        root.scheduleRebuild();
    }

    // Handles the final answer: structured action JSON or plain text.
    function finishAi(answer, prompt, req) {
        if (req !== root._aiReq) return;
        if (answer.length > 4000) answer = answer.slice(0, 4000) + "…";

        const cleaned = String(answer).trim()
            .replace(/^```json\s*/i, "")
            .replace(/^```\s*/i, "")
            .replace(/```\s*$/i, "")
            .trim();

        // Actions run only when the request had a matching intent, so untrusted text
        // (web pages, PDFs, OCR, diffs) cannot make the model trigger actions on its own.
        const allowedAction = ({
            lembrar: "add_reminder",
            todo: "add_todo", timer: "start_timer",
            alias: "create_alias", block: "block_sites", focus: "focus_mode",
            web: "web_summary", pdf: "pdf_summary"
        })[root._aiIntent];
        if (allowedAction && cleaned.startsWith("{") && cleaned.endsWith("}")) {
            try {
                const obj = JSON.parse(cleaned);
                if (obj.action !== allowedAction) throw new Error("action not requested");
                if (obj.action === "web_summary" && obj.url) {
                    root.aiText = "🌐 Downloading " + obj.url + "…";
                    spotlightActions.fetchPage(obj.url);
                    return;
                }
                if (obj.action === "pdf_summary" && obj.path) {
                    root.aiText = "📄 Reading " + obj.path + "…";
                    spotlightActions.summarizePdf(obj.path);
                    return;
                }
                const handled = root.handleStructuredAction(obj, prompt);
                if (handled) {
                    root.aiText = handled;
                    root.aiLoading = false;
                    root._aiXhr = null;
                    root.pushHistory("assistant", handled);
                    root.notify(handled);
                    root.rebuildIfShown();
                    return;
                }
            } catch (e) { }
        }

        root.aiText = answer;
        root.aiLoading = false;
        root._aiXhr = null;
        if (!root.aiErrored) root.pushHistory("assistant", answer);
        root.rebuildIfShown();
    }

    function handleStructuredAction(obj, prompt) {
        if (!obj || !obj.action) return "";
        switch (obj.action) {
            case "add_reminder": {
                if (!obj.text) return "";
                let due = undefined;
                let dueLabel = "";
                if (obj.due) {
                    const parts = String(obj.due).trim().split(/\s+/);
                    const timePart = parts[1] || "09:00";
                    const [y, m, d] = parts[0].split("-").map(Number);
                    const [hh, mm] = timePart.split(":").map(Number);
                    if ([y, m, d, hh, mm].every(n => !isNaN(n))) {
                        due = new Date(Date.UTC(y, m - 1, d, hh, mm));
                        dueLabel = root.pad2(d) + "/" + root.pad2(m) + " at " + root.pad2(hh) + ":" + root.pad2(mm);
                    }
                }
                Todo.addTask(obj.text, due);
                if (due && due.getTime() > Date.now()) {
                    const whenStr = due.getFullYear() + "-" + root.pad2(due.getMonth() + 1) + "-" + root.pad2(due.getDate())
                        + " " + root.pad2(due.getHours()) + ":" + root.pad2(due.getMinutes()) + ":00";
                    root.scheduleReminder(whenStr, obj.text);
                }
                return "⏰ Reminder created: \"" + obj.text + "\"" + (dueLabel ? " · " + dueLabel : "");
            }
            case "add_todo": {
                if (!obj.text) return "";
                let due = undefined;
                let dueLabel = "";
                if (obj.due) {
                    const parts = String(obj.due).trim().split(/\s+/);
                    const timePart = parts[1] || "09:00";
                    const [y, m, d] = parts[0].split("-").map(Number);
                    const [hh, mm] = timePart.split(":").map(Number);
                    if ([y, m, d, hh, mm].every(n => !isNaN(n))) {
                        due = new Date(Date.UTC(y, m - 1, d, hh, mm));
                        dueLabel = root.pad2(d) + "/" + root.pad2(m) + " at " + root.pad2(hh) + ":" + root.pad2(mm);
                    }
                }
                Todo.addTask(obj.text, due);
                if (due && due.getTime() > Date.now()) {
                    const whenStr = due.getFullYear() + "-" + root.pad2(due.getMonth() + 1) + "-" + root.pad2(due.getDate())
                        + " " + root.pad2(due.getHours()) + ":" + root.pad2(due.getMinutes()) + ":00";
                    root.scheduleReminder(whenStr, obj.text);
                }
                return "✅ Task created: \"" + obj.text + "\"" + (dueLabel ? " · " + dueLabel : "");
            }
            case "start_timer": {
                const s = parseInt(obj.seconds) || 0;
                if (s <= 0) return "";
                root.startTimer(s, obj.label || (s + "s"));
                return "⏱ Timer started: " + (obj.label || (s + "s"));
            }
            case "create_alias": return spotlightActions.createAlias(obj.name, obj.actions || []);
            case "block_sites": return spotlightActions.blockSites(obj.sites || [], obj.minutes || 60);
            case "focus_mode": return spotlightActions.enterFocusMode(obj.minutes || 120);
            default: return "";
        }
    }

    function buildResumePrompt(page, focus) {
        return "Summarize this web page content concisely"
            + (focus ? ", focusing on: " + focus : "") + ":\n\n"
            + "TITLE: " + (page.title || "") + "\n"
            + "LINK: " + page.url + "\n\n"
            + (page.text || "").slice(0, 5000);
    }

    function aiIsAuto(s) {
        return root.aiAutoQuestion && !s.startsWith("/") && s.endsWith("?") && s.length > 3
            && !/^\/?(ai|gpt|ia)\s/i.test(s)
            && !/^(?:tr|traduzir|translate)\s+/i.test(s);
    }

    function aiPromptFor(s) {
        const tm = s.match(/^(?:tr|traduzir|translate)\s+([a-z]{2}(?:-[a-z]{2})?)\s+(.+)$/i);
        const m = s.match(/^\/?(ai|gpt|ia)\s+(.+)$/i);
        if (tm) return "Translate the following text to " + root.langName(tm[1])
                       + ". Reply with ONLY the translation, without quotes or explanations.\n\n" + tm[2];
        if (m && m[2] && (!s.startsWith("/") || m[1].toLowerCase() === "ai")) return m[2].trim();
        // Natural language reminder detection (no ? required)
        const reminderMatch = s.match(/^(?:por favor\s+)?(?:lembre|lembre-se|me lembre|defina|agende)\s+(?:me\s+)?(?:de\s+)?(.+)$/i);
        if (reminderMatch) {
            return "Create a reminder with alarm. Current date/time: " + (() => { const n = new Date(); return n.getFullYear() + "-" + root.pad2(n.getMonth()+1) + "-" + root.pad2(n.getDate()) + " " + root.pad2(n.getHours()) + ":" + root.pad2(n.getMinutes()); })() + ". REPLY ONLY with JSON:\n{\"action\":\"add_reminder\",\"text\":\"...\",\"due\":\"YYYY-MM-DD HH:MM\"}\n\nUser request: " + reminderMatch[1].trim();
        }
        if (root.aiIsAuto(s)) return s;
        return "";
    }

    function clearAi() {
        root._aiReq++;
        root.abortXhr(root._aiXhr);
        root._aiXhr = null;
        root.aiText = "";
        root.aiLoading = false;
        root._lastAiQuery = "";
        root._aiRetries = 0;
    }

    function newAiConversation() {
        root.aiHistory = [];
        root.clearAi();
        root.scheduleRebuild();
    }

    function sendChat(text) {
        const t = text.trim();
        if (t.length === 0 || root.aiLoading) return false;
        root.runHermes(t);
        return true;
    }

    function _aiResultItems() {
        if (root.aiText) {
            return [{
                kind: "info", isAi: true,
                name: root.aiLoading ? "Thinking…" : "See the answer in the popup beside",
                category: root.aiLoading ? "Hermes Agent · thinking…" : "Hermes Agent — Enter to copy"
            }];
        }
        if (root.aiPromptFor(root.query.trim()) !== "") {
            return [{ kind: "info", isAi: true, name: "Ask Hermes Agent", category: "Press Enter to send" }];
        }
        return [];
    }

    function checkAI() {
        const s = root.query.trim();
        const isSlashOther = s.startsWith("/") && !/^\/ai\s/i.test(s);
        const prompt = isSlashOther ? "" : root.aiPromptFor(s);
        if (!prompt) {
            _aiDeb.stop();
            if (root.aiText !== "") {
                root.clearAi();
                root.rebuildIfShown();
            }
            return;
        }
        root._pendingAiPrompt = prompt;
        if (root.aiIsAuto(s)) _aiDeb.restart();
        else {
            _aiDeb.stop();
            if (prompt !== root._lastAiQuery && root.aiText !== "") {
                root.clearAi();
                root.rebuildIfShown();
            }
        }
    }

    // =====================================================================
    //  PREVIEW
    // =====================================================================
    function _fitPreview(maxW, maxH, minW, minH, fbW, fbH) {
        const w = root.previewNatW, h = root.previewNatH;
        if (!w || !h) return { w: fbW, h: fbH };
        const fit = Math.min(maxW / w, maxH / h);
        let outW = w * fit, outH = h * fit;
        if (outW < minW) { const s = minW / outW; outW = minW; outH *= s; }
        if (outH < minH) { const s = minH / outH; outH = minH; outW *= s; }
        return { w: Math.min(outW, maxW), h: Math.min(outH, maxH) };
    }
    function previewSize()      { return root._fitPreview(480, 480, 220, 160, 300, 260); }
    function previewSizeLarge() { return root._fitPreview(580, 700, 300, 400, 420, 560); }

    function previewKindFor(ext) {
        if (root._imgExts.indexOf(ext) !== -1) return "image";
        if (root._textExts.indexOf(ext) !== -1) return ext === "md" ? "markdown" : "text";
        if (root._videoExts.indexOf(ext) !== -1) return "video";
        if (root._audioExts.indexOf(ext) !== -1) return "audio";
        if (ext === "pdf") return "pdf";
        return "";
    }

    function resetPreview() {
        root.previewThumbPath = "";
        root.previewNatW = 0;
        root.previewNatH = 0;
        root.previewPath = "";
        root.previewKind = "";
        root.previewText = "";
    }

    function previewFile(p, isDirectory) {
        root.resetPreview();
        if (isDirectory) return;
        const kind = root.previewKindFor(p.split(".").pop().toLowerCase());
        if (!kind) return;
        root.previewKind = kind;
        root.previewPath = p;
        const q = root.shellQuote;
        const pend = (outPath) => { root._pendingPreview = { for: p, path: outPath, kind: kind }; };

        if (kind === "text" || kind === "markdown") {
            _preview.exec(["bash", "-c", "head -c 4000 " + q(p) + " 2>/dev/null | iconv -c -t UTF-8 2>/dev/null"]);
        } else if (kind === "video") {
            const out = root.tmpDir + "/thumb_" + Date.now() + ".jpg";
            pend(out);
            _videoThumb.exec(["bash", "-c", root.tmpPrep("thumb") + "ffmpegthumbnailer -i " + q(p) + " -o " + q(out) + " -s 400 2>/dev/null"]);
        } else if (kind === "audio") {
            const out = root.tmpDir + "/cover_" + Date.now() + ".jpg";
            pend(out);
            _audioCover.exec(["bash", "-c", root.tmpPrep("cover") + "ffmpeg -y -i " + q(p) + " -an -frames:v 1 " + q(out) + " 2>/dev/null"]);
        } else if (kind === "pdf") {
            const base = root.tmpDir + "/pdf_" + Date.now();
            pend(base + ".jpg");
            _pdfThumb.exec(["bash", "-c",
                root.tmpPrep("pdf") +
                "pdftoppm -jpeg -f 1 -l 1 -scale-to 1200 " + q(p) + " " + q(base) + " 2>/dev/null; " +
                "f=$(ls " + q(base) + "*.jpg 2>/dev/null | head -1); " +
                "[ -n \"$f\" ] && mv \"$f\" " + q(base + ".jpg")
            ]);
        }
    }

    function previewClipText(id) { root.previewClipSource("cliphist decode " + id + " 2>/dev/null"); }

    function previewClipSource(src) {
        root._clipPrevKey = root.selectedKey;
        const script = [
            "c=$(" + src + " | head -c 4000)",
            "n=$(printf '%s\\n' \"$c\" | wc -l)",
            "first=$(printf '%s\\n' \"$c\" | tr -d '\\r' | grep -m1 -E '^(file://|/)')",
            "case \"$first\" in",
            "  file://*) p=$(printf '%s' \"$first\" | sed 's#^file://##' | python3 -c 'import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read().strip()))' 2>/dev/null) ;;",
            "  /*) p=\"$first\" ;;",
            "  *) p=\"\" ;;",
            "esac",
            "if [ \"$n\" -le 3 ] && [ -n \"$p\" ] && [ -f \"$p\" ]; then printf 'FILE\\t%s\\n' \"$p\"; else printf 'TEXT\\n%s' \"$c\"; fi"
        ].join("\n");
        _clipPreview.exec(["bash", "-c", script]);
    }

    function updatePreview() {
        const key = root.selectedKey;
        if (key === root._previewKeyShown) return;
        root._previewKeyShown = key;
        const it = root.selectedItem;
        if (it && it.kind === "file") { root.previewFile(it.path, !!it.isDirectory); return; }
        if (it && it.kind === "clip") {
            if (it.isImage && it.imagePath) { root.previewFile(it.imagePath, false); return; }
            if (it.pinned && it.pinPath) { root.previewClipSource("cat " + root.shellQuote(it.pinPath) + " 2>/dev/null"); return; }
            if (/^\d+$/.test(it.id || "")) { root.previewClipText(it.id); return; }
        }
        root.resetPreview();
    }

    // =====================================================================
    //  BUILDING RESULTS
    // =====================================================================
    function computeResultsHeight() {
        const maxH = Math.round(root.screen.height * 0.65);
        if (!root.hasBody) return 0;
        if (root.mode === "apps") {
            const rows = Math.max(1, Math.ceil(root.items.length / 2));
            return Math.min(maxH, Math.min(8, rows) * root.rowH + 16);
        }
        const idleSearch = root.query.length === 0 && root.mode === "search";
        let h = 12;
        if (root.sysStatsText.length > 0 && idleSearch) h += 24;
        // The window shows at most `maxVisibleRows` rows; the rest is reached by scrolling the list
        let rowsShown = 0;
        for (const r of root.results) {
            if (r.isHeader) { h += root.headerH; continue; }
            if (r.kind === "weather") { h += root.weatherH; continue; }
            if (r.kind === "volume" || r.kind === "brightness" || r.kind === "mic" || r.kind === "night" || r.kind === "lamp") { h += root.volumeH; continue; }
            if (r.kind === "power") { h += root.powerH; continue; }
            if (r.kind === "qr") { h += root.qrH; continue; }
            if (rowsShown >= root.maxVisibleRows) break;
            h += root.rowH;
            rowsShown++;
        }
        if (root.items.length === 0 && root.query.length > 0) h += 56;
        return Math.min(maxH, Math.max(48, h + 12));
    }

    function _addItems(items, disp, arr, title) {
        if (!arr.length) return;
        if (title) disp.push({ isHeader: true, title: title });
        for (const it of arr) {
            if (!it) continue;
            const copy = Object.assign({}, it);
            copy._idx = items.length;
            copy._dispIdx = disp.length;
            items.push(copy);
            disp.push(copy);
        }
    }

    function _appRows(list) {
        return list.map(a => ({ kind: "app", name: a.name, icon: a.icon, exec: a.exec, category: a.category || "Application",
                                id: a.id, wmClass: a.wmClass || a.startupClass || a.startupWMClass }));
    }

    function _fileRows(arr) {
        return arr.map(f => ({ kind: "file", name: f.name, path: f.path, dir: f.dir, category: f.dir, isDirectory: f.isDirectory }));
    }

    function _infoRow(text, category) { return [{ kind: "info", name: text, category: category }]; }

    function _calcRow(text, raw, category, iconKey) {
        return [{ kind: "calc", name: text, raw: raw, category: category, iconKey: iconKey || "calc" }];
    }

    function _sortedApps(q) {
        const found = spotlightApps.search(q);
        try {
            const ql = q.trim().toLowerCase();
            const scored = found.map(a => ({
                a: a, s: spotlightApps.matchScore(a, ql), u: root.usageOf("app:" + a.exec)
            }));
            scored.sort((x, y) => (y.s - x.s) || (y.u - x.u) || x.a.name.localeCompare(y.a.name));
            return scored.map(x => x.a);
        } catch (err) {
            console.warn("[Spotlight] app ranking failed, using usage order:", err);
            return found.slice().sort((a, b) => root.usageOf("app:" + b.exec) - root.usageOf("app:" + a.exec));
        }
    }

    function _buildSlashMode(items, disp, q, ql) {
        const full = ql.slice(1);
        const spaceIdx = full.indexOf(" ");
        const cmdName = spaceIdx >= 0 ? full.slice(0, spaceIdx) : full;
        const cmdArgs = spaceIdx >= 0 ? full.slice(spaceIdx + 1).trim() : "";
        const rawArgs = spaceIdx >= 0 ? q.slice(1 + spaceIdx + 1) : "";
        const A = (arr, title) => root._addItems(items, disp, arr, title);
        const hasArgs = cmdArgs.length > 0;

        if (cmdName === "web" && hasArgs) {
            A([{ kind: "action", name: "Search the Web for \u201c" + cmdArgs + "\u201d", action: "web:" + cmdArgs, iconKey: "web", category: "Search" }], "WEB SEARCH");
            return;
        }
        if (cmdName === "maps" && hasArgs) {
            const place = rawArgs.trim() || cmdArgs;
            A([{ kind: "action", name: "Search Google Maps for \u201c" + place + "\u201d", action: "open:" + root.bangs.maps[1] + encodeURIComponent(place), iconKey: "web", category: "Google Maps" }], "GOOGLE MAPS");
            return;
        }
        if (cmdName === "calc" && hasArgs) {
            const cr = root.evalMath(cmdArgs);
            if (cr !== null) A(root._calcRow("= " + cr, String(cr), "Calculator"), "CALCULATOR");
            return;
        }
        if ((cmdName === "search" || cmdName === "buscar") && hasArgs) {
            A(root.contentResults.map(f => ({ kind: "file", name: f.name, path: f.path, category: f.dir })), "CONTENT: " + cmdArgs);
            return;
        }
        if (cmdName === "ai" && hasArgs) {
            A(root._aiResultItems(), "AI");
            return;
        }
        if (cmdName === "emoji") {
            const filter = cmdArgs.toLowerCase();
            let list = root.emojiList;
            if (filter.length > 0) list = list.filter(x => x.n.indexOf(filter) !== -1 || x.e.indexOf(filter) !== -1);
            A(list.slice(0, 100).map(x => ({ kind: "emoji", name: x.e + "  " + x.n, raw: x.e, category: "Emoji — Enter to copy" })),
              filter ? "EMOJI: " + filter : "EMOJI");
            return;
        }
        if ((cmdName === "todo" || cmdName === "notes") && hasArgs) {
            A([root.todoActionItem(root.parseTodoInput(rawArgs))], "TODO");
            return;
        }
        if ((cmdName === "calendar" || cmdName === "cal" || cmdName === "evento" || cmdName === "event") && hasArgs) {
            const ev = root.parseEventInput(rawArgs);
            if (!ev.dueStr) {
                A([{ kind: "info", name: "Add a date or time: /event meeting 02/10 at 14h", category: "Event" }], "EVENT");
                return;
            }
            A([{
                kind: "action",
                name: "Add event: \u201c" + ev.text + "\u201d \u00b7 " + ev.dueLabel + (ev.remindAt ? " \u00b7 " + ev.duration + " min" : " \u00b7 all day"),
                action: "addevent:",
                evText: ev.text,
                evDate: ev.dueStr,
                evTime: ev.remindAt ? ev.remindAt.slice(11, 16) : "-",
                evDuration: ev.duration,
                evRemind: ev.remindAt,
                evRemindMs: ev.remindMs,
                iconKey: "note",
                category: "Calendar"
            }], "EVENT");
            return;
        }
        if (cmdName === "timer" && hasArgs) {
            const tm = cmdArgs.match(/^(\d+)\s*(min|m|s|sec|seg|h)?$/);
            if (tm) {
                const n = parseInt(tm[1]);
                const unit = tm[2] || "min";
                let secs = n * 60;
                if (unit === "s" || unit === "sec" || unit === "seg") secs = n;
                else if (unit === "h") secs = n * 3600;
                A([{ kind: "action", name: "Start " + n + " " + unit + " timer", action: "realtimer:" + secs + ":" + n + " " + unit, iconKey: "timer", category: "Timer" }], "TIMER");
                return;
            }
        }
        if (cmdName === "lembrar" && hasArgs) {
            const parsed = root.parseTodoInput(rawArgs);
            if (parsed.text && parsed.remindMs > Date.now()) {
                const seconds = Math.round((parsed.remindMs - Date.now()) / 1000);
                A([{
                    kind: "action",
                    name: "⏰ Lembrar: " + parsed.text + " · " + root.pad2(new Date(parsed.remindMs).getHours()) + ":" + root.pad2(new Date(parsed.remindMs).getMinutes()),
                    action: "localreminder:" + seconds + ":" + parsed.text,
                    iconKey: "bell",
                    category: "Lembrete"
                }], "LEMBRAR");
                return;
            } else if (parsed.text) {
                A([root.todoActionItem(parsed)], "LEMBRAR");
                return;
            }
        }

        const filtered = cmdName.length > 0
            ? root.slashCommands.filter(c => c.name.slice(1).toLowerCase().startsWith(cmdName))
            : root.slashCommands;
        A(filtered, "COMMANDS");
    }

    function _buildAppsMode(items, disp, q, ql) {
        const list = (ql ? spotlightApps.search(q) : spotlightApps.apps).slice();
        list.sort((a, b) => root.usageOf("app:" + b.exec) - root.usageOf("app:" + a.exec));
        root._addItems(items, disp, root._appRows(list.slice(0, 60)), ql ? "APPLICATIONS" : "");
    }

    function _buildFilesMode(items, disp, ql) {
        let src;
        if (!ql) src = root.recentItems.slice();
        else if (root.fileItems.length) src = root.fileItems;
        else src = root.recentItems.filter(f => f.name.toLowerCase().indexOf(ql) !== -1);
        const fitems = ql ? root.sortFileResults(src, ql) : src;
        const home = root.browseDir.replace(/^\/home\/[^\/]+/, "~");
        root._addItems(items, disp, root._fileRows(fitems), ql ? "FILES" : (home || "~"));
    }

    function _buildClipboardMode(items, disp) {
        const pins = root.clipPins || [];
        const pinned = new Set(pins.map(p => p.h));
        root._addItems(items, disp, pins.map(p => ({
            kind: "clip", pinned: true, h: p.h, id: "pin:" + p.h,
            name: p.image ? "Image" : (p.text || ""),
            category: p.image ? (p.mime || "Image") : "Pinned",
            isImage: p.image === true, imagePath: p.image ? p.path : "",
            pinPath: p.path, pinMime: p.mime || ""
        })), "PINNED");
        root._addItems(items, disp, root.clipItems.filter(c => !c.h || !pinned.has(c.h)).map(c => ({
            kind: "clip", pinned: false, h: c.h || "", name: c.isImage ? "Image" : c.text,
            id: c.id, category: c.isImage ? (c.text || "Image") : "Clipboard",
            isImage: !!c.isImage, imagePath: c.imagePath || ""
        })), "CLIPBOARD");
    }

    function _buildWindowsMode(items, disp, ql) {
        const wlist = ql ? root.windowItems.filter(w => w.title.toLowerCase().indexOf(ql) !== -1 || w.cls.toLowerCase().indexOf(ql) !== -1) : root.windowItems;
        root._addItems(items, disp, wlist.map(w => ({ kind: "window", name: w.title, address: w.address, category: w.cls })), "OPEN WINDOWS");
    }

    // =====================================================================
    //  VOLUME CARD
    // =====================================================================
    function volSet(v) {
        root.volLevel = Math.max(0, Math.min(1, v));
        root.volMuted = false;
        root._volHold = Date.now() + 600;
        if (!_volApply.running) _volApply.start();   // throttled: applies the latest value every 60 ms while dragging
    }

    // =====================================================================
    //  MIC / NIGHT LIGHT / POWER PROFILE / QR / KILL / USB
    // =====================================================================
    function _pinCard(disp, kind) {
        disp.unshift({ kind: kind });                                 // display-only card, pinned on top
        disp.forEach((d, i) => { if (d._idx !== undefined) d._dispIdx = i; });
    }

    // ---- microphone
    function micSet(v) {
        root.micLevel = Math.max(0, Math.min(1, v));
        root.micMuted = false;
        root._micHold = Date.now() + 600;
        if (!_micApply.running) _micApply.start();
    }

    function micSetMute(m) {
        root.micMuted = m;
        root._micHold = Date.now() + 600;
        spotlightController.run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ " + (m ? "1" : "0"));
    }

    // ---- bedroom light
    function lampSet(v) {
        root.lampLevel = Math.max(0.01, Math.min(1, v));
        root._lampTarget = Math.max(1, Math.round(root.lampLevel * 100));
        root.lampOn = true;
        root._lampHold = Date.now() + 4000;
        _lampApply.restart();
    }

    function lampToggle() {
        root.lampOn = !root.lampOn;
        root._lampHold = Date.now() + 4000;
        spotlightController.run("python3 \"" + root.lampScript + "\" " + (root.lampOn ? "on" : "off") + " --quiet");
    }

    // ---- night light
    function nightSet(level) {
        const l = Math.max(0, Math.min(1, level));
        root._nightTarget = Math.round(6000 - l * 3500);
        if (!Hyprsunset.temperatureActive) Hyprsunset.toggleTemperature(true);   // moving the bar turns it on
        if (!_nightApply.running) _nightApply.start();
    }

    function nightToggle() {
        Hyprsunset.toggleTemperature();
    }

    // ---- power profile
    function ppSet(id) {
        root.ppCurrent = id;
        root._ppHold = Date.now() + 1500;
        spotlightController.run("powerprofilesctl set " + id);
    }

    function ppCycle(dir) {
        const ids = root.ppProfiles.map(p => p.id);
        if (ids.length === 0) return;
        let i = ids.indexOf(root.ppCurrent);
        if (i < 0) i = 0;
        root.ppSet(ids[(i + dir + ids.length) % ids.length]);
    }

    // ---- QR code
    function _qrHook(text) {
        const t = text.trim();
        let want = "", label = "";
        const m = t.match(/^qr\s+([\s\S]+)$/i);
        if (m) { want = "t:" + m[1]; label = m[1]; }
        else if (/^wifi\s+qr$/i.test(t)) { want = "wifi"; label = "Current Wi-Fi network"; }
        if (want === root._qrWanted) return;
        root._qrWanted = want;
        if (want === "") return;
        root.qrBusy = true;
        root.qrError = "";
        root.qrLabel = label;
        _qrDeb.restart();
    }

    function _qrRun() {
        if (_qrGen.running) { _qrDeb.restart(); return; }
        const want = root._qrWanted;
        if (want === "") return;
        root._qrSeq++;
        root._qrRanFor = want;
        root._qrOut = "/tmp/spotlight-qr-" + root._qrSeq + ".png";
        _qrGen.environment = {
            "SP_OUT": root._qrOut,
            "SP_MODE": want === "wifi" ? "wifi" : "text",
            "SP_QR": want.startsWith("t:") ? want.slice(2) : ""
        };
        _qrGen.command = ["bash", "-c", root._qrScript];
        _qrGen.running = true;
    }

    // ---- /kill and /usb (typed as "/kill firefox", "/usb", "usb", "pendrive", "eject")
    function _extraWordOf(ql) {
        let m = ql.match(/^\/kill(?:\s+(.*))?$/);
        if (m) return { kind: "kill", filter: (m[1] || "").trim() };
        m = ql.match(/^(?:\/usb|usb|pendrive|ejetar|eject)(?:\s+(.*))?$/);
        if (m) return { kind: "usb", filter: (m[1] || "").trim() };
        m = ql.match(/^(?:\/keys|atalhos|shortcuts|keybinds|binds)(?:\s+(.*))?$/);
        if (m) return { kind: "keys", filter: (m[1] || "").trim() };
        return null;
    }

    function _extraWordHook(text) {
        const w = (root.mode === "search") ? root._extraWordOf(text.trim().toLowerCase()) : null;
        const kind = w ? w.kind : "";
        if (kind === root._extraShown) return;
        root._extraShown = kind;
        if (kind === "kill") root.procScan();
        else if (kind === "usb") root.usbScan();
        else if (kind === "keys") root.keysScan();
    }

    function procScan() { _procs.running = true; }
    function usbScan() { _usb.running = true; }

    function _buildKillMode(items, disp, filter) {
        const f = (filter || "").trim().toLowerCase();
        let list = root.killList;
        if (f) list = list.filter(p => p.args.toLowerCase().indexOf(f) >= 0 || String(p.pid) === f);
        else list = list.slice(0, 40);
        const rows = list.map(p => ({
            kind: "kproc",
            id: "proc:" + p.pid,
            pid: p.pid,
            name: p.name,
            category: "PID " + p.pid + " \u00B7 " + p.cpu.toFixed(1) + "% CPU \u00B7 " + p.mem.toFixed(1) + "% RAM"
        }));
        root._addItems(items, disp, rows, f ? "PROCESSES" : "TOP PROCESSES");
        if (rows.length === 0)
            root._addItems(items, disp, root._infoRow(_procs.running ? "Loading processes\u2026" : "No matching processes", ""), "PROCESSES");
    }

    function _buildUsbMode(items, disp, filter) {
        const f = (filter || "").trim().toLowerCase();
        const list = f ? root.usbItems.filter(d => (d.name + " " + d.dev).toLowerCase().indexOf(f) >= 0) : root.usbItems;
        const rows = list.map(d => ({
            kind: "usb",
            id: "usb:" + d.dev,
            dev: d.dev,
            parent: d.parent,
            mp: d.mp,
            name: d.name,
            category: d.mp ? ("Mounted \u00B7 " + d.mp + " \u00B7 " + d.size) : ("Not mounted \u00B7 " + d.size)
        }));
        root._addItems(items, disp, rows, "EXTERNAL DRIVES");
        if (rows.length === 0)
            root._addItems(items, disp, root._infoRow(_usb.running ? "Looking for drives\u2026" : "No external drives found", ""), "EXTERNAL DRIVES");
    }

    // Enter ends the process (SIGTERM), Shift+Enter forces it (SIGKILL). The list stays open and refreshes.
    function _activateProc(e, alt) {
        const pid = parseInt(e.pid);
        if (!(pid > 1)) return true;
        spotlightController.run("kill " + (alt ? "-9 " : "") + pid + " 2>/dev/null");
        _procRefresh.restart();
        return true;
    }

    // Enter ejects a mounted drive (or mounts an unmounted one), Shift+Enter opens the mounted folder.
    function _activateUsb(e, alt) {
        const env = { "SP_DEV": e.dev, "SP_PARENT": e.parent, "SP_NAME": e.name, "SP_MP": e.mp };
        let script;
        if (e.mp && alt) {
            script = "xdg-open \"$SP_MP\" >/dev/null 2>&1";
        } else if (e.mp) {
            script = [
                "notify-send -t 2500 'Drive' \"Ejecting $SP_NAME\u2026\"",
                "lsblk -nrpo PATH,MOUNTPOINTS \"$SP_PARENT\" | awk 'NF>1 {print $1}' | while read -r p; do udisksctl unmount -b \"$p\" >/dev/null 2>&1; done",
                "if udisksctl power-off -b \"$SP_PARENT\" >/dev/null 2>&1; then",
                "  notify-send 'Drive' \"$SP_NAME can be removed safely\"",
                "else",
                "  notify-send -u critical 'Drive' \"Could not eject $SP_NAME (is something still using it?)\"",
                "fi"
            ].join("\n");
        } else {
            script = [
                "if out=$(udisksctl mount -b \"$SP_DEV\" 2>&1); then",
                "  notify-send 'Drive' \"$out\"",
                "else",
                "  notify-send -u critical 'Drive' \"Could not mount $SP_NAME\"",
                "fi"
            ].join("\n");
        }
        root._netRun(script, env);
        return false;
    }

    // =====================================================================
    //  FILE ACTIONS PANEL (Ctrl+K) and /keys
    // =====================================================================
    function _baseName(p) { const i = p.lastIndexOf("/"); return i >= 0 ? p.slice(i + 1) : p; }
    function _dirName(p) { const i = p.lastIndexOf("/"); return i > 0 ? p.slice(0, i) : "/"; }

    function fileActOpen(item) {
        if (!item || item.kind !== "file" || !item.path) return;
        root.fileActFor = { path: item.path, name: item.name || root._baseName(item.path), isDirectory: !!item.isDirectory };
        root.fileActStage = "actions";
        root.fileActPending = "";
        root.selectedIndex = 0;
        root._userNavigated = false;
        root.scheduleRebuild();
    }

    function fileActClose() {
        root.fileActFor = null;
        root.fileActStage = "actions";
        root.fileActPending = "";
        root.selectedIndex = 0;
        root._userNavigated = false;
        root.scheduleRebuild();
    }

    // Esc / back inside "Open with..." returns to the action list. False when there is nothing to go back to.
    function fileActBack() {
        if (root.fileActStage !== "apps") return false;
        root.fileActStage = "actions";
        root.selectedIndex = 0;
        root._userNavigated = false;
        root.scheduleRebuild();
        return true;
    }

    function _openWithScan(path) {
        _openWith.environment = { "SP_FILE": path };
        _openWith.command = ["bash", "-c", root._openWithScript];
        _openWith.running = true;
    }

    function _buildFileActions(items, disp) {
        const f = root.fileActFor;
        if (!f) return;
        if (root.fileActStage === "apps") {
            const apps = root.fileOpenWith.map(a => ({
                kind: "fapp", id: "fapp:" + a.id, name: a.name, category: a.id, iconKey: "grid", appFile: a.file
            }));
            root._addItems(items, disp, apps, "OPEN WITH \u00B7 " + f.name);
            if (apps.length === 0)
                root._addItems(items, disp, root._infoRow(_openWith.running ? "Looking for apps\u2026" : "No other apps found for this file", ""), "OPEN WITH \u00B7 " + f.name);
            return;
        }
        const dir = root._dirName(f.path);
        const rows = [
            { kind: "fact", id: "fact:open",     act: "open",     name: "Open",            category: f.name,                          iconKey: "external" },
            { kind: "fact", id: "fact:folder",   act: "folder",   name: "Open folder",     category: dir,                             iconKey: "folder" },
            { kind: "fact", id: "fact:with",     act: "with",     name: "Open with\u2026", category: "Choose another app",            iconKey: "grid" },
            { kind: "fact", id: "fact:copypath", act: "copypath", name: "Copy path",       category: f.path,                          iconKey: "link" },
            { kind: "fact", id: "fact:copyfile", act: "copyfile", name: "Copy file",       category: "Paste it in Dolphin or a chat", iconKey: "copy" },
            { kind: "fact", id: "fact:rename",   act: "rename",   name: "Rename\u2026",    category: f.name,                          iconKey: "edit" },
            { kind: "fact", id: "fact:trash",    act: "trash",
              name: root.fileActPending === "trash" ? "Move to trash?" : "Move to trash",
              category: root.fileActPending === "trash" ? "Press Enter again to confirm" : "You can restore it from the trash",
              iconKey: "trash" }
        ];
        root._addItems(items, disp, rows, "ACTIONS \u00B7 " + f.name);
    }

    // Returns true if Spotlight should stay open.
    function _activateFileAct(e) {
        const f = root.fileActFor;
        if (!f) return true;
        switch (e.act) {
        case "open":
            root.xdgOpen(f.path);
            return false;
        case "folder":
            root.xdgOpen(root._dirName(f.path));
            return false;
        case "with":
            root.fileActStage = "apps";
            root.fileOpenWith = [];
            root.selectedIndex = 0;
            root._userNavigated = false;
            root._openWithScan(f.path);
            root.scheduleRebuild();
            return true;
        case "copypath":
            root.copyText(f.path);
            return false;
        case "copyfile":
            root._netRun([
                "if printf '%s\\r\\n' \"$SP_URI\" | wl-copy --type text/uri-list; then",
                "  notify-send -t 2000 'Spotlight' \"Copied $SP_NAME\"",
                "else",
                "  notify-send -u critical 'Spotlight' \"Could not copy $SP_NAME\"",
                "fi"
            ].join("\n"), { "SP_URI": "file://" + encodeURI(f.path).replace(/#/g, "%23").replace(/\?/g, "%3F"), "SP_NAME": f.name });
            return false;
        case "rename":
            root.renameStart();
            return true;
        case "trash":
            if (root.fileActPending !== "trash") {
                root.fileActPending = "trash";
                root.scheduleRebuild();
                return true;
            }
            root._netRun([
                "if gio trash -- \"$SP_FILE\" 2>/dev/null; then",
                "  notify-send 'Spotlight' \"Moved to trash: $SP_NAME\"",
                "else",
                "  notify-send -u critical 'Spotlight' \"Could not move $SP_NAME to the trash\"",
                "fi"
            ].join("\n"), { "SP_FILE": f.path, "SP_NAME": f.name });
            return false;
        }
        return true;
    }

    function _activateFileApp(e) {
        const f = root.fileActFor;
        if (!f) return true;
        root._netRun(
            "gio launch \"$SP_DESKTOP\" \"$SP_FILE\" >/dev/null 2>&1 || notify-send -u critical 'Open with' \"Could not open with $SP_APP\"",
            { "SP_DESKTOP": e.appFile, "SP_FILE": f.path, "SP_APP": e.name });
        return false;
    }

    // ---- rename: the search field becomes the name field (its text never reaches root.query)
    function renameStart() {
        const f = root.fileActFor;
        if (!f) return;
        root.renameReturnText = searchField.text;
        root.renameFor = f.path;
        root.renameText = f.name;
        root.fileActFor = null;
        root.fileActStage = "actions";
        root.fileActPending = "";
        searchField.text = f.name;
        searchField.forceActiveFocus();
        const dot = f.name.lastIndexOf(".");
        searchField.select(0, dot > 0 ? dot : f.name.length);      // select the name, not the extension
        root.scheduleRebuild();
    }

    function renameCancel() {
        const back = root.renameReturnText;
        root.renameFor = "";
        root.renameText = "";
        searchField.text = back;
        root.scheduleRebuild();
    }

    function renameSubmit() {
        const old = root.renameFor;
        const nn = root.renameText.trim();
        if (nn === "" || nn.indexOf("/") >= 0 || nn === root._baseName(old)) { root.renameCancel(); return; }
        root.renameFor = "";
        root.renameText = "";
        root._netRun([
            "if [ -e \"$SP_NEW\" ]; then",
            "  notify-send -u critical 'Spotlight' \"A file named $SP_NAME already exists\"",
            "elif mv -- \"$SP_OLD\" \"$SP_NEW\"; then",
            "  notify-send 'Spotlight' \"Renamed to $SP_NAME\"",
            "else",
            "  notify-send -u critical 'Spotlight' \"Could not rename to $SP_NAME\"",
            "fi"
        ].join("\n"), { "SP_OLD": old, "SP_NEW": root._dirName(old) + "/" + nn, "SP_NAME": nn });
        spotlightController.spotlightOpen = false;
    }

    function _buildRenamePrompt(items, disp) {
        root._addItems(items, disp, [{
            kind: "info",
            name: "Type the new name and press Enter",
            category: "Esc to cancel"
        }], "RENAME \u00B7 " + root._baseName(root.renameFor));
    }

    // ---- /keys: Hyprland shortcuts from `hyprctl binds -j`
    function keysScan() { _keys.running = true; }

    function _buildKeysMode(items, disp, filter) {
        const f = (filter || "").toLowerCase().replace(/\+/g, " ").trim();
        const tokens = f.split(/\s+/).filter(t => t.length > 0);
        let list = root.keysItems;
        if (tokens.length)
            list = list.filter(k => {
                const hay = (k.combo + " " + k.action).toLowerCase().replace(/\+/g, " ");
                return tokens.every(t => hay.indexOf(t) >= 0);
            });
        const rows = list.slice(0, 200).map(k => ({
            kind: "key",
            id: "key:" + k.idx,
            name: k.action,
            category: k.combo + (k.submap ? "  \u00B7  submap: " + k.submap : ""),
            combo: k.combo
        }));
        root._addItems(items, disp, rows, tokens.length ? "SHORTCUTS" : "HYPRLAND SHORTCUTS");
        if (rows.length === 0)
            root._addItems(items, disp, root._infoRow(_keys.running ? "Loading shortcuts\u2026" : "No shortcuts found", ""), "SHORTCUTS");
    }

    // Enter copies the shortcut text (e.g. "Super + Shift + Q"); it never runs the bind.
    function _activateKey(e) {
        root.copyText(e.combo);
        return false;
    }

    function brightSet(v) {
        if (!root.brightControllable) return;
        root.brightMonitor.setBrightness(Math.max(0.01, Math.min(1, v)));   // never 0%: a black screen is hard to undo
    }

    function volSetMute(m) {
        root.volMuted = m;
        root._volHold = Date.now() + 600;
        spotlightController.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ " + (m ? "1" : "0"));
    }

    // =====================================================================
    //  WI-FI / BLUETOOTH PICKER
    // =====================================================================
    // Typing "wifi" or "bluetooth" (optionally followed by a filter) lists the networks / devices
    // around you. "wifi on|off" and "bluetooth on|off" keep their old behaviour.
    function _netWordOf(ql) {
        const m = ql.match(/^(wi-?fi|bluetooth)(?:\s+(.*))?$/);
        if (!m) return null;
        const rest = (m[2] || "").trim();
        if (/^(on|off|ligar|desligar)$/.test(rest) || (m[1].charAt(0) === "w" && rest === "qr")) return null;
        return { kind: m[1].charAt(0) === "w" ? "wifi" : "bluetooth", filter: rest };
    }

    function _netWordHook(text) {
        const w = (root.mode === "search") ? root._netWordOf(text.trim().toLowerCase()) : null;
        const kind = w ? w.kind : "";
        if (kind === root._netWordShown) return;
        root._netWordShown = kind;
        if (kind === "wifi") root.wifiScan();
        else if (kind === "bluetooth") root.btScan();
    }

    function wifiScan() {
        _wifi.running = true;
        _wifiRescan.running = true;
    }

    function btScan() {
        _btDiscover.running = true;
        _bt.running = true;
    }

    function wifiAskPassword(ssid) {
        root.netPassReturnText = searchField.text;
        root.netPassFor = ssid;
        root.netPass = "";
        searchField.text = "";
        root.scheduleRebuild();
    }

    function wifiCancelPassword() {
        const back = root.netPassReturnText;
        root.netPassFor = "";
        root.netPass = "";
        searchField.text = back;
        root.scheduleRebuild();
    }

    function wifiSubmitPassword() {
        const ssid = root.netPassFor;
        const pass = root.netPass;
        if (pass.length === 0) return;
        root.netPassFor = "";
        root.netPass = "";
        root._netRun([
            "notify-send -t 2500 'Wi-Fi' \"Connecting to $SP_SSID\u2026\"",
            "nmcli connection delete id \"$SP_SSID\" >/dev/null 2>&1",
            "if nmcli device wifi connect \"$SP_SSID\" password \"$SP_PASS\" >/dev/null 2>&1; then",
            "  notify-send 'Wi-Fi' \"Connected to $SP_SSID\"",
            "else",
            "  nmcli connection delete id \"$SP_SSID\" >/dev/null 2>&1",
            "  notify-send -u critical 'Wi-Fi' \"Could not connect to $SP_SSID (wrong password?)\"",
            "fi"
        ].join("\n"), { "SP_SSID": ssid, "SP_PASS": pass });
        spotlightController.spotlightOpen = false;
    }

    // Runs a script in the background; values reach it through environment variables (never through quoting).
    function _netRun(script, env) {
        if (_netAct.running) {
            spotlightController.run("notify-send 'Spotlight' 'A network action is still running, try again in a moment'");
            return;
        }
        _netAct.environment = env;
        _netAct.command = ["bash", "-c", script];
        _netAct.running = true;
    }

    function _activateWifi(e, alt) {
        if (e.active && !alt) return false;
        if (e.secure && (!e.saved || alt)) {
            root.wifiAskPassword(e.name);
            return true;
        }
        root._netRun([
            "notify-send -t 2500 'Wi-Fi' \"Connecting to $SP_SSID\u2026\"",
            "if nmcli connection up id \"$SP_SSID\" >/dev/null 2>&1 || nmcli device wifi connect \"$SP_SSID\" >/dev/null 2>&1; then",
            "  notify-send 'Wi-Fi' \"Connected to $SP_SSID\"",
            "else",
            "  notify-send -u critical 'Wi-Fi' \"Could not connect to $SP_SSID. Try Shift+Enter to type a new password.\"",
            "fi"
        ].join("\n"), { "SP_SSID": e.name });
        return false;
    }

    function _activateBt(e, alt) {
        const env = { "SP_MAC": e.address, "SP_NAME": e.name };
        let script;
        if (alt && e.paired) {
            script = [
                "bluetoothctl remove \"$SP_MAC\" >/dev/null 2>&1",
                "notify-send 'Bluetooth' \"Forgot $SP_NAME\""
            ].join("\n");
        } else if (e.connected) {
            script = [
                "bluetoothctl disconnect \"$SP_MAC\" >/dev/null 2>&1",
                "notify-send 'Bluetooth' \"Disconnected from $SP_NAME\""
            ].join("\n");
        } else if (e.paired) {
            script = [
                "notify-send -t 2500 'Bluetooth' \"Connecting to $SP_NAME\u2026\"",
                "out=$(bluetoothctl connect \"$SP_MAC\" 2>&1)",
                "case \"$out\" in",
                "  *successful*) notify-send 'Bluetooth' \"Connected to $SP_NAME\";;",
                "  *) notify-send -u critical 'Bluetooth' \"Could not connect to $SP_NAME\";;",
                "esac"
            ].join("\n");
        } else {
            script = [
                "notify-send -t 4000 'Bluetooth' \"Pairing with $SP_NAME\u2026\"",
                "bluetoothctl scan off >/dev/null 2>&1",
                "bluetoothctl --timeout 30 --agent NoInputNoOutput pair \"$SP_MAC\" >/dev/null 2>&1 || bluetoothctl pair \"$SP_MAC\" >/dev/null 2>&1",
                "bluetoothctl trust \"$SP_MAC\" >/dev/null 2>&1",
                "out=$(bluetoothctl connect \"$SP_MAC\" 2>&1)",
                "case \"$out\" in",
                "  *successful*) notify-send 'Bluetooth' \"Paired and connected to $SP_NAME\";;",
                "  *) notify-send -u critical 'Bluetooth' \"Could not pair with $SP_NAME (it may need a PIN, or not be in pairing mode)\";;",
                "esac"
            ].join("\n");
        }
        root._netRun(script, env);
        return false;
    }

    function _buildPasswordPrompt(items, disp) {
        root._addItems(items, disp, [{
            kind: "info",
            name: "Type the password for \u201C" + root.netPassFor + "\u201D and press Enter",
            category: "Esc to cancel"
        }], "WI-FI");
    }

    function _buildWifiMode(items, disp, filter) {
        const f = (filter || "").trim().toLowerCase();
        const list = f ? root.wifiItems.filter(w => w.ssid.toLowerCase().indexOf(f) >= 0) : root.wifiItems;
        const rows = list.map(w => ({
            kind: "wifi",
            id: "wifi:" + w.ssid,
            name: w.ssid,
            iconKey: "wifi",
            active: w.active,
            secure: w.secure,
            saved: w.saved,
            category: w.active ? "Connected"
                      : ((w.saved ? "Saved" : (w.secure ? "Secured" : "Open")) + " \u00B7 " + w.signal + "%")
        }));
        root._addItems(items, disp, rows, "WI-FI NETWORKS");
        if (rows.length === 0)
            root._addItems(items, disp, root._infoRow((_wifi.running || _wifiRescan.running) ? "Scanning for networks\u2026" : "No networks found", ""), "WI-FI NETWORKS");
        root._addItems(items, disp, [{ kind: "action", name: "Wi-Fi settings", action: "settings_open:WifiConfig.qml|wifi", iconKey: "settings", category: "Settings" }], "");
    }

    function _buildBluetoothMode(items, disp, filter) {
        const f = (filter || "").trim().toLowerCase();
        const list = f ? root.btItems.filter(d => d.name.toLowerCase().indexOf(f) >= 0) : root.btItems;
        const rows = list.map(d => ({
            kind: "bt",
            id: "bt:" + d.mac,
            name: d.name,
            address: d.mac,
            iconKey: "bluetooth",
            paired: d.paired,
            connected: d.connected,
            category: d.connected ? "Connected" : (d.paired ? "Paired" : "Available \u00B7 not paired")
        }));
        root._addItems(items, disp, rows, "BLUETOOTH DEVICES");
        if (rows.length === 0)
            root._addItems(items, disp, root._infoRow(_btDiscover.running ? "Searching for devices\u2026" : "No devices found", ""), "BLUETOOTH DEVICES");
        root._addItems(items, disp, [{ kind: "action", name: "Bluetooth settings", action: "settings_open:BluetoothConfig.qml|bluetooth", iconKey: "settings", category: "Settings" }], "");
    }

    // =====================================================================
    //  COMMAND MENU (/menu)
    // =====================================================================
    function _menuStripComments(text) {
        // only whole-line // comments, so URLs inside strings survive
        return text.replace(/^\s*\/\/.*$/gm, "");
    }

    function _menuNormalize(nodes, parentPath, parentIds) {
        const out = [];
        let i = 0;
        for (const n of (nodes || [])) {
            if (!n || typeof n.label !== "string") continue;
            const path = parentPath ? parentPath + " \u203A " + n.label : n.label;
            const ids = parentIds.concat(i);
            out.push({
                label: n.label,
                icon: n.icon || "",
                keywords: n.keywords || "",
                command: (n.command !== undefined) ? n.command : null,
                confirm: n.confirm === true,
                path: path,
                parentPath: parentPath,
                ids: ids,
                children: Array.isArray(n.children) ? root._menuNormalize(n.children, path, ids) : null
            });
            i++;
        }
        return out;
    }

    function _menuFlatten(nodes, acc) {
        for (const n of nodes) {
            acc.push(n);
            if (n.children) root._menuFlatten(n.children, acc);
        }
        return acc;
    }

    function menuRebuild() {
        let parsed = null;
        for (const text of [root._menuUserText, root._menuDefaultText]) {
            if (!text) continue;
            try {
                const obj = JSON.parse(text);
                const arr = Array.isArray(obj) ? obj : obj.items;
                if (Array.isArray(arr)) { parsed = arr; break; }
            } catch (err) {
                console.warn("[Spotlight] invalid command menu JSON:", err);
            }
        }
        root.menuTree = root._menuNormalize(parsed || [], "", []);
        root.menuFlat = root._menuFlatten(root.menuTree, []);
        root.menuStack = [];
        root.menuPendingId = "";
        if (root.mode === "menu") root.scheduleRebuild();
    }

    function menuReset() {
        root.menuStack = [];
        root.menuPendingId = "";
    }

    // One level up. Returns false when already at the top.
    function menuBack() {
        if (root.menuStack.length === 0) return false;
        root.menuStack = root.menuStack.slice(0, -1);
        root.menuPendingId = "";
        root.selectedIndex = 0;
        root._userNavigated = false;
        root.scheduleRebuild();
        return true;
    }

    function _menuResolve(ids) {
        const stack = [];
        let level = root.menuTree;
        for (const i of ids) {
            const n = level[i];
            if (!n) break;
            stack.push(n);
            level = n.children || [];
        }
        return stack;
    }

    function _menuSearch(ql) {
        const tokens = ql.split(/\s+/).filter(t => t.length > 0);
        if (tokens.length === 0) return [];
        const joined = tokens.join(" ");
        const scored = [];
        for (const n of root.menuFlat) {
            const label = n.label.toLowerCase();
            const hay = (n.path + " " + n.keywords).toLowerCase();
            let ok = true;
            for (const t of tokens) { if (hay.indexOf(t) < 0) { ok = false; break; } }
            if (!ok) continue;
            let score = 0;
            if (label === joined) score += 100;
            if (label.startsWith(tokens[0])) score += 50;
            else if (label.indexOf(tokens[0]) >= 0) score += 20;
            if (!n.children) score += 5;
            score -= n.path.length * 0.1;
            scored.push({ node: n, score: score });
        }
        scored.sort((a, b) => b.score - a.score);
        return scored.map(s => s.node);
    }

    function _buildMenuMode(items, disp, q, ql) {
        const searching = ql.length > 0;
        if (root.menuTree.length === 0) {
            root._addItems(items, disp, root._infoRow("The command menu is empty", "Check ~/.config/illogical-impulse/menu.jsonc"), "COMMAND MENU");
            return;
        }
        const level = root.menuStack.length ? root.menuStack[root.menuStack.length - 1].children : root.menuTree;
        const nodes = searching ? root._menuSearch(ql) : level;
        const title = (!searching && root.menuStack.length)
            ? root.menuStack.map(n => n.label).join("  \u203A  ").toUpperCase()
            : "COMMAND MENU";
        const rows = nodes.map(n => {
            const key = n.ids.join(".");
            const pending = root.menuPendingId === key;
            let cat;
            if (pending) cat = "Press Enter again to run";
            else if (n.children) cat = searching ? n.path : "Folder";
            else if (searching) cat = n.parentPath !== "" ? n.parentPath : "Command";
            else cat = n.confirm ? "Asks for confirmation" : "Command";
            return {
                kind: "menu",
                id: "menu:" + key,
                menuIds: n.ids,
                name: pending ? "Confirm: " + n.label : n.label,
                category: cat,
                iconKey: n.icon || (n.children ? "files" : "default"),
                isFolder: n.children !== null,
                command: n.command,
                confirm: n.confirm
            };
        });
        root._addItems(items, disp, rows, title);
    }

    function _menuRun(cmd) {
        if (Array.isArray(cmd)) spotlightController.run(cmd.map(a => root.shellQuote(a)).join(" "));
        else spotlightController.run(String(cmd));
    }

    // Returns true if Spotlight should stay open.
    function _activateMenu(e) {
        if (e.isFolder) {
            root.menuStack = root._menuResolve(e.menuIds);
            root.menuPendingId = "";
            if (root.query !== "") { searchField.text = ""; root.query = ""; }
            root.selectedIndex = 0;
            root._userNavigated = false;
            root.scheduleRebuild();
            return true;
        }
        if (e.command === null || e.command === undefined) return true;
        if (e.confirm && root.menuPendingId !== e.menuIds.join(".")) {
            root.menuPendingId = e.menuIds.join(".");
            root.scheduleRebuild();
            return true;
        }
        root.menuPendingId = "";
        root._menuRun(e.command);
        return false;
    }

    function _buildActionsMode(items, disp) {
        const acts = [];
        const A = (name, act, key, cat) => acts.push({ kind: "action", name: name, action: act, iconKey: key, category: cat || "Actions" });
        A("Start Timer", "action:timer", "timer", "Actions");
        A("Lock Screen", "lock", "lock", "System");
        A("Sleep", "sleep", "moon", "System");
        A("Restart\u2026", "restart", "restart", "System");
        A("Shut Down\u2026", "shutdown", "power", "System");
        A("Log Out", "logout", "logout", "System");
        root._addItems(items, disp, acts, "ACTIONS");
    }

    // -- Search mode, split into blocks (section order is preserved)
    function _searchPrimary(items, disp, q, ql) {
        const A = (arr, title) => root._addItems(items, disp, arr, title);

        const aiItems = root._aiResultItems();
        if (aiItems.length) A(aiItems, "AI");

        const urlT = root.urlTarget(q);
        if (urlT) A([{ kind: "action", name: "Open " + q.trim(), action: "open:" + urlT, iconKey: "web", category: "Website" }], "OPEN WEBSITE");

        const bang = root.bangItem(q);
        if (bang) A([bang], "SITE SHORTCUT");

        const sc = root.sysControlItems(ql);
        if (sc.length) A(sc, "CONTROLS");

        if (root.procItems.length && /^(kill|matar|encerrar|pkill)\s/i.test(q)) {
                    A(root.procItems.map(pr => ({
                        kind: "proc", name: pr.name, pid: pr.pid,
                        category: "PID " + pr.pid + " · " + pr.mb + " MB · Enter = kill · Shift+Enter = force kill"
                    })), "PROCESSES");
                }
                if (root.timeText && /^(?:que\s+)?(?:hora|horas|time)\s/.test(ql)) A(root._infoRow(root.timeText, "Time"), "TIME");

        const colorIt = root.colorItem(q);
        if (colorIt) A([colorIt], "COLOR");

        if (root.devResult.q === q && root.devResult.text) {
            A(root._calcRow(root.devResult.text, root.devResult.text, root.devResult.label + " \u2014 click to copy"), "TOOLS");
        }
        let appList = [];
        try { appList = root._sortedApps(q); } catch (err) { console.warn("[Spotlight] app search failed:", err); appList = spotlightApps.search(q); }
        A(root._appRows(appList), "APPLICATIONS");
    }

    function _searchInfo(items, disp, q, ql) {
        const A = (arr, title) => root._addItems(items, disp, arr, title);

        if (ql.startsWith("clima") || ql.startsWith("weather")) {
            if (root.weatherData) disp.push({ kind: "weather", wx: root.weatherData });   // display-only card
            else if (root.weatherText) A(root._infoRow(root.weatherText, "Weather"), "WEATHER");
        }
        if ((ql.startsWith("define ") || ql.startsWith("significado ") || ql.startsWith("meaning ")) && root.dictText)
            A(root._infoRow(root.dictText, "Definition"), "DEFINITION");
        if (/^(senha|password)\s*(\d+)?$/.test(ql) && root.passText)
            A(root._calcRow(root.passText, root.passText, "Generated password — click to copy", "lock"), "PASSWORD");

        const todoMatch = q.match(/^(todo|tarefa|afazer)\s+(.+)$/i);
        if (todoMatch) A([root.todoActionItem(root.parseTodoInput(todoMatch[2]))], "TODO");

        if ((ql === "bateria" || ql === "battery") && root.batteryText) A(root._infoRow(root.batteryText, "Battery"), "BATTERY");
        if ((ql === "meu ip" || ql === "my ip") && root.ipText) A(root._infoRow(root.ipText, "Network"), "MY IP");
        if (root.currencyText) A(root._calcRow(root.currencyText, root.currencyText, "Currency"), "CURRENCY");
        if (root.quoteResult.q && root.quoteResult.q === ql.replace(/\s+/g, " ")) {
            if (root.quoteResult.loading) A(root._infoRow(root.quoteResult.text, "Cota\u00e7\u00e3o"), "COTA\u00c7\u00c3O");
            else if (root.quoteResult.raw) A(root._calcRow(root.quoteResult.text, root.quoteResult.raw, root.quoteResult.sub, "trend"), "COTA\u00c7\u00c3O");
            else A(root._infoRow(root.quoteResult.text, "Cota\u00e7\u00e3o"), "COTA\u00c7\u00c3O");
        }
    }

    function _searchActions(items, disp, q, ql) {
        const A = (arr, title) => root._addItems(items, disp, arr, title);

        // Fuzzy match: split query into words, all must match somewhere
        const qWords = ql.split(/\s+/).filter(w => w.length > 0);

        const playMatch = q.match(/^(toque|tocar|play)\s+(.+)$/i);
        if (playMatch) {
            A([{ kind: "action", name: "Play \u201c" + playMatch[2] + "\u201d on Spotify", action: "spotifyplay:" + playMatch[2], iconKey: "music", category: "Spotify" }], "SPOTIFY");
        }

        const timerMatch = ql.match(/^timer\s+(\d+)\s*(min|m|s|sec|seg|h)?$/);
        if (timerMatch) {
            const n = parseInt(timerMatch[1]);
            const unit = timerMatch[2] || "min";
            let secs = n * 60;
            if (unit === "s" || unit === "sec" || unit === "seg") secs = n;
            else if (unit === "h") secs = n * 3600;
            A([{ kind: "action", name: "Start " + n + " " + unit + " timer", action: "realtimer:" + secs + ":" + n + " " + unit, iconKey: "timer", category: "Timer" }], "TIMER");
        }

        const lembrarMatch = ql.match(/^lembrar\s+(\d+)\s*(min|m|s|sec|seg|h)?\s+(.+)$/);
        if (lembrarMatch) {
            const n = parseInt(lembrarMatch[1]);
            const unit = lembrarMatch[2] || "min";
            const msg = lembrarMatch[3].trim();
            let secs = n * 60;
            if (unit === "s" || unit === "sec" || unit === "seg") secs = n;
            else if (unit === "h") secs = n * 3600;
            A([{ kind: "action", name: "Lembrar daqui a " + n + " " + unit + ": " + msg, action: "localreminder:" + secs + ":" + msg, iconKey: "bell", category: "Lembrete" }], "LEMBRAR");
        }

        if ("lock screen sleep restart shut down log out".includes(ql)) {
            A([
                { kind: "action", name: "Lock Screen",   action: "lock",     iconKey: "lock",    category: "System" },
                { kind: "action", name: "Sleep",         action: "sleep",    iconKey: "moon",    category: "System" },
                { kind: "action", name: "Restart\u2026", action: "restart",  iconKey: "restart", category: "System" },
                { kind: "action", name: "Shut Down\u2026", action: "shutdown", iconKey: "power",  category: "System" },
                { kind: "action", name: "Log Out",       action: "logout",   iconKey: "logout",  category: "System" }
            ], "SYSTEM");
        }

        const mm = /^-?[\d.]+$/.test(q) ? null : root.evalMath(q);
        if (mm !== null) {
            A(root._calcRow("= " + mm, String(mm), "Calculator"), "CALCULATOR");
        } else {
            const cv = root.convertUnits(q);
            if (cv !== null) A(root._calcRow("= " + cv, cv, "Conversion"), "CONVERSION");
        }

    }

    // -- Settings + web search shortcuts (shown BEFORE files)
    function _searchSettings(items, disp, q, ql) {
        const A = (arr, title) => root._addItems(items, disp, arr, title);
        const qWords = ql.split(/\s+/).filter(w => w.length > 0);

        // Settings shortcuts in main search (fuzzy match on section names + deep search grouped by parent)
                const settingsMap = {
                    "interface": "InterfaceConfig.qml",
                    "appearance": "InterfaceConfig.qml",
                    "bar": "BarConfig.qml",
                    "dock": "DockConfig.qml",
                    "background": "BackgroundConfig.qml",
                    "wallpaper": "BackgroundConfig.qml",
                    "decorations": "DecorationsConfig.qml",
                    "display": "DisplayConfig.qml",
                    "layouts": "LayoutsConfig.qml",
                    "keyboard": "KeyboardConfig.qml",
                    "mouse": "MouseConfig.qml",
                    "power": "PowerConfig.qml",
                    "wifi": "WifiConfig.qml",
                    "bluetooth": "BluetoothConfig.qml",
                    "quick": "QuickConfig.qml",
                    "services": "ServicesConfig.qml",
                    "manage": "ManageAppsConfig.qml",
                    "settings": "InterfaceConfig.qml"  // generic entry point
                };
        
                // Track which parent sections we've already shown
                const shownParents = new Set();
                const allSectionItems = [];

                // 1. Direct section name matches from settingsMap
                const matchedSections = Object.keys(settingsMap).filter(k => 
                    qWords.every(w => k.includes(w))
                ).slice(0, 10);
                for (const k of matchedSections) {
                    const parent = k; // e.g., "background", "wallpaper"
                    if (!shownParents.has(parent)) {
                        shownParents.add(parent);
                        allSectionItems.push({
                            kind: "action",
                            name: "Open settings \u2192 " + k.charAt(0).toUpperCase() + k.slice(1),
                            action: "settings_open:" + settingsMap[k] + "|" + parent,
                            iconKey: "settings",
                            category: "Settings"
                        });
                    }
                }

                // 2. Deep search: find nested config items and group by parent SECTION
                let deepPaths = [];
                try {
                    deepPaths = root.flattenConfigPaths(Config.options || {});
                } catch (e) {
                    deepPaths = [];
                }
                const deepMatches = deepPaths.filter(c => 
                    !c.isSection && qWords.every(w => (c.path + " " + c.name).toLowerCase().includes(w))
                ).slice(0, 15);

                // Keyword aliases for settings not in Config.options (stored in hyprland/env)
                const keywordMap = {
                    "gap": ["decorations.gapsIn", "decorations.gapsOut", "interface.workspace_gap"],
                    "gaps": ["decorations.gapsIn", "decorations.gapsOut", "interface.workspace_gap"],
                    "workspace gap": ["interface.workspace_gap"],
                    "round": ["decorations.windowShape.cornerRadius", "appearance.fakeScreenRounding", "bar.floatRadius", "bar.widgetRadius", "dock.radius", "dock.topRadius"],
                    "corner": ["decorations.windowShape.cornerRadius", "appearance.fakeScreenRounding", "bar.floatRadius", "bar.widgetRadius", "dock.radius", "dock.topRadius", "bar.cornerStyle", "dock.cornerStyle"],
                    "radius": ["decorations.windowShape.cornerRadius", "appearance.fakeScreenRounding", "bar.floatRadius", "bar.widgetRadius", "dock.radius", "dock.topRadius"],
                    "blur": ["decorations.windowBlur.enable", "decorations.windowBlur.strength", "appearance.transparency.enable"],
                    "opacity": ["bar.backgroundOpacity", "bar.widgetOpacity", "appearance.transparency.backgroundTransparency", "appearance.transparency.contentTransparency", "dock.backgroundOpacity"],
                    "anim": ["decorations.animations.enabled"],
                    "animation": ["decorations.animations.enabled"],
                    "shadow": ["decorations.windowShadow.enable", "decorations.windowShadow.range", "decorations.windowShadow.renderPower", "bar.floatStyleShadow"],
                    "dock position": ["dock.position"],
                    "bar position": ["bar.bottom", "bar.vertical"],
                    "wallpaper": ["background.wallpaperPath", "background.slideshow.enable", "background.slideshow.folder"],
                    "slideshow": ["background.slideshow.enable", "background.slideshow.folder", "background.slideshow.intervalMinutes"],
                    "theme": ["appearance.palette.type", "appearance.palette.accentColor", "appearance.themeSchedule.mode"],
                    "color": ["appearance.palette.accentColor", "appearance.palette.type"],
                    "font": ["appearance.fonts.main", "appearance.fonts.monospace", "appearance.fonts.title"],
                    "cursor": ["cursor.shakeMode", "cursor.shakeZoomFactor", "cursor.shakeGrowFactor"],
                    "hotkey": ["bar.hotCorners.trigger", "bar.hotCorners.animationEnabled"],
                    "hotcorner": ["bar.hotCorners.trigger", "bar.hotCorners.animationEnabled"],
                    "overview": ["interface.workspace_gap", "interface.scrollOverviewWorkspaceGap"],
                };
        
                // Collect keyword matches
                const keywordMatches = [];
                for (const [keyword, paths] of Object.entries(keywordMap)) {
                    if (qWords.every(w => keyword.includes(w))) {
                        for (const p of paths) {
                            let found = deepPaths.find(d => d.path === p);
                            if (!found) {
                                const parts = p.split(".");
                                let prefix = "";
                                for (let i = 0; i < parts.length - 1; i++) {
                                    prefix += parts[i] + ".";
                                }
                                found = deepPaths.find(d => d.path === prefix) || { path: p, name: parts[parts.length - 1] + ": (hyprland)", isSection: false };
                            }
                            if (found) keywordMatches.push(found);
                        }
                    }
                }

                // Merge deepMatches + keywordMatches, then GROUP BY PARENT SECTION
                const allMatches = [...deepMatches, ...keywordMatches];
                const seen = new Set();
                const uniqueMatches = allMatches.filter(m => {
                    if (seen.has(m.path)) return false;
                    seen.add(m.path);
                    return true;
                });

                // Group by parent section (first part of path)
                const sectionGroups = {};
                for (const m of uniqueMatches) {
                    const parent = m.path.split(".")[0]; // e.g., "decorations", "appearance", "bar", "background"
                    if (!sectionGroups[parent]) sectionGroups[parent] = [];
                    sectionGroups[parent].push(m);
                }

                // Show ONE result per parent section (if not already shown from settingsMap)
                for (const parent of Object.keys(sectionGroups).slice(0, 8)) {
                    if (shownParents.has(parent)) continue;
                    shownParents.add(parent);
                    const pageMap = {
                        "bar": "BarConfig.qml",
                        "dock": "DockConfig.qml",
                        "interface": "InterfaceConfig.qml",
                        "appearance": "InterfaceConfig.qml",
                        "background": "BackgroundConfig.qml",
                        "decorations": "DecorationsConfig.qml",
                        "display": "DisplayConfig.qml",
                        "layouts": "LayoutsConfig.qml",
                        "keyboard": "KeyboardConfig.qml",
                        "mouse": "MouseConfig.qml",
                        "power": "PowerConfig.qml",
                        "wifi": "WifiConfig.qml",
                        "bluetooth": "BluetoothConfig.qml",
                        "quick": "QuickConfig.qml",
                        "services": "ServicesConfig.qml",
                        "manage": "ManageAppsConfig.qml",
                    };
                    const matchedPage = pageMap[parent] || parent + "Config.qml";
                    const count = sectionGroups[parent].length;
                    allSectionItems.push({
                        kind: "action",
                        name: "Open settings \u2192 " + parent.charAt(0).toUpperCase() + parent.slice(1) + " (" + count + " matches)",
                        action: "settings_open:" + matchedPage + "|" + parent,
                        iconKey: "settings",
                        category: "Settings"
                    });
                }

                if (allSectionItems.length) {
                    A(allSectionItems, "SETTINGS");
                }

        A([
            { kind: "action", name: "Search the Web for \u201c" + q + "\u201d", action: "web:" + q, iconKey: "web", category: "Search" }
        ], "SEARCH");
    }

    function _buildSearchMode(items, disp, q, ql) {
        if (!ql && root.nowPlayingText.length > 0) {
            root._addItems(items, disp, [{ kind: "media", name: root.nowPlayingText, category: root.nowPlayingStatus === "Playing" ? "Now playing" : "Paused" }], "NOW PLAYING");
        }
        if (!ql) return;
        // Each section is isolated: if one throws, the rest still show and the error reaches `qs log`.
        const safe = (name, fn) => {
            try { fn(); } catch (err) { console.warn("[Spotlight] search section '" + name + "' failed:", err); }
        };
        safe("primary", () => root._searchPrimary(items, disp, q, ql));
        safe("settings", () => root._searchSettings(items, disp, q, ql));
        // Assistant entry point (shown when the query is not already an AI prompt)
        safe("ask", () => {
            if (root._aiResultItems().length === 0)
                root._addItems(items, disp, [{ kind: "action", name: "Ask Hermes about \u201c" + q + "\u201d", action: "askai:" + q, iconKey: "ai", category: "Ask" }], "ASK");
        });
        safe("files", () => {
            if (root.fileItems.length) root._addItems(items, disp, root._fileRows(root.sortFileResults(root.fileItems, q)), "FILES");
        });
        safe("info", () => root._searchInfo(items, disp, q, ql));
        safe("actions", () => root._searchActions(items, disp, q, ql));
        safe("tophit", () => root._promoteTopHit(items, disp));
        safe("volume", () => {
            if (!/^(vol|volu|volum|volume|som)$/.test(ql)) return;
            disp.unshift({ kind: "volume" });                    // display-only card, pinned on top
            disp.forEach((d, i) => { if (d._idx !== undefined) d._dispIdx = i; });
        });
        safe("brightness", () => {
            if (!/^(bri|brig|brigh|bright|brightn|brightne|brightnes|brightness|bril|brilh|brilho)$/.test(ql)) return;
            disp.unshift({ kind: "brightness" });
            disp.forEach((d, i) => { if (d._idx !== undefined) d._dispIdx = i; });
        });
        safe("mic", () => {
            if (/^(mic|microf|microfo|microfon|microfone|microp|microph|micropho|microphon|microphone)$/.test(ql)) root._pinCard(disp, "mic");
        });
        safe("night", () => {
            if (/^(noi|noit|noite|nig|nigh|night)$/.test(ql)) root._pinCard(disp, "night");
        });
        safe("lamp", () => {
            if (/^(luz|l[a\u00e2]mpada|lampada|lamp)$/.test(ql)) root._pinCard(disp, "lamp");
        });
        safe("power", () => {
            if (/^(ener|energ|energi|energia|power)$/.test(ql)) root._pinCard(disp, "power");
        });
        safe("qr", () => {
            if (/^\s*qr\s+\S/i.test(q) || /^wifi\s+qr$/.test(ql)) root._pinCard(disp, "qr");
        });
    }

    // Moves the best match to a "TOP HIT" section at the very top (macOS-style).
    // Skipped when an AI row is present, so Enter keeps sending the question to Hermes.
    function _promoteTopHit(items, disp) {
        if (items.some(i => i.isAi)) return;
        let hit = null;
        for (const it of items) {
            const a = it.action || "";
            if (it.kind === "info" || it.kind === "media") continue;
            if (a.indexOf("web:") === 0 || a.indexOf("askai:") === 0) continue;
            hit = it; break;
        }
        if (!hit) return;
        const rest = disp.filter(d => d !== hit);
        const cleaned = rest.filter((d, i) => !(d.isHeader && (i + 1 >= rest.length || rest[i + 1].isHeader)));
        const newDisp = [{ isHeader: true, title: "TOP HIT" }, hit].concat(cleaned);
        const newItems = [hit].concat(items.filter(x => x !== hit));
        newItems.forEach((x, k) => { x._idx = k; });
        items.length = 0; newItems.forEach(x => items.push(x));
        disp.length = 0;
        newDisp.forEach(d => {
            disp.push(d);
            if (d._idx !== undefined) d._dispIdx = disp.length - 1;
        });
    }

    function buildResults() {
        const q = root.query.trim();
        const ql = q.toLowerCase();
        const items = [];
        const disp = [];
        const m = root.mode;
        const prevKey = root.itemKey(root.items[root.selectedIndex]);
        const sig = m + "|" + q;

        const bareLembrar = m === "search" && /^lembrar\s+\S/.test(ql)
            && !/^lembrar\s+\d+\s*(?:min|m|s|sec|seg|h)?\s+\S/.test(ql);
        const netWord = (m === "search" && root.netPassFor === "") ? root._netWordOf(ql) : null;
        const extraWord = (m === "search" && root.netPassFor === "") ? root._extraWordOf(ql) : null;

        if (root.netPassFor !== "") root._buildPasswordPrompt(items, disp);
        else if (root.renameFor !== "") root._buildRenamePrompt(items, disp);
        else if (root.fileActFor) root._buildFileActions(items, disp);
        else if (extraWord && extraWord.kind === "kill") root._buildKillMode(items, disp, extraWord.filter);
        else if (extraWord && extraWord.kind === "usb") root._buildUsbMode(items, disp, extraWord.filter);
        else if (extraWord && extraWord.kind === "keys") root._buildKeysMode(items, disp, extraWord.filter);
        else if (ql.startsWith("/")) root._buildSlashMode(items, disp, q, ql);
        else if (bareLembrar) root._buildSlashMode(items, disp, "/" + q, "/" + ql);
        else if (netWord && netWord.kind === "wifi") root._buildWifiMode(items, disp, netWord.filter);
        else if (netWord && netWord.kind === "bluetooth") root._buildBluetoothMode(items, disp, netWord.filter);
        else switch (m) {
            case "apps":      root._buildAppsMode(items, disp, q, ql); break;
            case "files":     root._buildFilesMode(items, disp, ql); break;
            case "clipboard": root._buildClipboardMode(items, disp); break;
            case "windows":   root._buildWindowsMode(items, disp, ql); break;
            case "wifi":      root._buildWifiMode(items, disp, ql); break;
            case "bluetooth": root._buildBluetoothMode(items, disp, ql); break;
            case "menu":      root._buildMenuMode(items, disp, q, ql); break;
            case "kill":      root._buildKillMode(items, disp, ql); break;
            case "usb":       root._buildUsbMode(items, disp, ql); break;
            case "keys":      root._buildKeysMode(items, disp, ql); break;
            case "actions":   root._buildActionsMode(items, disp); break;
            default:          root._buildSearchMode(items, disp, q, ql);
        }

        root.items = items;
        root.results = disp;
        let idx = 0;
        if (sig === root._buildSig && prevKey && root._userNavigated) {
            const f = items.findIndex(i => root.itemKey(i) === prevKey);
            if (f >= 0) idx = f;
        }
        root._buildSig = sig;
        root.selectedIndex = idx;
        if (idx === 0) {
            if (resultList) resultList.positionViewAtBeginning();
            if (resultGrid) resultGrid.positionViewAtBeginning();
        }
    }

    function scheduleRebuild() { _rebuildDeb.restart(); }

    function setMode(m) {
        root.mode = m;
        root.selectedIndex = 0;
        if (m === "files") { root.browseDir = ""; root.runRecents(); }
        if (m === "clipboard") root.runClip();
        if (m === "windows") _windows.running = true;
        if (m === "wifi") root.wifiScan();
        if (m === "bluetooth") root.btScan();
        if (m === "kill") root.procScan();
        if (m === "usb") root.usbScan();
        if (m === "keys") root.keysScan();
        if (m === "menu" || m === "wifi" || m === "bluetooth" || m === "kill" || m === "usb" || m === "keys") root.circlesLocked = true;   // locked: typing filters the list instead of leaving the mode
        if (m === "menu") root.menuReset();
        root.scheduleRebuild();
    }

    function animateRail(target) {
        _railAnim.stop()
        _railAnim.from = root.railProgress
        _railAnim.to = target
        _railAnim.duration = Math.max(100, Math.round(620 * Math.abs(target - root.railProgress)))
        _railAnim.start()
    }

    // =====================================================================
    //  NAVIGATION AND ITEM ACTIVATION
    // =====================================================================
    function moveSelection(delta) {
        if (root.items.length === 0) return;
        root._userNavigated = true;
        root.selectedIndex = (root.selectedIndex + delta + root.items.length) % root.items.length;
        const it = root.items[root.selectedIndex];
        if (resultList && resultList.visible) {
            resultList.positionViewAtIndex(it._dispIdx, ListView.Contain);
        } else if (resultGrid && resultGrid.visible) {
            resultGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
        }
    }

    function submit(event) {
        const sel = root.selectedItem;
        const isFile = !!sel && sel.kind === "file" && !!sel.path;
        const ctrl = !!(event.modifiers & Qt.ControlModifier);
        const shift = !!(event.modifiers & Qt.ShiftModifier);
        if (shift && !ctrl && isFile) {                          // Shift+Enter on a file → actions panel (same as Shift+click)
            root.fileActOpen(sel);
            event.accepted = true;
            return;
        }
        root.openSelected(shift || (ctrl && isFile));            // Ctrl+Enter on a file → its folder
        event.accepted = true;
    }

    // Search field shortcuts. Returns true if the key was handled.
    function handleSearchKey(event, hasSelection) {
        if (root.volCardShown && !(event.modifiers & Qt.ControlModifier)
                && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
            const step = (event.modifiers & Qt.ShiftModifier) ? 0.01 : 0.05;
            root.volSet(root.volLevel + (event.key === Qt.Key_Right ? step : -step));
            return true;
        }
        if (root.brightCardShown && !(event.modifiers & Qt.ControlModifier)
                && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
            const bstep = (event.modifiers & Qt.ShiftModifier) ? 0.01 : 0.05;
            root.brightSet(root.brightLevel + (event.key === Qt.Key_Right ? bstep : -bstep));
            return true;
        }
        if (!(event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
            const dir = event.key === Qt.Key_Right ? 1 : -1;
            const fine = (event.modifiers & Qt.ShiftModifier) ? 0.01 : 0.05;
            if (root.micCardShown) { root.micSet(root.micLevel + dir * fine); return true; }
            if (root.nightCardShown) { root.nightSet(root.nightLevel + dir * fine); return true; }
            if (root.lampCardShown) { root.lampSet(root.lampLevel + dir * fine); return true; }
            if (root.powerCardShown) { root.ppCycle(dir); return true; }
        }
        if (event.key === Qt.Key_Backspace && root.query === "" && root.mode === "menu") {
            if (!root.menuBack()) root.setMode("search");
            return true;
        }
        if (event.key === Qt.Key_Backspace && root.query === "" && (root.mode === "wifi" || root.mode === "bluetooth" || root.mode === "kill" || root.mode === "usb" || root.mode === "keys")) {
            root.setMode("search");
            return true;
        }
        if (event.key === Qt.Key_Backspace && root.query === ""
                && root.mode === "files" && root.browseDir !== "" && root.browseDir !== "/") {
            root.browseUp();
            return true;
        }
        if (!(event.modifiers & Qt.ControlModifier)) return false;
        switch (event.key) {
            case Qt.Key_1: root.setMode("apps"); return true;
            case Qt.Key_2: root.setMode("files"); return true;
            case Qt.Key_3: root.setMode("actions"); return true;
            case Qt.Key_4: root.setMode("clipboard"); return true;
            case Qt.Key_5: root.openSettingsApp(); return true;
            case Qt.Key_C:
                if (!hasSelection && root.selectedItem && root.selectedItem.kind === "file") {
                    root.copyText(root.selectedItem.path);
                    spotlightController.spotlightOpen = false;
                    return true;
                }
                return false;
            case Qt.Key_Left:
            case Qt.Key_Right:
            case Qt.Key_Space:
                if (root.selectedItem && root.selectedItem.kind === "media") {
                    root.mediaControl(event.key === Qt.Key_Left ? "previous"
                                      : event.key === Qt.Key_Right ? "next" : "play-pause");
                    return true;
                }
                return false;
            case Qt.Key_P:
                if (root.mode === "clipboard" && root.selectedItem && root.selectedItem.kind === "clip") {
                    root.toggleClipPin(root.selectedItem);
                    return true;
                }
                return false;
            case Qt.Key_R:
                if (root.aiHistory.length > 0 && root._lastAiQuery) {
                    const p = root._lastAiQuery;
                    root._lastAiQuery = "";
                    root.runHermes(p);
                    return true;
                }
                return false;
        }
        return false;
    }

    function openSelected(alt) {
        if (root.renameFor !== "") { root.renameSubmit(); return; }
        if (root.netPassFor !== "") { root.wifiSubmitPassword(); return; }
        const queryText = root.query.trim();
        if (queryText.startsWith(">")) {
            const command = queryText.slice(1).trim();
            if (command.length > 0) root.runInTerminal(command);
            return;
        }
        if (root.mode === "menu" && !queryText.startsWith("/")) {
            const msel = root.items[root.selectedIndex];
            if (msel && !root._activate(msel, alt)) spotlightController.spotlightOpen = false;
            return;
        }
        const aiPrompt = root.aiPromptFor(queryText);
        const sel = root.items[root.selectedIndex];
        const aiOk = !(queryText.startsWith("/") && !/^\/ai\s/i.test(queryText));
        if (aiPrompt && aiOk && (!sel || sel.isAi) && !root.aiLoading && root._lastAiQuery !== aiPrompt) {
            _aiDeb.stop();
            root.runHermes(aiPrompt);
            return;
        }
        if (!sel) return;
        const keepOpen = root._activate(sel, alt);
        if (!keepOpen) spotlightController.spotlightOpen = false;
    }

    // Runs the item; returns true if Spotlight should stay open.
    function _activate(e, alt) {
        switch (e.kind) {
            case "app":
                root.recordUsage("app:" + e.exec);
                root.launchOrFocus(e, alt);
                return false;
            case "file":
                return root._activateFile(e, alt);
            case "proc":
                if (/^\d+$/.test(String(e.pid))) {
                    const sig = alt ? "KILL" : "TERM";
                    spotlightController.run("kill -" + sig + " " + e.pid + " 2>/dev/null; notify-send 'Spotlight' 'SIG" + sig + " sent to PID " + e.pid + "'");
                }
                return false;
            case "clip":
                if (e.pinned && e.pinPath) {
                    const pq = root.shellQuote(e.pinPath);
                    spotlightController.run((e.isImage && e.pinMime)
                        ? "wl-copy --type " + root.shellQuote(e.pinMime) + " < " + pq + " 2>/dev/null || true"
                        : "wl-copy < " + pq + " 2>/dev/null || true");
                } else if (/^\d+$/.test(e.id || "")) {
                    spotlightController.run("cliphist decode " + e.id + " | wl-copy 2>/dev/null || true");
                }
                return false;
            case "calc":
            case "emoji":
                root.copyText(e.raw);
                return false;
            case "media":
                root.mediaControl("play-pause");
                return true;
            case "info":
                if (e.isAi) {
                    if (!root.aiLoading && root.aiText) root.copyText(root.aiText);
                    return true;
                }
                if (e.name && e.name !== "Thinking…") root.copyText(e.name);
                return false;
            case "window":
                root.focusWindowReliably({ address: e.address, cls: e.category || "" }, e.name);
                return false;
            case "wifi":
                return root._activateWifi(e, alt);
            case "bt":
                return root._activateBt(e, alt);
            case "kproc":
                return root._activateProc(e, alt);
            case "usb":
                return root._activateUsb(e, alt);
            case "fact":
                return root._activateFileAct(e);
            case "fapp":
                return root._activateFileApp(e);
            case "key":
                return root._activateKey(e);
            case "menu":
                return root._activateMenu(e);
            case "action":
                return root._activateAction(e);
            case "cmd":
                return root._activateCmd(e);
        }
        return false;
    }

    function _activateFile(e, alt) {
        root.recordUsage("file:" + e.path);
        if (root.mode === "files" && root.query.trim() === "" && e.isDirectory && !alt) {
            root.browseDir = e.path;
            root.selectedIndex = 0;
            root.runRecents();
            return true;
        }
        if (alt) {
            const i = e.path.lastIndexOf("/");
            root.xdgOpen(i > 0 ? e.path.slice(0, i) : "/");
        } else {
            root.xdgOpen(e.path);
        }
        return false;
    }

    function _activateAction(e) {
        const a = e.action;
        if (a === "shell") { spotlightController.run(e.cmd); return false; }
        if (a.startsWith("open:")) { root.openUrl(a.slice(5)); return false; }
        if (a.startsWith("web:")) { root.openUrl("https://www.google.com/search?q=" + encodeURIComponent(a.slice(4))); return false; }
        if (a.startsWith("filesearch:")) {
            root.circlesLocked = true;
            root.setMode("files");
            root.runFd();
            return true;
        }
        if (a.startsWith("askai:")) {
            root.runHermes(a.slice(6));
            return true;
        }
        if (a.startsWith("spotifyplay:")) {
            spotlightController.run(
                "export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}; " +
                "export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}; " +
                "pgrep -x spotify >/dev/null || (setsid spotify-launcher </dev/null >/dev/null 2>&1 &); " +
                "~/.local/bin/spotify-play " + root.shellQuote(a.slice(12)) + " >> /tmp/spotify-play.log 2>&1"
            );
            return false;
        }
        if (a.startsWith("realtimer:")) {
            const parts = a.slice(10).split(":");
            const secs = parts[0];
            const label = parts.slice(1).join(":");
            root.startTimer(secs, label || (secs + "s"));
            return false;
        }
        if (a.startsWith("localreminder:")) {
            const parts = a.slice(14).split(":");
            const secs = parts[0];
            const msg = parts.slice(1).join(":");
            root.scheduleLocalReminder(secs, msg || (secs + "s"));
            return false;
        }
        if (a === "addtodo:") { root.addTodoFromItem(e); return false; }
        if (a === "addevent:") {
            if (!e.evText || !e.evDate) return true;
            _addEvent.title = e.evText;
            _addEvent.command = ["python3", Quickshell.shellPath("scripts/calendar/eds-add-event.py"),
                                e.evText, e.evDate, e.evTime, String(e.evDuration)];
            _addEvent.running = true;
            if (e.evRemind && e.evRemindMs > Date.now()) root.scheduleReminder(e.evRemind, e.evText);
            return false;
        }
        if (a.startsWith("action:")) {
            const sub = a.slice(7);
            if (sub === "timer") root.startTimer(300, "5 min");
            else spotlightController.requestAction(a);
            return false;
        }
        if (a === "clipboard:clear") { root.clearClipboard(); return true; }
        if (a.startsWith("settings_open:")) {
            const pagePart = a.slice("settings_open:".length);
            // Format: "PageConfig.qml|sectionHint" or just "PageConfig.qml"
            const [page, sectionHint] = pagePart.split("|");
            // Launch settings app with QS_SETTINGS_PAGE env var to open specific page
            spotlightController.run(
                "QS_SETTINGS_PAGE=" + page + 
                (sectionHint ? " QS_SETTINGS_SECTION=" + sectionHint : "") + 
                " qs -p " + Quickshell.shellPath("settings.qml") + " --no-duplicate"
            );
            return false;
        }
        spotlightController.requestAction(a);
        return false;
    }

    function _beginScreenshotSelect(mode, lang, hint) {
        root._ocrMode = mode;
        if (lang !== undefined) root._ocrLang = lang;
        root._screenshotSelecting = true;
        root.aiText = hint;
        _screenshotDeb.useSelectArea = true;
        _screenshotDeb.restart();
    }

    function _activateCmd(e) {
        const a = e.action;
        if (a === "ocrtr:") {
            // /translate -> Portuguese | /translate en -> English, etc.
            root._beginScreenshotSelect("translate",
                root.query.replace(/^\/(?:translate|traduzir)\s*/i, "").trim().toLowerCase() || "pt",
                "📸 Select the text to translate…");
            return true;
        }
        if (a === "sum:") {
            const arg = root.query.replace(/^\/sum\s*/i, "").trim();
            if (!arg) return true;
            if (root.looksLikeUrl(arg) || /^https?:\/\//i.test(arg) || /^www\./i.test(arg)) {
                root.aiText = "🌐 Downloading…";
                spotlightActions.fetchPage(/^https?:\/\//i.test(arg) ? arg : "https://" + arg);
            } else {
                root.aiText = "📄 Reading…";
                spotlightActions.summarizePdf(arg);
            }
            return true;
        }
        if (a.startsWith("lembrar:")) {
            const reminderText = root.query.replace(/^\/lembrar\s*/i, "").trim();
            if (!reminderText) {
                searchField.text = "/lembrar ";
                searchField.cursorPosition = searchField.text.length;
                searchField.forceActiveFocus();
                return true;
            }
            // Parse time from text and use local timer (like TimerService)
            const parsed = root.parseTodoInput(reminderText);
            if (parsed.text && parsed.remindMs > Date.now()) {
                const seconds = Math.round((parsed.remindMs - Date.now()) / 1000);
                root.scheduleLocalReminder(seconds, parsed.text);
            } else if (parsed.text) {
                // No valid future time, just add to todo
                root.addTodoFromItem({ todoText: parsed.text, todoDue: parsed.dueStr, todoRemind: parsed.remindAt, todoRemindMs: parsed.remindMs });
            }
            return true;
        }
        if (a.startsWith("mode:")) {
            searchField.text = "";
            root.query = "";
            root.setMode(a.slice(5));
            return true;
        }
        if (a.startsWith("sys:")) { spotlightController.requestAction(a.slice(4)); return false; }
        if (a === "emoji:") {
            const em = spotlightApps.apps.find(x => x.name.toLowerCase().indexOf("emoji") !== -1);
            if (em) spotlightApps.launch(em.exec);
            else spotlightController.run("rofimoji 2>/dev/null || wtype 2>/dev/null || true");
            return false;
        }
        if (a === "colorpick:") { spotlightController.run("hyprpicker -a 2>/dev/null || true"); return false; }
        if (a.startsWith("ipc:")) {
            const parts = a.split(":");
            spotlightController.run("qs -c ii ipc call " + parts[1] + " " + parts[2]);
            return false;
        }
        if (a === "ai-new:") {
            root.aiHistory = [];
            root.clearAi();
            searchField.text = "";
            root.query = "";
            root.scheduleRebuild();
            searchField.forceActiveFocus();
            return true;
        }
        if (a === "web:" || a === "maps:" || a === "calc:" || a === "search:" || a === "ai:" || a === "todo:" || a === "lembrar:" || a === "timer:") {
            searchField.text = e.name + " ";
            searchField.cursorPosition = searchField.text.length;
            searchField.forceActiveFocus();
            return true;
        }
        return false;
    }

    // =====================================================================
    //  REACTIONS / CONNECTIONS
    // =====================================================================
    onSelectedKeyChanged: _previewDeb.restart()
    onCirclesVisibleChanged: root.animateRail(circlesVisible ? 1.0 : 0.0)

    Connections {
        target: spotlightActions
        function onScreenshotOcrReady(ocrText) {
            root._screenshotSelecting = false;
            const mode = root._ocrMode;
            root._ocrMode = "analyze";          // keeps the mode from "sticking"

            if (!ocrText || (ocrText === "Nenhuma imagem capturada" || ocrText === "No image captured")) {
                root.aiFail("❌ OCR returned no text (empty screen?)");
                return;
            }
            if (mode === "translate") {
                root.runInternalAi("Translate the following text to " + root.langName(root._ocrLang)
                    + ". Reply with ONLY the translation, without quotes or explanations. Preserve line breaks.\n\n"
                    + ocrText.slice(0, 3000));
                return;
            }
            root.runInternalAi("Analyze this text extracted from a screenshot and reply helpfully:\n\n" + ocrText.slice(0, 3000));
        }
        function onPageReady(page) {
            const focus = root._resumeFocus;
            root._resumeFocus = "";
            if (!page || !page.ok) {
                root.aiFail("❌ " + ((page && page.error) || "Couldn't read the link"));
                return;
            }
            root.runInternalAi(root.buildResumePrompt(page, focus), "🌐 Summarize: " + (page.title || page.url));
        }
        function onPdfReady(text) {
            if (!text) { root.aiFail("❌ Couldn't read the PDF"); return; }
            root.runInternalAi("Summarize this PDF concisely:\n\n" + text.slice(0, 6000));
        }
        function onBriefingReady(text) {
            if (!text) {
                root.aiText = "❌ Briefing unavailable";
                root.rebuildIfShown();
                return;
            }
            root.runInternalAi("Format this morning briefing nicely:\n\n" + text);
        }
        function onHistoryReady(history) {
            if (Array.isArray(history) && history.length > 0) root.aiHistory = history;
        }
    }

    Connections {
        target: spotlightController
        function onSpotlightOpenChanged() {
            if (!spotlightController.spotlightOpen) {
                root._opened = false;
                closeAnim.start();
                return;
            }
            root._userNavigated = false;
            root._opened = true;
            root._shown = true;
            root.query = "";
            root.mode = "search";
            root.selectedIndex = 0;
            searchField.text = "";
            root.circlesVisible = false;
            root.circlesLocked = false;
            root.netPassFor = "";
            root.netPass = "";
            root._netWordShown = "";
            root._extraShown = "";
            root._qrWanted = "";
            root.fileActFor = null;
            root.fileActStage = "actions";
            root.fileActPending = "";
            root.renameFor = "";
            root.clearAi();
            if (!root.aiPersistentHistory) root.aiHistory = [];
            else spotlightActions.loadHistory();
            root.passText = "";
            root._passKey = "";
            root.timeText = "";
            root._timeKey = "";
            root.procItems = [];
            root._procKey = "";
            root.devResult = { q: "", text: "", label: "" };
            root._devQ = "";
            root.quoteResult = { q: "", loading: false, text: "", sub: "", raw: "" };
            root._quoteQ = "";
            root._buildSig = "";
            root._previewKeyShown = "";
            root.previewKind = "";
            root.previewPath = "";
            root._lastContentQuery = "";
            root.scheduleRebuild();
            if (root._pendingMode !== "") {
                root.setMode(root._pendingMode);
                root._pendingMode = "";
            }
            openAnim.start();
            Qt.callLater(() => searchField.forceActiveFocus());
        }
    }

    Connections {
        target: spotlightApps
        ignoreUnknownSignals: true
        function onReadyChanged() {
            if (spotlightController.spotlightOpen) root.scheduleRebuild();
        }
    }

    IpcHandler {
        target: "spotlightMode"
        function openMode(mode: string): void {
            if (spotlightController.spotlightOpen) {
                if (root.mode === mode) spotlightController.spotlightOpen = false;
                else root.setMode(mode);
            } else {
                root._pendingMode = mode;
                spotlightController.spotlightOpen = true;
            }
        }
    }

    IpcHandler {
        target: "todoReminder"
        function fire(text: string): void {
            Quickshell.execDetached(["notify-send", "Reminder", text, "-a", "Shell"]);
            Quickshell.execDetached(["bash", "-c",
                "for f in /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga " +
                "/usr/share/sounds/*/stereo/alarm-clock-elapsed.oga " +
                "/usr/share/sounds/*/stereo/complete.oga; do " +
                "[ -f \"$f\" ] || continue; " +
                "pw-play \"$f\" || paplay \"$f\" || ffplay -nodisp -autoexit -loglevel quiet \"$f\"; " +
                "break; done >> /tmp/todo-reminder.log 2>&1"
            ]);
        }
    }

    // =====================================================================
    //  ANIMATIONS
    // =====================================================================
    NumberAnimation {
        id: _railAnim
        target: root
        property: "railProgress"
        duration: 620
        easing.type: Easing.Linear
    }

    SequentialAnimation {
        id: openAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "panelScale"; to: 1.0; duration: root.animSlow; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "panelYOffset"; to: 0; duration: root.animSlow; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "panelOpacity"; to: 1.0; duration: root.animMed; easing.type: Easing.OutQuad }
        }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "panelScale"; to: 0.98; duration: root.animMed; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "panelYOffset"; to: 8; duration: root.animMed; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "panelOpacity"; to: 0.0; duration: root.animMed; easing.type: Easing.InQuad }
        }
        ScriptAction { script: {
            root._shown = false; root.circlesVisible = false;
        } }
    }

    // =====================================================================
    //  INTERFACE
    // =====================================================================
    MouseArea {
        anchors.fill: parent
        enabled: !root._screenshotSelecting
        onClicked: spotlightController.spotlightOpen = false
    }

    Item {
        id: outerWrap
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(root.screen.height * 0.22) + root.panelYOffset
        width: root.panelWidth
        height: root.panelTotalH
        transformOrigin: Item.Top
        scale: root.panelScale
        opacity: root.panelOpacity

        Behavior on height { NumberAnimation { duration: root.animMed; easing.type: Easing.OutCubic } }

        // ---- "Glass" background
        Rectangle {
            id: panelChrome
            anchors.left: parent.left
            anchors.leftMargin: root.panelPad - root.bodyPad
            anchors.top: parent.top
            width: root.framed ? parent.width : morphSurface.mainWidth
            height: root.panelTotalH
            radius: root.framed ? root.panelRadius : 22
            Behavior on radius { NumberAnimation { duration: root.animMed; easing.type: Easing.OutCubic } }
            color: root.glassBg
            border.color: root.glassBorder
            border.width: 1
            z: 0
            Behavior on height { NumberAnimation { duration: root.animMed; easing.type: Easing.OutCubic } }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: panelChrome.radius - 1
                color: "transparent"
                border.color: root.glassHighlight
                border.width: 1
            }
            // Soft top sheen (frosted-glass look)
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: Math.min(parent.height - 2, 260)
                radius: panelChrome.radius - 1
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
                    GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.025) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                }
            }
        }

        // ---- Search bar
        Item {
            id: searchHeader
            anchors.left: parent.left
            anchors.leftMargin: root.panelPad
            anchors.top: parent.top
            anchors.topMargin: root.bodyPad
            width: parent.width - 2 * root.panelPad
            height: root.searchH
            z: 2

            MouseArea { anchors.fill: parent; z: -2 }

            SpotlightModeMorphSurface {
                id: morphSurface
                anchors.fill: parent
                railProgress: root.railProgress
                mainLeft: 0
                collapsedMainWidth: root.panelWidth - 2 * root.panelPad
                expandedMainWidth: root.panelWidth - 2 * root.panelPad - 5 * (root.circleSize + root.circlesGap)
                shapeCenterY: root.searchH / 2
                shapeHeight: root.searchH
                buttonDiameter: root.circleSize
                buttonGap: root.circlesGap
                blurEdgeInset: 2
                surfaceColor: "transparent"
                shadowColor: "transparent"
                z: -1
            }

            Item {
                id: searchInputContent
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: morphSurface.mainWidth
                clip: true

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 22
                    anchors.rightMargin: 16

                    Item {
                        id: searchIconWrap
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20; height: 20

                        Canvas {
                            anchors.fill: parent
                            property bool isSlash: root.slashMode
                            onIsSlashChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d"); ctx.reset()
                                ctx.lineWidth = 1.6; ctx.lineCap = "round"; ctx.lineJoin = "round"
                                if (root.slashMode) {
                                    ctx.strokeStyle = root.accent
                                    ctx.beginPath(); ctx.moveTo(6, 4); ctx.lineTo(14, 10); ctx.lineTo(6, 16); ctx.stroke()
                                } else {
                                    ctx.strokeStyle = root.sFgDim
                                    ctx.beginPath(); ctx.arc(8, 8, 6, 0, Math.PI * 2); ctx.stroke()
                                    ctx.beginPath(); ctx.moveTo(12.5, 12.5); ctx.lineTo(17, 17); ctx.stroke()
                                }
                            }
                        }
                    }

                    TextInput {
                        id: searchField
                        anchors.left: searchIconWrap.right; anchors.leftMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 28
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        color: root.sFg
                        font { family: root.fontDisplay; pixelSize: 24; weight: Font.Normal }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: root.netPassFor !== "" ? TextInput.Password : TextInput.Normal
                        selectByMouse: true; clip: true; cursorVisible: root._opened
                        focus: true
                        onActiveFocusChanged: { if (activeFocus) root.circlesLocked = false }
                        Keys.onUpPressed: (event) => { root.moveSelection(-1); event.accepted = true }
                        Keys.onDownPressed: (event) => { root.moveSelection(1); event.accepted = true }
                        Keys.onReturnPressed: (event) => root.submit(event)
                        Keys.onEnterPressed: (event) => root.submit(event)
                        Keys.onEscapePressed: (event) => {
                            if (root.renameFor !== "") { root.renameCancel(); event.accepted = true; return; }
                            if (root.fileActFor) { if (!root.fileActBack()) root.fileActClose(); event.accepted = true; return; }
                            if (root.netPassFor !== "") { root.wifiCancelPassword(); event.accepted = true; return; }
                            if (!root._screenshotSelecting) spotlightController.spotlightOpen = false;
                            event.accepted = true;
                        }
                        Keys.onTabPressed: (event) => { root.circlesVisible = !root.circlesVisible; event.accepted = true }
                        Keys.onPressed: (event) => {
                            if (root.handleSearchKey(event, searchField.selectedText !== "")) event.accepted = true;
                        }
                        onTextChanged: {
                            if (root.renameFor !== "") { root.renameText = text; return; }   // rename: keep it out of root.query
                            if (root.netPassFor !== "") { root.netPass = text; return; }   // password: keep it out of root.query
                            if (root.fileActFor) { root.fileActFor = null; root.fileActStage = "actions"; root.fileActPending = ""; }   // typing leaves the actions panel
                            root._userNavigated = false;
                            root.query = text;
                            if (text.length > 0 && !root.circlesLocked && root.mode !== "search") root.mode = "search";
                            root.scheduleRebuild();
                            _fdDeb.restart();
                            _sideEffectsDeb.restart();
                            root._netWordHook(text);
                            root._extraWordHook(text);
                            root._qrHook(text);
                            if (text.length > 0) root.circlesVisible = false
                        }
                    }

                    Text {
                        anchors.left: searchIconWrap.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        text: root.renameFor !== "" ? "New name"
                              : (root.netPassFor !== "" ? ("Password for \u201C" + root.netPassFor + "\u201D") : root.placeholderText)
                        font { family: root.fontDisplay; pixelSize: 24; weight: Font.Normal }
                        color: root.placeholderFg
                        visible: searchField.text.length === 0
                    }
                }
            }

            // ---- Round mode buttons
            Item {
                id: circlesContainer
                anchors.fill: parent
                visible: root.railProgress > 0.001
                z: 300

                Repeater {
                    model: [
                        { m: "apps",      tip: "Applications", icon: Quickshell.shellPath("assets/app-store.png") },
                        { m: "files",     tip: "Files",        icon: Quickshell.shellPath("assets/Finder.png") },
                        { m: "actions",   tip: "Actions",      icon: Quickshell.shellPath("assets/Shortcuts.png") },
                        { m: "clipboard", tip: "Clipboard",    icon: Quickshell.shellPath("assets/clipboard.png") },
                        { m: "config",    tip: "Settings",     icon: Quickshell.shellPath("assets/preferences-system.png") }
                    ]
                    delegate: Item {
                        id: circleBtn
                        width: root.circleSize; height: root.circleSize
                        property real growth: morphSurface.buttonGrowth(index)
                        property real iconAlpha: morphSurface.iconProgress(index)
                        property bool isActive: root.mode === modelData.m
                        property bool isHover: circleMA.containsMouse
                        x: morphSurface.buttonCenterX(index) - root.circleSize / 2
                        y: morphSurface.shapeCenterY - root.circleSize / 2
                        scale: growth
                        opacity: iconAlpha
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 2; radius: width / 2
                            color: root.glassBg; border.width: 1; border.color: root.glassBorder
                        }
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 4; radius: width / 2
                            color: "transparent"; border.width: 1
                            border.color: circleBtn.isActive ? root.white28 : circleBtn.isHover ? root.white14 : Qt.rgba(1, 1, 1, 0.0)
                            Behavior on border.color { ColorAnimation { duration: root.animMed } }
                        }
                        Image {
                            anchors.centerIn: parent
                            width: 34; height: 34
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                        Rectangle {
                            id: tipBox
                            anchors.top: parent.bottom; anchors.topMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tipText.implicitWidth + 24; height: 30; radius: 8
                            color: root.glassBg; border.color: root.glassBorder; border.width: 1
                            visible: circleBtn.isHover
                            opacity: circleBtn.isHover ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: root.animMed } }
                            Text {
                                id: tipText
                                anchors.centerIn: parent
                                text: modelData.tip
                                color: root.sFgDim
                                font { family: root.fontDisplay; pixelSize: 13 }
                            }
                        }
                        MouseArea {
                            id: circleMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.placeholderText = modelData.tip
                            onExited: root.placeholderText = "Search or Ask"
                            onClicked: {
                                // Settings opens the settings.qml app directly (instead of the internal "config" mode)
                                if (modelData.m === "config") {
                                    root.openSettingsApp()
                                    return
                                }
                                root.circlesLocked = true
                                root.circlesVisible = false
                                root.setMode(root.mode === modelData.m ? "search" : modelData.m)
                            }
                        }
                    }
                }
            }

            // ---- Drag to open/close the mode track
            MouseArea {
                id: dragZone
                anchors.right: searchHeader.right
                anchors.top: searchHeader.top
                anchors.bottom: searchHeader.bottom
                width: 60
                hoverEnabled: true
                cursorShape: Qt.SplitHCursor
                z: 50
                property real startMouseX: 0
                property real startProgress: 0
                property bool isDragging: false
                onPressed: (mouse) => {
                    startMouseX = mouse.x
                    startProgress = root.railProgress
                    isDragging = true
                    _railAnim.stop()
                }
                onPositionChanged: (mouse) => {
                    if (!isDragging) return
                    var maxDist = root.circleSize * 5 + root.circlesGap * 5
                    root.railProgress = Math.max(0, Math.min(1, startProgress + (mouse.x - startMouseX) / maxDist))
                }
                onReleased: (mouse) => {
                    if (!isDragging) return
                    isDragging = false
                    const open = root.railProgress > 0.25
                    root.circlesVisible = open
                    root.animateRail(open ? 1.0 : 0.0)
                }
            }

            // ---- Clear button
            Rectangle {
                id: clearBtn
                x: morphSurface.mainWidth - width - 16
                y: (searchHeader.height - height) / 2
                width: 20; height: 20; radius: 10
                z: 100
                color: clearMA.containsMouse ? root.white25 : "transparent"
                visible: root.query.length > 0
                Canvas {
                    anchors.centerIn: parent; width: 14; height: 14
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset()
                        ctx.strokeStyle = root.white85; ctx.lineWidth = 1.4
                        ctx.beginPath(); ctx.arc(width/2, height/2, width/2 - 1, 0, Math.PI * 2); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(width*0.35, height*0.35); ctx.lineTo(width*0.65, height*0.65)
                        ctx.moveTo(width*0.65, height*0.35); ctx.lineTo(width*0.35, height*0.65); ctx.stroke()
                    }
                }
                MouseArea { id: clearMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { searchField.text = ""; root.query = ""; root.scheduleRebuild(); searchField.forceActiveFocus() }
                }
            }
        }

        // ---- Button that opens/closes the modes
        Rectangle {
            id: modesToggle
            x: root.panelPad + morphSurface.mainWidth - width - 12
            y: root.bodyPad + (searchHeader.height - height) / 2
            width: 28; height: 28; radius: 14
            z: 120
            visible: root.query.length === 0
            color: modesToggleMA.containsMouse || root.circlesVisible ? root.white14 : "transparent"
            border.width: 1
            border.color: root.circlesVisible ? root.white28 : root.white12
            Canvas {
                anchors.centerIn: parent
                width: 14; height: 14
                rotation: root.circlesVisible ? 0 : 180
                Behavior on rotation { NumberAnimation { duration: root.animSlow; easing.type: Easing.OutCubic } }
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    ctx.strokeStyle = root.white90; ctx.lineWidth = 1.8
                    ctx.lineCap = "round"; ctx.lineJoin = "round"
                    ctx.beginPath(); ctx.moveTo(5, 3); ctx.lineTo(10, 7); ctx.lineTo(5, 11); ctx.stroke()
                }
            }
            MouseArea {
                id: modesToggleMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.circlesVisible = !root.circlesVisible
                    root.circlesLocked = true
                }
            }
        }

        // ---- Clear clipboard history button (Clipboard mode only)
        Rectangle {
            id: clipTrashBtn
            property bool armed: false
            // right below the arrow (right-aligned, on the "CLIPBOARD" header line)
            x: root.panelPad + morphSurface.mainWidth - width - 10
            y: root.bodyPad + searchHeader.height + root.listGap + 4 + (root.headerH - height) / 2
            width: 22; height: 22; radius: 6
            z: 120
            visible: root.mode === "clipboard" && root.clipItems.length > 0
            color: armed ? Qt.rgba(1, 0.27, 0.27, 0.35)
                 : clipTrashMA.containsMouse ? root.white14 : "transparent"
            border.width: 1
            border.color: armed ? Qt.rgba(1, 0.4, 0.4, 0.8) : root.white12
            Behavior on color { ColorAnimation { duration: root.animMed } }
            onVisibleChanged: armed = false
            onArmedChanged: trashIcon.requestPaint()

            Timer { id: armTimer; interval: 2500; onTriggered: clipTrashBtn.armed = false }

            Canvas {
                id: trashIcon
                anchors.centerIn: parent
                width: 14; height: 14; scale: 0.9
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    ctx.strokeStyle = clipTrashBtn.armed ? "#ff8080" : root.white90
                    ctx.lineWidth = 1.4; ctx.lineCap = "round"; ctx.lineJoin = "round"
                    ctx.beginPath(); ctx.moveTo(2, 3.5); ctx.lineTo(12, 3.5); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(5.5, 3.5); ctx.lineTo(5.5, 2); ctx.lineTo(8.5, 2); ctx.lineTo(8.5, 3.5); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(3.5, 3.5); ctx.lineTo(4.2, 12); ctx.lineTo(9.8, 12); ctx.lineTo(10.5, 3.5); ctx.stroke()
                }
            }
            MouseArea {
                id: clipTrashMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.placeholderText = clipTrashBtn.armed ? "Click again to confirm" : "Clear history (pinned items stay)"
                onExited: root.placeholderText = "Search or Ask"
                onClicked: {
                    if (clipTrashBtn.armed) {
                        armTimer.stop(); clipTrashBtn.armed = false
                        root.clearClipboard()
                        root.placeholderText = "Search or Ask"
                    } else {
                        clipTrashBtn.armed = true; armTimer.restart()
                        root.placeholderText = "Click again to confirm"
                    }
                    searchField.forceActiveFocus()
                }
            }
        }

        // ---- Results card
        Item {
            id: resultsCard
            anchors.top: searchHeader.bottom
            anchors.topMargin: root.listGap
            anchors.left: parent.left
            anchors.leftMargin: root.listPad
            anchors.right: parent.right
            anchors.rightMargin: root.listPad
            height: root.resultsHeight + (root.hasBody ? root.footerH : 0)
            visible: root.hasBody && height > 0
            z: 1
            clip: true
            Behavior on height { NumberAnimation { duration: root.animMed; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // System stats
                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: 24
                    Layout.leftMargin: 14; Layout.rightMargin: 14
                    visible: root.sysStatsText.length > 0 && root.query.length === 0 && root.mode === "search"
                    Text {
                        Layout.fillWidth: true
                        text: root.sysStatsText
                        color: root.sFgDim
                        font { family: root.fontText; pixelSize: 11 }
                        elide: Text.ElideRight
                    }
                }

                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true

                    ListView {
                        id: resultList
                        visible: root.mode !== "apps"
                        anchors.fill: parent
                        anchors.topMargin: 4
                        anchors.bottomMargin: 20   // hides the slack that would show a cut-off row
                        anchors.leftMargin: 0
                        anchors.rightMargin: 0
                        model: root.results
                        spacing: 0
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        reuseItems: true

                        ScrollBar.vertical: ScrollBar {
                            id: resultScrollBar
                            policy: resultList.contentHeight > resultList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            width: 8
                            contentItem: Rectangle {
                                implicitWidth: 6; radius: 3
                                color: root.white35
                                opacity: resultScrollBar.pressed ? 0.85 : 0.5
                                Behavior on opacity { NumberAnimation { duration: root.animMed } }
                            }
                            background: Rectangle { implicitWidth: 6; color: "transparent" }
                        }

                        delegate: Item {
                            id: dlg
                            required property var modelData
                            readonly property bool isPinned: modelData.kind === "clip" && modelData.pinned === true
                            readonly property bool isDanger: modelData.action === "clipboard:clear"
                            readonly property bool isHeader: modelData.isHeader === true
                            readonly property bool isWeather: modelData.kind === "weather"
                            readonly property bool isVolume: modelData.kind === "volume"
                            readonly property bool isBrightness: modelData.kind === "brightness"
                            readonly property bool isMic: modelData.kind === "mic"
                            readonly property bool isNight: modelData.kind === "night"
                            readonly property bool isLamp: modelData.kind === "lamp"
                            readonly property bool isPower: modelData.kind === "power"
                            readonly property bool isQr: modelData.kind === "qr"
                            readonly property bool isCard: isWeather || isVolume || isBrightness || isMic || isNight || isLamp || isPower || isQr
                            readonly property bool isClipImage: modelData.kind === "clip" && modelData.isImage === true && !!modelData.imagePath
                            readonly property bool isDraggedPin: isPinned && root.pinDragH === modelData.h
                            // Where a pinned row sits while another one is being dragged
                            readonly property real pinShiftY: {
                                if (!isPinned || root.pinDragH === "" || isDraggedPin) return 0;
                                const i = root.pinIndexOf(modelData.h), f = root.pinDragFrom, t = root.pinDragTarget;
                                if (f < t && i > f && i <= t) return -root.rowH;
                                if (f > t && i < f && i >= t) return root.rowH;
                                return 0;
                            }
                            z: isDraggedPin ? 20 : 0
                            transform: Translate {
                                y: dlg.isDraggedPin ? root.pinDragDelta : dlg.pinShiftY
                                Behavior on y { enabled: !dlg.isDraggedPin; NumberAnimation { duration: root.animMed; easing.type: Easing.OutCubic } }
                            }
                            width: resultList.width
                            height: isHeader ? root.headerH : (isWeather ? root.weatherH : (isPower ? root.powerH : (isQr ? root.qrH : ((isVolume || isBrightness || isMic || isNight || isLamp) ? root.volumeH : root.rowH))))
                            Text {
                                visible: isHeader
                                anchors.left: parent.left; anchors.leftMargin: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                                text: modelData.title || ""
                                font { family: root.fontDisplay; pixelSize: 12; weight: Font.DemiBold }
                                color: root.headerFg
                            }
                            Rectangle {
                                visible: !isHeader && !isCard
                                anchors.fill: parent; anchors.leftMargin: 3; anchors.rightMargin: 3
                                anchors.topMargin: 1; anchors.bottomMargin: 1
                                radius: 10
                                border.width: (!isDanger && root.selectedIndex === modelData._idx) ? 1 : 0
                                border.color: root.selectionBorder
                                color: {
                                    if (isDanger) return rowHover.containsMouse ? Qt.rgba(1, 0.27, 0.23, 0.20) : Qt.rgba(1, 0.27, 0.23, 0.10);
                                    if (root.selectedIndex === modelData._idx) return root.selectionBg;
                                    if (rowHover.containsMouse) return root.hoverBg;
                                    return "transparent";
                                }
                                Behavior on color { ColorAnimation { duration: root.animFast } }
                            }
                            RowLayout {
                                visible: !isHeader && !isCard
                                anchors.fill: parent; anchors.leftMargin: 16
                                anchors.rightMargin: modelData.kind === "media" ? 122 : (modelData.kind === "clip" ? 44 : 14)
                                spacing: 12
                                Image {
                                    visible: modelData.kind === "app"
                                    Layout.preferredWidth: root.iconSize; Layout.preferredHeight: root.iconSize; Layout.alignment: Qt.AlignVCenter
                                    source: modelData.icon || ""
                                    sourceSize { width: root.iconSize * 2; height: root.iconSize * 2 }
                                    asynchronous: true; smooth: true
                                }
                                Image {
                                    visible: isClipImage
                                    Layout.preferredWidth: 60; Layout.preferredHeight: 44; Layout.alignment: Qt.AlignVCenter
                                    source: visible ? ("file://" + modelData.imagePath) : ""
                                    sourceSize { width: 120; height: 88 }
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true; smooth: true; mipmap: true
                                    Rectangle { anchors.fill: parent; radius: 5; color: "transparent"; border.color: root.white18; border.width: 1 }
                                }
                                Item {
                                    visible: modelData.kind !== "app" && !isClipImage
                                    Layout.preferredWidth: root.iconSize; Layout.preferredHeight: root.iconSize; Layout.alignment: Qt.AlignVCenter
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 18; height: 18; radius: 5
                                        visible: !!modelData.swatch
                                        color: modelData.swatch || "transparent"
                                        border.color: Qt.rgba(1, 1, 1, 0.4); border.width: 1
                                    }
                                    Image {
                                        id: mediaArt
                                        anchors.fill: parent
                                        visible: modelData.kind === "media" && status === Image.Ready
                                        source: modelData.kind === "media" ? root.nowPlayingArt : ""
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: 96; sourceSize.height: 96
                                        asynchronous: true; smooth: true
                                        Rectangle { anchors.fill: parent; radius: 5; color: "transparent"; border.color: root.white18; border.width: 1 }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: modelData.kind === "media" && !mediaArt.visible
                                        text: "\u266A"; color: root.sFg; font.pixelSize: 18
                                    }
                                    SpotlightFileIcon {
                                        anchors.fill: parent
                                        visible: modelData.kind === "file"
                                        folder: modelData.isDirectory === true
                                    }
                                    Shape {
                                        id: rowGlyph
                                        readonly property string glyph: root.rowGlyphPath(modelData)
                                        anchors.centerIn: parent
                                        width: 24; height: 24
                                        scale: 20 / 24
                                        visible: glyph !== ""
                                        opacity: 0.85
                                        preferredRendererType: Shape.CurveRenderer
                                        antialiasing: true

                                        ShapePath {
                                            strokeColor: root.sFg
                                            strokeWidth: 2
                                            fillColor: "transparent"
                                            capStyle: ShapePath.RoundCap
                                            joinStyle: ShapePath.RoundJoin
                                            PathSvg { path: rowGlyph.glyph }
                                        }
                                    }
                                    SpotlightSearchIcon {
                                        anchors.centerIn: parent
                                        width: 20; height: 20
                                        visible: modelData.kind !== "cmd" && ((modelData.action || "").indexOf("web:") === 0 || modelData.category === "Site shortcut" || modelData.category === "Google Maps")
                                        color: root.sFg
                                        opacity: 0.8
                                    }
                                    SiriOrb {
                                        anchors.centerIn: parent
                                        size: 28
                                        visible: (modelData.action || "").indexOf("askai:") === 0
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 0; Layout.alignment: Qt.AlignVCenter
                                    Text {
                                        Layout.fillWidth: true; text: modelData.name || ""
                                        font { family: root.fontDisplay; pixelSize: 14; weight: Font.DemiBold }
                                        color: isDanger ? "#FF6961" : root.sFg
                                        elide: Text.ElideRight; maximumLineCount: 1
                                        wrapMode: modelData.kind === "info" ? Text.Wrap : Text.NoWrap
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        visible: !!modelData.category && modelData.category.length > 0
                                        text: modelData.category || ""
                                        font { family: root.fontText; pixelSize: 11 }
                                        color: root.sFgDim
                                        elide: Text.ElideRight; maximumLineCount: 1
                                    }
                                }
                            }
                            // Enter glyph on the selected row
                            Canvas {
                                visible: false && !isHeader && !isCard && root.selectedIndex === modelData._idx
                                         && modelData.kind !== "media" && modelData.kind !== "clip"
                                anchors.right: parent.right; anchors.rightMargin: 24
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16; height: 16
                                onVisibleChanged: if (visible) requestPaint()
                                Component.onCompleted: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.reset()
                                    ctx.strokeStyle = root.sFgDim
                                    ctx.lineWidth = 1.5; ctx.lineCap = "round"; ctx.lineJoin = "round"
                                    ctx.beginPath(); ctx.moveTo(13, 3); ctx.lineTo(13, 9.5); ctx.lineTo(3.5, 9.5); ctx.stroke()
                                    ctx.beginPath(); ctx.moveTo(6.5, 6.5); ctx.lineTo(3.5, 9.5); ctx.lineTo(6.5, 12.5); ctx.stroke()
                                }
                            }
                            MouseArea {
                                id: rowHover
                                visible: !isHeader && !isCard
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                hoverEnabled: true
                                preventStealing: root.pinDragH !== ""
                                pressAndHoldInterval: 750
                                cursorShape: dlg.isDraggedPin ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                                // A held pinned row is picked up; the others make room
                                onPressAndHold: (mouse) => {
                                    if (!dlg.isPinned || mouse.button !== Qt.LeftButton) return
                                    root.beginPinDrag(modelData.h, rowHover.mapToItem(resultList.contentItem, mouse.x, mouse.y).y)
                                }
                                onReleased: root.endPinDrag()
                                onCanceled: root.endPinDrag()

                                onPositionChanged: (mouse) => {
                                    if (dlg.isDraggedPin) {
                                        root.updatePinDrag(rowHover.mapToItem(resultList.contentItem, mouse.x, mouse.y).y)
                                        return
                                    }
                                    if (root.selectedIndex !== modelData._idx) {
                                        root._userNavigated = true
                                        root.selectedIndex = modelData._idx
                                    }
                                }
                                onClicked: (mouse) => {
                                    // A drag that just ended must not also run the row
                                    if (root.pinDragJustEnded) return
                                    root.selectedIndex = modelData._idx

                                    const ctrl = !!(mouse.modifiers & Qt.ControlModifier)
                                    const shift = !!(mouse.modifiers & Qt.ShiftModifier)
                                    const it = root.items[root.selectedIndex]
                                    const isFile = !!(it && it.kind === "file" && it.path)

                                    // Right click on a file → actions panel (like Shift + click); on other rows it does nothing
                                    if (mouse.button === Qt.RightButton) {
                                        if (isFile) root.fileActOpen(it)
                                        return
                                    }

                                    // Ctrl + Shift + click → copies the file path
                                    if (ctrl && shift) {
                                        if (isFile) {
                                            root.copyText(it.path)
                                            spotlightController.spotlightOpen = false
                                        }
                                        return
                                    }
                                    // Ctrl + click → opens the folder that contains the file
                                    if (ctrl) {
                                        if (isFile) root.openSelected(true)
                                        return
                                    }
                                    // Shift + click on a file → actions panel (open, open folder, open with, copy, rename, trash...)
                                    if (shift && isFile) {
                                        root.fileActOpen(it)
                                        return
                                    }
                                    // Shift + click on other rows → their alternate action | normal click → default action
                                    root.openSelected(shift)
                                }
                            }
                            // Media controls (SpotlightMediaControls.qml component)
                            SpotlightMediaControls {
                                visible: !isHeader && modelData.kind === "media"
                                z: 2
                                anchors.right: parent.right; anchors.rightMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                fg: root.sFg
                                playing: root.nowPlayingStatus === "Playing"
                                onAction: (cmd) => root.mediaControl(cmd)
                            }
                            // Pin / unpin button (clipboard rows)
                            Rectangle {
                                id: pinBtn
                                visible: !isHeader && modelData.kind === "clip"
                                         && (rowHover.containsMouse || pinMA.containsMouse || dlg.isPinned
                                             || root.selectedIndex === modelData._idx)
                                z: 3
                                anchors.right: parent.right; anchors.rightMargin: 20
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24; height: 24; radius: 6
                                color: pinMA.containsMouse ? root.white14 : "transparent"
                                Canvas {
                                    id: pinIcon
                                    anchors.centerIn: parent
                                    width: 14; height: 14
                                    property bool filled: dlg.isPinned
                                    onFilledChanged: requestPaint()
                                    onVisibleChanged: if (visible) requestPaint()
                                    Component.onCompleted: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d"); ctx.reset()
                                        ctx.strokeStyle = pinIcon.filled ? "#ffd60a" : root.white90
                                        ctx.fillStyle = "#ffd60a"
                                        ctx.lineWidth = 1.4; ctx.lineCap = "round"; ctx.lineJoin = "round"
                                        ctx.beginPath()
                                        ctx.moveTo(4.5, 1.5); ctx.lineTo(9.5, 1.5); ctx.lineTo(9.5, 3.5)
                                        ctx.lineTo(11.5, 6.5); ctx.lineTo(2.5, 6.5); ctx.lineTo(4.5, 3.5)
                                        ctx.closePath()
                                        if (pinIcon.filled) ctx.fill()
                                        ctx.stroke()
                                        ctx.beginPath(); ctx.moveTo(7, 6.5); ctx.lineTo(7, 12.5); ctx.stroke()
                                    }
                                }
                                MouseArea {
                                    id: pinMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.placeholderText = dlg.isPinned ? "Unpin" : "Pin"
                                    onExited: root.placeholderText = "Search or Ask"
                                    onClicked: { root.toggleClipPin(modelData); searchField.forceActiveFocus() }
                                }
                            }
                            SpotlightWeatherCard {
                                visible: isWeather
                                anchors.fill: parent
                                anchors.leftMargin: 6; anchors.rightMargin: 6
                                anchors.topMargin: 2; anchors.bottomMargin: 6
                                info: isWeather ? modelData.wx : null
                                fontFamily: root.fontDisplay
                                fg: root.sFg
                                muted: root.headerFg
                                panel: root.white06
                                panelBorder: root.white10
                                onOpenBrowser: root.openUrl(modelData.wx.url)
                            }
                            SpotlightVolumeCard {
                                visible: isVolume
                                anchors.fill: parent
                                anchors.leftMargin: 6; anchors.rightMargin: 6
                                anchors.topMargin: 2; anchors.bottomMargin: 6
                                level: root.volLevel
                                isMuted: root.volMuted
                                fontFamily: root.fontDisplay
                                fg: root.sFg
                                dim: root.sFgDim
                                accent: root.accent
                                panel: root.white06
                                panelBorder: root.white10
                                speakerPath: root.cmdGlyphPaths["volume"]
                                hint: "Volume  \u00B7  \u2190 \u2192 adjust  \u00B7  Shift for fine steps  \u00B7  click the speaker to mute"
                                onLevelChosen: (value) => root.volSet(value)
                                onMuteToggled: root.volSetMute(!root.volMuted)
                                onDraggingChanged: root.volDragging = dragging
                            }
                            SpotlightVolumeCard {
                                visible: isBrightness
                                anchors.fill: parent
                                anchors.leftMargin: 6; anchors.rightMargin: 6
                                anchors.topMargin: 2; anchors.bottomMargin: 6
                                level: root.brightLevel
                                muteEnabled: false
                                dimmed: !root.brightControllable
                                fontFamily: root.fontDisplay
                                fg: root.sFg
                                dim: root.sFgDim
                                accent: root.accent
                                panel: root.white06
                                panelBorder: root.white10
                                speakerPath: root.cmdGlyphPaths["theme"]
                                hint: root.brightControllable
                                      ? ("Brightness \u00B7 " + root.screen.name + (root.brightMonitor.isDdc ? " (DDC)" : "") + "  \u00B7  \u2190 \u2192 adjust  \u00B7  Shift for fine steps")
                                      : ("No brightness control for " + (root.screen ? root.screen.name : "this monitor") + "  \u00B7  needs ddcutil (and i2c access)")
                                onLevelChosen: (value) => root.brightSet(value)
                            }
                            SpotlightVolumeCard {
                                visible: isMic
                                anchors.fill: parent
                                anchors.leftMargin: 6; anchors.rightMargin: 6
                                anchors.topMargin: 2; anchors.bottomMargin: 6
                                level: root.micLevel
                                isMuted: root.micMuted
                                fontFamily: root.fontDisplay
                                fg: root.sFg
                                dim: root.sFgDim
                                accent: root.accent
                                panel: root.white06
                                panelBorder: root.white10
                                speakerPath: root.cmdGlyphPaths["mic"]
                                hint: "Microphone input level  \u00B7  \u2190 \u2192 adjust  \u00B7  click the mic to mute"
                                onLevelChosen: (value) => root.micSet(value)
                                onMuteToggled: root.micSetMute(!root.micMuted)
                                onDraggingChanged: root.micDragging = dragging
                            }
                            SpotlightVolumeCard {
                                visible: isNight
                                anchors.fill: parent
                                anchors.leftMargin: 6; anchors.rightMargin: 6
                                anchors.topMargin: 2; anchors.bottomMargin: 6
                                level: root.nightLevel
                                isMuted: !root.nightActive
                                valueText: root.nightActive ? (root.nightTemp + "K") : "Off"
                                fontFamily: root.fontDisplay
                                fg: root.sFg
                                dim: root.sFgDim
                                accent: "#FF9F0A"
                                panel: root.white06
                                panelBorder: root.white10
                                speakerPath: root.cmdGlyphPaths["moon"]
                                hint: "Night light  \u00B7  \u2190 \u2192 cooler / warmer  \u00B7  click the moon to turn on or off"
                                onLevelChosen: (value) => root.nightSet(value)
                                onMuteToggled: root.nightToggle()
                            }
                            SpotlightVolumeCard {
                                visible: isLamp
                                anchors.fill: parent
                                anchors.leftMargin: 6; anchors.rightMargin: 6
                                anchors.topMargin: 2; anchors.bottomMargin: 6
                                level: root.lampLevel
                                isMuted: !root.lampOn
                                dimmed: root.lampError !== "" && !root.lampKnown
                                valueText: root.lampOn ? (Math.round(root.lampLevel * 100) + "%") : "Off"
                                fontFamily: root.fontDisplay
                                fg: root.sFg
                                dim: root.sFgDim
                                accent: "#FFD60A"
                                panel: root.white06
                                panelBorder: root.white10
                                speakerPath: root.cmdGlyphPaths["bulb"]
                                hint: root.lampError !== "" && !root.lampKnown
                                      ? ("Luz sem resposta  \u00B7  " + root.lampError)
                                      : "Luz do quarto  \u00B7  \u2190 \u2192 adjust  \u00B7  Shift for fine steps  \u00B7  click the bulb to turn on or off"
                                onLevelChosen: (value) => root.lampSet(value)
                                onMuteToggled: root.lampToggle()
                                onDraggingChanged: root.lampDragging = dragging
                            }
                            SpotlightPowerCard {
                                visible: isPower
                                anchors.fill: parent
                                anchors.leftMargin: 6; anchors.rightMargin: 6
                                anchors.topMargin: 2; anchors.bottomMargin: 6
                                profiles: root.ppProfiles
                                current: root.ppCurrent
                                batteryText: root.powerBatteryText
                                fontFamily: root.fontDisplay
                                fg: root.sFg
                                dim: root.sFgDim
                                accent: root.accent
                                panel: root.white06
                                panelBorder: root.white10
                                onProfileChosen: (id) => root.ppSet(id)
                            }
                            SpotlightQrCard {
                                visible: isQr
                                anchors.fill: parent
                                anchors.leftMargin: 6; anchors.rightMargin: 6
                                anchors.topMargin: 2; anchors.bottomMargin: 6
                                source: isQr ? root.qrFile : ""
                                label: root.qrLabel
                                busy: root.qrBusy
                                error: root.qrError
                                fontFamily: root.fontDisplay
                                fg: root.sFg
                                dim: root.sFgDim
                                panel: root.white06
                                panelBorder: root.white10
                            }
                        }
                        onCountChanged: { if (root.selectedIndex >= root.items.length) root.selectedIndex = 0 }
                    }

                    GridView {
                        id: resultGrid
                        visible: root.mode === "apps"
                        anchors.fill: parent; anchors.margins: 0
                        cellWidth: Math.floor(width / 2); cellHeight: root.rowH
                        model: root.items; clip: true
                        currentIndex: root.selectedIndex
                        reuseItems: true
                        ScrollBar.vertical: ScrollBar {
                            policy: resultGrid.contentHeight > resultGrid.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            width: 8
                            contentItem: Rectangle { implicitWidth: 6; radius: 3; color: Qt.rgba(1,1,1,0.35) }
                            background: Rectangle { implicitWidth: 6; color: "transparent" }
                        }
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: resultGrid.cellWidth
                            height: resultGrid.cellHeight
                            Rectangle {
                                anchors.fill: parent; anchors.margins: 2; radius: 10
                                border.width: root.selectedIndex === index ? 1 : 0
                                border.color: root.selectionBorder
                                color: {
                                    if (root.selectedIndex === index) return root.selectionBg;
                                    if (gridHover.containsMouse) return root.hoverBg;
                                    return "transparent";
                                }
                                Behavior on color { ColorAnimation { duration: root.animFast } }
                            }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10; spacing: 12
                                Image {
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 30; Layout.alignment: Qt.AlignVCenter
                                    source: modelData.icon || ""; sourceSize { width: 60; height: 60 }
                                    asynchronous: true; smooth: true
                                }
                                Text {
                                    Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                    text: modelData.name || ""
                                    font { family: root.fontDisplay; pixelSize: 14; weight: Font.Medium }
                                    color: root.sFg
                                    elide: Text.ElideRight; maximumLineCount: 1
                                }
                            }
                            MouseArea { id: gridHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onPositionChanged: {
                                    if (root.selectedIndex !== index) {
                                        root._userNavigated = true;
                                        root.selectedIndex = index;
                                    }
                                }
                                onClicked: (mouse) => {
                                    root.selectedIndex = index;
                                    root.openSelected(!!(mouse.modifiers & Qt.ShiftModifier));
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent; text: "No Results Found"
                        font { family: root.fontDisplay; pixelSize: 14 }
                        color: root.sFgDim
                        visible: root.query.length > 0 && root.items.length === 0
                    }
                }

                // ---- Footer: settings button (left) + key hints (right)
                Item {
                    visible: root.footerH > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.footerH
                    Layout.minimumHeight: root.footerH

                    Rectangle {
                        id: gearBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 2
                        width: 28; height: 28; radius: 14
                        color: gearMA.containsMouse ? root.white14 : "transparent"
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: root.animFast } }
                        MouseArea {
                            id: gearMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openSettingsApp()
                        }
                        Canvas {
                            anchors.centerIn: parent
                            width: 20; height: 20
                            scale: 0.8
                            opacity: gearMA.containsMouse ? 1.0 : 0.75
                            Behavior on opacity { NumberAnimation { duration: root.animFast } }
                            Component.onCompleted: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d"); ctx.reset()
                                ctx.strokeStyle = root.sFgDim
                                ctx.lineWidth = 1.4; ctx.lineJoin = "round"; ctx.lineCap = "round"
                                var cx = 10, cy = 10, n = 8, ro = 8.2, ri = 6.2, st = Math.PI * 2 / n
                                ctx.beginPath()
                                for (var k = 0; k < n; k++) {
                                    var a = st * k
                                    var pts = [[ri, a - 0.30 * st], [ro, a - 0.17 * st], [ro, a + 0.17 * st], [ri, a + 0.30 * st]]
                                    for (var m = 0; m < 4; m++) {
                                        var x = cx + pts[m][0] * Math.cos(pts[m][1]), y = cy + pts[m][0] * Math.sin(pts[m][1])
                                        if (k === 0 && m === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                                    }
                                }
                                ctx.closePath(); ctx.stroke()
                                ctx.beginPath(); ctx.arc(cx, cy, 2.6, 0, Math.PI * 2); ctx.stroke()
                            }
                        }
                    }

                    RowLayout {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 2
                        spacing: 22
                        Repeater {
                            model: root.footerHints
                            delegate: RowLayout {
                                spacing: 6
                                Text {
                                    text: modelData.k
                                    color: root.sFgDim
                                    font { family: root.fontText; pixelSize: 12; weight: Font.Medium }
                                }
                                Text {
                                    text: modelData.t
                                    color: root.sFgDim
                                    font { family: root.fontText; pixelSize: 12; weight: Font.Medium }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- Preview popup (image, text, markdown, PDF, video, audio)
        Rectangle {
            id: previewPopup
            visible: root.previewKind !== ""
            anchors.left: searchHeader.right
            anchors.leftMargin: 16 + root.panelPad
            anchors.top: searchHeader.top
            anchors.topMargin: -root.bodyPad
            width: root.previewBox.w
            height: root.previewBox.h
            radius: root.panelRadius
            color: root.glassBg
            border.color: root.glassBorder
            border.width: 1
            clip: true
            Behavior on width { NumberAnimation { duration: root.animSlow; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: root.animSlow; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; z: -1 }

            Image {
                id: previewImg
                visible: root.previewKind === "image"
                anchors.fill: parent; anchors.margins: 10
                source: root.previewKind === "image" && root.previewPath ? root.fileUrl(root.previewPath) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true; cache: true
                sourceSize.width: 1400; sourceSize.height: 1400
                onStatusChanged: {
                    if (status === Image.Ready) { root.previewNatW = implicitWidth; root.previewNatH = implicitHeight; }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: root.previewKind === "image" && previewImg.status === Image.Error
                text: "Couldn't load this image"
                horizontalAlignment: Text.AlignHCenter
                color: root.sFgDim
                font { family: root.fontText; pixelSize: 12 }
            }
            Flickable {
                id: previewTextFlick
                visible: root.previewKind === "text"
                anchors.fill: parent; anchors.margins: 12; anchors.rightMargin: 22
                clip: true
                contentWidth: width; contentHeight: previewTextItem.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Text {
                    id: previewTextItem
                    width: previewTextFlick.width
                    text: root.previewText
                    color: root.sFgDim
                    font { family: "JetBrains Mono"; pixelSize: 16 }
                    wrapMode: Text.Wrap
                }
                ScrollBar.vertical: ScrollBar {
                    policy: previewTextFlick.contentHeight > previewTextFlick.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    width: 6
                    contentItem: Rectangle { implicitWidth: 6; radius: 3; color: Qt.rgba(1,1,1,0.35) }
                }
            }
            Flickable {
                id: previewMdFlick
                visible: root.previewKind === "markdown"
                anchors.fill: parent; anchors.margins: 12; anchors.rightMargin: 22
                clip: true
                contentWidth: width; contentHeight: previewMdItem.implicitHeight
                Text {
                    id: previewMdItem
                    width: previewMdFlick.width
                    text: root.previewText
                    textFormat: Text.MarkdownText
                    color: root.sFg
                    font { family: root.fontText; pixelSize: 15 }
                    wrapMode: Text.Wrap
                }
            }
            Image {
                visible: root.previewKind === "pdf"
                anchors.fill: parent; anchors.margins: 10
                source: root.previewKind === "pdf" && root.previewThumbPath ? root.fileUrl(root.previewThumbPath) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true; cache: true
                sourceSize.width: 1400; sourceSize.height: 1400
            }
            // Lazy: MediaPlayer/AudioOutput only exist while a video is being previewed
            Loader {
                id: videoLoader
                active: root._shown && root.previewKind === "video"
                anchors.fill: parent; anchors.margins: 10
                sourceComponent: Item {
                    MediaPlayer {
                        id: videoPlayer
                        source: root.previewKind === "video" && root.previewPath ? root.fileUrl(root.previewPath) : ""
                        videoOutput: videoOut
                        audioOutput: AudioOutput { volume: 0.7 }
                        onMetaDataChanged: {
                            const r = metaData.resolution;
                            if (root.previewKind === "video" && r && r.width > 0 && r.height > 0) {
                                root.previewNatW = r.width;
                                root.previewNatH = r.height;
                            }
                        }
                    }
                    VideoOutput { id: videoOut; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectFit }
                    Image {
                        anchors.fill: parent
                        source: root.previewThumbPath ? root.fileUrl(root.previewThumbPath) : ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 1000; sourceSize.height: 1000
                        visible: videoPlayer.playbackState !== MediaPlayer.PlayingState
                                && videoPlayer.playbackState !== MediaPlayer.PausedState
                        asynchronous: true
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 48; height: 48; radius: 24
                        color: Qt.rgba(0, 0, 0, 0.45)
                        visible: videoPlayer.playbackState !== MediaPlayer.PlayingState
                        Text { anchors.centerIn: parent; text: "▶"; color: "#ffffff"; font.pixelSize: 20 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: videoPlayer.play() }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: videoPlayer.playbackState === MediaPlayer.PlayingState
                        onClicked: videoPlayer.pause()
                    }
            
                }
            }
            // Lazy: audio player only exists while an audio file is being previewed
            Loader {
                id: audioLoader
                active: root._shown && root.previewKind === "audio"
                anchors.fill: parent; anchors.margins: 10
                sourceComponent: Item {
                    readonly property bool playing: audioPlayer.playbackState === MediaPlayer.PlayingState
                    Image {
                        id: audioCoverImgPopup
                        anchors.fill: parent; anchors.bottomMargin: 40
                        source: root.previewThumbPath ? root.fileUrl(root.previewThumbPath) : ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 800; sourceSize.height: 800
                        asynchronous: true
                        visible: status === Image.Ready
                        onStatusChanged: if (status === Image.Ready) { root.previewNatW = implicitWidth; root.previewNatH = implicitHeight + 40; }
                    }
                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -20
                        text: "\u266a"
                        color: root.sFgDim
                        font.pixelSize: 46
                        visible: audioCoverImgPopup.status !== Image.Ready
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 100; height: 30; radius: 15
                        color: audioPlayPopupMA.containsMouse ? root.white25 : Qt.rgba(1, 1, 1, 0.15)
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            SpotlightMediaGlyph { kind: root.previewAudioPlaying ? "pause" : "play"; fg: "#ffffff" }
                            Text { text: root.previewAudioPlaying ? "Pause" : "Play"; color: "#ffffff"; font.pixelSize: 11 }
                        }
                        MouseArea {
                            id: audioPlayPopupMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (audioPlayer.playbackState === MediaPlayer.PlayingState) audioPlayer.pause();
                                else audioPlayer.play();
                            }
                        }
                    }
                    MediaPlayer {
                        id: audioPlayer
                        source: root.previewKind === "audio" && root.previewPath ? root.fileUrl(root.previewPath) : ""
                        audioOutput: AudioOutput { volume: 0.8 }
                    }
            
                }
            }
        }

        // ---- AI popup (Hermes Agent)
        Rectangle {
            id: aiPopup
            visible: root.aiText.length > 0 && root.previewKind === ""
            anchors.left: searchHeader.right
            anchors.leftMargin: 16 + root.panelPad
            anchors.top: searchHeader.top
            anchors.topMargin: -root.bodyPad

            width: 460

            readonly property real aiMinH: 160
            readonly property real aiMaxH: 700
            readonly property real aiPad: 28
            readonly property real aiExtra: 8

            height: Math.min(aiMaxH, Math.max(aiMinH, aiBody.implicitHeight + aiPad + aiExtra))

            radius: root.panelRadius
            color: root.glassBg
            border.color: root.glassBorder
            border.width: 1
            clip: true

            Behavior on height { NumberAnimation { duration: root.animSlow; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: root.animMed; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent; z: -1 }

            ColumnLayout {
                id: aiBody
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 8

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SiriOrb {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        size: 26
                        active: root.aiLoading
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!root.aiLoading) {
                                const turns = Math.floor(root.aiHistory.length / 2);
                                return turns > 0 ? "Hermes Agent · " + turns + " msg" : "Hermes Agent"
                            }
                            if (root.aiErrored) return "Hermes Agent · error"
                            return "Hermes Agent" + ".".repeat((_dotsTimer.tick % 3) + 1)
                        }
                        color: root.aiErrored ? "#FF6961" : root.sFg
                        font { family: root.fontDisplay; pixelSize: 13; weight: Font.DemiBold }
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        width: 24; height: 24; radius: 6
                        visible: !root.aiLoading && root.aiText.length > 0 && !root.aiErrored
                        color: copyMA.containsMouse ? root.white14 : "transparent"
                        border.width: 1
                        border.color: root.white12
                        Text { anchors.centerIn: parent; text: "\u29c9"; color: root.sFg; font.pixelSize: 13 }
                        MouseArea {
                            id: copyMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.copyText(root.aiText)
                        }
                    }

                    Rectangle {
                        width: 24; height: 24; radius: 6
                        color: newConvMA.containsMouse ? root.white14 : "transparent"
                        border.width: 1
                        border.color: root.white12
                        visible: root.aiHistory.length > 0
                        Canvas {
                            anchors.centerIn: parent
                            width: 12; height: 12
                            onPaint: {
                                var ctx = getContext("2d"); ctx.reset()
                                ctx.strokeStyle = root.white85; ctx.lineWidth = 1.4
                                ctx.lineCap = "round"
                                ctx.beginPath()
                                ctx.moveTo(2, 2); ctx.lineTo(10, 10)
                                ctx.moveTo(10, 2); ctx.lineTo(2, 10)
                                ctx.stroke()
                            }
                        }
                        MouseArea {
                            id: newConvMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.newAiConversation()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root.divider
                }

                // Messages
                ScrollView {
                    id: aiScroll
                    Layout.fillWidth: true
                    Layout.preferredHeight: {
                        const headerish = 40 + 1 + 8
                        const inputish = 40 + 8 + 18
                        const maxBody = aiPopup.aiMaxH - aiPopup.aiPad - headerish - inputish
                        return Math.min(Math.max(aiMessages.implicitHeight, 40), maxBody)
                    }
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical: ScrollBar {
                        width: 6
                        policy: aiScroll.contentHeight > aiScroll.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        contentItem: Rectangle {
                            implicitWidth: 6; radius: 3
                            color: root.white35
                        }
                        background: Rectangle { implicitWidth: 6; color: "transparent" }
                    }

                    ColumnLayout {
                        id: aiMessages
                        width: aiScroll.availableWidth
                        spacing: 8

                        Repeater {
                            model: root.aiHistory
                            delegate: Item {
                                id: bubbleItem
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: bubble.implicitHeight + 22
                                readonly property bool isUser: modelData.role === "user"
                                property real anim: 0
                                readonly property string ts: modelData.ts || ""
                                Component.onCompleted: {
                                    if (index === root.aiHistory.length - 1) enterAnim.start()
                                    else anim = 1
                                }
                                SequentialAnimation {
                                    id: enterAnim
                                    NumberAnimation { target: bubbleItem; property: "anim"; from: 0; to: 1.08; duration: root.animSlow; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: bubbleItem; property: "anim"; to: 1.0; duration: root.animMed; easing.type: Easing.OutBack }
                                }
                                SiriOrb {
                                    id: avatar
                                    visible: !isUser
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    width: 22; height: 22; size: 22
                                    active: false
                                    showRing: false
                                }
                                Rectangle {
                                    id: bubble
                                    anchors.right: isUser ? parent.right : undefined
                                    anchors.left: isUser ? undefined : avatar.right
                                    anchors.leftMargin: 8
                                    transform: [
                                        Translate { y: (1 - bubbleItem.anim) * 12 },
                                        Scale {
                                            origin.x: isUser ? bubble.width : 0
                                            origin.y: bubble.height
                                            xScale: 0.9 + 0.1 * bubbleItem.anim
                                            yScale: 0.9 + 0.1 * bubbleItem.anim
                                        }
                                    ]
                                    opacity: Math.min(1, bubbleItem.anim)
                                    radius: 10
                                    width: Math.min(parent.width * (isUser ? 0.78 : 0.85), implicitWidth)
                                    implicitWidth: bubbleText.implicitWidth + 24
                                    implicitHeight: bubbleText.implicitHeight + 20
                                    gradient: Gradient {
                                        orientation: Gradient.Diagonal
                                        GradientStop { position: 0.0; color: isUser ? Qt.rgba(0.36, 0.56, 1.0, 0.30) : root.white12 }
                                        GradientStop { position: 1.0; color: isUser ? Qt.rgba(0.30, 0.42, 0.95, 0.12) : root.white06 }
                                    }
                                    border.width: 1
                                    border.color: isUser ? Qt.rgba(0.50, 0.70, 1.0, 0.40) : root.white14
                                    Text {
                                        id: bubbleText
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                        anchors.margins: 12
                                        text: modelData.label || modelData.content
                                        textFormat: isUser ? Text.PlainText : Text.MarkdownText
                                        color: "#ffffff"
                                        font { family: root.fontText; pixelSize: 14 }
                                        wrapMode: Text.Wrap
                                    }
                                }
                                Row {
                                    anchors.top: bubble.bottom; anchors.topMargin: 3
                                    anchors.right: isUser ? bubble.right : undefined
                                    anchors.left: isUser ? undefined : bubble.left
                                    spacing: 4
                                    Text { text: bubbleItem.ts; color: root.white28; font { family: root.fontText; pixelSize: 9 } }
                                    Text { visible: isUser; text: "✓✓"; color: Qt.rgba(0.4, 0.75, 1.0, 0.7); font { family: root.fontText; pixelSize: 9; weight: Font.Bold } }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.aiLoading ? 30 : 0
                            visible: root.aiLoading
                            SequentialAnimation on opacity {
                                running: root.aiLoading; loops: Animation.Infinite
                                NumberAnimation { to: 0.4; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                            Row {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Text { text: "Hermes is typing"; color: root.sFgDim; font { family: root.fontText; pixelSize: 12; italic: true } }
                                Text { text: ".".repeat((_dotsTimer.tick % 3) + 1); color: root.sFgDim; font { family: root.fontText; pixelSize: 12; italic: true } }
                            }
                        }

                        Connections {
                            target: root
                            function onAiHistoryChanged() {
                                Qt.callLater(() => {
                                    scrollAnim.to = Math.max(0, aiScroll.contentHeight - aiScroll.height)
                                    scrollAnim.start()
                                })
                            }
                        }

                        NumberAnimation {
                            id: scrollAnim
                            target: aiScroll.contentItem
                            property: "contentY"
                            duration: root.animSlow
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // Chat input
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 10
                    color: root.white06
                    border.width: 1
                    border.color: chatInput.activeFocus ? root.accent : root.white12
                    Behavior on border.color { ColorAnimation { duration: root.animMed } }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 6
                        spacing: 8
                        TextInput {
                            id: chatInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            color: root.sFg
                            font { family: root.fontText; pixelSize: 14 }
                            selectByMouse: true; clip: true
                            enabled: !root.aiLoading
                            Text {
                                anchors.fill: parent
                                text: root.aiLoading ? "Please wait…" : "Continue the conversation…"
                                color: root.placeholderFg
                                font: chatInput.font
                                verticalAlignment: Text.AlignVCenter
                                visible: chatInput.text.length === 0
                            }
                            function sendNow() {
                                const t = text;
                                if (root.sendChat(t)) text = "";
                            }
                            Keys.onReturnPressed: (event) => { sendNow(); event.accepted = true; }
                            Keys.onEnterPressed: (event) => { sendNow(); event.accepted = true; }
                        }
                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            color: {
                                if (root.aiLoading) return Qt.rgba(1, 1, 1, 0.04);
                                if (sendMA.containsMouse) return Qt.rgba(0.0, 0.48, 1.0, 0.55);
                                return Qt.rgba(0.0, 0.48, 1.0, 0.35);
                            }
                            Canvas {
                                anchors.centerIn: parent
                                width: 14; height: 14
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.reset()
                                    ctx.strokeStyle = root.white90; ctx.lineWidth = 1.6
                                    ctx.lineCap = "round"; ctx.lineJoin = "round"
                                    ctx.beginPath()
                                    ctx.moveTo(2, 7); ctx.lineTo(12, 7)
                                    ctx.moveTo(8, 3); ctx.lineTo(12, 7); ctx.lineTo(8, 11)
                                    ctx.stroke()
                                }
                            }
                            MouseArea {
                                id: sendMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.aiLoading
                                onClicked: chatInput.sendNow()
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: !root.aiLoading && root.aiHistory.length === 0
                    text: "Enter to send · history is cleared when Spotlight closes"
                    color: root.headerFg
                    font { family: root.fontText; pixelSize: 10 }
                }
            }
        }
    }

    // =====================================================================
    //  TIMERS
    // =====================================================================
    Timer { id: _previewDeb; interval: 120; repeat: false; onTriggered: root.updatePreview() }
    Timer { id: _fdDeb; interval: 140; repeat: false; onTriggered: root.runFd() }
    Timer { id: _sideEffectsDeb; interval: 250; repeat: false; onTriggered: root.runSideEffects() }
    Timer { id: _rebuildDeb; interval: 30; repeat: false; onTriggered: root.buildResults() }

    // Command menu sources: your menu.jsonc wins, menu.default.json (next to this file) is the fallback
    FileView {
        id: _menuUserFile
        path: Quickshell.env("HOME") + "/.config/illogical-impulse/menu.jsonc"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { root._menuUserText = root._menuStripComments(text()); root.menuRebuild(); }
        onLoadFailed: { root._menuUserText = ""; root.menuRebuild(); }
    }
    FileView {
        id: _menuDefaultFile
        path: Qt.resolvedUrl("menu.default.json").toString().replace(/^file:\/\//, "")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { root._menuDefaultText = root._menuStripComments(text()); root.menuRebuild(); }
    }
    Timer { id: _aiDeb; interval: 1200; repeat: false; onTriggered: root.runHermes(root._pendingAiPrompt) }

    Timer {
        id: _screenshotDeb
        interval: 150
        repeat: false
        property bool useSelectArea: true
        onTriggered: spotlightActions.runScreenshotOcr(useSelectArea)
    }

    Timer {
        id: _aiRetryTimer
        interval: 1000; repeat: false
        property string prompt: ""
        onTriggered: { if (prompt) root.runHermes(prompt, true); }
    }

    Timer {
        id: _dotsTimer
        interval: 400
        running: root.aiLoading
        repeat: true
        property int tick: 0
        onTriggered: tick++
    }

    Timer {
        id: _statsTimer
        interval: 3000; repeat: true
        running: root._shown && root.showSysStats
        triggeredOnStart: true
        onTriggered: { if (!_stats.running) _stats.running = true; }
    }

    // =====================================================================
    //  PROCESSES
    // =====================================================================
    Process { id: _saveUsage; running: false }

    Process {
        id: terminalProcess
        running: false
        property string commandText: ""
        command: [root.terminal, "--", "bash", "-lc", commandText + "; echo; read -n 1 -s -r -p 'Press any key to close...'"]
    }

    Process {
        id: _fd; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const id = parseInt(lines.shift());
                if (id !== root._fdReq) return;
                root.fileItems = root.parseFdLines(lines);
                root.scheduleRebuild();
            }
        }
    }

    Process {
        id: _recents; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.browseDir = lines.shift().trim();
                root.recentItems = root.parseFdLines(lines);
                if (root.mode === "files") root.scheduleRebuild();
            }
        }
    }

    Process {
        id: _rg; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const id = parseInt(lines.shift());
                if (id !== root._rgReq) return;
                root.contentResults = lines.filter(Boolean).map(p => {
                    const sp = root.splitPath(p);
                    return { name: sp.name, path: p, dir: sp.dir };
                });
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _clip; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let data = null;
                try { data = JSON.parse(text.trim()); } catch (e) { data = null; }
                if (!data) return;
                const out = [];
                for (const c of (data.history || [])) {
                    if (!c || !c.id) continue;
                    const t = String(c.text || "");
                    out.push({ id: String(c.id), text: t.length > 120 ? t.slice(0, 120) + "\u2026" : t,
                               isImage: c.isImage === true, imagePath: c.imagePath || "", h: c.h || "" });
                }
                root.clipItems = out;
                root.clipPins = data.pins || [];
                if (root.mode === "clipboard") root.scheduleRebuild();
            }
        }
    }

    Process {
        id: _clipPinProc; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const pins = JSON.parse(text.trim());
                    if (Array.isArray(pins)) root.clipPins = pins;
                } catch (e) { /* keep the current pins */ }
                if (root.mode === "clipboard") root.scheduleRebuild();
            }
        }
        onExited: (exitCode, exitStatus) => _clipNextTimer.restart()
    }
    Timer { id: _clipNextTimer; interval: 40; onTriggered: root._clipNext() }

    Process {
        id: _clipClear
        running: false
        command: ["bash", "-c", "cliphist wipe && rm -f \"$HOME/.cache/quickshell/spotlight-clipboard/\"*"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.clipItems = [];
                if (root.mode === "clipboard") root.scheduleRebuild();
            }
        }
    }

    Process {
        id: _dict; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let def = "";
                try {
                    const data = JSON.parse(text);
                    def = (data[0] && data[0].meanings && data[0].meanings[0] && data[0].meanings[0].definitions && data[0].meanings[0].definitions[0] && data[0].meanings[0].definitions[0].definition) || "";
                } catch (e) { def = ""; }
                root.dictText = def;
                const s = root.query.trim().toLowerCase();
                const m = s.match(/^(define|significado|meaning)\s+(.+)$/);
                if (m) {
                    const pt = m[1] === "significado";
                    const lang = pt ? "pt-BR" : "en";
                    const word = m[2].trim().replace(pt ? /[^a-zà-ú-]/g : /[^a-z-]/g, "");
                    if (word) root.cacheSet("dict:" + lang + ":" + word, def);
                }
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _loadUsage; running: false
        command: ["bash", "-c", "cat ~/.cache/spotlight-usage.json 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.usageCounts = JSON.parse(text.trim() || "{}"); } catch (e) { root.usageCounts = {}; }
            }
        }
    }

    Process {
        id: _addEvent
        running: false
        property string title: ""
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                CalendarEvents.refresh();
                root.notify("Event added: " + title);
            } else {
                root.notify("Could not add event", true);
            }
        }
    }

    Process {
        id: _currency; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const p = root._pendingCurrency;
                    if (p && data.rates && data.rates[p.to] !== undefined) {
                        const result = (p.val * data.rates[p.to]).toFixed(p.to === "BTC" ? 8 : 2);
                        const txt = p.val + " " + p.from + " = " + result + " " + p.to;
                        root.currencyText = txt;
                        root.cacheSet("cur:" + p.from + ":" + p.to + ":" + p.val, txt);
                    } else {
                        root.currencyText = "";
                    }
                } catch (e) { root.currencyText = ""; }
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _quote; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const p = root._pendingQuote;
                if (!p || root._quoteQ !== p.q) return;       // query changed while fetching
                root._pendingQuote = null;
                let res = null;
                try {
                    const d = JSON.parse(text)[p.pair.replace("-", "")];
                    const bid = parseFloat(d.bid);
                    if (!isNaN(bid)) {
                        const dec = bid >= 100 ? 2 : (bid >= 0.1 ? 4 : 6);
                        const pct = parseFloat(d.pctChange);
                        const arrow = isNaN(pct) ? "" : (pct >= 0 ? "\u25b2 +" : "\u25bc ") + root.fmtBR(pct, 2) + "% \u00b7 ";
                        const hi = parseFloat(d.high), lo = parseFloat(d.low), ask = parseFloat(d.ask);
                        let sub = arrow;
                        if (!isNaN(ask)) sub += "venda " + root.fmtBR(ask, dec) + " \u00b7 ";
                        if (!isNaN(hi) && !isNaN(lo)) sub += "m\u00e1x " + root.fmtBR(hi, dec) + " \u00b7 m\u00edn " + root.fmtBR(lo, dec) + " \u00b7 ";
                        const ts = parseInt(d.timestamp);
                        if (!isNaN(ts)) {
                            const dt = new Date(ts * 1000);
                            sub += String(dt.getHours()).padStart(2, "0") + ":" + String(dt.getMinutes()).padStart(2, "0") + " \u00b7 ";
                        }
                        sub += "clique para copiar";
                        res = { text: p.label + ": R$ " + root.fmtBR(bid, dec), sub: sub, raw: root.fmtBR(bid, dec) };
                    }
                } catch (e) { res = null; }
                if (res) {
                    root.cacheSet("quote:" + p.pair, res);
                    root.quoteResult = { q: p.q, loading: false, text: res.text, sub: res.sub, raw: res.raw };
                } else {
                    root.quoteResult = { q: p.q, loading: false, text: "N\u00e3o consegui buscar a cota\u00e7\u00e3o de " + p.label, sub: "", raw: "" };
                }
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _battery; running: false
        command: ["bash", "-c", "upower -i $(upower -e | grep -m1 BAT) 2>/dev/null | grep -E 'percentage|state'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (!t) { root.batteryText = "No battery detected"; }
                else {
                    const pct = (t.match(/percentage:\s*(\S+)/) || [])[1] || "?";
                    const state = (t.match(/state:\s*(\S+)/) || [])[1] || "";
                    root.batteryText = pct + (state ? " \u2014 " + state : "");
                }
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _ipInfo; running: false
        command: ["bash", "-c", "echo \"Local: $(hostname -I 2>/dev/null | awk '{print $1}')\"; echo \"Public: $(curl -s --max-time 8 ifconfig.me 2>/dev/null)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ipText = text.trim().replace("\n", "  \u2022  ");
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _windows; running: false
        command: ["bash", "-c", "hyprctl clients -j 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.windowItems = data.map(w => ({ title: w.title || w.class || "(untitled)", address: w.address, cls: w.class || "", icls: w.initialClass || "" }));
                } catch (e) { root.windowItems = []; }
                if (root.mode === "windows") root.scheduleRebuild();
            }
        }
    }

    // Wi-Fi: saved profiles ("S:name") + visible networks ("N:in-use:signal:security:ssid")
    readonly property string _wifiListScript: [
        "nmcli -t -f NAME,TYPE connection show 2>/dev/null | while IFS= read -r l; do t=\"${l##*:}\"; n=\"${l%:*}\"; case \"$t\" in wifi|802-11-wireless) printf 'S:%s\\n' \"$n\";; esac; done",
        "nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list 2>/dev/null | sed 's/^/N:/'"
    ].join("\n")

    Process {
        id: _wifi; running: false
        command: ["bash", "-c", root._wifiListScript]
        stdout: StdioCollector {
            onStreamFinished: {
                const unesc = s => s.replace(/\\(.)/g, "$1");
                const saved = {};
                const best = {};
                for (const l of text.split("\n")) {
                    if (l.startsWith("S:")) { saved[unesc(l.slice(2))] = true; continue; }
                    if (!l.startsWith("N:")) continue;
                    const m = l.slice(2).match(/^([^:]*):([^:]*):([^:]*):(.*)$/);
                    if (!m) continue;
                    const ssid = unesc(m[4]);
                    if (!ssid) continue;
                    const sec = m[3].trim();
                    const o = { ssid: ssid, active: m[1].trim() === "*", signal: parseInt(m[2]) || 0,
                                secure: sec !== "" && sec !== "--" };
                    const prev = best[ssid];
                    if (!prev || o.active || (!prev.active && o.signal > prev.signal)) best[ssid] = o;
                }
                const out = Object.keys(best).map(k => { best[k].saved = !!saved[k]; return best[k]; });
                out.sort((a, b) => (b.active - a.active) || (b.saved - a.saved) || (b.signal - a.signal));
                root.wifiItems = out;
                if (root.mode === "wifi" || root._netWordShown === "wifi") root.scheduleRebuild();
            }
        }
    }

    // Ask NetworkManager for a fresh scan, then refresh the list
    Process {
        id: _wifiRescan; running: false
        command: ["bash", "-c", "nmcli device wifi rescan >/dev/null 2>&1; sleep 3"]
        onExited: _wifi.running = true
    }

    // Bluetooth: every device BlueZ knows about (paired or just discovered), with its state
    readonly property string _btListScript: [
        "bluetoothctl devices 2>/dev/null | while read -r _ mac name; do",
        "  i=$(bluetoothctl info \"$mac\" 2>/dev/null)",
        "  p=no; c=no",
        "  case \"$i\" in *'Paired: yes'*) p=yes;; esac",
        "  case \"$i\" in *'Connected: yes'*) c=yes;; esac",
        "  printf '%s\\t%s\\t%s\\t%s\\n' \"$mac\" \"$p\" \"$c\" \"$name\"",
        "done"
    ].join("\n")

    Process {
        id: _bt; running: false
        command: ["bash", "-c", root._btListScript]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const l of text.split("\n")) {
                    const p = l.split("\t");
                    if (p.length < 4 || !p[0]) continue;
                    const name = p.slice(3).join("\t");
                    // devices that only advertise their address have nothing useful to show
                    if (name.replace(/-/g, ":").toUpperCase() === p[0].toUpperCase()) continue;
                    out.push({ mac: p[0], name: name, paired: p[1] === "yes", connected: p[2] === "yes" });
                }
                out.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name));
                root.btItems = out;
                if (root.mode === "bluetooth" || root._netWordShown === "bluetooth") root.scheduleRebuild();
            }
        }
    }

    // Discovery: powers the adapter on if needed and scans for a while so new devices show up
    Process {
        id: _btDiscover; running: false
        command: ["bash", "-c",
            "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' || { bluetoothctl power on >/dev/null 2>&1; sleep 1; }; " +
            "bluetoothctl --timeout 20 scan on >/dev/null 2>&1"]
    }

    // While the Bluetooth list is on screen, refresh it so discovered devices appear
    Timer {
        id: _btPoll
        interval: 2000; repeat: true
        running: root._shown && (root.mode === "bluetooth" || root._netWordShown === "bluetooth")
        onTriggered: { if (!_bt.running) _bt.running = true; }
    }

    // Connect / pair / disconnect actions (values come in as SP_* environment variables)
    Process { id: _netAct; running: false }

    // ---- Open with...: apps registered for the file's MIME type ("id<TAB>name<TAB>path of the .desktop file")
    readonly property string _openWithScript: [
        "mime=$(xdg-mime query filetype \"$SP_FILE\" 2>/dev/null)",
        "[ -n \"$mime\" ] || mime=$(file -b --mime-type \"$SP_FILE\" 2>/dev/null)",
        "gio mime \"$mime\" 2>/dev/null | sed -n 's/^[[:space:]]\\{1,\\}\\([^[:space:]]\\{1,\\}\\.desktop\\)$/\\1/p' | awk '!s[$0]++' | while read -r id; do",
        "  f=\"\"",
        "  for d in \"${XDG_DATA_HOME:-$HOME/.local/share}\" $(printf '%s' \"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\" | tr ':' ' '); do",
        "    [ -f \"$d/applications/$id\" ] && { f=\"$d/applications/$id\"; break; }",
        "  done",
        "  [ -n \"$f\" ] || continue",
        "  n=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-)",
        "  printf '%s\\t%s\\t%s\\n' \"$id\" \"${n:-$id}\" \"$f\"",
        "done"
    ].join("\n")

    Process {
        id: _openWith; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const l of text.split("\n")) {
                    const p = l.split("\t");
                    if (p.length >= 3 && p[0]) out.push({ id: p[0], name: p[1], file: p.slice(2).join("\t") });
                }
                root.fileOpenWith = out;
                if (root.fileActFor && root.fileActStage === "apps") root.scheduleRebuild();
            }
        }
    }

    // ---- /keys
    Process {
        id: _keys; running: false
        command: ["bash", "-c", "hyprctl binds -j 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let data = [];
                try { data = JSON.parse(text); } catch (err) { data = []; }
                if (!Array.isArray(data)) data = [];
                const modNames = [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]];
                const keyNames = {
                    "return": "Enter", "escape": "Esc", "space": "Space", "tab": "Tab", "backspace": "Backspace",
                    "delete": "Del", "print": "PrtSc", "left": "\u2190", "right": "\u2192", "up": "\u2191", "down": "\u2193",
                    "prior": "PgUp", "next": "PgDn", "grave": "`", "minus": "-", "equal": "=", "bracketleft": "[",
                    "bracketright": "]", "comma": ",", "period": ".", "slash": "/", "semicolon": ";",
                    "apostrophe": "'", "backslash": "\\"
                };
                const mouseNames = { "mouse:272": "Left click", "mouse:273": "Right click", "mouse:274": "Middle click",
                                     "mouse_down": "Scroll down", "mouse_up": "Scroll up" };
                const out = [];
                for (const b of data) {
                    const mods = modNames.filter(n => ((b.modmask || 0) & n[0]) !== 0).map(n => n[1]);
                    let key = b.key || "";
                    if (mouseNames[key]) key = mouseNames[key];
                    else if (key.startsWith("mouse:")) key = "Mouse " + key.slice(6);
                    else if (key.length === 1) key = key.toUpperCase();
                    else if (key) key = keyNames[key.toLowerCase()] || key.replace(/^XF86/, "");
                    else if (b.keycode) key = "code:" + b.keycode;
                    else if (b.catch_all) key = "Any key";
                    const desc = (b.has_description && b.description) ? b.description : "";
                    const act = desc || (((b.dispatcher || "") + " " + (b.arg || "")).trim());
                    if (!key && !act) continue;
                    out.push({
                        idx: out.length,
                        combo: mods.concat([key]).join(" + "),
                        action: act || "(custom action)",
                        submap: b.submap || ""
                    });
                }
                root.keysItems = out;
                if (root.mode === "keys" || root._extraShown === "keys") root.scheduleRebuild();
            }
        }
    }

    // ---- Microphone: read the input level while the card is up, write it throttled
    Process {
        id: _micGet; running: false
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/Volume:\s*([0-9.]+)/);
                if (!m || root.micDragging || Date.now() < root._micHold) return;
                root.micLevel = Math.max(0, Math.min(1, parseFloat(m[1])));
                root.micMuted = text.indexOf("[MUTED]") >= 0;
            }
        }
    }
    Timer {
        id: _micPoll
        interval: 1000; repeat: true; triggeredOnStart: true
        running: root._shown && root.micCardShown
        onTriggered: { if (!_micGet.running) _micGet.running = true; }
    }
    Timer {
        id: _micApply
        interval: 60; repeat: false
        onTriggered: spotlightController.run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0; wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + Math.round(root.micLevel * 100) + "%")
    }

    // ---- Bedroom light: read the state while the card is up, write the brightness debounced
    Process {
        id: _lampGet; running: false
        command: ["python3", root.lampScript, "state", "--quiet"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const st = JSON.parse(text.trim().split("\n").pop());
                    root.lampKnown = true;
                    root.lampError = "";
                    if (root.lampDragging || Date.now() < root._lampHold) return;
                    root.lampOn = !!st.on;
                    root.lampLevel = Math.max(0.01, Math.min(1, st.brightness / 100));
                } catch (e) {
                    root.lampKnown = false;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = text.trim().split("\n").pop();
                if (t) root.lampError = t.length > 70 ? t.slice(0, 70) + "\u2026" : t;
            }
        }
    }
    Timer {
        id: _lampPoll
        interval: 6000; repeat: true; triggeredOnStart: true
        running: root._shown && root.lampCardShown
        onTriggered: { if (!_lampGet.running) _lampGet.running = true; }
    }
    Timer {
        id: _lampApply
        interval: 300; repeat: false
        onTriggered: spotlightController.run("python3 \"" + root.lampScript + "\" brightness " + root._lampTarget + " --quiet")
    }

    // ---- Night light: state comes from the Hyprsunset service, the temperature goes into the shell config
    Timer {
        id: _nightPoll
        interval: 3000; repeat: true; triggeredOnStart: true
        running: root._shown && root.nightCardShown
        onTriggered: Hyprsunset.fetchState()
    }
    Timer {
        id: _nightApply
        interval: 80; repeat: false
        onTriggered: Config.options.light.night.colorTemperature = root._nightTarget
    }

    // ---- Power profile (power-profiles-daemon): current profile "---" available profiles
    Process {
        id: _ppGet; running: false
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null; echo '---'; powerprofilesctl list 2>/dev/null | grep -oE '^[* ]*[a-z-]+:' | tr -d '* :'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("---");
                const cur = (parts[0] || "").trim();
                const order = ["power-saver", "balanced", "performance"];
                const labels = { "power-saver": "Power saver", "balanced": "Balanced", "performance": "Performance" };
                const ids = (parts[1] || "").split("\n").map(s => s.trim()).filter(s => s.length > 0);
                ids.sort((a, b) => (order.indexOf(a) < 0 ? 99 : order.indexOf(a)) - (order.indexOf(b) < 0 ? 99 : order.indexOf(b)));
                root.ppProfiles = ids.map(id => ({ id: id, label: labels[id] || id }));
                if (cur && Date.now() >= root._ppHold) root.ppCurrent = cur;
            }
        }
    }
    Timer {
        id: _ppPoll
        interval: 2000; repeat: true; triggeredOnStart: true
        running: root._shown && root.powerCardShown
        onTriggered: { if (!_ppGet.running) _ppGet.running = true; }
    }

    // ---- QR code: qrencode writes a PNG that the card shows
    readonly property string _qrScript: [
        "command -v qrencode >/dev/null 2>&1 || exit 3",
        "find /tmp -maxdepth 1 -name 'spotlight-qr-*.png' ! -path \"$SP_OUT\" -delete 2>/dev/null",
        "if [ \"$SP_MODE\" = wifi ]; then",
        "  prof=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | while IFS= read -r l; do t=\"${l##*:}\"; n=\"${l%:*}\"; case \"$t\" in wifi|802-11-wireless) printf '%s\\n' \"$n\"; break;; esac; done)",
        "  [ -n \"$prof\" ] || exit 2",
        "  ssid=$(nmcli -g 802-11-wireless.ssid connection show \"$prof\" 2>/dev/null)",
        "  pass=$(nmcli -s -g 802-11-wireless-security.psk connection show \"$prof\" 2>/dev/null)",
        "  esc() { printf '%s' \"$1\" | sed -e 's/[\\\\;,:\"]/\\\\&/g'; }",
        "  if [ -n \"$pass\" ]; then SP_QR=\"WIFI:T:WPA;S:$(esc \"$ssid\");P:$(esc \"$pass\");;\"; else SP_QR=\"WIFI:T:nopass;S:$(esc \"$ssid\");;\"; fi",
        "fi",
        "printf '%s' \"$SP_QR\" | qrencode -s 8 -m 2 -o \"$SP_OUT\""
    ].join("\n")

    Process {
        id: _qrGen; running: false
        onExited: (exitCode, exitStatus) => {
            if (root._qrRanFor !== root._qrWanted) { _qrDeb.restart(); return; }   // text changed meanwhile
            if (exitCode === 0) { root.qrFile = "file://" + root._qrOut; root.qrError = ""; }
            else {
                root.qrFile = "";
                root.qrError = exitCode === 3 ? "qrencode is not installed"
                             : (exitCode === 2 ? "No active Wi-Fi network" : "Could not create the QR code (text too long?)");
            }
            root.qrBusy = false;
        }
    }
    Timer { id: _qrDeb; interval: 250; repeat: false; onTriggered: root._qrRun() }

    // ---- /kill: processes of your user, busiest first
    Process {
        id: _procs; running: false
        command: ["bash", "-c", "ps -u \"$(id -u)\" -o pid=,pcpu=,pmem=,args= --sort=-pcpu 2>/dev/null | head -120"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const l of text.split("\n")) {
                    const m = l.match(/^\s*(\d+)\s+([\d.,]+)\s+([\d.,]+)\s+(.+)$/);
                    if (!m) continue;
                    const args = m[4];
                    if (args.indexOf("--sort=-pcpu") >= 0) continue;          // this very listing
                    const parts = args.split(/\s+/);
                    let base = parts[0].split("/").pop() || parts[0];
                    if (/^(python[\d.]*|bash|sh|zsh|fish|node|java|perl|ruby|electron)$/.test(base)) {
                        const next = parts.slice(1).find(p => p.length > 0 && p[0] !== "-");
                        if (next) base = next.split("/").pop() || next;
                    }
                    out.push({
                        pid: parseInt(m[1]),
                        cpu: parseFloat(m[2].replace(",", ".")) || 0,
                        mem: parseFloat(m[3].replace(",", ".")) || 0,
                        name: base,
                        args: args
                    });
                }
                root.killList = out;
                if (root.mode === "kill" || root._extraShown === "kill") root.scheduleRebuild();
            }
        }
    }
    Timer {
        id: _procPoll
        interval: 2000; repeat: true; triggeredOnStart: false
        running: root._shown && (root.mode === "kill" || root._extraShown === "kill")
        onTriggered: { if (!_procs.running) _procs.running = true; }
    }
    Timer { id: _procRefresh; interval: 500; repeat: false; onTriggered: root.procScan() }

    // ---- /usb: external partitions (mounted or not)
    Process {
        id: _usb; running: false
        command: ["bash", "-c", "lsblk -J -o NAME,PATH,LABEL,SIZE,MOUNTPOINTS,RM,HOTPLUG,TRAN,TYPE,MODEL,FSTYPE 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let data = null;
                try { data = JSON.parse(text); } catch (err) { data = null; }
                const truthy = v => v === true || v === 1 || v === "1" || v === "true";
                const out = [];
                for (const d of ((data && data.blockdevices) || [])) {
                    if (d.type !== "disk") continue;
                    if (!(truthy(d.hotplug) || truthy(d.rm) || d.tran === "usb")) continue;
                    const parts = (d.children || []).filter(c => c.type === "part");
                    const cands = parts.length ? parts : [d];
                    for (const p of cands) {
                        const fs = p.fstype || "";
                        if (!fs || fs === "swap" || /LUKS|LVM/i.test(fs)) continue;
                        const mps = (p.mountpoints || [p.mountpoint]).filter(Boolean);
                        out.push({
                            dev: p.path,
                            parent: d.path,
                            name: p.label || (d.model || "").trim() || p.name,
                            size: p.size || "",
                            mp: mps[0] || ""
                        });
                    }
                }
                root.usbItems = out;
                if (root.mode === "usb" || root._extraShown === "usb") root.scheduleRebuild();
            }
        }
    }
    Timer {
        id: _usbPoll
        interval: 3000; repeat: true
        running: root._shown && (root.mode === "usb" || root._extraShown === "usb")
        onTriggered: { if (!_usb.running) _usb.running = true; }
    }

    // Volume: read the current level while the card is on screen, write it (throttled) when you move the bar
    Process {
        id: _volGet; running: false
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/Volume:\s*([0-9.]+)/);
                if (!m || root.volDragging || Date.now() < root._volHold) return;
                root.volLevel = Math.max(0, Math.min(1, parseFloat(m[1])));
                root.volMuted = text.indexOf("[MUTED]") >= 0;
            }
        }
    }

    Timer {
        id: _volPoll
        interval: 1000; repeat: true; triggeredOnStart: true
        running: root._shown && root.volCardShown
        onTriggered: { if (!_volGet.running) _volGet.running = true; }
    }

    Timer {
        id: _volApply
        interval: 60; repeat: false
        onTriggered: spotlightController.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.round(root.volLevel * 100) + "%")
    }

    Process {
        id: _ps; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const id = parseInt(lines.shift());
                if (id !== root._psReq) return;
                const out = [];
                for (const l of lines) {
                    const m = l.trim().match(/^(\d+)\s+(\d+)\s+(.+)$/);
                    if (!m) continue;
                    out.push({ pid: parseInt(m[1]), mb: Math.round(parseInt(m[2]) / 1024), name: m[3] });
                }
                root.procItems = out;
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _dev; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const id = parseInt(lines.shift());
                if (id !== root._devReq) return;
                let out = lines.join("\n").trim();
                if (!out) out = root._devLabel.indexOf("decoded") >= 0 ? "Invalid Base64" : "(empty)";
                root.devResult = { q: root._devQ, text: out, label: root._devLabel };
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _stats; running: false
        command: ["bash", "-c", `
            read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat
            sleep 0.4
            read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat
            t1=$((u1+n1+s1+i1+w1+q1+sq1+st1)); t2=$((u2+n2+s2+i2+w2+q2+sq2+st2))
            dt=$((t2-t1)); di=$(((i2+w2)-(i1+w1)))
            if [ "$dt" -gt 0 ]; then cpu=$((100*(dt-di)/dt)); else cpu=0; fi
            ram=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%.1f/%.1f GB",(t-a)/1048576,t/1048576}' /proc/meminfo)
            disk=$(df --output=pcent / | tail -1 | tr -d ' ')
            echo "CPU $cpu% \u00b7 RAM $ram \u00b7 Disk $disk"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                root.sysStatsText = text.trim();
                if (root._shown && root.query.length === 0 && root.mode === "search") root.scheduleRebuild();
            }
        }
    }

    Process {
        id: _pass; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t.length !== root._passWanted) return;
                root.passText = t;
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _preview; running: false
        stdout: StdioCollector { onStreamFinished: { root.previewText = text; } }
    }

    Process {
        id: _clipPreview; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._clipPrevKey !== root.selectedKey) return;
                const nl = text.indexOf("\n");
                const head = nl >= 0 ? text.slice(0, nl) : text;
                const body = nl >= 0 ? text.slice(nl + 1) : "";
                if (head.startsWith("FILE\t")) {
                    root.previewFile(head.slice(5), false);
                } else {
                    root.previewKind = "text";
                    root.previewPath = "clip:" + root.selectedKey;
                    root.previewText = body;
                }
            }
        }
    }

    Process {
        id: _pdfThumb; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.previewPath === root._pendingPreview.for && root.previewKind === "pdf")
                    root.previewThumbPath = root._pendingPreview.path;
            }
        }
    }

    Process {
        id: _videoThumb; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.previewPath === root._pendingPreview.for && root.previewKind === "video")
                    root.previewThumbPath = root._pendingPreview.path;
            }
        }
    }

    Process {
        id: _audioCover; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.previewPath === root._pendingPreview.for && root.previewKind === "audio")
                    root.previewThumbPath = root._pendingPreview.path;
            }
        }
    }

    Component.onCompleted: {
        root.buildResults();
        _loadUsage.running = true;
    }
}