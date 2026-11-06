import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sysmonitor

/**
 * Remote Desktop — Remmina-style RDP manager in the ii shell style (FreeRDP 3 underneath).
 *   qs -c ii ipc call remote toggle      open / close the window
 *   qs -c ii ipc call remote switcher    open the floating quick switcher
 */
Scope {
    id: root
    property bool shown: false

    // ── service state (lives in the shell, so sessions and the floating
    //    switcher keep working while the window is closed) ──────────────
    property var connections: []
    property var sessions: ({})
    property var reach: ({})
    property var saved: ({})
    property string client: ""
    property var clients: []
    property bool keyring: true
    property bool loaded: false
    property string lastLog: ""
    property var prefs: ({ view: "grid", sort: "name", desc: false, switcher: true })
    readonly property int activeCount: Object.keys(sessions).length
    signal notice(string text, bool ok)
    signal passwordNeeded(string id, string name, string user)
    property var pendingPrompt: null
    // where each visible session window is (from Hyprland), keyed by connection id
    property var sessionWindows: ({})
    readonly property var sessionWindowIds: Object.keys(sessionWindows).sort()

    // natural sort: "dedicado 66" < "dedicado 89" < "dedicado 169"
    function naturalCompare(a, b) {
        const ax = String(a).toLowerCase().match(/(\d+|\D+)/g) || [];
        const bx = String(b).toLowerCase().match(/(\d+|\D+)/g) || [];
        for (let i = 0; i < Math.min(ax.length, bx.length); i++) {
            const an = /^\d/.test(ax[i]), bn = /^\d/.test(bx[i]);
            if (an && bn) {
                const d = parseInt(ax[i]) - parseInt(bx[i]);
                if (d !== 0)
                    return d;
            } else if (ax[i] !== bx[i])
                return ax[i] < bx[i] ? -1 : 1;
        }
        return ax.length - bx.length;
    }
    function hostCompare(a, b) {
        const ip = /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/;
        const ma = String(a).match(ip), mb = String(b).match(ip);
        if (ma && mb) {
            for (let i = 1; i <= 4; i++) {
                const d = parseInt(ma[i]) - parseInt(mb[i]);
                if (d !== 0)
                    return d;
            }
            return 0;
        }
        if (ma !== null !== (mb !== null))
            return ma ? -1 : 1;  // IPs before host names
        return naturalCompare(a, b);
    }
    readonly property var sortedConnections: {
        const key = prefs.sort === "host" ? "host" : "name";
        const dir = prefs.desc ? -1 : 1;
        return connections.slice().sort((a, b) => {
            const c = key === "host" ? hostCompare(a.host, b.host) || naturalCompare(a.name, b.name) : naturalCompare(a.name, b.name) || hostCompare(a.host, b.host);
            return c * dir;
        });
    }

    function send(obj) {
        if (backend.running)
            backend.write(JSON.stringify(obj) + "\n");
    }
    function setPref(key, value) {
        const p = Object.assign({}, prefs);
        p[key] = value;
        prefs = p;
        send({
            cmd: "set_pref",
            key: key,
            value: value
        });
    }
    // open the main window; if it's already open (maybe on another workspace or
    // behind other windows), reopen it so it appears on the current workspace,
    // focused and on top of everything
    function showApp() {
        if (!shown) {
            shown = true;
            return;
        }
        shown = false;
        reopenTimer.restart();
    }
    Timer {
        id: reopenTimer
        interval: 60
        onTriggered: root.shown = true
    }
    function openOrFocus(id) {
        send({
            cmd: "open_or_focus",
            id: id
        });
    }
    function handle(line) {
        let m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            return;
        }
        switch (m.type) {
        case "state":
            connections = m.connections;
            sessions = m.sessions;
            reach = m.reach;
            client = m.client;
            clients = m.clients;
            keyring = m.keyring;
            if (m.prefs)
                prefs = Object.assign({ view: "grid", sort: "name", desc: false, switcher: true }, m.prefs);
            loaded = true;
            break;
        case "saved":
            saved = m.saved;
            break;
        case "need_password":
            // the prompt lives in the window — open it if needed
            pendingPrompt = { id: m.id, name: m.name, user: m.user };
            if (!shown)
                shown = true;
            else
                passwordNeeded(m.id, m.name, m.user);
            break;
        case "windows":
            {
                const map = {};
                for (const w of m.windows)
                    map[w.id] = w;
                sessionWindows = map;
                break;
            }
        case "log":
            lastLog = m.text;
            break;
        case "msg":
            notice(m.text, m.ok);
            if (!shown && !m.ok)
                Quickshell.execDetached(["notify-send", "-a", "Remote Desktop", "-i", "network-error", "Remote Desktop", m.text]);
            break;
        }
    }

    Process {
        id: backend
        running: true
        stdinEnabled: true
        command: ["python3", "-u", decodeURIComponent(String(Qt.resolvedUrl("../../scripts/remote/remote.py")).replace(/^file:\/\//, ""))]
        stdout: SplitParser {
            onRead: data => root.handle(data)
        }
        stderr: SplitParser {
            onRead: data => console.warn("[Remote]", data)
        }
    }

    IpcHandler {
        target: "remote"
        function toggle(): void {
            root.shown = !root.shown;
        }
        function open(): void {
            root.shown = true;
        }
        function close(): void {
            root.shown = false;
        }
        // qs -c ii ipc call remote switcher   → open the floating quick switcher
        function switcher(): void {
            const list = switchers.instances;
            if (list.length > 0)
                list[0].expanded = !list[0].expanded;
        }
    }

    // floating quick switcher: one button in the top-right corner of every
    // visible session window (follows it when moved/resized/tiled)
    Variants {
        id: switchers
        model: root.loaded && root.prefs.switcher !== false ? root.sessionWindowIds : []
        delegate: RemoteSwitcher {
            required property var modelData
            service: root
            windowId: modelData
        }
    }

    LazyLoader {
        active: root.shown

        component: FloatingWindow {
            id: win
            title: "Remote Desktop"
            implicitWidth: 1200
            implicitHeight: 800
            color: Appearance.m3colors.m3background
            visible: true
            onVisibleChanged: if (!visible)
                root.shown = false

            // ── window-only state ──────────────────────────────
            property string filter: ""
            property string group: "__all"
            property real now: Date.now() / 1000

            readonly property var groups: {
                const g = [];
                for (const c of root.connections)
                    if (c.group && g.indexOf(c.group) < 0)
                        g.push(c.group);
                return g.sort();
            }
            // fixed order (name or host) — opening a connection no longer moves it
            readonly property var visibleConnections: {
                const f = filter.toLowerCase();
                return root.sortedConnections.filter(c => {
                    if (group === "__active" && !root.sessions[c.id])
                        return false;
                    if (group !== "__all" && group !== "__active" && c.group !== group)
                        return false;
                    if (!f)
                        return true;
                    return (c.name + " " + c.host + " " + c.user + " " + c.group).toLowerCase().indexOf(f) >= 0;
                });
            }

            function quickConnect() {
                const h = quick.text.trim();
                if (!h)
                    return;
                prompt.askQuick(h);
            }

            Connections {
                target: root
                function onNotice(text, ok) {
                    toast.show(text, ok);
                }
                function onPasswordNeeded(id, name, user) {
                    prompt.ask(id, name, user);
                }
            }
            Component.onCompleted: {
                if (root.pendingPrompt) {
                    const p = root.pendingPrompt;
                    Qt.callLater(() => prompt.ask(p.id, p.name, p.user));
                }
                root.send({
                    cmd: "refresh"
                });
            }

            Timer {
                interval: 30000
                repeat: true
                running: true
                triggeredOnStart: true
                onTriggered: win.now = Date.now() / 1000
            }

            FocusScope {
                id: content
                anchors.fill: parent
                focus: true
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: e => {
                    if (editor.visible || prompt.visible) {
                        if (e.key === Qt.Key_Escape) {
                            editor.close();
                            prompt.close();
                            e.accepted = true;
                        }
                        return;
                    }
                    if (e.key === Qt.Key_Escape) {
                        if (search.field.activeFocus || quick.field.activeFocus)
                            content.forceActiveFocus();
                        else
                            root.shown = false;
                        e.accepted = true;
                    } else if (e.key === Qt.Key_N && (e.modifiers & Qt.ControlModifier)) {
                        editor.open(null, false);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_F && (e.modifiers & Qt.ControlModifier) || e.key === Qt.Key_Slash) {
                        search.field.forceActiveFocus();
                        e.accepted = true;
                    } else if (e.key === Qt.Key_L && (e.modifiers & Qt.ControlModifier)) {
                        quick.field.forceActiveFocus();
                        e.accepted = true;
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    SysAppHeader {
                        icon: "connected_tv"
                        title: "Remote Desktop"
                        subtitle: !root.loaded ? "Loading…" : `${root.connections.length} connections  ·  ${root.activeCount} active  ·  ` + (root.client ? root.client : "FreeRDP not installed")
                        onCloseRequested: root.shown = false

                        SysTextField {
                            id: quick
                            Layout.preferredWidth: 280
                            icon: "bolt"
                            placeholderText: "Quick connect: host or IP  (Ctrl+L)"
                            onAccepted: win.quickConnect()
                        }
                        SysButton {
                            icon: "download"
                            text: "Import Remmina"
                            onClicked: root.send({
                                cmd: "import_remmina"
                            })
                        }
                        SysButton {
                            icon: "add"
                            text: "New"
                            tonal: true
                            onClicked: editor.open(null, false)
                        }
                    }

                    // warnings
                    Rectangle {
                        visible: root.loaded && (!root.client || !root.keyring)
                        Layout.fillWidth: true
                        implicitHeight: warnRow.implicitHeight + 20
                        radius: Appearance.rounding.normal
                        color: Appearance.m3colors.m3errorContainer
                        RowLayout {
                            id: warnRow
                            anchors.fill: parent
                            anchors.margins: 10
                            anchors.leftMargin: 14
                            spacing: 10
                            MaterialSymbol {
                                text: "warning"
                                iconSize: 20
                                color: Appearance.m3colors.m3onErrorContainer
                            }
                            StyledText {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: Appearance.m3colors.m3onErrorContainer
                                text: (!root.client ? "FreeRDP is not installed — run: sudo pacman -S freerdp   " : "") + (!root.keyring ? "No keyring tool found — install libsecret (secret-tool) to save passwords." : "")
                            }
                        }
                    }

                    // toolbar: search, groups, client
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        SysTextField {
                            id: search
                            Layout.preferredWidth: 300
                            icon: "search"
                            placeholderText: "Search connections  ( / )"
                            onTextChanged: win.filter = text
                        }
                        Flickable {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            contentWidth: chips.implicitWidth
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            Row {
                                id: chips
                                spacing: 6
                                SysButton {
                                    text: "All"
                                    toggled: win.group === "__all"
                                    onClicked: win.group = "__all"
                                }
                                SysButton {
                                    icon: "cast_connected"
                                    text: "Active" + (root.activeCount ? "  " + root.activeCount : "")
                                    toggled: win.group === "__active"
                                    onClicked: win.group = "__active"
                                }
                                Repeater {
                                    model: win.groups
                                    delegate: SysButton {
                                        required property string modelData
                                        icon: "folder"
                                        text: modelData
                                        toggled: win.group === modelData
                                        onClicked: win.group = modelData
                                    }
                                }
                            }
                        }
                        // view: grid / list
                        Rectangle {
                            implicitHeight: 34
                            implicitWidth: viewRow.implicitWidth + 6
                            radius: height / 2
                            color: Appearance.colors.colLayer1
                            Row {
                                id: viewRow
                                anchors.centerIn: parent
                                spacing: 2
                                SysButton {
                                    icon: "grid_view"
                                    implicitWidth: 30
                                    implicitHeight: 28
                                    toggled: root.prefs.view !== "list"
                                    color: toggled ? Appearance.m3colors.m3secondaryContainer : "transparent"
                                    onClicked: root.setPref("view", "grid")
                                }
                                SysButton {
                                    icon: "view_list"
                                    implicitWidth: 30
                                    implicitHeight: 28
                                    toggled: root.prefs.view === "list"
                                    color: toggled ? Appearance.m3colors.m3secondaryContainer : "transparent"
                                    onClicked: root.setPref("view", "list")
                                }
                            }
                        }
                        // sort: name / host + direction
                        Rectangle {
                            implicitHeight: 34
                            implicitWidth: sortRow.implicitWidth + 6
                            radius: height / 2
                            color: Appearance.colors.colLayer1
                            Row {
                                id: sortRow
                                anchors.centerIn: parent
                                spacing: 2
                                SysButton {
                                    text: "Name"
                                    implicitHeight: 28
                                    toggled: root.prefs.sort !== "host"
                                    color: toggled ? Appearance.m3colors.m3secondaryContainer : "transparent"
                                    onClicked: root.setPref("sort", "name")
                                }
                                SysButton {
                                    text: "Host"
                                    implicitHeight: 28
                                    toggled: root.prefs.sort === "host"
                                    color: toggled ? Appearance.m3colors.m3secondaryContainer : "transparent"
                                    onClicked: root.setPref("sort", "host")
                                }
                                SysButton {
                                    icon: root.prefs.desc ? "arrow_downward" : "arrow_upward"
                                    implicitWidth: 30
                                    implicitHeight: 28
                                    color: "transparent"
                                    onClicked: root.setPref("desc", !root.prefs.desc)
                                }
                            }
                        }
                        SysButton {
                            icon: "picture_in_picture_alt"
                            implicitWidth: 34
                            toggled: root.prefs.switcher !== false
                            onClicked: {
                                root.setPref("switcher", root.prefs.switcher === false);
                                toast.show(root.prefs.switcher === false ? "Floating switcher hidden" : "Floating switcher shows while a session is open", true);
                            }
                        }
                        SysButton {
                            visible: root.clients.length > 1
                            icon: "swap_horiz"
                            text: root.client
                            onClicked: {
                                const i = root.clients.indexOf(root.client);
                                root.send({
                                    cmd: "set_client",
                                    client: root.clients[(i + 1) % root.clients.length]
                                });
                            }
                        }
                        SysButton {
                            icon: "network_check"
                            implicitWidth: 34
                            onClicked: root.send({
                                cmd: "check"
                            })
                        }
                    }

                    // ── connections: grid or list ───────────────
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: root.prefs.view === "list" ? listCol.implicitHeight : grid.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        visible: win.visibleConnections.length > 0
                        ScrollBar.vertical: ScrollBar {}

                        GridLayout {
                            id: grid
                            visible: root.prefs.view !== "list"
                            width: parent.width
                            columns: Math.max(1, Math.floor((width + 12) / 372))
                            columnSpacing: 12
                            rowSpacing: 12
                            Repeater {
                                model: root.prefs.view !== "list" ? win.visibleConnections : []
                                delegate: ConnectionCard {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    conn: modelData
                                    session: root.sessions[modelData.id] || null
                                    reachable: root.reach[modelData.id]
                                    hasPassword: !!root.saved[modelData.id]
                                    now: win.now
                                    onConnectRequested: root.send({ cmd: "connect", id: modelData.id })
                                    onShowRequested: root.openOrFocus(modelData.id)
                                    onDisconnectRequested: root.send({ cmd: "disconnect", id: modelData.id })
                                    onEditRequested: editor.open(modelData, !!root.saved[modelData.id])
                                    onDuplicateRequested: root.send({ cmd: "duplicate", id: modelData.id })
                                    onDeleteRequested: root.send({ cmd: "delete", id: modelData.id })
                                }
                            }
                        }

                        ColumnLayout {
                            id: listCol
                            visible: root.prefs.view === "list"
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: root.prefs.view === "list" ? win.visibleConnections : []
                                delegate: ConnectionRow {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    conn: modelData
                                    session: root.sessions[modelData.id] || null
                                    reachable: root.reach[modelData.id]
                                    hasPassword: !!root.saved[modelData.id]
                                    now: win.now
                                    onConnectRequested: root.send({ cmd: "connect", id: modelData.id })
                                    onShowRequested: root.openOrFocus(modelData.id)
                                    onDisconnectRequested: root.send({ cmd: "disconnect", id: modelData.id })
                                    onEditRequested: editor.open(modelData, !!root.saved[modelData.id])
                                    onDuplicateRequested: root.send({ cmd: "duplicate", id: modelData.id })
                                    onDeleteRequested: root.send({ cmd: "delete", id: modelData.id })
                                }
                            }
                        }
                    }

                    // ── empty state ─────────────────────────────
                    Item {
                        visible: root.loaded && win.visibleConnections.length === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 10
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.connections.length === 0 ? "connected_tv" : "search_off"
                                iconSize: 56
                                color: Appearance.colors.colSubtext
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.connections.length === 0 ? "No connections yet" : "Nothing matches"
                                font.pixelSize: Appearance.font.pixelSize.large
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                visible: root.connections.length === 0
                                text: "Bring your Remmina profiles over or create a new connection"
                                color: Appearance.colors.colSubtext
                            }
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                visible: root.connections.length === 0
                                spacing: 8
                                SysButton {
                                    icon: "download"
                                    text: "Import from Remmina"
                                    onClicked: root.send({
                                        cmd: "import_remmina"
                                    })
                                }
                                SysButton {
                                    icon: "add"
                                    text: "New connection"
                                    tonal: true
                                    onClicked: editor.open(null, false)
                                }
                            }
                        }
                    }

                    // last error log (collapsible)
                    Rectangle {
                        visible: root.lastLog.length > 0
                        Layout.fillWidth: true
                        implicitHeight: Math.min(150, logText.implicitHeight + 46)
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer1
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6
                            RowLayout {
                                Layout.fillWidth: true
                                MaterialSymbol {
                                    text: "terminal"
                                    iconSize: 16
                                    color: Appearance.colors.colSubtext
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: "FreeRDP output of the last failed connection"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                                SysButton {
                                    icon: "close"
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    color: "transparent"
                                    onClicked: root.lastLog = ""
                                }
                            }
                            Flickable {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                contentHeight: logText.implicitHeight
                                TextEdit {
                                    id: logText
                                    width: parent.width
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.WrapAnywhere
                                    text: root.lastLog
                                    font.family: Appearance.font.family.monospace
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colOnLayer1
                                }
                            }
                        }
                    }
                }

                ConnectionEditor {
                    id: editor
                    anchors.fill: parent
                    z: 50
                    keyring: root.keyring
                    onSave: (conn, password) => root.send({
                        cmd: "save",
                        conn: conn,
                        password: password
                    })
                    onOpacityChanged: if (opacity === 0)
                        content.forceActiveFocus()
                }

                // ── password prompt ─────────────────────────────
                Item {
                    id: prompt
                    anchors.fill: parent
                    z: 60
                    visible: opacity > 0
                    opacity: 0
                    property string connId: ""
                    property string name: ""
                    property string user: ""
                    property string quickHost: ""
                    property bool remember: true
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                    function ask(id, n, u) {
                        connId = id;
                        quickHost = "";
                        name = n;
                        user = u;
                        pwField.text = "";
                        quickUser.text = "";
                        opacity = 1;
                        pwField.field.forceActiveFocus();
                    }
                    function askQuick(host) {
                        connId = "";
                        quickHost = host;
                        name = host;
                        user = "";
                        pwField.text = "";
                        quickUser.text = "";
                        opacity = 1;
                        quickUser.field.forceActiveFocus();
                    }
                    function close() {
                        opacity = 0;
                        root.pendingPrompt = null;
                        content.forceActiveFocus();
                    }
                    function go() {
                        if (quickHost) {
                            root.send({
                                cmd: "quick",
                                host: quickHost,
                                user: quickUser.text.trim(),
                                password: pwField.text
                            });
                            quick.text = "";
                        } else
                            root.send({
                                cmd: "connect",
                                id: connId,
                                password: pwField.text,
                                remember: remember && root.keyring
                            });
                        close();
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
                        opacity: 0.6
                        MouseArea {
                            anchors.fill: parent
                            onClicked: prompt.close()
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 420
                        height: pcol.implicitHeight + 40
                        radius: Appearance.rounding.large
                        color: Qt.rgba(Appearance.colors.colLayer1.r, Appearance.colors.colLayer1.g, Appearance.colors.colLayer1.b, 1)
                        border.width: 1
                        border.color: Appearance.m3colors.m3outlineVariant
                        MouseArea {
                            anchors.fill: parent
                        }
                        ColumnLayout {
                            id: pcol
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 12
                            RowLayout {
                                spacing: 10
                                MaterialSymbol {
                                    text: "lock"
                                    iconSize: 24
                                    color: Appearance.m3colors.m3primary
                                }
                                ColumnLayout {
                                    spacing: 0
                                    StyledText {
                                        text: prompt.quickHost ? "Quick connect" : "Sign in"
                                        font.pixelSize: Appearance.font.pixelSize.larger
                                        font.weight: Font.Bold
                                        color: Appearance.colors.colOnLayer1
                                    }
                                    StyledText {
                                        text: (prompt.user ? prompt.user + " @ " : "") + prompt.name
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                    }
                                }
                            }
                            SysTextField {
                                id: quickUser
                                visible: prompt.quickHost.length > 0
                                Layout.fillWidth: true
                                icon: "person"
                                placeholderText: "Username"
                                onAccepted: pwField.field.forceActiveFocus()
                            }
                            SysTextField {
                                id: pwField
                                Layout.fillWidth: true
                                icon: "key"
                                field.echoMode: TextInput.Password
                                placeholderText: "Password"
                                onAccepted: prompt.go()
                            }
                            RowLayout {
                                visible: !prompt.quickHost && root.keyring
                                spacing: 10
                                SysSwitch {
                                    checked: prompt.remember
                                    onToggled: on => prompt.remember = on
                                }
                                StyledText {
                                    text: "Remember in keyring"
                                    color: Appearance.colors.colOnLayer1
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Item {
                                    Layout.fillWidth: true
                                }
                                SysButton {
                                    text: "Cancel"
                                    onClicked: prompt.close()
                                }
                                SysButton {
                                    icon: "login"
                                    text: "Connect"
                                    tonal: true
                                    onClicked: prompt.go()
                                }
                            }
                        }
                    }
                }

                SysToast {
                    id: toast
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 28
                }
            }
        }
    }
}
