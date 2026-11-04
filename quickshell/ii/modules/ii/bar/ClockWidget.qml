import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool showDate: Config.options.bar.verbose
    implicitWidth: rowLayout.implicitWidth
    implicitHeight: Appearance.sizes.baseBarHeight

    readonly property Item popupAnchorItem: root
    readonly property real clockSize: {
        const s = Config.options.bar.clock.fontSize
        return s >= 0 ? s : Appearance.font.pixelSize.large
    }
    readonly property bool clockBold: Config.options.bar.clock.bold
    readonly property string separatorText: {
        switch (Config.options.bar.clock.separator) {
        case "bar": return "|"
        case "dash": return "–"
        case "none": return ""
        default: return "•"
        }
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 4

        StyledText {
            font.pixelSize: root.clockSize
            font.weight: root.clockBold ? Font.DemiBold : Font.Normal
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer1
            text: DateTime.time
        }

        StyledText {
            visible: root.showDate && root.separatorText !== ""
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: root.separatorText
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: DateTime.longDate
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow

        ClockWidgetPopup {
            hoverTarget: mouseArea
        }
    }

    DropArea {
        anchors.fill: parent
        z: 10

        onEntered: (drag) => {
            if (!drag.hasUrls) return;
            if (LocalSend.state === LocalSend.stateSending) return;
            GlobalStates.mediaWidgetItem = root;
            GlobalStates.mediaTransferActive = true;
            GlobalStates.mediaControlsOpen = true;
        }
        onDropped: (drop) => {
            if (LocalSend.state === LocalSend.stateSending) return;
            const urls = (drop.urls ?? []).map(u => String(u));
            if (urls.length > 0) GlobalStates.mediaTransferUrls = urls;
            drop.accept(Qt.CopyAction);
        }
    }
}
