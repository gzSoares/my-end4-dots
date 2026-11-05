import QtQuick
import QtQuick.Controls
import qs.modules.common

// The window of a standalone Quickshell app (screenshot editor, recorder,
// video editor...). Transparent, with the shell's translucent layer and a
// hairline panel border painted inside, so the compositor's blur shows through
// the same way for all of them. Children go onto that surface.
ApplicationWindow {
    id: window
    default property alias content: surface.data
    color: "transparent"

    Rectangle {
        id: surface
        anchors.fill: parent
        color: Appearance.colors.colLayer0
        border.width: Appearance.panel.borderWidth
        border.color: Appearance.panel.borderColor
    }
}
