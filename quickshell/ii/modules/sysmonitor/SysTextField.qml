import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/** Pill text field with optional leading icon. */
Rectangle {
    id: box

    property string icon: ""
    property alias text: field.text
    property alias placeholderText: field.placeholderText
    property alias field: field
    property bool multiline: false
    signal accepted

    implicitHeight: 40
    implicitWidth: 240
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2
    border.width: field.activeFocus ? 2 : 0
    border.color: Appearance.m3colors.m3primary

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8
        MaterialSymbol {
            visible: box.icon.length > 0
            text: box.icon
            iconSize: 18
            color: Appearance.colors.colSubtext
        }
        TextField {
            id: field
            Layout.fillWidth: true
            background: null
            padding: 0
            color: Appearance.colors.colOnLayer1
            placeholderTextColor: Appearance.colors.colSubtext
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.small
            selectByMouse: true
            onAccepted: box.accepted()
        }
    }
}
