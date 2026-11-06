pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.widgets
import qs.services

/**
 * The call on the phone, seen from the shell: who, for how long, and the
 * buttons that act on it (answer while it rings, hang up always). The sound
 * stays on the phone; this only places, follows and ends the call.
 */
Rectangle {
    id: root

    visible: PhoneCallService.active
    implicitHeight: visible ? row.implicitHeight + 2 * Appearance.spacing.md : 0
    radius: Appearance.rounding.normal
    color: Appearance.colors.colPrimaryContainer

    property double _now: Date.now()
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && PhoneCallService.callState === "talking"
        onTriggered: root._now = Date.now()
    }

    readonly property string statusText: {
        if (PhoneCallService.callState === "ringing")
            return Translation.tr("Ringing");
        const s = Math.max(0, Math.floor((root._now - PhoneCallService.stateSince) / 1000));
        const mm = Math.floor(s / 60), ss = s % 60;
        return Translation.tr("In call") + " · " + mm + ":" + (ss < 10 ? "0" : "") + ss;
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Appearance.spacing.md
        spacing: Appearance.spacing.md

        Rectangle {
            id: avatarBox
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: Math.min(width / 2, Appearance.rounding.full)
            color: Appearance.colors.colPrimary
            clip: true

            Image {
                anchors.fill: parent
                source: PhoneCallService.avatarPath !== "" ? ("file://" + PhoneCallService.avatarPath) : ""
                visible: PhoneCallService.avatarPath !== ""
                fillMode: Image.PreserveAspectCrop
            }
            StyledText {
                anchors.centerIn: parent
                visible: PhoneCallService.avatarPath === ""
                text: (PhoneCallService.displayName || "?").substring(0, 1).toUpperCase()
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Bold
                color: Appearance.colors.colOnPrimary
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -2
            StyledText {
                Layout.fillWidth: true
                text: PhoneCallService.displayName
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnPrimaryContainer
            }
            StyledText {
                Layout.fillWidth: true
                text: root.statusText
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnPrimaryContainer
                opacity: 0.8
            }
        }

        RippleButton {
            visible: PhoneCallService.callState === "ringing" && PhoneCallService.adbLive
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            onClicked: PhoneCallService.answer()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "call"
                iconSize: 20
                color: Appearance.colors.colOnPrimary
            }
            StyledToolTip { text: Translation.tr("Answer") }
        }

        RippleButton {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colError
            colBackgroundHover: Appearance.colors.colErrorHover
            enabled: PhoneCallService.adbLive || PhoneCallService.callState !== "ringing"
            onClicked: PhoneCallService.decline()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "call_end"
                iconSize: 20
                color: Appearance.colors.colOnError
            }
            StyledToolTip { text: PhoneCallService.callState === "ringing" ? Translation.tr("Decline") : Translation.tr("Hang up") }
        }
    }
}
