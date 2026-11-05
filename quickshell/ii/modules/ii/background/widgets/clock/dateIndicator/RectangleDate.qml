
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Rectangle {
    id: rect
    readonly property string dialStyle: Config.options.background.widgets.clock.cookie.dialNumberStyle

    StyledText {
        anchors.centerIn: parent
        color: Appearance.colors.colSecondaryHover
        text: Qt.locale().toString(DateTime.clock.date, "dd")
        font {
            family: Appearance.font.family.expressive
            pixelSize: Appearance.font.pixelSize.larger
            weight: 1000
        }
    }
}
