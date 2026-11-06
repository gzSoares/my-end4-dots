import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sysmonitor

/**
 * Agenda — month calendar, day events and tasks (Evolution Data Server).
 *   qs -c ii ipc call agenda toggle
 */
Scope {
    id: root
    property bool shown: false
    property var pendingDate: null   // set by openDate(), applied when the window is ready

    IpcHandler {
        target: "agenda"
        function toggle(): void {
            root.shown = !root.shown;
        }
        function open(): void {
            root.shown = true;
        }
        function close(): void {
            root.shown = false;
        }
        // qs -c ii ipc call agenda openDate 2026-11-06
        function openDate(date: string): void {
            const p = date.split("-");
            const d = new Date(+p[0], +p[1] - 1, +p[2]);
            if (isNaN(d.getTime()))
                return;
            root.pendingDate = d;
            root.shown = true;
        }
    }

    LazyLoader {
        active: root.shown

        component: FloatingWindow {
            id: win
            title: "Agenda"
            implicitWidth: 1380
            implicitHeight: 860
            color: Appearance.m3colors.m3background
            visible: true
            onVisibleChanged: if (!visible)
                root.shown = false

            // ── state ───────────────────────────────────────────
            property int viewYear: new Date().getFullYear()
            property int viewMonth: new Date().getMonth()
            property date selected: new Date()
            property var calendars: []
            property var taskLists: []
            property var events: []
            property var tasks: []
            property var eventsByDay: ({})
            property var tasksByDay: ({})
            property bool showDone: false
            property bool loading: true

            readonly property var dayEvents: eventsByDay[dayKey(selected)] || []

            function applyPendingDate() {
                if (root.pendingDate) {
                    win.selectDay(root.pendingDate);
                    root.pendingDate = null;
                }
            }
            Component.onCompleted: applyPendingDate()
            Connections {
                target: root
                function onPendingDateChanged() {
                    win.applyPendingDate();
                }
            }

            function pad(n) {
                return (n < 10 ? "0" : "") + n;
            }
            function dayKey(d) {
                return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
            }
            function startOfDay(d) {
                return new Date(d.getFullYear(), d.getMonth(), d.getDate());
            }
            function send(obj) {
                if (backend.running)
                    backend.write(JSON.stringify(obj) + "\n");
            }
            function requestRange() {
                const first = new Date(viewYear, viewMonth, 1);
                const offset = (first.getDay() - Qt.locale().firstDayOfWeek + 7) % 7;
                const start = new Date(viewYear, viewMonth, 1 - offset);
                const end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 42);
                send({
                    cmd: "range",
                    start: Math.floor(start.getTime() / 1000),
                    end: Math.floor(end.getTime() / 1000)
                });
            }
            function refreshAll() {
                requestRange();
                send({
                    cmd: "tasks"
                });
            }
            function goMonth(delta) {
                const d = new Date(viewYear, viewMonth + delta, 1);
                viewYear = d.getFullYear();
                viewMonth = d.getMonth();
                requestRange();
            }
            function goToday() {
                const t = new Date();
                selected = t;
                if (t.getFullYear() !== viewYear || t.getMonth() !== viewMonth) {
                    viewYear = t.getFullYear();
                    viewMonth = t.getMonth();
                    requestRange();
                }
            }
            function selectDay(d) {
                selected = d;
                if (d.getMonth() !== viewMonth || d.getFullYear() !== viewYear) {
                    viewYear = d.getFullYear();
                    viewMonth = d.getMonth();
                    requestRange();
                }
            }

            function indexEvents(list) {
                const map = {};
                for (const ev of list) {
                    let d = startOfDay(new Date(ev.start * 1000));
                    const endMs = ev.end * 1000 - 1;
                    let guard = 0;
                    while (d.getTime() <= endMs && guard++ < 62) {
                        const k = dayKey(d);
                        (map[k] = map[k] || []).push(ev);
                        d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1);
                    }
                }
                for (const k in map)
                    map[k].sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start));
                eventsByDay = map;
            }
            function indexTasks(list) {
                const map = {};
                for (const t of list) {
                    if (t.due < 0 || t.done)
                        continue;
                    const k = dayKey(new Date(t.due * 1000));
                    (map[k] = map[k] || []).push(t);
                }
                tasksByDay = map;
            }

            function handle(line) {
                let m;
                try {
                    m = JSON.parse(line);
                } catch (e) {
                    return;
                }
                switch (m.type) {
                case "sources":
                    calendars = m.calendars;
                    taskLists = m.taskLists;
                    refreshAll();
                    break;
                case "events":
                    events = m.events;
                    indexEvents(m.events);
                    loading = false;
                    break;
                case "tasks":
                    tasks = m.tasks;
                    indexTasks(m.tasks);
                    break;
                case "changed":
                    requestRange();
                    break;
                case "msg":
                    toast.show(m.text, m.ok);
                    break;
                }
            }

            // task grouping
            readonly property var taskGroups: {
                const today = startOfDay(new Date()).getTime() / 1000;
                const tomorrow = today + 86400;
                const g = {
                    overdue: [],
                    today: [],
                    upcoming: [],
                    someday: [],
                    done: []
                };
                for (const t of tasks) {
                    if (t.done)
                        g.done.push(t);
                    else if (t.due < 0)
                        g.someday.push(t);
                    else if (t.due < today)
                        g.overdue.push(t);
                    else if (t.due < tomorrow)
                        g.today.push(t);
                    else
                        g.upcoming.push(t);
                }
                const out = [];
                const add = (key, label, items) => {
                    if (items.length) {
                        out.push({
                            header: true,
                            key: key,
                            label: label,
                            count: items.length
                        });
                        for (const t of items)
                            out.push({
                                header: false,
                                key: key,
                                task: t
                            });
                    }
                };
                add("overdue", "Overdue", g.overdue);
                add("today", "Today", g.today);
                add("upcoming", "Upcoming", g.upcoming);
                add("someday", "No date", g.someday);
                if (showDone)
                    add("done", "Completed", g.done);
                else if (g.done.length)
                    out.push({
                        header: true,
                        key: "done",
                        label: "Completed",
                        count: g.done.length,
                        collapsed: true
                    });
                return out;
            }

            Process {
                id: backend
                running: true
                stdinEnabled: true
                command: ["python3", "-u", decodeURIComponent(String(Qt.resolvedUrl("../../scripts/agenda/agenda.py")).replace(/^file:\/\//, ""))]
                stdout: SplitParser {
                    onRead: data => win.handle(data)
                }
                stderr: SplitParser {
                    onRead: data => console.warn("[Agenda]", data)
                }
                onExited: (code, status) => {
                    if (code !== 0)
                        toast.show("Agenda backend stopped — is python-gobject / evolution-data-server installed?", false);
                }
            }
            Timer {
                interval: 60000
                repeat: true
                running: true
                onTriggered: win.refreshAll()
            }

            FocusScope {
                id: content
                anchors.fill: parent
                focus: true
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: e => {
                    if (editor.visible) {
                        if (e.key === Qt.Key_Escape) {
                            editor.close();
                            e.accepted = true;
                        }
                        return;
                    }
                    let handled = true;
                    switch (e.key) {
                    case Qt.Key_Escape:
                        if (quickTask.field.activeFocus)
                            content.forceActiveFocus();
                        else
                            root.shown = false;
                        break;
                    case Qt.Key_Left:
                        win.selectDay(new Date(win.selected.getFullYear(), win.selected.getMonth(), win.selected.getDate() - 1));
                        break;
                    case Qt.Key_Right:
                        win.selectDay(new Date(win.selected.getFullYear(), win.selected.getMonth(), win.selected.getDate() + 1));
                        break;
                    case Qt.Key_Up:
                        win.selectDay(new Date(win.selected.getFullYear(), win.selected.getMonth(), win.selected.getDate() - 7));
                        break;
                    case Qt.Key_Down:
                        win.selectDay(new Date(win.selected.getFullYear(), win.selected.getMonth(), win.selected.getDate() + 7));
                        break;
                    case Qt.Key_PageUp:
                        win.goMonth(-1);
                        break;
                    case Qt.Key_PageDown:
                        win.goMonth(1);
                        break;
                    case Qt.Key_T:
                        win.goToday();
                        break;
                    case Qt.Key_N:
                        editor.openEvent(null, win.selected);
                        break;
                    case Qt.Key_A:
                        quickTask.field.forceActiveFocus();
                        break;
                    default:
                        handled = false;
                    }
                    e.accepted = handled;
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    SysAppHeader {
                        icon: "calendar_month"
                        title: "Agenda"
                        subtitle: Qt.locale("en_US").toString(new Date(), "dddd, MMMM d") + "  ·  " + win.calendars.length + " calendars  ·  " + win.tasks.filter(t => !t.done).length + " open tasks"
                        onCloseRequested: root.shown = false

                        SysButton {
                            icon: "today"
                            text: "Today"
                            onClicked: win.goToday()
                        }
                        SysButton {
                            icon: "add_task"
                            text: "Task"
                            onClicked: editor.openTask(null, null)
                        }
                        SysButton {
                            icon: "add"
                            text: "Event"
                            tonal: true
                            onClicked: editor.openEvent(null, win.selected)
                        }
                        SysButton {
                            icon: "open_in_new"
                            onClicked: Quickshell.execDetached(["gnome-calendar"])
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        // ── month ───────────────────────────────
                        SysCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            title: Qt.locale("en_US").monthName(win.viewMonth, Locale.LongFormat) + " " + win.viewYear
                            subtitle: win.loading ? "Loading…" : win.events.length + " events this view"
                            icon: "calendar_view_month"
                            headerItems: [
                                SysButton {
                                    icon: "chevron_left"
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    onClicked: win.goMonth(-1)
                                },
                                SysButton {
                                    icon: "chevron_right"
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    onClicked: win.goMonth(1)
                                }
                            ]

                            AgendaMonth {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                year: win.viewYear
                                monthIndex: win.viewMonth
                                selected: win.selected
                                eventsByDay: win.eventsByDay
                                tasksByDay: win.tasksByDay
                                onDaySelected: d => win.selectDay(d)
                                onDayDoubleClicked: d => {
                                    win.selectDay(d);
                                    editor.openEvent(null, d);
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.preferredWidth: 430
                            Layout.maximumWidth: 430
                            Layout.fillHeight: true
                            spacing: 12

                            // ── selected day ────────────────────
                            SysCard {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.verticalStretchFactor: 1
                                title: win.dayKey(win.selected) === win.dayKey(new Date()) ? "Today" : Qt.locale("en_US").toString(win.selected, "dddd")
                                subtitle: Qt.locale("en_US").toString(win.selected, "MMMM d, yyyy") + "  ·  " + win.dayEvents.length + (win.dayEvents.length === 1 ? " event" : " events")
                                icon: "event"
                                headerItems: [
                                    SysButton {
                                        icon: "add"
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        onClicked: editor.openEvent(null, win.selected)
                                    }
                                ]

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 8
                                    model: win.dayEvents
                                    ScrollBar.vertical: ScrollBar {}
                                    delegate: Rectangle {
                                        id: evRow
                                        required property var modelData
                                        readonly property color evColor: modelData.color ? modelData.color : Appearance.m3colors.m3primary
                                        readonly property bool past: modelData.end * 1000 < Date.now()
                                        width: ListView.view.width
                                        implicitHeight: evCol.implicitHeight + 20
                                        radius: Appearance.rounding.normal
                                        color: evMouse.containsMouse ? Qt.lighter(Appearance.colors.colLayer2, 1.08) : Appearance.colors.colLayer2
                                        opacity: past ? 0.6 : 1

                                        MouseArea {
                                            id: evMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (evRow.modelData.readonly)
                                                    toast.show("“" + evRow.modelData.sourceName + "” is read-only", false);
                                                else
                                                    editor.openEvent(evRow.modelData, win.selected);
                                            }
                                        }
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 8
                                            width: 4
                                            radius: 2
                                            color: evRow.evColor
                                        }
                                        ColumnLayout {
                                            id: evCol
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 22
                                            anchors.rightMargin: 12
                                            spacing: 2
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: evRow.modelData.summary
                                                elide: Text.ElideRight
                                                font.pixelSize: Appearance.font.pixelSize.normal
                                                font.weight: Font.DemiBold
                                                color: Appearance.colors.colOnLayer1
                                            }
                                            StyledText {
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                                text: (evRow.modelData.allDay ? "All day" : Qt.formatTime(new Date(evRow.modelData.start * 1000), "HH:mm") + " – " + Qt.formatTime(new Date(evRow.modelData.end * 1000), "HH:mm")) + "  ·  " + evRow.modelData.sourceName + (evRow.modelData.recurring ? "  ·  repeats" : "")
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: Appearance.colors.colSubtext
                                            }
                                            RowLayout {
                                                visible: evRow.modelData.location.length > 0
                                                spacing: 4
                                                MaterialSymbol {
                                                    text: "location_on"
                                                    iconSize: 14
                                                    color: Appearance.colors.colSubtext
                                                }
                                                StyledText {
                                                    text: evRow.modelData.location
                                                    elide: Text.ElideRight
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    color: Appearance.colors.colSubtext
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        visible: win.dayEvents.length === 0
                                        spacing: 6
                                        MaterialSymbol {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "event_available"
                                            iconSize: 40
                                            color: Appearance.colors.colSubtext
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "Nothing scheduled"
                                            color: Appearance.colors.colSubtext
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "Double-click a day or press N"
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                        }
                                    }
                                }
                            }

                            // ── tasks ───────────────────────────
                            SysCard {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.verticalStretchFactor: 1
                                title: "Tasks"
                                subtitle: win.tasks.filter(t => !t.done).length + " open  ·  " + win.tasks.filter(t => t.done).length + " done"
                                icon: "task_alt"
                                accent: Appearance.m3colors.m3tertiary

                                SysTextField {
                                    id: quickTask
                                    Layout.fillWidth: true
                                    icon: "add"
                                    placeholderText: "Add a task  ( A )  — Enter to save"
                                    onAccepted: {
                                        const t = text.trim();
                                        if (!t)
                                            return;
                                        let src = "";
                                        for (const l of win.taskLists)
                                            if (l.writable && (l.default || !src))
                                                src = l.uid;
                                        win.send({
                                            cmd: "create_task",
                                            source: src,
                                            summary: t,
                                            due: -1,
                                            dueAllDay: true
                                        });
                                        text = "";
                                    }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 4
                                    model: win.taskGroups
                                    ScrollBar.vertical: ScrollBar {}
                                    delegate: Loader {
                                        required property var modelData
                                        width: ListView.view.width
                                        sourceComponent: modelData.header ? headerComp : taskComp
                                        property var item_: modelData
                                    }

                                    StyledText {
                                        anchors.centerIn: parent
                                        visible: win.taskGroups.length === 0
                                        text: "No tasks — enjoy the free time"
                                        color: Appearance.colors.colSubtext
                                    }
                                }

                                Component {
                                    id: headerComp
                                    RowLayout {
                                        id: hdr
                                        readonly property var entry: parent && parent.item_ ? parent.item_ : ({ label: "", key: "", count: 0 })
                                        height: 30
                                        spacing: 6
                                        StyledText {
                                            text: hdr.entry.label
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.Bold
                                            color: hdr.entry.key === "overdue" ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
                                        }
                                        StyledText {
                                            text: hdr.entry.count
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                        SysButton {
                                            visible: hdr.entry.key === "done"
                                            text: win.showDone ? "Hide" : "Show"
                                            implicitHeight: 24
                                            onClicked: win.showDone = !win.showDone
                                        }
                                    }
                                }

                                Component {
                                    id: taskComp
                                    Rectangle {
                                        id: taskRow
                                        readonly property var task: parent && parent.item_ && parent.item_.task ? parent.item_.task : ({ summary: "", done: false, due: -1, dueAllDay: true, source: "", uid: "" })
                                        readonly property string groupKey: parent && parent.item_ ? parent.item_.key : ""
                                        height: 44
                                        radius: Appearance.rounding.small
                                        color: taskMouse.containsMouse ? Appearance.colors.colLayer2 : "transparent"

                                        MouseArea {
                                            id: taskMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: editor.openTask(taskRow.task, null)
                                        }
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 6
                                            anchors.rightMargin: 8
                                            spacing: 8
                                            Item {
                                                implicitWidth: 28
                                                implicitHeight: 28
                                                MaterialSymbol {
                                                    anchors.centerIn: parent
                                                    text: taskRow.task.done ? "check_circle" : "radio_button_unchecked"
                                                    iconSize: 22
                                                    color: taskRow.task.done ? Appearance.m3colors.m3tertiary : Appearance.colors.colSubtext
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: win.send({
                                                        cmd: "toggle_task",
                                                        source: taskRow.task.source,
                                                        uid: taskRow.task.uid,
                                                        done: !taskRow.task.done
                                                    })
                                                }
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: taskRow.task.summary
                                                    elide: Text.ElideRight
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                    font.strikeout: taskRow.task.done
                                                    color: taskRow.task.done ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
                                                }
                                                StyledText {
                                                    visible: taskRow.task.due >= 0
                                                    text: {
                                                        const d = new Date(taskRow.task.due * 1000);
                                                        return Qt.locale("en_US").toString(d, "ddd, MMM d") + (taskRow.task.dueAllDay ? "" : "  ·  " + Qt.formatTime(d, "HH:mm"));
                                                    }
                                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                                    color: taskRow.groupKey === "overdue" ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
                                                }
                                            }
                                            SysButton {
                                                visible: taskMouse.containsMouse
                                                icon: "delete"
                                                implicitWidth: 28
                                                implicitHeight: 28
                                                color: "transparent"
                                                onClicked: win.send({
                                                    cmd: "delete_task",
                                                    source: taskRow.task.source,
                                                    uid: taskRow.task.uid
                                                })
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                AgendaEditor {
                    id: editor
                    anchors.fill: parent
                    z: 50
                    calendars: win.calendars
                    taskLists: win.taskLists
                    onSubmit: cmd => win.send(cmd)
                    onOpacityChanged: if (opacity === 0)
                        content.forceActiveFocus()
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
