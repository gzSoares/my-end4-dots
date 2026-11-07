pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

/**
 * Whether something is recording the screen, and for how long.
 *
 * Hyprland's capture events say that frames are flowing, not that a recording
 * is alive: on a screen where nothing changes a session closes after half a
 * second and opens again a few seconds later, for as long as the recording
 * lasts. So a closed session does not end anything by itself.
 *
 * Known recorders are asked about directly, which gives their exact age and
 * end: wf-recorder, the shell's own, and GPU Screen Recorder, which captures
 * from the GPU and so raises no Hyprland event at all. That is why this check
 * runs all the time rather than only after an event. Its replay mode, a buffer
 * that can stay on in the background, is not a recording.
 *
 * For any other app the gaps are waited out, and it takes either a session that
 * stays open or a second one soon after to count: a screenshot is one short
 * session.
 *
 * Sessions on a single window are left out. They are what the overview, the
 * dock and the phone mirror open for their live thumbnails.
 */
Singleton {
    id: root

    readonly property int confirmDelay: 1500
    // Longer than the widest gap between sessions on a still screen, about 2.5s.
    readonly property int gapTolerance: 3500

    property bool active: false
    property int elapsedSeconds: 0
    readonly property string elapsedText: {
        const t = root.elapsedSeconds;
        const pad = n => n.toString().padStart(2, "0");
        const clock = pad(Math.floor(t / 60) % 60) + ":" + pad(t % 60);
        return t >= 3600 ? Math.floor(t / 3600) + ":" + clock : clock;
    }

    property bool tracking: false
    property int openSessions: 0
    property real startedAt: 0
    property bool recorderSeen: false

    function tick() {
        root.elapsedSeconds = Math.max(0, Math.floor((Date.now() - root.startedAt) / 1000));
    }

    function confirm() {
        root.tick();
        root.active = true;
    }

    function finish() {
        confirmTimer.stop();
        gapTimer.stop();
        root.active = false;
        root.tracking = false;
        root.recorderSeen = false;
        root.openSessions = 0;
        root.elapsedSeconds = 0;
    }

    function sessionOpened() {
        gapTimer.stop();
        if (!root.tracking) {
            root.tracking = true;
            root.startedAt = Date.now();
            confirmTimer.restart();
        } else if (!root.active && Date.now() - root.startedAt >= root.confirmDelay) {
            root.confirm();
        }
        root.openSessions++;
    }

    function sessionClosed() {
        root.openSessions = Math.max(0, root.openSessions - 1);
        if (root.tracking && root.openSessions === 0) gapTimer.restart();
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "screencastv2") return;
            const [state, owner] = event.data.split(",");
            if (owner === "window") return;
            if (state === "1") root.sessionOpened();
            else root.sessionClosed();
        }
    }

    Timer {
        id: confirmTimer
        interval: root.confirmDelay
        onTriggered: if (root.openSessions > 0) root.confirm()
    }

    Timer {
        id: gapTimer
        interval: root.gapTolerance
        onTriggered: if (root.openSessions === 0 && !root.recorderSeen) root.finish()
    }

    Timer {
        interval: root.tracking ? 1000 : 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (root.active) root.tick();
            if (!recorderProc.running) recorderProc.running = true;
        }
    }

    // The age in seconds of the newest recorder, or nothing.
    Process {
        id: recorderProc
        command: ["bash", "-c", `ps -eo etimes=,args= | awk '
            $2 ~ /(^|\\/)wf-recorder$/ { print $1 }
            $2 ~ /(^|\\/)gpu-screen-recorder$/ && / -w / && !/ -r [0-9]/ { print $1 }
        ' | sort -n | head -1`]
        stdout: StdioCollector {
            onStreamFinished: {
                const age = parseInt(this.text.trim());
                if (isNaN(age)) {
                    if (root.recorderSeen) root.finish();
                    return;
                }
                root.tracking = true;
                root.recorderSeen = true;
                root.startedAt = Date.now() - age * 1000;
                root.confirm();
            }
        }
    }
}
