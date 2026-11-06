import QtQuick
import qs.modules.common

/**
 * Material 3 style slider. Bind `value`, react to `moved(v)`.
 * While dragging it shows the drag position, so external updates don't fight the finger.
 */
Item {
    id: slider

    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0
    property real wheelStep: 0.05 * (to - from)
    property color accent: Appearance.m3colors.m3primary
    property color trackColor: Appearance.m3colors.m3surfaceContainerHighest
    property bool useGradient: false       // gradient track (e.g. warm → cool color temperature)
    property color gradientFrom: "#ffb35c"
    property color gradientTo: "#cfe3ff"
    property bool enabledState: true
    signal moved(real v)
    signal released

    readonly property bool dragging: mouse.pressed
    property real _drag: 0
    readonly property real shownValue: dragging ? _drag : value
    readonly property real frac: to > from ? Math.max(0, Math.min(1, (shownValue - from) / (to - from))) : 0

    implicitWidth: 200
    implicitHeight: 28
    opacity: enabledState ? 1 : 0.45

    function valueAt(x) {
        let f = Math.max(0, Math.min(1, (x - handle.width / 2) / (width - handle.width)));
        let v = from + f * (to - from);
        if (stepSize > 0)
            v = Math.round(v / stepSize) * stepSize;
        return Math.max(from, Math.min(to, v));
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 12
        radius: height / 2
        color: slider.trackColor
        gradient: slider.useGradient ? grad : null

        Gradient {
            id: grad
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: slider.gradientFrom
            }
            GradientStop {
                position: 1
                color: slider.gradientTo
            }
        }

        Rectangle {
            visible: !slider.useGradient
            height: parent.height
            width: handle.x + handle.width / 2
            radius: height / 2
            color: slider.accent
        }
    }

    Rectangle {
        id: handle
        width: 20
        height: 20
        radius: 10
        anchors.verticalCenter: parent.verticalCenter
        x: slider.frac * (slider.width - width)
        color: slider.useGradient ? Appearance.m3colors.m3onSurface : slider.accent
        border.width: 3
        border.color: Appearance.colors.colLayer1
        scale: mouse.pressed ? 1.15 : mouse.containsMouse ? 1.07 : 1
        Behavior on scale {
            NumberAnimation {
                duration: 120
            }
        }
        Behavior on x {
            enabled: !slider.dragging
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        enabled: slider.enabledState
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: e => {
            slider._drag = slider.valueAt(e.x - 4);
            slider.moved(slider._drag);
        }
        onPositionChanged: e => {
            if (pressed) {
                slider._drag = slider.valueAt(e.x - 4);
                slider.moved(slider._drag);
            }
        }
        onReleased: slider.released()
        onWheel: e => {
            const d = (e.angleDelta.y > 0 ? 1 : -1) * slider.wheelStep;
            slider.moved(Math.max(slider.from, Math.min(slider.to, slider.value + d)));
        }
    }
}
