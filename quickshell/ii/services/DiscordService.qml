pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

/**
 * The voice side of the Discord desktop app, for the Chat tab.
 *
 * scripts/discord/discord_rpc.py talks to the running Discord client over its
 * local IPC socket as an app of the user's own, and prints the whole state as
 * a JSON line whenever something changes; commands go back on its stdin. The
 * account token is never involved, and no chat message is read or sent.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.options.sidebar.discord?.enable ?? false
    readonly property string clientId: String(Config.options.sidebar.discord?.clientId ?? "").trim()
    readonly property string clientSecret: String(Config.options.sidebar.discord?.clientSecret ?? "").trim()
    readonly property bool configured: root.clientId !== "" && root.clientSecret !== ""

    // State, as the helper reports it
    property bool connected: false
    property bool authorized: false
    property string status: "starting"
    property string error: ""
    property var user: null
    property var guilds: []
    property string guildId: ""
    property var channels: []
    property var voice: null          // null when not in a call
    property var settings: ({ mute: false, deaf: false, input: 100, output: 100,
                              inputDevice: "", outputDevice: "", inputDevices: [], outputDevices: [] })

    readonly property bool inCall: root.voice !== null

    function send(msg) {
        if (proc.running)
            proc.write(JSON.stringify(msg) + "\n");
    }

    function selectGuild(id) { root.send({ cmd: "selectGuild", id: id }); }
    function join(id) { root.send({ cmd: "join", id: id }); }
    function leave() { root.send({ cmd: "leave" }); }
    function setMute(value) { root.send({ cmd: "setMute", value: value }); }
    function setDeaf(value) { root.send({ cmd: "setDeaf", value: value }); }
    function setVolume(which, value) { root.send({ cmd: "setVolume", which: which, value: value }); }
    function setDevice(which, id) { root.send({ cmd: "setDevice", which: which, id: id }); }
    function setUserVolume(id, value) { root.send({ cmd: "setUserVolume", id: id, value: value }); }
    function muteUser(id, value) { root.send({ cmd: "muteUser", id: id, value: value }); }
    function refresh() { root.send({ cmd: "refresh" }); }

    // Starts the Discord app when it is not running: the Flatpak if that is the one
    // installed, else the regular one, minimized so it only has to be up.
    function openApp() {
        Quickshell.execDetached(["bash", "-c",
            "if command -v flatpak >/dev/null 2>&1 && flatpak info com.discordapp.Discord >/dev/null 2>&1; then " +
            "exec flatpak run com.discordapp.Discord --start-minimized; " +
            "elif command -v discord >/dev/null 2>&1; then exec discord --start-minimized; " +
            "elif command -v Discord >/dev/null 2>&1; then exec Discord --start-minimized; " +
            "else exit 1; fi"]);
    }

    function _apply(s) {
        root.connected = s.connected;
        root.authorized = s.authorized;
        root.status = s.status;
        root.error = s.error;
        root.user = s.user;
        root.guilds = s.guilds;
        root.guildId = s.guildId;
        root.channels = s.channels;
        root.voice = s.voice;
        root.settings = s.settings;
    }

    // Runs only while the tab is on and set up, so nothing is started for
    // someone who never uses it. The helper keeps trying until Discord is up.
    Process {
        id: proc
        running: root.enabled && root.configured
        stdinEnabled: true
        command: [
            "python3",
            `${FileUtils.trimFileProtocol(Directories.scriptPath)}/discord/discord_rpc.py`,
            "--client-id", root.clientId,
            "--client-secret", root.clientSecret,
            "--token-file", `${FileUtils.trimFileProtocol(Directories.state)}/user/discord_rpc.json`
        ]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const s = JSON.parse(line);
                    if (s.type === "state")
                        root._apply(s);
                } catch (e) {}
            }
        }
        onRunningChanged: if (!running) {
            root.connected = false;
            root.authorized = false;
            root.voice = null;
            root.status = root.configured ? "stopped" : "needs setup";
        }
    }
}
