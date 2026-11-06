pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * The Chat tab: Discord voice. In a call it shows who is there and who is
 * speaking, with mute, deafen and leave; outside one it lists the voice
 * channels of the chosen server to join. The sound stays in the Discord app,
 * which has to be running; this only shows and drives it.
 */
Item {
    id: root

    readonly property var voice: DiscordService.voice
    readonly property bool ready: DiscordService.authorized

    // What to say while it is not ready yet
    readonly property string waitingTitle: {
        if (!DiscordService.configured) return Translation.tr("Set up Discord voice");
        switch (DiscordService.status) {
        case "waiting for Discord": return Translation.tr("Open the Discord app");
        case "waiting for authorization": return Translation.tr("Authorize in Discord");
        case "needs setup": return Translation.tr("Set up Discord voice");
        default: return Translation.tr("Connecting to Discord…");
        }
    }
    readonly property string waitingHint: {
        if (!DiscordService.configured)
            return Translation.tr("Add the client ID and secret of your Discord app in Settings > Interface > Left sidebar.");
        switch (DiscordService.status) {
        case "waiting for Discord": return Translation.tr("The official Discord app has to be running. It can stay minimized.");
        case "waiting for authorization": return Translation.tr("Discord is asking you to allow this app. Accept the prompt in the Discord window.");
        default: return DiscordService.error;
        }
    }

    component RoundButton: RippleButton {
        id: btn
        property string symbol: ""
        property string tip: ""
        property bool danger: false
        property bool active: false
        implicitWidth: 48
        implicitHeight: 48
        buttonRadius: Appearance.rounding.verysmall
        colBackground: danger ? Appearance.colors.colError
            : (active ? Appearance.colors.colErrorContainer : Appearance.colors.colSecondaryContainer)
        colBackgroundHover: danger ? Appearance.colors.colErrorHover
            : (active ? Appearance.colors.colErrorContainerHover : Appearance.colors.colSecondaryContainerHover)
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: btn.symbol
            iconSize: 22
            color: btn.danger ? Appearance.colors.colOnError
                : (btn.active ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSecondaryContainer)
        }
        StyledToolTip { text: btn.tip }
    }

    component Avatar: Rectangle {
        id: av
        property string name: ""
        property string source: ""
        property bool speaking: false
        implicitWidth: 36
        implicitHeight: 36
        radius: width / 2
        color: Appearance.colors.colPrimary
        border.width: speaking ? 3 : 0
        border.color: "#3ba55d"
        Behavior on border.width { NumberAnimation { duration: Appearance.motion.fast } }
        Image {
            id: img
            anchors.fill: parent
            anchors.margins: av.speaking ? 3 : 0
            source: av.source
            visible: status === Image.Ready
            fillMode: Image.PreserveAspectCrop
            layer.enabled: visible
            layer.effect: OpacityMask {
                maskSource: Rectangle { width: img.width; height: img.height; radius: width / 2 }
            }
        }
        StyledText {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready
            text: (av.name || "?").substring(0, 1).toUpperCase()
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Bold
            color: Appearance.colors.colOnPrimary
        }
    }

    StyledFlickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight + 20
        clip: true

        ColumnLayout {
            id: column
            width: parent.width - 20
            x: 10
            y: 10
            spacing: Appearance.spacing.md

            // ── Not ready: say what is missing ─────────────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: !root.ready
                implicitHeight: waitCol.implicitHeight + 2 * Appearance.spacing.lg
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2

                ColumnLayout {
                    id: waitCol
                    anchors.fill: parent
                    anchors.margins: Appearance.spacing.lg
                    spacing: Appearance.spacing.sm
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "headset_mic"
                        iconSize: 40
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.waitingTitle
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: root.waitingHint
                        visible: text !== ""
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    RippleButton {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Appearance.spacing.sm
                        visible: DiscordService.configured && DiscordService.status === "waiting for Discord"
                        implicitHeight: 40
                        implicitWidth: openRow.implicitWidth + 2 * Appearance.spacing.lg
                        buttonRadius: Math.min(height / 2, Appearance.rounding.full)
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        onClicked: DiscordService.openApp()
                        contentItem: RowLayout {
                            id: openRow
                            anchors.centerIn: parent
                            spacing: Appearance.spacing.sm
                            MaterialSymbol {
                                text: "open_in_new"
                                iconSize: 18
                                color: Appearance.colors.colOnPrimary
                            }
                            StyledText {
                                text: Translation.tr("Open Discord")
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnPrimary
                            }
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        visible: DiscordService.error !== "" && root.waitingHint !== DiscordService.error
                        text: DiscordService.error
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colError
                    }
                }
            }

            // ── In a call ──────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: root.ready && root.voice !== null
                implicitHeight: callCol.implicitHeight + 2 * Appearance.spacing.md
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2

                ColumnLayout {
                    id: callCol
                    anchors.fill: parent
                    anchors.margins: Appearance.spacing.md
                    spacing: Appearance.spacing.sm

                    RowLayout {
                        spacing: Appearance.spacing.sm
                        MaterialSymbol {
                            text: "volume_up"
                            iconSize: 18
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.voice ? root.voice.name : ""
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            text: Translation.tr("%1 in the call").arg(root.voice ? root.voice.users.length : 0)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }

                    Repeater {
                        model: root.voice ? root.voice.users : []
                        delegate: ColumnLayout {
                            id: userRow
                            required property var modelData
                            property bool open: false
                            Layout.fillWidth: true
                            spacing: 0

                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 48
                                buttonRadius: Appearance.rounding.verysmall
                                colBackground: "transparent"
                                enabled: !userRow.modelData.me
                                onClicked: userRow.open = !userRow.open
                                contentItem: RowLayout {
                                    spacing: Appearance.spacing.md
                                    Avatar {
                                        name: userRow.modelData.name
                                        source: userRow.modelData.avatar
                                        speaking: userRow.modelData.speaking
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: -2
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: userRow.modelData.me ? Translation.tr("%1 (you)").arg(userRow.modelData.name) : userRow.modelData.name
                                            elide: Text.ElideRight
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnLayer2
                                        }
                                        StyledText {
                                            visible: text !== ""
                                            text: userRow.modelData.localMute ? Translation.tr("silenced for you")
                                                : (userRow.modelData.speaking ? Translation.tr("speaking") : "")
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                        }
                                    }
                                    MaterialSymbol {
                                        visible: userRow.modelData.mute
                                        text: "mic_off"
                                        iconSize: 18
                                        color: Appearance.colors.colError
                                    }
                                    MaterialSymbol {
                                        visible: userRow.modelData.deaf
                                        text: "headset_off"
                                        iconSize: 18
                                        color: Appearance.colors.colError
                                    }
                                }
                            }

                            // Volume and silence for this person, only for you
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 48
                                Layout.rightMargin: Appearance.spacing.sm
                                visible: userRow.open && !userRow.modelData.me
                                spacing: Appearance.spacing.sm
                                StyledSlider {
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 200
                                    stepSize: 5
                                    usePercentTooltip: false
                                    tooltipContent: Math.round(value) + "%"
                                    value: userRow.modelData.volume
                                    onMoved: DiscordService.setUserVolume(userRow.modelData.id, Math.round(value))
                                }
                                RippleButton {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    buttonRadius: Appearance.rounding.verysmall
                                    colBackground: userRow.modelData.localMute ? Appearance.colors.colErrorContainer : Appearance.colors.colSecondaryContainer
                                    onClicked: DiscordService.muteUser(userRow.modelData.id, !userRow.modelData.localMute)
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: userRow.modelData.localMute ? "volume_off" : "volume_up"
                                        iconSize: 18
                                        color: Appearance.colors.colOnSecondaryContainer
                                    }
                                    StyledToolTip { text: Translation.tr("Silence for me") }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Appearance.spacing.sm
                        spacing: Appearance.spacing.md
                        RoundButton {
                            symbol: DiscordService.settings.mute ? "mic_off" : "mic"
                            active: DiscordService.settings.mute
                            tip: DiscordService.settings.mute ? Translation.tr("Unmute") : Translation.tr("Mute")
                            onClicked: DiscordService.setMute(!DiscordService.settings.mute)
                        }
                        RoundButton {
                            symbol: DiscordService.settings.deaf ? "headset_off" : "headset"
                            active: DiscordService.settings.deaf
                            tip: DiscordService.settings.deaf ? Translation.tr("Undeafen") : Translation.tr("Deafen")
                            onClicked: DiscordService.setDeaf(!DiscordService.settings.deaf)
                        }
                        RoundButton {
                            symbol: "call_end"
                            danger: true
                            tip: Translation.tr("Leave the call")
                            onClicked: DiscordService.leave()
                        }
                    }
                }
            }

            // ── Volumes (always, once ready) ───────────────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: root.ready
                implicitHeight: volCol.implicitHeight + 2 * Appearance.spacing.md
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2

                ColumnLayout {
                    id: volCol
                    anchors.fill: parent
                    anchors.margins: Appearance.spacing.md
                    spacing: Appearance.spacing.sm
                    Repeater {
                        model: [
                            { which: "input", icon: "mic", label: Translation.tr("Microphone") },
                            { which: "output", icon: "volume_up", label: Translation.tr("Volume") }
                        ]
                        delegate: RowLayout {
                            id: volRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.md
                            MaterialSymbol {
                                text: volRow.modelData.icon
                                iconSize: 20
                                color: Appearance.colors.colSubtext
                            }
                            StyledSlider {
                                Layout.fillWidth: true
                                from: 0
                                to: 100
                                stepSize: 1
                                usePercentTooltip: false
                                tooltipContent: volRow.modelData.label + " " + Math.round(value) + "%"
                                value: DiscordService.settings[volRow.modelData.which]
                                onMoved: DiscordService.setVolume(volRow.modelData.which, Math.round(value))
                            }
                        }
                    }

                    // Which microphone and speakers Discord uses
                    Repeater {
                        model: [
                            { which: "input", icon: "mic", label: Translation.tr("Microphone") },
                            { which: "output", icon: "speaker", label: Translation.tr("Output") }
                        ]
                        delegate: RowLayout {
                            id: devRow
                            required property var modelData
                            readonly property var devices: DiscordService.settings[modelData.which + "Devices"] ?? []
                            readonly property string current: DiscordService.settings[modelData.which + "Device"] ?? ""
                            Layout.fillWidth: true
                            visible: devices.length > 0
                            spacing: Appearance.spacing.md
                            MaterialSymbol {
                                text: devRow.modelData.icon
                                iconSize: 20
                                color: Appearance.colors.colSubtext
                            }
                            StyledComboBox {
                                Layout.fillWidth: true
                                implicitHeight: 36
                                textRole: "name"
                                model: devRow.devices
                                currentIndex: Math.max(0, devRow.devices.findIndex(d => d.id === devRow.current))
                                onActivated: index => DiscordService.setDevice(devRow.modelData.which, devRow.devices[index].id)
                            }
                        }
                    }
                }
            }

            // ── Test the microphone and the audio ──────────────────────
            MicTester {
                Layout.fillWidth: true
                visible: root.ready
            }

            // ── Not in a call: servers and voice channels ──────────────
            Flow {
                Layout.fillWidth: true
                visible: root.ready && root.voice === null && DiscordService.guilds.length > 0
                spacing: Appearance.spacing.sm
                Repeater {
                    model: DiscordService.guilds
                    delegate: RippleButton {
                        id: guildChip
                        required property var modelData
                        readonly property bool on: modelData.id === DiscordService.guildId
                        implicitHeight: 32
                        implicitWidth: chipText.implicitWidth + 2 * Appearance.spacing.lg
                        buttonRadius: Math.min(height / 2, Appearance.rounding.full)
                        colBackground: on ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colLayer2
                        colBackgroundHover: on ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colLayer2Hover
                        onClicked: DiscordService.selectGuild(modelData.id)
                        contentItem: StyledText {
                            id: chipText
                            anchors.centerIn: parent
                            text: guildChip.modelData.name
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: guildChip.on ? Font.DemiBold : Font.Normal
                            color: guildChip.on ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.ready && root.voice === null
                implicitHeight: chCol.implicitHeight + 2 * Appearance.spacing.md
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2

                ColumnLayout {
                    id: chCol
                    anchors.fill: parent
                    anchors.margins: Appearance.spacing.md
                    spacing: Appearance.spacing.sm

                    StyledText {
                        text: Translation.tr("Voice channels")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                    Repeater {
                        model: DiscordService.channels
                        delegate: RippleButton {
                            id: chRow
                            required property var modelData
                            readonly property var members: modelData.users ?? []
                            Layout.fillWidth: true
                            implicitHeight: 52 + (members.length > 0 ? members.length * 28 + Appearance.spacing.sm : 0)
                            buttonRadius: Appearance.rounding.verysmall
                            colBackground: Appearance.colors.colLayer3
                            colBackgroundHover: Appearance.colors.colLayer3Hover
                            onClicked: DiscordService.join(modelData.id)
                            contentItem: ColumnLayout {
                              spacing: Appearance.spacing.xs
                              RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                spacing: Appearance.spacing.md
                                MaterialSymbol {
                                    text: "volume_up"
                                    iconSize: 22
                                    color: Appearance.colors.colPrimary
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: -2
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: chRow.modelData.name
                                        elide: Text.ElideRight
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnLayer3
                                    }
                                    StyledText {
                                        visible: chRow.modelData.count !== null && chRow.modelData.count !== undefined
                                        text: chRow.modelData.count === 0 ? Translation.tr("empty")
                                            : Translation.tr("%1 in the call").arg(chRow.modelData.count)
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                    }
                                }
                                StyledText {
                                    text: Translation.tr("Join")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colPrimary
                                }
                              }
                              // Who is in it right now
                              Repeater {
                                model: chRow.members
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 30
                                    spacing: Appearance.spacing.sm
                                    Avatar {
                                        implicitWidth: 24
                                        implicitHeight: 24
                                        name: modelData.name
                                        source: modelData.avatar
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        elide: Text.ElideRight
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnLayer3
                                    }
                                }
                              }
                            }
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: DiscordService.channels.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: Translation.tr("No voice channels in this server")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }
    }
}
