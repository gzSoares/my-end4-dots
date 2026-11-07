//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
// The Background page previews the wallpaper transitions; pages load by path,
// so the module has to be named here for the scanner to find it.
import qs.modules.ii.background

ApplicationWindow {
    id: root
    property string firstRunFilePath: CF.FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property real contentPadding: 8
    property bool showNextTime: false
    property var pages: [
        {
            group: Translation.tr("Start"),
            name: Translation.tr("Quick"),
            icon: "instant_mix",
            description: Translation.tr("Wallpaper, colors and the most used options"),
            component: "modules/settings/QuickConfig.qml"
        },
        {
            group: Translation.tr("Connections"),
            name: "Wi-Fi",
            icon: "wifi",
            description: Translation.tr("Wireless networks and connection details"),
            component: "modules/settings/WifiConfig.qml"
        },
        {
            group: Translation.tr("Connections"),
            name: Translation.tr("Bluetooth"),
            icon: "bluetooth",
            description: Translation.tr("Pair and manage Bluetooth devices"),
            component: "modules/settings/BluetoothConfig.qml"
        },
        {
            group: Translation.tr("Personalize"),
            name: Translation.tr("Background"),
            icon: "texture",
            description: Translation.tr("Wallpaper behavior and desktop widgets"),
            component: "modules/settings/BackgroundConfig.qml"
        },
        {
            group: Translation.tr("Personalize"),
            name: Translation.tr("Decorations"),
            icon: "palette",
            description: Translation.tr("Window borders, blur, shadows and animations"),
            component: "modules/settings/DecorationsConfig.qml"
        },
        {
            group: Translation.tr("Personalize"),
            name: Translation.tr("Bar"),
            icon: "toast",
            iconRotation: 180,
            description: Translation.tr("Layout, style and modules of the top bar"),
            component: "modules/settings/BarConfig.qml"
        },
        {
            group: Translation.tr("Personalize"),
            name: Translation.tr("Dock"),
            icon: "toast",
            // The bar's glyph the other way up, so the two entries are one
            // shape distinguished only by which edge it sits on.
            description: Translation.tr("Position, style and pinned apps of the dock"),
            component: "modules/settings/DockConfig.qml"
        },
        {
            group: Translation.tr("Personalize"),
            name: Translation.tr("Interface"),
            icon: "bottom_app_bar",
            description: Translation.tr("Sidebars, notifications, overview and lock screen"),
            component: "modules/settings/InterfaceConfig.qml"
        },
        {
            group: Translation.tr("Personalize"),
            name: Translation.tr("Layouts"),
            icon: "view_quilt",
            description: Translation.tr("How windows are arranged on the screen"),
            component: "modules/settings/LayoutsConfig.qml"
        },
        {
            group: Translation.tr("Devices"),
            name: Translation.tr("Display"),
            icon: "monitor",
            // The Display page is by far the heaviest entry in this settings
            // app — multiple monitors × per-monitor sections × ~400 widgets
            // each. Synchronous load froze the page-swap animation while
            // every monitor section materialised. Loader.asynchronous offloads
            // the page's QML compilation + initial binding pass to a worker
            // thread so the swap stays smooth. Only this page is opted-in;
            // other pages stay sync because their layouts don't tolerate
            // having a 0-width parent during the brief async-loading window.
            asynchronous: true,
            description: Translation.tr("Resolution, scale, arrangement and night light"),
            component: "modules/settings/DisplayConfig.qml"
        },
        {
            group: Translation.tr("Devices"),
            name: Translation.tr("Keyboard"),
            icon: "keyboard",
            description: Translation.tr("Layouts, input sources and shortcuts"),
            component: "modules/settings/KeyboardConfig.qml"
        },
        {
            group: Translation.tr("Devices"),
            name: Translation.tr("Mouse"),
            icon: "mouse",
            description: Translation.tr("Pointer, touchpad and gestures"),
            component: "modules/settings/MouseConfig.qml"
        },
        {
            group: Translation.tr("Devices"),
            name: Translation.tr("Power"),
            icon: "bolt",
            description: Translation.tr("Battery, sleep and power profiles"),
            component: "modules/settings/PowerConfig.qml"
        },
        {
            group: Translation.tr("System"),
            name: Translation.tr("Services"),
            icon: "settings",
            description: Translation.tr("Background services, weather and integrations"),
            component: "modules/settings/ServicesConfig.qml"
        },
        {
            group: Translation.tr("System"),
            name: Translation.tr("Manage"),
            icon: "apps",
            description: Translation.tr("Default apps and what starts with the session"),
            component: "modules/settings/ManageAppsConfig.qml"
        }
    ]

    // ─── Search ─────────────────────────────────────────────
    readonly property real pageHeaderHeight: 72
    property string searchQuery: ""
    property int searchSelection: 0
    property var searchIndex: []
    // Waits for a page to be on screen before marking the option found on it.
    property string pendingReveal: ""
    readonly property var searchResults: root.findSettings(root.searchQuery)

    function normalized(text) {
        return (text ?? "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    }
    // The labels are in the interface's language; these let a search typed in
    // Portuguese find them as well. Keys are written as normalized() leaves them.
    readonly property var searchSynonyms: ({
        "transparencia": "transparen", "papel": "wallpaper", "parede": "wallpaper", "fundo": "background",
        "cor": "color", "cores": "color", "aparencia": "appearance", "barra": "bar",
        "janela": "window", "janelas": "window", "borda": "border", "bordas": "border", "sombra": "shadow",
        "desfoque": "blur", "animacao": "animation", "animacoes": "animation", "arredondado": "round",
        "tela": "display", "monitor": "display", "resolucao": "resolution", "escala": "scale",
        "teclado": "keyboard", "atalho": "keybind", "atalhos": "keybind", "idioma": "language",
        "energia": "power", "bateria": "battery", "suspender": "suspend", "bloqueio": "lock",
        "notificacao": "notification", "notificacoes": "notification", "som": "sound", "audio": "audio",
        "rede": "network", "redes": "network", 
        "aplicativo": "app", "aplicativos": "app", "inicializacao": "autostart",
        "gesto": "gesture", "gestos": "gesture", "relogio": "clock", "clima": "weather",
        "barra lateral": "sidebar", "lateral": "sidebar", "ponteiro": "pointer", "rolagem": "scroll"
    })
    function searchForms(term) {
        const forms = [term];
        if (term.length < 3) return forms;
        for (const word in root.searchSynonyms)
            if (word.startsWith(term)) forms.push(root.searchSynonyms[word]);
        return forms;
    }
    function findSettings(query) {
        const terms = root.normalized(query).split(/\s+/).filter(term => term.length > 0);
        if (terms.length === 0) return [];
        const termForms = terms.map(term => root.searchForms(term));
        const results = [];
        const consider = (entry, label, context, bonus) => {
            const name = root.normalized(label);
            const all = name + " " + root.normalized(context);
            if (!termForms.every(forms => forms.some(form => all.includes(form)))) return;
            const first = termForms[0];
            const score = bonus + (first.some(form => name.startsWith(form)) ? 2
                : first.some(form => name.includes(form)) ? 1 : 0);
            results.push(Object.assign({ score: score }, entry));
        };
        root.pages.forEach((page, index) => {
            consider({ pageIndex: index, label: page.name, path: page.group, icon: page.icon, reveal: "" },
                page.name, page.description, 2);
        });
        root.searchIndex.forEach(item => {
            const index = root.pageIndex(item.page);
            if (index === -1) return;
            const page = root.pages[index];
            const label = Translation.tr(item.label);
            const section = item.section && item.section !== item.label ? Translation.tr(item.section) : "";
            consider({ pageIndex: index, label: label, icon: page.icon, reveal: label,
                       path: section ? page.name + " › " + section : page.name },
                label + " " + item.label, page.name + " " + section, 0);
        });
        return results.sort((a, b) => b.score - a.score).slice(0, 40);
    }
    function openResult(result) {
        if (!result) return;
        root.pendingReveal = result.reveal;
        if (result.pageIndex === root.currentPage) revealTimer.restart();
        else root.currentPage = result.pageIndex;
    }
    function clearSearch() {
        searchInput.text = "";
        searchInput.focus = false;
    }

    Timer {
        id: revealTimer
        interval: 160
        repeat: false
        onTriggered: {
            const label = root.pendingReveal;
            root.pendingReveal = "";
            if (label && pageLoader.item?.revealLabel) pageLoader.item.revealLabel(label);
        }
    }

    Process {
        id: searchIndexProc
        running: true
        command: ["python3", Quickshell.shellPath("scripts/settings/search-index.py"),
            Quickshell.shellPath("modules/settings")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.searchIndex = JSON.parse(this.text);
                } catch (e) {
                    console.log("settings: could not read the search index:", e);
                }
            }
        }
    }

    Shortcut {
        sequences: ["Ctrl+F", "Ctrl+K"]
        onActivated: searchInput.forceActiveFocus()
    }

    // A page opened from elsewhere can sit below the fold of the page list.
    function scrollNavToCurrent() {
        const row = navRepeater.itemAt(root.currentPage);
        if (!row) return;
        const top = row.y - 8;
        const bottom = row.y + row.height + 8;
        if (top < navRailFlickable.contentY) navRailFlickable.contentY = Math.max(0, top);
        else if (bottom > navRailFlickable.contentY + navRailFlickable.height)
            navRailFlickable.contentY = bottom - navRailFlickable.height;
    }
    onCurrentPageChanged: Qt.callLater(root.scrollNavToCurrent)

    function pageIndex(name) {
        return root.pages.findIndex(page => page.component.endsWith(name));
    }
    function showPage(name) {
        const idx = root.pageIndex(name);
        if (idx !== -1) root.currentPage = idx;
    }

    // Read deep-linking from environment variables (set by dialogs)
    // A page may be named by its component file (WifiConfig.qml) instead of
    // its position, so callers don't have to track this list's ordering.
    property int initialPage: {
        const envPage = Quickshell.env("QS_SETTINGS_PAGE");
        if (!envPage) return 0;
        const named = root.pageIndex(envPage);
        return named !== -1 ? named : (parseInt(envPage) || 0);
    }
    property int initialTab: {
        const envTab = Quickshell.env("QS_SETTINGS_TAB");
        return envTab ? parseInt(envTab) : 0;
    }
    // Handed to the loaded page below and cleared once a page reports the
    // section found, so later page visits start at the top as usual.
    property string pendingSettingsSection: Quickshell.env("QS_SETTINGS_SECTION") || ""
    property int currentPage: initialPage

    visible: true
    onClosing: Qt.quit()
    title: Translation.tr("Mainstream Settings")

    // Re-center on the active screen after a monitor scale apply.
    //
    // Why hyprctl instead of Screen.*: on Hyprland/Wayland the QScreen
    // attached properties don't reliably notify when the compositor changes
    // a per-monitor scale at runtime, so reading Screen.width/height after a
    // reload returns the *previous* logical size. That made a 167%→100%
    // change land the window at the old (smaller) centre — visibly up-left
    // of the new true centre — and a 167%→200% change overshoot down-right.
    //
    // hyprctl monitors -j is the source of truth: pixel `width`/`height`
    // plus `scale` give the logical compositor size (width/scale), and
    // `x`/`y` give the monitor origin in the multi-monitor virtual desktop.
    function recenter() {
        recenterProc.running = false;
        recenterProc.running = true;
    }

    Process {
        id: recenterProc
        command: ["hyprctl", "monitors", "-j"]
        // Collected whole. A parser with an empty marker hands over each raw
        // pipe read as it arrives, so on a machine with several screens the
        // JSON arrived in pieces and every piece failed to parse.
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let mons = JSON.parse(this.text);
                    if (!mons || mons.length === 0) return;
                    let mon = mons.find(m => m.focused) || mons[0];
                    let scale = mon.scale || 1.0;
                    // Hyprland's transform values 1, 3, 5, 7 are 90°/270°
                    // rotations — swap width/height in those cases so the
                    // logical orientation matches the visible one.
                    let rot = (mon.transform || 0) % 2 === 1;
                    let pxW = rot ? mon.height : mon.width;
                    let pxH = rot ? mon.width  : mon.height;
                    let logicalW = pxW / scale;
                    let logicalH = pxH / scale;
                    let tx = Math.round(mon.x + (logicalW - root.width)  / 2);
                    let ty = Math.round(mon.y + (logicalH - root.height) / 2);
                    // Asking for a position it already asked for is what let a
                    // resize become a move become another resize, forking two
                    // hyprctl processes each time round.
                    if (tx === root.lastRecenterX && ty === root.lastRecenterY)
                        return;
                    root.lastRecenterX = tx;
                    root.lastRecenterY = ty;
                    // Wayland xdg-shell does not allow clients to set their
                    // own x/y after creation — assigning root.x/root.y is a
                    // no-op on Hyprland. Ask the compositor to move us via
                    // a hyprctl dispatch keyed on our (translated) title.
                    let titleRegex = (root.title || "")
                        .replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
                    if (!titleRegex) return;
                    recenterMoveProc.command = [
                        "hyprctl", "dispatch",
                        `hl.dsp.window.move({ x = ${tx}, y = ${ty}, window = [[title:^${titleRegex}$]] })`
                    ];
                    recenterMoveProc.running = false;
                    recenterMoveProc.running = true;
                } catch (e) {
                    console.log("settings: could not read monitors for recenter:", e);
                }
            }
        }
    }

    Process { id: recenterMoveProc; command: [] }

    // Where the last move asked for, so the same request is not made twice.
    property int lastRecenterX: -100000
    property int lastRecenterY: -100000

    // Debounce — give hyprctl reload a beat to land before we query so we
    // don't read the pre-apply geometry.
    Timer {
        id: recenterTimer
        interval: 220
        repeat: false
        onTriggered: root.recenter()
    }

    Screen.onWidthChanged:  recenterTimer.restart()
    Screen.onHeightChanged: recenterTimer.restart()
    onWidthChanged:  recenterTimer.restart()
    onHeightChanged: recenterTimer.restart()

    // The Loader below swaps in DisplayConfig.qml when the user opens the
    // Display page. DisplayConfig emits scaleApplied() after its reloadProc
    // exits, which is the only deterministic "apply has fully landed"
    // signal — Screen.* changes are unreliable on Wayland scale apply.
    Connections {
        target: pageLoader.item
        ignoreUnknownSignals: true
        function onScaleApplied() { recenterTimer.restart() }
    }

    Component.onCompleted: {
        // An app must not tear itself down under the user. Quickshell reloads
        // an instance whenever a file it loaded changes, and the update copies
        // this very tree in, so the window used to restart part way through
        // an update and, since a reload kills the objects' child processes,
        // took the running update with it. The next launch loads the new
        // files; this one keeps what it started with.
        Quickshell.watchFiles = false
        MaterialThemeLoader.reapplyTheme()
        ThemeLibrary.load()
        Config.readWriteDelay = 0 // Settings app always only sets one var at a time so delay isn't needed
        recenterTimer.restart()
    }

    // A second launch hands its page to this window rather than opening
    // another: qs ipc --pid <pid> call settings showPage WifiConfig.qml
    IpcHandler {
        target: "settings"
        function showPage(name: string): void {
            root.showPage(name);
        }
        // Fills the search box, as if typed: qs ipc -p <this file> call settings search wifi
        function search(query: string): void {
            searchInput.text = query;
        }
        // Goes to the result the search box has selected.
        function openSearchResult(): void {
            root.openResult(root.searchResults[root.searchSelection]);
        }
    }

    minimumWidth: 900
    minimumHeight: 500
    width: 1100
    height: 750
    color: Appearance.m3colors.m3background

    ColumnLayout {
        anchors {
            fill: parent
            margins: contentPadding
        }

        Keys.onPressed: (event) => {
            if (event.modifiers === Qt.ControlModifier) {
                if (event.key === Qt.Key_PageDown) {
                    root.currentPage = Math.min(root.currentPage + 1, root.pages.length - 1)
                    event.accepted = true;
                } 
                else if (event.key === Qt.Key_PageUp) {
                    root.currentPage = Math.max(root.currentPage - 1, 0)
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Tab) {
                    root.currentPage = (root.currentPage + 1) % root.pages.length;
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Backtab) {
                    root.currentPage = (root.currentPage - 1 + root.pages.length) % root.pages.length;
                    event.accepted = true;
                }
            }
        }

        RowLayout { // Window content with navigation rail and content pane
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: contentPadding
            ColumnLayout {
                id: navRailWrapper
                Layout.fillHeight: true
                Layout.fillWidth: false
                Layout.preferredWidth: 228
                Layout.margins: 4
                spacing: 10

                StyledText {
                    visible: Config.options?.windows.showTitlebar ?? true
                    Layout.leftMargin: 10
                    Layout.topMargin: 6
                    color: Appearance.colors.colOnLayer0
                    text: Translation.tr("Settings")
                    font {
                        family: Appearance.font.family.title
                        pixelSize: Appearance.font.pixelSize.title
                        variableAxes: Appearance.font.variableAxes.title
                    }
                }

                Rectangle { // Search box
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colLayer1
                    border.width: searchInput.activeFocus ? 2 : 1
                    border.color: searchInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 6
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
                                text: Translation.tr("Search settings")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                            StyledTextInput {
                                id: searchInput
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                clip: true
                                onTextChanged: {
                                    root.searchQuery = text;
                                    root.searchSelection = 0;
                                }
                                Keys.onEscapePressed: root.clearSearch()
                                Keys.onReturnPressed: root.openResult(root.searchResults[root.searchSelection])
                                Keys.onEnterPressed: root.openResult(root.searchResults[root.searchSelection])
                                Keys.onDownPressed: root.searchSelection = Math.min(root.searchSelection + 1, root.searchResults.length - 1)
                                Keys.onUpPressed: root.searchSelection = Math.max(root.searchSelection - 1, 0)
                            }
                        }
                        RippleButton {
                            visible: searchInput.text.length > 0
                            implicitWidth: 30
                            implicitHeight: 30
                            buttonRadius: Appearance.rounding.full
                            onClicked: root.clearSearch()
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: "close"
                                iconSize: 18
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }

                Flickable { // Page list
                    id: navRailFlickable
                    visible: root.searchQuery.length === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: navRail.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

                    ColumnLayout {
                        id: navRail
                        width: navRailFlickable.width
                        spacing: 2

                        onImplicitHeightChanged: root.scrollNavToCurrent()

                        Repeater {
                            id: navRepeater
                            model: root.pages
                            delegate: ColumnLayout {
                                required property int index
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 2

                                // A heading whenever the group changes — driven off each
                                // page's `group`, so pages can be added, removed, or
                                // reordered without touching hardcoded indices.
                                StyledText {
                                    visible: index > 0 && root.pages[index - 1].group !== modelData.group
                                    Layout.leftMargin: 12
                                    Layout.topMargin: 12
                                    Layout.bottomMargin: 2
                                    text: modelData.group.toUpperCase()
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                    font.letterSpacing: 1.1
                                    color: Appearance.colors.colSubtext
                                }

                                SettingsNavButton {
                                    toggled: root.currentPage === index
                                    onPressed: root.currentPage = index
                                    buttonIcon: modelData.icon
                                    buttonIconRotation: modelData.iconRotation ?? 0
                                    buttonText: modelData.name
                                }
                            }
                        }
                    }
                }

                StyledListView { // Search results, in the list's place
                    id: searchResultsView
                    visible: root.searchQuery.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: root.searchResults
                    currentIndex: root.searchSelection
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: RippleButton {
                        id: resultButton
                        required property int index
                        required property var modelData
                        width: searchResultsView.width
                        implicitHeight: resultRow.implicitHeight + 16
                        buttonRadius: Appearance.rounding.small
                        colBackground: index === root.searchSelection ? Appearance.colors.colSecondaryContainer : "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        onClicked: {
                            root.searchSelection = index;
                            root.openResult(modelData);
                        }
                        contentItem: RowLayout {
                            id: resultRow
                            spacing: 10
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 10
                                rightMargin: 10
                            }
                            MaterialSymbol {
                                text: resultButton.modelData.icon
                                iconSize: 20
                                color: Appearance.colors.colOnLayer1
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    Layout.fillWidth: true
                                    text: resultButton.modelData.label
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer1
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: resultButton.modelData.path
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                    }

                    StyledText {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 12
                        }
                        visible: root.searchResults.length === 0
                        wrapMode: Text.Wrap
                        text: Translation.tr("No settings found")
                        color: Appearance.colors.colSubtext
                    }
                }
            }
            Rectangle { // Content container
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Appearance.m3colors.m3surfaceContainerLow
                radius: Appearance.rounding.windowRounding - root.contentPadding

                Item { // Where you are
                    id: pageHeader
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: root.pageHeaderHeight

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 24
                            rightMargin: 24
                        }
                        spacing: 14

                        MaterialSymbol {
                            text: root.pages[root.currentPage].icon
                            rotation: root.pages[root.currentPage].iconRotation ?? 0
                            iconSize: 30
                            fill: 1
                            color: Appearance.colors.colPrimary
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: root.pages[root.currentPage].name
                                elide: Text.ElideRight
                                color: Appearance.colors.colOnLayer0
                                font {
                                    family: Appearance.font.family.title
                                    pixelSize: Appearance.font.pixelSize.huge
                                    variableAxes: Appearance.font.variableAxes.title
                                }
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: root.pages[root.currentPage].description
                                elide: Text.ElideRight
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smallie
                            }
                        }
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        height: 1
                        color: Appearance.colors.colLayer0Border
                    }
                }

                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    anchors.topMargin: root.pageHeaderHeight
                    opacity: 1.0

                    active: Config.ready
                    source: Config.ready ? root.pages[root.currentPage].component : ""
                    // Per-page opt-in (see the page entries above) — currently
                    // only DisplayConfig flips this on. Async loads avoid the
                    // page-swap stutter on heavy pages but break layouts that
                    // assume the Loader's content is sized synchronously, so
                    // we don't apply it as a blanket setting.
                    asynchronous: Config.ready
                        && (root.pages[root.currentPage]?.asynchronous ?? false)

                    onLoaded: {
                        if (root.pendingReveal) revealTimer.restart();
                        if (!root.pendingSettingsSection || !item?.scrollToSection) return;
                        const name = root.pendingSettingsSection;
                        const page = item;
                        // After layout: section positions are not final inside onLoaded.
                        Qt.callLater(() => {
                            if (page === pageLoader.item && page.scrollToSection(name))
                                root.pendingSettingsSection = "";
                        });
                    }

                    function reloadCurrentPage() {
                        if (!Config.ready)
                            return;

                        const currentSource = root.pages[root.currentPage].component;
                        source = "";
                        source = currentSource;
                    }

                    Connections {
                        target: Appearance
                        function onThemeRevisionChanged() {
                            pageLoader.reloadCurrentPage();
                        }
                    }

                    Connections {
                        target: root
                        function onCurrentPageChanged() {
                            switchAnim.complete();
                            switchAnim.start();
                        }
                    }

                    SequentialAnimation {
                        id: switchAnim

                        NumberAnimation {
                            target: pageLoader
                            properties: "opacity"
                            from: 1
                            to: 0
                            duration: Appearance.motion.instant
                            easing.type: Appearance.animation.elementMoveExit.type
                            easing.bezierCurve: Appearance.animationCurves.emphasizedFirstHalf
                        }
                        ParallelAnimation {
                            PropertyAction {
                                target: pageLoader
                                property: "source"
                                value: root.pages[root.currentPage].component
                            }
                            PropertyAction {
                                target: pageLoader
                                property: "anchors.topMargin"
                                value: root.pageHeaderHeight + 20
                            }
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: pageLoader
                                properties: "opacity"
                                from: 0
                                to: 1
                                duration: Appearance.motion.fast
                                easing.type: Appearance.animation.elementMoveEnter.type
                                easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                            }
                            NumberAnimation {
                                target: pageLoader
                                properties: "anchors.topMargin"
                                to: root.pageHeaderHeight
                                duration: Appearance.motion.fast
                                easing.type: Appearance.animation.elementMoveEnter.type
                                easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                            }
                        }
                    }
                }
            }
        }
    }

    // Inline nav button for settings — same visual style as NavigationRailButton
    // in expanded mode but without states/transitions to avoid animation on first open.
    component SettingsNavButton: TabButton {
        id: navBtn
        property bool toggled: false
        property string buttonIcon
        // A glyph that only reads correctly one way up, the bar's among them,
        // is turned here. NavigationRailButton has carried this for its own
        // rows all along; this one had the value passed to it and nowhere to
        // put it, so the bar's icon sat upside down.
        property real buttonIconRotation: 0
        property string buttonText

        readonly property real baseSize: 42
        readonly property real visualWidth: baseSize + 20 + navBtnText.implicitWidth

        Layout.fillWidth: true
        implicitHeight: baseSize
        padding: 0
        background: null
        PointingHandInteraction {}

        contentItem: Item {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            implicitWidth: navBtn.visualWidth

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: navBtn.width
                radius: Appearance.rounding.small
                color: navBtn.toggled ?
                    (navBtn.down ? Appearance.colors.colSecondaryContainerActive : navBtn.hovered ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer) :
                    (navBtn.down ? Appearance.colors.colLayer1Active : navBtn.hovered ? Appearance.colors.colLayer1Hover : CF.ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1))

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }

            Item {
                id: navBtnIconArea
                implicitWidth: navBtn.baseSize
                implicitHeight: 32
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    iconSize: 22
                    fill: navBtn.toggled ? 1 : 0
                    font.weight: (navBtn.toggled || navBtn.hovered) ? Font.DemiBold : Font.Normal
                    text: navBtn.buttonIcon
                    rotation: navBtn.buttonIconRotation
                    color: navBtn.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1

                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                }
            }

            StyledText {
                id: navBtnText
                anchors {
                    left: navBtnIconArea.right
                    verticalCenter: navBtnIconArea.verticalCenter
                }
                text: navBtn.buttonText
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: navBtn.toggled ? Font.Medium : Font.Normal
                color: navBtn.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
            }
        }
    }
}
