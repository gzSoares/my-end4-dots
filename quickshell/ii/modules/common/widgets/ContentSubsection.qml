import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root
    property string title: ""
    property string tooltip: ""
    // A small symbol before the title, when one is given.
    property string icon: ""
    default property alias contentData: sectionContent.data

    Layout.fillWidth: true
    Layout.topMargin: Appearance.spacing.xs
    spacing: 2

    RowLayout {
        spacing: 6
        MaterialSymbol {
            visible: root.icon !== ""
            text: root.icon
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colSubtext
        }
        ContentSubsectionLabel {
            visible: root.title && root.title.length > 0
            text: root.title
        }
        MaterialSymbol {
            visible: root.tooltip && root.tooltip.length > 0
            text: "info"
            iconSize: Appearance.font.pixelSize.large
            
            color: Appearance.colors.colSubtext
            MouseArea {
                id: infoMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.WhatsThisCursor
                StyledToolTip {
                    extraVisibleCondition: false
                    alternativeVisibleCondition: infoMouseArea.containsMouse
                    text: root.tooltip
                }
            }
        }
        Item { Layout.fillWidth: true }
    }
    ColumnLayout {
        id: sectionContent
        Layout.fillWidth: true
        spacing: 2
    }
}
