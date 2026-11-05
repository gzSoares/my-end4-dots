import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * The label that opens a group of sections on a settings page: a small
 * capitalised name and a thin line running out to the edge.
 *
 * It is a sibling of the sections, never a box around them. A page finds a
 * section by name among its own direct children (see ContentPage), and that
 * link from elsewhere in the shell would stop working for any section pushed
 * a level down.
 */
RowLayout {
    id: root
    property string text: ""

    Layout.fillWidth: true
    Layout.topMargin: 10
    Layout.leftMargin: Appearance.spacing.xs
    spacing: Appearance.spacing.md

    StyledText {
        text: root.text.toUpperCase()
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.Medium
        font.letterSpacing: 1.2
        color: Appearance.colors.colPrimary
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        implicitHeight: 1
        color: Appearance.colors.colLayer0Border
    }
}
