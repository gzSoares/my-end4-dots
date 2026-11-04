import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool vertical: false
    property real padding: {
        const p = Config.options?.bar.groupPadding ?? -1
        return p >= 0 ? p : 5
    }
    readonly property real pillMargin: {
        const m = Config.options?.bar.pillMargin ?? -1
        return m >= 0 ? m : 4
    }
    readonly property real itemSpacing: {
        const s = Config.options?.bar.itemSpacing ?? -1
        return s >= 0 ? s : 4
    }
    // Opt-in glow — when true the group pill picks up a primary border
    // (and a faint primary tint, so the shape stays visible even in
    // line-separated mode where the fill is otherwise transparent).
    property bool glowing: false
    implicitWidth: vertical ? Appearance.sizes.baseVerticalBarWidth : (gridLayout.implicitWidth + padding * 2)
    implicitHeight: vertical ? (gridLayout.implicitHeight + padding * 2) : Appearance.sizes.baseBarHeight
    default property alias items: gridLayout.children

    Rectangle {
        id: background
        anchors {
            fill: parent
            topMargin: root.vertical ? 0 : root.pillMargin
            bottomMargin: root.vertical ? 0 : root.pillMargin
            leftMargin: root.vertical ? root.pillMargin : 0
            rightMargin: root.vertical ? root.pillMargin : 0
        }
        readonly property color baseColor:
            Config.options?.bar.borderless ? "transparent" : Appearance.colors.colBarWidget
        color: root.glowing
            ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.82)
            : baseColor
        radius: Appearance.rounding.barWidget
        border.color: root.glowing ? Appearance.colors.colPrimary : Appearance.colors.colOutline
        border.width: root.glowing ? 1.5
            : (Config.options?.bar.borderless || !(Config.options?.bar.pillOutline ?? true)) ? 0
            : (Config.options?.bar.pillOutlineWidth ?? 1)

        // Subtle top highlight for depth — catches "light" from matugen palette
        Rectangle {
            // Held in from the ends by the corner radius, so the line stays on the
            // straight part of the edge instead of hanging out past the curves.
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: Math.min(Appearance.rounding.barWidget * 0.8, parent.width / 2)
                rightMargin: Math.min(Appearance.rounding.barWidget * 0.8, parent.width / 2)
            }
            height: 1
            color: Appearance.colors.colOnSurface
            opacity: (Config.options?.bar.pillHighlight ?? -1) >= 0 ? Config.options.bar.pillHighlight : 0.08
        }
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        anchors {
            verticalCenter: root.vertical ? undefined : parent.verticalCenter
            horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
            left: root.vertical ? undefined : parent.left
            right: root.vertical ? undefined : parent.right
            top: root.vertical ? parent.top : undefined
            bottom: root.vertical ? parent.bottom : undefined
            margins: root.padding
        }
        columnSpacing: root.itemSpacing
        rowSpacing: 12
    }
}