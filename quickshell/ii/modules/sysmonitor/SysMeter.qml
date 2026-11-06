import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/** Label + value line with a pill progress bar below. Turns error-colored when high. */
ColumnLayout {
    id: meter

    property string label: ""
    property string valueText: ""
    property string detailText: ""
    property real fraction: 0
    property color barColor: Appearance.m3colors.m3primary
    property bool warn: true
    property real warnAt: 0.85
    property int barHeight: 8
    readonly property color effectiveColor: warn && fraction >= warnAt ? Appearance.m3colors.m3error : barColor

    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        StyledText {
            text: meter.label
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        StyledText {
            visible: meter.detailText.length > 0
            text: meter.detailText
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
        StyledText {
            text: meter.valueText
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            font.family: Appearance.font.family.monospace
            color: meter.effectiveColor
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: meter.barHeight
        radius: height / 2
        color: Appearance.m3colors.m3surfaceContainerHighest

        Rectangle {
            height: parent.height
            width: Math.max(height, parent.width * Math.max(0, Math.min(1, meter.fraction)))
            radius: height / 2
            color: meter.effectiveColor
            opacity: meter.fraction > 0.002 ? 1 : 0
            Behavior on width {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 250
                }
            }
        }
    }
}
