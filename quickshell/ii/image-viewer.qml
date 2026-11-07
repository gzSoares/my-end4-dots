//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// image-viewer.qml — an image viewer in the shell's own look.
//
// Qt reads most formats directly, among them HEIC, AVIF, JXL, camera RAW, PSD,
// XCF and EXR through kimageformats. A file it refuses goes through ImageMagick
// into a cached PNG, so the original is never touched. Rotating and flipping
// only change the view.
//
// Open it with viewer/mainstream-viewer [files or a folder...]
// Needs: kimageformats, qt6-imageformats, qt6-svg, imagemagick.

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ApplicationWindow {
    id: root
    visible: true
    width: 1100
    height: 720
    minimumWidth: 520
    minimumHeight: 360
    color: Appearance.m3colors.m3background
    title: root.currentPath ? root.fileName + " — Images" : "Images"

    // What counts as an image when walking through a folder.
    readonly property var imageExtensions: ["png", "jpg", "jpeg", "jpe", "jfif", "gif", "webp", "avif", "heic", "heif",
        "jxl", "bmp", "dib", "tif", "tiff", "svg", "svgz", "ico", "cur", "icns", "tga", "psd", "psb", "xcf", "kra", "ora",
        "exr", "hdr", "dds", "jp2", "j2k", "jpx", "jxr", "qoi", "pcx", "ppm", "pgm", "pbm", "pnm", "pam", "pfm", "xbm", "xpm", "sgi",
        "rgb", "ras", "wbmp", "dng", "cr2", "cr3", "crw", "nef", "nrw", "arw", "srf", "sr2", "orf", "raf", "rw2", "rwl", "pef",
        "srw", "x3f", "3fr", "mef", "mrw", "erf", "kdc", "dcr", "iiq", "apng", "mng", "miff", "fits", "fit", "pcd", "eps", "pdf"]
    readonly property var animatedExtensions: ["gif", "webp", "apng", "mng"]

    // ── Which file ─────────────────────────────────────────────────
    property var files: []
    property int index: -1
    readonly property string currentPath: root.index >= 0 ? (root.files[root.index] ?? "") : ""
    readonly property string fileName: root.currentPath.replace(/^.*\//, "")
    readonly property string extension: root.fileName.includes(".") ? root.fileName.replace(/^.*\./, "").toLowerCase() : ""
    readonly property bool isVector: root.extension === "svg" || root.extension === "svgz"
    readonly property bool isAnimated: root.animatedExtensions.includes(root.extension)
    // A PNG made by ImageMagick, used in place of a file Qt refused.
    property string converted: ""
    property bool converting: false
    property bool failed: false
    readonly property string shownPath: root.converted || root.currentPath
    readonly property var picture: root.isAnimated && !root.converted ? animated : still
    readonly property bool loaded: root.picture.status === Image.Ready
    readonly property string pendingFiles: Quickshell.env("VIEWER_FILES") ?? ""

    // ── View ───────────────────────────────────────────────────────
    // A picture opens whole and without being enlarged: a small one at its size, a
    // large one reduced to fit. The button fills the window edge to edge, cropping
    // what overflows, and a second press goes back to how it opened.
    property bool fit: true
    property bool fillWindow: false
    property real zoom: 1
    property real panX: 0
    property real panY: 0
    property int rotationSteps: 0
    property bool flipped: false
    readonly property bool sideways: root.rotationSteps % 2 !== 0
    readonly property real sourceW: root.picture.implicitWidth
    readonly property real sourceH: root.picture.implicitHeight
    readonly property real turnedW: root.sideways ? root.sourceH : root.sourceW
    readonly property real turnedH: root.sideways ? root.sourceW : root.sourceH
    readonly property real fitZoom: {
        if (root.sourceW <= 0 || root.sourceH <= 0) return 1;
        const byWidth = stage.width / root.turnedW;
        const byHeight = stage.height / root.turnedH;
        return root.fillWindow ? Math.max(byWidth, byHeight) : Math.min(byWidth, byHeight, 1);
    }
    readonly property real shownZoom: root.fit ? root.fitZoom : root.zoom
    readonly property bool filled: root.fit && root.fillWindow

    // ── Interface ──────────────────────────────────────────────────
    property bool controlsShown: true
    property bool infoShown: false
    property var info: ({})
    readonly property bool fullscreen: root.visibility === Window.FullScreen
    readonly property bool keepControls: !root.loaded || root.infoShown || barHover.hovered

    function urlFor(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
    function isImage(path) {
        const name = path.replace(/^.*\//, "");
        return !name.startsWith(".") && root.imageExtensions.includes(name.replace(/^.*\./, "").toLowerCase());
    }
    function resetView() {
        root.fit = true;
        root.fillWindow = false;
        root.zoom = 1;
        root.panX = 0;
        root.panY = 0;
        root.rotationSteps = 0;
        root.flipped = false;
    }
    function openFiles(paths) {
        const list = paths.filter(p => p.length > 0);
        if (list.length === 0) return;
        if (list.length > 1) {
            root.files = list;
            root.index = 0;
            return;
        }
        // One file brings its folder with it, one folder opens from its start.
        root.files = [list[0]];
        root.index = 0;
        folderProc.wanted = list[0];
        folderProc.running = false;
        folderProc.command = ["bash", "-c",
            'p="$1"; [ -d "$p" ] && d="$p" || d="$(dirname "$p")"; find "$d" -maxdepth 1 -type f -print0 | sort -zV',
            "viewer", list[0]];
        folderProc.running = true;
    }
    function step(delta) {
        if (root.files.length < 2) return;
        root.index = (root.index + delta + root.files.length) % root.files.length;
        root.wake();
    }
    function zoomAt(factor, x, y) {
        if (!root.loaded) return;
        const before = root.shownZoom;
        const after = Math.max(0.02, Math.min(32, before * factor));
        // Keep what is under the pointer under it.
        const dx = x - stage.width / 2 - root.panX;
        const dy = y - stage.height / 2 - root.panY;
        root.panX += dx * (1 - after / before);
        root.panY += dy * (1 - after / before);
        root.zoom = after;
        root.fit = false;
        root.clampPan();
        root.wake();
    }
    function actualSize() {
        root.zoom = 1;
        root.fit = false;
        root.panX = 0;
        root.panY = 0;
    }
    function fitToWindow() {
        root.fit = true;
        root.fillWindow = true;
        root.panX = 0;
        root.panY = 0;
    }
    function toggleFit() {
        if (root.filled) {
            root.fillWindow = false;
            root.panX = 0;
            root.panY = 0;
        } else {
            root.fitToWindow();
        }
        root.wake();
    }
    function clampPan() {
        const limitX = Math.max(0, (root.turnedW * root.shownZoom - stage.width) / 2);
        const limitY = Math.max(0, (root.turnedH * root.shownZoom - stage.height) / 2);
        root.panX = Math.max(-limitX, Math.min(limitX, root.panX));
        root.panY = Math.max(-limitY, Math.min(limitY, root.panY));
    }
    function rotate(steps) {
        root.rotationSteps = (root.rotationSteps + steps + 4) % 4;
        root.clampPan();
    }
    function toggleFullscreen() {
        root.visibility = root.fullscreen ? Window.Windowed : Window.FullScreen;
    }
    function formatSize(bytes) {
        if (!bytes) return "";
        const units = ["B", "KB", "MB", "GB"];
        const i = Math.min(units.length - 1, Math.floor(Math.log(bytes) / Math.log(1024)));
        return (bytes / Math.pow(1024, i)).toFixed(i === 0 ? 0 : 1) + " " + units[i];
    }
    function wake() {
        root.controlsShown = true;
        hideTimer.restart();
    }
    function convert() {
        if (root.converted || root.converting) return;
        root.converting = true;
        const target = convertedDir + "/" + Qt.md5(root.currentPath) + ".png";
        convertProc.wanted = root.currentPath;
        convertProc.target = target;
        convertProc.command = ["bash", "-c",
            '[ -s "$2" ] && [ "$2" -nt "$1" ] && exit 0; mkdir -p "$(dirname "$2")" && magick "$1[0]" -auto-orient "$2"',
            "viewer", root.currentPath, target];
        convertProc.running = true;
    }
    function refreshInfo() {
        if (!root.infoShown || !root.currentPath) return;
        infoProc.running = false;
        infoProc.command = ["bash", "-c",
            'stat -c "%s" -- "$1"; magick identify -ping -format "%m|%[colorspace]|%[depth]|%[EXIF:Model]|%[EXIF:DateTimeOriginal]\\n" "$1[0]" 2>/dev/null',
            "viewer", root.currentPath];
        infoProc.running = true;
    }

    readonly property string convertedDir: FileUtils.trimFileProtocol(Directories.cache) + "/image-viewer"

    onCurrentPathChanged: {
        root.converted = "";
        root.converting = false;
        root.failed = false;
        root.info = ({});
        root.resetView();
        root.refreshInfo();
    }
    onInfoShownChanged: root.refreshInfo()
    onClosing: Qt.quit()

    Component.onCompleted: {
        // Started on its own, so it has to ask for the shell's colors itself.
        Quickshell.watchFiles = false;
        MaterialThemeLoader.reapplyTheme();
        root.openFiles(root.pendingFiles.split("\n"));
    }

    IpcHandler {
        target: "viewer"
        function open(paths: string): void {
            root.openFiles(paths.split("\n"));
        }
        function next(): void {
            root.step(1);
        }
        function previous(): void {
            root.step(-1);
        }
        function zoom(factor: real): void {
            root.zoomAt(factor, stage.width / 2, stage.height / 2);
        }
        function turn(steps: int): void {
            root.rotate(steps);
        }
        function flip(): void {
            root.flipped = !root.flipped;
        }
        function fit(): void {
            fitButton.clicked();
        }
        function details(shown: bool): void {
            root.infoShown = shown;
        }
    }

    Process {
        id: folderProc
        property string wanted: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const all = this.text.split("\0").filter(path => root.isImage(path));
                if (all.length === 0) return;
                root.files = all;
                const at = all.indexOf(folderProc.wanted);
                root.index = at === -1 ? 0 : at;
            }
        }
    }

    Process {
        id: convertProc
        property string wanted: ""
        property string target: ""
        onExited: exitCode => {
            if (convertProc.wanted !== root.currentPath) return;
            root.converting = false;
            if (exitCode === 0) root.converted = convertProc.target;
            else root.failed = true;
        }
    }

    Process {
        id: infoProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                const parts = (lines[1] ?? "").split("|");
                root.info = {
                    size: parseInt(lines[0]) || 0,
                    format: parts[0] ?? "",
                    colors: parts[1] ?? "",
                    depth: parts[2] ?? "",
                    camera: parts[3] ?? "",
                    date: parts[4] ?? ""
                };
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 2500
        running: true
        onTriggered: root.controlsShown = false
    }

    FileDialog {
        id: fileDialog
        title: Translation.tr("Open image")
        fileMode: FileDialog.OpenFile
        currentFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        onAccepted: root.openFiles([decodeURIComponent(selectedFile.toString().replace("file://", ""))])
    }

    // ── The picture ────────────────────────────────────────────────
    Item {
        id: stage
        anchors.fill: parent
        clip: true
        onWidthChanged: root.clampPan()
        onHeightChanged: root.clampPan()

        Item {
            id: holder
            width: root.sourceW
            height: root.sourceH
            x: (stage.width - width) / 2 + root.panX
            y: (stage.height - height) / 2 + root.panY
            transform: [
                Scale {
                    origin.x: holder.width / 2
                    origin.y: holder.height / 2
                    xScale: root.shownZoom * (root.flipped ? -1 : 1)
                    yScale: root.shownZoom
                },
                Rotation {
                    origin.x: holder.width / 2
                    origin.y: holder.height / 2
                    angle: root.rotationSteps * 90
                }
            ]

            Image {
                id: still
                anchors.fill: parent
                visible: root.picture === still
                source: !root.isAnimated || root.converted ? (root.shownPath ? root.urlFor(root.shownPath) : "") : ""
                asynchronous: true
                autoTransform: true
                cache: false
                smooth: root.fit || root.shownZoom < 3
                mipmap: true
                // A vector has no size of its own; this is as sharp as it gets when zoomed.
                sourceSize: root.isVector ? Qt.size(2048, 2048) : undefined
                fillMode: Image.PreserveAspectFit
                onStatusChanged: if (status === Image.Error) root.convert()
            }
            AnimatedImage {
                id: animated
                anchors.fill: parent
                visible: root.picture === animated
                source: root.isAnimated && !root.converted && root.currentPath ? root.urlFor(root.currentPath) : ""
                asynchronous: true
                cache: false
                playing: true
                smooth: root.fit || root.shownZoom < 3
                onStatusChanged: if (status === Image.Error) root.convert()
            }
        }
    }

    // ── States without a picture ───────────────────────────────────
    ColumnLayout {
        anchors.centerIn: parent
        visible: !root.currentPath
        spacing: 10
        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "image"
            iconSize: 72
            color: Appearance.colors.colPrimary
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("Drop an image here")
            color: Appearance.colors.colOnLayer0
            font.pixelSize: Appearance.font.pixelSize.larger
        }
        RippleButtonWithIcon {
            Layout.alignment: Qt.AlignHCenter
            materialIcon: "folder_open"
            mainText: Translation.tr("Open image")
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            onClicked: fileDialog.open()
        }
    }
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 460)
        visible: root.failed || root.converting
        spacing: 8
        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: root.failed ? "broken_image" : "hourglass_top"
            iconSize: 64
            color: root.failed ? Appearance.m3colors.m3error : Appearance.colors.colPrimary
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.failed ? Translation.tr("Could not open this image") : Translation.tr("Converting…")
            color: Appearance.colors.colOnLayer0
        }
    }

    // ── Pointer and keys ───────────────────────────────────────────
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        property real lastX: 0
        property real lastY: 0
        readonly property bool canPan: root.turnedW * root.shownZoom > stage.width || root.turnedH * root.shownZoom > stage.height
        cursorShape: pressed ? Qt.ClosedHandCursor : canPan ? Qt.OpenHandCursor : Qt.ArrowCursor
        onPressed: mouse => {
            lastX = mouse.x;
            lastY = mouse.y;
        }
        onPositionChanged: mouse => {
            root.wake();
            if (!pressed) return;
            root.panX += mouse.x - lastX;
            root.panY += mouse.y - lastY;
            lastX = mouse.x;
            lastY = mouse.y;
            root.clampPan();
        }
        onDoubleClicked: mouse => {
            if (root.fit && root.fitZoom !== 1) root.zoomAt(1 / root.fitZoom, mouse.x, mouse.y);
            else root.fitToWindow();
        }
        onWheel: wheel => root.zoomAt(wheel.angleDelta.y > 0 ? 1.2 : 1 / 1.2, wheel.x, wheel.y)
    }

    DropArea {
        anchors.fill: parent
        onDropped: drop => {
            if (!drop.hasUrls) return;
            root.openFiles(drop.urls.map(url => decodeURIComponent(url.toString().replace("file://", ""))));
            drop.accept(Qt.CopyAction);
        }
    }

    component Key: Shortcut { context: Qt.WindowShortcut }
    Key { sequences: ["Right", "PgDown", "Space"]; onActivated: root.step(1) }
    Key { sequences: ["Left", "PgUp", "Backspace"]; onActivated: root.step(-1) }
    Key { sequence: "Home"; onActivated: if (root.files.length) root.index = 0 }
    Key { sequence: "End"; onActivated: if (root.files.length) root.index = root.files.length - 1 }
    Key { sequences: ["+", "="]; onActivated: root.zoomAt(1.2, stage.width / 2, stage.height / 2) }
    Key { sequence: "-"; onActivated: root.zoomAt(1 / 1.2, stage.width / 2, stage.height / 2) }
    Key { sequence: "0"; onActivated: root.fitToWindow() }
    Key { sequence: "1"; onActivated: root.actualSize() }
    Key { sequence: "R"; onActivated: root.rotate(1) }
    Key { sequence: "Shift+R"; onActivated: root.rotate(-1) }
    Key { sequence: "H"; onActivated: root.flipped = !root.flipped }
    Key { sequence: "I"; onActivated: root.infoShown = !root.infoShown }
    Key { sequence: "F"; onActivated: root.toggleFullscreen() }
    Key { sequence: "Ctrl+O"; onActivated: fileDialog.open() }
    Key { sequence: "Q"; onActivated: Qt.quit() }
    Key {
        sequence: "Esc"
        onActivated: {
            if (root.infoShown) root.infoShown = false;
            else if (root.fullscreen) root.toggleFullscreen();
        }
    }

    // ── Controls ───────────────────────────────────────────────────
    component ViewerButton: RippleButton {
        id: viewerButton
        property string symbol
        property string tip: ""
        implicitWidth: 40
        implicitHeight: 40
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        // The accent, because hovering is a grey close to any quieter choice: the
        // pointer stays on the button after a click and would look switched on.
        colBackgroundToggled: Appearance.colors.colPrimary
        colBackgroundToggledHover: Appearance.colors.colPrimaryHover
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: viewerButton.symbol
            iconSize: 22
            fill: viewerButton.toggled ? 1 : 0
            color: viewerButton.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
        }
        StyledToolTip {
            text: viewerButton.tip
            extraVisibleCondition: viewerButton.tip.length > 0
        }
    }

    component Panel: Rectangle {
        radius: Appearance.rounding.normal
        color: Appearance.m3colors.m3surfaceContainer
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
    }

    component InfoRow: ColumnLayout {
        property string label
        property string value
        visible: value !== ""
        Layout.fillWidth: true
        spacing: 0
        StyledText {
            text: parent.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
        StyledText {
            Layout.fillWidth: true
            text: parent.value
            wrapMode: Text.WrapAnywhere
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
        }
    }

    Item {
        anchors.fill: parent
        opacity: root.controlsShown || root.keepControls ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        HoverHandler { id: barHover; target: bar }

        Panel {
            id: bar
            visible: root.currentPath !== ""
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 14
            }
            width: Math.min(parent.width - 28, barRow.implicitWidth + 20)
            height: 56

            RowLayout {
                id: barRow
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 20)
                spacing: 2

                ViewerButton {
                    symbol: "folder_open"
                    tip: Translation.tr("Open image") + " (Ctrl+O)"
                    onClicked: fileDialog.open()
                }
                ViewerButton {
                    symbol: "chevron_left"
                    tip: Translation.tr("Previous") + " (←)"
                    enabled: root.files.length > 1
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.step(-1)
                }
                StyledText {
                    Layout.minimumWidth: 56
                    horizontalAlignment: Text.AlignHCenter
                    text: (root.index + 1) + " / " + root.files.length
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.features: ({ "tnum": 1 })
                    color: Appearance.colors.colSubtext
                }
                ViewerButton {
                    symbol: "chevron_right"
                    tip: Translation.tr("Next") + " (→)"
                    enabled: root.files.length > 1
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.step(1)
                }
                Rectangle {
                    implicitWidth: 1
                    implicitHeight: 24
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    color: Appearance.colors.colLayer0Border
                }
                ViewerButton {
                    symbol: "zoom_out"
                    tip: Translation.tr("Zoom out") + " (-)"
                    onClicked: root.zoomAt(1 / 1.2, stage.width / 2, stage.height / 2)
                }
                StyledText {
                    Layout.minimumWidth: 46
                    horizontalAlignment: Text.AlignHCenter
                    text: Math.round(root.shownZoom * 100) + "%"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.features: ({ "tnum": 1 })
                    color: Appearance.colors.colOnLayer1
                }
                ViewerButton {
                    symbol: "zoom_in"
                    tip: Translation.tr("Zoom in") + " (+)"
                    onClicked: root.zoomAt(1.2, stage.width / 2, stage.height / 2)
                }
                ViewerButton {
                    id: fitButton
                    symbol: "fit_screen"
                    tip: Translation.tr("Fill window") + " (0)"
                    toggled: root.filled
                    onClicked: root.toggleFit()
                }
                Rectangle {
                    implicitWidth: 1
                    implicitHeight: 24
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    color: Appearance.colors.colLayer0Border
                }
                ViewerButton {
                    symbol: "rotate_right"
                    tip: Translation.tr("Rotate") + " (R)"
                    onClicked: root.rotate(1)
                }
                ViewerButton {
                    symbol: "flip"
                    tip: Translation.tr("Flip") + " (H)"
                    toggled: root.flipped
                    onClicked: root.flipped = !root.flipped
                }
                ViewerButton {
                    symbol: "info"
                    tip: Translation.tr("Details") + " (I)"
                    toggled: root.infoShown
                    onClicked: root.infoShown = !root.infoShown
                }
                ViewerButton {
                    symbol: root.fullscreen ? "fullscreen_exit" : "fullscreen"
                    tip: Translation.tr("Fullscreen") + " (F)"
                    onClicked: root.toggleFullscreen()
                }
            }
        }

        Panel {
            visible: root.infoShown && root.currentPath !== ""
            anchors {
                right: parent.right
                top: parent.top
                bottom: bar.top
                margins: 14
            }
            width: 280

            ColumnLayout {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 16
                }
                spacing: 12
                InfoRow {
                    label: Translation.tr("Name")
                    value: root.fileName
                }
                InfoRow {
                    label: Translation.tr("Folder")
                    value: root.currentPath.replace(/\/[^\/]*$/, "")
                }
                InfoRow {
                    label: Translation.tr("Dimensions")
                    value: root.loaded ? root.sourceW + " × " + root.sourceH : ""
                }
                InfoRow {
                    label: Translation.tr("Format")
                    value: root.info.format ?? ""
                }
                InfoRow {
                    label: Translation.tr("File size")
                    value: root.formatSize(root.info.size)
                }
                InfoRow {
                    label: Translation.tr("Colors")
                    value: root.info.colors ? root.info.colors + (root.info.depth ? " · " + root.info.depth + "-bit" : "") : ""
                }
                InfoRow {
                    label: Translation.tr("Camera")
                    value: root.info.camera ?? ""
                }
                InfoRow {
                    label: Translation.tr("Taken")
                    value: root.info.date ?? ""
                }
            }
        }
    }
}
