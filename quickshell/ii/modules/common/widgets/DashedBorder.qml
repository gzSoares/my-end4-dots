import QtQuick
import qs.modules.common
import qs.modules.common.functions

Canvas {
    id: root
    property color color: "#ffffff"
    property int dashLength: 6
    property int gapLength: 4
    property int borderWidth: 1
    property real radius: 0
    onRadiusChanged: requestPaint()

    onDashLengthChanged: requestPaint()
    onGapLengthChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        ctx.save();
        ctx.strokeStyle = root.color;
        ctx.lineWidth = root.borderWidth;
        if (root.gapLength > 0) {
            ctx.setLineDash([root.dashLength, root.gapLength]); // Set dash pattern
        }
        const bw = root.borderWidth;
        if (root.radius > 0) {
            const r = Math.min(root.radius, (width - bw) / 2, (height - bw) / 2);
            ctx.beginPath();
            ctx.roundedRect(bw / 2, bw / 2, width - bw, height - bw, r, r);
            ctx.stroke();
        } else {
            ctx.strokeRect(bw / 2, bw / 2, width - bw, height - bw); // Draw it
        }
        ctx.restore();
    }
}
