import QtQuick
import qs.modules.common

/**
 * Smooth area graph drawn with Canvas. `values` oldest → newest.
 * With autoScale the max follows the data (for rates like network/disk).
 */
Canvas {
    id: graph

    property var values: []
    property int capacity: 90
    property real maxValue: 1
    property bool autoScale: false
    property real minScale: 1024 * 64     // autoScale floor (64 KiB/s)
    property real scaleOverride: -1       // share a scale between graphs
    property bool inverted: false         // grow from the top (mirrored graphs)
    property bool showGrid: true
    property color lineColor: Appearance.m3colors.m3primary
    property color gridColor: Appearance.m3colors.m3outlineVariant
    property real fillOpacity: 0.32

    readonly property real dataMax: {
        let m = 0;
        for (let i = 0; i < values.length; i++)
            if (values[i] > m)
                m = values[i];
        return m;
    }
    readonly property real effectiveMax: scaleOverride > 0 ? scaleOverride : autoScale ? Math.max(minScale, dataMax * 1.15) : maxValue

    function css(c, a) {
        return `rgba(${Math.round(c.r * 255)},${Math.round(c.g * 255)},${Math.round(c.b * 255)},${a})`;
    }

    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onEffectiveMaxChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const w = width, h = height;
        if (w <= 0 || h <= 0)
            return;

        if (showGrid) {
            ctx.strokeStyle = css(gridColor, 0.35);
            ctx.lineWidth = 1;
            ctx.setLineDash([3, 4]);
            for (let i = 1; i < 4; i++) {
                const y = Math.round(h * i / 4) + 0.5;
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(w, y);
                ctx.stroke();
            }
            ctx.setLineDash([]);
        }

        const n = values.length;
        if (n < 2)
            return;
        const step = w / (capacity - 1);
        const x0 = w - (n - 1) * step;
        const maxV = effectiveMax > 0 ? effectiveMax : 1;
        const base = inverted ? 0 : h;
        const pts = [];
        for (let i = 0; i < n; i++) {
            const v = Math.max(0, Math.min(1, values[i] / maxV));
            pts.push([x0 + i * step, inverted ? v * (h - 2) + 1 : h - v * (h - 2) - 1]);
        }

        const trace = () => {
            ctx.moveTo(pts[0][0], pts[0][1]);
            for (let i = 1; i < pts.length; i++) {
                const mx = (pts[i - 1][0] + pts[i][0]) / 2;
                const my = (pts[i - 1][1] + pts[i][1]) / 2;
                ctx.quadraticCurveTo(pts[i - 1][0], pts[i - 1][1], mx, my);
            }
            ctx.lineTo(pts[pts.length - 1][0], pts[pts.length - 1][1]);
        };

        // area
        const grad = ctx.createLinearGradient(0, inverted ? h : 0, 0, inverted ? 0 : h);
        grad.addColorStop(0, css(lineColor, fillOpacity));
        grad.addColorStop(1, css(lineColor, 0.02));
        ctx.beginPath();
        trace();
        ctx.lineTo(pts[pts.length - 1][0], base);
        ctx.lineTo(pts[0][0], base);
        ctx.closePath();
        ctx.fillStyle = grad;
        ctx.fill();

        // line
        ctx.beginPath();
        trace();
        ctx.strokeStyle = css(lineColor, 1);
        ctx.lineWidth = 2;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.stroke();

        // head dot
        const last = pts[pts.length - 1];
        ctx.beginPath();
        ctx.arc(last[0] - 2, last[1], 3, 0, Math.PI * 2);
        ctx.fillStyle = css(lineColor, 1);
        ctx.fill();
    }
}
