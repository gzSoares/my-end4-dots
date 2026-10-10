import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import qs.modules.common.functions

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

import qs.modules.ii.bar as Bar

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property MprisPlayer player: MprisController.trackedPlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(player?.trackTitle) || Translation.tr("No media")

    // What the controls popup lines itself up with. Matches the horizontal
    // widget so the popup opens beside whichever one was clicked rather than
    // at a fixed spot on the screen edge.
    readonly property Item popupAnchorItem: parent?.popupAnchor ?? root

    Layout.fillHeight: true
    implicitHeight: mediaCircProg.implicitHeight
    implicitWidth: Appearance.sizes.verticalBarWidth

    Timer {
        running: player?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: player.positionChanged()
    }

    acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
    hoverEnabled: !Config.options.bar.tooltips.clickToShow
    onPressed: (event) => {
        if (event.button === Qt.MiddleButton) {
            player.togglePlaying();
        } else if (event.button === Qt.BackButton) {
            player.previous();
        } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
            player.next();
        } else if (event.button === Qt.LeftButton) {
            GlobalStates.mediaWidgetItem = root.popupAnchorItem;
            GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
        }
    }

    Bar.MediaTransferDropArea {
        anchors.fill: parent
        popupAnchorItem: root.popupAnchorItem
    }

    ClippedFilledCircularProgress {
        id: mediaCircProg
        anchors.centerIn: parent
        implicitSize: 20

        lineWidth: Appearance.rounding.unsharpen
        value: player?.position / player?.length
        colPrimary: Appearance.colors.colOnSecondaryContainer
        enableAnimation: false

        Item {
            anchors.centerIn: parent
            width: mediaCircProg.implicitSize
            height: mediaCircProg.implicitSize
            
            MaterialSymbol {
                anchors.centerIn: parent
                fill: 1
                text: player?.isPlaying ? "pause" : "music_note"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3onSecondaryContainer
            }
        }
    }

    Bar.StyledPopup {
        hoverTarget: root
        active: GlobalStates.mediaControlsOpen ? false : root.containsMouse

        Column {
            anchors.centerIn: parent
            spacing: 4

            Bar.StyledPopupHeaderRow {
                icon: "music_note"
                label: Translation.tr("Media")
            }

            StyledText {
                color: Appearance.colors.colOnSurfaceVariant
                text: `${cleanedTitle}${player?.trackArtist ? '\\n' + player.trackArtist : ''}`
            }
        }
    }

}
