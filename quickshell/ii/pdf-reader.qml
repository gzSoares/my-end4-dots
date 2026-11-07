//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// pdf-reader.qml — a PDF reader in the shell's own look, on Qt's PDF module.
//
// Open it with pdf/mainstream-pdf [file]
// Needs: qt6-webengine, which is what ships QtQuick.Pdf.

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Pdf
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ApplicationWindow {
    id: root
    visible: true
    width: 1000
    height: 760
    minimumWidth: 640
    minimumHeight: 420
    color: Appearance.m3colors.m3background
    title: root.fileName ? root.fileName + " — PDF" : "PDF"

    property string filePath: ""
    readonly property string fileName: root.filePath.replace(/^.*\//, "")
    readonly property bool ready: doc.status === PdfDocument.Ready
    readonly property bool failed: doc.status === PdfDocument.Error && !root.asking
    readonly property bool fullscreen: root.visibility === Window.FullScreen
    // "width", "page" or "" once zoomed by hand. Followed when the window resizes.
    property string fitMode: "width"
    property bool outlineShown: false
    property bool searchShown: false
    property bool asking: false
    property bool wrongPassword: false

    function open(path) {
        if (!path) return;
        root.filePath = path;
        root.asking = false;
        root.wrongPassword = false;
        doc.password = "";
        doc.source = "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
    function applyFit() {
        if (!root.ready) return;
        if (root.fitMode === "") return;
        // Worked out here because the view's own fit ignores the rotation.
        const size = doc.pagePointSize(view.currentPage);
        const sideways = Math.round(((view.pageRotation % 360) + 360) % 360) % 180 !== 0;
        const pageW = sideways ? size.height : size.width;
        const pageH = sideways ? size.width : size.height;
        const byWidth = (view.width - 16) / pageW;
        root.rescale(root.fitMode === "width" ? byWidth : Math.min(byWidth, (view.height - 8) / pageH));
    }
    // Rescaling keeps the scroll position while the pages change size, which lands
    // on another page, so the one being read is gone back to afterwards.
    function rescale(scale) {
        const page = view.currentPage;
        view.renderScale = scale;
        Qt.callLater(root.relayout, page);
    }
    // The page column keeps the width of the last zoom until the view inside
    // PdfMultiPageView lays out again, which left pages off to one side.
    function relayout(page) {
        scrollAnim.stop();
        for (const child of view.children) {
            if (!child.forceLayout) continue;
            child.forceLayout();
            child.contentX = 0;
        }
        view.goToPage(page);
    }
    function turn(degrees) {
        view.pageRotation += degrees;
        fitTimer.restart();
    }
    function setFit(mode) {
        root.fitMode = mode;
        root.applyFit();
    }
    function zoomBy(factor) {
        root.fitMode = "";
        root.rescale(Math.max(0.1, Math.min(10, view.renderScale * factor)));
    }
    function goTo(page) {
        scrollAnim.stop();
        if (root.ready) view.goToPage(Math.max(0, Math.min(doc.pageCount - 1, page)));
    }
    // The scrolling part of the view, which it keeps to itself.
    function scroller() {
        for (const child of view.children)
            if (child.forceLayout) return child;
        return null;
    }
    // Each notch adds to where the page is heading, so turning the wheel again
    // while it glides carries on from there instead of starting over.
    function glide(pixels) {
        const list = root.scroller();
        if (!list) return;
        const base = scrollAnim.running ? scrollAnim.to : list.contentY;
        const end = Math.max(0, list.contentHeight - list.height);
        scrollAnim.target = list;
        scrollAnim.to = Math.max(0, Math.min(end, base + pixels));
        scrollAnim.restart();
    }
    function toggleSearch() {
        root.searchShown = !root.searchShown;
        if (root.searchShown) searchInput.forceActiveFocus();
        else {
            searchInput.text = "";
            view.forceActiveFocus();
        }
    }
    function toggleFullscreen() {
        root.visibility = root.fullscreen ? Window.Windowed : Window.FullScreen;
    }

    Component.onCompleted: {
        // Started on its own, so it has to ask for the shell's colors itself.
        Quickshell.watchFiles = false;
        MaterialThemeLoader.reapplyTheme();
        root.open(Quickshell.env("PDF_FILE") ?? "");
    }
    onClosing: Qt.quit()

    IpcHandler {
        target: "pdf"
        function open(path: string): void {
            root.open(path);
        }
        function page(number: int): void {
            root.goTo(number - 1);
        }
        function fit(mode: string): void {
            root.setFit(mode);
        }
        function zoom(factor: real): void {
            root.zoomBy(factor);
        }
        function search(text: string): void {
            root.searchShown = true;
            searchInput.text = text;
        }
        function nextMatch(): void {
            view.searchForward();
        }
        function outline(shown: bool): void {
            root.outlineShown = shown;
        }
        function turn(degrees: int): void {
            root.turn(degrees);
        }
    }

    PdfDocument {
        id: doc
        onPasswordRequired: {
            root.wrongPassword = root.asking;
            root.asking = true;
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
        }
        onStatusChanged: {
            if (doc.status !== PdfDocument.Ready) return;
            root.asking = false;
            root.fitMode = "width";
            fitTimer.restart();
        }
    }
    NumberAnimation {
        id: scrollAnim
        property: "contentY"
        duration: 380
        easing.type: Easing.OutCubic
    }

    PdfBookmarkModel {
        id: bookmarks
        document: doc
    }

    // The view has its size only after the layout has run.
    Timer {
        id: fitTimer
        interval: 60
        onTriggered: root.applyFit()
    }

    FileDialog {
        id: fileDialog
        title: Translation.tr("Open PDF")
        nameFilters: ["PDF (*.pdf)"]
        currentFolder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
        onAccepted: root.open(decodeURIComponent(selectedFile.toString().replace("file://", "")))
    }

    component BarButton: RippleButton {
        id: barButton
        property string symbol
        property string tip: ""
        implicitWidth: 38
        implicitHeight: 38
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colBackgroundToggled: Appearance.colors.colPrimary
        colBackgroundToggledHover: Appearance.colors.colPrimaryHover
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: barButton.symbol
            iconSize: 22
            fill: barButton.toggled ? 1 : 0
            color: barButton.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
        }
        StyledToolTip {
            text: barButton.tip
            extraVisibleCondition: barButton.tip.length > 0
        }
    }
    component Divider: Rectangle {
        implicitWidth: 1
        implicitHeight: 24
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        color: Appearance.colors.colLayer0Border
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Toolbar ────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 56
            color: Appearance.m3colors.m3surfaceContainer

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 2

                BarButton {
                    symbol: "folder_open"
                    tip: Translation.tr("Open PDF") + " (Ctrl+O)"
                    onClicked: fileDialog.open()
                }
                BarButton {
                    symbol: "toc"
                    tip: Translation.tr("Contents")
                    enabled: root.ready
                    opacity: enabled ? 1 : 0.4
                    toggled: root.outlineShown
                    onClicked: root.outlineShown = !root.outlineShown
                }
                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    text: doc.title || root.fileName
                    elide: Text.ElideMiddle
                    color: Appearance.colors.colOnLayer1
                }
                Rectangle {
                    implicitWidth: 44
                    implicitHeight: 30
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                    StyledTextInput {
                        id: pageInput
                        anchors.fill: parent
                        anchors.margins: 4
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        validator: IntValidator { bottom: 1; top: Math.max(1, doc.pageCount) }
                        onAccepted: {
                            root.goTo(parseInt(text) - 1);
                            view.forceActiveFocus();
                        }
                        Binding on text {
                            when: !pageInput.activeFocus
                            value: root.ready ? String(view.currentPage + 1) : ""
                        }
                    }
                }
                StyledText {
                    Layout.leftMargin: 4
                    text: "/ " + (root.ready ? doc.pageCount : 0)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                Divider {}
                BarButton {
                    symbol: "zoom_out"
                    tip: Translation.tr("Zoom out") + " (Ctrl+-)"
                    onClicked: root.zoomBy(1 / 1.2)
                }
                StyledText {
                    Layout.minimumWidth: 46
                    horizontalAlignment: Text.AlignHCenter
                    text: Math.round(view.renderScale * 100) + "%"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.features: ({ "tnum": 1 })
                    color: Appearance.colors.colOnLayer1
                }
                BarButton {
                    symbol: "zoom_in"
                    tip: Translation.tr("Zoom in") + " (Ctrl++)"
                    onClicked: root.zoomBy(1.2)
                }
                BarButton {
                    symbol: "fit_page_width"
                    tip: Translation.tr("Fit width")
                    toggled: root.fitMode === "width"
                    onClicked: root.setFit("width")
                }
                BarButton {
                    symbol: "fit_screen"
                    tip: Translation.tr("Fit page")
                    toggled: root.fitMode === "page"
                    onClicked: root.setFit("page")
                }
                Divider {}
                BarButton {
                    symbol: "rotate_right"
                    tip: Translation.tr("Rotate")
                    onClicked: root.turn(90)
                }
                BarButton {
                    symbol: "search"
                    tip: Translation.tr("Search") + " (Ctrl+F)"
                    toggled: root.searchShown
                    onClicked: root.toggleSearch()
                }
                BarButton {
                    symbol: root.fullscreen ? "fullscreen_exit" : "fullscreen"
                    tip: Translation.tr("Fullscreen") + " (F11)"
                    onClicked: root.toggleFullscreen()
                }
            }
        }

        // ── Search ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: root.searchShown
            implicitHeight: 46
            color: Appearance.m3colors.m3surfaceContainerLow

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 14
                    rightMargin: 10
                }
                spacing: 8
                MaterialSymbol {
                    text: "search"
                    iconSize: 20
                    color: Appearance.colors.colSubtext
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text.length === 0
                        text: Translation.tr("Search in document")
                        color: Appearance.colors.colSubtext
                    }
                    StyledTextInput {
                        id: searchInput
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        clip: true
                        onTextChanged: view.searchString = text
                        Keys.onReturnPressed: event => {
                            if (event.modifiers & Qt.ShiftModifier) view.searchBack();
                            else view.searchForward();
                        }
                        Keys.onEscapePressed: root.toggleSearch()
                    }
                }
                StyledText {
                    visible: searchInput.text.length > 0
                    text: view.searchModel.count > 0
                        ? (view.searchModel.currentResult + 1) + " / " + view.searchModel.count
                        : Translation.tr("No results")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                BarButton {
                    symbol: "keyboard_arrow_up"
                    tip: Translation.tr("Previous") + " (Shift+Enter)"
                    onClicked: view.searchBack()
                }
                BarButton {
                    symbol: "keyboard_arrow_down"
                    tip: Translation.tr("Next") + " (Enter)"
                    onClicked: view.searchForward()
                }
                BarButton {
                    symbol: "close"
                    onClicked: root.toggleSearch()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ── Contents ───────────────────────────────────────────
            Rectangle {
                visible: root.outlineShown
                Layout.fillHeight: true
                Layout.preferredWidth: 270
                color: Appearance.m3colors.m3surfaceContainerLow

                TreeView {
                    id: outline
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    model: bookmarks
                    delegate: RippleButton {
                        id: outlineRow
                        required property int depth
                        required property string title
                        required property int page
                        required property point location
                        required property real zoom
                        required property bool hasChildren
                        required property bool expanded
                        required property int row
                        implicitWidth: outline.width
                        implicitHeight: 38
                        buttonRadius: Appearance.rounding.small
                        colBackground: page === view.currentPage ? Appearance.colors.colSecondaryContainer : "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        onClicked: {
                            if (outlineRow.hasChildren) outline.toggleExpanded(outlineRow.row);
                            root.goTo(outlineRow.page);
                        }
                        contentItem: RowLayout {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 10 + outlineRow.depth * 14
                                rightMargin: 10
                            }
                            spacing: 6
                            MaterialSymbol {
                                visible: outlineRow.hasChildren
                                text: outlineRow.expanded ? "expand_more" : "chevron_right"
                                iconSize: 18
                                color: Appearance.colors.colSubtext
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: outlineRow.title
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                text: outlineRow.page + 1
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
                StyledText {
                    anchors.centerIn: parent
                    visible: outline.rows === 0
                    text: Translation.tr("No contents")
                    color: Appearance.colors.colSubtext
                }
            }

            // ── Pages ──────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                // The view does not clip: pages would scroll up over the toolbar.
                clip: true

                PdfMultiPageView {
                    id: view
                    anchors.fill: parent
                    document: doc
                    visible: root.ready
                    onWidthChanged: fitTimer.restart()
                    onHeightChanged: fitTimer.restart()
                }

                // On top of the view because it would take the wheel first. It
                // accepts no buttons, so selecting text still reaches the pages.
                MouseArea {
                    anchors.fill: parent
                    visible: root.ready
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        if (wheel.modifiers & Qt.ControlModifier) {
                            root.zoomBy(wheel.angleDelta.y > 0 ? 1.1 : 1 / 1.1);
                            return;
                        }
                        // A touchpad already moves in small, continuous steps. On
                        // Wayland a wheel sends a pixelDelta as well, so the size of
                        // the step is what tells the two apart.
                        const list = root.scroller();
                        if (Math.abs(wheel.angleDelta.y) < 60 && list) {
                            scrollAnim.stop();
                            const end = Math.max(0, list.contentHeight - list.height);
                            list.contentY = Math.max(0, Math.min(end, list.contentY - wheel.pixelDelta.y));
                        } else {
                            root.glide(-wheel.angleDelta.y * 1.5);
                        }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: !root.ready && !root.asking
                    width: Math.min(parent.width - 80, 460)
                    spacing: 10
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.failed ? "error" : "picture_as_pdf"
                        iconSize: 72
                        color: root.failed ? Appearance.m3colors.m3error : Appearance.colors.colPrimary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: root.failed ? Translation.tr("Could not open this PDF") : Translation.tr("Drop a PDF here")
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.larger
                    }
                    RippleButtonWithIcon {
                        Layout.alignment: Qt.AlignHCenter
                        materialIcon: "folder_open"
                        mainText: Translation.tr("Open PDF")
                        colBackground: Appearance.colors.colSecondaryContainer
                        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                        onClicked: fileDialog.open()
                    }
                }

                // Password
                Rectangle {
                    anchors.centerIn: parent
                    visible: root.asking
                    width: 340
                    height: passwordColumn.implicitHeight + 32
                    radius: Appearance.rounding.normal
                    color: Appearance.m3colors.m3surfaceContainer
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border

                    ColumnLayout {
                        id: passwordColumn
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 16
                        }
                        spacing: 10
                        StyledText {
                            text: root.wrongPassword ? Translation.tr("Wrong password, try again") : Translation.tr("This PDF is protected")
                            color: root.wrongPassword ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer2
                            StyledTextInput {
                                id: passwordInput
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    margins: 10
                                }
                                echoMode: TextInput.Password
                                onAccepted: doc.password = text
                            }
                        }
                        RippleButtonWithIcon {
                            Layout.alignment: Qt.AlignRight
                            materialIcon: "lock_open"
                            mainText: Translation.tr("Open")
                            colBackground: Appearance.colors.colSecondaryContainer
                            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                            onClicked: doc.password = passwordInput.text
                        }
                    }
                }

                DropArea {
                    anchors.fill: parent
                    onDropped: drop => {
                        if (!drop.hasUrls) return;
                        root.open(decodeURIComponent(drop.urls[0].toString().replace("file://", "")));
                        drop.accept(Qt.CopyAction);
                    }
                }
            }
        }
    }

    component Key: Shortcut { context: Qt.WindowShortcut }
    Key { sequence: "Ctrl+O"; onActivated: fileDialog.open() }
    Key { sequence: "Ctrl+F"; onActivated: { if (!root.searchShown) root.toggleSearch(); else searchInput.forceActiveFocus(); } }
    Key { sequences: ["Ctrl++", "Ctrl+="]; onActivated: root.zoomBy(1.2) }
    Key { sequence: "Ctrl+-"; onActivated: root.zoomBy(1 / 1.2) }
    Key { sequence: "Ctrl+0"; onActivated: root.setFit("width") }
    Key { sequence: "PgDown"; onActivated: root.goTo(view.currentPage + 1) }
    Key { sequence: "PgUp"; onActivated: root.goTo(view.currentPage - 1) }
    Key { sequence: "Ctrl+Home"; onActivated: root.goTo(0) }
    Key { sequence: "Ctrl+End"; onActivated: root.goTo(doc.pageCount - 1) }
    Key { sequence: "Ctrl+C"; onActivated: view.copySelectionToClipboard() }
    Key { sequence: "Ctrl+A"; onActivated: view.selectAll() }
    Key { sequence: "F11"; onActivated: root.toggleFullscreen() }
    Key {
        sequence: "Esc"
        onActivated: {
            if (root.searchShown) root.toggleSearch();
            else if (root.fullscreen) root.toggleFullscreen();
        }
    }
}
