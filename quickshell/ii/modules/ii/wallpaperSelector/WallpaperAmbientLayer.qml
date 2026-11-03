import qs.modules.common
import QtQuick
import Qt5Compat.GraphicalEffects

// Blurred version of the focused wallpaper that crossfades as focus moves.
Item {
    id: ambient
    property string path: ""
    property real sizeWidth: 0
    property real sizeHeight: 0
    property string shownPath: ""
    property bool switching: false

    onPathChanged: {
        ambient.switching = true;
        swapTimer.restart();
    }
    Component.onCompleted: ambient.shownPath = ambient.path

    // Also debounces fast scrolling through many wallpapers
    Timer {
        id: swapTimer
        interval: 160
        onTriggered: {
            ambient.shownPath = ambient.path;
            ambient.switching = false;
        }
    }

    Loader {
        anchors.fill: parent
        active: ambient.shownPath.length > 0
        sourceComponent: WallpaperThumb {
            sourcePath: ambient.shownPath
            sizeWidth: ambient.sizeWidth
            sizeHeight: ambient.sizeHeight
            opacity: (!ambient.switching && status === Image.Ready) ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
            }
            // Blur is rendered at 1/4 size: looks the same, costs a fraction
            layer.enabled: true
            layer.textureSize: Qt.size(Math.max(1, Math.round(width / 4)), Math.max(1, Math.round(height / 4)))
            layer.effect: FastBlur {
                radius: 24
            }
        }
    }
}
