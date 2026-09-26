import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "./services"


PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: root._shown
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "macos:spotlight"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root._shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool _shown: false
    property string query: ""
    property int selectedIndex: 0
    property var items: []
    property var results: []
    property var fileItems: []
    property string mode: "search"
    property var recentItems: []
    property var clipItems: []
    property bool _opened: false
    property bool hasBody: root.mode !== "search" || root.query.length > 0 || root.items.length > 0 || root.nowPlayingText.length > 0
    property bool slashMode: root.query.startsWith("/")

    // ── NOVO: Now Playing (mpris via playerctl) ──
    property string nowPlayingText: ""
    property string nowPlayingStatus: ""

    // ── NOVO: Clima ──
    property string weatherText: ""

    // ── NOVO: Dicionário ──
    property string dictText: ""

    // ── NOVO: Quick Look ──
    property string previewPath: ""
    property string previewKind: ""   // "image" | "text" | "video" | "audio" | ""
    property string previewText: ""
    property string previewThumbPath: ""
    property bool previewAudioPlaying: false
    property string _pendingThumbPath: ""
    property string _pendingFor: ""
    property real previewNatW: 0
    property real previewNatH: 0

    // ── NOVO: calcula o tamanho do popup de preview a partir das dimensões naturais ──
    function previewSize() {
        const maxW = 480, maxH = 480, minW = 220, minH = 160;
        const w = root.previewNatW, h = root.previewNatH;
        if (!w || !h) return { w: 300, h: 260 };
        let scaleFit = Math.min(maxW / w, maxH / h);
        let outW = w * scaleFit, outH = h * scaleFit;
        if (outW < minW) { const s = minW / outW; outW = minW; outH = outH * s; }
        if (outH < minH) { const s = minH / outH; outH = minH; outW = outW * s; }
        outW = Math.min(outW, maxW); outH = Math.min(outH, maxH);
        return { w: outW, h: outH };
    }

    // ── Liquid Glass Color Palette (Pure Liquid Glass Refraction) ──
    readonly property color glassBg: Qt.rgba(0, 0, 0, 0.75)
    readonly property color glassBorder: Qt.rgba(255, 255, 255, 0.12)
    readonly property color glassHighlight: Qt.rgba(255, 255, 255, 0.06)
    readonly property color selectionBg: Qt.rgba(255, 255, 255, 0.22)
    readonly property color hoverBg: Qt.rgba(255, 255, 255, 0.15)
    readonly property color divider: Qt.rgba(255, 255, 255, 0.18)
    readonly property color headerFg: Qt.rgba(255, 255, 255, 0.30)
    readonly property color sFg: "#ffffff"
    readonly property color sFgDim: Qt.rgba(255, 255, 255, 0.85)
    readonly property color placeholderFg: Qt.rgba(255, 255, 255, 0.30)
    readonly property color accent: "#0c84ff"

    // ── Layout Dimensions ──
    readonly property real panelWidth: 600
    readonly property real panelRadius: 26
    readonly property real searchH: 60
    readonly property real circleSize: 60
    readonly property real circlesGap: 8
    readonly property real rowH: 44
    readonly property real headerH: 22
    readonly property real iconSize: 22
    readonly property real footerH: 28
    readonly property real stripH: 58
    readonly property real nowPlayingH: 46
    readonly property real previewH: 170

    property real panelOpacity: 0.0
    property real panelScale: 0.94
    property real panelYOffset: 15
    property bool circlesVisible: false
    property bool circlesLocked: false
    property int lockedCircleIndex: -1
    property string placeholderText: "Spotlight Search"

    property real railProgress: 0.0

    function animateRail(target) {
        _railAnim.stop()
        _railAnim.from = root.railProgress
        _railAnim.to = target
        _railAnim.duration = Math.max(100, Math.round(620 * Math.abs(target - root.railProgress)))
        _railAnim.start()
    }

    onCirclesVisibleChanged: {
        root.animateRail(circlesVisible ? 1.0 : 0.0)
    }

    NumberAnimation {
        id: _railAnim
        target: root
        property: "railProgress"
        duration: 620
        easing.type: Easing.Linear
    }

    // File search debounced function
    function runFd() {
        if (root.slashMode || root.query.trim().length < 2) { root.fileItems = []; root.buildResults(); return; }
        _fd.command = ["bash", "-c", "fd -t f -i " + root.shellQuote(root.query.trim()) + " ~ -d 5 2>/dev/null | head -8"]
        _fd.running = true
    }

    // ── NOVO: Conversão de unidades ──
    function convertUnits(q) {
        const s = q.trim().toLowerCase().replace(",", ".");
        const m = s.match(/^(-?[\d.]+)\s*(km|mi|milhas?|kg|lb|libras?|m|ft|pes?|c|f|celsius|fahrenheit)\s*(?:em|to|para)\s*(km|mi|milhas?|kg|lb|libras?|m|ft|pes?|c|f|celsius|fahrenheit)$/);
        if (!m) return null;
        const val = parseFloat(m[1]);
        if (isNaN(val)) return null;
        const norm = (u) => ({ milhas: "mi", milha: "mi", libras: "lb", libra: "lb", pes: "ft", pe: "ft", celsius: "c", fahrenheit: "f" }[u] || u);
        const from = norm(m[2]), to = norm(m[3]);
        if (from === to) return val + " " + to;
        const table = {
            "km_mi": v => v * 0.621371, "mi_km": v => v / 0.621371,
            "kg_lb": v => v * 2.20462, "lb_kg": v => v / 2.20462,
            "m_ft": v => v * 3.28084, "ft_m": v => v / 3.28084,
            "c_f": v => v * 9 / 5 + 32, "f_c": v => (v - 32) * 5 / 9
        };
        const fn = table[from + "_" + to];
        if (!fn) return null;
        return fn(val).toFixed(2) + " " + to;
    }

    // ── NOVO: Clima (curl wttr.in) ──
    function checkWeather() {
        const s = root.query.trim().toLowerCase();
        if (s === "clima" || s === "weather" || s.startsWith("clima ") || s.startsWith("weather ")) {
            const city = s.replace(/^(clima|weather)\s*/, "").trim();
            _weather.command = ["bash", "-c", "curl -s 'wttr.in/" + city.replace(/'/g, "") + "?format=3' 2>/dev/null"];
            _weather.running = true;
        } else if (root.weatherText !== "") {
            root.weatherText = "";
        }
    }

    // ── NOVO: Dicionário (dictionaryapi.dev, em inglês) ──
    function checkDefine() {
        const s = root.query.trim().toLowerCase();
        const m = s.match(/^(define|significado)\s+(.+)$/);
        if (m && m[2]) {
            _dict.command = ["bash", "-c", "curl -s 'https://api.dictionaryapi.dev/api/v2/entries/en/" + m[2].trim().replace(/[^a-z-]/g, "") + "' 2>/dev/null"];
            _dict.running = true;
        } else if (root.dictText !== "") {
            root.dictText = "";
        }
    }

    // ── NOVO: Quick Look ──
    function updatePreview() {
        // Ao trocar de seleção, para qualquer prévia de áudio que esteja tocando
        if (root.previewKind === "audio" && root.previewAudioPlaying) {
            SpotlightController.run("pkill -f 'mpv --no-video --really-quiet' 2>/dev/null || true");
        }
        root.previewAudioPlaying = false;
        root.previewThumbPath = "";
        root.previewNatW = 0;
        root.previewNatH = 0;

        const it = root.selectedItem;
        if (!it || it.kind !== "file") { root.previewPath = ""; root.previewKind = ""; root.previewText = ""; return; }
        const p = it.path;
        const ext = p.split(".").pop().toLowerCase();
        const imgExts = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"];
        const textExts = ["txt", "md", "json", "qml", "js", "ts", "py", "sh", "conf", "yaml", "yml", "xml", "html", "css", "c", "cpp", "h", "lua", "toml", "ini", "log"];
        const videoExts = ["mp4", "mkv", "webm", "avi", "mov", "m4v", "flv"];
        const audioExts = ["mp3", "flac", "wav", "ogg", "opus", "m4a", "aac"];
        if (imgExts.indexOf(ext) !== -1) {
            root.previewKind = "image"; root.previewPath = p; root.previewText = "";
        } else if (textExts.indexOf(ext) !== -1) {
            root.previewKind = "text"; root.previewPath = p;
            _preview.command = ["bash", "-c", "head -c 1500 " + root.shellQuote(p) + " 2>/dev/null"];
            _preview.running = true;
        } else if (videoExts.indexOf(ext) !== -1) {
            root.previewKind = "video"; root.previewPath = p;
            const thumbPath = "/tmp/spotlight_thumb_" + Date.now() + ".jpg";
            root._pendingThumbPath = thumbPath; root._pendingFor = p;
            _videoThumb.command = ["bash", "-c", "rm -f /tmp/spotlight_thumb_*.jpg; ffmpegthumbnailer -i " + root.shellQuote(p) + " -o " + root.shellQuote(thumbPath) + " -s 400 2>/dev/null"];
            _videoThumb.running = true;
        } else if (audioExts.indexOf(ext) !== -1) {
            root.previewKind = "audio"; root.previewPath = p;
            const coverPath = "/tmp/spotlight_cover_" + Date.now() + ".jpg";
            root._pendingThumbPath = coverPath; root._pendingFor = p;
            _audioCover.command = ["bash", "-c", "rm -f /tmp/spotlight_cover_*.jpg; ffmpeg -y -i " + root.shellQuote(p) + " -an -vcodec copy " + root.shellQuote(coverPath) + " 2>/dev/null"];
            _audioCover.running = true;
        } else {
            root.previewKind = ""; root.previewPath = ""; root.previewText = "";
        }
    }

    Timer { id: _previewDeb; interval: 120; repeat: false; onTriggered: root.updatePreview() }

    function computeResultsHeight() {
        const maxH = Math.round(root.screen.height * 0.65);
        if (!root.hasBody) return 0;
        if (root.mode === "apps") {
            const cols = 2;
            const rows = Math.max(1, Math.ceil(root.items.length / cols));
            let h = Math.min(8, rows) * root.rowH + 16;
            return Math.min(maxH, h);
        }
        let h = 12;
        if (root.nowPlayingText.length > 0 && root.query.length === 0 && root.mode === "search") h += root.nowPlayingH;
        for (const r of root.results) h += r.isHeader ? root.headerH : root.rowH;
        if (root.items.length === 0 && root.query.length > 0) h += 56;
        if (root.selectedItem !== null && root.mode !== "apps") h += root.stripH + 1;
        return Math.min(maxH, Math.max(48, h + root.footerH + 12));
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function openPath(p) {
        const e = (p || "~").replace(/^~\/?$/, "$HOME").replace(/^~\//, "$HOME/");
        SpotlightController.run("mkdir -p " + root.shellQuote(e) + "; xdg-open " + root.shellQuote(e));
    }

    function evalMath(q) {
        if (!/^[0-9+\-*/%.()\s]+$/.test(q)) return null;
        try {
            const r = Function('"use strict";return (' + q + ')')();
            if (typeof r !== "number" || !isFinite(r)) return null;
            return r;
        } catch (e) { return null; }
    }

    function buildResults() {
        const q = root.query.trim();
        const ql = q.toLowerCase();
        const items = [];
        const disp = [];
        const addItems = (arr, title) => {
            if (!arr.length) return;
            if (title) disp.push({ isHeader: true, title: title });
            for (const it of arr) { it._idx = items.length; items.push(it); disp.push(it); }
        };
        const m = root.mode;

        // ── Slash Commands ──
        if (ql.startsWith("/")) {
            const full = ql.slice(1);
            const spaceIdx = full.indexOf(" ");
            const cmdName = spaceIdx >= 0 ? full.slice(0, spaceIdx) : full;
            const cmdArgs = spaceIdx >= 0 ? full.slice(spaceIdx + 1).trim() : "";

            if (cmdName === "web" && cmdArgs.length > 0) {
                addItems([{ kind: "action", name: "Search the Web for \u201c" + cmdArgs + "\u201d", action: "web:" + cmdArgs, iconKey: "web", category: "Search" }], "WEB SEARCH");
                root.items = items; root.results = disp; root.selectedIndex = 0; return;
            }
            if (cmdName === "calc" && cmdArgs.length > 0) {
                const cr = root.evalMath(cmdArgs);
                if (cr !== null) addItems([{ kind: "calc", name: "= " + cr, raw: cmdArgs, category: "Calculator", iconKey: "calc" }], "CALCULATOR");
                root.items = items; root.results = disp; root.selectedIndex = 0; return;
            }

            const allCmds = [
                { kind: "cmd", name: "/apps",      category: "Switch to Applications", action: "mode:apps" },
                { kind: "cmd", name: "/files",     category: "Switch to Files",        action: "mode:files" },
                { kind: "cmd", name: "/clipboard", category: "Switch to Clipboard",    action: "mode:clipboard" },
                { kind: "cmd", name: "/actions",   category: "Switch to Actions",      action: "mode:actions" },
                { kind: "cmd", name: "/emoji",     category: "Abrir seletor de emoji", action: "emoji:" },
                { kind: "cmd", name: "/wallpaper", category: "Trocar wallpaper (ii)",  action: "ipc:wallpaperSelector:toggle" },
                { kind: "cmd", name: "/tema",      category: "Alternar tema claro/escuro (ii)", action: "ipc:theme:toggleLightDark" },
                { kind: "cmd", name: "/barra",     category: "Mostrar/esconder a barra (ii)", action: "ipc:bar:toggle" },
                { kind: "cmd", name: "/lock",      category: "Lock Screen",            action: "sys:lock" },
                { kind: "cmd", name: "/sleep",     category: "Sleep",                  action: "sys:sleep" },
                { kind: "cmd", name: "/restart",   category: "Restart",                action: "sys:restart" },
                { kind: "cmd", name: "/shutdown",  category: "Shut Down",              action: "sys:shutdown" },
                { kind: "cmd", name: "/logout",    category: "Log Out",                action: "sys:logout" },
                { kind: "cmd", name: "/web",       category: "Search the Web",         action: "web:" },
                { kind: "cmd", name: "/calc",      category: "Calculator",             action: "calc:" },
            ];
            const filtered = cmdName.length > 0
                ? allCmds.filter(c => c.name.slice(1).toLowerCase().startsWith(cmdName))
                : allCmds;
            addItems(filtered, "COMMANDS");
            root.items = items; root.results = disp; root.selectedIndex = 0; return;
        }

        if (m === "apps") {
            const list = ql ? SpotlightApps.search(q) : SpotlightApps.apps;
            addItems(list.slice(0, 60).map(a => ({ kind: "app", name: a.name, icon: a.icon, exec: a.exec, category: a.category || "Application" })), ql ? "APPLICATIONS" : "");
            root.items = items; root.results = disp; root.selectedIndex = 0; return;
        }
        if (m === "files") {
            addItems(root.recentItems.map(f => ({ kind: "file", name: f.name, path: f.path, category: f.dir })), ql ? "FILES" : "RECENT FILES");
            root.items = items; root.results = disp; root.selectedIndex = 0; return;
        }
        if (m === "clipboard") {
            addItems(root.clipItems.map(c => ({ kind: "clip", name: c.text, text: c.text, category: "Clipboard" })), "CLIPBOARD");
            root.items = items; root.results = disp; root.selectedIndex = 0; return;
        }
        if (m === "actions") {
            const acts = [];
            const A = (name, act, key, cat) => acts.push({ kind: "action", name: name, action: act, iconKey: key, category: cat || "Actions" });
            A("Send Message", "action:msg", "message", "Actions");
            A("Create Note", "action:note", "note", "Actions");
            A("Start Timer", "action:timer", "timer", "Actions");
            A("Run Shortcut", "action:shortcut", "shortcut", "Actions");
            A("Lock Screen", "lock", "lock", "System");
            A("Sleep", "sleep", "moon", "System");
            A("Restart\u2026", "restart", "restart", "System");
            A("Shut Down\u2026", "shutdown", "power", "System");
            A("Log Out", "logout", "logout", "System");
            addItems(acts, "ACTIONS");
            root.items = items; root.results = disp; root.selectedIndex = 0; return;
        }

        // ── NOVO: Now Playing aparece na tela inicial (query vazia) ──
        if (!ql && root.nowPlayingText.length > 0) {
            addItems([{ kind: "media", name: root.nowPlayingText, category: root.nowPlayingStatus === "Playing" ? "Tocando agora" : "Pausado" }], "NOW PLAYING");
        }

        if (ql) {
            const apps = SpotlightApps.search(q);
            addItems(apps.map(a => ({ kind: "app", name: a.name, icon: a.icon, exec: a.exec, category: a.category || "Application" })), "APPLICATIONS");
        }
        if (ql && root.fileItems.length) addItems(root.fileItems.map(f => ({ kind: "file", name: f.name, path: f.path, category: f.dir })), "FILES");

        // ── NOVO: Clima ──
        if (ql && (ql.startsWith("clima") || ql.startsWith("weather")) && root.weatherText) {
            addItems([{ kind: "info", name: root.weatherText, category: "Clima" }], "CLIMA");
        }

        // ── NOVO: Dicionário ──
        if (ql && (ql.startsWith("define ") || ql.startsWith("significado ")) && root.dictText) {
            addItems([{ kind: "info", name: root.dictText, category: "Definição" }], "DEFINIÇÃO");
        }

        // ── NOVO: "toque <algo>" abre e toca no Spotify ──
        const playMatch = q.match(/^(toque|tocar|play)\s+(.+)$/i);
        if (playMatch) {
            addItems([{ kind: "action", name: "Tocar \u201c" + playMatch[2] + "\u201d no Spotify", action: "spotifyplay:" + playMatch[2], iconKey: "music", category: "Spotify" }], "SPOTIFY");
        }

        // ── NOVO: Timer real ──
        const timerMatch = ql.match(/^timer\s+(\d+)\s*(min|m|s|seg|h)?$/);
        if (timerMatch) {
            const n = parseInt(timerMatch[1]);
            const unit = timerMatch[2] || "min";
            let secs = n * 60;
            if (unit === "s" || unit === "seg") secs = n;
            else if (unit === "h") secs = n * 3600;
            addItems([{ kind: "action", name: "Iniciar timer de " + n + " " + unit, action: "realtimer:" + secs, iconKey: "timer", category: "Timer" }], "TIMER");
        }

        const sys = [];
        if (ql && "lock screen sleep restart shut down log out".includes(ql)) {
            sys.push({ kind: "action", name: "Lock Screen", action: "lock", iconKey: "lock", category: "System" });
            sys.push({ kind: "action", name: "Sleep", action: "sleep", iconKey: "moon", category: "System" });
            sys.push({ kind: "action", name: "Restart\u2026", action: "restart", iconKey: "restart", category: "System" });
            sys.push({ kind: "action", name: "Shut Down\u2026", action: "shutdown", iconKey: "power", category: "System" });
            sys.push({ kind: "action", name: "Log Out", action: "logout", iconKey: "logout", category: "System" });
        }
        addItems(sys, "SYSTEM");
        if (ql) {
            const mm = root.evalMath(q);
            if (mm !== null) {
                addItems([{ kind: "calc", name: "= " + mm, raw: q, category: "Calculator", iconKey: "calc" }], "CALCULATOR");
            } else {
                const cv = root.convertUnits(q);
                if (cv !== null) addItems([{ kind: "calc", name: "= " + cv, raw: q, category: "Conversão", iconKey: "calc" }], "CONVERSÃO");
            }
            const isUrl = /^(https?:\/\/)?([\w-]+\.)+[a-z]{2,}(\/\S*)?$/i.test(q.trim());
            const searchActions = [];
            if (isUrl) {
                const target = /^https?:\/\//i.test(q.trim()) ? q.trim() : "https://" + q.trim();
                searchActions.push({ kind: "action", name: "Open " + q.trim(), action: "open:" + target, iconKey: "web", category: "Search" });
            }
            searchActions.push({ kind: "action", name: "Search the Web for \u201c" + q + "\u201d", action: "web:" + q, iconKey: "web", category: "Search" });
            searchActions.push({ kind: "action", name: "Search in Files", action: "filesearch:" + q, iconKey: "finder", category: "Search" });
            addItems(searchActions, "SEARCH");
        }
        root.items = items; root.results = disp; root.selectedIndex = 0;
    }

    function setMode(m) {
        root.mode = m;
        root.selectedIndex = 0;
        if (m === "files" && root.recentItems.length === 0) runRecents();
        if (m === "clipboard" && root.clipItems.length === 0) runClip();
        root.buildResults();
    }

    function runRecents() { _recents.running = true; }
    function runClip() { _clip.running = true; }

    function moveSelection(delta) {
        if (root.items.length === 0) return;
        root.selectedIndex = (root.selectedIndex + delta + root.items.length) % root.items.length;
    }

    function openSelected() {
        const e = root.items[root.selectedIndex];
        if (!e) return;
        if (e.kind === "app") SpotlightApps.launch(e.exec);
        else if (e.kind === "file") SpotlightController.run("xdg-open " + root.shellQuote(e.path));
        else if (e.kind === "clip") SpotlightController.run("echo -n " + root.shellQuote(e.text) + " | wl-copy 2>/dev/null || true");
        else if (e.kind === "calc") SpotlightController.run("echo -n " + root.shellQuote(e.raw) + " | wl-copy 2>/dev/null || true");
        else if (e.kind === "media") { SpotlightController.run("playerctl play-pause"); return; }
        else if (e.kind === "info") { /* clima / dicionário: só mostra, não faz nada ao abrir */ return; }
        else if (e.kind === "action") {
            if (e.action.startsWith("open:")) SpotlightController.run("xdg-open '" + e.action.slice(5) + "'");
            else if (e.action.startsWith("web:")) SpotlightController.run("xdg-open 'https://www.google.com/search?q=" + encodeURIComponent(e.action.slice(4)) + "'");
            else if (e.action.startsWith("filesearch:")) root.openPath("~");
            else if (e.action.startsWith("spotifyplay:")) {
                const term = e.action.slice(12);
                const encoded = encodeURIComponent(term);
                SpotlightController.run(
                    "pgrep -f spotify >/dev/null || (flatpak run com.spotify.Client & ); " +
                    "sleep 1.2; xdg-open 'spotify:search:" + encoded + "' 2>/dev/null; " +
                    "sleep 1.8; wtype -k Return 2>/dev/null || true"
                );
            }
            else if (e.action.startsWith("realtimer:")) {
                const secs = e.action.slice(10);
                SpotlightController.run("(sleep " + secs + " && notify-send 'Spotlight Timer' 'Tempo esgotado!') &");
                SpotlightController.run("notify-send 'Spotlight Timer' 'Timer iniciado (" + secs + "s)'");
            }
            else if (e.action.startsWith("action:")) {
                const sub = e.action.slice(7);
                if (sub === "msg") SpotlightController.run("xdg-open 'https://messages.google.com/web' 2>/dev/null || true");
                else if (sub === "note") SpotlightController.run("xdg-open 'obsidian://new' 2>/dev/null || true");
                else if (sub === "timer") SpotlightController.run("notify-send 'Timer' '5 minutes' 2>/dev/null || true");
                else if (sub === "shortcut") SpotlightController.run("xdg-open 'shortcuts://' 2>/dev/null || true");
                else SpotlightController.requestAction(e.action);
            }
            else SpotlightController.requestAction(e.action);
        }
        else if (e.kind === "cmd") {
            if (e.action.startsWith("mode:")) {
                searchField.text = "";
                root.query = "";
                root.setMode(e.action.slice(5));
                return;
            } else if (e.action.startsWith("sys:")) {
                SpotlightController.requestAction(e.action.slice(4));
            } else if (e.action === "emoji:") {
                const em = SpotlightApps.apps.find(a => a.name.toLowerCase().indexOf("emoji") !== -1);
                if (em) SpotlightApps.launch(em.exec);
                else SpotlightController.run("rofimoji 2>/dev/null || wtype 2>/dev/null || true");
            } else if (e.action.startsWith("ipc:")) {
                const parts = e.action.split(":");
                SpotlightController.run("qs -c ii ipc call " + parts[1] + " " + parts[2]);
            } else if (e.action === "web:" || e.action === "calc:") {
                if (!searchField.text.endsWith(" ")) searchField.text = searchField.text + " ";
                searchField.cursorPosition = searchField.text.length;
                searchField.forceActiveFocus();
                return;
            }
        }
        SpotlightController.spotlightOpen = false;
    }

    property var selectedItem: (root.items.length ? root.items[root.selectedIndex] : null)
    onSelectedItemChanged: _previewDeb.restart()

    Connections {
        target: SpotlightController
        function onSpotlightOpenChanged() {
            if (SpotlightController.spotlightOpen) {
                root._opened = true;
                root._shown = true;
                root.query = "";
                root.mode = "search";
                root.selectedIndex = 0;
                searchField.text = "";
                root.circlesVisible = false;
                root.buildResults();
                openAnim.start();
                Qt.callLater(() => searchField.forceActiveFocus());
            } else {
                root._opened = false;
                closeAnim.start();
            }
        }
    }

    Connections {
        target: SpotlightApps
        function onReadyChanged() {
            if (SpotlightController.spotlightOpen) root.buildResults();
        }
    }

    SequentialAnimation {
        id: openAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "panelScale"; to: 1.0; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: root; property: "panelYOffset"; to: 0; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "panelOpacity"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "panelScale"; to: 0.92; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "panelYOffset"; to: 15; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "panelOpacity"; to: 0.0; duration: 150; easing.type: Easing.InCubic }
        }
        ScriptAction { script: {
            root._shown = false; root.circlesVisible = false;
            if (root.previewAudioPlaying) { SpotlightController.run("pkill -f 'mpv --no-video --really-quiet' 2>/dev/null || true"); root.previewAudioPlaying = false; }
        } }
    }

    // Main Wrapping Container with Fixed Panel Width (Matching SpotlightSearchBar canvas)
    Item {
        id: outerWrap
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(root.screen.height * 0.32) + root.panelYOffset
        width: root.panelWidth
        height: root.searchH + (root.hasBody ? root.computeResultsHeight() + 10 : 0)
        transformOrigin: Item.Top
        scale: root.panelScale
        opacity: root.panelOpacity

        // ── 1. Spotlight Search Bar Header with Morph Surface ──
        Item {
            id: searchHeader
            anchors.left: parent.left
            anchors.top: parent.top
            width: parent.width
            height: root.searchH

            Rectangle {
                anchors.fill: parent
                radius: root.panelRadius
                color: root.glassBg
                z: -2
            }

            SpotlightModeMorphSurface {
                id: morphSurface
                anchors.fill: parent
                railProgress: root.railProgress
                mainLeft: 0
                collapsedMainWidth: root.panelWidth
                expandedMainWidth: root.panelWidth - 4 * (root.circleSize + root.circlesGap)
                shapeCenterY: root.searchH / 2
                shapeHeight: root.searchH
                buttonDiameter: root.circleSize
                buttonGap: root.circlesGap
                blurEdgeInset: 2
                surfaceColor: root.glassBg
                shadowColor: Qt.rgba(0, 0, 0, 0.45)
                z: -1
                Rectangle {
                	anchors.fill: parent
                	// radius: root.panelRadius
                    radius: 12
                	color: root.glassBg
                	z: -2
                }
            }

            // Search Input Content Area (Contracts from panelWidth to expandedMainWidth as railProgress expands)
            Item {
                id: searchInputContent
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: morphSurface.mainWidth
                clip: true

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16

                    Item {
                        id: searchIconWrap
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20; height: 20

                        Canvas {
                            anchors.fill: parent
                            property bool isSlash: root.slashMode
                            onIsSlashChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d"); ctx.reset()
                                ctx.lineWidth = 1.8; ctx.lineCap = "round"; ctx.lineJoin = "round"
                                if (root.slashMode) {
                                    ctx.strokeStyle = root.accent
                                    ctx.beginPath(); ctx.moveTo(6, 4); ctx.lineTo(14, 10); ctx.lineTo(6, 16); ctx.stroke()
                                } else {
                                    ctx.strokeStyle = root.sFgDim
                                    ctx.beginPath(); ctx.arc(8, 8, 6, 0, Math.PI * 2); ctx.stroke()
                                    ctx.beginPath(); ctx.moveTo(12.5, 12.5); ctx.lineTo(17, 17); ctx.stroke()
                                }
                            }
                        }
                    }

                    TextInput {
                        id: searchField
                        anchors.left: searchIconWrap.right; anchors.leftMargin: 12
                        anchors.right: clearBtn.left; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        color: root.sFg
                        font { family: "SF Pro Display"; pixelSize: 20; weight: Font.Normal }
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true; clip: true; cursorVisible: root._opened
                        focus: true
                        onActiveFocusChanged: {
                            if (activeFocus) root.circlesLocked = false
                        }
                        Keys.onUpPressed: (event) => { root.moveSelection(-1); event.accepted = true }
                        Keys.onDownPressed: (event) => { root.moveSelection(1); event.accepted = true }
                        Keys.onReturnPressed: (event) => { root.openSelected(); event.accepted = true }
                        Keys.onEscapePressed: (event) => { SpotlightController.spotlightOpen = false; event.accepted = true }
                        Keys.onTabPressed: (event) => { root.circlesVisible = !root.circlesVisible; event.accepted = true }
                        Keys.onPressed: (event) => {
                            if (event.modifiers & Qt.ControlModifier) {
                                if (event.key === Qt.Key_1) { root.setMode("apps"); event.accepted = true; }
                                else if (event.key === Qt.Key_2) { root.setMode("files"); event.accepted = true; }
                                else if (event.key === Qt.Key_3) { root.setMode("actions"); event.accepted = true; }
                                else if (event.key === Qt.Key_4) { root.setMode("clipboard"); event.accepted = true; }
                            }
                        }
                        onTextChanged: {
                            root.query = text; root.buildResults(); _fdDeb.restart();
                            root.checkWeather(); root.checkDefine();
                            if (text.length > 0) root.circlesVisible = false
                        }
                    }

                    Text {
                        anchors.left: searchIconWrap.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        text: root.placeholderText
                        font { family: "SF Pro Display"; pixelSize: 20; weight: Font.Normal }
                        color: root.placeholderFg
                        visible: searchField.text.length === 0
                    }

                    Rectangle {
                        id: clearBtn
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: 20; height: 20; radius: 10
                        color: clearMA.containsMouse ? Qt.rgba(255, 255, 255, 0.25) : "transparent"
                        visible: root.query.length > 0
                        Canvas {
                            anchors.centerIn: parent; width: 14; height: 14
                            onPaint: {
                                var ctx = getContext("2d"); ctx.reset()
                                ctx.strokeStyle = Qt.rgba(255, 255, 255, 0.85); ctx.lineWidth = 1.4
                                ctx.beginPath(); ctx.arc(width/2, height/2, width/2 - 1, 0, Math.PI * 2); ctx.stroke()
                                ctx.beginPath(); ctx.moveTo(width*0.35, height*0.35); ctx.lineTo(width*0.65, height*0.65)
                                ctx.moveTo(width*0.65, height*0.35); ctx.lineTo(width*0.35, height*0.65); ctx.stroke()
                            }
                        }
                        MouseArea { id: clearMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { searchField.text = ""; root.query = ""; root.buildResults(); searchField.forceActiveFocus() }
                        }
                    }
                }
            }

            // ── 4 Mode Circle Buttons (Emerging directly inside searchHeader from contracted space) ──
            Item {
                id: circlesContainer
                anchors.fill: parent
                visible: root.railProgress > 0.001
                z: 300

                Repeater {
                    model: [
                        { m: "apps",      tip: "Applications", icon: "/home/revo/Downloads/iiii/extracted/oooo/assets/swiftassets/sf_symbold/spotlight/func.png" },
                        { m: "files",     tip: "Files",        icon: "/home/revo/Downloads/iiii/extracted/oooo/assets/swiftassets/sf_symbold/spotlight/conf.png" },
                        { m: "actions",   tip: "Actions",      icon: "/home/revo/Downloads/iiii/glass_effect/spotlight.png" },
                        { m: "clipboard", tip: "Clipboard",    icon: "/home/revo/Downloads/iiii/extracted/oooo/assets/swiftassets/sf_symbold/spotlight/fr.png" }
                    ]

                    delegate: Item {
                        id: circleBtn
                        width: root.circleSize; height: root.circleSize
                        property real growth: morphSurface.buttonGrowth(index)
                        property real iconAlpha: morphSurface.iconProgress(index)
                        property bool isActive: root.mode === modelData.m
                        property bool isHover: circleMA.containsMouse

                        x: morphSurface.buttonCenterX(index) - root.circleSize / 2
                        y: morphSurface.shapeCenterY - root.circleSize / 2
                        scale: growth
                        opacity: iconAlpha

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: circleBtn.isActive ? Qt.rgba(255, 255, 255, 0.28)
                                 : circleBtn.isHover ? Qt.rgba(255, 255, 255, 0.16)
                                 : "transparent"
                            border.color: circleBtn.isActive ? Qt.rgba(255, 255, 255, 0.45)
                                        : circleBtn.isHover ? Qt.rgba(255, 255, 255, 0.25)
                                        : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 34; height: 34
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Rectangle {
                            anchors.top: parent.bottom; anchors.topMargin: 8
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tipText.width + 12; height: 20; radius: 6
                            color: Qt.rgba(20, 20, 25, 0.75)
                            border.color: Qt.rgba(255, 255, 255, 0.3)
                            border.width: 1
                            visible: circleBtn.isHover
                            opacity: circleBtn.isHover ? 1.0 : 0.0
                            scale: circleBtn.isHover ? 1.0 : 0.8
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                            Text {
                                id: tipText
                                anchors.centerIn: parent
                                text: modelData.tip
                                font { family: "SF Pro Display"; pixelSize: 10; weight: Font.Medium }
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            id: circleMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                if (modelData.m === "apps") root.placeholderText = "Applications"
                                else if (modelData.m === "files") root.placeholderText = "Files"
                                else if (modelData.m === "actions") root.placeholderText = "Actions"
                                else if (modelData.m === "clipboard") root.placeholderText = "Clipboard"
                            }
                            onExited: {
                                root.placeholderText = "Spotlight Search"
                                if (!root.circlesLocked) {
                                    root.lockedCircleIndex = -1
                                }
                            }
                            onClicked: {
                                root.circlesLocked = true
                                root.lockedCircleIndex = index
                                root.circlesVisible = false
                                if (root.mode === modelData.m) root.setMode("search")
                                else root.setMode(modelData.m)
                            }
                        }
                    }
                }
            }

            // ── Interactive Drag & Swipe Mouse Handle Zone ──
            MouseArea {
                id: dragZone
                anchors.right: searchHeader.right
                anchors.top: searchHeader.top
                anchors.bottom: searchHeader.bottom
                width: 60
                hoverEnabled: true
                cursorShape: Qt.SplitHCursor
                z: 50

                property real startMouseX: 0
                property real startProgress: 0
                property bool isDragging: false

                onEntered: { if (!root.circlesLocked && !isDragging) root.circlesVisible = true }
                onExited: { if (!isDragging && !root.circlesLocked && !searchField.activeFocus) root.circlesVisible = false }

                onPressed: (mouse) => {
                    startMouseX = mouse.x
                    startProgress = root.railProgress
                    isDragging = true
                    _railAnim.stop()
                }

                onPositionChanged: (mouse) => {
                    if (isDragging) {
                        var delta = mouse.x - startMouseX
                        var maxDist = root.circleSize * 4 + root.circlesGap * 4
                        var targetP = Math.max(0, Math.min(1, startProgress + delta / maxDist))
                        root.railProgress = targetP
                    }
                }

                onReleased: (mouse) => {
                    if (isDragging) {
                        isDragging = false
                        if (root.railProgress > 0.25) {
                            root.circlesVisible = true
                            root.animateRail(1.0)
                        } else {
                            root.circlesVisible = false
                            root.animateRail(0.0)
                        }
                    }
                }
            }
        }

        // ── 2. Results Glass Card Panel ──
        Rectangle {
            id: resultsCard
            anchors.top: searchHeader.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.computeResultsHeight()
            visible: root.hasBody && height > 0
            radius: root.panelRadius
            color: root.glassBg
            border.color: root.glassBorder
            border.width: 1
            clip: true

            Behavior on height {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: root.panelRadius - 1
                color: "transparent"
                border.color: root.glassHighlight
                border.width: 1
                opacity: root.glassSpecular
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ── NOVO: Now Playing ──
                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: root.nowPlayingH
                    Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 4
                    visible: root.nowPlayingText.length > 0 && root.query.length === 0 && root.mode === "search"
                    spacing: 10

                    Text { text: "\u266A"; color: root.accent; font.pixelSize: 18 }
                    Text {
                        Layout.fillWidth: true; text: root.nowPlayingText; color: root.sFg
                        font { family: "SF Pro Display"; pixelSize: 13 }
                        elide: Text.ElideRight; maximumLineCount: 1
                    }
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: prevMA.containsMouse ? root.hoverBg : "transparent"
                        Text { anchors.centerIn: parent; text: "\u23ee"; color: root.sFg; font.pixelSize: 13 }
                        MouseArea {
                            id: prevMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { _mediaCmd.command = ["bash", "-c", "playerctl previous"]; _mediaCmd.running = true; }
                        }
                    }
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: playPauseMA.containsMouse ? root.hoverBg : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: root.nowPlayingStatus === "Playing" ? "\u23f8" : "\u25b6"
                            color: root.sFg
                        }
                        MouseArea {
                            id: playPauseMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { _mediaCmd.command = ["bash", "-c", "playerctl play-pause"]; _mediaCmd.running = true; }
                        }
                    }
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: nextMA.containsMouse ? root.hoverBg : "transparent"
                        Text { anchors.centerIn: parent; text: "\u23ed"; color: root.sFg; font.pixelSize: 13 }
                        MouseArea {
                            id: nextMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { _mediaCmd.command = ["bash", "-c", "playerctl next"]; _mediaCmd.running = true; }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true

                    ListView {
                        id: resultList
                        visible: root.mode !== "apps"
                        anchors.fill: parent; anchors.topMargin: 4; anchors.bottomMargin: 4; anchors.leftMargin: 8; anchors.rightMargin: 8
                        model: root.results; spacing: 2; boundsBehavior: Flickable.StopAtBounds; clip: true

                        delegate: Item {
                            required property var modelData
                            width: resultList.width
                            height: modelData.isHeader === true ? root.headerH : root.rowH

                            Text {
                                visible: modelData.isHeader === true
                                anchors.left: parent.left; anchors.leftMargin: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                                text: modelData.title || ""
                                font { family: "SF Pro Display"; pixelSize: 10; weight: Font.DemiBold }
                                color: root.headerFg
                            }

                            Rectangle {
                                visible: modelData.isHeader !== true
                                anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4
                                radius: 8
                                color: {
                                    if (root.selectedIndex === modelData._idx) return root.selectionBg;
                                    if (rowHover.containsMouse) return root.hoverBg;
                                    return "transparent";
                                }
                                border.color: root.selectedIndex === modelData._idx ? Qt.rgba(255, 255, 255, 0.4) : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }

                            RowLayout {
                                visible: modelData.isHeader !== true
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 10

                                Image {
                                    visible: modelData.kind === "app"
                                    Layout.preferredWidth: root.iconSize; Layout.preferredHeight: root.iconSize; Layout.alignment: Qt.AlignVCenter
                                    source: modelData.icon || ""
                                    sourceSize { width: root.iconSize * 2; height: root.iconSize * 2 }
                                    asynchronous: true; smooth: true
                                }

                                Item {
                                    visible: modelData.kind !== "app"
                                    Layout.preferredWidth: root.iconSize; Layout.preferredHeight: root.iconSize; Layout.alignment: Qt.AlignVCenter
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 0; Layout.alignment: Qt.AlignVCenter
                                    Text {
                                        Layout.fillWidth: true; text: modelData.name || ""
                                        font { family: "SF Pro Display"; pixelSize: 13; weight: Font.Normal }
                                        color: root.sFg
                                        elide: Text.ElideRight; maximumLineCount: 1
                                        wrapMode: modelData.kind === "info" ? Text.Wrap : Text.NoWrap
                                    }
                                    Text {
                                        Layout.fillWidth: true; visible: !!modelData.category && modelData.category.length > 0
                                        text: modelData.category || ""
                                        font { family: "SF Pro Text"; pixelSize: 11; weight: Font.Normal }
                                        color: root.sFgDim
                                        elide: Text.ElideRight; maximumLineCount: 1
                                    }
                                }
                            }

                            MouseArea {
                                visible: modelData.isHeader !== true; id: rowHover
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: root.selectedIndex = modelData._idx
                                onClicked: { root.selectedIndex = modelData._idx; root.openSelected() }
                            }
                        }
                        onCountChanged: { if (root.selectedIndex >= root.items.length) root.selectedIndex = 0 }
                    }

                    GridView {
                        id: resultGrid
                        visible: root.mode === "apps"
                        anchors.fill: parent; anchors.margins: 6
                        cellWidth: Math.floor(width / 2); cellHeight: 46
                        model: root.items; clip: true

                        delegate: Item {
                            required property var modelData
                            width: resultGrid.cellWidth; height: resultGrid.cellHeight

                            Rectangle {
                                anchors.fill: parent; anchors.margins: 3; radius: 8
                                color: {
                                    if (root.selectedIndex === modelData._idx) return root.selectionBg;
                                    if (gridHover.containsMouse) return root.hoverBg;
                                    return "transparent";
                                }
                                border.color: root.selectedIndex === modelData._idx ? Qt.rgba(255, 255, 255, 0.4) : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 8
                                Image {
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; Layout.alignment: Qt.AlignVCenter
                                    source: modelData.icon || ""; sourceSize { width: 52; height: 52 }
                                    asynchronous: true; smooth: true
                                }
                                Text {
                                    Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                    text: modelData.name || ""
                                    font { family: "SF Pro Display"; pixelSize: 13; weight: Font.Normal }
                                    color: root.sFg
                                    elide: Text.ElideRight; maximumLineCount: 1
                                }
                            }

                            MouseArea { id: gridHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: root.selectedIndex = modelData._idx
                                onClicked: { root.selectedIndex = modelData._idx; root.openSelected() }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent; text: "No Results Found"
                        font { family: "SF Pro Display"; pixelSize: 14; weight: Font.Normal }
                        color: root.sFgDim
                        visible: root.query.length > 0 && root.items.length === 0
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.leftMargin: 12; Layout.rightMargin: 12; color: root.divider; visible: root.selectedItem !== null && root.mode !== "apps" }

                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: root.stripH; Layout.leftMargin: 14; Layout.rightMargin: 14
                    visible: root.selectedItem !== null && root.mode !== "apps"; spacing: 12

                    Item {
                        Layout.preferredWidth: 36; Layout.preferredHeight: 36; Layout.alignment: Qt.AlignVCenter
                        Image {
                            visible: root.selectedItem && root.selectedItem.kind === "app"
                            anchors.fill: parent
                            source: root.selectedItem ? root.selectedItem.icon || "" : ""
                            sourceSize { width: 72; height: 72 }
                            asynchronous: true; smooth: true
                        }
                    }

                    ColumnLayout { Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 1
                        Text { Layout.fillWidth: true; text: root.selectedItem ? root.selectedItem.name || "" : ""
                            font { family: "SF Pro Display"; pixelSize: 13; weight: Font.Medium }
                            color: root.sFg; elide: Text.ElideRight; maximumLineCount: 1 }
                        Text { Layout.fillWidth: true; visible: root.selectedItem && !!root.selectedItem.category
                            text: root.selectedItem ? root.selectedItem.category || "" : ""
                            font { family: "SF Pro Text"; pixelSize: 11; weight: Font.Normal }
                            color: root.sFgDim; elide: Text.ElideRight; maximumLineCount: 1 }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 68; Layout.preferredHeight: 26; Layout.alignment: Qt.AlignVCenter; radius: 8
                        color: openBtnMA.containsMouse ? "#0062cc" : root.accent
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; text: "Open"
                            font { family: "SF Pro Display"; pixelSize: 12; weight: Font.DemiBold }
                            color: "#ffffff" }
                        MouseArea { id: openBtnMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openSelected() }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: root.footerH; Layout.leftMargin: 14; Layout.rightMargin: 14
                    color: "transparent"; visible: root.hasBody
                    Row {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 16
                        Row { spacing: 4
                            Rectangle { width: 18; height: 16; radius: 4; color: Qt.rgba(255,255,255,0.15); border.color: Qt.rgba(255,255,255,0.25); border.width: 1
                                Text { anchors.centerIn: parent; text: "\u2191"; font { family: "SF Pro Text"; pixelSize: 10; weight: Font.Medium } color: root.sFgDim } }
                            Rectangle { width: 18; height: 16; radius: 4; color: Qt.rgba(255,255,255,0.15); border.color: Qt.rgba(255,255,255,0.25); border.width: 1
                                Text { anchors.centerIn: parent; text: "\u2193"; font { family: "SF Pro Text"; pixelSize: 10; weight: Font.Medium } color: root.sFgDim } }
                            Text { text: "Navigate"; font { family: "SF Pro Text"; pixelSize: 10; weight: Font.Normal } color: root.sFgDim; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Row { spacing: 4
                            Rectangle { width: 22; height: 16; radius: 4; color: Qt.rgba(255,255,255,0.15); border.color: Qt.rgba(255,255,255,0.25); border.width: 1
                                Text { anchors.centerIn: parent; text: "\u21a9"; font { family: "SF Pro Text"; pixelSize: 10; weight: Font.Medium } color: root.sFgDim } }
                            Text { text: "Open"; font { family: "SF Pro Text"; pixelSize: 10; weight: Font.Normal } color: root.sFgDim; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Row { spacing: 4
                            Rectangle { width: 28; height: 16; radius: 4; color: Qt.rgba(255,255,255,0.15); border.color: Qt.rgba(255,255,255,0.25); border.width: 1
                                Text { anchors.centerIn: parent; text: "esc"; font { family: "SF Pro Text"; pixelSize: 9; weight: Font.Medium } color: root.sFgDim } }
                            Text { text: "Close"; font { family: "SF Pro Text"; pixelSize: 10; weight: Font.Normal } color: root.sFgDim; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }

        // ── NOVO: Quick Look como popup lateral (lado direito) ──
        Rectangle {
            id: previewPopup
            visible: root.previewKind !== ""
            anchors.left: searchHeader.right
            anchors.leftMargin: 16
            anchors.top: searchHeader.top
            width: root.previewKind === "text" ? 320 : root.previewSize().w
            height: root.previewKind === "text" ? 260 : root.previewSize().h
            radius: root.panelRadius
            color: root.glassBg
            border.color: root.glassBorder
            border.width: 1
            clip: true

            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Image {
                visible: root.previewKind === "image"
                anchors.fill: parent
                anchors.margins: 10
                source: root.previewKind === "image" && root.previewPath ? "file://" + root.previewPath : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                onStatusChanged: if (status === Image.Ready) { root.previewNatW = implicitWidth; root.previewNatH = implicitHeight; }
            }

            ScrollView {
                visible: root.previewKind === "text"
                anchors.fill: parent
                anchors.margins: 12
                clip: true

                Text {
                    width: parent.width
                    text: root.previewText
                    color: root.sFgDim
                    font { family: "monospace"; pixelSize: 10 }
                    wrapMode: Text.Wrap
                }
            }

            // ── Preview de vídeo (miniatura via ffmpegthumbnailer) ──
            Item {
                visible: root.previewKind === "video"
                anchors.fill: parent
                anchors.margins: 10

                Image {
                    id: videoThumbImgPopup
                    anchors.fill: parent
                    source: root.previewThumbPath ? "file://" + root.previewThumbPath : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: status === Image.Ready
                    onStatusChanged: if (status === Image.Ready) { root.previewNatW = implicitWidth; root.previewNatH = implicitHeight; }
                }
                Text {
                    anchors.centerIn: parent
                    text: "\u25b6 V\u00eddeo"
                    color: root.sFgDim
                    visible: videoThumbImgPopup.status !== Image.Ready
                    font { family: "SF Pro Display"; pixelSize: 13 }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 44; height: 44; radius: 22
                    color: Qt.rgba(0, 0, 0, 0.45)
                    visible: videoThumbImgPopup.status === Image.Ready
                    Text { anchors.centerIn: parent; text: "\u25b6"; color: "#ffffff"; font.pixelSize: 18 }
                }
            }

            // ── Preview de áudio (capa via ffmpeg + play/pause via mpv) ──
            Item {
                visible: root.previewKind === "audio"
                anchors.fill: parent
                anchors.margins: 10

                Image {
                    id: audioCoverImgPopup
                    anchors.fill: parent
                    anchors.bottomMargin: 40
                    source: root.previewThumbPath ? "file://" + root.previewThumbPath : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: status === Image.Ready
                    onStatusChanged: if (status === Image.Ready) { root.previewNatW = implicitWidth; root.previewNatH = implicitHeight + 40; }
                }
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -20
                    text: "\u266a"
                    color: root.sFgDim
                    font.pixelSize: 46
                    visible: audioCoverImgPopup.status !== Image.Ready
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 100; height: 30; radius: 15
                    color: audioPlayPopupMA.containsMouse ? Qt.rgba(255, 255, 255, 0.25) : Qt.rgba(255, 255, 255, 0.15)
                    Row {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: root.previewAudioPlaying ? "\u23f8" : "\u25b6"; color: "#ffffff"; font.pixelSize: 13 }
                        Text { text: root.previewAudioPlaying ? "Pausar" : "Tocar"; color: "#ffffff"; font.pixelSize: 11 }
                    }
                    MouseArea {
                        id: audioPlayPopupMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.previewAudioPlaying) {
                                SpotlightController.run("pkill -f 'mpv --no-video --really-quiet' 2>/dev/null || true");
                                root.previewAudioPlaying = false;
                            } else {
                                SpotlightController.run("pkill -f 'mpv --no-video --really-quiet' 2>/dev/null; mpv --no-video --really-quiet " + root.shellQuote(root.previewPath) + " &");
                                root.previewAudioPlaying = true;
                            }
                        }
                    }
                }
            }
        }
    }

    Timer { id: _fdDeb; interval: 140; repeat: false; onTriggered: root.runFd() }

    // ── NOVO: Process dedicado aos botões de mídia (não compartilha fila com o SpotlightController.run) ──
    Process { id: _mediaCmd; running: false }

    // ── NOVO: Poll de Now Playing (mpris via playerctl) ──
    Timer {
        id: _mprisTimer
        interval: 2000; running: root._shown; repeat: true
        triggeredOnStart: true
        onTriggered: _mprisPoll.running = true
    }

    Process {
        id: _mprisPoll; running: false
        command: ["bash", "-c", "playerctl metadata --format '{{status}}|{{artist}} - {{title}}' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                let newText = "", newStatus = "";
                if (t) {
                    const parts = t.split("|");
                    newStatus = parts[0] || "";
                    newText = parts[1] || "";
                }
                if (newText !== root.nowPlayingText || newStatus !== root.nowPlayingStatus) {
                    root.nowPlayingText = newText;
                    root.nowPlayingStatus = newStatus;
                    if (root._shown) root.buildResults();
                }
            }
        }
    }

    Process {
        id: _fd; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(s => s.trim()).filter(Boolean).slice(0, 8);
                const out = [];
                for (const p of lines) {
                    const base = p.split("/").pop();
                    let dir = p.replace(new RegExp("/" + base.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$"), "");
                    out.push({ name: base, path: p, dir: dir || "~" });
                }
                root.fileItems = out; root.buildResults();
            }
        }
    }

    Process {
        id: _recents; running: false
        command: ["bash", "-c", "fd -t f -H --changed-within 60d -E .git -d 6 ~ 2>/dev/null | head -40"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(s => s.trim()).filter(Boolean);
                const out = [];
                for (const p of lines) {
                    const base = p.split("/").pop();
                    let dir = p.replace(new RegExp("/" + base.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$"), "");
                    out.push({ name: base, path: p, dir: dir || "~" });
                }
                root.recentItems = out; if (root.mode === "files") root.buildResults();
            }
        }
    }

    Process {
        id: _clip; running: false
        command: ["bash", "-c", "cliphist list 2>/dev/null | tail -n 30"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(s => s.trim()).filter(Boolean);
                const out = [];
                for (const l of lines) {
                    const t = l.replace(/^\d+\t/, "");
                    if (t) out.push({ text: t.length > 120 ? t.slice(0, 120) + "\u2026" : t });
                }
                root.clipItems = out; if (root.mode === "clipboard") root.buildResults();
            }
        }
    }

    // ── NOVO: Clima ──
    Process {
        id: _weather; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.weatherText = text.trim();
                if (root._shown) root.buildResults();
            }
        }
    }

    // ── NOVO: Dicionário ──
    Process {
        id: _dict; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let def = "";
                try {
                    const data = JSON.parse(text);
                    def = (data[0] && data[0].meanings && data[0].meanings[0] && data[0].meanings[0].definitions && data[0].meanings[0].definitions[0] && data[0].meanings[0].definitions[0].definition) || "";
                } catch (e) { def = ""; }
                root.dictText = def;
                if (root._shown) root.buildResults();
            }
        }
    }

    // ── NOVO: Quick Look (preview de texto) ──
    Process {
        id: _preview; running: false
        stdout: StdioCollector {
            onStreamFinished: { root.previewText = text; }
        }
    }

    // ── NOVO: Quick Look (miniatura de vídeo) ──
    Process {
        id: _videoThumb; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.previewPath === root._pendingFor && root.previewKind === "video") root.previewThumbPath = root._pendingThumbPath;
            }
        }
    }

    // ── NOVO: Quick Look (capa de álbum do áudio) ──
    Process {
        id: _audioCover; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.previewPath === root._pendingFor && root.previewKind === "audio") root.previewThumbPath = root._pendingThumbPath;
            }
        }
    }

    Component.onCompleted: root.buildResults()
}
