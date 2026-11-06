import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/** Bottom snackbar. Call show(text, ok). Anchor it yourself (usually bottom center of the window). */
Rectangle {
    id: toast

    property string text: ""
    property bool ok: true
    property bool shown: false

    function show(t, isOk) {
        toast.text = t;
        toast.ok = isOk === undefined ? true : isOk;
        toast.shown = true;
        timer.restart();
    }

    z: 100
    implicitHeight: 42
    implicitWidth: row.implicitWidth + 32
    radius: height / 2
    color: ok ? Appearance.m3colors.m3inverseSurface : Appearance.m3colors.m3errorContainer
    opacity: shown ? 1 : 0
    visible: opacity > 0
    transform: Translate {
        y: toast.shown ? 0 : 24
        Behavior on y {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 180
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8
        MaterialSymbol {
            text: toast.ok ? "check_circle" : "error"
            iconSize: 18
            color: toast.ok ? Appearance.m3colors.m3inverseOnSurface : Appearance.m3colors.m3onErrorContainer
        }
        StyledText {
            text: toast.text
            font.pixelSize: Appearance.font.pixelSize.small
            color: toast.ok ? Appearance.m3colors.m3inverseOnSurface : Appearance.m3colors.m3onErrorContainer
        }
    }
    Timer {
        id: timer
        interval: 2800
        onTriggered: toast.shown = false
    }
}
