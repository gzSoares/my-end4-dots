pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Check the microphone and the speakers before a call: a level meter that says
 * whether the voice is too quiet, good, loud or clipping, a chime on the
 * output, and a short recording played back so you can hear yourself. The microphone is read here, through
 * PipeWire, since Discord does not report its input level.
 */
Rectangle {
    id: root

    property bool open: false
    // Levels in dBFS: the last reading and the peak held for a moment
    property real peak: -90
    property real hold: -90
    property string meterError: ""
    // The playback test: "idle", "recording" or "playing"
    property string testState: "idle"
    property string testError: ""

    readonly property string scripts: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/discord`
    readonly property bool meterOn: root.open && root.visible && !DiscordService.inCall

    implicitHeight: col.implicitHeight + 2 * Appearance.spacing.md
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2

    // Bar scale: -60 dB (nothing) to 0 dB (full scale)
    function level(db) { return Math.max(0, Math.min(1, (db + 60) / 60)); }

    readonly property string verdict: {
        if (root.hold <= -60) return Translation.tr("No sound. Say something");
        if (root.hold < -35) return Translation.tr("Too quiet");
        if (root.hold < -18) return Translation.tr("A bit quiet");
        if (root.hold <= -6) return Translation.tr("Good");
        if (root.hold < -1) return Translation.tr("Loud");
        return Translation.tr("Clipping: too loud");
    }
    readonly property color verdictColor: {
        if (root.hold <= -60) return Appearance.colors.colSubtext;
        if (root.hold < -35) return "#e0a43a";
        if (root.hold < -18) return "#9fc24a";
        if (root.hold <= -6) return "#3ba55d";
        if (root.hold < -1) return "#e0a43a";
        return Appearance.colors.colError;
    }

    onMeterOnChanged: {
        if (!root.meterOn) {
            root.peak = -90;
            root.hold = -90;
            root.meterError = "";
        }
    }
    onOpenChanged: if (!root.open && recProc.running) recProc.running = false

    // The meter: one reading every 50 ms while the card is open
    Process {
        id: meter
        running: root.meterOn
        command: ["python3", `${root.scripts}/mic_meter.py`, DiscordService.settings.inputDevice ?? ""]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const d = JSON.parse(line);
                    if (d.error !== undefined) {
                        root.meterError = d.error;
                        return;
                    }
                    root.meterError = "";
                    root.peak = d.peak;
                    if (d.peak >= root.hold) {
                        root.hold = d.peak;
                        holdTimer.restart();
                    }
                } catch (e) {}
            }
        }
    }
    // The held peak stays 1.5 s, then falls: that is what the verdict reads
    Timer {
        id: holdTimer
        interval: 1500
        onTriggered: fall.start()
    }
    Timer {
        id: fall
        interval: 100
        repeat: true
        onTriggered: {
            root.hold = Math.max(root.peak, root.hold - 5);
            if (root.hold <= root.peak) fall.stop();
        }
    }

    // Hear yourself: record a few seconds, then play them back. The microphone is
    // closed by the time the sound plays, so it cannot feed back whatever the output.
    Process {
        id: recProc
        command: ["python3", `${root.scripts}/mic_playback.py`, DiscordService.settings.inputDevice ?? "", "4"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const d = JSON.parse(line);
                    if (d.error !== undefined) { root.testError = d.error; root.testState = "idle"; return; }
                    if (d.state === "recording" || d.state === "playing") { root.testError = ""; root.testState = d.state; }
                    else if (d.state === "done") root.testState = "idle";
                } catch (e) {}
            }
        }
        onExited: root.testState = "idle"
    }

    Process {
        id: toneProc
        command: ["python3", `${root.scripts}/test_tone.py`]
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Appearance.spacing.md
        spacing: Appearance.spacing.sm

        RippleButton {
            Layout.fillWidth: true
            implicitHeight: 36
            buttonRadius: Appearance.rounding.verysmall
            colBackground: "transparent"
            onClicked: root.open = !root.open
            contentItem: RowLayout {
                spacing: Appearance.spacing.md
                MaterialSymbol {
                    text: "graphic_eq"
                    iconSize: 20
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Test microphone and audio")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer2
                }
                MaterialSymbol {
                    text: root.open ? "keyboard_arrow_up" : "keyboard_arrow_down"
                    iconSize: 20
                    color: Appearance.colors.colSubtext
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.open
            spacing: Appearance.spacing.sm

            StyledText {
                Layout.fillWidth: true
                visible: DiscordService.inCall
                wrapMode: Text.Wrap
                text: Translation.tr("You are in a call: the microphone is in use there. Leave it to test.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            // Level bar with its zones: quiet, good, loud, clipping
            Item {
                id: bar
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                visible: !DiscordService.inCall

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.verysmall
                    color: Appearance.colors.colLayer3
                    clip: true
                    // zones behind the fill
                    Row {
                        anchors.fill: parent
                        opacity: 0.35
                        Rectangle { width: parent.width * root.level(-35); height: parent.height; color: "#e0a43a" }
                        Rectangle { width: parent.width * (root.level(-18) - root.level(-35)); height: parent.height; color: "#9fc24a" }
                        Rectangle { width: parent.width * (root.level(-6) - root.level(-18)); height: parent.height; color: "#3ba55d" }
                        Rectangle { width: parent.width * (root.level(-1) - root.level(-6)); height: parent.height; color: "#e0a43a" }
                        Rectangle { width: parent.width * (1 - root.level(-1)); height: parent.height; color: Appearance.colors.colError }
                    }
                    Rectangle {
                        width: parent.width * root.level(root.peak)
                        height: parent.height
                        color: root.peak >= -1 ? Appearance.colors.colError
                            : (root.peak >= -6 ? "#e0a43a" : (root.peak >= -18 ? "#3ba55d" : Appearance.colors.colPrimary))
                        Behavior on width { NumberAnimation { duration: 60 } }
                    }
                    // held peak
                    Rectangle {
                        x: Math.min(parent.width - width, parent.width * root.level(root.hold))
                        width: 3
                        height: parent.height
                        color: Appearance.colors.colOnLayer2
                        visible: root.hold > -60
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !DiscordService.inCall && root.meterError === ""
                StyledText {
                    Layout.fillWidth: true
                    text: root.verdict
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: root.verdictColor
                }
                StyledText {
                    text: root.hold > -90 ? Math.round(root.hold) + " dB" : ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
            StyledText {
                Layout.fillWidth: true
                visible: !DiscordService.inCall && root.meterError === ""
                wrapMode: Text.Wrap
                text: Translation.tr("Speak normally. The mark should stay in the green; if it reaches red, lower the microphone volume.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.testError !== ""
                wrapMode: Text.Wrap
                text: root.testError
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colError
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.meterError !== ""
                wrapMode: Text.Wrap
                text: root.meterError
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colError
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.sm

                RippleButton {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.verysmall
                    colBackground: Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    onClicked: toneProc.running = true
                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: Appearance.spacing.sm
                        MaterialSymbol {
                            text: "volume_up"
                            iconSize: 18
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                        StyledText {
                            text: Translation.tr("Play test sound")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }
                }
                RippleButton {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 40
                    // Not disabled while it records: a disabled button is drawn at 40%, which
                    // would leave its text unreadable. A click while busy is just ignored.
                    enabled: !DiscordService.inCall
                    buttonRadius: Appearance.rounding.verysmall
                    colBackground: root.testState !== "idle" ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer
                    colBackgroundHover: root.testState !== "idle" ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainerHover
                    onClicked: if (root.testState === "idle") recProc.running = true
                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: Appearance.spacing.sm
                        MaterialSymbol {
                            text: root.testState === "recording" ? "fiber_manual_record" : (root.testState === "playing" ? "play_arrow" : "hearing")
                            iconSize: 18
                            color: root.testState !== "idle" ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                        }
                        StyledText {
                            text: root.testState === "recording" ? Translation.tr("Recording… speak")
                                : (root.testState === "playing" ? Translation.tr("Playing back…") : Translation.tr("Record and hear me"))
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: root.testState !== "idle" ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                        }
                    }
                }
            }
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Translation.tr("Record and hear me records 4 seconds of your voice and plays them back, so you can judge how you sound. It works with speakers or headphones.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }
}
