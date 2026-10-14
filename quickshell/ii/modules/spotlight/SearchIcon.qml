import QtQuick
import QtQuick.Shapes

// Magnifying-glass icon (line art, vector — crisp at any size).
// Needs Qt 6.6+ (Shape.CurveRenderer).
Item {
    id: icon

    property color color: "#ffffff"

    implicitWidth: 18
    implicitHeight: 18

    Shape {
        width: 24; height: 24
        scale: icon.width / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            strokeColor: icon.color
            strokeWidth: 2.1
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M3 11a8 8 0 1 0 16 0a8 8 0 1 0 -16 0 M21 21l-4.35-4.35" }
        }
    }
}
