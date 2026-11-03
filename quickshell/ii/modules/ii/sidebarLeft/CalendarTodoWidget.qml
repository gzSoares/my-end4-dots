import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.calendar
import qs.modules.ii.sidebarRight.todo
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // Calendar
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: parent.height * 0.2
            radius: 0
            color: Appearance.colors.colLayer1
            clip: true

            CalendarWidget {
                anchors.fill: parent
            }
        }

        // To Do
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: parent.height * 0.5
            radius: 0
            color: Appearance.colors.colLayer1
            clip: true

            TodoWidget {
                anchors.fill: parent
            }
        }
    }
}