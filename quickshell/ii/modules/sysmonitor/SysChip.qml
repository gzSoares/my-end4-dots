import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/** Read-only info pill: tinted icon + text. */
Rectangle {
    id: chip

    property string icon: ""
    property string text: ""
    property bool small: false
    property color accent: Appearance.m3colors.m3primary

    implicitHeight: small ? 26 : 34
    implicitWidth: row.implicitWidth + (small ? 18 : 24)
    radius: height / 2
    color: small ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        MaterialSymbol {
            visible: chip.icon.length > 0
            text: chip.icon
            iconSize: chip.small ? 15 : 18
            color: chip.accent
        }
        StyledText {
            text: chip.text
            font.pixelSize: chip.small ? Appearance.font.pixelSize.smaller : Appearance.font.pixelSize.small
            font.family: Appearance.font.family.monospace
            color: Appearance.colors.colOnLayer1
        }
    }
}
