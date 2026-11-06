import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

MouseArea {
    id: root

    // ───────────────────────── State ─────────────────────────
    property bool monitorIsFocused: true
    // "carousel" (coverflow) or "grid"
    property string viewMode: "carousel"
    readonly property bool carouselMode: root.viewMode === "carousel"
    readonly property real cardAspectRatio: 16 / 9
    // Single source of truth for the focused item; both views follow it
    property int focusIndex: 0
    // Bumped when the folder model changes so bindings that call get() re-evaluate
    property int modelRevision: 0

    // Live preview: while browsing the carousel, the focused wallpaper is applied
    // to the system after a short pause. Esc / close reverts, Enter keeps it.
    property bool livePreview: true
    // How long the focus has to rest on a card before it is applied (ms)
    property int previewDelay: 900
    property bool previewArmed: false      // only true after the user moved the focus
    property bool committed: false         // the user confirmed a choice
    property string originalPath: ""       // wallpaper in use when the picker opened
    property string lastPreviewedPath: ""  // last one this picker applied
    property int pendingPreviews: 0        // applications still being processed

    property bool useDarkMode: Appearance.m3colors.darkmode
    // The monitor this pick is for, or empty for the main wallpaper. The
    // highlighted card is what that screen shows now.
    readonly property string monitorTarget: GlobalStates.wallpaperSelectorMonitor
    readonly property string currentPath: (root.monitorTarget !== "" ? MonitorWallpapers.pathFor(root.monitorTarget) : "")
        || Config.options.background.wallpaperPath

    readonly property int itemCount: Wallpapers.folderModel.count
    readonly property string focusedPath: {
        root.modelRevision;
        return root.itemCount > 0 ? (Wallpapers.folderModel.get(root.focusIndex, "filePath") ?? "") : "";
    }
    readonly property string focusedName: {
        root.modelRevision;
        return root.itemCount > 0 ? (Wallpapers.folderModel.get(root.focusIndex, "fileName") ?? "") : "";
    }
    readonly property bool focusedIsDir: {
        root.modelRevision;
        return root.itemCount > 0 && Wallpapers.folderModel.get(root.focusIndex, "fileIsDir") === true;
    }
    readonly property string ambientPath: root.focusedIsDir ? "" : root.focusedPath

    // Card size follows the stage. The thumbnail bucket is derived from it, and
    // the bulk generator below uses the very same numbers.
    readonly property real cardHeight: Math.max(96, Math.min(stage.height * 0.8, stage.width * 0.56 / root.cardAspectRatio))
    readonly property real cardWidth: root.cardHeight * root.cardAspectRatio
    onCardWidthChanged: thumbnailTimer.restart()

    readonly property var quickDirs: [
        { icon: "wallpaper", name: "Wallpapers", path: `${Directories.pictures}/Wallpapers` },
        { icon: "image", name: "Pictures", path: Directories.pictures },
        { icon: "home", name: "Home", path: Directories.home },
        { icon: "docs", name: "Documents", path: Directories.documents },
        { icon: "download", name: "Downloads", path: Directories.downloads },
        { icon: "movie", name: "Videos", path: Directories.videos },
        ...(Config.options.policies.weeb === 1 ? [
            { icon: "favorite", name: "Homework", path: `${Directories.pictures}/homework` }
        ] : [])
    ]

    // ───────────────────────── Logic ─────────────────────────
    function updateThumbnails() {
        if (root.cardWidth <= 0) return;
        Wallpapers.generateThumbnail(Images.thumbnailSizeNameForDimensions(root.cardWidth, root.cardHeight));
    }

    // Moves focus to the wallpaper in use, or to the first item
    function focusCurrent() {
        // Programmatic focus (opening, changing folder, searching) never previews
        root.previewArmed = false;
        previewTimer.stop();
        let target = 0;
        for (let i = 0; i < root.itemCount; i++) {
            if (Wallpapers.folderModel.get(i, "filePath") === root.currentPath) {
                target = i;
                break;
            }
        }
        root.focusIndex = target;
        gridLoader.item?.positionAt(target);
    }

    function moveSelection(delta) {
        if (root.itemCount <= 0) return;
        root.previewArmed = true;
        root.focusIndex = Math.max(0, Math.min(root.itemCount - 1, root.focusIndex + delta));
        gridLoader.item?.positionAt(root.focusIndex);
    }

    function activateIndex(index) {
        if (index < 0 || index >= root.itemCount) return;
        const path = Wallpapers.folderModel.get(index, "filePath");
        const isDir = Wallpapers.folderModel.get(index, "fileIsDir") === true;
        // The live preview only swapped the picture. Confirming runs the full
        // apply, so the colors change a single time, here.
        if (!isDir) root.committed = true;
        root.selectWallpaperPath(path);
    }

    // The preview is only a value the background layer reads (GlobalStates.wallpaperPreviewPath):
    // no script, no config write or reload, no matugen, no hyprctl. The real apply runs
    // once, when the user confirms.
    // false: the preview plays the configured transition (the crossfade, ideally).
    // true: a hard cut, which is the lightest option.
    property bool previewInstant: true
    function showPreview(path) {
        if (root.previewInstant) GlobalStates.wallpaperPreviewUntil = Date.now() + 1500;
        GlobalStates.wallpaperPreviewPath = path;
    }
    function clearPreview() {
        if (root.previewInstant) GlobalStates.wallpaperPreviewUntil = Date.now() + 1500;
        GlobalStates.wallpaperPreviewPath = "";
    }

    // Shows the focused wallpaper on the desktop without closing the picker
    function applyPreview() {
        if (!root.livePreview || !root.carouselMode || !root.previewArmed || root.committed) return;
        // A picture for a single monitor is stored through another path
        // (and closes the picker when it lands), so previews are for the main wallpaper.
        if (root.monitorTarget !== "") return;
        if (root.focusedIsDir || root.focusedPath === "") return;
        const target = root.focusedPath;
        // Videos are drawn by mpvpaper, not by the background layer
        if (Wallpapers.isVideoFile(target.toLowerCase()) || Wallpapers.isVideoFile(root.originalPath.toLowerCase())) return;
        if (target === (root.lastPreviewedPath || root.originalPath)) return;
        // One at a time, so a transition is never started on top of another
        if (root.pendingPreviews > 0) {
            previewTimer.restart();
            return;
        }
        root.pendingPreviews = 1;
        pendingGuard.restart();
        root.lastPreviewedPath = target;
        root.showPreview(target);
    }

    // Wallpapers.changed / MonitorWallpapers.assigned: a real pick landed (ours or
    // from elsewhere, like the random shortcut), so there is nothing to revert.
    function handleApplied() {
        root.committed = true;
        GlobalStates.wallpaperSelectorOpen = false;
    }

    function handleFilePasting(event) {
        const currentClipboardEntry = Cliphist.entries[0];
        if (/^\d+\tfile:\/\/\S+/.test(currentClipboardEntry)) {
            const url = StringUtils.cleanCliphistEntry(currentClipboardEntry);
            Wallpapers.setDirectory(FileUtils.trimFileProtocol(decodeURIComponent(url)));
            event.accepted = true;
        } else {
            event.accepted = false; // No image, let text pasting proceed
        }
    }

    // Hands the choice to the system dialog. For one monitor the file it
    // returns is stored for that screen; otherwise the wallpaper script
    // takes it as the main wallpaper.
    function openSystemPicker() {
        if (root.monitorTarget !== "") MonitorWallpapers.pickWithSystemDialog(root.monitorTarget);
        else Wallpapers.openFallbackPicker(root.useDarkMode);
        GlobalStates.wallpaperSelectorOpen = false;
    }

    function selectWallpaperPath(filePath) {
        if (filePath && filePath.length > 0) {
            Wallpapers.select(filePath, root.useDarkMode, root.monitorTarget);
            filterField.text = "";
        }
    }

    function toggleViewMode() {
        root.viewMode = root.carouselMode ? "grid" : "carousel";
    }

    Timer {
        id: thumbnailTimer
        interval: 150
        onTriggered: root.updateThumbnails()
    }
    onFocusIndexChanged: if (root.previewArmed) previewTimer.restart()
    Timer {
        id: previewTimer
        interval: root.previewDelay
        onTriggered: root.applyPreview()
    }
    // Gap left between two previews, so a decode never overlaps the next one
    // (and the full-resolution decode in the carousel waits for it too)
    Timer {
        id: pendingGuard
        // A crossfade takes about 700 ms plus the decode: leave room so two never overlap
        interval: root.previewInstant ? 600 : 1300
        onTriggered: root.pendingPreviews = 0
    }
    Timer {
        id: focusTimer
        interval: 80
        onTriggered: root.focusCurrent()
    }

    Component.onDestruction: {
        if (GlobalStates.wallpaperPreviewPath === "") return;
        // Confirmed: the full apply is still running, so the preview keeps being drawn
        // until the config catches up (the background layer lets go of it then).
        // Closed any other way: drop the preview and the original is back.
        if (root.committed) GlobalStates.releaseWallpaperPreview();
        else root.clearPreview();
    }

    Component.onCompleted: {
        root.originalPath = root.currentPath;
        thumbnailTimer.restart();
        focusTimer.restart();
        panel.forceActiveFocus();
    }

    Connections {
        target: Wallpapers
        function onDirectoryChanged() {
            root.previewArmed = false;
            previewTimer.stop();
            root.modelRevision++;
            thumbnailTimer.restart();
            focusTimer.restart();
        }
    }
    Connections {
        target: Wallpapers.folderModel
        function onCountChanged() {
            root.modelRevision++;
            focusTimer.restart();
        }
    }

    // ───────────────────────── Input ─────────────────────────
    acceptedButtons: Qt.BackButton | Qt.ForwardButton
    onPressed: event => {
        if (event.button === Qt.BackButton) {
            Wallpapers.navigateBack();
        } else if (event.button === Qt.ForwardButton) {
            Wallpapers.navigateForward();
        }
    }

    Keys.onPressed: event => {
        const columns = gridLoader.item?.columns ?? 4;
        if (event.key === Qt.Key_Escape) {
            GlobalStates.wallpaperSelectorOpen = false;
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) { // Intercept Ctrl+V to handle "paste to go to" in pickers
            root.handleFilePasting(event);
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Up) {
            Wallpapers.navigateUp();
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Left) {
            Wallpapers.navigateBack();
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Right) {
            Wallpapers.navigateForward();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            root.moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            root.moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            root.moveSelection(root.carouselMode ? -1 : -columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            root.moveSelection(root.carouselMode ? 1 : columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            root.moveSelection(root.carouselMode ? -5 : -columns * 2);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            root.moveSelection(root.carouselMode ? 5 : columns * 2);
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            root.moveSelection(-root.itemCount);
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.moveSelection(root.itemCount);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activateIndex(root.focusIndex);
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab) {
            root.toggleViewMode();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace) {
            if (filterField.text.length > 0) {
                filterField.text = filterField.text.substring(0, filterField.text.length - 1);
            }
            filterField.forceActiveFocus();
            event.accepted = true;
        } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_L) {
            addressBar.focusBreadcrumb();
            event.accepted = true;
        } else if (event.key === Qt.Key_Slash) {
            filterField.forceActiveFocus();
            event.accepted = true;
        } else {
            if (event.text.length > 0) {
                filterField.text += event.text;
                filterField.cursorPosition = filterField.text.length;
                filterField.forceActiveFocus();
            }
            event.accepted = true;
        }
    }

    // ───────────────────────── Layout ─────────────────────────
    StyledRectangularShadow {
        target: panel
    }

    Rectangle {
        id: panel
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        focus: true
        color: Appearance.colors.colLayer0
        radius: RoundedCorners.on ? Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1 : 0

        // Swallows left/right clicks so they never fall through to the scrim
        // (which closes the picker). Back/forward still reach the root.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
        }

        // Ambient backdrop, clipped to the panel's rounded shape
        Item {
            id: ambientClip
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: ambientClip.width
                    height: ambientClip.height
                    radius: panel.radius
                }
            }

            WallpaperAmbientLayer {
                anchors.fill: parent
                path: root.ambientPath
                sizeWidth: root.cardWidth
                sizeHeight: root.cardHeight
            }
            // Keeps text readable and the panel on-theme
            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.2)
            }
        }

        ColumnLayout {
            id: contentColumn
            anchors {
                fill: parent
                margins: Appearance.spacing.lg
            }
            spacing: Appearance.spacing.md

            // ── Header: title, address bar, view toggle ──
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.md

                StyledText {
                    text: root.monitorTarget !== "" ? Translation.tr("This screen only") : Translation.tr("Pick a wallpaper")
                    color: Appearance.colors.colOnLayer0
                    font {
                        pixelSize: Appearance.font.pixelSize.larger
                        weight: Font.Medium
                    }
                }

                AddressBar {
                    id: addressBar
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    directory: Wallpapers.effectiveDirectory
                    onNavigateToDirectory: path => {
                        Wallpapers.setDirectory(path.length == 0 ? "/" : path);
                    }
                    radius: Math.min(height / 2, Appearance.rounding.full)
                }

                Rectangle {
                    implicitWidth: viewToggleRow.implicitWidth + 8
                    implicitHeight: 40
                    radius: Math.min(height / 2, Appearance.rounding.full)
                    color: Appearance.colors.colLayer1

                    Row {
                        id: viewToggleRow
                        anchors.centerIn: parent
                        spacing: 2

                        Repeater {
                            model: [
                                { icon: "view_carousel", mode: "carousel", tip: Translation.tr("Carousel") },
                                { icon: "grid_view", mode: "grid", tip: Translation.tr("Grid") }
                            ]
                            delegate: RippleButton {
                                id: viewButton
                                required property var modelData
                                implicitWidth: 36
                                implicitHeight: 32
                                buttonRadius: Math.min(height / 2, Appearance.rounding.full)
                                toggled: root.viewMode === viewButton.modelData.mode
                                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                                colRippleToggled: Appearance.colors.colSecondaryContainerActive
                                onClicked: root.viewMode = viewButton.modelData.mode

                                contentItem: MaterialSymbol {
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    iconSize: Appearance.font.pixelSize.larger
                                    text: viewButton.modelData.icon
                                    fill: viewButton.toggled ? 1 : 0
                                    color: viewButton.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                }
                                StyledToolTip {
                                    text: viewButton.modelData.tip + "  (Tab)"
                                }
                            }
                        }
                    }
                }
            }

            // Picking for one monitor leaves the colors alone, which is easy
            // to miss in a picker that otherwise looks like the usual one.
            NoticeBox {
                visible: root.monitorTarget !== ""
                Layout.fillWidth: true
                radius: Math.max(0, panel.radius - 12)
                materialIcon: "desktop_windows"
                text: Translation.tr("Only this screen changes. Your colors stay with the main wallpaper.")
            }

            // ── Folder chips ──
            ListView {
                id: chips
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                orientation: ListView.Horizontal
                spacing: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.quickDirs

                delegate: RippleButton {
                    id: chip
                    required property var modelData
                    implicitHeight: 36
                    implicitWidth: chipContent.implicitWidth + 28
                    buttonRadius: Math.min(height / 2, Appearance.rounding.full)
                    toggled: Wallpapers.directory === Qt.resolvedUrl(chip.modelData.path)
                    colBackgroundToggled: Appearance.colors.colSecondaryContainer
                    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                    colRippleToggled: Appearance.colors.colSecondaryContainerActive
                    onClicked: Wallpapers.setDirectory(chip.modelData.path)

                    contentItem: RowLayout {
                        id: chipContent
                        spacing: 6
                        MaterialSymbol {
                            color: chip.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                            iconSize: Appearance.font.pixelSize.larger
                            text: chip.modelData.icon
                            fill: chip.toggled ? 1 : 0
                        }
                        StyledText {
                            color: chip.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                            text: chip.modelData.name
                        }
                    }
                }
            }

            // ── Stage: carousel or grid ──
            Item {
                id: stage
                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledIndeterminateProgressBar {
                    id: indeterminateProgressBar
                    visible: Wallpapers.thumbnailGenerationRunning && value == 0
                    z: 10
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        leftMargin: Appearance.spacing.xs
                        rightMargin: Appearance.spacing.xs
                    }
                }

                StyledProgressBar {
                    visible: Wallpapers.thumbnailGenerationRunning && value > 0
                    value: Wallpapers.thumbnailGenerationProgress
                    z: 10
                    anchors.fill: indeterminateProgressBar
                }

                Loader {
                    id: carouselLoader
                    anchors.fill: parent
                    active: root.carouselMode && root.itemCount > 0
                    sourceComponent: carouselComponent
                }

                Loader {
                    id: gridLoader
                    anchors.fill: parent
                    active: !root.carouselMode && root.itemCount > 0
                    sourceComponent: gridComponent
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.itemCount === 0
                    spacing: Appearance.spacing.sm

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "image_not_supported"
                        iconSize: 48
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("Nothing to show here")
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            // ── Footer: info, search, actions ──
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.md

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.focusedName
                        elide: Text.ElideMiddle
                        color: Appearance.colors.colOnLayer0
                        font {
                            pixelSize: Appearance.font.pixelSize.normal
                            weight: Font.Medium
                        }
                    }
                    StyledText {
                        text: root.itemCount > 0 ? `${root.focusIndex + 1} / ${root.itemCount}` : ""
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }

                RippleButton {
                    id: applyButton
                    visible: root.itemCount > 0
                    implicitHeight: 40
                    implicitWidth: applyContent.implicitWidth + 32
                    buttonRadius: Math.min(height / 2, Appearance.rounding.full)
                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimaryHover
                    colRipple: Appearance.colors.colPrimaryActive
                    onClicked: root.activateIndex(root.focusIndex)

                    contentItem: RowLayout {
                        id: applyContent
                        spacing: 6
                        MaterialSymbol {
                            text: root.focusedIsDir ? "folder_open" : "check"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnPrimary
                        }
                        StyledText {
                            text: root.focusedIsDir ? Translation.tr("Open") : Translation.tr("Apply")
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }

                Row {
                    spacing: 6

                    Toolbar {
                        IconToolbarButton {
                            implicitWidth: height
                            onClicked: root.openSystemPicker()
                            altAction: () => {
                                root.openSystemPicker();
                                Config.options.wallpaperSelector.useSystemFileDialog = true;
                            }
                            text: "open_in_new"
                            StyledToolTip {
                                text: Translation.tr("Use the system file picker instead\nRight-click to make this the default behavior")
                            }
                        }

                        IconToolbarButton {
                            implicitWidth: height
                            onClicked: {
                                root.committed = true;
                                Wallpapers.randomFromCurrentFolder(Appearance.m3colors.darkmode, root.monitorTarget);
                            }
                            text: "ifl"
                            StyledToolTip {
                                text: Translation.tr("Pick random from this folder")
                            }
                        }

                        IconToolbarButton {
                            visible: root.carouselMode && root.monitorTarget === ""
                            implicitWidth: height
                            onClicked: root.livePreview = !root.livePreview
                            text: root.livePreview ? "visibility" : "visibility_off"
                            StyledToolTip {
                                text: Translation.tr("Live preview: show the wallpaper on the desktop while browsing\nColors only change when you confirm (Enter). Esc reverts")
                            }
                        }

                        IconToolbarButton {
                            // Light or dark only matters to the colors,
                            // which a picture for one screen never sets.
                            visible: root.monitorTarget === ""
                            implicitWidth: height
                            onClicked: root.useDarkMode = !root.useDarkMode
                            text: root.useDarkMode ? "dark_mode" : "light_mode"
                            StyledToolTip {
                                text: Translation.tr("Click to toggle light/dark mode\n(applied when wallpaper is chosen)")
                            }
                        }

                        ToolbarTextField {
                            id: filterField
                            placeholderText: focus ? Translation.tr("Search wallpapers") : Translation.tr("Hit \"/\" to search")

                            // Style
                            clip: true
                            font.pixelSize: Appearance.font.pixelSize.small

                            // Search
                            onTextChanged: {
                                Wallpapers.searchQuery = text;
                            }

                            Keys.onPressed: event => {
                                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) { // Intercept Ctrl+V to handle "paste to go to" in pickers
                                    root.handleFilePasting(event);
                                    return;
                                } else if (text.length !== 0) {
                                    // No filtering, just navigate
                                    const columns = gridLoader.item?.columns ?? 4;
                                    if (event.key === Qt.Key_Down) {
                                        root.moveSelection(root.carouselMode ? 1 : columns);
                                        event.accepted = true;
                                        return;
                                    }
                                    if (event.key === Qt.Key_Up) {
                                        root.moveSelection(root.carouselMode ? -1 : -columns);
                                        event.accepted = true;
                                        return;
                                    }
                                }
                                event.accepted = false;
                            }
                        }
                    }

                    ToolbarPairedFab {
                        iconText: "close"
                        onClicked: GlobalStates.wallpaperSelectorOpen = false;
                        StyledToolTip {
                            text: Translation.tr("Cancel wallpaper selection")
                        }
                    }
                }
            }
        }

        // Border on top of the ambient backdrop
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: panel.radius
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
        }
    }

    // ───────────────────────── Carousel ─────────────────────────
    Component {
        id: carouselComponent

        ListView {
            id: carousel
            property bool animated: false

            orientation: ListView.Horizontal
            model: Wallpapers.folderModel
            // Slight overlap; the side cards are scaled down anyway
            spacing: -root.cardWidth * 0.05
            currentIndex: root.focusIndex
            onCurrentIndexChanged: {
                if (currentIndex >= 0 && currentIndex !== root.focusIndex) {
                    // Dragging / flicking by hand counts as the user browsing
                    if (carousel.moving) root.previewArmed = true;
                    root.focusIndex = currentIndex;
                }
            }

            // Whatever is centered is the current item
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: width / 2 - root.cardWidth / 2
            preferredHighlightEnd: width / 2 + root.cardWidth / 2
            highlightMoveDuration: carousel.animated ? 380 : 0
            snapMode: ListView.SnapToItem
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: root.cardWidth
            clip: true

            // No animation on open, only once the view has settled
            Component.onCompleted: Qt.callLater(() => carousel.animated = true)

            // (No layer/mask over the whole list: re-rendering it every frame
            // while scrolling was costly. The cards fade out by distance instead.)

            // Mouse wheel / touchpad scrolling steps through the cards
            WheelHandler {
                property real accumulated: 0
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? event.angleDelta.x : event.angleDelta.y;
                    accumulated += delta;
                    const steps = Math.trunc(accumulated / 120);
                    if (steps !== 0) {
                        root.moveSelection(-steps);
                        accumulated -= steps * 120;
                    }
                }
            }

            delegate: Item {
                id: slot
                required property var modelData
                required property int index

                // 0 at the center, ±1 for the neighbors
                readonly property real offset: ((slot.x + slot.width / 2) - (carousel.contentX + carousel.width / 2)) / (slot.width + carousel.spacing)
                readonly property real distance: Math.abs(slot.offset)

                width: root.cardWidth
                height: carousel.height
                z: 100 - slot.distance * 10

                WallpaperDirectoryItem {
                    id: card
                    anchors.centerIn: parent
                    width: root.cardWidth
                    height: root.cardHeight
                    fileModelData: slot.modelData
                    thumbWidth: root.cardWidth
                    thumbHeight: root.cardHeight
                    cornerRadius: Appearance.rounding.large
                    highlighted: slot.index === carousel.currentIndex
                    applied: fileModelData.filePath === root.currentPath
                    // Don't decode a big image while the system is busy applying a wallpaper
                    allowFullResolution: root.pendingPreviews === 0

                    scale: 1 - Math.min(slot.distance, 2.5) * 0.13
                    opacity: 1 - Math.min(slot.distance, 3) * 0.25
                    transform: Rotation {
                        origin.x: card.width / 2
                        origin.y: card.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: -Math.max(-1.5, Math.min(1.5, slot.offset)) * 14
                    }

                    // First click brings a side card to the center,
                    // clicking the centered card applies it.
                    onActivated: {
                        if (slot.index === carousel.currentIndex) root.activateIndex(slot.index);
                        else {
                            root.previewArmed = true;
                            root.focusIndex = slot.index;
                        }
                    }
                }
            }
        }
    }

    // ───────────────────────── Grid ─────────────────────────
    Component {
        id: gridComponent

        GridView {
            id: grid
            readonly property int columns: root.width < 1000 ? 3 : 4

            function positionAt(index) {
                grid.positionViewAtIndex(index, GridView.Contain);
            }

            model: Wallpapers.folderModel
            cellWidth: width / grid.columns
            cellHeight: cellWidth / root.cardAspectRatio
            currentIndex: root.focusIndex
            onCurrentIndexChanged: {
                if (currentIndex >= 0 && currentIndex !== root.focusIndex)
                    root.focusIndex = currentIndex;
            }

            interactive: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: cellHeight * 2
            ScrollBar.vertical: StyledScrollBar {}

            Component.onCompleted: grid.positionViewAtIndex(root.focusIndex, GridView.Center)

            delegate: Item {
                id: gridCell
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight

                WallpaperDirectoryItem {
                    anchors.fill: parent
                    anchors.margins: 6
                    fileModelData: gridCell.modelData
                    thumbWidth: root.cardWidth
                    thumbHeight: root.cardHeight
                    cornerRadius: Appearance.rounding.normal
                    highlighted: gridCell.index === root.focusIndex
                    applied: fileModelData.filePath === root.currentPath
                    // The grid is small, so skip the original-resolution crossfade
                    loadFullResolution: false

                    onEntered: root.focusIndex = gridCell.index
                    onActivated: root.activateIndex(gridCell.index)
                }
            }
        }
    }

    Connections {
        target: GlobalStates
        function onWallpaperSelectorOpenChanged() {
            if (GlobalStates.wallpaperSelectorOpen && root.monitorIsFocused) {
                filterField.forceActiveFocus();
            }
        }
    }

    Connections {
        target: Wallpapers
        function onChanged() {
            root.handleApplied();
        }
    }

    // Wallpapers.changed follows only a main wallpaper pick, so a picture
    // for one monitor closes the picker here.
    Connections {
        target: MonitorWallpapers
        function onAssigned(monitorName) {
            if (monitorName === root.monitorTarget) root.handleApplied();
        }
    }
}
