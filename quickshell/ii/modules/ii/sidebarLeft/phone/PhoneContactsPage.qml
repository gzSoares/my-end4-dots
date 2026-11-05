pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Rectangle {
    id: root
    color: Appearance.colors.colLayer2
    radius: Appearance.rounding.normal

    property bool showBackButton: true
    signal goBack()

    property string selectedContactId: ""
    property string selectedFavId: ""

    // ─── Favorites: order and press-and-hold reordering ───────────────
    // The list follows the order of `favoriteIds`, so what the user sets by
    // dragging is what is stored. A row is picked up after 1 s of holding the
    // left button on it, then follows the pointer while the others make room.
    readonly property var favContacts: {
        const ids = Config.options?.phone?.contacts?.favoriteIds ?? []
        const byId = {}
        for (const c of (PhoneContactsService.contacts || [])) byId[c.id] = c
        const out = []
        for (const id of ids) if (byId[id]) out.push(byId[id])
        return out
    }
    readonly property real favPitch: 66 // row height 60 + spacing 6, rows collapsed
    property string dragFavId: ""
    property int dragFromIndex: -1
    property int dragTargetIndex: -1
    property real dragPointerY: 0
    property real dragGrabOffset: 0
    property bool favDragJustEnded: false

    Timer {
        id: favDragSettle
        interval: 80
        onTriggered: root.favDragJustEnded = false
    }

    function beginFavDrag(id, index, pointerY) {
        root.selectedFavId = ""
        root.dragFavId = id
        root.dragFromIndex = index
        root.dragTargetIndex = index
        root.dragGrabOffset = Math.max(0, Math.min(root.favPitch - 6, pointerY - index * root.favPitch))
        root.dragPointerY = pointerY
    }

    function updateFavDrag(pointerY) {
        if (root.dragFavId === "") return
        root.dragPointerY = pointerY
        const last = root.favContacts.length - 1
        root.dragTargetIndex = Math.max(0, Math.min(last,
            Math.round((pointerY - root.dragGrabOffset) / root.favPitch)))
    }

    function endFavDrag() {
        if (root.dragFavId === "") return
        const from = root.dragFromIndex
        const to = root.dragTargetIndex
        const id = root.dragFavId
        root.dragFavId = ""
        root.dragFromIndex = -1
        root.dragTargetIndex = -1
        root.favDragJustEnded = true
        favDragSettle.restart()
        if (from < 0 || to < 0 || from === to) return
        // Reorder the visible favorites; ids that have no contact on this
        // phone any more keep their place at the end.
        const visible = root.favContacts.map(c => c.id)
        visible.splice(from, 1)
        visible.splice(to, 0, id)
        const rest = (Config.options.phone.contacts.favoriteIds || []).filter(x => visible.indexOf(x) < 0)
        Config.options.phone.contacts.favoriteIds = visible.concat(rest)
    }

    // Sub-page entrance animation
    opacity: 0
    transform: Translate { id: pageTranslate; y: 16 }

    Component.onCompleted: pageEntranceAnim.start()

    SequentialAnimation {
        id: pageEntranceAnim
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.motion.normal
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pageTranslate
                property: "y"
                from: 16
                to: 0
                duration: Appearance.motion.slow
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }
        }
    }

    /** Phones, emails and their actions for one contact. Shared by the
     *  favorites rows and the main list. */
    component ContactDetails: ColumnLayout {
    id: details
    required property var contact
    property bool expanded: false
                            Layout.fillWidth: true
                            Layout.leftMargin: Appearance.spacing.sm
                            Layout.rightMargin: Appearance.spacing.sm
                            visible: opacity > 0
                            opacity: details.expanded ? 1.0 : 0.0
                            spacing: Appearance.spacing.sm

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Appearance.colors.colOutlineVariant
                                opacity: 0.3
                            }

                            // Organization
                            StyledText {
                                Layout.fillWidth: true
                                visible: details.contact.organization !== ""
                                text: Translation.tr("Org: %1").arg(details.contact.organization)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colSubtext
                            }

                            // Phones Section
                            Repeater {
                                model: details.contact.phones || []
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.sm

                                    MaterialSymbol {
                                        text: modelData.type === "mobile" ? "smartphone" : "phone"
                                        iconSize: 18
                                        color: Appearance.colors.colPrimary
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: -2
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: modelData.value
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colOnLayer2
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: modelData.type || "phone"
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            color: Appearance.colors.colSubtext
                                            opacity: 0.8
                                        }
                                    }

                                    // Dial Button
                                    RippleButton {
                                        Layout.preferredHeight: 32
                                        Layout.preferredWidth: 32
                                        buttonRadius: Appearance.rounding.full
                                        colBackground: Appearance.colors.colPrimaryContainer
                                        colBackgroundHover: Appearance.colors.colPrimaryContainerHover

                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "call"
                                            iconSize: 16
                                            color: Appearance.colors.colOnPrimaryContainer
                                        }
                                        onClicked: PhoneContactsService.openDialer(modelData.value)
                                        StyledToolTip {
                                            text: Translation.tr("Open dialer on phone")
                                        }
                                    }

                                    // WhatsApp Button
                                    RippleButton {
                                        Layout.preferredHeight: 32
                                        Layout.preferredWidth: 32
                                        buttonRadius: Appearance.rounding.full
                                        colBackground: Appearance.colors.colSecondaryContainer
                                        colBackgroundHover: Appearance.colors.colSecondaryContainerHover

                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "chat"
                                            iconSize: 16
                                            color: Appearance.colors.colOnSecondaryContainer
                                        }
                                        onClicked: PhoneContactsService.openWhatsApp(modelData.value)
                                        StyledToolTip {
                                            text: Translation.tr("Message on WhatsApp")
                                        }
                                    }

                                    // Copy Button
                                    RippleButton {
                                        Layout.preferredHeight: 32
                                        Layout.preferredWidth: 32
                                        buttonRadius: Appearance.rounding.full
                                        colBackground: Appearance.colors.colLayer4
                                        colBackgroundHover: Appearance.colors.colLayer4Hover

                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "content_copy"
                                            iconSize: 16
                                            color: Appearance.colors.colOnLayer4
                                        }
                                        onClicked: PhoneContactsService.copyPhone(modelData.value)
                                        StyledToolTip {
                                            text: Translation.tr("Copy number")
                                        }
                                    }
                                }
                            }

                            // Message box: what is typed here is waiting in the WhatsApp chat
                            // when it opens, ready to be sent with Enter.
                            RowLayout {
                                id: messageRow
                                Layout.fillWidth: true
                                visible: (details.contact.phones || []).length > 0
                                spacing: 6

                                function send() {
                                    const phones = details.contact.phones || []
                                    if (phones.length === 0) return
                                    const mobile = phones.find(p => p.type === "mobile") || phones[0]
                                    PhoneContactsService.openWhatsAppWithText(mobile.value, messageField.text)
                                    messageField.text = ""
                                }

                                MaterialTextField {
                                    id: messageField
                                    Layout.fillWidth: true
                                    placeholderText: Translation.tr("Message on WhatsApp…")
                                    onAccepted: messageRow.send()
                                }
                                RippleButton {
                                    Layout.preferredHeight: 32
                                    Layout.preferredWidth: 32
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: Appearance.colors.colSecondaryContainer
                                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                                    enabled: messageField.text.trim().length > 0

                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "send"
                                        iconSize: 16
                                        color: Appearance.colors.colOnSecondaryContainer
                                    }
                                    onClicked: messageRow.send()
                                    StyledToolTip {
                                        text: Translation.tr("Open the chat with this message")
                                    }
                                }
                            }

                            // Emails Section
                            Repeater {
                                model: details.contact.emails || []
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.sm

                                    MaterialSymbol {
                                        text: "email"
                                        iconSize: 18
                                        color: Appearance.colors.colPrimary
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: -2
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: modelData.value
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnLayer2
                                        }
                                    }

                                    RippleButton {
                                        Layout.preferredHeight: 32
                                        Layout.preferredWidth: 32
                                        buttonRadius: Appearance.rounding.full
                                        colBackground: Appearance.colors.colLayer4
                                        colBackgroundHover: Appearance.colors.colLayer4Hover

                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "content_copy"
                                            iconSize: 16
                                            color: Appearance.colors.colOnLayer4
                                        }
                                        onClicked: Quickshell.clipboardText = modelData.value
                                        StyledToolTip {
                                            text: Translation.tr("Copy email")
                                        }
                                    }
                                }
                            }
                        }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // ─── Header Bar ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.sm

            RippleButton {
                id: backBtn
                visible: root.showBackButton
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer3
                colBackgroundHover: Appearance.colors.colLayer3Hover

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: 20
                    color: Appearance.colors.colOnLayer3
                }
                onClicked: root.goBack()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Contacts")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer2
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (!PhoneContactsService.ready) return Translation.tr("Connecting…")
                        const shown = String(PhoneContactsService.filteredContacts.length)
                        if (PhoneContactsService.hiddenCount <= 0) return Translation.tr("%1 found").arg(shown)
                        return Translation.tr("%1 found · %2 hidden")
                            .arg(shown).arg(String(PhoneContactsService.hiddenCount))
                    }
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    opacity: 0.8
                }
            }

            RippleButton {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer3
                colBackgroundHover: Appearance.colors.colLayer3Hover

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer3
                }
                onClicked: PhoneContactsService.refresh()
                StyledToolTip {
                    text: Translation.tr("Refresh contacts")
                }
            }
        }

        // ─── Search Field ─────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: Appearance.rounding.full
            color: Appearance.colors.colLayer3

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Appearance.spacing.md
                anchors.rightMargin: Appearance.spacing.md
                spacing: Appearance.spacing.sm

                MaterialSymbol {
                    text: "search"
                    iconSize: 18
                    color: Appearance.colors.colSubtext
                }

                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Search contacts or numbers…")
                    placeholderTextColor: Appearance.colors.colSubtext
                    color: Appearance.colors.colOnLayer3
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    background: null
                    padding: 0
                    verticalAlignment: TextInput.AlignVCenter

                    onTextChanged: PhoneContactsService.setSearchQuery(text)

                    StyledTextContextMenuLoader {
                        id: searchContextMenu
                        targetField: searchInput
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        acceptedButtons: Qt.RightButton
                        onPressed: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                searchInput.forceActiveFocus();
                                searchContextMenu.popup(mouse.x, mouse.y);
                            }
                        }
                    }
                }

                RippleButton {
                    visible: searchInput.text.length > 0
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer3Hover

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 16
                        color: Appearance.colors.colSubtext
                    }
                    onClicked: {
                        searchInput.text = ""
                        PhoneContactsService.setSearchQuery("")
                    }
                }
            }
        }

        // ─── Favorites Section ──────────────────────────────────
        Item {
            id: favoritesRow
            Layout.fillWidth: true
            implicitHeight: favLayout.implicitHeight
            visible: favRepeater.count > 0

            ColumnLayout {
                id: favLayout
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 6

                StyledText {
                    text: Translation.tr("Favorites")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colSubtext
                    opacity: 0.85
                }

                // Favorites as a plain list, each row the same size as the rows
                // of the contacts below it; the tinted background is what marks
                // them as favorites.
                ColumnLayout {
                    id: favRow
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        id: favRepeater
                        model: root.favContacts

                        delegate: Rectangle {
                            id: favCard
                            required property var modelData
                            required property int index
                            readonly property bool isExpanded: root.selectedFavId === modelData.id
                            readonly property bool isDragged: root.dragFavId === modelData.id

                            // Where the row sits relative to its slot: the held
                            // row follows the pointer, the ones it passes make room.
                            property real shiftY: {
                                if (root.dragFavId === "") return 0
                                const pitch = root.favPitch
                                if (favCard.isDragged) {
                                    const raw = root.dragPointerY - root.dragGrabOffset - favCard.index * pitch
                                    return Math.max(-favCard.index * pitch,
                                        Math.min((root.favContacts.length - 1 - favCard.index) * pitch, raw))
                                }
                                if (root.dragFromIndex < favCard.index && favCard.index <= root.dragTargetIndex) return -pitch
                                if (root.dragTargetIndex <= favCard.index && favCard.index < root.dragFromIndex) return pitch
                                return 0
                            }
                            Behavior on shiftY {
                                enabled: !favCard.isDragged
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                            z: favCard.isDragged ? 10 : 0
                            scale: favCard.isDragged ? 1.03 : 1
                            Behavior on scale {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                            transform: Translate { y: favCard.shiftY }
                            Layout.fillWidth: true
                            Layout.preferredHeight: isExpanded ? favCol.implicitHeight + 16 : 60
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colPrimaryContainer
                            clip: true

                            Behavior on Layout.preferredHeight {
                                NumberAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                            }

                            ColumnLayout {
                                id: favCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Appearance.spacing.sm
                                spacing: Appearance.spacing.sm

                                Rectangle {
                                    id: favHeader
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    radius: Appearance.rounding.small
                                    color: favMouse.containsMouse ? Appearance.colors.colPrimaryContainerHover : "transparent"

                                    RowLayout {
                                        z: 1 // above the press-and-hold area, so the star gets its own clicks
                                        anchors.fill: parent
                                        anchors.leftMargin: Appearance.spacing.xs
                                        anchors.rightMargin: Appearance.spacing.xs
                                        spacing: 10

                                        Rectangle {
                                            id: favAvatarBox
                                            Layout.preferredWidth: 38
                                            Layout.preferredHeight: 38
                                            radius: 19
                                            color: Appearance.colors.colPrimary
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                source: modelData.avatarPath ? ("file://" + modelData.avatarPath) : ""
                                                visible: modelData.avatarPath !== ""
                                                fillMode: Image.PreserveAspectCrop

                                                layer.enabled: visible
                                                layer.effect: OpacityMask {
                                                    maskSource: Rectangle {
                                                        width: favAvatarBox.width
                                                        height: favAvatarBox.height
                                                        radius: favAvatarBox.width / 2
                                                    }
                                                }
                                            }

                                            StyledText {
                                                anchors.centerIn: parent
                                                visible: !modelData.avatarPath
                                                text: (modelData.displayName || "?").substring(0, 1).toUpperCase()
                                                font.pixelSize: Appearance.font.pixelSize.normal
                                                font.weight: Font.Bold
                                                color: Appearance.colors.colOnPrimary
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: -2

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: modelData.displayName || Translation.tr("Unknown")
                                                font.pixelSize: Appearance.font.pixelSize.normal
                                                font.weight: Font.DemiBold
                                                color: Appearance.colors.colOnPrimaryContainer
                                                elide: Text.ElideRight
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: (modelData.phones && modelData.phones.length > 0) ? modelData.phones[0].value : ""
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: Appearance.colors.colOnPrimaryContainer
                                                opacity: 0.8
                                                elide: Text.ElideRight
                                            }
                                        }

                                        // Marks the row as a favorite and removes it from them on click
                                        RippleButton {
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            Layout.alignment: Qt.AlignVCenter
                                            buttonRadius: Appearance.rounding.full
                                            colBackground: "transparent"
                                            colBackgroundHover: Appearance.colors.colPrimaryContainerHover

                                            contentItem: MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "star"
                                                iconSize: 18
                                                fill: 1.0
                                                color: Appearance.colors.colSubtext
                                            }
                                            onClicked: PhoneContactsService.toggleFavorite(modelData.id)
                                            StyledToolTip {
                                                text: Translation.tr("Remove from favorites")
                                            }
                                        }

                                        MaterialSymbol {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: "expand_more"
                                            iconSize: 20
                                            color: Appearance.colors.colOnPrimaryContainer
                                            rotation: favCard.isExpanded ? 180 : 0
                                            Behavior on rotation {
                                                NumberAnimation {
                                                    duration: Appearance.animation.elementMoveFast.duration
                                                    easing.type: Appearance.animation.elementMoveFast.type
                                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                                }
                                            }
                                        }
                                    }

                                    // Fills while the button is held, so it is clear that
                                    // something is about to happen after the 3 seconds.
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        height: 2
                                        radius: 1
                                        color: Appearance.colors.colPrimary
                                        visible: favMouse.pressed && root.dragFavId === ""
                                        width: favMouse.pressed ? parent.width : 0
                                        Behavior on width {
                                            NumberAnimation { duration: favMouse.pressed ? 1000 : 0 }
                                        }
                                    }

                                    MouseArea {
                                        id: favMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton
                                        preventStealing: true
                                        pressAndHoldInterval: 1000
                                        cursorShape: favCard.isDragged ? Qt.ClosedHandCursor : Qt.ArrowCursor

                                        onPressAndHold: mouse => {
                                            const p = favMouse.mapToItem(favRow, mouse.x, mouse.y)
                                            root.beginFavDrag(modelData.id, favCard.index, p.y)
                                        }
                                        onPositionChanged: mouse => {
                                            if (favCard.isDragged)
                                                root.updateFavDrag(favMouse.mapToItem(favRow, mouse.x, mouse.y).y)
                                        }
                                        onReleased: root.endFavDrag()
                                        onCanceled: root.endFavDrag()
                                        // Not sent after a press-and-hold, so a drag never also toggles the row.
                                        onClicked: {
                                            if (!root.favDragJustEnded)
                                                root.selectedFavId = (favCard.isExpanded ? "" : modelData.id)
                                        }
                                    }
                                }

                                ContactDetails {
                                    Layout.fillWidth: true
                                    contact: modelData
                                    expanded: favCard.isExpanded
                                }
                            }
                        }
                    }
                }
            }
        }

        // ─── Contacts List ────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledListView {
                id: contactsList
                anchors.fill: parent
                model: PhoneContactsService.filteredContacts
                clip: true
                spacing: 6
                animateAppearance: false // Model is search-filtered: no pop-in on every keystroke

                delegate: Rectangle {
                    id: contactItem
                    required property var modelData
                    required property int index

                    width: contactsList.width
                    height: isExpanded ? expandedCol.implicitHeight + 16 : 60
                    radius: Appearance.rounding.normal
                    color: isExpanded ? Appearance.colors.colLayer3 : Appearance.colors.colLayer2

                    readonly property bool isExpanded: root.selectedContactId === modelData.id

                    Behavior on height {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                        }
                    }

                    ColumnLayout {
                        id: expandedCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Appearance.spacing.sm
                        spacing: Appearance.spacing.sm

                        // Collapsed row header
                        RippleButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            buttonRadius: Appearance.rounding.small
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer3Hover

                            contentItem: RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Appearance.spacing.xs
                                anchors.rightMargin: Appearance.spacing.xs
                                spacing: 10

                                // Circular Avatar
                                Rectangle {
                                    id: listAvatarBox
                                    Layout.preferredWidth: 38
                                    Layout.preferredHeight: 38
                                    radius: 19
                                    color: Appearance.colors.colPrimaryContainer
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.avatarPath ? ("file://" + modelData.avatarPath) : ""
                                        visible: modelData.avatarPath !== ""
                                        fillMode: Image.PreserveAspectCrop

                                        layer.enabled: visible
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: listAvatarBox.width
                                                height: listAvatarBox.height
                                                radius: listAvatarBox.width / 2
                                            }
                                        }
                                    }

                                    StyledText {
                                        anchors.centerIn: parent
                                        visible: !modelData.avatarPath
                                        text: (modelData.displayName || "?").substring(0, 1).toUpperCase()
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        font.weight: Font.Bold
                                        color: Appearance.colors.colOnPrimaryContainer
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: -2

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.displayName || Translation.tr("Unknown Contact")
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        font.weight: Font.DemiBold
                                        color: Appearance.colors.colOnLayer2
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: {
                                            if (modelData.organization) return modelData.organization
                                            if (modelData.phones && modelData.phones.length > 0) return modelData.phones[0].value
                                            if (modelData.emails && modelData.emails.length > 0) return modelData.emails[0].value
                                            return ""
                                        }
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                        opacity: 0.85
                                        elide: Text.ElideRight
                                    }
                                }

                                // Favorite Star Button
                                RippleButton {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colLayer3Hover

                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: PhoneContactsService.isFavorite(modelData.id) ? "star" : "star_outline"
                                        iconSize: 18
                                        fill: PhoneContactsService.isFavorite(modelData.id) ? 1.0 : 0.0
                                        color: PhoneContactsService.isFavorite(modelData.id)
                                               ? Appearance.colors.colPrimary
                                               : Appearance.colors.colSubtext
                                        animateChange: true
                                    }
                                    onClicked: PhoneContactsService.toggleFavorite(modelData.id)
                                    StyledToolTip {
                                        text: PhoneContactsService.isFavorite(modelData.id)
                                              ? Translation.tr("Remove from favorites")
                                              : Translation.tr("Add to favorites")
                                    }
                                }

                                // Chevron with smooth 180° rotation animation
                                MaterialSymbol {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "expand_more"
                                    iconSize: 20
                                    color: Appearance.colors.colSubtext

                                    transform: Rotation {
                                        origin.x: 10
                                        origin.y: 10
                                        angle: contactItem.isExpanded ? 180 : 0
                                        Behavior on angle {
                                            NumberAnimation {
                                                duration: Appearance.animation.elementMoveFast.duration
                                                easing.type: Appearance.animation.elementMoveFast.type
                                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                            }
                                        }
                                    }
                                }
                            }

                            onClicked: {
                                root.selectedContactId = (contactItem.isExpanded ? "" : modelData.id)
                            }
                        }

                        // Expanded Contact Details
                        ContactDetails {
                            Layout.fillWidth: true
                            contact: modelData
                            expanded: contactItem.isExpanded
                        }
                    }
                }
            }

            // Empty State overlay if list is empty
            ColumnLayout {
                anchors.centerIn: parent
                spacing: Appearance.spacing.md
                visible: PhoneContactsService.filteredContacts.length === 0

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: PhoneContactsService.ready ? "person_search" : "sync_problem"
                    iconSize: 48
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: PhoneContactsService.ready
                          ? (searchInput.text.length > 0 ? Translation.tr("No contacts matching search") : Translation.tr("No contacts found"))
                          : Translation.tr("Enable Contact Sync in KDE Connect on your phone")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colSubtext
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
