//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_SCALE_FACTOR=1

// screen-recorder.qml — screen recorder in the shell's own look.
//
// One floating toolbar (what to record, with sound or not, a delay, and the
// record button) over a list of the recordings in the save folder, each with
// play, show-in-folder and trash. A translucent window, blurred behind by the
// compositor like the shell's panels (rule in hypr rules.lua, matched on this
// exact title).
//
// The recording itself is done by the shell's own scripts/videos/record.sh
// (wf-recorder), the one behind Super+Shift+R, so file names, folder, color
// handling and the "saved" notification are the same. That script toggles: run
// again, it stops. The window gets out of the way while recording, and comes
// back when the recording ends; start it again meanwhile and it opens as a
// stop button. A recording started with Super+Shift+R shows up here too.
//
// Open it with:  qs -p ~/.config/quickshell/ii/screen-recorder.qml --no-duplicate
// Needs: wf-recorder, slurp, jq, ffmpeg (list thumbnails), hyprctl.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

TranslucentAppWindow {
    id: root
    visible: true
    width: 760
    height: 620
    minimumWidth: 560
    minimumHeight: 420
    // Fixed, not translated: the blur rule in rules.lua matches on it
    title: "Screen recorder"

    // ── State ──────────────────────────────────────────────────────
    property string mode: "region"      // region | window | screen
    property bool withSound: false
    property int delay: 0               // seconds, for window and screen

    property bool recording: false
    property int elapsed: 0             // seconds into the recording
    property bool starting: false       // asked to start, not recording yet
    property int startingPolls: 0

    readonly property string recordScript: Directories.recordScriptPath
    readonly property string saveDir: {
        let configured = FileUtils.trimFileProtocol(Config.options.screenRecord.savePath ?? "").replace(/\/+$/, "")
        if (configured.startsWith("~")) configured = Quickshell.env("HOME") + configured.slice(1)
        // The script falls back to ~/Videos the same way
        return configured !== "" ? configured : Quickshell.env("HOME") + "/Videos"
    }
    readonly property string thumbDir: FileUtils.trimFileProtocol(Directories.cache) + "/screen-recorder-thumbs"

    onClosing: Qt.quit()

    function formatTime(total) {
        const m = Math.floor(total / 60), s = total % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    // ── Start and stop ─────────────────────────────────────────────
    // $1 mode, $2 delay, $3 sound, $4 record.sh. A window or a screen is
    // started here; a region goes through the shell's area selector instead.
    readonly property string startScript: `
mode="$1"; delay="$2"; sound="$3"; rec="$4"
extra=(); [ "$sound" = 1 ] && extra=(--sound)
sleep 0.4
if [ "$mode" = window ]; then
  ws=$(hyprctl monitors -j | jq -c '[.[].activeWorkspace.id]')
  geom=$(hyprctl clients -j | jq -r --argjson ws "$ws" '.[] | select(.mapped and (.workspace.id as $w | $ws | index($w))) | "\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"' | slurp -r) || exit 2
  [ "$delay" -gt 0 ] && sleep "$delay"
  exec "$rec" --region "$geom" "\${extra[@]}"
else
  [ "$delay" -gt 0 ] && sleep "$delay"
  exec "$rec" --fullscreen "\${extra[@]}"
fi
`

    function startRecording() {
        if (root.recording || root.starting) return
        root.starting = true
        root.startingPolls = 0
        // Out of the way first, so the window is not in its own recording
        root.visible = false
        if (root.mode === "region") {
            // The shell's own selector: the same global shortcuts as
            // Super+Shift+R (and its with-sound twin)
            regionStart.restart()
        } else {
            Quickshell.execDetached(["bash", "-c", root.startScript, "recorder",
                root.mode, String(root.delay), root.withSound ? "1" : "0", root.recordScript])
        }
    }
    Timer {
        id: regionStart
        interval: 400
        onTriggered: Quickshell.execDetached(["hyprctl", "dispatch",
            root.withSound ? 'hl.dsp.global("quickshell:regionRecordWithSound")'
                           : 'hl.dsp.global("quickshell:regionRecord")'])
    }
    function stopRecording() {
        // The script is a toggle: with a recording going, it stops it
        Quickshell.execDetached([root.recordScript])
    }

    // ── Is it recording? ───────────────────────────────────────────
    // Seconds the newest wf-recorder has been running, or nothing.
    Process {
        id: stateProc
        command: ["bash", "-c", 'p=$(pgrep -n wf-recorder) && ps -o etimes= -p "$p"']
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                const was = root.recording
                root.recording = t.length > 0
                root.elapsed = t.length > 0 ? parseInt(t) : 0
                if (root.recording) {
                    root.starting = false
                } else if (root.starting) {
                    // Asked to start and nothing yet: give the selector or the
                    // delay time, then take the window back if it never started
                    root.startingPolls++
                    if (root.startingPolls > 60) {
                        root.starting = false
                        root.showWindow()
                    }
                }
                if (was && !root.recording) root.showWindow()
            }
        }
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!stateProc.running) stateProc.running = true
    }
    function showWindow() {
        root.visible = true
        root.raise()
        root.requestActivate()
    }

    // ── Per recording ──────────────────────────────────────────────
    function runFor(file, script) {
        Quickshell.execDetached(["bash", "-c", script, "recorder", file])
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

                Repeater {
                    model: [
                        { mode: "region", icon: "crop_free", tip: Translation.tr("Region") },
                        { mode: "window", icon: "web_asset", tip: Translation.tr("Window") },
                        { mode: "screen", icon: "desktop_windows", tip: Translation.tr("Screen") }
                    ]
                    delegate: RippleButton {
                        id: modeButton
                        required property var modelData
                        enabled: !root.recording
                        implicitWidth: 40
                        implicitHeight: 40
                        buttonRadius: Appearance.rounding.full
                        toggled: root.mode === modelData.mode
                        onClicked: root.mode = modelData.mode
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modeButton.modelData.icon
                            fill: modeButton.toggled ? 1 : 0
                            iconSize: Appearance.font.pixelSize.larger
                            color: modeButton.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        }
                        StyledToolTip { text: modeButton.modelData.tip }
                    }
                }
                ToolbarDivider {}

                ToolbarSymbolButton {
                    enabled: !root.recording
                    symbol: root.withSound ? "volume_up" : "volume_off"
                    tip: root.withSound ? Translation.tr("Recording system sound") : Translation.tr("No sound")
                    toggled: root.withSound
                    onClicked: root.withSound = !root.withSound
                }
                // Cycles through the delays; the region goes through the selector, which has none
                ToolbarSymbolButton {
                    enabled: !root.recording && root.mode !== "region"
                    symbol: "timer"
                    label: root.delay > 0 && root.mode !== "region" ? root.delay + "s" : ""
                    tip: Translation.tr("Delay before recording")
                    toggled: root.delay > 0 && root.mode !== "region"
                    onClicked: root.delay = root.delay === 0 ? 3 : root.delay === 3 ? 5 : root.delay === 5 ? 10 : 0
                }
                ToolbarDivider {}

                // Record, or stop with the time so far
                RippleButton {
                    id: recordButton
                    implicitWidth: root.recording ? stopRow.implicitWidth + 28 : 44
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.full
                    enabled: !root.starting
                    colBackground: Appearance.colors.colError
                    colBackgroundHover: Appearance.colors.colErrorHover
                    colRipple: Appearance.colors.colErrorActive
                    onClicked: root.recording ? root.stopRecording() : root.startRecording()
                    contentItem: Row {
                        id: stopRow
                        anchors.centerIn: parent
                        spacing: Appearance.spacing.sm
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.recording ? "stop" : "fiber_manual_record"
                            fill: 1
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnError
                        }
                        StyledText {
                            visible: root.recording
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.formatTime(root.elapsed)
                            font.features: ({ "tnum": 1 })
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnError
                        }
                    }
                    StyledToolTip { text: root.recording ? Translation.tr("Stop recording") : Translation.tr("Start recording") }
                }
            }

            // List
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Appearance.spacing.md
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                clip: true

                FolderListModel {
                    id: recordings
                    folder: "file://" + root.saveDir
                    nameFilters: ["*.mp4", "*.mkv", "*.webm"]
                    showDirs: false
                    sortField: FolderListModel.Time
                    sortReversed: true
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: recordings.count === 0
                    spacing: Appearance.spacing.sm
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "videocam"
                        iconSize: 40
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("No recordings yet")
                        color: Appearance.colors.colSubtext
                    }
                }

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 6
                    visible: recordings.count > 0
                    clip: true
                    spacing: Appearance.spacing.xs
                    model: recordings
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: StyledScrollBar {}

                    delegate: Item {
                        id: row
                        required property string filePath
                        required property string fileName
                        required property var fileModified
                        required property var fileSize
                        width: list.width
                        height: 76

                        readonly property string thumb: root.thumbDir + "/" + fileName + ".jpg"
                        property bool thumbReady: false

                        HoverHandler { id: rowHover }

                        // A still from a second in, made once and kept
                        Process {
                            id: thumbProc
                            command: ["bash", "-c",
                                'mkdir -p "$3"; [ -s "$2" ] || ffmpeg -y -v error -ss 1 -i "$1" -frames:v 1 -vf scale=320:-2 "$2" 2>/dev/null || ffmpeg -y -v error -i "$1" -frames:v 1 -vf scale=320:-2 "$2" 2>/dev/null; [ -s "$2" ]',
                                "thumb", row.filePath, row.thumb, root.thumbDir]
                            onExited: (code, status) => row.thumbReady = code === 0
                        }
                        Component.onCompleted: thumbProc.running = true

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: rowHover.hovered ? Appearance.colors.colLayer1Hover : "transparent"
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: Appearance.spacing.sm
                                rightMargin: Appearance.spacing.sm
                                topMargin: 6
                                bottomMargin: 6
                            }
                            spacing: Appearance.spacing.md

                            ClippingRectangle {
                                Layout.preferredWidth: 104
                                Layout.fillHeight: true
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colLayer2
                                Image {
                                    anchors.fill: parent
                                    visible: row.thumbReady
                                    source: row.thumbReady ? "file://" + row.thumb : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    visible: !row.thumbReady
                                    text: "movie"
                                    iconSize: 28
                                    color: Appearance.colors.colSubtext
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["xdg-open", row.filePath])
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                StyledText {
                                    Layout.fillWidth: true
                                    text: row.fileName
                                    elide: Text.ElideMiddle
                                    color: Appearance.colors.colOnLayer1
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: Qt.formatDateTime(row.fileModified, "dd/MM/yyyy  HH:mm")
                                        + "  ·  " + (row.fileSize / 1048576).toFixed(1) + " MB"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                            }

                            Row {
                                spacing: 2
                                opacity: rowHover.hovered ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                                Repeater {
                                    model: [
                                        { icon: "play_arrow", tip: Translation.tr("Play"), act: "play" },
                                        { icon: "folder_open", tip: Translation.tr("Show in folder"), act: "folder" },
                                        { icon: "delete", tip: Translation.tr("Move to the trash"), act: "trash" }
                                    ]
                                    delegate: RippleButton {
                                        id: actionButton
                                        required property var modelData
                                        implicitWidth: 34
                                        implicitHeight: 34
                                        buttonRadius: Appearance.rounding.full
                                        onClicked: {
                                            if (modelData.act === "play") Quickshell.execDetached(["xdg-open", row.filePath])
                                            else if (modelData.act === "folder") Quickshell.execDetached(["xdg-open", root.saveDir])
                                            else root.runFor(row.filePath, 'gio trash -- "$1"; rm -f -- "' + root.thumbDir + '/$(basename "$1").jpg"')
                                        }
                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            text: actionButton.modelData.icon
                                            iconSize: Appearance.font.pixelSize.larger
                                            color: modelData.act === "trash" ? Appearance.colors.colError : Appearance.colors.colOnLayer1
                                        }
                                        StyledToolTip { text: actionButton.modelData.tip }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
