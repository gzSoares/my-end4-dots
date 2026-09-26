// services/SpotlightController.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool spotlightOpen: false

    function run(cmd) {
        _runner.command = ["bash", "-c", cmd];
        _runner.running = true;
    }

    function requestAction(name) {
        if (name === "restart") run("systemctl reboot");
        else if (name === "shutdown") run("systemctl poweroff");
        else if (name === "logout") run("hyprctl dispatch exit");
        else if (name === "lock") run("hyprlock");
    }

    Process {
        id: _runner
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    IpcHandler {
        target: "spotlight"
        function toggle() { root.spotlightOpen = !root.spotlightOpen; }
        function open() { root.spotlightOpen = true; }
        function close() { root.spotlightOpen = false; }
    }
}
