import QtQuick

/*
 * The drawing surface of the screenshot editor: an image and the marks put on
 * it, at the image's own pixel size (the window shows it scaled to fit, and
 * what is saved is the real thing). Free of shell imports on purpose, so it
 * can be driven and checked on its own.
 *
 * Tools: brush, text, rect, oval, arrow, pixelate. Every mark is kept as data
 * until it is saved, which is what makes undo and redo plain list moves.
 *
 * Two canvases: `base` holds the image and the finished marks; `live` holds the
 * mark being drawn right now. Keeping them apart lets pixelate read clean
 * pixels from `base`, and keeps a brush stroke from repainting everything.
 */
Item {
    id: root

    property url source: ""
    property string tool: "brush"      // brush | text | rect | oval | arrow | pixelate
    property color color: "#ff0000"
    property real lineWidth: 5
    property real textSize: 20
    property bool fillShape: false
    property real pixelBlock: 12

    readonly property alias imageWidth: base.width
    readonly property alias imageHeight: base.height
    readonly property bool loaded: base.imageReady && base.width > 1
    readonly property bool canUndo: root.revision >= 0 && root.marks.length > 0
    readonly property bool canRedo: root.revision >= 0 && root.undone.length > 0
    readonly property bool hasMarks: root.canUndo

    // Bumped on every change to the lists, so the can* flags re-read them.
    property int revision: 0
    property var marks: []
    property var undone: []
    property var current: null

    signal saved(string path, bool ok)
    readonly property bool textEditing: textBox.visible

    implicitWidth: base.width
    implicitHeight: base.height
    width: base.width
    height: base.height

    // ── Marks ──────────────────────────────────────────────────────
    function addMark(mark) {
        root.marks = root.marks.concat([mark]);
        root.undone = [];
        root.revision++;
        base.requestPaint();
    }
    function undo() {
        if (root.marks.length === 0) return;
        const last = root.marks[root.marks.length - 1];
        root.marks = root.marks.slice(0, -1);
        root.undone = root.undone.concat([last]);
        root.revision++;
        base.requestPaint();
    }
    function redo() {
        if (root.undone.length === 0) return;
        const last = root.undone[root.undone.length - 1];
        root.undone = root.undone.slice(0, -1);
        root.marks = root.marks.concat([last]);
        root.revision++;
        base.requestPaint();
    }
    function clearMarks() {
        if (root.marks.length === 0) return;
        root.undone = root.marks.slice().reverse().concat(root.undone);
        root.marks = [];
        root.revision++;
        base.requestPaint();
    }

    // Pixelate: the region's colors are read once, from the canvas as it stands
    // when the mark is made, and kept as blocks. Redrawing never reads pixels.
    function pixelateMark(x, y, w, h) {
        x = Math.max(0, Math.round(x));
        y = Math.max(0, Math.round(y));
        w = Math.min(base.width - x, Math.round(w));
        h = Math.min(base.height - y, Math.round(h));
        if (w < 2 || h < 2) return null;
        const ctx = base.getContext("2d");
        const data = ctx.getImageData(x, y, w, h).data;
        const size = Math.max(2, Math.round(root.pixelBlock));
        const blocks = [];
        for (let by = 0; by < h; by += size) {
            for (let bx = 0; bx < w; bx += size) {
                const bw = Math.min(size, w - bx);
                const bh = Math.min(size, h - by);
                let r = 0, g = 0, b = 0, n = 0;
                // Average of a sparse grid inside the block: cheap and smooth enough
                const stepX = Math.max(1, Math.floor(bw / 4));
                const stepY = Math.max(1, Math.floor(bh / 4));
                for (let py = 0; py < bh; py += stepY) {
                    for (let px = 0; px < bw; px += stepX) {
                        const i = ((by + py) * w + (bx + px)) * 4;
                        r += data[i]; g += data[i + 1]; b += data[i + 2]; n++;
                    }
                }
                blocks.push({
                    x: x + bx, y: y + by, w: bw, h: bh,
                    c: "rgb(" + Math.round(r / n) + "," + Math.round(g / n) + "," + Math.round(b / n) + ")"
                });
            }
        }
        return { t: "pixelate", x: x, y: y, w: w, h: h, blocks: blocks };
    }

    // ── Drawing ────────────────────────────────────────────────────
    function drawMark(ctx, m) {
        ctx.save();
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        switch (m.t) {
        case "brush": {
            ctx.strokeStyle = m.color;
            ctx.lineWidth = m.lw;
            ctx.beginPath();
            const p = m.pts;
            ctx.moveTo(p[0][0], p[0][1]);
            if (p.length === 1) ctx.lineTo(p[0][0] + 0.01, p[0][1]);
            for (let i = 1; i < p.length; i++) ctx.lineTo(p[i][0], p[i][1]);
            ctx.stroke();
            break;
        }
        case "rect":
            if (m.fill) {
                ctx.fillStyle = m.color;
                ctx.fillRect(m.x, m.y, m.w, m.h);
            } else {
                ctx.strokeStyle = m.color;
                ctx.lineWidth = m.lw;
                ctx.strokeRect(m.x, m.y, m.w, m.h);
            }
            break;
        case "oval": {
            const cx = m.x + m.w / 2, cy = m.y + m.h / 2;
            const rx = Math.max(0.5, m.w / 2), ry = Math.max(0.5, m.h / 2);
            const k = 0.5522847498;
            ctx.beginPath();
            ctx.moveTo(cx + rx, cy);
            ctx.bezierCurveTo(cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry);
            ctx.bezierCurveTo(cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy);
            ctx.bezierCurveTo(cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry);
            ctx.bezierCurveTo(cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy);
            ctx.closePath();
            if (m.fill) {
                ctx.fillStyle = m.color;
                ctx.fill();
            } else {
                ctx.strokeStyle = m.color;
                ctx.lineWidth = m.lw;
                ctx.stroke();
            }
            break;
        }
        case "arrow": {
            const dx = m.x2 - m.x1, dy = m.y2 - m.y1;
            const len = Math.sqrt(dx * dx + dy * dy);
            if (len < 1) break;
            const ang = Math.atan2(dy, dx);
            const head = Math.min(len * 0.6, Math.max(14, m.lw * 4));
            ctx.strokeStyle = m.color;
            ctx.fillStyle = m.color;
            ctx.lineWidth = m.lw;
            // The shaft stops inside the head so the tip stays sharp
            const sx = m.x2 - Math.cos(ang) * head * 0.7;
            const sy = m.y2 - Math.sin(ang) * head * 0.7;
            ctx.beginPath();
            ctx.moveTo(m.x1, m.y1);
            ctx.lineTo(sx, sy);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(m.x2, m.y2);
            ctx.lineTo(m.x2 - head * Math.cos(ang - 0.45), m.y2 - head * Math.sin(ang - 0.45));
            ctx.lineTo(m.x2 - head * Math.cos(ang + 0.45), m.y2 - head * Math.sin(ang + 0.45));
            ctx.closePath();
            ctx.fill();
            break;
        }
        case "text": {
            ctx.fillStyle = m.color;
            ctx.font = m.size + "px sans-serif";
            ctx.textBaseline = "top";
            const lines = m.text.split("\n");
            for (let i = 0; i < lines.length; i++)
                ctx.fillText(lines[i], m.x, m.y + i * m.size * 1.2);
            break;
        }
        case "pixelate":
            for (let i = 0; i < m.blocks.length; i++) {
                const b = m.blocks[i];
                ctx.fillStyle = b.c;
                ctx.fillRect(b.x, b.y, b.w, b.h);
            }
            break;
        }
        ctx.restore();
    }

    Canvas {
        id: base
        property bool imageReady: false
        renderStrategy: Canvas.Cooperative
        renderTarget: Canvas.Image
        width: 1
        height: 1

        onImageLoaded: {
            imageReady = true;
            requestPaint();
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (imageReady) ctx.drawImage(root.source, 0, 0);
            for (let i = 0; i < root.marks.length; i++) root.drawMark(ctx, root.marks[i]);
        }
    }

    Canvas {
        id: live
        width: base.width
        height: base.height
        renderStrategy: Canvas.Cooperative
        renderTarget: Canvas.Image
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const m = root.current;
            if (!m) return;
            if (m.t === "pixelate") {
                ctx.strokeStyle = "#ffffff";
                ctx.lineWidth = 2;
                ctx.strokeRect(m.x, m.y, m.w, m.h);
                ctx.strokeStyle = "#000000";
                ctx.lineWidth = 1;
                ctx.strokeRect(m.x + 2, m.y + 2, m.w - 4, m.h - 4);
            } else {
                root.drawMark(ctx, m);
            }
        }
    }

    onSourceChanged: {
        base.imageReady = false;
        root.marks = [];
        root.undone = [];
        root.current = null;
        root.revision++;
        if (root.source.toString() === "") return;
        base.loadImage(root.source);
    }

    // The canvas takes the image's size once the image is there
    Image {
        id: probe
        source: root.source
        visible: false
        asynchronous: false
        onStatusChanged: {
            if (status === Image.Ready) {
                base.width = implicitWidth;
                base.height = implicitHeight;
                base.requestPaint();
            }
        }
    }

    // ── Input ──────────────────────────────────────────────────────
    function commitText() {
        if (!textBox.visible) return;
        const text = textField.text;
        textBox.visible = false;
        textField.text = "";
        if (text.trim().length === 0) return;
        root.addMark({
            t: "text", x: textBox.x, y: textBox.y, text: text,
            color: "" + root.color, size: root.textSize
        });
    }
    function cancelText() {
        textBox.visible = false;
        textField.text = "";
    }

    onToolChanged: root.commitText()

    MouseArea {
        id: area
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: root.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
        property real sx: 0
        property real sy: 0

        onPressed: mouse => {
            if (textBox.visible) {
                root.commitText();
                // A click that only closes the text box does not also start another
                if (root.tool === "text") return;
            }
            sx = mouse.x;
            sy = mouse.y;
            const col = "" + root.color;
            switch (root.tool) {
            case "text":
                textBox.x = mouse.x;
                textBox.y = mouse.y;
                textBox.visible = true;
                textField.forceActiveFocus();
                return;
            case "brush":
                root.current = { t: "brush", pts: [[mouse.x, mouse.y]], color: col, lw: root.lineWidth };
                break;
            case "arrow":
                root.current = { t: "arrow", x1: mouse.x, y1: mouse.y, x2: mouse.x, y2: mouse.y, color: col, lw: root.lineWidth };
                break;
            default: // rect, oval, pixelate
                root.current = { t: root.tool, x: mouse.x, y: mouse.y, w: 0, h: 0, color: col, lw: root.lineWidth, fill: root.fillShape };
            }
            live.requestPaint();
        }
        onPositionChanged: mouse => {
            const m = root.current;
            if (!m) return;
            if (m.t === "brush") {
                m.pts.push([mouse.x, mouse.y]);
            } else if (m.t === "arrow") {
                m.x2 = mouse.x;
                m.y2 = mouse.y;
            } else {
                m.x = Math.min(sx, mouse.x);
                m.y = Math.min(sy, mouse.y);
                m.w = Math.abs(mouse.x - sx);
                m.h = Math.abs(mouse.y - sy);
            }
            live.requestPaint();
        }
        onReleased: mouse => {
            const m = root.current;
            root.current = null;
            live.requestPaint();
            if (!m) return;
            if (m.t === "pixelate") {
                const p = root.pixelateMark(m.x, m.y, m.w, m.h);
                if (p) root.addMark(p);
            } else if (m.t === "arrow") {
                if (Math.abs(m.x2 - m.x1) + Math.abs(m.y2 - m.y1) > 3) root.addMark(m);
            } else if (m.t === "rect" || m.t === "oval") {
                if (m.w > 2 || m.h > 2) root.addMark(m);
            } else {
                root.addMark(m);
            }
        }
        onCanceled: {
            root.current = null;
            live.requestPaint();
        }
    }

    // The text being typed, right where the click was. Multi-line: Enter adds a
    // line, Ctrl+Enter or a click elsewhere finishes, Escape drops it.
    Item {
        id: textBox
        visible: false
        width: Math.max(40, textField.contentWidth + 12)
        height: Math.max(root.textSize * 1.2, textField.contentHeight) + 8

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: "#80ffffff"
        }
        TextEdit {
            id: textField
            x: 6
            y: 4
            color: root.color
            font.pixelSize: root.textSize
            font.family: "sans-serif"
            selectByMouse: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.cancelText();
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                           && (event.modifiers & Qt.ControlModifier)) {
                    root.commitText();
                    event.accepted = true;
                }
            }
        }
    }

    // ── Output ─────────────────────────────────────────────────────
    // Writes the picture and marks to `path` (PNG by its suffix) and says how it
    // went through `saved`. The canvas writes it itself; if that fails, the
    // item is rendered and written instead.
    function save(path) {
        root.commitText();
        if (base.save(path)) {
            root.saved(path, true);
            return;
        }
        root.grabToImage(result => root.saved(path, result.saveToFile(path)), Qt.size(base.width, base.height));
    }
}
