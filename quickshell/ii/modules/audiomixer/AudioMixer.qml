import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sysmonitor

/**
 * Audio Mixer — outputs, inputs and per-app volume in the ii shell style.
 *   qs -c ii ipc call audiomixer toggle
 */
Scope {
    id: root
    property bool shown: false

    IpcHandler {
        target: "audiomixer"
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
            title: "Audio Mixer"
            implicitWidth: 1120
            implicitHeight: 760
            color: Appearance.m3colors.m3background
            visible: true
            onVisibleChanged: if (!visible)
                root.shown = false

            // ── PipeWire model ───────────────────────────────────
            readonly property var audioNodes: Pipewire.nodes.values.filter(n => n.audio !== null)
            readonly property var sinks: audioNodes.filter(n => n.isSink && !n.isStream)
            readonly property var sources: audioNodes.filter(n => !n.isSink && !n.isStream && !(n.name ?? "").endsWith(".monitor"))
            readonly property var playback: audioNodes.filter(n => n.isSink && n.isStream)
            readonly property var recording: audioNodes.filter(n => !n.isSink && n.isStream && !((n.properties ?? {})["stream.monitor"] === "true"))

            PwObjectTracker {
                objects: win.audioNodes
            }

            // ── keep-awake (WirePlumber suspend) ─────────────────
            property var keepAwake: []
            readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("../../scripts/audiomixer/nosuspend.py")).replace(/^file:\/\//, ""))

            Process {
                id: keepAwakeProc
                property string pendingMsg: ""
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            win.keepAwake = JSON.parse(text);
                        } catch (e) {}
                        if (keepAwakeProc.pendingMsg.length > 0)
                            toast.show(keepAwakeProc.pendingMsg, true);
                        keepAwakeProc.pendingMsg = "";
                    }
                }
            }
            function runKeepAwake(args, msg) {
                keepAwakeProc.pendingMsg = msg || "";
                keepAwakeProc.command = ["python3", win.helper].concat(args);
                keepAwakeProc.running = true;
            }
            function toggleKeepAwake(node) {
                const on = win.keepAwake.indexOf(node.name) >= 0;
                runKeepAwake([on ? "remove" : "add", node.name], on ? "Output can suspend again" : "Output will never suspend (WirePlumber restarted)");
            }
            Component.onCompleted: runKeepAwake(["list"], "")

            // ── move a stream to another device ──────────────────
            Process {
                id: moveProc
            }
            function moveStream(stream, target) {
                moveProc.command = ["pw-metadata", String(stream.id), "target.object", target.name];
                moveProc.running = true;
                toast.show("Moved " + ((stream.properties ?? {})["application.name"] || "stream") + " to " + (target.description || target.name), true);
            }

            FocusScope {
                anchors.fill: parent
                focus: true
                Component.onCompleted: forceActiveFocus()
                Keys.onEscapePressed: root.shown = false

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    SysAppHeader {
                        icon: "tune"
                        title: "Audio Mixer"
                        subtitle: {
                            const s = Pipewire.defaultAudioSink, m = Pipewire.defaultAudioSource;
                            return [s ? "Output: " + (s.description || s.name) : "", m ? "Input: " + (m.description || m.name) : ""].filter(x => x.length > 0).join("  ·  ");
                        }
                        onCloseRequested: root.shown = false

                        SysChip {
                            icon: "graphic_eq"
                            text: win.playback.length + (win.playback.length === 1 ? " app playing" : " apps playing")
                        }
                        SysButton {
                            icon: "open_in_new"
                            text: "pavucontrol"
                            onClicked: Quickshell.execDetached(["pavucontrol"])
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        // ── devices ─────────────────────────────
                        ColumnLayout {
                            Layout.preferredWidth: 480
                            Layout.maximumWidth: 480
                            Layout.fillHeight: true
                            spacing: 12

                            SysCard {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                title: "Outputs"
                                subtitle: win.sinks.length + " devices  ·  ⚡ = never suspend"
                                icon: "speaker"
                                accent: Appearance.m3colors.m3primary

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 8
                                    model: win.sinks
                                    ScrollBar.vertical: ScrollBar {}
                                    delegate: AudioDeviceRow {
                                        required property var modelData
                                        width: ListView.view.width
                                        node: modelData
                                        isDefault: Pipewire.defaultAudioSink === modelData
                                        keepAwake: win.keepAwake.indexOf(modelData.name) >= 0
                                        canKeepAwake: (modelData.name ?? "").startsWith("alsa_") || (modelData.name ?? "").startsWith("bluez_")
                                        onMakeDefault: Pipewire.preferredDefaultAudioSink = modelData
                                        onToggleKeepAwake: win.toggleKeepAwake(modelData)
                                    }
                                }
                            }

                            SysCard {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(330, 82 + win.sources.length * 98)
                                title: "Inputs"
                                subtitle: win.sources.length + " devices"
                                icon: "mic"
                                accent: Appearance.m3colors.m3tertiary

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 8
                                    model: win.sources
                                    ScrollBar.vertical: ScrollBar {}
                                    delegate: AudioDeviceRow {
                                        required property var modelData
                                        width: ListView.view.width
                                        node: modelData
                                        isInput: true
                                        isDefault: Pipewire.defaultAudioSource === modelData
                                        onMakeDefault: Pipewire.preferredDefaultAudioSource = modelData
                                    }
                                }
                            }
                        }

                        // ── applications ────────────────────────
                        SysCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            title: "Applications"
                            subtitle: "Per-app volume  ·  ⇄ moves an app to another device"
                            icon: "apps"
                            accent: Appearance.m3colors.m3tertiary

                            Flickable {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                contentHeight: appsCol.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar {}

                                ColumnLayout {
                                    id: appsCol
                                    width: parent.width
                                    spacing: 8

                                    Repeater {
                                        model: win.playback
                                        delegate: AudioStreamRow {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            node: modelData
                                            targets: win.sinks
                                            onMoveTo: t => win.moveStream(modelData, t)
                                        }
                                    }

                                    ColumnLayout {
                                        visible: win.playback.length === 0
                                        Layout.fillWidth: true
                                        Layout.topMargin: 40
                                        spacing: 6
                                        MaterialSymbol {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "music_off"
                                            iconSize: 42
                                            color: Appearance.colors.colSubtext
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "Nothing is playing"
                                            color: Appearance.colors.colSubtext
                                        }
                                    }

                                    // recording
                                    RowLayout {
                                        visible: win.recording.length > 0
                                        Layout.fillWidth: true
                                        Layout.topMargin: 10
                                        spacing: 8
                                        MaterialSymbol {
                                            text: "radio_button_checked"
                                            iconSize: 16
                                            color: Appearance.m3colors.m3error
                                        }
                                        StyledText {
                                            text: "Using the microphone"
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colOnLayer1
                                        }
                                    }
                                    Repeater {
                                        model: win.recording
                                        delegate: AudioStreamRow {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            node: modelData
                                            isRecording: true
                                            targets: win.sources
                                            onMoveTo: t => win.moveStream(modelData, t)
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
