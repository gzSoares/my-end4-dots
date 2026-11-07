//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QSG_RHI_BACKEND=opengl

// player.qml — a media player in the shell's own look, built on libmpv.
//
// Plays what mpv plays: video, audio, images and playlists. The picture is drawn
// by the MpvPlayer plugin (player/plugin), which player/build.sh compiles.
//
// Open it with player/mainstream-player [files...]
// Needs: mpv, and a VA-API driver for hardware decoding (intel-media-driver here).

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import MpvPlayer
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ApplicationWindow {
    id: root
    visible: true
    width: 1100
    height: 680
    minimumWidth: 560
    minimumHeight: 360
    color: "black"
    title: root.mediaTitle ? root.mediaTitle + " — Player" : "Player"

    // ── State, mirrored from mpv ───────────────────────────────────
    property string mediaTitle: ""
    property string filePath: ""
    property real duration: 0
    property real position: 0
    property bool paused: true
    property real volume: 100
    property bool muted: false
    property real speed: 1
    property var tracks: []
    property var playlist: []
    property int playlistPos: -1
    property var chapters: []
    property string hwdec: ""
    property bool hasPicture: false
    property var metadata: ({})
    property bool idle: true

    // ── Interface ──────────────────────────────────────────────────
    property bool controlsShown: true
    property string openPanel: ""     // "", "playlist", "tracks", "speed"
    property string toast: ""
    readonly property bool fullscreen: root.visibility === Window.FullScreen
    readonly property bool hasMedia: root.filePath !== ""
    readonly property bool keepControls: root.paused || !root.hasMedia || root.openPanel !== ""
        || seekBar.pressed || volumeSlider.pressed || controlsHover.hovered
    readonly property var audioTracks: root.tracks.filter(t => t.type === "audio")
    readonly property var subtitleTracks: root.tracks.filter(t => t.type === "sub")
    readonly property string pendingFiles: Quickshell.env("PLAYER_FILES") ?? ""

    function formatTime(seconds) {
        const t = Math.max(0, Math.floor(seconds || 0));
        const pad = n => n.toString().padStart(2, "0");
        const clock = pad(Math.floor(t / 60) % 60) + ":" + pad(t % 60);
        return t >= 3600 ? Math.floor(t / 3600) + ":" + clock : clock;
    }
    function openFiles(paths, append) {
        const list = paths.filter(p => p.length > 0);
        list.forEach((path, i) => mpv.command(["loadfile", path, (i === 0 && !append) ? "replace" : "append-play"]));
    }
    function pathFromUrl(url) {
        const text = url.toString();
        return text.startsWith("file://") ? decodeURIComponent(text.slice(7)) : text;
    }
    function togglePause() {
        if (root.hasMedia) mpv.setProperty("pause", !root.paused);
    }
    function seekBy(seconds) {
        if (root.hasMedia) mpv.command(["seek", String(seconds), "relative"]);
        root.wake();
    }
    function setVolume(value) {
        mpv.setProperty("volume", Math.max(0, Math.min(130, value)));
        root.wake();
    }
    function setSpeed(value) {
        mpv.setProperty("speed", Math.max(0.25, Math.min(4, Math.round(value * 100) / 100)));
    }
    function toggleFullscreen() {
        root.visibility = root.fullscreen ? Window.Windowed : Window.FullScreen;
    }
    function togglePanel(name) {
        root.openPanel = root.openPanel === name ? "" : name;
    }
    function trackLabel(track) {
        const parts = [track.title, track.lang?.toUpperCase(), track.codec].filter(p => p);
        return parts.length > 0 ? parts.join(" · ") : Translation.tr("Track %1").arg(track.id);
    }
    function showToast(text) {
        root.toast = text;
        toastTimer.restart();
    }
    // Any sign of life brings the controls back; they leave on their own.
    function wake() {
        root.controlsShown = true;
        hideTimer.restart();
    }
    function quit() {
        Qt.quit();
    }

    Component.onCompleted: {
        // Started on its own, so it has to ask for the shell's colors itself.
        Quickshell.watchFiles = false;
        MaterialThemeLoader.reapplyTheme();
    }
    onClosing: root.quit()

    IpcHandler {
        target: "player"
        function open(paths: string): void {
            root.openFiles(paths.split("\n"), false);
        }
        function playPause(): void {
            root.togglePause();
        }
        function seek(seconds: real): void {
            root.seekBy(seconds);
        }
        function panel(name: string): void {
            root.openPanel = name;
            root.wake();
        }
    }

    Timer {
        id: hideTimer
        interval: 2500
        running: true
        onTriggered: root.controlsShown = false
    }
    Timer {
        id: toastTimer
        interval: 3500
        onTriggered: root.toast = ""
    }

    FileDialog {
        id: fileDialog
        title: Translation.tr("Open media")
        fileMode: FileDialog.OpenFiles
        currentFolder: StandardPaths.writableLocation(StandardPaths.MoviesLocation)
        onAccepted: root.openFiles(selectedFiles.map(url => root.pathFromUrl(url)), false)
    }

    // ── The picture ────────────────────────────────────────────────
    MpvItem {
        id: mpv
        anchors.fill: parent

        readonly property var watched: ["media-title", "path", "duration", "time-pos", "pause", "volume", "mute",
            "speed", "track-list", "playlist", "playlist-pos", "chapter-list", "hwdec-current", "vo-configured",
            "metadata", "idle-active"]

        Component.onCompleted: {
            // Settings of the player itself. mpv's own config is left out on
            // purpose: its scripts and on-screen controller are for its window.
            setProperty("keep-open", "yes");
            setProperty("image-display-duration", "inf");
            setProperty("audio-display", "embedded-first");
            // A file always starts from the beginning.
            setProperty("resume-playback", "no");
            setProperty("sub-auto", "fuzzy");
            setProperty("volume-max", "130");
            watched.forEach(name => observeProperty(name));
        }
        onReadyChanged: if (ready && root.pendingFiles !== "") root.openFiles(root.pendingFiles.split("\n"), false)

        onPropertyChanged: (name, value) => {
            switch (name) {
            case "media-title": root.mediaTitle = value ?? ""; break;
            case "path": root.filePath = value ?? ""; break;
            case "duration": root.duration = value ?? 0; break;
            case "time-pos": root.position = value ?? 0; break;
            case "pause": root.paused = value ?? true; break;
            case "volume": root.volume = value ?? 100; break;
            case "mute": root.muted = value ?? false; break;
            case "speed": root.speed = value ?? 1; break;
            case "track-list": root.tracks = value ?? []; break;
            case "playlist": root.playlist = value ?? []; break;
            case "playlist-pos": root.playlistPos = value ?? -1; break;
            case "chapter-list": root.chapters = value ?? []; break;
            case "hwdec-current": root.hwdec = value ?? ""; break;
            case "vo-configured": root.hasPicture = value ?? false; break;
            case "metadata": root.metadata = value ?? ({}); break;
            case "idle-active": root.idle = value ?? true; break;
            }
        }
        onEndFile: (reason, error) => {
            if (reason === "error") root.showToast(Translation.tr("Could not play this file: %1").arg(error));
        }
    }

    // mpv stops drawing when there is no video, which would leave its last frame.
    Rectangle {
        anchors.fill: parent
        visible: !root.hasPicture
        color: Appearance.m3colors.m3background
    }

    // ── Sound without a picture ────────────────────────────────────
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 460)
        visible: root.hasMedia && !root.hasPicture
        spacing: 6

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "music_note"
            fill: 1
            iconSize: 96
            color: Appearance.colors.colPrimary
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.metadata.title ?? root.metadata.TITLE ?? root.mediaTitle
            color: Appearance.colors.colOnLayer0
            font.pixelSize: Appearance.font.pixelSize.huge
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            visible: text !== ""
            text: root.metadata.artist ?? root.metadata.ARTIST ?? ""
            color: Appearance.colors.colSubtext
        }
    }

    // ── Nothing open ───────────────────────────────────────────────
    ColumnLayout {
        anchors.centerIn: parent
        visible: !root.hasMedia
        spacing: 10

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "movie"
            iconSize: 72
            color: Appearance.colors.colPrimary
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("Drop a file here")
            color: Appearance.colors.colOnLayer0
            font.pixelSize: Appearance.font.pixelSize.larger
        }
        RippleButtonWithIcon {
            Layout.alignment: Qt.AlignHCenter
            materialIcon: "folder_open"
            mainText: Translation.tr("Open media")
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            onClicked: fileDialog.open()
        }
    }

    // ── Pointer and keys ───────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.controlsShown || root.keepControls ? Qt.ArrowCursor : Qt.BlankCursor
        onPositionChanged: root.wake()
        onClicked: mouse => {
            if (root.openPanel !== "") root.openPanel = "";
            else if (mouse.button === Qt.LeftButton) clickTimer.restart();
        }
        onDoubleClicked: {
            clickTimer.stop();
            root.toggleFullscreen();
        }
        onWheel: wheel => root.setVolume(root.volume + (wheel.angleDelta.y > 0 ? 5 : -5))
        Timer {
            id: clickTimer
            interval: 220
            onTriggered: root.togglePause()
        }
    }

    DropArea {
        anchors.fill: parent
        onDropped: drop => {
            if (!drop.hasUrls) return;
            root.openFiles(drop.urls.map(url => root.pathFromUrl(url)), root.hasMedia);
            drop.accept(Qt.CopyAction);
        }
    }

    component Keys2: Shortcut { context: Qt.WindowShortcut }
    Keys2 { sequence: "Space"; onActivated: root.togglePause() }
    Keys2 { sequence: "K"; onActivated: root.togglePause() }
    Keys2 { sequence: "Right"; onActivated: root.seekBy(5) }
    Keys2 { sequence: "Left"; onActivated: root.seekBy(-5) }
    Keys2 { sequence: "Shift+Right"; onActivated: root.seekBy(60) }
    Keys2 { sequence: "Shift+Left"; onActivated: root.seekBy(-60) }
    Keys2 { sequence: "Up"; onActivated: root.setVolume(root.volume + 5) }
    Keys2 { sequence: "Down"; onActivated: root.setVolume(root.volume - 5) }
    Keys2 { sequence: "M"; onActivated: mpv.setProperty("mute", !root.muted) }
    Keys2 { sequence: "F"; onActivated: root.toggleFullscreen() }
    Keys2 { sequence: "N"; onActivated: mpv.command(["playlist-next"]) }
    Keys2 { sequence: "P"; onActivated: mpv.command(["playlist-prev"]) }
    Keys2 { sequence: "["; onActivated: root.setSpeed(root.speed - 0.25) }
    Keys2 { sequence: "]"; onActivated: root.setSpeed(root.speed + 0.25) }
    Keys2 { sequence: "Ctrl+O"; onActivated: fileDialog.open() }
    Keys2 { sequence: "Q"; onActivated: root.quit() }
    Keys2 {
        sequence: "Esc"
        onActivated: {
            if (root.openPanel !== "") root.openPanel = "";
            else if (root.fullscreen) root.toggleFullscreen();
        }
    }

    // ── Controls ───────────────────────────────────────────────────
    component PlayerButton: RippleButton {
        id: playerButton
        property string symbol
        property string tip: ""
        property real size: 40
        property real glyph: 22
        implicitWidth: size
        implicitHeight: size
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colBackgroundToggled: Appearance.colors.colSecondaryContainer
        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: playerButton.symbol
            iconSize: playerButton.glyph
            fill: playerButton.toggled ? 1 : 0
            color: playerButton.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
        }
        StyledToolTip {
            text: playerButton.tip
            extraVisibleCondition: playerButton.tip.length > 0
        }
    }

    component Panel: Rectangle {
        radius: Appearance.rounding.normal
        // Solid: a translucent surface is not readable over a moving picture.
        color: Appearance.m3colors.m3surfaceContainer
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
    }

    component ChoiceRow: RippleButton {
        id: choiceRow
        property string label
        property string detail: ""
        property bool selected: false
        Layout.fillWidth: true
        implicitHeight: detail ? 52 : 40
        buttonRadius: Appearance.rounding.small
        colBackground: selected ? Appearance.colors.colSecondaryContainer : "transparent"
        colBackgroundHover: selected ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer1Hover
        contentItem: ColumnLayout {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 12
                rightMargin: 12
            }
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: choiceRow.label
                elide: Text.ElideMiddle
                font.pixelSize: Appearance.font.pixelSize.small
                color: choiceRow.selected ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                visible: choiceRow.detail !== ""
                text: choiceRow.detail
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }

    Item {
        id: overlay
        anchors.fill: parent
        opacity: root.controlsShown || root.keepControls ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        HoverHandler { id: controlsHover; target: bottomBar }

        // Title
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: 88
            visible: root.hasMedia
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.65) }
                GradientStop { position: 1; color: "transparent" }
            }
            RowLayout {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 16
                }
                spacing: 10
                StyledText {
                    Layout.fillWidth: true
                    text: root.mediaTitle
                    elide: Text.ElideMiddle
                    color: "white"
                    font.pixelSize: Appearance.font.pixelSize.large
                }
                Rectangle {
                    implicitWidth: decodeLabel.implicitWidth + 16
                    implicitHeight: 24
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colSecondaryContainer
                    StyledText {
                        id: decodeLabel
                        anchors.centerIn: parent
                        text: !root.hasPicture ? Translation.tr("Audio")
                            : (root.hwdec && root.hwdec !== "no") ? "GPU · " + root.hwdec : "CPU"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
            }
        }

        // Bottom bar
        Panel {
            id: bottomBar
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 14
            }
            anchors.leftMargin: Math.max(14, (parent.width - 1000) / 2)
            anchors.rightMargin: anchors.leftMargin
            height: barColumn.implicitHeight + 16

            ColumnLayout {
                id: barColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 8
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 2

                RowLayout {
                    spacing: 10
                    StyledText {
                        text: root.formatTime(seekBar.pressed ? seekBar.value : root.position)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.features: ({ "tnum": 1 })
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledSlider {
                        id: seekBar
                        Layout.fillWidth: true
                        enabled: root.hasMedia && root.duration > 0
                        from: 0
                        to: Math.max(root.duration, 1)
                        configuration: StyledSlider.Configuration.XS
                        stopIndicatorValues: []
                        dividerValues: root.chapters.map(c => c.time).filter(time => time > 0)
                        tooltipContent: root.formatTime(value)
                        onPressedChanged: if (!pressed) mpv.command(["seek", String(value), "absolute"])
                        Binding on value {
                            when: !seekBar.pressed
                            value: root.position
                        }
                    }
                    StyledText {
                        text: root.formatTime(root.duration)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.features: ({ "tnum": 1 })
                        color: Appearance.colors.colSubtext
                    }
                }

                RowLayout {
                    spacing: 2

                    PlayerButton {
                        symbol: "folder_open"
                        tip: Translation.tr("Open media") + " (Ctrl+O)"
                        onClicked: fileDialog.open()
                    }
                    Item { Layout.fillWidth: true }

                    PlayerButton {
                        symbol: "skip_previous"
                        tip: Translation.tr("Previous") + " (P)"
                        enabled: root.playlistPos > 0
                        opacity: enabled ? 1 : 0.4
                        onClicked: mpv.command(["playlist-prev"])
                    }
                    PlayerButton {
                        symbol: "replay_10"
                        tip: Translation.tr("Back 10 seconds")
                        onClicked: root.seekBy(-10)
                    }
                    PlayerButton {
                        symbol: root.paused ? "play_arrow" : "pause"
                        tip: root.paused ? Translation.tr("Play") : Translation.tr("Pause")
                        size: 48
                        glyph: 30
                        toggled: true
                        onClicked: root.togglePause()
                    }
                    PlayerButton {
                        symbol: "forward_10"
                        tip: Translation.tr("Forward 10 seconds")
                        onClicked: root.seekBy(10)
                    }
                    PlayerButton {
                        symbol: "skip_next"
                        tip: Translation.tr("Next") + " (N)"
                        enabled: root.playlistPos >= 0 && root.playlistPos < root.playlist.length - 1
                        opacity: enabled ? 1 : 0.4
                        onClicked: mpv.command(["playlist-next"])
                    }

                    Item { Layout.fillWidth: true }

                    PlayerButton {
                        symbol: root.muted || root.volume === 0 ? "volume_off" : root.volume < 50 ? "volume_down" : "volume_up"
                        tip: Translation.tr("Mute") + " (M)"
                        onClicked: mpv.setProperty("mute", !root.muted)
                    }
                    StyledSlider {
                        id: volumeSlider
                        Layout.fillWidth: false
                        Layout.preferredWidth: 96
                        configuration: StyledSlider.Configuration.XS
                        from: 0
                        to: 130
                        stopIndicatorValues: []
                        tooltipContent: Math.round(value) + "%"
                        onMoved: mpv.setProperty("volume", value)
                        Binding on value {
                            when: !volumeSlider.pressed
                            value: root.volume
                        }
                    }
                    PlayerButton {
                        symbol: "speed"
                        tip: Translation.tr("Speed")
                        toggled: root.openPanel === "speed"
                        onClicked: root.togglePanel("speed")
                    }
                    PlayerButton {
                        symbol: "subtitles"
                        tip: Translation.tr("Audio and subtitles")
                        toggled: root.openPanel === "tracks"
                        onClicked: root.togglePanel("tracks")
                    }
                    PlayerButton {
                        symbol: "queue_music"
                        tip: Translation.tr("Playlist")
                        toggled: root.openPanel === "playlist"
                        onClicked: root.togglePanel("playlist")
                    }
                    PlayerButton {
                        symbol: root.fullscreen ? "fullscreen_exit" : "fullscreen"
                        tip: Translation.tr("Fullscreen") + " (F)"
                        onClicked: root.toggleFullscreen()
                    }
                }
            }
        }

        // Side panels sit above the bar, against the right edge
        Panel {
            visible: root.openPanel !== ""
            anchors {
                right: bottomBar.right
                bottom: bottomBar.top
                bottomMargin: 8
            }
            width: root.openPanel === "speed" ? 200 : 340
            height: Math.min(panelFlick.contentHeight + 20, root.height - bottomBar.height - 60)

            StyledFlickable {
                id: panelFlick
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                contentHeight: panelColumn.implicitHeight

                ColumnLayout {
                    id: panelColumn
                    width: panelFlick.width
                    spacing: 2

                    // Playlist
                    Repeater {
                        model: root.openPanel === "playlist" ? root.playlist : []
                        delegate: ChoiceRow {
                            required property var modelData
                            required property int index
                            label: modelData.title ?? modelData.filename.replace(/^.*\//, "")
                            selected: index === root.playlistPos
                            onClicked: mpv.setProperty("playlist-pos", index)
                        }
                    }
                    StyledText {
                        visible: root.openPanel === "playlist" && root.playlist.length === 0
                        text: Translation.tr("The playlist is empty")
                        color: Appearance.colors.colSubtext
                    }

                    // Tracks
                    ContentSubsectionLabel {
                        visible: root.openPanel === "tracks"
                        text: Translation.tr("Audio")
                    }
                    Repeater {
                        model: root.openPanel === "tracks" ? root.audioTracks : []
                        delegate: ChoiceRow {
                            required property var modelData
                            label: root.trackLabel(modelData)
                            selected: modelData.selected ?? false
                            onClicked: mpv.setProperty("aid", modelData.id)
                        }
                    }
                    ContentSubsectionLabel {
                        visible: root.openPanel === "tracks"
                        text: Translation.tr("Subtitles")
                    }
                    ChoiceRow {
                        visible: root.openPanel === "tracks"
                        label: Translation.tr("Off")
                        selected: !root.subtitleTracks.some(t => t.selected)
                        onClicked: mpv.setProperty("sid", "no")
                    }
                    Repeater {
                        model: root.openPanel === "tracks" ? root.subtitleTracks : []
                        delegate: ChoiceRow {
                            required property var modelData
                            label: root.trackLabel(modelData)
                            selected: modelData.selected ?? false
                            onClicked: mpv.setProperty("sid", modelData.id)
                        }
                    }

                    // Speed
                    Repeater {
                        model: root.openPanel === "speed" ? [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2] : []
                        delegate: ChoiceRow {
                            required property var modelData
                            label: modelData + "×"
                            selected: Math.abs(root.speed - modelData) < 0.01
                            onClicked: root.setSpeed(modelData)
                        }
                    }
                }
            }
        }
    }

    // Messages
    Panel {
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: 56
        }
        visible: root.toast !== ""
        width: Math.min(toastText.implicitWidth + 32, parent.width - 40)
        height: toastText.implicitHeight + 20
        StyledText {
            id: toastText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, root.width - 72)
            wrapMode: Text.Wrap
            text: root.toast
            color: Appearance.colors.colOnLayer1
        }
    }
}
