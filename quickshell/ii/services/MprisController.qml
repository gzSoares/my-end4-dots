pragma Singleton
pragma ComponentBehavior: Bound

// From https://git.outfoxxed.me/outfoxxed/nixnew
// It does not have a license, but the author is okay with redistribution.

import QtQml.Models
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

/**
 * A service that provides easy access to the active Mpris player.
 */
Singleton {
    id: root;

    // Internal raw players list - updated via timer
    property list<MprisPlayer> _rawPlayers: []
    
    // Debounced filtered players - updated every 200ms
    property list<MprisPlayer> players: []
    
    // Tracked player (currently playing or last known)
    property MprisPlayer trackedPlayer: null;
    
    // Active player - computed from cached players (no binding re-eval)
    property MprisPlayer activePlayer: null;
    
    signal trackChanged(reverse: bool);

    // Most-recently-active bus names, newest first
    property var recentPlayerNames: [];
    
    // Last observed isPlaying per bus
    property var __wasPlaying: ({});
    
    // Cached plasma integration check (only changes when players list changes)
    property bool _hasActivePlasmaIntegration: false;

    function notePlaybackChange(player) {
        const name = player?.dbusName ?? '';
        if (!name) return;
        const was = root.__wasPlaying[name] === true;
        const now = player.isPlaying === true;
        root.__wasPlaying[name] = now;
        if (now && !was) root.bumpRecentPlayer(player);
    }
    
    function bumpRecentPlayer(player) {
        const name = player?.dbusName ?? '';
        if (!name || !isRealPlayer(player)) return;
        root.recentPlayerNames = [name, ...root.recentPlayerNames.filter(n => n !== name)].slice(0, 16);
    }
    
    function orderByRecency(list) {
        const rank = name => {
            const i = root.recentPlayerNames.indexOf(name);
            return i === -1 ? root.recentPlayerNames.length : i;
        };
        return [...list].sort((a, b) => rank(a.dbusName) - rank(b.dbusName));
    }

    property bool __reverse: false;
    property var activeTrack;

    function isFirefoxMprisBridge(name) {
        return /\.firefox\.instance\d+_t\d+/.test(name ?? '');
    }
    
    function isChromiumMprisBridge(name) {
        return /\.chromium\.instance\d+_t\d+/.test(name ?? '');
    }
    
    function isBuiltinFirefoxPlayer(name) {
        name = name ?? '';
        return name.startsWith('org.mpris.MediaPlayer2.firefox') && !isFirefoxMprisBridge(name);
    }
    
    function isBuiltinChromiumPlayer(name) {
        name = name ?? '';
        return (name.startsWith('org.mpris.MediaPlayer2.chromium')
            || name.startsWith('org.mpris.MediaPlayer2.chrome'))
            && !isChromiumMprisBridge(name);
    }
    
    function isBuiltinBrowserPlayer(name) {
        return isBuiltinFirefoxPlayer(name) || isBuiltinChromiumPlayer(name);
    }
    
    // Which built-ins a running bridge covers
    property var coveredBuiltins: []
    Process {
        id: coveredBuiltinsProc
        stdout: StdioCollector {
            onStreamFinished: root.coveredBuiltins = text.trim().length > 0 ? text.trim().split("\n") : []
        }
    }
    
    // Debounced: players arrive and leave in bursts, one resolve per burst is enough
    Timer {
        id: coveredBuiltinsRefresh
        interval: 150
        onTriggered: {
            const names = Mpris.players.values.map(p => p.dbusName ?? "").filter(n => n.length > 0);
            coveredBuiltinsProc.running = false;
            coveredBuiltinsProc.command = [Quickshell.shellPath("scripts/mpris/covered-builtins.sh"), ...names];
            coveredBuiltinsProc.running = true;
        }
    }
    
    function isRealPlayer(player) {
        if (!Config.options.media.filterDuplicatePlayers) {
            return true;
        }
        const name = player.dbusName ?? '';
        return (
            !(isBuiltinBrowserPlayer(name) && (_hasActivePlasmaIntegration || root.coveredBuiltins.indexOf(name) !== -1)) &&
            !name.startsWith('org.mpris.MediaPlayer2.playerctld') &&
            !(name.endsWith('.mpd') && !name.endsWith('MediaPlayer2.mpd')));
    }

    // Prefer Spotify when available
    function preferredPlayer() {
        // Always prefer Spotify if available
        for (const player of players) {
            if (player.dbusName?.includes("spotify")) return player;
        }
        // Fallback: currently playing player (trackedPlayer)
        if (trackedPlayer && trackedPlayer.isPlaying) return trackedPlayer;
        // Fallback: most recent player
        const recent = orderByRecency(players);
        if (recent.length > 0) return recent[0];
        return null;
    }
    
    // Debounced player list update - runs every 200ms instead of every binding eval
    Timer {
        id: playersUpdateTimer
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            const filtered = Mpris.players.values.filter(player => isRealPlayer(player));
            // Only update if actually changed (reference check)
            if (filtered.length !== _rawPlayers.length || 
                filtered.some((p, i) => p !== _rawPlayers[i])) {
                _rawPlayers = filtered;
                players = filtered;
                // Update cached plasma integration flag
                _hasActivePlasmaIntegration = filtered.some(
                    p => p.dbusName?.startsWith('org.mpris.MediaPlayer2.plasma-browser-integration')
                );
                // Update activePlayer from cached list
                activePlayer = preferredPlayer();
            }
        }
    }

    // Original stuff from fox below
    Instantiator {
        model: Mpris.players;

        Connections {
            required property MprisPlayer modelData;
            target: modelData;

            Component.onCompleted: {
                coveredBuiltinsRefresh.restart();
                root.notePlaybackChange(modelData);
                if (root.trackedPlayer == null || modelData.isPlaying) {
                    root.trackedPlayer = modelData;
                }
            }

            Component.onDestruction: {
                coveredBuiltinsRefresh.restart();
                if (root.trackedPlayer == null || !root.trackedPlayer.isPlaying) {
                    for (const player of Mpris.players.values) {
                        if (player.playbackState.isPlaying) {
                            root.trackedPlayer = player;
                            break;
                        }
                    }

                    if (trackedPlayer == null && Mpris.players.values.length != 0) {
                        trackedPlayer = Mpris.players.values[0];
                    }
                }
            }

            // Recency rides on the isPlaying PROPERTY change, not
            // playbackStateChanged: the state signal fires while isPlaying
            // still holds its old value, so a starting player reads as
            // not-playing there and never gets bumped.
            function onIsPlayingChanged() {
                root.notePlaybackChange(modelData);
            }

            function onPlaybackStateChanged() {
                if (root.trackedPlayer !== modelData) root.trackedPlayer = modelData;
            }
        }
    }

    // Use a single Connections with dynamic target instead of binding to activePlayer
    Connections {
        id: activePlayerConnections
        target: null
        
        function updateTarget() {
            activePlayerConnections.target = root.activePlayer;
        }
        
        Component.onCompleted: updateTarget()
        onActivePlayerChanged: updateTarget()
        
        function onPostTrackChanged() {
            root.updateTrack();
        }

        function onTrackArtUrlChanged() {
            if (root.activePlayer.uniqueId == root.activeTrack.uniqueId && root.activePlayer.trackArtUrl != root.activeTrack.artUrl) {
                const r = root.__reverse;
                root.updateTrack();
                root.__reverse = r;
            }
        }
    }

    function updateTrack() {
        this.activeTrack = {
            uniqueId: this.activePlayer?.uniqueId ?? 0,
            artUrl: this.activePlayer?.trackArtUrl ?? "",
            title: this.activePlayer?.trackTitle || Translation.tr("Unknown Title"),
            artist: this.activePlayer?.trackArtist || Translation.tr("Unknown Artist"),
            album: this.activePlayer?.trackAlbum || Translation.tr("Unknown Album"),
        };

        this.trackChanged(__reverse);
        this.__reverse = false;
    }

    property bool isPlaying: this.activePlayer && this.activePlayer.isPlaying;
    property bool canTogglePlaying: this.activePlayer?.canTogglePlaying ?? false;
    function togglePlaying() {
        if (this.canTogglePlaying) this.activePlayer.togglePlaying();
    }

    property bool canGoPrevious: this.activePlayer?.canGoPrevious ?? false;
    function previous() {
        if (this.canGoPrevious) {
            this.__reverse = true;
            this.activePlayer.previous();
        }
    }

    property bool canGoNext: this.activePlayer?.canGoNext ?? false;
    function next() {
        if (this.canGoNext) {
            this.__reverse = false;
            this.activePlayer.next();
        }
    }

    property bool canChangeVolume: this.activePlayer && this.activePlayer.volumeSupported && this.activePlayer.canControl;

    property bool loopSupported: this.activePlayer && this.activePlayer.loopSupported && this.activePlayer.canControl;
    property var loopState: this.activePlayer?.loopState ?? MprisLoopState.None;
    function setLoopState(loopState: var) {
        if (this.loopSupported) {
            this.activePlayer.loopState = loopState;
        }
    }

    property bool shuffleSupported: this.activePlayer && this.activePlayer.shuffleSupported && this.activePlayer.canControl;
    property bool hasShuffle: this.activePlayer?.shuffle ?? false;
    function setShuffle(shuffle: bool) {
        if (this.shuffleSupported) {
            this.activePlayer.shuffle = shuffle;
        }
    }

    function setActivePlayer(player: MprisPlayer) {
        const targetPlayer = player ?? Mpris.players[0];
        root.bumpRecentPlayer(targetPlayer);
        console.log(`[Mpris] Active player ${targetPlayer} << ${activePlayer}`)

        if (targetPlayer && this.activePlayer) {
            this.__reverse = Mpris.players.indexOf(targetPlayer) < Mpris.players.indexOf(this.activePlayer);
        } else {
            this.__reverse = false;
        }

        this.trackedPlayer = targetPlayer;
    }

    IpcHandler {
        target: "mpris"

        function pauseAll(): void {
            for (const player of Mpris.players.values) {
                if (player.canPause) player.pause();
            }
        }

        function playPause(): void { root.togglePlaying(); }
        function previous(): void { root.previous(); }
        function next(): void { root.next(); }
    }
}