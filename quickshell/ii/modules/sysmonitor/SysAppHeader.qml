import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/** Shared window header for the ii apps: icon tile, title, subtitle, trailing items, close button. */
RowLayout {
    id: header

    property string icon: "apps"
    property string title: ""
    property string subtitle: ""
    default property alias trailing: extra.data
    signal closeRequested

    Layout.fillWidth: true
    spacing: 12

    Rectangle {
        implicitWidth: 42
        implicitHeight: 42
        radius: Appearance.rounding.normal
        color: Appearance.m3colors.m3primaryContainer
        MaterialSymbol {
            anchors.centerIn: parent
            text: header.icon
            iconSize: 24
            color: Appearance.m3colors.m3onPrimaryContainer
        }
    }
    ColumnLayout {
        spacing: 0
        Layout.fillWidth: true
        StyledText {
            text: header.title
            font.pixelSize: Appearance.font.pixelSize.larger
            font.weight: Font.Bold
            color: Appearance.colors.colOnLayer0
        }
        StyledText {
            visible: header.subtitle.length > 0
            text: header.subtitle
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
    RowLayout {
        id: extra
        spacing: 8
    }
    SysButton {
        icon: "close"
        implicitHeight: 34
        implicitWidth: 34
        onClicked: header.closeRequested()
    }
}
