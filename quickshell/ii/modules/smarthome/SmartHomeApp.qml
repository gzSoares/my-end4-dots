import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sysmonitor

/**
 * Smart Home — local control of Tuya lamps (Intelbras Izy, Smart Life…) via tinytuya.
 *   qs -c ii ipc call smarthome toggle        open / close the window
 *   qs -c ii ipc call smarthome lights        toggle all lamps (no window)
 *   qs -c ii ipc call smarthome scene night   apply a scene (relax read focus night cinema sunset)
 */
Scope {
    id: root
    property bool shown: false
    readonly property string script: decodeURIComponent(String(Qt.resolvedUrl("../../scripts/smarthome/smarthome.py")).replace(/^file:\/\//, ""))

    IpcHandler {
        target: "smarthome"
        function toggle(): void {
            root.shown = !root.shown;
        }
        function open(): void {
            root.shown = true;
        }
        function close(): void {
            root.shown = false;
        }
        function lights(): void {
            Quickshell.execDetached(["python3", root.script, "--oneshot", "toggle"]);
        }
        function on(): void {
            Quickshell.execDetached(["python3", root.script, "--oneshot", "on"]);
        }
        function off(): void {
            Quickshell.execDetached(["python3", root.script, "--oneshot", "off"]);
        }
        function scene(name: string): void {
            Quickshell.execDetached(["python3", root.script, "--oneshot", "scene", name]);
        }
    }

    // follow the wallpaper: matugen changes the palette → lamp follows (if enabled in the app)
    Timer {
        id: syncDebounce
        interval: 1500
        onTriggered: Quickshell.execDetached(["python3", root.script, "--wallpaper-sync", String(Appearance.m3colors.m3primary)])
    }
    Connections {
        target: Appearance.m3colors
        function onM3primaryChanged() {
            syncDebounce.restart();
        }
    }

    LazyLoader {
        active: root.shown

        component: FloatingWindow {
            id: win
            title: "Smart Home"
            implicitWidth: win.devices.length > 1 ? 1260 : 720
            implicitHeight: win.devices.length > 2 ? 820 : win.devices.length === 0 ? 660 : 560
            color: Appearance.m3colors.m3background
            visible: true
            onVisibleChanged: if (!visible)
                root.shown = false

            property var devices: []
            property var setup: ({ hasDevices: true, error: "", configPath: "", searched: [], syncWallpaper: false })
            property bool loaded: false
            readonly property var wallpaperColors: [String(Appearance.m3colors.m3primary), String(Appearance.m3colors.m3secondary), String(Appearance.m3colors.m3tertiary)]
            readonly property int onCount: devices.filter(d => d.on && d.online).length

            function send(obj) {
                if (backend.running)
                    backend.write(JSON.stringify(obj) + "\n");
            }
            function handle(line) {
                let m;
                try {
                    m = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (m.type === "setup")
                    win.setup = m;
                else if (m.type === "devices") {
                    win.devices = m.devices;
                    win.loaded = true;
                } else if (m.type === "msg")
                    toast.show(m.text, m.ok);
            }

            Process {
                id: backend
                running: true
                stdinEnabled: true
                command: ["python3", "-u", root.script]
                stdout: SplitParser {
                    onRead: data => win.handle(data)
                }
                stderr: SplitParser {
                    onRead: data => console.warn("[SmartHome]", data)
                }
            }

            FocusScope {
                anchors.fill: parent
                focus: true
                Component.onCompleted: forceActiveFocus()
                Keys.onEscapePressed: root.shown = false
                Keys.onSpacePressed: win.send({
                    cmd: win.onCount > 0 ? "all_off" : "all_on"
                })

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    SysAppHeader {
                        icon: "home"
                        title: "Smart Home"
                        subtitle: !win.loaded ? "Connecting…" : win.devices.length === 0 ? "No devices yet" : `${win.devices.length} ${win.devices.length === 1 ? "lamp" : "lamps"}  ·  ${win.onCount} on`
                        onCloseRequested: root.shown = false

                        RowLayout {
                            visible: win.devices.length > 0
                            spacing: 8
                            MaterialSymbol {
                                text: "wallpaper"
                                iconSize: 18
                                color: Appearance.colors.colSubtext
                            }
                            StyledText {
                                text: "Follow wallpaper"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                            }
                            SysSwitch {
                                checked: win.setup.syncWallpaper
                                onToggled: on => win.send({
                                    cmd: "setting",
                                    key: "syncWallpaper",
                                    value: on
                                })
                            }
                        }
                        SysButton {
                            visible: win.devices.length > 1
                            icon: win.onCount > 0 ? "light_off" : "light_mode"
                            text: win.onCount > 0 ? "All off" : "All on"
                            onClicked: win.send({
                                cmd: win.onCount > 0 ? "all_off" : "all_on"
                            })
                        }
                        SysButton {
                            icon: "refresh"
                            implicitWidth: 34
                            implicitHeight: 34
                            onClicked: win.send({
                                cmd: "reload"
                            })
                        }
                    }

                    // ── lamps ───────────────────────────────────
                    Flickable {
                        visible: win.devices.length > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: grid.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {}

                        GridLayout {
                            id: grid
                            width: parent.width
                            columns: Math.max(1, Math.floor(width / 600))
                            columnSpacing: 12
                            rowSpacing: 12
                            Repeater {
                                model: win.devices
                                delegate: LampCard {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    lamp: modelData
                                    wallpaperColors: win.wallpaperColors
                                    onCommand: cmd => win.send(cmd)
                                }
                            }
                        }
                    }

                    // ── setup guide ─────────────────────────────
                    SysCard {
                        visible: win.loaded && win.devices.length === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        title: "Connect your lamp"
                        subtitle: "Local control through tinytuya — no cloud round-trip once set up"
                        icon: "lightbulb"

                        StyledText {
                            visible: win.setup.error.length > 0
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: win.setup.error
                            color: Appearance.m3colors.m3error
                        }

                        Repeater {
                            model: [
                                { n: "1", t: "Keep the lamp in the Smart Life app (Izy → Smart Life, as you already did)." },
                                { n: "2", t: "In your Tuya IoT project (“luz quarto”): Devices → Link App Account → scan the QR code with Smart Life." },
                                { n: "3", t: "In a terminal:  mkdir -p ~/.config/tinytuya && cd ~/.config/tinytuya && python -m tinytuya wizard" },
                                { n: "4", t: "Answer the wizard (API key, secret, region “us” for Western America) and say yes to the network scan." },
                                { n: "5", t: "Press Reload below — devices.json is imported automatically." }
                            ]
                            delegate: RowLayout {
                                id: step
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 12
                                Rectangle {
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    radius: 14
                                    color: Appearance.m3colors.m3primaryContainer
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: step.modelData.n
                                        font.weight: Font.Bold
                                        color: Appearance.m3colors.m3onPrimaryContainer
                                    }
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: step.modelData.t
                                    color: Appearance.colors.colOnLayer1
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            wrapMode: Text.WordWrap
                            text: "Looked for devices.json in: " + (win.setup.searched || []).join(", ") + "\nConfig is saved to " + win.setup.configPath + " (you can rename lamps or fix IPs there)."
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        Item {
                            Layout.fillHeight: true
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Item {
                                Layout.fillWidth: true
                            }
                            SysButton {
                                icon: "terminal"
                                text: "Open terminal there"
                                onClicked: Quickshell.execDetached(["sh", "-c", "mkdir -p ~/.config/tinytuya && cd ~/.config/tinytuya && exec kitty"])
                            }
                            SysButton {
                                icon: "refresh"
                                text: "Reload"
                                tonal: true
                                onClicked: win.send({
                                    cmd: "reload"
                                })
                            }
                        }
                    }

                    Item {
                        visible: !win.loaded
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        StyledText {
                            anchors.centerIn: parent
                            text: "Talking to your lamps…"
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                SysToast {
                    id: toast
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 28
                }
            }
        }
    }
}
