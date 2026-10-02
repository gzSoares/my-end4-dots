import QtQuick

Item {
    id: orb

    property real size: 26
    property color accentColor: "#5E5CE6"
    property bool active: false
    property bool showRing: true

    implicitWidth: size
    implicitHeight: size

    // ── Aura externa que pulsa ──
    Rectangle {
        id: glowOuter
        anchors.centerIn: parent
        width: orb.size * 0.9
        height: orb.size * 0.9
        radius: width / 2
        color: "transparent"
        border.width: Math.max(1, orb.size * 0.077)
        border.color: orb.active ? Qt.rgba(0.6, 0.3, 1.0, 0.7)
                                 : Qt.rgba(0.5, 0.3, 0.9, 0.25)

        SequentialAnimation on scale {
            running: orb.active
            loops: Animation.Infinite
            NumberAnimation { to: 1.15; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.90; duration: 800; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on opacity {
            running: orb.active
            loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.00; duration: 800; easing.type: Easing.InOutSine }
        }
        Behavior on border.color { ColorAnimation { duration: 300 } }
    }

    // ── Núcleo com gradiente ──
    Rectangle {
        id: core
        anchors.centerIn: parent
        width: orb.size * 0.72
        height: orb.size * 0.72
        radius: width / 2

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00B4FF" }
            GradientStop { position: 0.5; color: "#5E5CE6" }
            GradientStop { position: 1.0; color: "#BF5AF2" }
        }

        RotationAnimation on rotation {
            running: orb.active
            loops: Animation.Infinite
            from: 0; to: 360; duration: 3000
        }

        SequentialAnimation on scale {
            running: true
            loops: Animation.Infinite
            NumberAnimation {
                to: orb.active ? 1.12 : 1.03
                duration: orb.active ? 600 : 1600
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: orb.active ? 0.94 : 0.98
                duration: orb.active ? 600 : 1600
                easing.type: Easing.InOutSine
            }
        }

        opacity: orb.active ? 1.0 : 0.7
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    // ── Brilho interno (highlight 3D) ──
    Rectangle {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -orb.size * 0.115
        width: core.width * 0.5
        height: core.height * 0.35
        radius: width / 2
        color: Qt.rgba(1, 1, 1, 0.35)
        opacity: orb.active ? 0.6 : 0.3
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    // ── Anel girando externo (só quando active) ──
    Rectangle {
        anchors.centerIn: parent
        width: orb.size
        height: orb.size
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(0.8, 0.5, 1.0, 0.6)
        visible: orb.active && orb.showRing
        opacity: orb.active ? 1.0 : 0.0

        RotationAnimation on rotation {
            running: orb.active
            loops: Animation.Infinite
            from: 0; to: 360; duration: 1500
        }
    }
}