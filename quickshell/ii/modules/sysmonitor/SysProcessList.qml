import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/** btop-style process table: search, sortable columns, selection + signal actions. */
SysCard {
    id: root

    title: "Processes"
    icon: "list_alt"
    subtitle: `${SysMonService.summary.total} total · ${SysMonService.summary.running} running · ${SysMonService.summary.threads} threads`
    accent: Appearance.m3colors.m3primary

    property int selectedPid: -1
    property string selectedName: ""
    property string selectedState: ""
    property bool confirmKill: false
    property alias searchField: search
    signal releaseFocus

    readonly property var columns: [
        { key: "pid", label: "PID", width: 64, align: Text.AlignRight },
        { key: "name", label: "Name", width: -1, align: Text.AlignLeft },
        { key: "user", label: "User", width: 92, align: Text.AlignLeft },
        { key: "threads", label: "Thr", width: 44, align: Text.AlignRight },
        { key: "cpu", label: "CPU%", width: 92, align: Text.AlignRight },
        { key: "mem", label: "Mem", width: 84, align: Text.AlignRight },
        { key: "time", label: "Time", width: 72, align: Text.AlignRight }
    ]

    function indexOfPid(pid) {
        const m = SysMonService.procModel;
        for (let i = 0; i < m.count; i++)
            if (m.get(i).pid === pid)
                return i;
        return -1;
    }
    function selectIndex(i) {
        const m = SysMonService.procModel;
        if (m.count === 0)
            return;
        i = Math.max(0, Math.min(m.count - 1, i));
        const row = m.get(i);
        root.selectedPid = row.pid;
        root.selectedName = row.name;
        root.selectedState = row.state;
        root.confirmKill = false;
        list.positionViewAtIndex(i, ListView.Contain);
    }
    function moveSelection(delta) {
        const cur = indexOfPid(root.selectedPid);
        selectIndex(cur < 0 ? 0 : cur + delta);
    }
    function pageSize() {
        return Math.max(1, Math.floor(list.height / 30) - 1);
    }
    function sendSignal(sig) {
        if (root.selectedPid > 0)
            SysMonService.signalProcess(root.selectedPid, sig);
    }
    function terminate() {
        sendSignal(15);
    }
    function kill() {
        if (root.selectedPid <= 0)
            return;
        if (!root.confirmKill) {
            root.confirmKill = true;
            confirmTimer.restart();
            return;
        }
        root.confirmKill = false;
        sendSignal(9);
    }
    function togglePause() {
        sendSignal(root.selectedState === "T" ? 18 : 19);
    }

    // keep selected row's state fresh after each refresh
    Connections {
        target: SysMonService.procModel
        function onDataChanged() {
            const i = root.indexOfPid(root.selectedPid);
            if (i >= 0)
                root.selectedState = SysMonService.procModel.get(i).state;
        }
    }

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.confirmKill = false
    }

    headerItems: [
        SysButton {
            icon: "speed"
            text: "Per-core"
            toggled: SysMonService.perCore
            onClicked: SysMonService.setPerCore(!SysMonService.perCore)
        }
    ]

    // ── search ──────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 38
        radius: height / 2
        color: Appearance.colors.colLayer2
        border.width: search.activeFocus ? 2 : 0
        border.color: Appearance.m3colors.m3primary

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 8
            spacing: 8
            MaterialSymbol {
                text: "search"
                iconSize: 20
                color: Appearance.colors.colSubtext
            }
            TextField {
                id: search
                Layout.fillWidth: true
                background: null
                padding: 0
                color: Appearance.colors.colOnLayer1
                placeholderText: "Filter by name, user, PID or command   ( / )"
                placeholderTextColor: Appearance.colors.colSubtext
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                selectByMouse: true
                onTextChanged: filterDebounce.restart()
                Keys.onUpPressed: root.moveSelection(-1)
                Keys.onDownPressed: root.moveSelection(1)
                Keys.onReturnPressed: root.releaseFocus()
                Keys.onEscapePressed: event => {
                    if (text.length > 0)
                        text = "";
                    else
                        root.releaseFocus();
                    event.accepted = true;
                }
            }
            SysButton {
                visible: search.text.length > 0
                icon: "close"
                implicitHeight: 26
                onClicked: search.text = ""
            }
        }

        Timer {
            id: filterDebounce
            interval: 180
            onTriggered: SysMonService.setFilter(search.text)
        }
    }

    // ── header row ──────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 10
        Layout.rightMargin: 14
        spacing: 8

        Repeater {
            model: root.columns
            delegate: Item {
                id: col
                required property var modelData
                readonly property bool active: SysMonService.sortKey === modelData.key
                Layout.fillWidth: modelData.width < 0
                Layout.preferredWidth: modelData.width < 0 ? 100 : modelData.width
                implicitHeight: 24

                RowLayout {
                    anchors.fill: parent
                    spacing: 2
                    layoutDirection: col.modelData.align === Text.AlignRight ? Qt.RightToLeft : Qt.LeftToRight
                    StyledText {
                        text: col.modelData.label
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: col.active ? Font.Bold : Font.Medium
                        color: col.active ? Appearance.m3colors.m3primary : Appearance.colors.colSubtext
                    }
                    MaterialSymbol {
                        visible: col.active
                        text: SysMonService.sortDesc ? "arrow_downward" : "arrow_upward"
                        iconSize: 14
                        color: Appearance.m3colors.m3primary
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SysMonService.setSort(col.modelData.key)
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Appearance.m3colors.m3outlineVariant
        opacity: 0.5
    }

    // ── rows ────────────────────────────────────────────────
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: SysMonService.procModel
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        keyNavigationEnabled: false
        cacheBuffer: 300
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: Rectangle {
            id: rowItem
            required property int index
            required property var model
            readonly property bool selected: model.pid === root.selectedPid
            readonly property bool paused: model.state === "T"
            readonly property bool zombie: model.state === "Z"

            width: ListView.view.width
            height: 30
            clip: true
            radius: Appearance.rounding.small
            color: selected ? Appearance.m3colors.m3secondaryContainer : rowMouse.containsMouse ? Appearance.colors.colLayer2 : "transparent"

            readonly property color textColor: selected ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
            readonly property color dimColor: selected ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colSubtext

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.selectIndex(rowItem.index)
                onDoubleClicked: root.terminate()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 14
                spacing: 8

                StyledText {
                    Layout.preferredWidth: 64
                    horizontalAlignment: Text.AlignRight
                    text: rowItem.model.pid
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: rowItem.dimColor
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 100
                    spacing: 8
                    MaterialSymbol {
                        visible: rowItem.paused || rowItem.zombie
                        text: rowItem.paused ? "pause_circle" : "skull"
                        iconSize: 15
                        color: rowItem.zombie ? Appearance.m3colors.m3error : Appearance.m3colors.m3tertiary
                    }
                    StyledText {
                        text: rowItem.model.name
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: rowItem.textColor
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: rowItem.model.cmd.replace(/\s+/g, " ")
                        textFormat: Text.PlainText
                        wrapMode: Text.NoWrap
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: rowItem.dimColor
                        opacity: 0.75
                    }
                }
                StyledText {
                    Layout.preferredWidth: 92
                    text: rowItem.model.user
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: rowItem.model.user === "root" ? Appearance.m3colors.m3tertiary : rowItem.dimColor
                }
                StyledText {
                    Layout.preferredWidth: 44
                    horizontalAlignment: Text.AlignRight
                    text: rowItem.model.threads
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: rowItem.dimColor
                }
                // CPU% with inline bar
                Item {
                    Layout.preferredWidth: 92
                    implicitHeight: 20
                    // bar = share of one core
                    readonly property real frac: Math.min(1, (SysMonService.perCore ? rowItem.model.cpu : rowItem.model.cpu * Math.max(1, SysMonService.cpuCount)) / 100)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 5
                        radius: 3
                        color: Appearance.m3colors.m3surfaceContainerHighest
                        Rectangle {
                            width: Math.max(rowItem.model.cpu > 0.05 ? 3 : 0, parent.width * parent.parent.frac)
                            height: parent.height
                            radius: 3
                            color: rowItem.model.cpu >= 50 ? Appearance.m3colors.m3error : Appearance.m3colors.m3primary
                        }
                    }
                    StyledText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: rowItem.model.cpu.toFixed(1)
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: rowItem.model.cpu >= 1 ? Font.DemiBold : Font.Normal
                        color: rowItem.model.cpu >= 50 ? Appearance.m3colors.m3error : rowItem.model.cpu >= 1 ? rowItem.textColor : rowItem.dimColor
                    }
                }
                StyledText {
                    Layout.preferredWidth: 84
                    horizontalAlignment: Text.AlignRight
                    text: SysMonService.formatBytes(rowItem.model.rss, 0)
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: rowItem.model.mem >= 10 ? Appearance.m3colors.m3tertiary : rowItem.textColor
                }
                StyledText {
                    Layout.preferredWidth: 72
                    horizontalAlignment: Text.AlignRight
                    text: SysMonService.formatTime(rowItem.model.time)
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: rowItem.dimColor
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: list.count === 0
            text: SysMonService.filter.length > 0 ? "No process matches “" + SysMonService.filter + "”" : "Loading…"
            color: Appearance.colors.colSubtext
        }
    }

    // ── action bar ──────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Appearance.m3colors.m3outlineVariant
        opacity: 0.5
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MaterialSymbol {
            text: root.selectedPid > 0 ? "radio_button_checked" : "radio_button_unchecked"
            iconSize: 18
            color: root.selectedPid > 0 ? Appearance.m3colors.m3primary : Appearance.colors.colSubtext
        }
        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root.selectedPid > 0 ? `${root.selectedName}  ·  PID ${root.selectedPid}` : "↑↓ select  ·  Del terminate  ·  Shift+Del kill  ·  Space pause"
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.selectedPid > 0 ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
        }
        SysButton {
            icon: root.selectedState === "T" ? "play_arrow" : "pause"
            text: root.selectedState === "T" ? "Resume" : "Pause"
            enabledState: root.selectedPid > 0
            onClicked: root.togglePause()
        }
        SysButton {
            icon: "stop_circle"
            text: "Terminate"
            tonal: true
            enabledState: root.selectedPid > 0
            onClicked: root.terminate()
        }
        SysButton {
            icon: "dangerous"
            text: root.confirmKill ? "Confirm kill?" : "Kill"
            danger: true
            enabledState: root.selectedPid > 0
            onClicked: root.kill()
        }
    }
    property alias listView: list
}
