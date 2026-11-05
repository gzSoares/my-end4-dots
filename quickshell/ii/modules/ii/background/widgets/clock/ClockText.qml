import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

StyledText {
    Layout.fillWidth: true
    font {
        family: Appearance.font.family.expressive
        pixelSize: Appearance.font.pixelSize.larger
        weight: 350
        // Set empty to prevent conflicts, not meaningless
        styleName: ""
        variableAxes: ({})
    }
    style: Text.Raised
    styleColor: Appearance.colors.colShadow
    animateChange: Config.options.background.widgets.clock.digital.animateChange
}