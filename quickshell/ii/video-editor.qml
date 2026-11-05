//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_SCALE_FACTOR=1

// video-editor.qml — a small video editor in the shell's own look.
//
// Opens the video named in the VIDEO_EDIT_FILE environment variable (scripts/
// videos/record.sh sets it when a recording ends). What it does:
//   · trim: drag the two handles on the timeline
//   · crop: pick an area of the picture
//   · speed 0.5x to 2x, remove the sound
//   · export as MP4 or as a GIF, next to the original ("name-edited.mp4")
// The original is never touched. ffmpeg does the work; the ffmpeg arguments
// are built in modules/ii/videoEditor/VideoExport.js.
//
// Open it by hand with:
//   VIDEO_EDIT_FILE=/path/video.mp4 qs -p ~/.config/quickshell/ii/video-editor.qml
// Needs: ffmpeg, ffprobe, notify-send.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "modules/ii/videoEditor/VideoExport.js" as VideoExport

TranslucentAppWindow {
    id: root
    visible: true
    width: 980
    height: 700
    minimumWidth: 760
    minimumHeight: 520
    // Fixed, not translated: the blur rule in rules.lua matches on it
    title: "Video editor"

    // ── State ──────────────────────────────────────────────────────
    readonly property string sourceFile: Quickshell.env("VIDEO_EDIT_FILE") ?? ""
    readonly property string sourceDir: sourceFile.replace(/\/[^\/]*$/, "")
    readonly property string sourceBase: sourceFile.replace(/^.*\//, "").replace(/\.[^.]*$/, "")

    property real duration: 0           // seconds
    property int videoW: 0
    property int videoH: 0
    property bool hasAudio: false
    property bool ready: false

    property real trimStart: 0
    property real trimEnd: 0
    property real speed: 1
    property bool mute: false
    property string format: "mp4"       // mp4 | gif

    // The crop, as fractions of the picture
    property bool cropMode: false
    property real cropX: 0
    property real cropY: 0
    property real cropW: 1
    property real cropH: 1
    readonly property bool cropped: cropW < 0.995 || cropH < 0.995
    function resetCrop() { cropX = 0; cropY = 0; cropW = 1; cropH = 1 }

    property bool exporting: false
    property real progress: 0
    property string statusText: ""
    property string lastOutput: ""

    readonly property var speeds: [0.5, 0.75, 1, 1.25, 1.5, 2]

    onClosing: Qt.quit()

    function pos() { return player.position / 1000 }

    // ── Reading the file ───────────────────────────────────────────
    Process {
        id: probe
        command: ["ffprobe", "-v", "error", "-show_entries",
            "stream=codec_type,width,height:format=duration", "-of", "json", root.sourceFile]
        running: root.sourceFile !== ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(text)
                    const v = o.streams.find(s => s.codec_type === "video")
                    root.hasAudio = o.streams.some(s => s.codec_type === "audio")
                    root.videoW = v.width
                    root.videoH = v.height
                    root.duration = parseFloat(o.format.duration)
                    root.trimStart = 0
                    root.trimEnd = root.duration
                    root.ready = root.duration > 0
                    if (!root.hasAudio) root.mute = true
                    thumbs.running = true
                } catch (e) {
                    root.statusText = Translation.tr("Could not read this video")
                }
            }
        }
    }

    // One image of evenly spaced frames, shown behind the timeline
    readonly property string thumbFile: FileUtils.trimFileProtocol(Directories.cache) + "/video-editor-strip.jpg"
    property int thumbRev: 0
    Process {
        id: thumbs
        command: ["bash", "-c",
            'mkdir -p "$(dirname "$3")" && ffmpeg -y -v error -i "$1" -vf "fps=14/$2,scale=-2:80,tile=14x1" -frames:v 1 -q:v 4 "$3"',
            "strip", root.sourceFile, String(Math.max(0.1, root.duration)), root.thumbFile]
        onExited: root.thumbRev++
    }

    // ── Playback ───────────────────────────────────────────────────
    MediaPlayer {
        id: player
        source: root.sourceFile !== "" ? "file://" + root.sourceFile : ""
        videoOutput: video
        audioOutput: AudioOutput { muted: root.mute; volume: 0.8 }
        playbackRate: root.speed
        onPositionChanged: {
            // Stay inside the part that is kept
            if (root.ready && playbackState === MediaPlayer.PlayingState && root.pos() >= root.trimEnd) {
                player.pause()
                player.position = root.trimStart * 1000
            }
        }
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.LoadedMedia) { player.position = 0; player.pause() }
    }
    function togglePlay() {
        if (player.playbackState === MediaPlayer.PlayingState) { player.pause(); return }
        if (root.pos() < root.trimStart || root.pos() >= root.trimEnd - 0.05)
            player.position = root.trimStart * 1000
        player.play()
    }
    function seekTo(t) {
        player.position = Math.max(0, Math.min(root.duration, t)) * 1000
    }

    // ── Export ─────────────────────────────────────────────────────
    readonly property real outSeconds: VideoExport.outputSeconds({ start: trimStart, end: trimEnd, speed: speed })
    readonly property var cropPx: cropped ? {
        x: cropX * videoW, y: cropY * videoH, w: cropW * videoW, h: cropH * videoH
    } : null
    readonly property string outInfo: {
        const w = cropped ? Math.floor(cropW * videoW / 2) * 2 : videoW
        const h = cropped ? Math.floor(cropH * videoH / 2) * 2 : videoH
        return w + "×" + h + "  ·  " + VideoExport.formatTime(outSeconds)
    }

    // First free "name-edited(.n).ext" beside the original
    Process {
        id: nameProc
        property string ext: "mp4"
        command: ["bash", "-c",
            'o="$1/$2-edited.$3"; n=2; while [ -e "$o" ]; do o="$1/$2-edited-$n.$3"; n=$((n+1)); done; printf %s "$o"',
            "name", root.sourceDir, root.sourceBase, ext]
        stdout: StdioCollector {
            onStreamFinished: root.runExport(text.trim())
        }
    }
    function startExport() {
        if (root.exporting || !root.ready) return
        player.pause()
        root.exporting = true
        root.progress = 0
        root.statusText = ""
        nameProc.ext = root.format
        nameProc.running = true
    }
    function runExport(output) {
        root.lastOutput = output
        ffmpeg.command = ["ffmpeg"].concat(VideoExport.buildArgs({
            input: root.sourceFile, output: output, format: root.format,
            start: root.trimStart, end: root.trimEnd, speed: root.speed,
            mute: root.mute, crop: root.cropPx
        }))
        ffmpeg.running = true
    }
    Process {
        id: ffmpeg
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/^out_time_(?:us|ms)=(\d+)/)
                if (m) root.progress = Math.max(0, Math.min(0.99, parseInt(m[1]) / 1e6 / root.outSeconds))
            }
        }
        stderr: StdioCollector { id: ffmpegErr }
        onExited: (code, status) => {
            root.exporting = false
            if (code === 0) {
                root.progress = 1
                root.statusText = Translation.tr("Saved: %1").arg(root.lastOutput.replace(/^.*\//, ""))
                Quickshell.execDetached(["notify-send", "-a", Translation.tr("Video editor"),
                    Translation.tr("Video saved"), root.lastOutput.replace(/^.*\//, ""),
                    "-i", "video-x-generic"])
            } else {
                root.statusText = Translation.tr("Export failed")
                Quickshell.execDetached(["rm", "-f", "--", root.lastOutput])
            }
        }
    }
    function cancelExport() {
        ffmpeg.running = false
        root.statusText = Translation.tr("Cancelled")
    }

    // ── Layout ─────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Toolbar {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Appearance.spacing.md
                Layout.leftMargin: Appearance.spacing.md
                Layout.rightMargin: Appearance.spacing.md
                enableShadow: false
                spacing: 2

                ToolbarSymbolButton {
                    symbol: player.playbackState === MediaPlayer.PlayingState ? "pause" : "play_arrow"
                    tip: Translation.tr("Play / pause")
                    enabled: root.ready
                    onClicked: root.togglePlay()
                }
                StyledText {
                    Layout.leftMargin: Appearance.spacing.xs
                    Layout.rightMargin: Appearance.spacing.xs
                    text: VideoExport.formatTime(root.pos()) + " / " + VideoExport.formatTime(root.duration)
                    font.features: ({ "tnum": 1 })
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
                ToolbarDivider {}

                ToolbarSymbolButton {
                    symbol: "crop"
                    label: root.cropped ? Translation.tr("Crop") : ""
                    tip: Translation.tr("Crop the picture")
                    toggled: root.cropMode
                    enabled: root.ready && !root.exporting
                    onClicked: root.cropMode = !root.cropMode
                }
                ToolbarSymbolButton {
                    visible: root.cropped
                    symbol: "crop_free"
                    tip: Translation.tr("Remove the crop")
                    enabled: !root.exporting
                    onClicked: root.resetCrop()
                }
                // Cycles through the speeds
                ToolbarSymbolButton {
                    symbol: "speed"
                    label: root.speed + "x"
                    tip: Translation.tr("Speed")
                    toggled: root.speed !== 1
                    enabled: root.ready && !root.exporting
                    onClicked: root.speed = root.speeds[(root.speeds.indexOf(root.speed) + 1) % root.speeds.length]
                }
                ToolbarSymbolButton {
                    symbol: root.mute ? "volume_off" : "volume_up"
                    tip: !root.hasAudio ? Translation.tr("This video has no sound")
                        : root.mute ? Translation.tr("Sound removed") : Translation.tr("Keep the sound")
                    toggled: root.mute
                    enabled: root.ready && root.hasAudio && root.format === "mp4" && !root.exporting
                    onClicked: root.mute = !root.mute
                }
                ToolbarDivider {}

                ToolbarSymbolButton {
                    symbol: "movie"
                    label: "MP4"
                    tip: Translation.tr("Export as a video")
                    toggled: root.format === "mp4"
                    enabled: !root.exporting
                    onClicked: root.format = "mp4"
                }
                ToolbarSymbolButton {
                    symbol: "gif_box"
                    label: "GIF"
                    tip: Translation.tr("Export as a GIF (no sound)")
                    toggled: root.format === "gif"
                    enabled: !root.exporting
                    onClicked: root.format = "gif"
                }
                ToolbarDivider {}

                RippleButton {
                    implicitWidth: exportRow.implicitWidth + 28
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.full
                    enabled: root.ready
                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimaryHover
                    colRipple: Appearance.colors.colPrimaryActive
                    onClicked: root.exporting ? root.cancelExport() : root.startExport()
                    contentItem: Row {
                        id: exportRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.exporting ? "close" : "download"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnPrimary
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.exporting ? Translation.tr("Cancel") : Translation.tr("Export")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }

            // Picture
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Appearance.spacing.md
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                clip: true

                StyledText {
                    anchors.centerIn: parent
                    visible: !root.ready
                    text: root.sourceFile === "" ? Translation.tr("No video to edit") : (root.statusText !== "" ? root.statusText : Translation.tr("Loading…"))
                    color: Appearance.colors.colSubtext
                }

                VideoOutput {
                    id: video
                    anchors.fill: parent
                    anchors.margins: Appearance.spacing.sm
                    fillMode: VideoOutput.PreserveAspectFit

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.cropMode
                        onClicked: root.togglePlay()
                    }

                    // The area picker: dims what is cut away
                    Item {
                        id: cropLayer
                        visible: root.cropMode && root.ready
                        x: video.contentRect.x
                        y: video.contentRect.y
                        width: video.contentRect.width
                        height: video.contentRect.height

                        readonly property real rx: root.cropX * width
                        readonly property real ry: root.cropY * height
                        readonly property real rw: root.cropW * width
                        readonly property real rh: root.cropH * height

                        Rectangle { color: "#99000000"; x: 0; y: 0; width: parent.width; height: cropLayer.ry }
                        Rectangle { color: "#99000000"; x: 0; y: cropLayer.ry + cropLayer.rh; width: parent.width; height: parent.height - y }
                        Rectangle { color: "#99000000"; x: 0; y: cropLayer.ry; width: cropLayer.rx; height: cropLayer.rh }
                        Rectangle { color: "#99000000"; x: cropLayer.rx + cropLayer.rw; y: cropLayer.ry; width: parent.width - x; height: cropLayer.rh }

                        Rectangle {
                            x: cropLayer.rx; y: cropLayer.ry; width: cropLayer.rw; height: cropLayer.rh
                            color: "transparent"
                            border.width: 2
                            border.color: Appearance.colors.colPrimary
                        }
                        Repeater {
                            model: [[0, 0], [1, 0], [0, 1], [1, 1]]
                            delegate: Rectangle {
                                required property var modelData
                                width: 14; height: 14; radius: 7
                                x: cropLayer.rx + modelData[0] * cropLayer.rw - 7
                                y: cropLayer.ry + modelData[1] * cropLayer.rh - 7
                                color: Appearance.colors.colPrimary
                            }
                        }

                        // One area for everything: corners and edges resize, the inside moves
                        MouseArea {
                            id: cropMouse
                            anchors.fill: parent
                            property string hx: ""
                            property string hy: ""
                            property bool moving: false
                            property real sx; property real sy
                            property real ox; property real oy; property real ow; property real oh

                            onPressed: m => {
                                const t = 18
                                const nl = Math.abs(m.x - cropLayer.rx) < t
                                const nr = Math.abs(m.x - (cropLayer.rx + cropLayer.rw)) < t
                                const nt = Math.abs(m.y - cropLayer.ry) < t
                                const nb = Math.abs(m.y - (cropLayer.ry + cropLayer.rh)) < t
                                const inX = m.x > cropLayer.rx - t && m.x < cropLayer.rx + cropLayer.rw + t
                                const inY = m.y > cropLayer.ry - t && m.y < cropLayer.ry + cropLayer.rh + t
                                hx = (inY && nl) ? "l" : (inY && nr) ? "r" : ""
                                hy = (inX && nt) ? "t" : (inX && nb) ? "b" : ""
                                moving = hx === "" && hy === "" && m.x > cropLayer.rx && m.x < cropLayer.rx + cropLayer.rw
                                    && m.y > cropLayer.ry && m.y < cropLayer.ry + cropLayer.rh
                                sx = m.x; sy = m.y
                                ox = root.cropX; oy = root.cropY; ow = root.cropW; oh = root.cropH
                            }
                            onPositionChanged: m => {
                                const dx = (m.x - sx) / cropLayer.width
                                const dy = (m.y - sy) / cropLayer.height
                                const min = 0.05
                                if (moving) {
                                    root.cropX = Math.max(0, Math.min(1 - ow, ox + dx))
                                    root.cropY = Math.max(0, Math.min(1 - oh, oy + dy))
                                    return
                                }
                                if (hx === "l") {
                                    const nx = Math.max(0, Math.min(ox + ow - min, ox + dx))
                                    root.cropX = nx; root.cropW = ox + ow - nx
                                } else if (hx === "r") {
                                    root.cropW = Math.max(min, Math.min(1 - ox, ow + dx))
                                }
                                if (hy === "t") {
                                    const ny = Math.max(0, Math.min(oy + oh - min, oy + dy))
                                    root.cropY = ny; root.cropH = oy + oh - ny
                                } else if (hy === "b") {
                                    root.cropH = Math.max(min, Math.min(1 - oy, oh + dy))
                                }
                            }
                        }
                    }
                }
            }

            // Timeline
            Item {
                Layout.fillWidth: true
                Layout.leftMargin: Appearance.spacing.md
                Layout.rightMargin: Appearance.spacing.md
                Layout.preferredHeight: 84
                visible: root.ready

                Rectangle {
                    id: track
                    anchors.fill: parent
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    anchors.leftMargin: Appearance.spacing.sm
                    anchors.rightMargin: Appearance.spacing.sm
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer1
                    clip: true

                    Image {
                        anchors.fill: parent
                        fillMode: Image.Stretch
                        asynchronous: true
                        cache: false
                        source: root.thumbRev > 0 ? "file://" + root.thumbFile + "?" + root.thumbRev : ""
                        opacity: 0.9
                    }
                    // What is cut away
                    Rectangle {
                        color: "#aa000000"
                        x: 0; width: root.trimStart / root.duration * track.width; height: track.height
                    }
                    Rectangle {
                        color: "#aa000000"
                        x: root.trimEnd / root.duration * track.width
                        width: track.width - x; height: track.height
                    }
                }

                // Kept part: the frame around it, and the two handles
                Item {
                    id: keep
                    x: track.x + root.trimStart / root.duration * track.width
                    y: track.y
                    width: (root.trimEnd - root.trimStart) / root.duration * track.width
                    height: track.height
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 3
                        border.color: Appearance.colors.colPrimary
                        radius: Appearance.rounding.small
                    }
                }

                // Playhead
                Rectangle {
                    x: track.x + root.pos() / root.duration * track.width - 1.5
                    y: track.y - 4
                    width: 3
                    height: track.height + 8
                    radius: 1.5
                    color: Appearance.colors.colOnLayer1
                }

                MouseArea {
                    anchors.fill: parent
                    property string grab: ""
                    function timeAt(mx) { return Math.max(0, Math.min(1, (mx - track.x) / track.width)) * root.duration }
                    onPressed: m => {
                        const xs = track.x + root.trimStart / root.duration * track.width
                        const xe = track.x + root.trimEnd / root.duration * track.width
                        if (Math.abs(m.x - xs) < 14) grab = "start"
                        else if (Math.abs(m.x - xe) < 14) grab = "end"
                        else { grab = "seek"; root.seekTo(timeAt(m.x)) }
                    }
                    onPositionChanged: m => {
                        const t = timeAt(m.x)
                        if (grab === "start") {
                            root.trimStart = Math.min(t, root.trimEnd - 0.2)
                            root.seekTo(root.trimStart)
                        } else if (grab === "end") {
                            root.trimEnd = Math.max(t, root.trimStart + 0.2)
                            root.seekTo(root.trimEnd)
                        } else if (grab === "seek") {
                            root.seekTo(t)
                        }
                    }
                }
            }

            // Footer: what comes out, and how the export is going
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.bottomMargin: Appearance.spacing.md
                Layout.topMargin: 2
                spacing: Appearance.spacing.md

                StyledText {
                    text: root.ready ? Translation.tr("Result: %1").arg(root.outInfo) : ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
                Item { Layout.fillWidth: true }

                Rectangle {
                    visible: root.exporting
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Appearance.colors.colSecondaryContainer
                    Rectangle {
                        width: parent.width * root.progress
                        height: parent.height
                        radius: 3
                        color: Appearance.colors.colPrimary
                    }
                }
                StyledText {
                    visible: root.exporting
                    text: Math.round(root.progress * 100) + "%"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    visible: !root.exporting && root.statusText !== "" && root.ready
                    text: root.statusText
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
                // After an export: show the file
                RippleButton {
                    visible: !root.exporting && root.progress === 1 && root.lastOutput !== ""
                    implicitWidth: 34
                    implicitHeight: 34
                    buttonRadius: Appearance.rounding.full
                    onClicked: Quickshell.execDetached(["xdg-open", root.sourceDir])
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "folder_open"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledToolTip { text: Translation.tr("Show in folder") }
                }
            }
        }
    }
}
