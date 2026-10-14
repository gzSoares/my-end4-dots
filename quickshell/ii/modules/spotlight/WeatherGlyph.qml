import QtQuick
import QtQuick.Shapes

// Line-art weather icon (24x24 icon paths, scaled to the item's width).
// Needs Qt 6.6+ (Shape.CurveRenderer).
// kind: clear | clear-night | partly | partly-night | cloud | fog | drizzle | rain | snow | storm
Item {
    id: glyph

    property string kind: "cloud"
    property color fg: "#ffffff"
    readonly property color sunColor: "#FF9F0A"
    readonly property color moonColor: "#A9A6F0"

    implicitWidth: 24
    implicitHeight: 24

    // icon paths (Feather / Lucide, 24x24 viewBox)
    readonly property string pSun: "M7 12a5 5 0 1 0 10 0a5 5 0 1 0 -10 0 M12 1v2 M12 21v2 M4.22 4.22l1.42 1.42 M18.36 18.36l1.42 1.42 M1 12h2 M21 12h2 M4.22 19.78l1.42-1.42 M18.36 5.64l1.42-1.42"
    readonly property string pMoon: "M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"
    readonly property string pPartSun: "M12 2v2 M4.93 4.93l1.41 1.41 M20 12h2 M19.07 4.93l-1.41 1.41 M15.947 12.65a4 4 0 0 0-5.925-4.128"
    readonly property string pPartCloud: "M13 22H7a5 5 0 1 1 4.9-6H13a3 3 0 0 1 0 6Z"
    readonly property string pCloud: "M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z"
    readonly property string pFog: "M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242 M16 17H7 M17 21H9"
    readonly property string pDrizzle: "M8 19v2 M8 13v2 M16 19v2 M16 13v2 M12 21v2 M12 15v2 M20 16.58A5 5 0 0 0 18 7h-1.26A8 8 0 1 0 4 15.25"
    readonly property string pRain: "M16 13v8 M8 13v8 M12 15v8 M20 16.58A5 5 0 0 0 18 7h-1.26A8 8 0 1 0 4 15.25"
    readonly property string pSnow: "M20 17.58A5 5 0 0 0 18 8h-1.26A8 8 0 1 0 4 16.25 M8 16h.01 M8 20h.01 M12 18h.01 M12 22h.01 M16 16h.01 M16 20h.01"
    readonly property string pStorm: "M19 16.9A5 5 0 0 0 18 7h-1.26a8 8 0 1 0-11.62 9 M13 11l-4 6h6l-4 6"

    // sun / moon part (drawn in orange or lavender)
    readonly property string accentPath: {
        switch (kind) {
        case "clear":        return pSun;
        case "clear-night":  return pMoon;
        case "partly":       return pPartSun;
        case "partly-night": return pMoon;
        default:             return "M0 0";
        }
    }
    // cloud / precipitation part (drawn in fg)
    readonly property string mainPath: {
        switch (kind) {
        case "partly":
        case "partly-night": return pPartCloud;
        case "cloud":        return pCloud;
        case "fog":          return pFog;
        case "drizzle":      return pDrizzle;
        case "rain":         return pRain;
        case "snow":         return pSnow;
        case "storm":        return pStorm;
        default:             return "M0 0";
        }
    }
    readonly property color accentColor: kind.indexOf("night") >= 0 ? moonColor : sunColor
    // the small moon behind the cloud in "partly-night"
    readonly property real accentScale: kind === "partly-night" ? 0.62 : 1.0
    readonly property real u: width / 24

    Shape {
        x: kind === "partly-night" ? 10.5 * glyph.u : 0
        y: kind === "partly-night" ? 1.0 * glyph.u : 0
        width: 24; height: 24
        scale: glyph.u * glyph.accentScale
        transformOrigin: Item.TopLeft
        // curves are rendered at the final resolution (no intermediate bitmap, so no pixelation)
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        ShapePath {
            strokeColor: glyph.accentColor
            strokeWidth: 1.8 / glyph.accentScale
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: glyph.accentPath }
        }
    }

    Shape {
        width: 24; height: 24
        scale: glyph.u
        transformOrigin: Item.TopLeft
        // curves are rendered at the final resolution (no intermediate bitmap, so no pixelation)
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        ShapePath {
            strokeColor: glyph.fg
            strokeWidth: 1.8
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: glyph.mainPath }
        }
    }
}
