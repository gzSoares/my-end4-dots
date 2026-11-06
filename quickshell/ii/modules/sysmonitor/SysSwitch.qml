import QtQuick
import qs.modules.common
import qs.modules.common.widgets

/** Material 3 switch. Bind `checked`, react to `toggled(bool)`. */
Rectangle {
    id: sw

    property bool checked: false
    property bool enabledState: true
    signal toggled(bool on)

    implicitWidth: 52
    implicitHeight: 30
    radius: height / 2
    color: checked ? Appearance.m3colors.m3primary : Appearance.m3colors.m3surfaceContainerHighest
    border.width: checked ? 0 : 2
    border.color: Appearance.m3colors.m3outline
    opacity: enabledState ? 1 : 0.45
    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Rectangle {
        width: sw.checked ? 22 : 16
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: sw.checked ? parent.width - width - 4 : 7
        color: sw.checked ? Appearance.m3colors.m3onPrimary : Appearance.m3colors.m3outline
        Behavior on x {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 160
            }
        }
        MaterialSymbol {
            anchors.centerIn: parent
            visible: sw.checked
            text: "check"
            iconSize: 15
            color: Appearance.m3colors.m3primary
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: sw.enabledState
        onClicked: sw.toggled(!sw.checked)
    }
}
