import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/** 6×7 month grid with colored event pills. */
Item {
    id: month

    property int year: new Date().getFullYear()
    property int monthIndex: new Date().getMonth()
    property date selected: new Date()
    property var eventsByDay: ({})
    property var tasksByDay: ({})
    property int weekStart: Qt.locale().firstDayOfWeek  // 0 = Sunday
    signal daySelected(date d)
    signal dayDoubleClicked(date d)

    readonly property date gridStart: {
        const first = new Date(year, monthIndex, 1);
        const offset = (first.getDay() - weekStart + 7) % 7;
        return new Date(year, monthIndex, 1 - offset);
    }

    function pad(n) {
        return (n < 10 ? "0" : "") + n;
    }
    function dayKey(d) {
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
    }
    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // weekday header
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: 7
                delegate: StyledText {
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale("en_US").dayName((month.weekStart + index) % 7, Locale.ShortFormat)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: Appearance.colors.colSubtext
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: 6
            columnSpacing: 6

            Repeater {
                model: 42
                delegate: Rectangle {
                    id: cell
                    required property int index
                    readonly property date day: new Date(month.gridStart.getFullYear(), month.gridStart.getMonth(), month.gridStart.getDate() + index)
                    readonly property bool inMonth: day.getMonth() === month.monthIndex
                    readonly property bool isToday: month.sameDay(day, new Date())
                    readonly property bool isSelected: month.sameDay(day, month.selected)
                    readonly property var events: month.eventsByDay[month.dayKey(day)] || []
                    readonly property int taskCount: (month.tasksByDay[month.dayKey(day)] || []).length
                    readonly property int maxPills: Math.max(0, Math.floor((height - 34) / 20))

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 1
                    radius: Appearance.rounding.small
                    color: isSelected ? Appearance.m3colors.m3secondaryContainer : cellMouse.containsMouse ? Appearance.colors.colLayer2 : inMonth ? Qt.rgba(Appearance.colors.colLayer2.r, Appearance.colors.colLayer2.g, Appearance.colors.colLayer2.b, 0.5) : "transparent"
                    border.width: isToday && !isSelected ? 1 : 0
                    border.color: Appearance.m3colors.m3primary
                    clip: true

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: month.daySelected(cell.day)
                        onDoubleClicked: month.dayDoubleClicked(cell.day)
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Rectangle {
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: 13
                                color: cell.isToday ? Appearance.m3colors.m3primary : "transparent"
                                StyledText {
                                    anchors.centerIn: parent
                                    text: cell.day.getDate()
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: cell.isToday || cell.isSelected ? Font.Bold : Font.Normal
                                    color: cell.isToday ? Appearance.m3colors.m3onPrimary : cell.isSelected ? Appearance.m3colors.m3onSecondaryContainer : cell.inMonth ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                                    opacity: cell.inMonth || cell.isToday ? 1 : 0.5
                                }
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            MaterialSymbol {
                                visible: cell.taskCount > 0
                                text: "task_alt"
                                iconSize: 14
                                color: Appearance.m3colors.m3tertiary
                            }
                        }

                        Repeater {
                            model: cell.events.slice(0, cell.events.length > cell.maxPills ? Math.max(0, cell.maxPills - 1) : cell.maxPills)
                            delegate: Rectangle {
                                id: pill
                                required property var modelData
                                readonly property color evColor: modelData.color ? modelData.color : Appearance.m3colors.m3primary
                                Layout.fillWidth: true
                                implicitHeight: 17
                                radius: 5
                                color: modelData.allDay ? Qt.rgba(evColor.r, evColor.g, evColor.b, 0.85) : Qt.rgba(evColor.r, evColor.g, evColor.b, 0.18)
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 5
                                    anchors.rightMargin: 4
                                    spacing: 4
                                    Rectangle {
                                        visible: !pill.modelData.allDay
                                        implicitWidth: 3
                                        implicitHeight: 11
                                        radius: 2
                                        color: pill.evColor
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: (pill.modelData.allDay ? "" : Qt.formatTime(new Date(pill.modelData.start * 1000), "HH:mm") + " ") + pill.modelData.summary
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: pill.modelData.allDay ? "#111111" : Appearance.colors.colOnLayer1
                                    }
                                }
                            }
                        }
                        StyledText {
                            visible: cell.events.length > cell.maxPills && cell.maxPills > 0
                            text: "+" + (cell.events.length - Math.max(0, cell.maxPills - 1)) + " more"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }
                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }
            }
        }
    }
}
