import QtQuick
import QtQuick.Layouts
import qs.modules.common

// A round Toolbar button with a Material symbol, an optional short label
// beside it and a tooltip. Shared by the screenshot editor, the screen
// recorder and the video editor so the three keep the same look.
RippleButton {
    id: root
    // Not "icon": the button already has a final property of that name
    property string symbol
    property string tip
    property string label: ""
    implicitWidth: label.length > 0 ? 40 + labelText.implicitWidth + 4 : 40
    implicitHeight: 40
    buttonRadius: Appearance.rounding.full
    opacity: enabled ? 1 : 0.4
    contentItem: Row {
        anchors.centerIn: parent
        spacing: 2
        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: root.symbol
            fill: root.toggled ? 1 : 0
            iconSize: Appearance.font.pixelSize.larger
            color: root.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
        }
        StyledText {
            id: labelText
            visible: root.label.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
        }
    }
    StyledToolTip { text: root.tip }
}
