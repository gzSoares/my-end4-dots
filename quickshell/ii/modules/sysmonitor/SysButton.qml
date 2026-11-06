import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/** Small pill button: optional icon + text. `tonal` uses secondaryContainer, `danger` uses error colors. */
Rectangle {
    id: btn

    property string icon: ""
    property string text: ""
    property bool tonal: false
    property bool danger: false
    property bool toggled: false
    property bool enabledState: true
    property string tooltip: ""
    signal clicked

    readonly property color fg: !enabledState ? Appearance.colors.colSubtext : danger ? Appearance.m3colors.m3onErrorContainer : (tonal || toggled) ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
    readonly property color bg: danger ? Appearance.m3colors.m3errorContainer : (tonal || toggled) ? Appearance.m3colors.m3secondaryContainer : Appearance.colors.colLayer2

    implicitHeight: 32
    implicitWidth: row.implicitWidth + (text.length > 0 ? 24 : 16)
    radius: height / 2
    color: bg
    opacity: enabledState ? 1 : 0.55

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: btn.fg
        opacity: mouse.pressed ? 0.16 : mouse.containsMouse ? 0.08 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        MaterialSymbol {
            visible: btn.icon.length > 0
            text: btn.icon
            iconSize: 18
            color: btn.fg
        }
        StyledText {
            visible: btn.text.length > 0
            text: btn.text
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: btn.fg
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: btn.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (btn.enabledState)
            btn.clicked()
    }
}
