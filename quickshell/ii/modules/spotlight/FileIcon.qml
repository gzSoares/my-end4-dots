import QtQuick
import QtQuick.Shapes

// Document icon (white page, folded corner, blue title line + gray text lines)
// or a folder when `folder` is true. Drawn as vector curves, crisp at any size.
// Needs Qt 6.6+ (Shape.CurveRenderer).
Item {
    id: icon

    property bool folder: false
    property color pageColor: "#F3F4F7"
    property color foldColor: "#C9CCD6"
    property color titleColor: "#4F86E8"
    property color lineColor: "#A9AEBB"
    property color folderBack: "#3E8EF0"
    property color folderFront: "#64B0FF"

    implicitWidth: 28
    implicitHeight: 28
    readonly property real u: width / 28

    // ---- document
    Shape {
        visible: !icon.folder
        width: 28; height: 28
        scale: icon.u
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {   // page
            strokeColor: Qt.rgba(0, 0, 0, 0.16); strokeWidth: 0.7
            fillColor: icon.pageColor
            PathSvg { path: "M7 2 H17 L23 8 V24 A2 2 0 0 1 21 26 H7 A2 2 0 0 1 5 24 V4 A2 2 0 0 1 7 2 Z" }
        }
        ShapePath {   // folded corner
            strokeColor: "transparent"
            fillColor: icon.foldColor
            PathSvg { path: "M17 2 V6 A2 2 0 0 0 19 8 H23 Z" }
        }
        ShapePath {   // title line
            strokeColor: icon.titleColor; strokeWidth: 1.9
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M8.5 13 H19.5" }
        }
        ShapePath {   // text lines
            strokeColor: icon.lineColor; strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M8.5 17 H19.5 M8.5 20.5 H15.5" }
        }
    }

    // ---- folder
    Shape {
        visible: icon.folder
        width: 28; height: 28
        scale: icon.u
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {   // back + tab
            strokeColor: "transparent"
            fillColor: icon.folderBack
            PathSvg { path: "M3 8 A2 2 0 0 1 5 6 H11 L14 9 H23 A2 2 0 0 1 25 11 V22 A2 2 0 0 1 23 24 H5 A2 2 0 0 1 3 22 Z" }
        }
        ShapePath {   // front
            strokeColor: "transparent"
            fillColor: icon.folderFront
            PathSvg { path: "M3 12 A2 2 0 0 1 5 10 H23 A2 2 0 0 1 25 12 V22 A2 2 0 0 1 23 24 H5 A2 2 0 0 1 3 22 Z" }
        }
    }
}
