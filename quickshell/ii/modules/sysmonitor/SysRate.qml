import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/** Icon bubble + label / big value / small total — used for network rates. */
RowLayout {
    id: rate

    property string icon: ""
    property string label: ""
    property string value: ""
    property string total: ""
    property color accent: Appearance.m3colors.m3primary

    spacing: 10

    Rectangle {
        implicitWidth: 30
        implicitHeight: 30
        radius: width / 2
        color: Qt.rgba(rate.accent.r, rate.accent.g, rate.accent.b, 0.16)
        MaterialSymbol {
            anchors.centerIn: parent
            text: rate.icon
            iconSize: 18
            color: rate.accent
        }
    }
    ColumnLayout {
        spacing: 0
        Layout.fillWidth: true
        StyledText {
            text: rate.label
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
        }
        StyledText {
            text: rate.value
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.DemiBold
            font.family: Appearance.font.family.monospace
            color: Appearance.colors.colOnLayer1
        }
        StyledText {
            text: rate.total
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
        }
    }
}
