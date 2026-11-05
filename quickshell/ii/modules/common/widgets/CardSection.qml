import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// A ContentSection drawn as a card: the same title, icon and slots, set on a
// raised surface so a page of many sections reads as groups instead of one long
// list. It takes the same properties, so a page switches between the two by
// changing the name — and every page that keeps ContentSection looks as before.
Rectangle {
    id: root
    property string title
    property string icon: ""
    property bool mirrorIcon: false
    // titleExtra sits against the title; headerExtra is pushed to the far end
    // of the row by the spacer between them.
    property alias titleExtra: titleExtraContainer.data
    property alias headerExtra: headerExtraContainer.data
    default property alias contentData: sectionContent.data
    property real padding: 14

    Layout.fillWidth: true
    implicitWidth: inner.implicitWidth + padding * 2
    implicitHeight: inner.implicitHeight + padding * 2

    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    border.width: 1
    border.color: Appearance.colors.colLayer0Border

    ColumnLayout {
        id: inner
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: 10

        RowLayout {
            id: titleRow
            Layout.fillWidth: true
            spacing: 10

            // The icon sits on a small tinted tile so the eye finds the start
            // of a section before it reads the words.
            Rectangle {
                id: iconTile
                visible: root.icon !== ""
                implicitWidth: 34
                implicitHeight: 34
                radius: Appearance.rounding.small
                color: Appearance.colors.colSecondaryContainer

                MaterialSymbol {
                    id: tileSymbol
                    anchors.centerIn: parent
                    text: root.icon
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSecondaryContainer
                    transform: Scale { xScale: root.mirrorIcon ? -1 : 1; origin.x: tileSymbol.width / 2 }
                }
            }

            StyledText {
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
                // Wraps within what the row has left rather than widening it, as
                // ContentSection does: a title longer than the column must not
                // push the whole page wider.
                wrapMode: Text.Wrap
                Layout.maximumWidth: Math.max(0, titleRow.width - (iconTile.visible ? iconTile.width : 0)
                    - titleExtraContainer.implicitWidth - headerExtraContainer.implicitWidth - titleRow.spacing * 4)
            }

            RowLayout {
                id: titleExtraContainer
                spacing: Appearance.spacing.sm
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                id: headerExtraContainer
                spacing: Appearance.spacing.sm
            }
        }

        ColumnLayout {
            id: sectionContent
            Layout.fillWidth: true
            spacing: Appearance.spacing.xs
        }
    }
}
