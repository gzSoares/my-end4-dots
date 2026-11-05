//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_SCALE_FACTOR=1

// screenshot-app.qml — screenshot utility in the shell's own look.
//
// Takes a region, a window or a whole screen, optionally after a delay, and
// keeps a gallery of what is in the save folder (Config screenSnip.savePath,
// the same folder the region selector saves to), where each shot can be
// copied, edited, shown in the file manager or sent to the trash.
//
// The window gets out of the way before the shot (hidden, then back with the
// result). Everything the shot needs reaches the script as arguments, never
// pasted into its text, so no path or option can alter the commands.
//
// Open it with:  qs -p ~/.config/quickshell/ii/screenshot-app.qml --no-duplicate
// (straight to the area selector); add SCREENSHOT_APP_WINDOW=1 for this window.
// Needs: grim, slurp, jq, wl-clipboard, hyprctl (all already used by the shell),
// and satty or swappy for the edit button.

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

ApplicationWindow {
    id: root
    // Opened plainly, it goes straight to the area selector with no window, as
    // Super+Shift+S does. SCREENSHOT_APP_WINDOW=1 opens this window instead.
    readonly property bool windowMode: Quickshell.env("SCREENSHOT_APP_WINDOW") === "1"
    visible: windowMode
    width: 800
    height: 720
    minimumWidth: 560
    minimumHeight: 520
    color: Appearance.m3colors.m3background
    title: Translation.tr("Screenshot")

    // ── State ──────────────────────────────────────────────────────
    property string mode: "region"      // region | window | screen
    property int delay: 0               // seconds, before the shot
    property bool copyToClipboard: true
    property bool includeCursor: false
    property bool editAfter: false

    property bool capturing: false
    property string status: ""
    property string resultKind: ""      // "", "success", "error"
    property string lastFile: ""

    readonly property string saveDir: FileUtils.trimFileProtocol(Config.options.screenSnip.savePath)
    readonly property string editor: Config.options.regionSelector.annotation.useSatty ? "satty" : "swappy"

    onClosing: Qt.quit()

    // The script, for the window and screen modes (a region goes through the
    // shell's own selector, see captureRegion). $1 mode, $2 delay, $3 copy, $4 cursor, $5 edit, $6 folder,
    // $7 editor. Prints the saved file's path on its first line. Exit 2 is a
    // selection the user backed out of.
    readonly property string captureScript: `
mode="$1"; delay="$2"; copy="$3"; cursor="$4"; edit="$5"; dir="$6"; editor="$7"
mkdir -p -- "$dir" || exit 3
file="$dir/screenshot-$(date '+%Y-%m-%d_%H.%M.%S').png"
sleep 0.4
args=()
case "$mode" in
  window)
    ws=$(hyprctl monitors -j | jq -c '[.[].activeWorkspace.id]')
    geom=$(hyprctl clients -j | jq -r --argjson ws "$ws" '.[] | select(.mapped and (.workspace.id as $w | $ws | index($w))) | "\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"' | slurp -r) || exit 2
    args=(-g "$geom") ;;
  *)
    out=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
    [ -n "$out" ] && args=(-o "$out") ;;
esac
[ "$delay" -gt 0 ] && sleep "$delay"
[ "$cursor" = 1 ] && args+=(-c)
grim "\${args[@]}" "$file" || exit 4
[ "$copy" = 1 ] && wl-copy --type image/png < "$file"
echo "$file"
if [ "$edit" = 1 ] && command -v "$editor" >/dev/null; then
  setsid "$editor" -f "$file" >/dev/null 2>&1 &
fi
exit 0
`

    // A region is picked with the shell's own area selector, by triggering the
    // same global shortcut as Super+Shift+S (quickshell:regionScreenshot), so it
    // looks and behaves exactly as that does (left click copies, right click opens the editor).
    // The window steps aside first, and comes back once the selector is gone.
    function captureRegion() {
        root.capturing = true
        root.resultKind = ""
        root.status = Translation.tr("Select an area…")
        root.selectorSeen = false
        root.selectorPolls = 0
        root.visible = false
        regionStart.restart()
    }
    property bool selectorSeen: false
    property int selectorPolls: 0

    Component.onCompleted: {
        if (!root.windowMode) {
            root.selectorSeen = false
            root.selectorPolls = 0
            regionStart.interval = 50
            regionStart.restart()
        }
    }

    Timer {
        id: regionStart
        interval: 400
        onTriggered: {
            Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.global("quickshell:regionScreenshot")'])
            selectorWatch.restart()
        }
    }
    // Watches for the selector's layer to appear and go away again.
    Timer {
        id: selectorWatch
        interval: 300
        repeat: true
        onTriggered: if (!layersProc.running) layersProc.running = true
    }
    Process {
        id: layersProc
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const open = text.indexOf("quickshell:regionSelector") !== -1
                root.selectorPolls++
                if (open) root.selectorSeen = true
                // Gone after having been there, or never showed up within ~4 s
                if ((root.selectorSeen && !open) || (!root.selectorSeen && root.selectorPolls > 13)) {
                    selectorWatch.stop()
                    root.capturing = false
                    if (!root.windowMode) {
                        // No window to come back to: the job is done
                        if (!root.selectorSeen)
                            Quickshell.execDetached(["notify-send", "-a", Translation.tr("Screenshot"), Translation.tr("The area selector did not open")])
                        Qt.quit()
                        return
                    }
                    root.visible = true
                    root.raise()
                    root.requestActivate()
                    root.resultKind = root.selectorSeen ? "success" : "error"
                    root.status = root.selectorSeen
                        ? Translation.tr("Done — new shots appear below")
                        : Translation.tr("The area selector did not open")
                }
            }
        }
    }

    function capture() {
        if (root.capturing) return
        if (root.mode === "region") {
            root.captureRegion()
            return
        }
        root.capturing = true
        root.resultKind = ""
        root.status = root.mode === "window" ? Translation.tr("Click a window…")
            : Translation.tr("Capturing…")
        captureProc.command = ["bash", "-c", root.captureScript, "screenshot",
            root.mode, String(root.delay), root.copyToClipboard ? "1" : "0",
            root.includeCursor ? "1" : "0", root.editAfter ? "1" : "0",
            root.saveDir, root.editor]
        // Out of the way first, so the window is not in its own picture.
        root.visible = false
        captureProc.running = true
    }

    Process {
        id: captureProc
        stdout: StdioCollector {
            id: captureOut
        }
        stderr: StdioCollector {
            id: captureErr
        }
        onExited: (exitCode, exitStatus) => {
            root.capturing = false
            root.visible = true
            root.raise()
            root.requestActivate()
            const path = captureOut.text.trim().split("\n")[0] ?? ""
            if (exitCode === 0 && path.length > 0) {
                root.lastFile = path
                root.resultKind = "success"
                root.status = root.copyToClipboard
                    ? Translation.tr("Saved and copied to the clipboard")
                    : Translation.tr("Saved")
                Quickshell.execDetached(["notify-send", "-a", Translation.tr("Screenshot"),
                    "-i", path, "-h", "boolean:transient:true",
                    Translation.tr("Screenshot saved"), path])
            } else if (exitCode === 2) {
                root.resultKind = ""
                root.status = Translation.tr("Cancelled")
            } else {
                root.resultKind = "error"
                const err = captureErr.text.trim()
                root.status = err.length > 0 ? err.split("\n").slice(-1)[0]
                    : Translation.tr("The screenshot could not be taken")
            }
        }
    }

    // Per-file actions. The file goes in as an argument.
    function runFor(file, script) {
        Quickshell.execDetached(["bash", "-c", script, "screenshot", file, root.editor])
    }
    function copyFile(file) {
        root.runFor(file, 'wl-copy --type image/png < "$1"')
        root.resultKind = "success"
        root.status = Translation.tr("Copied to the clipboard")
    }
    function editFile(file) {
        root.runFor(file, 'setsid "$2" -f "$1" >/dev/null 2>&1 &')
    }
    function openFile(file) {
        Quickshell.execDetached(["xdg-open", file])
    }
    function revealFolder() {
        Quickshell.execDetached(["xdg-open", root.saveDir])
    }
    function trashFile(file) {
        root.runFor(file, 'gio trash -- "$1"')
        root.resultKind = ""
        root.status = Translation.tr("Moved to the trash")
    }

    // ── Layout ─────────────────────────────────────────────────────
    // Same chrome as the other shell apps: m3background window, content on a
    // rounded m3surfaceContainerLow pane.
    property real contentPadding: 8

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.contentPadding
        color: Appearance.m3colors.m3surfaceContainerLow
        radius: RoundedCorners.on ? Appearance.rounding.windowRounding - root.contentPadding : 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                MaterialSymbol {
                    text: "screenshot_region"
                    iconSize: Appearance.font.pixelSize.hugeass
                    color: Appearance.colors.colOnSecondaryContainer
                }
                StyledText {
                    text: Translation.tr("Screenshot")
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnSecondaryContainer
                }
                Item { Layout.fillWidth: true }
            }

            // Capture options
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: optionsColumn.implicitHeight + 28
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1

                ColumnLayout {
                    id: optionsColumn
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 14
                    }
                    spacing: 10

                    ConfigSelectionArray {
                        currentValue: root.mode
                        onSelected: newValue => root.mode = newValue
                        options: [
                            { displayName: Translation.tr("Region"), icon: "crop_free", value: "region" },
                            { displayName: Translation.tr("Window"), icon: "web_asset", value: "window" },
                            { displayName: Translation.tr("Screen"), icon: "desktop_windows", value: "screen" }
                        ]
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.mode === "region"
                        wrapMode: Text.WordWrap
                        text: Translation.tr("The area is picked with the shell's own selector, the same as Super+Shift+S: a left click copies the shot to the clipboard, a right click opens it in the editor.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        enabled: root.mode !== "region"
                        opacity: root.mode === "region" ? 0.4 : 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        MaterialSymbol {
                            text: "timer"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: Translation.tr("Delay")
                            color: Appearance.colors.colSubtext
                        }
                        ConfigSelectionArray {
                            Layout.fillWidth: false
                            currentValue: root.delay
                            onSelected: newValue => root.delay = newValue
                            options: [
                                { displayName: Translation.tr("None"), value: 0 },
                                { displayName: "3 s", value: 3 },
                                { displayName: "5 s", value: 5 },
                                { displayName: "10 s", value: 10 }
                            ]
                        }
                        Item { Layout.fillWidth: true }
                    }

                    ConfigSwitch {
                        buttonIcon: "content_copy"
                        text: Translation.tr("Copy to the clipboard")
                        checked: root.copyToClipboard
                        onCheckedChanged: root.copyToClipboard = checked
                    }
                    ConfigSwitch {
                        buttonIcon: "arrow_selector_tool"
                        text: Translation.tr("Include the mouse cursor")
                        checked: root.includeCursor
                        onCheckedChanged: root.includeCursor = checked
                    }
                    ConfigSwitch {
                        buttonIcon: "edit"
                        text: Translation.tr("Open in the editor afterwards")
                        checked: root.editAfter
                        onCheckedChanged: root.editAfter = checked
                    }
                    }
                }
            }

            // Capture button + status
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                FloatingActionButton {
                    id: captureButton
                    expanded: true
                    enabled: !root.capturing
                    iconText: "photo_camera"
                    onClicked: root.capture()
                    contentItem: Row {
                        spacing: 8
                        anchors.centerIn: parent
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "photo_camera"
                            iconSize: Appearance.font.pixelSize.huge
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (root.delay > 0 && root.mode !== "region")
                                ? Translation.tr("Capture in %1 s").arg(root.delay)
                                : Translation.tr("Capture")
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }
                    implicitWidth: 56 + 130
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.status.length > 0
                    text: root.status
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.resultKind === "error" ? Appearance.colors.colError
                        : root.resultKind === "success" ? Appearance.colors.colPrimary
                        : Appearance.colors.colSubtext
                }
                Item {
                    Layout.fillWidth: true
                    visible: root.status.length === 0
                }
            }

            // Gallery header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                StyledText {
                    text: Translation.tr("Recent screenshots")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    Layout.fillWidth: true
                    text: gallery.count > 0 ? gallery.count : ""
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
                RippleButton {
                    implicitHeight: 32
                    implicitWidth: openFolderRow.implicitWidth + 24
                    buttonRadius: Appearance.rounding.full
                    onClicked: root.revealFolder()
                    contentItem: Row {
                        id: openFolderRow
                        spacing: 6
                        anchors.centerIn: parent
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "folder_open"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Translation.tr("Open folder")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }
            }

            // Gallery
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                clip: true

                FolderListModel {
                    id: gallery
                    folder: "file://" + root.saveDir
                    nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
                    showDirs: false
                    sortField: FolderListModel.Time
                    sortReversed: true
                }

                // Empty state
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: gallery.count === 0
                    spacing: 8
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "image"
                        iconSize: 40
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("No screenshots yet")
                        color: Appearance.colors.colSubtext
                    }
                }

                GridView {
                    id: grid
                    anchors.fill: parent
                    anchors.margins: 8
                    visible: gallery.count > 0
                    clip: true
                    model: gallery
                    readonly property int columns: Math.max(2, Math.floor(width / 190))
                    cellWidth: Math.floor(width / columns)
                    cellHeight: Math.round(cellWidth * 0.68)
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: StyledScrollBar {}

                    delegate: Item {
                        id: cell
                        required property string filePath
                        required property string fileName
                        required property var fileModified
                        width: grid.cellWidth
                        height: grid.cellHeight

                        HoverHandler { id: cellHover }

                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer2

                            Image {
                                anchors.fill: parent
                                source: "file://" + cell.filePath
                                asynchronous: true
                                cache: false
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 420
                                sourceSize.height: 300
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openFile(cell.filePath)
                            }

                            // Name strip along the bottom
                            Rectangle {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    bottom: parent.bottom
                                }
                                height: 24
                                color: ColorUtils.transparentize(Appearance.m3colors.m3scrim, 0.45)
                                opacity: cellHover.hovered ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                                StyledText {
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        margins: 8
                                    }
                                    text: Qt.formatDateTime(cell.fileModified, "dd/MM/yyyy  HH:mm:ss")
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: "white"
                                }
                            }

                            // Actions, shown while hovering
                            Row {
                                anchors {
                                    top: parent.top
                                    right: parent.right
                                    margins: 6
                                }
                                spacing: 4
                                opacity: cellHover.hovered ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 120 } }

                                Repeater {
                                    model: [
                                        { icon: "content_copy", tip: Translation.tr("Copy"), act: "copy" },
                                        { icon: "edit", tip: Translation.tr("Edit"), act: "edit" },
                                        { icon: "delete", tip: Translation.tr("Move to the trash"), act: "trash" }
                                    ]
                                    delegate: RippleButton {
                                        id: actionButton
                                        required property var modelData
                                        implicitWidth: 30
                                        implicitHeight: 30
                                        buttonRadius: Appearance.rounding.full
                                        colBackground: Appearance.colors.colSurfaceContainer
                                        colBackgroundHover: Appearance.colors.colSurfaceContainerHigh
                                        onClicked: {
                                            if (modelData.act === "copy") root.copyFile(cell.filePath)
                                            else if (modelData.act === "edit") root.editFile(cell.filePath)
                                            else root.trashFile(cell.filePath)
                                        }
                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            text: actionButton.modelData.icon
                                            iconSize: Appearance.font.pixelSize.larger
                                            color: modelData.act === "trash"
                                                ? Appearance.colors.colError
                                                : Appearance.colors.colOnLayer1
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
