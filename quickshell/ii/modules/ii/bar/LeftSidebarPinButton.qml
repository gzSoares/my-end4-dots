import QtQuick
import qs
import qs.modules.common
import qs.modules.common.widgets

/*
 * Pins and unpins the left sidebar, next to the button that opens it. Only there
 * while the sidebar is open, and not at all while it is detached (a window has
 * nothing to pin).
 */
RippleButton {
    id: root

    readonly property bool shown: GlobalStates.sidebarLeftOpen && !GlobalStates.sidebarLeftDetached
    visible: shown

    implicitWidth: shown ? 30 : 0
    implicitHeight: 30
    buttonRadius: Appearance.rounding.full
    colBackground: "transparent"
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active
    colBackgroundToggled: Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.colors.colSecondaryContainerActive
    toggled: GlobalStates.sidebarLeftPinned

    onClicked: GlobalStates.sidebarLeftTogglePin()

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "keep"
        fill: GlobalStates.sidebarLeftPinned ? 1 : 0
        iconSize: Appearance.font.pixelSize.larger
        color: GlobalStates.sidebarLeftPinned
            ? Appearance.colors.colOnSecondaryContainer
            : Appearance.colors.colOnLayer0
    }

    StyledToolTip {
        text: GlobalStates.sidebarLeftPinned
            ? Translation.tr("Unpin the sidebar (Ctrl+P)")
            : Translation.tr("Pin the sidebar (Ctrl+P)")
    }
}
