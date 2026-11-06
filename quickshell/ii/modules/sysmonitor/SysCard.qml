import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * Rounded Material 3 card with an icon bubble + title header.
 * Children go into a ColumnLayout (use Layout.* on them).
 * Put extra header items (chips, values) in `headerItems`.
 */
Rectangle {
    id: card

    property string title: ""
    property string icon: ""
    property string subtitle: ""
    property color accent: Appearance.m3colors.m3primary
    property alias headerItems: headerExtra.data
    default property alias content: body.data
    property int padding: 14

    radius: Appearance.rounding.large
    color: Appearance.colors.colLayer1
    border.width: 1
    border.color: Qt.rgba(Appearance.m3colors.m3outlineVariant.r, Appearance.m3colors.m3outlineVariant.g, Appearance.m3colors.m3outlineVariant.b, 0.35)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: card.padding
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                implicitWidth: 30
                implicitHeight: 30
                radius: width / 2
                color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.16)
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: card.icon
                    iconSize: 18
                    color: card.accent
                }
            }
            ColumnLayout {
                spacing: 0
                StyledText {
                    text: card.title
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    visible: card.subtitle.length > 0
                    text: card.subtitle
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    Layout.maximumWidth: card.width * 0.55
                }
            }
            Item {
                Layout.fillWidth: true
            }
            RowLayout {
                id: headerExtra
                spacing: 8
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
        }
    }
}
