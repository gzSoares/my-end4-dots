import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * System Monitor — a btop-like resource monitor using the ii shell look.
 *   qs -c ii ipc call sysmonitor toggle
 */
Scope {
    id: root
    property bool shown: false

    IpcHandler {
        target: "sysmonitor"
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
            title: "System Monitor"
            implicitWidth: 1320
            implicitHeight: 900
            color: Appearance.m3colors.m3background
            visible: true

            onVisibleChanged: if (!visible)
                root.shown = false
            Component.onCompleted: SysMonService.active = true
            Component.onDestruction: SysMonService.active = false

            FocusScope {
                id: content
                anchors.fill: parent
                focus: true
                Component.onCompleted: forceActiveFocus()

                // ── keyboard ─────────────────────────────────────
                Keys.onPressed: event => {
                    const procs = processes;
                    const shift = event.modifiers & Qt.ShiftModifier;
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    let handled = true;
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.shown = false;
                        break;
                    case Qt.Key_Slash:
                        procs.searchField.forceActiveFocus();
                        break;
                    case Qt.Key_F:
                        if (ctrl)
                            procs.searchField.forceActiveFocus();
                        else
                            handled = false;
                        break;
                    case Qt.Key_Up:
                    case Qt.Key_K:
                        procs.moveSelection(-1);
                        break;
                    case Qt.Key_Down:
                    case Qt.Key_J:
                        procs.moveSelection(1);
                        break;
                    case Qt.Key_PageUp:
                        procs.moveSelection(-procs.pageSize());
                        break;
                    case Qt.Key_PageDown:
                        procs.moveSelection(procs.pageSize());
                        break;
                    case Qt.Key_Home:
                        procs.selectIndex(0);
                        break;
                    case Qt.Key_End:
                        procs.selectIndex(SysMonService.procModel.count - 1);
                        break;
                    case Qt.Key_Delete:
                        if (shift)
                            procs.kill();
                        else
                            procs.terminate();
                        break;
                    case Qt.Key_Space:
                        procs.togglePause();
                        break;
                    case Qt.Key_C:
                        SysMonService.setSort("cpu");
                        break;
                    case Qt.Key_M:
                        SysMonService.setSort("mem");
                        break;
                    case Qt.Key_P:
                        SysMonService.setSort("pid");
                        break;
                    case Qt.Key_N:
                        SysMonService.setSort("name");
                        break;
                    case Qt.Key_U:
                        SysMonService.setSort("user");
                        break;
                    case Qt.Key_T:
                        SysMonService.setSort("time");
                        break;
                    case Qt.Key_Plus:
                    case Qt.Key_Equal:
                        SysMonService.setRefresh(SysMonService.interval + 250);
                        break;
                    case Qt.Key_Minus:
                        SysMonService.setRefresh(SysMonService.interval - 250);
                        break;
                    default:
                        handled = false;
                    }
                    event.accepted = handled;
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    // ── header ──────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            implicitWidth: 42
                            implicitHeight: 42
                            radius: Appearance.rounding.normal
                            color: Appearance.m3colors.m3primaryContainer
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "monitor_heart"
                                iconSize: 24
                                color: Appearance.m3colors.m3onPrimaryContainer
                            }
                        }
                        ColumnLayout {
                            spacing: 0
                            StyledText {
                                text: "System Monitor"
                                font.pixelSize: Appearance.font.pixelSize.larger
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnLayer0
                            }
                            StyledText {
                                text: [SysMonService.hostname, SysMonService.kernel ? "Linux " + SysMonService.kernel : "", "up " + SysMonService.formatUptime(SysMonService.uptime)].filter(s => s.length > 0).join("  ·  ")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // battery chip
                        SysChip {
                            visible: SysMonService.battery !== null
                            icon: {
                                const b = SysMonService.battery;
                                if (!b)
                                    return "battery_unknown";
                                if (b.status === "Charging")
                                    return "battery_charging_full";
                                if (b.status === "Full" || b.status === "Not charging")
                                    return "battery_full";
                                const lvl = Math.min(6, Math.floor(b.percent / 100 * 7));
                                return b.percent <= 10 ? "battery_alert" : "battery_" + lvl + "_bar";
                            }
                            text: SysMonService.battery ? `${SysMonService.battery.percent}%` + (SysMonService.battery.watts > 0 ? `  ·  ${SysMonService.battery.watts} W` : "") : ""
                            accent: SysMonService.battery && SysMonService.battery.percent <= 15 && SysMonService.battery.status !== "Charging" ? Appearance.m3colors.m3error : Appearance.m3colors.m3tertiary
                        }

                        // gpu chip
                        SysChip {
                            visible: SysMonService.gpu !== null
                            icon: "developer_board"
                            text: {
                                const g = SysMonService.gpu;
                                if (!g)
                                    return "";
                                if (g.sleeping)
                                    return g.name + "  ·  sleeping";
                                if (!g.available)
                                    return g.name + "  ·  no nvidia-smi";
                                return `${g.name}  ·  ${g.util}%` + (g.temp >= 0 ? `  ·  ${g.temp}°C` : "") + (g.memTotal > 0 ? `  ·  ${SysMonService.formatBytes(g.memUsed, 0)}` : "");
                            }
                            accent: SysMonService.gpu && SysMonService.gpu.sleeping ? Appearance.colors.colSubtext : Appearance.m3colors.m3secondary
                        }

                        // refresh interval
                        Rectangle {
                            implicitHeight: 34
                            implicitWidth: intervalRow.implicitWidth + 8
                            radius: height / 2
                            color: Appearance.colors.colLayer1
                            RowLayout {
                                id: intervalRow
                                anchors.centerIn: parent
                                spacing: 2
                                SysButton {
                                    icon: "remove"
                                    implicitHeight: 26
                                    color: "transparent"
                                    onClicked: SysMonService.setRefresh(SysMonService.interval - 250)
                                }
                                MaterialSymbol {
                                    text: "update"
                                    iconSize: 16
                                    color: Appearance.colors.colSubtext
                                }
                                StyledText {
                                    text: (SysMonService.interval / 1000).toFixed(2).replace(/0$/, "") + " s"
                                    font.family: Appearance.font.family.monospace
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer1
                                    Layout.minimumWidth: 44
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                SysButton {
                                    icon: "add"
                                    implicitHeight: 26
                                    color: "transparent"
                                    onClicked: SysMonService.setRefresh(SysMonService.interval + 250)
                                }
                            }
                        }

                        SysButton {
                            icon: "close"
                            implicitHeight: 34
                            implicitWidth: 34
                            onClicked: root.shown = false
                        }
                    }

                    // ── CPU ─────────────────────────────────────
                    SysCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 236
                        title: "CPU"
                        icon: "memory"
                        subtitle: `${SysMonService.cpuModel}  ·  ${SysMonService.cpuCount} threads`
                        accent: Appearance.m3colors.m3primary

                        headerItems: [
                            SysChip {
                                icon: "bolt"
                                text: (SysMonService.cpuFreq / 1000).toFixed(2) + " GHz"
                                small: true
                            },
                            SysChip {
                                visible: SysMonService.cpuTemp >= 0
                                icon: "thermostat"
                                text: Math.round(SysMonService.cpuTemp) + "°C"
                                small: true
                                accent: SysMonService.cpuTemp >= 85 ? Appearance.m3colors.m3error : SysMonService.cpuTemp >= 70 ? Appearance.m3colors.m3tertiary : Appearance.m3colors.m3primary
                            },
                            SysChip {
                                icon: "monitoring"
                                text: "Load " + SysMonService.loadAvg.map(v => v.toFixed(2)).join("  ")
                                small: true
                            }
                        ]

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 16

                            // total graph
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumWidth: 320
                                radius: Appearance.rounding.normal
                                color: Appearance.colors.colLayer2
                                clip: true

                                SysGraph {
                                    anchors.fill: parent
                                    anchors.topMargin: 8
                                    values: SysMonService.cpuHistory
                                    capacity: SysMonService.historyLength
                                    lineColor: SysMonService.cpuTotal >= 85 ? Appearance.m3colors.m3error : Appearance.m3colors.m3primary
                                }
                                ColumnLayout {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: 14
                                    spacing: -4
                                    StyledText {
                                        text: Math.round(SysMonService.cpuTotal) + "%"
                                        font.pixelSize: 40
                                        font.weight: Font.Bold
                                        color: Appearance.colors.colOnLayer1
                                    }
                                    StyledText {
                                        text: "total usage"
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                    }
                                }
                            }

                            // per-core
                            GridLayout {
                                id: coreGrid
                                Layout.fillWidth: false
                                Layout.preferredWidth: SysMonService.cpuCores.length > 8 ? 620 : 470
                                Layout.maximumWidth: Layout.preferredWidth
                                Layout.fillHeight: true
                                columns: SysMonService.cpuCores.length > 16 ? 4 : SysMonService.cpuCores.length > 8 ? 3 : 2
                                columnSpacing: 14
                                rowSpacing: 4

                                Repeater {
                                    model: SysMonService.cpuCores.length
                                    delegate: RowLayout {
                                        id: core
                                        required property int index
                                        readonly property real usage: SysMonService.cpuCores[index] || 0
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 8
                                        StyledText {
                                            text: "C" + core.index
                                            font.family: Appearance.font.family.monospace
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                            Layout.preferredWidth: 26
                                        }
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Layout.maximumHeight: 30
                                            Layout.minimumHeight: 14
                                            radius: Appearance.rounding.small
                                            color: Appearance.colors.colLayer2
                                            clip: true
                                            SysGraph {
                                                anchors.fill: parent
                                                values: SysMonService.coreHistories[core.index] || []
                                                capacity: 40
                                                showGrid: false
                                                fillOpacity: 0.45
                                                lineColor: core.usage >= 85 ? Appearance.m3colors.m3error : Appearance.m3colors.m3primary
                                            }
                                        }
                                        StyledText {
                                            text: Math.round(core.usage) + "%"
                                            font.family: Appearance.font.family.monospace
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            horizontalAlignment: Text.AlignRight
                                            Layout.preferredWidth: 36
                                            color: core.usage >= 85 ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── bottom: resources + processes ───────────
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        ColumnLayout {
                            id: leftColumn
                            // grows a bit on big / maximized windows
                            readonly property int columnWidth: Math.round(Math.max(430, Math.min(600, content.width * 0.24)))
                            readonly property bool roomy: content.height >= 1050
                            Layout.preferredWidth: columnWidth
                            Layout.maximumWidth: columnWidth
                            Layout.fillHeight: true
                            spacing: 12

                            // memory
                            SysCard {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.verticalStretchFactor: 2
                                Layout.preferredHeight: 178
                                Layout.minimumHeight: 178
                                Layout.maximumHeight: 340
                                title: "Memory"
                                icon: "memory_alt"
                                subtitle: SysMonService.formatBytes(SysMonService.mem.total) + " total"
                                accent: Appearance.m3colors.m3tertiary

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: 36
                                    radius: Appearance.rounding.small
                                    color: Appearance.colors.colLayer2
                                    clip: true
                                    SysGraph {
                                        anchors.fill: parent
                                        values: SysMonService.memHistory
                                        capacity: SysMonService.historyLength
                                        lineColor: Appearance.m3colors.m3tertiary
                                    }
                                }
                                SysMeter {
                                    Layout.fillWidth: true
                                    label: "RAM"
                                    detailText: SysMonService.formatBytes(SysMonService.mem.used) + " / " + SysMonService.formatBytes(SysMonService.mem.total) + "  ·  cache " + SysMonService.formatBytes(SysMonService.mem.cached)
                                    valueText: Math.round(SysMonService.memFraction * 100) + "%"
                                    fraction: SysMonService.memFraction
                                    barColor: Appearance.m3colors.m3tertiary
                                }
                                SysMeter {
                                    Layout.fillWidth: true
                                    visible: SysMonService.mem.swapTotal > 0
                                    label: "Swap"
                                    detailText: SysMonService.formatBytes(SysMonService.mem.swapUsed) + " / " + SysMonService.formatBytes(SysMonService.mem.swapTotal)
                                    valueText: Math.round(SysMonService.swapFraction * 100) + "%"
                                    fraction: SysMonService.swapFraction
                                    barColor: Appearance.m3colors.m3secondary
                                    barHeight: 6
                                }
                            }

                            // network
                            SysCard {
                                id: netCard
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.verticalStretchFactor: 3
                                Layout.preferredHeight: 200
                                Layout.minimumHeight: 150
                                Layout.maximumHeight: 380
                                title: "Network"
                                icon: "lan"
                                subtitle: SysMonService.netIface || "offline"
                                accent: Appearance.m3colors.m3primary

                                readonly property real sharedMax: {
                                    let m = 64 * 1024;
                                    const a = SysMonService.netRxHistory, b = SysMonService.netTxHistory;
                                    for (let i = 0; i < a.length; i++)
                                        m = Math.max(m, a[i]);
                                    for (let i = 0; i < b.length; i++)
                                        m = Math.max(m, b[i]);
                                    return m * 1.15;
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Appearance.rounding.small
                                    color: Appearance.colors.colLayer2
                                    clip: true

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        SysGraph {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            values: SysMonService.netRxHistory
                                            capacity: SysMonService.historyLength
                                            scaleOverride: netCard.sharedMax
                                            lineColor: Appearance.m3colors.m3primary
                                            showGrid: false
                                        }
                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 1
                                            color: Appearance.m3colors.m3outlineVariant
                                            opacity: 0.6
                                        }
                                        SysGraph {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            values: SysMonService.netTxHistory
                                            capacity: SysMonService.historyLength
                                            scaleOverride: netCard.sharedMax
                                            inverted: true
                                            lineColor: Appearance.m3colors.m3tertiary
                                            showGrid: false
                                        }
                                    }
                                    StyledText {
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 6
                                        text: "peak " + SysMonService.formatRate(netCard.sharedMax / 1.15)
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: Appearance.colors.colSubtext
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    SysRate {
                                        Layout.fillWidth: true
                                        icon: "south"
                                        label: "Download"
                                        value: SysMonService.formatRate(SysMonService.netRx)
                                        total: SysMonService.formatBytes(SysMonService.netRxTotal) + " total"
                                        accent: Appearance.m3colors.m3primary
                                    }
                                    SysRate {
                                        Layout.fillWidth: true
                                        icon: "north"
                                        label: "Upload"
                                        value: SysMonService.formatRate(SysMonService.netTx)
                                        total: SysMonService.formatBytes(SysMonService.netTxTotal) + " total"
                                        accent: Appearance.m3colors.m3tertiary
                                    }
                                }
                            }

                            // sensors & power — only when there is vertical room
                            SysCard {
                                visible: leftColumn.roomy && (SysMonService.cpuTemp >= 0 || SysMonService.gpu !== null || SysMonService.battery !== null)
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.verticalStretchFactor: 3
                                Layout.preferredHeight: 200
                                Layout.minimumHeight: 160
                                title: "Sensors & Power"
                                icon: "sensors"
                                accent: Appearance.m3colors.m3tertiary

                                SysMeter {
                                    Layout.fillWidth: true
                                    visible: SysMonService.cpuTemp >= 0
                                    label: "CPU temperature"
                                    valueText: Math.round(SysMonService.cpuTemp) + "°C"
                                    fraction: SysMonService.cpuTemp / 100
                                    warnAt: 0.85
                                }
                                SysMeter {
                                    Layout.fillWidth: true
                                    readonly property var g: SysMonService.gpu
                                    visible: g !== null && !g.sleeping && g.available
                                    label: (g ? g.name : "GPU") + " usage"
                                    detailText: g && g.temp >= 0 ? g.temp + "°C" : ""
                                    valueText: (g ? g.util : 0) + "%"
                                    fraction: g ? g.util / 100 : 0
                                    barColor: Appearance.m3colors.m3secondary
                                }
                                SysMeter {
                                    Layout.fillWidth: true
                                    readonly property var g: SysMonService.gpu
                                    visible: g !== null && !g.sleeping && g.memTotal > 0
                                    label: "Video memory"
                                    detailText: g ? SysMonService.formatBytes(g.memUsed) + " / " + SysMonService.formatBytes(g.memTotal) : ""
                                    valueText: g && g.memTotal > 0 ? Math.round(g.memUsed / g.memTotal * 100) + "%" : ""
                                    fraction: g && g.memTotal > 0 ? g.memUsed / g.memTotal : 0
                                    barColor: Appearance.m3colors.m3secondary
                                    barHeight: 6
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: SysMonService.gpu !== null && SysMonService.gpu.sleeping
                                    spacing: 8
                                    MaterialSymbol {
                                        text: "bedtime"
                                        iconSize: 18
                                        color: Appearance.colors.colSubtext
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: (SysMonService.gpu ? SysMonService.gpu.name : "GPU") + " is sleeping (not polled, to save power)"
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                        elide: Text.ElideRight
                                    }
                                }
                                SysMeter {
                                    Layout.fillWidth: true
                                    readonly property var b: SysMonService.battery
                                    visible: b !== null
                                    label: "Battery"
                                    detailText: b ? b.status + (b.watts > 0 ? "  ·  " + b.watts + " W" : "") : ""
                                    valueText: (b ? b.percent : 0) + "%"
                                    fraction: b ? b.percent / 100 : 0
                                    barColor: b && b.percent <= 15 && b.status !== "Charging" ? Appearance.m3colors.m3error : Appearance.m3colors.m3tertiary
                                    warn: false
                                }
                                Item {
                                    Layout.fillHeight: true
                                }
                            }

                            // disks
                            SysCard {
                                Layout.fillWidth: true
                                Layout.preferredHeight: implicitHeight
                                implicitHeight: 72 + SysMonService.disks.length * 40
                                title: "Disks"
                                icon: "hard_drive"
                                accent: Appearance.m3colors.m3secondary

                                headerItems: [
                                    SysChip {
                                        icon: "download"
                                        text: SysMonService.formatRate(SysMonService.ioRead)
                                        small: true
                                    },
                                    SysChip {
                                        icon: "upload"
                                        text: SysMonService.formatRate(SysMonService.ioWrite)
                                        small: true
                                        accent: Appearance.m3colors.m3tertiary
                                    }
                                ]

                                Repeater {
                                    model: SysMonService.disks
                                    delegate: SysMeter {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        label: modelData.mount
                                        detailText: `${modelData.fs}  ·  ${SysMonService.formatBytes(modelData.used)} / ${SysMonService.formatBytes(modelData.total)}`
                                        valueText: Math.round(modelData.used / modelData.total * 100) + "%"
                                        fraction: modelData.used / modelData.total
                                        barColor: Appearance.m3colors.m3secondary
                                        warnAt: 0.9
                                    }
                                }
                                Item {
                                    Layout.fillHeight: true
                                }
                            }
                        }

                        SysProcessList {
                            id: processes
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            onReleaseFocus: content.forceActiveFocus()
                        }
                    }
                }

                // ── toast ───────────────────────────────────────
                Rectangle {
                    id: toast
                    property string text: ""
                    property bool ok: true
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: shown ? 28 : -height
                    property bool shown: false
                    implicitHeight: 42
                    implicitWidth: toastRow.implicitWidth + 32
                    radius: height / 2
                    color: ok ? Appearance.m3colors.m3inverseSurface : Appearance.m3colors.m3errorContainer
                    opacity: shown ? 1 : 0
                    Behavior on anchors.bottomMargin {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 180
                        }
                    }
                    RowLayout {
                        id: toastRow
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialSymbol {
                            text: toast.ok ? "check_circle" : "error"
                            iconSize: 18
                            color: toast.ok ? Appearance.m3colors.m3inverseOnSurface : Appearance.m3colors.m3onErrorContainer
                        }
                        StyledText {
                            text: toast.text
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: toast.ok ? Appearance.m3colors.m3inverseOnSurface : Appearance.m3colors.m3onErrorContainer
                        }
                    }
                    Timer {
                        id: toastTimer
                        interval: 2600
                        onTriggered: toast.shown = false
                    }
                    Connections {
                        target: SysMonService
                        function onNotice(text, ok) {
                            toast.text = text;
                            toast.ok = ok;
                            toast.shown = true;
                            toastTimer.restart();
                        }
                    }
                }
            }
        }
    }
}
