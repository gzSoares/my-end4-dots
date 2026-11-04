import QtQuick
import QtQuick.Effects
import qs.modules.common

RectangularShadow {
    required property var target
    // Scales the blur; the bar sets it from its shadow size option.
    property real blurScale: 1
    anchors.fill: target
    radius: target.radius
    blur: 0.9 * Appearance.sizes.elevationMargin * blurScale
    offset: Qt.vector2d(0.0, 1.0)
    spread: 1
    color: Appearance.colors.colShadow
    cached: true
}
