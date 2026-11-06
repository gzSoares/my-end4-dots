import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sysmonitor

/**
 * Containers — Podman/Docker containers + Ollama models in the ii shell style.
 *   qs -c ii ipc call containers toggle
 */
Scope {
    id: root
    property bool shown: false
    property string terminal: "kitty"   // used for "enter container"

    IpcHandler {
        target: "containers"
        function toggle(): void {
            root.shown = !root.shown;
        }
        function open(): void {
            root.shown = true;
        }
        function close(): void {
            root.shown = false;
        }
    }

    LazyLoader {
        active: root.shown

        component: FloatingWindow {
            id: win
            title: "Containers"
            implicitWidth: 1280
            implicitHeight: 820
            color: Appearance.m3colors.m3background
            visible: true
            onVisibleChanged: if (!visible)
                root.shown = false

            // ── state ───────────────────────────────────────────
            property string engine: ""
            property string error: ""
            property var containers: []
            property var ollama: ({ online: false, url: "", models: [] })
            property var images: []
            property var cpuHistories: ({})
            property string logsId: ""
            property string logsName: ""
            property string logsText: ""
            readonly property int runningCount: containers.filter(c => c.state === "running").length

            function send(line) {
                if (backend.running)
                    backend.write(line + "\n");
            }
            function formatBytes(b) {
                const u = ["B", "KiB", "MiB", "GiB", "TiB"];
                let i = 0;
                b = b || 0;
                while (b >= 1024 && i < u.length - 1) {
                    b /= 1024;
                    i++;
                }
                return (i === 0 ? Math.round(b) : b.toFixed(b >= 100 ? 0 : 1)) + " " + u[i];
            }
            function handle(line) {
                let m;
                try {
                    m = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (m.type === "info") {
                    win.engine = m.engine;
                } else if (m.type === "state") {
                    win.engine = m.engine;
                    win.error = m.error;
                    win.containers = m.containers;
                    win.ollama = m.ollama;
                    const h = {};
                    for (const c of m.containers) {
                        const prev = win.cpuHistories[c.id] || [];
                        const a = prev.length >= 30 ? prev.slice(prev.length - 29) : prev.slice();
                        a.push(c.cpu);
                        h[c.id] = a;
                    }
                    win.cpuHistories = h;
                } else if (m.type === "images") {
                    win.images = m.images;
                } else if (m.type === "logs") {
                    if (m.id === win.logsId)
                        win.logsText = m.text;
                } else if (m.type === "msg") {
                    toast.show(m.text, m.ok);
                }
            }
            function openLogs(c) {
                if (win.logsId === c.id) {
                    win.logsId = "";
                    return;
                }
                win.logsId = c.id;
                win.logsName = c.name;
                win.logsText = "Loading…";
                send("logs " + c.id);
            }
            function openTerminal(c) {
                const inner = (c.kind === "distrobox") ? ["distrobox", "enter", c.name] : (c.kind === "toolbox") ? ["toolbox", "enter", c.name] : [win.engine, "exec", "-it", c.name, "sh", "-c", "command -v bash >/dev/null && exec bash || exec sh"];
                Quickshell.execDetached([root.terminal, "-e"].concat(inner));
            }

            Process {
                id: backend
                running: true
                stdinEnabled: true
                command: ["python3", "-u", decodeURIComponent(String(Qt.resolvedUrl("../../scripts/containers/containers.py")).replace(/^file:\/\//, ""))]
                stdout: SplitParser {
                    onRead: data => win.handle(data)
                }
                stderr: SplitParser {
                    onRead: data => console.warn("[Containers]", data)
                }
                onRunningChanged: if (running)
                    imagesTimer.start()
            }
            Timer {
                id: imagesTimer
                interval: 400
                onTriggered: win.send("images")
            }
            Timer {
                interval: 2500
                repeat: true
                running: win.logsId.length > 0
                onTriggered: win.send("logs " + win.logsId)
            }

            FocusScope {
                anchors.fill: parent
                focus: true
                Component.onCompleted: forceActiveFocus()
                Keys.onEscapePressed: {
                    if (win.logsId.length > 0)
                        win.logsId = "";
                    else
                        root.shown = false;
                }
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_F5 || (e.key === Qt.Key_R && (e.modifiers & Qt.ControlModifier))) {
                        win.send("refresh");
                        win.send("images");
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    SysAppHeader {
                        icon: "deployed_code"
                        title: "Containers"
                        subtitle: win.engine ? `${win.engine}  ·  ${win.runningCount} running  ·  ${win.containers.length - win.runningCount} stopped` : "Looking for podman / docker…"
                        onCloseRequested: root.shown = false

                        SysChip {
                            icon: win.ollama.online ? "smart_toy" : "cloud_off"
                            text: win.ollama.online ? "Ollama online" : "Ollama offline"
                            accent: win.ollama.online ? Appearance.m3colors.m3primary : Appearance.colors.colSubtext
                        }
                        SysButton {
                            icon: "refresh"
                            text: "Refresh"
                            onClicked: {
                                win.send("refresh");
                                win.send("images");
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        // ── containers + logs ───────────────────
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 12

                            SysCard {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                title: "Containers"
                                subtitle: win.error.length > 0 ? win.error : `${win.containers.length} total`
                                icon: "view_in_ar"

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 8
                                    model: win.containers
                                    ScrollBar.vertical: ScrollBar {}
                                    delegate: ContainerRow {
                                        required property var modelData
                                        width: ListView.view.width
                                        container: modelData
                                        cpuHistory: win.cpuHistories[modelData.id] || []
                                        logsOpen: win.logsId === modelData.id
                                        onAction: name => win.send(name + " " + modelData.id)
                                        onOpenLogs: win.openLogs(modelData)
                                        onOpenTerminal: win.openTerminal(modelData)
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        visible: win.containers.length === 0
                                        spacing: 6
                                        MaterialSymbol {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "inventory_2"
                                            iconSize: 42
                                            color: Appearance.colors.colSubtext
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: win.engine ? "No containers yet" : "Loading…"
                                            color: Appearance.colors.colSubtext
                                        }
                                    }
                                }
                            }

                            SysCard {
                                visible: win.logsId.length > 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: 280
                                title: "Logs  ·  " + win.logsName
                                subtitle: "last 300 lines  ·  refreshes every 2.5 s"
                                icon: "article"
                                accent: Appearance.m3colors.m3tertiary
                                headerItems: [
                                    SysButton {
                                        icon: "content_copy"
                                        implicitHeight: 30
                                        implicitWidth: 30
                                        onClicked: {
                                            Quickshell.clipboardText = win.logsText;
                                            toast.show("Logs copied", true);
                                        }
                                    },
                                    SysButton {
                                        icon: "close"
                                        implicitHeight: 30
                                        implicitWidth: 30
                                        onClicked: win.logsId = ""
                                    }
                                ]

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Appearance.rounding.small
                                    color: Appearance.colors.colLayer0
                                    clip: true
                                    Flickable {
                                        id: logFlick
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        contentHeight: logText.implicitHeight
                                        contentWidth: width
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds
                                        ScrollBar.vertical: ScrollBar {}
                                        onContentHeightChanged: if (!moving)
                                            contentY = Math.max(0, contentHeight - height)
                                        TextEdit {
                                            id: logText
                                            width: logFlick.width
                                            text: win.logsText
                                            readOnly: true
                                            selectByMouse: true
                                            wrapMode: TextEdit.WrapAnywhere
                                            textFormat: TextEdit.PlainText
                                            font.family: Appearance.font.family.monospace
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colOnLayer1
                                            selectionColor: Appearance.m3colors.m3primary
                                        }
                                    }
                                }
                            }
                        }

                        // ── ollama + images ─────────────────────
                        ColumnLayout {
                            Layout.preferredWidth: 430
                            Layout.maximumWidth: 430
                            Layout.fillHeight: true
                            spacing: 12

                            SysCard {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.verticalStretchFactor: 3
                                title: "Ollama"
                                subtitle: win.ollama.online ? `${win.ollama.models.length} models  ·  ${win.ollama.url}` : "not reachable at " + (win.ollama.url || "localhost:11434")
                                icon: "smart_toy"
                                accent: Appearance.m3colors.m3primary

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 8
                                    model: win.ollama.models
                                    ScrollBar.vertical: ScrollBar {}
                                    delegate: Rectangle {
                                        id: mrow
                                        required property var modelData
                                        property bool confirmDelete: false
                                        width: ListView.view.width
                                        implicitHeight: 64
                                        radius: Appearance.rounding.normal
                                        color: modelData.loaded ? Appearance.m3colors.m3secondaryContainer : Appearance.colors.colLayer2

                                        Timer {
                                            id: delTimer
                                            interval: 3000
                                            onTriggered: mrow.confirmDelete = false
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 10
                                            spacing: 10
                                            MaterialSymbol {
                                                text: mrow.modelData.loaded ? "memory" : "neurology"
                                                iconSize: 22
                                                color: mrow.modelData.loaded ? Appearance.m3colors.m3primary : Appearance.colors.colSubtext
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: mrow.modelData.name
                                                    elide: Text.ElideRight
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                    font.weight: Font.DemiBold
                                                    color: mrow.modelData.loaded ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
                                                }
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                    text: [mrow.modelData.params, mrow.modelData.quant, win.formatBytes(mrow.modelData.size)].filter(s => s && s.length > 0).join("  ·  ") + (mrow.modelData.loaded ? "  ·  loaded (" + (mrow.modelData.vram > 0 ? win.formatBytes(mrow.modelData.vram) + " VRAM" : win.formatBytes(mrow.modelData.ram) + " RAM") + ")" : "")
                                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                                    color: mrow.modelData.loaded ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colSubtext
                                                }
                                            }
                                            SysButton {
                                                visible: mrow.modelData.loaded
                                                icon: "eject"
                                                implicitHeight: 30
                                                implicitWidth: 30
                                                onClicked: win.send("ollama_unload " + mrow.modelData.name)
                                            }
                                            SysButton {
                                                icon: "delete"
                                                text: mrow.confirmDelete ? "Delete?" : ""
                                                danger: mrow.confirmDelete
                                                implicitHeight: 30
                                                onClicked: {
                                                    if (!mrow.confirmDelete) {
                                                        mrow.confirmDelete = true;
                                                        delTimer.restart();
                                                    } else {
                                                        mrow.confirmDelete = false;
                                                        win.send("ollama_delete " + mrow.modelData.name);
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        width: parent.width - 40
                                        visible: !win.ollama.online || win.ollama.models.length === 0
                                        spacing: 6
                                        MaterialSymbol {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: win.ollama.online ? "download" : "cloud_off"
                                            iconSize: 42
                                            color: Appearance.colors.colSubtext
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.WordWrap
                                            text: win.ollama.online ? "No models yet — ollama pull qwen2.5-coder:3b" : "Start your Ollama container to see models here"
                                            color: Appearance.colors.colSubtext
                                        }
                                    }
                                }
                            }

                            SysCard {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.verticalStretchFactor: 2
                                title: "Images"
                                subtitle: {
                                    let t = 0;
                                    for (const i of win.images)
                                        t += i.size;
                                    return `${win.images.length} images  ·  ${win.formatBytes(t)}`;
                                }
                                icon: "layers"
                                accent: Appearance.m3colors.m3secondary

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 2
                                    model: win.images
                                    ScrollBar.vertical: ScrollBar {}
                                    delegate: RowLayout {
                                        required property var modelData
                                        width: ListView.view.width
                                        height: 30
                                        spacing: 8
                                        MaterialSymbol {
                                            text: "layers"
                                            iconSize: 16
                                            color: Appearance.colors.colSubtext
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            elide: Text.ElideMiddle
                                            font.family: Appearance.font.family.monospace
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colOnLayer1
                                        }
                                        StyledText {
                                            text: win.formatBytes(modelData.size)
                                            font.family: Appearance.font.family.monospace
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                        }
                                    }
                                }
                            }
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
