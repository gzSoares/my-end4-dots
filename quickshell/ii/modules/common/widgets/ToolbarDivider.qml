import QtQuick
import QtQuick.Layouts
import qs.modules.common

// The thin vertical rule between groups of buttons in a Toolbar
Rectangle {
    implicitWidth: 1
    implicitHeight: 22
    Layout.alignment: Qt.AlignVCenter
    Layout.leftMargin: Appearance.spacing.xs
    Layout.rightMargin: Appearance.spacing.xs
    color: Appearance.colors.colOutlineVariant
}
