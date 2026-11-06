pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Data service for the System Monitor window.
 * Runs scripts/sysmonitor/sysmon.py only while `active` is true.
 */
Singleton {
    id: root

    // ── control ────────────────────────────────────────────
    property bool active: false
    property int interval: 1000
    property string sortKey: "cpu"
    property bool sortDesc: true
    property string filter: ""
    property bool perCore: false
    readonly property int historyLength: 90

    // ── static info ────────────────────────────────────────
    property string hostname: ""
    property string kernel: ""
    property string cpuModel: ""
    property int cpuCount: 0

    // ── live data ──────────────────────────────────────────
    property real cpuTotal: 0
    property var cpuCores: []
    property real cpuFreq: 0
    property real cpuFreqMax: 0
    property real cpuTemp: -1
    property var loadAvg: [0, 0, 0]
    property real uptime: 0

    property var mem: ({ total: 0, used: 0, available: 0, cached: 0, free: 0, swapTotal: 0, swapUsed: 0 })
    readonly property real memFraction: mem.total > 0 ? mem.used / mem.total : 0
    readonly property real swapFraction: mem.swapTotal > 0 ? mem.swapUsed / mem.swapTotal : 0

    property var disks: []
    property real ioRead: 0
    property real ioWrite: 0

    property string netIface: ""
    property real netRx: 0
    property real netTx: 0
    property real netRxTotal: 0
    property real netTxTotal: 0

    property var battery: null
    property var gpu: null
    property var summary: ({ total: 0, running: 0, threads: 0 })

    // histories (arrays of numbers, oldest first)
    property var cpuHistory: []
    property var coreHistories: []
    property var memHistory: []
    property var swapHistory: []
    property var netRxHistory: []
    property var netTxHistory: []
    property var ioReadHistory: []
    property var ioWriteHistory: []

    property ListModel procModel: ListModel {}

    signal notice(string text, bool ok)

    // ── commands ───────────────────────────────────────────
    function send(line) {
        if (proc.running)
            proc.write(line + "\n");
    }
    function setSort(key) {
        if (root.sortKey === key)
            root.sortDesc = !root.sortDesc;
        else {
            root.sortKey = key;
            root.sortDesc = (key !== "name" && key !== "user" && key !== "pid");
        }
        send(`sort ${root.sortKey} ${root.sortDesc ? "desc" : "asc"}`);
    }
    function setFilter(text) {
        root.filter = text;
        send("filter " + text);
    }
    function setRefresh(ms) {
        root.interval = Math.max(250, Math.min(10000, ms));
        send("interval " + root.interval);
    }
    function setPerCore(on) {
        root.perCore = on;
        send("percore " + (on ? 1 : 0));
    }
    function signalProcess(pid, sig) {
        send(`kill ${pid} ${sig}`);
    }
    function sendState() {
        send("interval " + root.interval);
        send(`sort ${root.sortKey} ${root.sortDesc ? "desc" : "asc"}`);
        send("percore " + (root.perCore ? 1 : 0));
        if (root.filter.length > 0)
            send("filter " + root.filter);
    }

    // ── formatting helpers ─────────────────────────────────
    function formatBytes(b, digits) {
        const d = digits === undefined ? 1 : digits;
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        let v = Math.max(0, b || 0);
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return (i === 0 ? Math.round(v) : v.toFixed(v >= 100 ? 0 : d)) + " " + units[i];
    }
    function formatRate(b) {
        return formatBytes(b) + "/s";
    }
    function formatUptime(s) {
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0)
            return `${d}d ${h}h ${m}m`;
        if (h > 0)
            return `${h}h ${m}m`;
        return `${m}m`;
    }
    function formatTime(s) {
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = Math.floor(s % 60);
        const pad = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? `${h}:${pad(m)}:${pad(sec)}` : `${m}:${pad(sec)}`;
    }

    // ── internals ──────────────────────────────────────────
    function push(arr, v) {
        const a = arr.length >= root.historyLength ? arr.slice(arr.length - root.historyLength + 1) : arr.slice();
        a.push(v);
        return a;
    }

    function syncProcs(list) {
        const model = root.procModel;
        for (let i = 0; i < list.length; i++) {
            if (i < model.count)
                model.set(i, list[i]);
            else
                model.append(list[i]);
        }
        if (model.count > list.length)
            model.remove(list.length, model.count - list.length);
    }

    function resetHistories() {
        root.cpuHistory = [];
        root.coreHistories = [];
        root.memHistory = [];
        root.swapHistory = [];
        root.netRxHistory = [];
        root.netTxHistory = [];
        root.ioReadHistory = [];
        root.ioWriteHistory = [];
    }

    function handle(line) {
        let m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            return;
        }
        switch (m.type) {
        case "info":
            root.hostname = m.hostname;
            root.kernel = m.kernel;
            root.cpuModel = m.cpuModel;
            root.cpuCount = m.cpuCount;
            break;
        case "stats":
            {
                const c = m.cpu;
                root.cpuTotal = c.total;
                root.cpuCores = c.cores;
                root.cpuFreq = c.freq;
                root.cpuFreqMax = c.freqMax;
                root.cpuTemp = c.temp;
                root.loadAvg = c.load;
                root.cpuHistory = push(root.cpuHistory, c.total / 100);
                const ch = [];
                for (let i = 0; i < c.cores.length; i++)
                    ch.push(push(root.coreHistories[i] || [], c.cores[i] / 100));
                root.coreHistories = ch;

                root.mem = m.mem;
                root.memHistory = push(root.memHistory, root.memFraction);
                root.swapHistory = push(root.swapHistory, root.swapFraction);

                root.disks = m.disks;
                root.ioRead = m.io.read;
                root.ioWrite = m.io.write;
                root.ioReadHistory = push(root.ioReadHistory, m.io.read);
                root.ioWriteHistory = push(root.ioWriteHistory, m.io.write);

                root.netIface = m.net.iface;
                root.netRx = m.net.rx;
                root.netTx = m.net.tx;
                root.netRxTotal = m.net.rxTotal;
                root.netTxTotal = m.net.txTotal;
                root.netRxHistory = push(root.netRxHistory, m.net.rx);
                root.netTxHistory = push(root.netTxHistory, m.net.tx);

                root.battery = m.battery;
                root.gpu = m.gpu;
                root.uptime = m.uptime;
                root.summary = m.summary;
                syncProcs(m.procs);
                break;
            }
        case "procs":
            syncProcs(m.procs);
            break;
        case "msg":
            root.notice(m.text, m.ok);
            break;
        }
    }

    readonly property string scriptPath: decodeURIComponent(String(Qt.resolvedUrl("../scripts/sysmonitor/sysmon.py")).replace(/^file:\/\//, ""))

    Process {
        id: proc
        running: root.active
        stdinEnabled: true
        command: ["python3", "-u", root.scriptPath]
        onRunningChanged: {
            if (running) {
                root.resetHistories();
                root.sendState();
            }
        }
        stdout: SplitParser {
            onRead: data => root.handle(data)
        }
        stderr: SplitParser {
            onRead: data => console.warn("[SysMonService]", data)
        }
    }
}
