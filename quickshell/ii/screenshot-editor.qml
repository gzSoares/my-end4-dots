//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_SCALE_FACTOR=1

// screenshot-editor.qml — marks up a screenshot, in the shell's own look.
//
// What comes after the area selector (Super+Shift+S): the picture opens here
// with brush, text, rectangle, oval, arrow and pixelate tools, undo and redo,
// and Copy and Save buttons. The image to open comes in the environment
// variable SCREENSHOT_EDIT_FILE; a file the selector left in the shell's temp
// folder is removed when the window closes.
//
//   B brush   T text   R rectangle   O oval   A arrow   D pixelate
//   Ctrl+Z undo   Ctrl+Shift+Z / Ctrl+Y redo   Ctrl+C copy   Ctrl+S save
//   F fill or outline (rectangle, oval)   Mouse wheel changes the size of the
//   brush / text / pixels   Esc closes (or drops the text being typed)
//
// The drawing itself lives in modules/ii/screenshotEditor/AnnotationCanvas.qml.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.screenshotEditor

TranslucentAppWindow {
    id: root
    visible: true
    width: 1180
    height: 780
    minimumWidth: 720
    minimumHeight: 480
    // Transparent window, translucent surface: the compositor blurs what is
    // behind it, as it does for the shell's panels (rule in hypr rules.lua,
    // matched on this exact title, so it is not translated).
    title: "Screenshot editor"

    readonly property string sourceFile: Quickshell.env("SCREENSHOT_EDIT_FILE") ?? ""
    // The folder from the config; with none set, Pictures/Screenshots
    readonly property string saveDir: {
        let configured = FileUtils.trimFileProtocol(Config.options.screenSnip.savePath ?? "").replace(/\/+$/, "")
        if (configured.startsWith("~")) configured = Quickshell.env("HOME") + configured.slice(1)
        return configured !== "" ? configured : FileUtils.trimFileProtocol(Directories.pictures) + "/Screenshots"
    }
    readonly property string tempDir: "/tmp/quickshell/media/"
    property string status: ""
    property string statusKind: ""      // "", "success", "error"

    readonly property var tools: [
        { key: "B", tool: "brush", icon: "brush", tip: Translation.tr("Brush") },
        { key: "T", tool: "text", icon: "match_case", tip: Translation.tr("Text") },
        { key: "R", tool: "rect", icon: "crop_square", tip: Translation.tr("Rectangle") },
        { key: "O", tool: "oval", icon: "circle", tip: Translation.tr("Oval") },
        { key: "A", tool: "arrow", icon: "arrow_right_alt", tip: Translation.tr("Arrow") },
        { key: "D", tool: "pixelate", icon: "blur_on", tip: Translation.tr("Pixelate") }
    ]

    function say(text, kind = "success") {
        root.status = text
        root.statusKind = kind
        toast.show()
    }

    // The mouse wheel sets the size of whatever the tool in use draws.
    function adjustSize(direction) {
        let label = ""
        if (canvas.tool === "text") {
            canvas.textSize = Math.max(8, Math.min(200, canvas.textSize + direction * 2))
            label = Translation.tr("Text size") + ": " + canvas.textSize
        } else if (canvas.tool === "pixelate") {
            canvas.pixelBlock = Math.max(4, Math.min(60, canvas.pixelBlock + direction * 2))
            label = Translation.tr("Pixel size") + ": " + canvas.pixelBlock
        } else {
            canvas.lineWidth = Math.max(1, Math.min(60, canvas.lineWidth + direction))
            label = Translation.tr("Line width") + ": " + canvas.lineWidth
        }
        root.say(label, "")
    }
    function toggleFill() {
        canvas.fillShape = !canvas.fillShape
        root.say(canvas.fillShape ? Translation.tr("Fill shape") : Translation.tr("Outline"), "")
    }

    onClosing: {
        // A shot the selector left in the shell's temp folder goes with the window
        if (root.sourceFile.startsWith(root.tempDir))
            Quickshell.execDetached(["rm", "-f", "--", root.sourceFile])
        Qt.quit()
    }

    // ── Output ─────────────────────────────────────────────────────
    function copy() {
        const tmp = root.tempDir + "edited-" + Date.now() + ".png"
        mkTemp.pendingPath = tmp
        mkTemp.running = true
    }
    // The temp folder may not exist yet; make it, then write and copy.
    Process {
        id: mkTemp
        property string pendingPath: ""
        command: ["mkdir", "-p", root.tempDir]
        onExited: {
            root.pendingAction = "copy"
            canvas.save(mkTemp.pendingPath)
        }
    }
    Process {
        id: copyProc
        onExited: (code, status) => root.say(code === 0
            ? Translation.tr("Copied to the clipboard")
            : Translation.tr("Could not copy the image"), code === 0 ? "success" : "error")
    }

    function save() {
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH.mm.ss")
        mkSave.pendingPath = root.saveDir + "/screenshot-" + stamp + ".png"
        mkSave.command = ["mkdir", "-p", "--", root.saveDir]
        mkSave.running = true
    }
    Process {
        id: mkSave
        property string pendingPath: ""
        onExited: (code, status) => {
            if (code !== 0) {
                root.say(Translation.tr("Could not create the folder %1").arg(root.saveDir), "error")
                return
            }
            root.pendingAction = "save"
            canvas.save(mkSave.pendingPath)
        }
    }

    // What the canvas wrote, and what it was for
    property string pendingAction: ""
    function onCanvasSaved(path, ok) {
        if (root.pendingAction === "copy") {
            if (!ok) {
                root.say(Translation.tr("Could not copy the image"), "error")
                return
            }
            copyProc.command = ["bash", "-c", 'wl-copy --type image/png < "$1"; rm -f -- "$1"', "copy", path]
            copyProc.running = true
        } else if (root.pendingAction === "save") {
            if (ok) {
                root.say(Translation.tr("Saved to %1").arg(path))
                Quickshell.execDetached(["notify-send", "-a", Translation.tr("Screenshot"),
                    "-i", path, "-h", "boolean:transient:true",
                    Translation.tr("Screenshot saved"), path])
            } else {
                root.say(Translation.tr("Could not save the image") + ": " + path, "error")
            }
        }
        root.pendingAction = ""
    }

    // ── Shortcuts ──────────────────────────────────────────────────
    // Letters step aside while text is being typed.
    Shortcut { sequence: "B"; enabled: !canvas.textEditing; onActivated: canvas.tool = "brush" }
    Shortcut { sequence: "T"; enabled: !canvas.textEditing; onActivated: canvas.tool = "text" }
    Shortcut { sequence: "R"; enabled: !canvas.textEditing; onActivated: canvas.tool = "rect" }
    Shortcut { sequence: "O"; enabled: !canvas.textEditing; onActivated: canvas.tool = "oval" }
    Shortcut { sequence: "A"; enabled: !canvas.textEditing; onActivated: canvas.tool = "arrow" }
    Shortcut { sequence: "D"; enabled: !canvas.textEditing; onActivated: canvas.tool = "pixelate" }
    Shortcut { sequence: "F"; enabled: !canvas.textEditing; onActivated: root.toggleFill() }
    Shortcut { sequence: StandardKey.Undo; onActivated: canvas.undo() }
    Shortcut { sequence: StandardKey.Redo; onActivated: canvas.redo() }
    Shortcut { sequence: "Ctrl+Y"; onActivated: canvas.redo() }
    Shortcut { sequence: StandardKey.Copy; enabled: !canvas.textEditing; onActivated: root.copy() }
    Shortcut { sequence: StandardKey.Save; onActivated: root.save() }
    Shortcut { sequence: "Escape"; enabled: !canvas.textEditing; onActivated: root.close() }

    // ── Layout ─────────────────────────────────────────────────────
    // Minimal: the picture, and one floating toolbar above it. Sizes have no
    // controls of their own; the mouse wheel sets them (see adjustSize).
    Item {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Toolbar {
                id: toolbar
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Appearance.spacing.md
                Layout.leftMargin: Appearance.spacing.md
                Layout.rightMargin: Appearance.spacing.md
                enableShadow: false
                colBackground: "transparent"   // buttons float straight over the window's blur
                spacing: 2

                ToolbarSymbolButton {
                    symbol: "undo"
                    tip: Translation.tr("Undo (Ctrl+Z)")
                    enabled: canvas.canUndo
                    onClicked: canvas.undo()
                }
                ToolbarSymbolButton {
                    symbol: "redo"
                    tip: Translation.tr("Redo (Ctrl+Shift+Z)")
                    enabled: canvas.canRedo
                    onClicked: canvas.redo()
                }
                ToolbarDivider {}

                Repeater {
                    model: root.tools
                    delegate: RippleButton {
                        id: toolButton
                        required property var modelData
                        implicitWidth: 40
                        implicitHeight: 40
                        buttonRadius: Appearance.rounding.full
                        toggled: canvas.tool === modelData.tool
                        onClicked: canvas.tool = modelData.tool
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: toolButton.modelData.icon
                            fill: toolButton.toggled ? 1 : 0
                            iconSize: Appearance.font.pixelSize.larger
                            color: toolButton.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        }
                        StyledToolTip { text: toolButton.modelData.tip + "  (" + toolButton.modelData.key + ")" }
                    }
                }

                // Rectangle and oval: filled or just the outline
                ToolbarSymbolButton {
                    visible: canvas.tool === "rect" || canvas.tool === "oval"
                    symbol: canvas.fillShape ? "square" : "check_box_outline_blank"
                    tip: (canvas.fillShape ? Translation.tr("Fill shape") : Translation.tr("Outline")) + "  (F)"
                    onClicked: root.toggleFill()
                }
                ToolbarDivider {}

                Repeater {
                    model: ["#ff3b30", "#34c759", "#0a84ff", "#ffd60a", "#ffffff", "#000000"]
                    delegate: RippleButton {
                        id: swatch
                        required property string modelData
                        implicitWidth: 28
                        implicitHeight: 40
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        onClicked: canvas.color = modelData
                        contentItem: Item {
                            Rectangle {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                radius: Appearance.rounding.fit(9)
                                color: swatch.modelData
                                border.width: 1
                                border.color: Appearance.colors.colOutlineVariant
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                radius: Appearance.rounding.small
                                color: "transparent"
                                border.width: 2
                                border.color: Appearance.colors.colPrimary
                                visible: Qt.colorEqual(canvas.color, swatch.modelData)
                            }
                        }
                    }
                }
                ToolbarDivider {}

                ToolbarSymbolButton {
                    symbol: "content_copy"
                    tip: Translation.tr("Copy to the clipboard (Ctrl+C)")
                    onClicked: root.copy()
                }
                ToolbarSymbolButton {
                    symbol: "save"
                    tip: Translation.tr("Save (Ctrl+S)")
                    onClicked: root.save()
                }
            }

            // Picture: scaled down to fit, never up
            Item {
                id: viewport
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                readonly property real fit: canvas.loaded
                    ? Math.min(1, (width - 32) / canvas.imageWidth, (height - 32) / canvas.imageHeight)
                    : 1

                Item {
                    anchors.centerIn: parent
                    width: canvas.imageWidth * viewport.fit
                    height: canvas.imageHeight * viewport.fit
                    visible: canvas.loaded

                    AnnotationCanvas {
                        id: canvas
                        source: root.sourceFile.length > 0 ? "file://" + root.sourceFile : ""
                        color: "#ff3b30"
                        transformOrigin: Item.TopLeft
                        scale: viewport.fit
                        onSaved: (path, ok) => root.onCanvasSaved(path, ok)
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => root.adjustSize(event.angleDelta.y > 0 ? 1 : -1)
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: !canvas.loaded
                    text: root.sourceFile.length === 0
                        ? Translation.tr("No image to edit")
                        : Translation.tr("Loading…")
                    color: Appearance.colors.colSubtext
                }

                // A short note, over the picture, that fades by itself
                Rectangle {
                    id: toast
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                        bottomMargin: 18
                    }
                    implicitWidth: toastText.implicitWidth + 28
                    implicitHeight: 36
                    radius: Math.min(height / 2, Appearance.rounding.full)
                    color: Appearance.m3colors.m3surfaceContainer
                    opacity: 0
                    visible: opacity > 0
                    function show() {
                        opacity = 1
                        toastHide.restart()
                    }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Timer {
                        id: toastHide
                        interval: 2200
                        onTriggered: toast.opacity = 0
                    }
                    StyledText {
                        id: toastText
                        anchors.centerIn: parent
                        text: root.status
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: root.statusKind === "error" ? Appearance.colors.colError
                            : root.statusKind === "success" ? Appearance.colors.colPrimary
                            : Appearance.colors.colOnLayer1
                    }
                }
            }
        }
    }
}
