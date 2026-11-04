pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * What the phone is playing, mirrored from KDE Connect's MPRIS player.
 *
 * The KDE Connect daemon only publishes that player while the phone has a
 * media session, so the host shows this card only while one exists. It holds
 * the cover, the title and artist, and previous / play-pause / next.
 */
Rectangle {
    id: root

    required property var player

    readonly property string title: root.player?.trackTitle ?? ""
    readonly property string artist: root.player?.trackArtist ?? ""
    readonly property string artUrl: root.player?.trackArtUrl ?? ""
    readonly property bool playing: root.player?.isPlaying ?? false

    implicitHeight: 76
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer3
    clip: true

    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }

    component TransportButton: Rectangle {
        id: btn
        property string icon: ""
        property bool primary: false
        property bool enabledState: true
        signal clicked()

        implicitWidth: primary ? 44 : 36
        implicitHeight: implicitWidth
        radius: width / 2
        color: primary ? Appearance.colors.colPrimary
            : (area.containsMouse ? Appearance.colors.colLayer3Hover : "transparent")
        opacity: enabledState ? 1 : 0.4

        MaterialSymbol {
            anchors.centerIn: parent
            text: btn.icon
            fill: 1
            iconSize: btn.primary ? 24 : 20
            color: btn.primary ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.enabledState
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    RowLayout {
        anchors {
            fill: parent
            margins: 10
        }
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2
            clip: true

            Image {
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: status === Image.Ready
            }
            MaterialSymbol {
                anchors.centerIn: parent
                visible: root.artUrl === ""
                text: "music_note"
                iconSize: 26
                color: Appearance.colors.colSubtext
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer3
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.artist !== ""
                text: root.artist
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        TransportButton {
            icon: "skip_previous"
            enabledState: root.player?.canGoPrevious ?? false
            onClicked: root.player?.previous()
        }
        TransportButton {
            primary: true
            icon: root.playing ? "pause" : "play_arrow"
            onClicked: root.player?.togglePlaying()
        }
        TransportButton {
            icon: "skip_next"
            enabledState: root.player?.canGoNext ?? false
            onClicked: root.player?.next()
        }
    }
}
