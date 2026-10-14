import QtQuick

// Media icon drawn on a Canvas: same size and center for every kind,
// independent of each glyph's font metrics.
Canvas {
    id: glyph

    property string kind: "play"   // "previous" | "next" | "play" | "pause"
    property color fg: "#ffffff"

    width: 14
    height: 14

    onFgChanged: requestPaint()
    onKindChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = fg;
        ctx.strokeStyle = fg;
        ctx.lineWidth = 1.4;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.beginPath();
        if (kind === "previous") {
            ctx.rect(2.2, 2.7, 1.6, 8.6);
            ctx.moveTo(11.8, 2.7); ctx.lineTo(11.8, 11.3); ctx.lineTo(5.4, 7); ctx.closePath();
        } else if (kind === "next") {
            ctx.rect(10.2, 2.7, 1.6, 8.6);
            ctx.moveTo(2.2, 2.7); ctx.lineTo(2.2, 11.3); ctx.lineTo(8.6, 7); ctx.closePath();
        } else if (kind === "pause") {
            ctx.rect(3.6, 2.6, 2.2, 8.8);
            ctx.rect(8.2, 2.6, 2.2, 8.8);
        } else {
            ctx.moveTo(4.4, 2.4); ctx.lineTo(4.4, 11.6); ctx.lineTo(11.6, 7); ctx.closePath();
        }
        ctx.fill();
        ctx.stroke();
    }
}
