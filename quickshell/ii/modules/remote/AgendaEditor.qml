import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sysmonitor

/**
 * Modal editor for events and tasks.
 * openEvent(ev|null, defaultDay) / openTask(task|null, defaultDay); emits submit(cmdObject).
 */
Item {
    id: editor

    property var calendars: []
    property var taskLists: []
    property string mode: "event"     // "event" | "task"
    property var original: null
    property string sourceUid: ""
    property bool allDay: false
    property bool hasDue: false
    property string errorText: ""
    readonly property bool editing: original !== null
    readonly property var sourceList: (mode === "event" ? calendars : taskLists).filter(s => s.writable)

    signal submit(var cmd)

    visible: opacity > 0
    opacity: 0
    Behavior on opacity {
        NumberAnimation {
            duration: 160
        }
    }

    function pad(n) {
        return (n < 10 ? "0" : "") + n;
    }
    function fmtDate(d) {
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
    }
    function fmtTime(d) {
        return pad(d.getHours()) + ":" + pad(d.getMinutes());
    }
    // accepts 2026-11-06, 06/11/2026, 06/11
    function parseDate(s) {
        s = s.trim();
        let m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
        if (m)
            return new Date(+m[1], +m[2] - 1, +m[3]);
        m = s.match(/^(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?$/);
        if (m) {
            let y = m[3] ? +m[3] : new Date().getFullYear();
            if (y < 100)
                y += 2000;
            return new Date(y, +m[2] - 1, +m[1]);
        }
        return null;
    }
    // accepts 14:30, 14h30, 14h, 9
    function parseTime(s) {
        const m = s.trim().toLowerCase().match(/^(\d{1,2})(?:[:h](\d{2})?)?$/);
        if (!m)
            return null;
        const h = +m[1], mi = m[2] ? +m[2] : 0;
        if (h > 23 || mi > 59)
            return null;
        return [h, mi];
    }
    function defaultSource() {
        const list = editor.sourceList;
        for (const s of list)
            if (s.default)
                return s.uid;
        return list.length ? list[0].uid : "";
    }

    function openEvent(ev, day) {
        mode = "event";
        original = ev;
        errorText = "";
        const base = day || new Date();
        if (ev) {
            const s = new Date(ev.start * 1000), e = new Date(ev.end * 1000);
            titleField.text = ev.summary;
            sourceUid = ev.source;
            allDay = ev.allDay;
            dateField.text = fmtDate(s);
            startField.text = fmtTime(s);
            endField.text = ev.allDay ? "" : fmtTime(e);
            endDateField.text = ev.allDay ? fmtDate(new Date(e.getTime() - 86400000)) : (e.toDateString() !== s.toDateString() ? fmtDate(e) : "");
            locationField.text = ev.location;
            notesField.text = ev.description;
        } else {
            const now = new Date();
            const h = Math.min(22, now.getHours() + 1);
            titleField.text = "";
            sourceUid = defaultSource();
            allDay = false;
            dateField.text = fmtDate(base);
            startField.text = pad(h) + ":00";
            endField.text = pad(h + 1) + ":00";
            endDateField.text = "";
            locationField.text = "";
            notesField.text = "";
        }
        opacity = 1;
        titleField.field.forceActiveFocus();
    }

    function openTask(t, day) {
        mode = "task";
        original = t;
        errorText = "";
        if (t) {
            titleField.text = t.summary;
            sourceUid = t.source;
            hasDue = t.due >= 0;
            const d = hasDue ? new Date(t.due * 1000) : (day || new Date());
            dateField.text = fmtDate(d);
            allDay = t.due < 0 || t.dueAllDay;
            startField.text = allDay ? "" : fmtTime(d);
            notesField.text = t.description;
        } else {
            titleField.text = "";
            sourceUid = defaultSource();
            hasDue = day !== undefined && day !== null;
            dateField.text = fmtDate(day || new Date());
            allDay = true;
            startField.text = "";
            notesField.text = "";
        }
        locationField.text = "";
        opacity = 1;
        titleField.field.forceActiveFocus();
    }

    function close() {
        opacity = 0;
    }

    function save() {
        errorText = "";
        const title = titleField.text.trim();
        if (!title) {
            errorText = "Give it a title";
            return;
        }
        if (!sourceUid) {
            errorText = "No writable calendar available";
            return;
        }
        if (mode === "event") {
            const d = parseDate(dateField.text);
            if (!d) {
                errorText = "Date: use 2026-11-06 or 06/11/2026";
                return;
            }
            let start, end;
            if (allDay) {
                start = d;
                const ed = endDateField.text.trim() ? parseDate(endDateField.text) : d;
                if (!ed) {
                    errorText = "End date is invalid";
                    return;
                }
                end = new Date(ed.getFullYear(), ed.getMonth(), ed.getDate() + 1);
            } else {
                const st = parseTime(startField.text), et = endField.text.trim() ? parseTime(endField.text) : null;
                if (!st) {
                    errorText = "Start time: use 14:30";
                    return;
                }
                start = new Date(d.getFullYear(), d.getMonth(), d.getDate(), st[0], st[1]);
                const ed = endDateField.text.trim() ? parseDate(endDateField.text) : d;
                end = et ? new Date(ed.getFullYear(), ed.getMonth(), ed.getDate(), et[0], et[1]) : new Date(start.getTime() + 3600000);
                if (end <= start)
                    end = new Date(start.getTime() + 3600000);
            }
            const cmd = {
                cmd: editing ? "update_event" : "create_event",
                source: sourceUid,
                summary: title,
                start: Math.floor(start.getTime() / 1000),
                end: Math.floor(end.getTime() / 1000),
                allDay: allDay,
                location: locationField.text.trim(),
                description: notesField.text.trim()
            };
            if (editing)
                cmd.uid = original.uid;
            if (editing && original.source !== sourceUid) {
                // moving between calendars = create in new + delete in old
                cmd.cmd = "create_event";
                submit(cmd);
                submit({
                    cmd: "delete_event",
                    source: original.source,
                    uid: original.uid
                });
            } else
                submit(cmd);
        } else {
            let due = -1;
            if (hasDue) {
                const d = parseDate(dateField.text);
                if (!d) {
                    errorText = "Due date: use 2026-11-06 or 06/11/2026";
                    return;
                }
                const t = startField.text.trim() ? parseTime(startField.text) : null;
                if (startField.text.trim() && !t) {
                    errorText = "Time: use 14:30";
                    return;
                }
                due = Math.floor(new Date(d.getFullYear(), d.getMonth(), d.getDate(), t ? t[0] : 0, t ? t[1] : 0).getTime() / 1000);
                allDay = !t;
            }
            const cmd = {
                cmd: editing ? "update_task" : "create_task",
                source: sourceUid,
                summary: title,
                due: due,
                dueAllDay: allDay,
                description: notesField.text.trim()
            };
            if (editing)
                cmd.uid = original.uid;
            submit(cmd);
        }
        close();
    }

    function remove() {
        if (!original)
            return;
        submit({
            cmd: mode === "event" ? "delete_event" : "delete_task",
            source: original.source,
            uid: original.uid
        });
        close();
    }

    // scrim
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.6
        MouseArea {
            anchors.fill: parent
            onClicked: editor.close()
        }
    }

    Rectangle {
        id: sheet
        anchors.centerIn: parent
        width: 520
        height: form.implicitHeight + 40
        radius: Appearance.rounding.large
        color: Qt.rgba(Appearance.colors.colLayer1.r, Appearance.colors.colLayer1.g, Appearance.colors.colLayer1.b, 1)
        border.width: 1
        border.color: Appearance.m3colors.m3outlineVariant

        MouseArea {
            anchors.fill: parent
        } // swallow clicks

        Keys.onEscapePressed: editor.close()

        ColumnLayout {
            id: form
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                MaterialSymbol {
                    text: editor.mode === "event" ? "event" : "task_alt"
                    iconSize: 24
                    color: Appearance.m3colors.m3primary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: (editor.editing ? "Edit " : "New ") + editor.mode
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer1
                }
            }

            SysTextField {
                id: titleField
                Layout.fillWidth: true
                icon: "title"
                placeholderText: editor.mode === "event" ? "Event title" : "What needs to be done?"
                onAccepted: editor.save()
            }

            // calendar / list chooser
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: editor.sourceList
                    delegate: SysButton {
                        required property var modelData
                        readonly property bool current: editor.sourceUid === modelData.uid
                        icon: current ? "check" : "circle"
                        text: modelData.name + (modelData.account && modelData.account !== "On This Computer" ? "  ·  " + modelData.account : "")
                        toggled: current
                        implicitHeight: 30
                        onClicked: editor.sourceUid = modelData.uid
                    }
                }
            }

            // due toggle (tasks) / all-day toggle (events)
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                SysSwitch {
                    checked: editor.mode === "event" ? editor.allDay : editor.hasDue
                    onToggled: on => {
                        if (editor.mode === "event")
                            editor.allDay = on;
                        else
                            editor.hasDue = on;
                    }
                }
                StyledText {
                    text: editor.mode === "event" ? "All day" : "Has a due date"
                    color: Appearance.colors.colOnLayer1
                }
            }

            GridLayout {
                Layout.fillWidth: true
                visible: editor.mode === "event" || editor.hasDue
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                SysTextField {
                    id: dateField
                    Layout.fillWidth: true
                    icon: "calendar_today"
                    placeholderText: "2026-11-06"
                    onAccepted: editor.save()
                }
                SysTextField {
                    id: endDateField
                    Layout.fillWidth: true
                    visible: editor.mode === "event"
                    icon: "event_upcoming"
                    placeholderText: "End date (optional)"
                    onAccepted: editor.save()
                }
                SysTextField {
                    id: startField
                    Layout.fillWidth: true
                    visible: editor.mode === "event" ? !editor.allDay : true
                    icon: "schedule"
                    placeholderText: editor.mode === "event" ? "Start  14:30" : "Time (optional)  20:00"
                    onAccepted: editor.save()
                }
                SysTextField {
                    id: endField
                    Layout.fillWidth: true
                    visible: editor.mode === "event" && !editor.allDay
                    icon: "schedule"
                    placeholderText: "End  15:30"
                    onAccepted: editor.save()
                }
            }

            SysTextField {
                id: locationField
                Layout.fillWidth: true
                visible: editor.mode === "event"
                icon: "location_on"
                placeholderText: "Location"
                onAccepted: editor.save()
            }
            SysTextField {
                id: notesField
                Layout.fillWidth: true
                icon: "notes"
                placeholderText: "Notes"
                onAccepted: editor.save()
            }

            StyledText {
                visible: editor.errorText.length > 0
                text: editor.errorText
                color: Appearance.m3colors.m3error
                font.pixelSize: Appearance.font.pixelSize.small
            }
            StyledText {
                visible: editor.editing && editor.mode === "event" && editor.original && editor.original.recurring
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "This is a recurring event — changes apply to the whole series."
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8
                SysButton {
                    visible: editor.editing
                    icon: "delete"
                    text: "Delete"
                    danger: true
                    onClicked: editor.remove()
                }
                Item {
                    Layout.fillWidth: true
                }
                SysButton {
                    text: "Cancel"
                    onClicked: editor.close()
                }
                SysButton {
                    icon: "check"
                    text: "Save"
                    tonal: true
                    onClicked: editor.save()
                }
            }
        }
    }
}
