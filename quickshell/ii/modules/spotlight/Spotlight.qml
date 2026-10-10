import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtMultimedia
import qs.services
import "./services"


PanelWindow {
    id: root

    // =====================================================================
    //  JANELA
    // =====================================================================
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: root._shown && !root._capturing
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "macos:spotlight"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root._shown
        ? (root._screenshotSelecting ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
        : WlrKeyboardFocus.None

    // =====================================================================
    //  CONFIGURAÇÃO
    // =====================================================================
    property string terminal: "kitty"
    property bool aiAutoQuestion: true
    property bool showSysStats: true
    property string weatherCity: "Itapira"
    property bool aiPersistentHistory: false

    readonly property string hermesUrl: Quickshell.env("HERMES_URL") || "http://127.0.0.1:8642"
    readonly property string hermesKey: Quickshell.env("HERMES_API_KEY") || ""
    readonly property string hermesModel: Quickshell.env("HERMES_MODEL") || "hermes-agent"

    readonly property var bangs: ({
        yt:    ["YouTube",        "https://www.youtube.com/results?search_query="],
        gh:    ["GitHub",         "https://github.com/search?q="],
        maps:  ["Google Maps",    "https://www.google.com/maps/search/"],
        wiki:  ["Wikipédia",      "https://pt.wikipedia.org/w/index.php?search="],
        pt:    ["Wikcionário",    "https://pt.wiktionary.org/w/index.php?search="],
        stack: ["Stack Overflow", "https://stackoverflow.com/search?q="],
        aur:   ["AUR",            "https://aur.archlinux.org/packages?K="],
        aw:    ["ArchWiki",       "https://wiki.archlinux.org/index.php?search="],
        gi:    ["Google Imagens", "https://www.google.com/search?tbm=isch&q="],
        imdb:  ["IMDb",           "https://www.imdb.com/find/?q="],
        ddg:   ["DuckDuckGo",     "https://duckduckgo.com/?q="]
    })

    readonly property var slashCommands: [
        { kind: "cmd", name: "/apps",       category: "Switch to Applications",         action: "mode:apps" },
        { kind: "cmd", name: "/files",      category: "Switch to Files",                action: "mode:files" },
        { kind: "cmd", name: "/clipboard",  category: "Switch to Clipboard",            action: "mode:clipboard" },
        { kind: "cmd", name: "/actions",    category: "Switch to Actions",              action: "mode:actions" },
        { kind: "cmd", name: "/config",     category: "Browse all II settings",         action: "mode:config" },
        { kind: "cmd", name: "/wallpaper",  category: "Change wallpaper (ii)",          action: "ipc:wallpaperSelector:toggle" },
        { kind: "cmd", name: "/theme",       category: "Toggle light/dark theme (ii)",   action: "ipc:theme:toggleLightDark" },
        { kind: "cmd", name: "/bar",        category: "Show/hide bar (ii)",             action: "ipc:bar:toggle" },
        { kind: "cmd", name: "/screen",     category: "Hermes reads everything on screen (OCR + windows)", action: "screen:" },
        { kind: "cmd", name: "/screenshot", category: "Analyze screen with OCR + AI",   action: "screenshot:" },
        { kind: "cmd", name: "/translate",  category: "Translate screen area (OCR + Hermes)", action: "ocrtr:" },
        { kind: "cmd", name: "/record",     category: "Record screen (ii)",             action: "ipc:region:record" },
        { kind: "cmd", name: "/ocr",        category: "Screen OCR (ii)",                action: "ipc:region:ocr" },
        { kind: "cmd", name: "/color",      category: "Color picker (copies hex)",      action: "colorpick:" },
        { kind: "cmd", name: "/windows",    category: "Switch between open windows",    action: "mode:windows" },
        { kind: "cmd", name: "/wifi",       category: "Wi-Fi networks",                 action: "mode:wifi" },
        { kind: "cmd", name: "/bluetooth",  category: "Paired Bluetooth devices",       action: "mode:bluetooth" },
        { kind: "cmd", name: "/search",     category: "Search inside files (ripgrep)",  action: "buscar:" },
        { kind: "cmd", name: "/ai",         category: "Ask Hermes Agent",               action: "ai:" },
        { kind: "cmd", name: "/new",        category: "New AI conversation",            action: "ai-new:" },
        { kind: "cmd", name: "/note",       category: "Create Obsidian note",           action: "aiintent:note:" },
        { kind: "cmd", name: "/email",      category: "Send email",                     action: "aiintent:email:" },
        { kind: "cmd", name: "/focus",      category: "Focus mode",                     action: "focus:" },
        { kind: "cmd", name: "/meeting",    category: "Meeting mode",                   action: "meeting:" },
        { kind: "cmd", name: "/briefing",   category: "Morning briefing",               action: "briefing:" },
        { kind: "cmd", name: "/git",        category: "Generate git commit message",    action: "git:" },
        { kind: "cmd", name: "/sum",        category: "Summarize a web page or PDF",    action: "sum:" },
        { kind: "cmd", name: "/mem-on",     category: "Enable persistent AI history",   action: "mem-on:" },
        { kind: "cmd", name: "/mem-off",    category: "Disable persistent AI history",  action: "mem-off:" },
        { kind: "cmd", name: "/todo",       category: "Add a ToDo task",                action: "todo:" },
        { kind: "cmd", name: "/event",      category: "Add a calendar event",           action: "todo:" },
        { kind: "cmd", name: "/calendar",   category: "Add a calendar event",           action: "todo:" },
        { kind: "cmd", name: "/notes",      category: "Add a ToDo task",                action: "todo:" },
        { kind: "cmd", name: "/lock",       category: "Lock Screen",                    action: "sys:lock" },
        { kind: "cmd", name: "/sleep",      category: "Sleep",                          action: "sys:sleep" },
        { kind: "cmd", name: "/restart",    category: "Restart",                        action: "sys:restart" },
        { kind: "cmd", name: "/shutdown",   category: "Shut Down",                      action: "sys:shutdown" },
        { kind: "cmd", name: "/logout",     category: "Log Out",                        action: "sys:logout" },
        { kind: "cmd", name: "/web",        category: "Search the Web",                 action: "web:" },
        { kind: "cmd", name: "/calc",       category: "Calculator",                     action: "calc:" }
    ]

    // Intenções estruturadas detectadas em prompts de IA (ordem importa).
    readonly property var _intentRules: [
        ["todo",       s => /(create|add|new|note|task|todo|to-?do|crie|criar|adicionar?|adiciona|nova|novo|anote|anotar)\s+/i.test(s)
                            || /(remind me to|me\s+lembr[ea]r?\s+de)/i.test(s)],
        ["note",       s => /(create|write|save|note|crie|criar|salve|salvar|anote|anotar|nova)\s+/i.test(s)],
        ["email",      s => /(send|write|email|mande|mandar|envi[ae]|enviar|escreva)\s+/i.test(s)
                            || /(email|e-?mail)\s+(to|for|pro?|para)\s+[^\s]+@/i.test(s)],
        ["timer",      s => /(remind me in|timer|pomodoro|count|start|me\s+avise\s+em|pomodoro|conte?|inici[ae]r?)\s+\d+/i.test(s)
                            || /\d+\s+(minute|min|second|sec|hour|h|minuto|min|segundo|seg|hora|h)\b/i.test(s) && /(remind|timer|count|avise|timer|conte?)/i.test(s)],
        ["alias",      s => /(create|new|crie|criar|novo|nova)\s+(a\s+)?(shortcut|atalho)/i.test(s)],
        ["block",      s => /(block|bloqueie|bloquear|bloqueia)\s+([\w.-]+\.\w+)/i.test(s)],
        ["focus",      s => /(focus mode|focus for|modo\s+foco|foco\s+por)/i.test(s)],
        ["meeting",    s => /(going into|in a|start)\s+(a\s+)?(meeting|reuni[ãa]o|modo\s+reuni[ãa]o|iniciar\s+reuni[ãa]o)/i.test(s)],
        ["briefing",   s => /^(good morning|briefing|summary of the day|what do i have today|bom\s+dia|briefing|resumo\s+do\s+dia|o\s+que\s+tenho\s+hoje)\s*[?!.]?$/i.test(s)],
        ["git",        s => /^(git\s+commit|commit|commit message|mensagem\s+de\s+commit)$/i.test(s)],
        ["screenshot", s => /(what|analyze|see|look|read|translate|explain)\s+(is|on|this)\s+(screen|screenshot|capture|image|tela|captura|imagem)/i.test(s)
                            || /(what is on the screen|o\s+que\s+est[áa]\s+na\s+tela)/i.test(s)],
        ["web",        s => /(summarize|analyze|what does)\s+(this|that)?\s*(link|url|site)/i.test(s)
                            || /https?:\/\/\S+/i.test(s) && /(summarize|analyze|what|resuma?|resumir|analise?|analisa|o\s+que)/i.test(s)],
        ["pdf",        s => /(summarize|analyze)\s+(the|this|that)?\s*(pdf|document)/i.test(s)
                            || /(resuma?|resumir|analise?|analisa)\s+(o\s+|esse\s+|esta\s+)?(pdf|documento)/i.test(s)]
    ]

    readonly property var emojiList: [
        { e: "😀", n: "grinning" }, { e: "😃", n: "smiley" }, { e: "😄", n: "smile" },
        { e: "😁", n: "grin" }, { e: "😆", n: "laughing" }, { e: "😅", n: "sweat smile" },
        { e: "😂", n: "joy" }, { e: "🤣", n: "rofl" }, { e: "😊", n: "blush" },
        { e: "😇", n: "innocent" }, { e: "🙂", n: "slight smile" }, { e: "😉", n: "wink" },
        { e: "😍", n: "heart eyes" }, { e: "🥰", n: "smiling hearts" }, { e: "😘", n: "kiss" },
        { e: "😋", n: "yum" }, { e: "😎", n: "sunglasses" }, { e: "🤔", n: "thinking" },
        { e: "😐", n: "neutral" }, { e: "😑", n: "expressionless" }, { e: "😶", n: "no mouth" },
        { e: "🙄", n: "eye roll" }, { e: "😏", n: "smirk" }, { e: "😴", n: "sleeping" },
        { e: "😢", n: "cry" }, { e: "😭", n: "sob" }, { e: "😡", n: "angry" },
        { e: "🤬", n: "cursing" }, { e: "🤯", n: "exploding head" }, { e: "🥶", n: "cold" },
        { e: "🥵", n: "hot" }, { e: "😱", n: "scream" }, { e: "🤪", n: "zany" },
        { e: "👋", n: "wave" }, { e: "👌", n: "ok" }, { e: "✌️", n: "victory" },
        { e: "🤞", n: "crossed fingers" }, { e: "👍", n: "thumbs up" }, { e: "👎", n: "thumbs down" },
        { e: "👏", n: "clap" }, { e: "🙌", n: "raised hands" }, { e: "🤝", n: "handshake" },
        { e: "🙏", n: "pray" }, { e: "💪", n: "muscle" }, { e: "❤️", n: "red heart" },
        { e: "🧡", n: "orange heart" }, { e: "💛", n: "yellow heart" }, { e: "💚", n: "green heart" },
        { e: "💙", n: "blue heart" }, { e: "💜", n: "purple heart" }, { e: "🖤", n: "black heart" },
        { e: "💔", n: "broken heart" }, { e: "✨", n: "sparkles" }, { e: "⭐", n: "star" },
        { e: "🔥", n: "fire" }, { e: "💯", n: "hundred" }, { e: "✅", n: "check" },
        { e: "❌", n: "x" }, { e: "🎉", n: "party" }, { e: "🎊", n: "confetti" },
        { e: "💻", n: "laptop" }, { e: "📱", n: "phone" }, { e: "💡", n: "bulb" },
        { e: "🔒", n: "lock" }, { e: "🔑", n: "key" }, { e: "🎵", n: "music" },
        { e: "📷", n: "camera" }, { e: "🎮", n: "game" }, { e: "🚀", n: "rocket" },
        { e: "☕", n: "coffee" }, { e: "🍕", n: "pizza" }, { e: "🍔", n: "burger" },
        { e: "🐱", n: "cat" }, { e: "🐶", n: "dog" }, { e: "🦊", n: "fox" },
        { e: "🐻", n: "bear" }, { e: "🐼", n: "panda" }, { e: "🐸", n: "frog" }
    ]

    readonly property var _imgExts:   ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"]
    readonly property var _textExts:  ["txt", "md", "json", "qml", "js", "ts", "py", "sh", "conf", "yaml", "yml", "xml", "html", "css", "c", "cpp", "h", "lua", "toml", "ini", "log"]
    readonly property var _videoExts: ["mp4", "mkv", "webm", "avi", "mov", "m4v", "flv"]
    readonly property var _audioExts: ["mp3", "flac", "wav", "ogg", "opus", "m4a", "aac"]

    // =====================================================================
    //  TEMA / GEOMETRIA
    // =====================================================================
    readonly property color glassBg:        Qt.rgba(30 / 255, 30 / 255, 30 / 255, 0.72)
    readonly property color glassBorder:    Qt.rgba(1, 1, 1, 0.12)
    readonly property color glassHighlight: Qt.rgba(1, 1, 1, 0.06)
    readonly property color selectionBg:    Qt.rgba(0.0, 0.48, 1.0, 0.45)
    readonly property color hoverBg:        Qt.rgba(1, 1, 1, 0.08)
    readonly property color divider:        Qt.rgba(1, 1, 1, 0.10)
    readonly property color headerFg:       Qt.rgba(1, 1, 1, 0.45)
    readonly property color sFg:            Qt.rgba(1, 1, 1, 0.92)
    readonly property color sFgDim:         Qt.rgba(1, 1, 1, 0.55)
    readonly property color placeholderFg:  Qt.rgba(1, 1, 1, 0.40)
    readonly property color accent:         "#0A84FF"

    readonly property real panelWidth: 680
    readonly property real panelRadius: 22
    readonly property real searchH: 56
    readonly property real circleSize: 56
    readonly property real circlesGap: 8
    readonly property real rowH: 44
    readonly property real headerH: 22
    readonly property real iconSize: 28
    readonly property real footerH: 0
    readonly property real stripH: 0
    readonly property real nowPlayingH: 46

    // =====================================================================
    //  ESTADO
    // =====================================================================
    // -- Interface / navegação
    property bool _shown: false
    property bool _opened: false
    property bool _capturing: false          // esconde o Spotlight enquanto captura a tela
    property string query: ""
    property string mode: "search"
    property string _pendingMode: ""
    property int selectedIndex: 0
    property bool _userNavigated: false
    property var items: []
    property var results: []
    property string _buildSig: ""
    property var selectedItem: (root.items.length ? root.items[root.selectedIndex] : null)
    readonly property string selectedKey: root.itemKey(root.selectedItem)
    property bool slashMode: root.query.startsWith("/")
    property string placeholderText: "Search or Ask"

    // -- Animação
    property real panelOpacity: 0.0
    property real panelScale: 0.96
    property real panelYOffset: 12
    property bool circlesVisible: false
    property bool circlesLocked: false
    property real railProgress: 0.0
    property bool railOpen: root.railProgress > 0.001

    // -- Dados por modo
    property var fileItems: []
    property var recentItems: []
    property string browseDir: ""
    property var clipItems: []
    property string _clipPrevKey: ""
    property var windowItems: []
    property var wifiItems: []
    property var btItems: []
    property var contentResults: []
    property string _lastContentQuery: ""
    property var procItems: []
    property string _procKey: ""
    property var usageCounts: ({})
    property var _cache: ({})

    // -- Config browser
    property var configItems: []
    property string configPath: ""
    property int configDepth: 0
    property var configStack: []

    // -- Ferramentas inline
    property string nowPlayingText: ""
    property string nowPlayingStatus: ""
    property string sysStatsText: ""
    property string weatherText: ""
    property string _wxLastCity: ""
    property string timeText: ""
    property string _timeKey: ""
    property string dictText: ""
    property string batteryText: ""
    property string ipText: ""
    property string currencyText: ""
    property var _pendingCurrency: null
    property string passText: ""
    property string _passKey: ""
    property int _passWanted: 0
    property var devResult: ({ q: "", text: "", label: "" })
    property string _devQ: ""
    property string _devLabel: ""

    // -- Contadores de requisição (descartam respostas obsoletas)
    property int _fdReq: 0
    property int _rgReq: 0
    property int _psReq: 0
    property int _devReq: 0
    property int _wxReq: 0
    property int _timeReq: 0
    property int _aiReq: 0
    property var _wxGeoXhr: null
    property var _wxDataXhr: null
    property var _timeXhr: null
    property var _aiXhr: null

    // -- Preview
    property string previewPath: ""
    property string previewKind: ""
    property string previewText: ""
    property string previewThumbPath: ""
    property real previewNatW: 0
    property real previewNatH: 0
    property string _previewKeyShown: ""
    property var _pendingPreview: ({ for: "", path: "", kind: "" })
    readonly property bool previewAudioPlaying: audioPlayer.playbackState === MediaPlayer.PlayingState
    readonly property var previewBox: {
        const k = root.previewKind;
        if (k === "text" || k === "markdown") return { w: 420, h: 660 };
        if (k === "pdf" || k === "image" || k === "video") return root.previewSizeLarge();
        return root.previewSize();
    }

    // -- IA
    property string aiText: ""
    property string _lastAiQuery: ""
    property bool aiLoading: false
    property string _pendingAiPrompt: ""
    property int _aiRetries: 0
    property var aiHistory: []
    property bool aiConversationMode: false
    readonly property bool aiErrored: root.aiText.startsWith("Sem resposta")
                                     || root.aiText.startsWith("Hermes Agent:")
                                     || root.aiText.startsWith("Erro ao consultar")

    // -- Captura de tela / OCR
    property bool _screenshotSelecting: false
    property string _ocrMode: "analyze"   // "analyze" | "translate"
    property string _ocrLang: "pt"
    property string _screenQuestion: ""
    property string _resumeFocus: ""

    // -- Altura do corpo (avaliada uma única vez por mudança)
    property bool hasBody: (root.mode !== "search"
            || root.query.length > 0
            || root.items.length > 0
            || root.nowPlayingText.length > 0)
        && !(root.railOpen && root.query.length === 0)
    readonly property real resultsHeight: root.computeResultsHeight()

    // =====================================================================
    //  UTILITÁRIOS BÁSICOS
    // =====================================================================
    function pad2(n) { return n < 10 ? "0" + n : String(n); }
    function hasOwn(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }

    function shellQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
    function urlq(s) { return encodeURIComponent(String(s)).replace(/'/g, "%27"); }

    function xdgOpenCmd(target) {
        return "setsid nohup env XDG_RUNTIME_DIR=/run/user/$(id -u) " +
               "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus " +
               "xdg-open " + root.shellQuote(target) + " </dev/null >/dev/null 2>&1";
    }
    function xdgOpen(target) { SpotlightController.run(root.xdgOpenCmd(target) + " &"); }

    function fileUrl(path) {
        if (!path) return "";
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function openUrl(u) {
        let ok = false;
        try { ok = Qt.openUrlExternally(u); } catch (e) { }
        if (!ok) {
            SpotlightController.run(
                "(" + root.xdgOpenCmd(u) + ") || gio open " + root.shellQuote(u) + " >/dev/null 2>&1 &"
            );
        }
    }

    function copyText(s) {
        SpotlightController.run("printf '%s' " + root.shellQuote(s) + " | wl-copy 2>/dev/null || true");
    }

    function notify(msg, critical) {
        SpotlightController.run("notify-send " + (critical ? "-u critical " : "") + "'Spotlight' " + root.shellQuote(msg));
    }

    function rebuildIfShown() { if (root._shown) root.scheduleRebuild(); }

    function splitPath(p) {
        const i = p.lastIndexOf("/");
        return { name: i >= 0 ? p.slice(i + 1) : p, dir: i > 0 ? p.slice(0, i) : "~" };
    }

    function _msg(role, content, label) {
        return { role: role, content: content, label: label || "", ts: Qt.formatTime(new Date(), "hh:mm") };
    }

    function abortXhr(x) { if (x) { try { x.abort(); } catch (e) { } } }

    function httpJson(url, timeoutMs, cb) {
        const x = new XMLHttpRequest();
        x.timeout = timeoutMs;
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            let data = null;
            try { data = JSON.parse(x.responseText); } catch (e) { data = null; }
            cb(data, x);
        };
        x.open("GET", url);
        x.send();
        return x;
    }

    // -- Cache em memória (mutação in-place, sem copiar o objeto a cada escrita)
    function cacheGet(key, ttlMs) {
        const c = root._cache[key];
        if (!c) return null;
        if (Date.now() - c.t > ttlMs) return null;
        return c.v;
    }

    function cacheSet(key, value) {
        const c = root._cache;
        c[key] = { v: value, t: Date.now() };
        const keys = Object.keys(c);
        if (keys.length > 200) {
            keys.sort((a, b) => c[a].t - c[b].t);
            for (let i = 0; i < keys.length - 150; i++) delete c[keys[i]];
        }
    }

    // -- Contagem de uso (também in-place)
    function itemKey(it) {
        if (!it) return "";
        return it.kind + ":" + (it.path || it.exec || it.address || it.action || it.id || it.text || it.name || "");
    }

    function recordUsage(key) {
        const counts = root.usageCounts;
        counts[key] = (counts[key] || 0) + 1;
        const keys = Object.keys(counts);
        if (keys.length > 600) {
            const fk = keys.filter(k => k.startsWith("file:")).sort((a, b) => counts[a] - counts[b]);
            for (let i = 0; i < keys.length - 500 && i < fk.length; i++) delete counts[fk[i]];
        }
        _saveUsage.command = ["bash", "-c", "mkdir -p ~/.cache && printf '%s' " + root.shellQuote(JSON.stringify(counts)) + " > ~/.cache/spotlight-usage.json"];
        _saveUsage.running = true;
    }

    function usageOf(key) { return root.usageCounts[key] || 0; }

    // =====================================================================
    //  TIMER / REMINDERS / TODO / EVENTOS
    // =====================================================================
    function startTimer(secs, label) {
        const n = parseInt(secs);
        if (isNaN(n) || n <= 0) return;
        TimerService.setCountdownTime(n);
        TimerService.toggleCountdown();
        root.notify("Timer started (" + label + ")");
    }

    function scheduleReminder(whenStr, text) {
        const script = 'qs -c ii ipc call todoReminder fire "$1" || notify-send -a Shell Lembrete "$1"';
        SpotlightController.run(
            "systemd-run --user --quiet --collect --on-calendar=" + root.shellQuote(whenStr) +
            " --timer-property=AccuracySec=1s" +
            " bash -c " + root.shellQuote(script) + " _ " + root.shellQuote(text)
        );
    }

    function parseTodoInput(raw) {
        let text = String(raw).trim();
        const pad = root.pad2;
        let hh = -1, mm = 0;
        let hasDate = false, dY = 0, dM = 0, dD = 0;
        const timeRe = /\s+(?:[àa]s\s+(\d{1,2})(?::(\d{2})|h(\d{2})?)?|(\d{1,2})(?::(\d{2})|h(\d{2})?))$/i;
        const dateRe = /\s+(?:(\d{4})-(\d{1,2})-(\d{1,2})|(\d{1,2})\/(\d{1,2})(?:\/(\d{4}))?)$/;
        for (let pass = 0; pass < 2; pass++) {
            if (hh < 0) {
                const tm = text.match(timeRe);
                if (tm) {
                    const h = parseInt(tm[1] ?? tm[4]);
                    const mi = parseInt(tm[2] ?? tm[3] ?? tm[5] ?? tm[6] ?? "0");
                    if (h >= 0 && h <= 23 && mi >= 0 && mi <= 59) {
                        hh = h; mm = mi;
                        text = text.slice(0, text.length - tm[0].length).trim();
                    }
                }
            }
            if (!hasDate) {
                const dm = text.match(dateRe);
                if (dm) {
                    const iso = !!dm[1];
                    const mo = parseInt(iso ? dm[2] : dm[5]);
                    const d = parseInt(iso ? dm[3] : dm[4]);
                    const now = new Date();
                    let y = iso ? parseInt(dm[1]) : (dm[6] ? parseInt(dm[6]) : now.getFullYear());
                    if (!iso && !dm[6] && new Date(y, mo - 1, d, 23, 59) < now) y += 1;
                    const check = new Date(Date.UTC(y, mo - 1, d, 12));
                    if (mo >= 1 && mo <= 12 && check.getUTCMonth() === mo - 1 && check.getUTCDate() === d) {
                        hasDate = true; dY = y; dM = mo; dD = d;
                        text = text.slice(0, text.length - dm[0].length).trim();
                    }
                }
            }
        }
        let remindAt = "", remindMs = 0, timeStr = "";
        if (hh >= 0) {
            const now = new Date();
            let target;
            if (hasDate) target = new Date(dY, dM - 1, dD, hh, mm);
            else {
                target = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hh, mm);
                if (target <= now) target.setDate(target.getDate() + 1);
            }
            dY = target.getFullYear(); dM = target.getMonth() + 1; dD = target.getDate();
            hasDate = true;
            timeStr = pad(hh) + ":" + pad(mm);
            remindAt = dY + "-" + pad(dM) + "-" + pad(dD) + " " + timeStr + ":00";
            remindMs = target.getTime();
        }
        let dueStr = "", dueLabel = "";
        if (hasDate) {
            dueStr = dY + "-" + pad(dM) + "-" + pad(dD);
            dueLabel = pad(dD) + "/" + pad(dM) + "/" + dY + (timeStr ? " " + timeStr : "");
        }
        return { text: text, dueStr: dueStr, dueLabel: dueLabel, remindAt: remindAt, remindMs: remindMs };
    }

    function parseEventInput(raw) {
        let text = String(raw).trim();
        let duration = 60;
        const dm = text.match(/\s+por\s+(\d+)\s*(h|hora|horas|min|m)$/i);
        if (dm) {
            const n = parseInt(dm[1]);
            const u = dm[2].toLowerCase();
            duration = (u === "h" || u === "hora" || u === "horas") ? n * 60 : n;
            if (duration <= 0) duration = 60;
            text = text.slice(0, text.length - dm[0].length).trim();
        }
        const t = root.parseTodoInput(text);
        return { text: t.text, dueStr: t.dueStr, dueLabel: t.dueLabel, remindAt: t.remindAt, remindMs: t.remindMs, duration: duration };
    }

    function todoActionItem(t) {
        return {
            kind: "action",
            name: "Add to ToDo: \u201c" + t.text + "\u201d" + (t.dueLabel ? " \u00b7 " + t.dueLabel : ""),
            action: "addtodo:",
            todoText: t.text,
            todoDue: t.dueStr,
            todoRemind: t.remindAt,
            todoRemindMs: t.remindMs,
            iconKey: "note",
            category: t.remindAt ? "ToDo \u00b7 vai avisar na hora" : "ToDo"
        };
    }

    function addTodoFromItem(e) {
        let due = undefined;
        if (e.todoDue) {
            const p = e.todoDue.split("-").map(Number);
            due = new Date(Date.UTC(p[0], p[1] - 1, p[2], 12));
        }
        Todo.addTask(e.todoText, due);
        if (e.todoRemind && e.todoRemindMs > Date.now()) {
            root.scheduleReminder(e.todoRemind, e.todoText);
            root.notify("Added to ToDo \u00b7 aviso agendado");
        } else {
            root.notify("Added to ToDo");
        }
    }

    function focusWindow(address) {
        SpotlightController.run("hyprctl dispatch focuswindow " + root.shellQuote("address:" + address));
    }

    // =====================================================================
    //  PARSERS / CONVERSORES (cor, calc, unidades, controles do sistema)
    // =====================================================================
    function bangItem(q) {
        const m = q.match(/^([a-z]+)\s+(.+)$/i);
        if (!m) return null;
        const key = m[1].toLowerCase();
        if (!root.hasOwn(root.bangs, key)) return null;
        const b = root.bangs[key];
        const term = m[2].trim();
        if (!term) return null;
        return { kind: "action", name: b[0] + ": \u201c" + term + "\u201d", action: "open:" + b[1] + encodeURIComponent(term), iconKey: "web", category: "Atalho de site" };
    }

    function colorItem(q) {
        const m = q.match(/^#([0-9a-f]{3}|[0-9a-f]{6})$/i);
        if (!m) return null;
        let h = m[1];
        if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
        const r = parseInt(h.slice(0, 2), 16), g = parseInt(h.slice(2, 4), 16), b = parseInt(h.slice(4, 6), 16);
        const rn = r / 255, gn = g / 255, bn = b / 255;
        const mx = Math.max(rn, gn, bn), mn = Math.min(rn, gn, bn);
        const l = (mx + mn) / 2, d = mx - mn;
        let hue = 0, sat = 0;
        if (d > 0) {
            sat = d / (1 - Math.abs(2 * l - 1));
            if (mx === rn) hue = ((gn - bn) / d) % 6;
            else if (mx === gn) hue = (bn - rn) / d + 2;
            else hue = (rn - gn) / d + 4;
            hue = Math.round(hue * 60);
            if (hue < 0) hue += 360;
        }
        const hex = "#" + h.toLowerCase();
        return { kind: "calc", swatch: hex, raw: hex, iconKey: "calc",
                 name: hex.toUpperCase() + " \u2192 rgb(" + r + ", " + g + ", " + b + ") \u00b7 hsl(" + hue + ", " + Math.round(sat * 100) + "%, " + Math.round(l * 100) + "%)",
                 category: "Cor \u2014 clique para copiar o hex" };
    }

    function sysControlItems(ql) {
            const out = [];
            const add = (name, cmd) => out.push({ kind: "action", action: "shell", cmd: cmd, name: name, category: "Controle do sistema", iconKey: "shortcut" });
            const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
            let m;
        
            // Trigger OSD when typing "volume" alone
            if (ql === "volume" || ql === "vol" || ql === "som") {
                add("Volume (mostrar OSD)", "qs -c ii ipc call osdVolume trigger");
            }
        
            if ((m = ql.match(/^(?:volume|vol|som)\s*([+-])?\s*(\d{1,3})$/))) {
            const n = clamp(parseInt(m[2]), 0, 150);
            const fb = "; notify-send -t 1500 Volume \"$(wpctl get-volume @DEFAULT_AUDIO_SINK@)\"";
            if (m[1]) add("Volume " + m[1] + n + "%", "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ " + n + "%" + m[1] + fb + "; qs -c ii ipc call osdVolume trigger");
            else add("Volume: " + n + "%", "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ " + n + "%" + fb + "; qs -c ii ipc call osdVolume trigger");

            // Auto-execute when query is exactly "volume N" (no +/-)
            if (!m[1]) {
                const cmd = "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ " + n + "%" + fb + "; qs -c ii ipc call osdVolume trigger";
                SpotlightController.run(cmd);
            }
        } else if (/^(mudo|mute|silenciar)$/.test(ql)) {
                add("Alternar mudo", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle; qs -c ii ipc call osdVolume trigger");
            } else if ((m = ql.match(/^(?:brilho|brightness|bright)\\s*([+-])?\\s*(\\d{1,3})$/))) {
            const n = clamp(parseInt(m[2]), m[1] ? 0 : 1, 100);
            if (m[1]) add("Brilho " + m[1] + n + "%", "brightnessctl set " + n + "%" + m[1]);
            else add("Brilho: " + n + "%", "brightnessctl set " + n + "%");
        } else if ((m = ql.match(/^wifi\s+(on|off|ligar|desligar)$/))) {
            const on = (m[1] === "on" || m[1] === "ligar");
            add("Wi-Fi " + (on ? "ligado" : "desligado"), "nmcli radio wifi " + (on ? "on" : "off"));
        } else if ((m = ql.match(/^(?:bluetooth|bt)\s+(on|off|ligar|desligar)$/))) {
            const on = (m[1] === "on" || m[1] === "ligar");
            add("Bluetooth " + (on ? "ligado" : "desligado"), "bluetoothctl power " + (on ? "on" : "off"));
        } else if (/^(n[ãa]o perturbe|dnd|silencioso)$/.test(ql)) {
            add("Alternar Não Perturbe",
                "if command -v makoctl >/dev/null; then " +
                "  m=$(makoctl mode | grep -q '^dnd$' && echo default || echo dnd); makoctl mode -s \"$m\"; " +
                "elif command -v swaync-client >/dev/null; then swaync-client -d; " +
                "elif command -v dunstctl >/dev/null; then dunstctl set-paused toggle; " +
                "fi");
        }
        return out;
    }

    function evalMath(q) {
        if (!/^[0-9+\-*/%.()\s]+$/.test(q)) return null;
        try {
            const r = Function('"use strict";return (' + q + ')')();
            if (typeof r !== "number" || !isFinite(r)) return null;
            return r;
        } catch (e) { return null; }
    }

    function convertUnits(q) {
        const s = q.trim().toLowerCase().replace(/,/g, ".");
        const m = s.match(/^(-?[\d.]+)\s*([a-zçãõáéíóúâêô°\/]+)\s+(?:in|to|em|para|->|=)\s+([a-zçãõáéíóúâêô°\/]+)$/);
        if (!m) return null;
        const val = parseFloat(m[1]);
        if (isNaN(val)) return null;
        const alias = {
            milha: "mi", milhas: "mi", mile: "mi", miles: "mi", libra: "lb", libras: "lb", pound: "lb", pounds: "lb", lbs: "lb",
            metro: "m", metros: "m", meter: "m", meters: "m",
            "quilômetro": "km", "quilômetros": "km", quilometro: "km", quilometros: "km", kilometer: "km", kilometers: "km",
            "centímetro": "cm", "centímetros": "cm", centimetro: "cm", centimetros: "cm",
            "milímetro": "mm", "milímetros": "mm", milimetro: "mm", milimetros: "mm",
            polegada: "in", polegadas: "in", inch: "in", inches: "in", pol: "in",
            "pé": "ft", "pés": "ft", pe: "ft", pes: "ft", feet: "ft", foot: "ft",
            jarda: "yd", jardas: "yd", yard: "yd", yards: "yd",
            quilo: "kg", quilos: "kg", kilo: "kg", kilos: "kg", quilograma: "kg", quilogramas: "kg",
            grama: "g", gramas: "g", tonelada: "t", toneladas: "t",
            "onça": "oz", "onças": "oz", onca: "oz", oncas: "oz", ounce: "oz", ounces: "oz",
            litro: "l", litros: "l", liter: "l", liters: "l", litre: "l", litres: "l",
            "galão": "gal", galao: "gal", "galões": "gal", galoes: "gal", gallon: "gal", gallons: "gal",
            "xícara": "cup", xicara: "cup", cups: "cup",
            celsius: "c", "°c": "c", fahrenheit: "f", "°f": "f", kelvin: "k",
            "km/h": "kmh", kph: "kmh", kmph: "kmh", "m/s": "ms",
            byte: "b", bytes: "b", kilobyte: "kb", kilobytes: "kb", megabyte: "mb", megabytes: "mb",
            gigabyte: "gb", gigabytes: "gb", terabyte: "tb", terabytes: "tb"
        };
        const cats = {
            len:   { mm: 0.001, cm: 0.01, m: 1, km: 1000, "in": 0.0254, ft: 0.3048, yd: 0.9144, mi: 1609.344 },
            mass:  { mg: 1e-6, g: 0.001, kg: 1, t: 1000, oz: 0.028349523, lb: 0.45359237 },
            vol:   { ml: 0.001, l: 1, gal: 3.785411784, cup: 0.2365882365, floz: 0.0295735296 },
            data:  { b: 1, kb: 1e3, mb: 1e6, gb: 1e9, tb: 1e12, kib: 1024, mib: 1048576, gib: 1073741824, tib: 1099511627776 },
            speed: { kmh: 1 / 3.6, mph: 0.44704, ms: 1, kn: 0.514444 }
        };
        const names = { kmh: "km/h", ms: "m/s", c: "\u00b0C", f: "\u00b0F", k: "K", floz: "fl oz" };
        const norm = (u) => root.hasOwn(alias, u) ? alias[u] : u;
        const label = (u) => root.hasOwn(names, u) ? names[u] : u;
        const fmt = (v) => String(parseFloat(v.toPrecision(8)));
        const from = norm(m[2]), to = norm(m[3]);
        const temps = ["c", "f", "k"];
        if (temps.indexOf(from) >= 0 && temps.indexOf(to) >= 0) {
            const c = from === "c" ? val : from === "f" ? (val - 32) * 5 / 9 : val - 273.15;
            const r = to === "c" ? c : to === "f" ? c * 9 / 5 + 32 : c + 273.15;
            return fmt(r) + " " + label(to);
        }
        for (const cat of Object.keys(cats)) {
            const t = cats[cat];
            if (root.hasOwn(t, from) && root.hasOwn(t, to)) return fmt(val * t[from] / t[to]) + " " + label(to);
        }
        return null;
    }

    function urlTarget(q) {
        const t = q.trim();
        if (!t || /\s/.test(t)) return "";
        try {
            const u = new URL(/^https?:\/\//i.test(t) ? t : "https://" + t);
            const host = u.hostname;
            if (!host.includes(".")) return "";
            const tld = host.split(".").pop();
            if (tld.length < 2) return "";
            return u.toString();
        } catch (e) { return ""; }
    }

    function looksLikeUrl(t) {
        return /^(https?:\/\/|www\.)\S+$/i.test(t) || /^[\w-]+(\.[\w-]+)+(\/\S*)?$/.test(t);
    }

    function langName(c) {
        const n = { en: "English", pt: "Brazilian Portuguese", es: "Spanish", fr: "French", de: "German", it: "Italian",
                    ja: "Japanese", ko: "Korean", zh: "Chinese", ru: "Russian", ar: "Arabic", nl: "Dutch", pl: "Polish", tr: "Turkish" };
        const k = c.toLowerCase();
        return root.hasOwn(n, k) ? n[k] : c;
    }

    // =====================================================================
    //  FERRAMENTAS INLINE (clima, hora, dicionário, câmbio, bateria, IP, etc.)
    // =====================================================================
    function wxDescribe(code) {
        const m = {
            0: ["\u2600\ufe0f", "Céu limpo"], 1: ["\ud83c\udf24\ufe0f", "Predominantemente limpo"],
            2: ["\u26c5", "Parcialmente nublado"], 3: ["\u2601\ufe0f", "Nublado"],
            45: ["\ud83c\udf2b\ufe0f", "Neblina"], 48: ["\ud83c\udf2b\ufe0f", "Neblina"],
            51: ["\ud83c\udf26\ufe0f", "Garoa fraca"], 53: ["\ud83c\udf26\ufe0f", "Garoa"], 55: ["\ud83c\udf26\ufe0f", "Garoa forte"],
            61: ["\ud83c\udf27\ufe0f", "Chuva fraca"], 63: ["\ud83c\udf27\ufe0f", "Chuva"], 65: ["\ud83c\udf27\ufe0f", "Chuva forte"],
            66: ["\ud83c\udf27\ufe0f", "Chuva congelante"], 67: ["\ud83c\udf27\ufe0f", "Chuva congelante forte"],
            71: ["\ud83c\udf28\ufe0f", "Neve fraca"], 73: ["\ud83c\udf28\ufe0f", "Neve"], 75: ["\ud83c\udf28\ufe0f", "Neve forte"],
            80: ["\ud83c\udf26\ufe0f", "Pancadas de chuva"], 81: ["\ud83c\udf27\ufe0f", "Pancadas fortes"], 82: ["\u26c8\ufe0f", "Pancadas violentas"],
            95: ["\u26c8\ufe0f", "Tempestade"], 96: ["\u26c8\ufe0f", "Tempestade com granizo"], 99: ["\u26c8\ufe0f", "Tempestade com granizo forte"]
        };
        return m[code] || ["\ud83c\udf21\ufe0f", "—"];
    }

    function fetchWeather(city, preferBR) {
        const cacheKey = "wx:" + city.toLowerCase() + ":" + (preferBR ? "br" : "any");
        const cached = root.cacheGet(cacheKey, 5 * 60 * 1000);
        if (cached) { root.weatherText = cached; root.rebuildIfShown(); return; }

        const req = ++root._wxReq;
        root.abortXhr(root._wxGeoXhr);
        root.abortXhr(root._wxDataXhr);
        const done = (txt) => { root.weatherText = txt; root.rebuildIfShown(); };

        root._wxGeoXhr = root.httpJson(
            "https://geocoding-api.open-meteo.com/v1/search?count=10&language=pt&name=" + encodeURIComponent(city),
            10000,
            function (geo) {
                if (req !== root._wxReq) return;
                const list = (geo && geo.results) || [];
                const place = (preferBR && list.find(r => r.country_code === "BR")) || list[0] || null;
                if (!place) { done("Cidade não encontrada: " + city); return; }

                root._wxDataXhr = root.httpJson(
                    "https://api.open-meteo.com/v1/forecast?latitude=" + place.latitude + "&longitude=" + place.longitude +
                    "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m&timezone=auto",
                    10000,
                    function (wd) {
                        if (req !== root._wxReq) return;
                        try {
                            const c = wd.current;
                            const d = root.wxDescribe(c.weather_code);
                            const where = place.name + (place.admin1 ? ", " + place.admin1 : "") +
                                          (place.country_code !== "BR" && place.country ? ", " + place.country : "");
                            const txt = where + ": " + d[0] + " " + Math.round(c.temperature_2m) + "°C" +
                                " (sensação " + Math.round(c.apparent_temperature) + "°C) · " + d[1] +
                                " · umidade " + Math.round(c.relative_humidity_2m) + "% · vento " + Math.round(c.wind_speed_10m) + " km/h";
                            root.cacheSet(cacheKey, txt);
                            done(txt);
                        } catch (e) { done("Não foi possível obter o clima"); }
                    });
            });
    }

    function checkWeather() {
        const s = root.query.trim().toLowerCase();
        if (s === "clima" || s === "weather" || s.startsWith("clima ") || s.startsWith("weather ")) {
            const typed = s.replace(/^(clima|weather)\s*/, "").replace(/^(em|in|de|para|no|na|do|da|for)\s+/, "").trim();
            if (/^(em|in|de|para|no|na|do|da|for)$/.test(typed)) return;
            const city = typed || root.weatherCity;
            const key = city + "|" + (typed ? "1" : "0");
            if (key === root._wxLastCity && root.weatherText) return;
            root._wxLastCity = key;
            root.fetchWeather(city, !typed);
        } else if (root.weatherText !== "") {
            root._wxReq++;
            root._wxLastCity = "";
            root.weatherText = "";
        }
    }

    function checkDefine() {
        const s = root.query.trim().toLowerCase();
        const m = s.match(/^(define|significado|meaning)\s+(.+)$/);
        if (m && m[2]) {
            const pt = m[1] === "significado";
            const lang = pt ? "pt-BR" : "en";
            const word = m[2].trim().replace(pt ? /[^a-zà-ú-]/g : /[^a-z-]/g, "");
            if (!word) { if (root.dictText !== "") root.dictText = ""; return; }
            const cacheKey = "dict:" + lang + ":" + word;
            const cached = root.cacheGet(cacheKey, 24 * 60 * 60 * 1000);
            if (cached !== null) { root.dictText = cached; root.rebuildIfShown(); return; }
            _dict.exec(["bash", "-c", "curl -s --max-time 10 'https://api.dictionaryapi.dev/api/v2/entries/" + lang + "/" + root.urlq(word) + "' 2>/dev/null"]);
        } else if (root.dictText !== "") {
            root.dictText = "";
        }
    }

    function curCode(x) {
        const alias = { dolar: "usd", "d\u00f3lar": "usd", dolares: "usd", "d\u00f3lares": "usd", real: "brl", reais: "brl",
                        euro: "eur", euros: "eur", iene: "jpy", ienes: "jpy" };
        const known = "usd brl eur gbp jpy btc cad aud chf cny inr mxn ars clp cop pen uyu krw rub try zar sek nok dkk pln czk huf ils aed sar sgd hkd nzd thb idr php vnd egp ngn".split(" ");
        if (root.hasOwn(alias, x)) return alias[x];
        return known.indexOf(x) >= 0 ? x : "";
    }

    function checkCurrency() {
        const s = root.query.trim().toLowerCase().replace(",", ".");
        const m = s.match(/^([\d.]+)\s*([a-z\u00e9\u00f3]{3,8})\s+(?:in|to|em|para)\s+([a-z\u00e9\u00f3]{3,8})$/);
        const from = m ? root.curCode(m[2]) : "";
        const to = m ? root.curCode(m[3]) : "";
        if (!m || !from || !to) { if (root.currencyText) root.currencyText = ""; return; }
        const cacheKey = "cur:" + from + ":" + to + ":" + m[1];
        const cached = root.cacheGet(cacheKey, 10 * 60 * 1000);
        if (cached !== null) { root.currencyText = cached; root.rebuildIfShown(); return; }
        root._pendingCurrency = { val: parseFloat(m[1]), from: from.toUpperCase(), to: to.toUpperCase() };
        _currency.exec(["bash", "-c", "curl -s --max-time 10 'https://api.exchangerate-api.com/v4/latest/" + from.toUpperCase() + "' 2>/dev/null"]);
    }

    function checkBattery() {
        const s = root.query.trim().toLowerCase();
        if (s === "bateria" || s === "battery") _battery.running = true;
        else if (root.batteryText) root.batteryText = "";
    }

    function checkMyIp() {
        const s = root.query.trim().toLowerCase();
        if (s === "meu ip" || s === "my ip") _ipInfo.running = true;
        else if (root.ipText) root.ipText = "";
    }

    function checkPassword() {
        const s = root.query.trim().toLowerCase();
        const m = s.match(/^(senha|password)\s*(\d+)?$/);
        if (!m) { if (root.passText) root.passText = ""; root._passKey = ""; return; }
        if (root._passKey === s) return;
        root._passKey = s;
        const len = Math.max(4, Math.min(64, parseInt(m[2] || "16")));
        root._passWanted = len;
        _pass.exec(["bash", "-c", "LC_ALL=C tr -dc 'A-Za-z0-9!@#$%&*' </dev/urandom | head -c " + len]);
    }

    // -- Hora em outra cidade
    function fetchTime(city) {
        const cacheKey = "time:" + city.toLowerCase();
        const cached = root.cacheGet(cacheKey, 30 * 1000);
        if (cached) { root.timeText = cached; root.rebuildIfShown(); return; }

        // Show immediate loading feedback
        root.timeText = "🔍 Searching for " + city + "...";
        root.rebuildIfShown();

        // Translate common Portuguese city names to English for the API
        const cityMap = {
            "londres": "London",
            "toquio": "Tokyo",
            "tokyo": "Tokyo",
            "nova york": "New York",
            "new york": "New York",
            "sao paulo": "Sao Paulo",
            "são paulo": "Sao Paulo",
            "rio de janeiro": "Rio de Janeiro",
            "paris": "Paris",
            "berlim": "Berlin",
            "madrid": "Madrid",
            "roma": "Rome",
            "pequim": "Beijing",
            "beijing": "Beijing",
            "moscu": "Moscow",
            "moscou": "Moscow",
            "dubai": "Dubai",
            "singapura": "Singapore",
            "sydney": "Sydney",
            "los angeles": "Los Angeles",
            "chicago": "Chicago",
            "toronto": "Toronto",
            "vancouver": "Vancouver",
            "montreal": "Montreal",
            "buenos aires": "Buenos Aires",
            "cidade do mexico": "Mexico City",
            "mexico city": "Mexico City",
            "bangkok": "Bangkok",
            "seul": "Seoul",
            "seoul": "Seoul",
            "hong kong": "Hong Kong",
            "shangai": "Shanghai",
            "shanghai": "Shanghai",
        };
        const apiCity = cityMap[city.toLowerCase()] || city;

        const req = ++root._timeReq;
        root.abortXhr(root._timeXhr);
        const fail = (msg) => { root.timeText = msg; root.rebuildIfShown(); };

        // Use English for geocoding (works better for international cities)
        root._timeXhr = root.httpJson(
            "https://geocoding-api.open-meteo.com/v1/search?count=3&language=en&name=" + encodeURIComponent(apiCity),
            10000,
            function (geo) {
                if (req !== root._timeReq) return;
                const place = (geo && geo.results && geo.results[0]) || null;
                if (!place) { fail("City not found: " + city); return; }

                root._timeXhr = root.httpJson(
                    "https://api.open-meteo.com/v1/forecast?latitude=" + place.latitude + "&longitude=" + place.longitude + "&current=temperature_2m&timezone=auto",
                    10000,
                    function (data) {
                        if (req !== root._timeReq) return;
                        const tzName = (data && data.timezone) || "";
                        if (!data || typeof data.utc_offset_seconds !== "number") {
                            root.fetchTimezoneFallback(city, place, req, cacheKey);
                            return;
                        }
                        root.renderTime(place, tzName, data.utc_offset_seconds, cacheKey);
                    });
            });
    }

    function fetchTimezoneFallback(city, place, req, cacheKey) {
        const gmtOffset = Math.round(-place.longitude / 15);
        const gmtSign = gmtOffset >= 0 ? "+" : "-";
        root._timeXhr = root.httpJson(
            "https://worldtimeapi.org/api/timezone/Etc/GMT" + gmtSign + Math.abs(gmtOffset),
            10000,
            function (data) {
                if (req !== root._timeReq) return;
                try {
                    if (!data || !data.utc_offset) throw new Error("no utc_offset");
                    const sign = data.utc_offset[0] === "-" ? -1 : 1;
                    const [hh, mm] = data.utc_offset.slice(1).split(":").map(Number);
                    root.renderTime(place, data.timezone || "", sign * (hh * 3600 + mm * 60), cacheKey);
                } catch (e) {
                    root.timeText = "Could not get time for " + city;
                    root.rebuildIfShown();
                }
            });
    }

    function renderTime(place, tzName, utcOffsetSeconds, cacheKey) {
        const now = new Date();
        const localOffsetSec = -now.getTimezoneOffset() * 60;
        const there = new Date(now.getTime() + utcOffsetSeconds * 1000);
        const wd = ["dom", "seg", "ter", "qua", "qui", "sex", "s\u00e1b"][there.getUTCDay()];
        const timeStr = root.pad2(there.getUTCHours()) + ":" + root.pad2(there.getUTCMinutes());
        const dateStr = wd + " " + root.pad2(there.getUTCDate()) + "/" + root.pad2(there.getUTCMonth() + 1);
        const diffH = (utcOffsetSeconds - localOffsetSec) / 3600;
        const diffStr = diffH === 0 ? "mesmo fuso que você"
                      : (diffH > 0 ? "+" : "") + (Number.isInteger(diffH) ? diffH : diffH.toFixed(1)) + "h em relação a você";
        const where = place.name + (place.admin1 ? ", " + place.admin1 : "") + (place.country ? ", " + place.country : "");
        const tzSuffix = tzName ? " (" + tzName + ")" : "";
        const txt = where + ": " + timeStr + " \u00b7 " + dateStr + " \u00b7 " + diffStr + tzSuffix;
        root.timeText = txt;
        if (cacheKey) root.cacheSet(cacheKey, txt);
        root.rebuildIfShown();
    }

    function checkTime() {
        const s = root.query.trim().toLowerCase();
        const m = s.match(/^(?:que\s+)?(?:hora|horas|time)\s+(?:em|in|de|no|na|do|da|for)\s+(.+)$/);
        if (!m) {
            // Only clear if the query no longer looks like a time query at all
            if (root.timeText && !/(?:que\s+)?(?:hora|horas|time)\s+(?:em|in|de|no|na|do|da|for)\s/.test(s)) {
                root._timeReq++;
                root._timeKey = "";
                root.timeText = "";
            }
            return;
        }
        const city = m[1].trim();
        if (!city || (root._timeKey === city && root.timeText)) return;
        root._timeKey = city;
        root.fetchTime(city);
    }

    // -- Processos (kill)
    function checkKill() {
        const m = root.query.trim().match(/^(?:kill|matar|encerrar|pkill)\s+(\S.*)$/i);
        if (!m) {
            if (root.procItems.length) root.procItems = [];
            root._procKey = "";
            return;
        }
        const name = m[1].trim();
        if (root._procKey === name) return;
        root._procKey = name;
        const id = ++root._psReq;
        _ps.exec(["bash", "-c", "echo " + id + "; ps -u \"$USER\" -o pid=,rss=,comm= --sort=-rss | grep -i -F -- " + root.shellQuote(name) + " | head -12"]);
    }

    // -- Ferramentas de dev (uuid, base64, hashes)
    function checkDev() {
        const q = root.query.trim();
        let kind = "", arg = "", m;
        if (q.toLowerCase() === "uuid") kind = "uuid";
        else if ((m = q.match(/^(?:base64d|b64d|debase64)\s+(.+)$/i))) { kind = "b64d"; arg = m[1]; }
        else if ((m = q.match(/^(?:base64|b64)\s+(.+)$/i))) { kind = "b64e"; arg = m[1]; }
        else if ((m = q.match(/^(sha256|sha1|sha512|md5|hash)\s+(.+)$/i))) {
            kind = m[1].toLowerCase() === "hash" ? "sha256" : m[1].toLowerCase();
            arg = m[2];
        }
        if (!kind) {
            if (root.devResult.q) root.devResult = { q: "", text: "", label: "" };
            root._devQ = "";
            return;
        }
        if (root._devQ === q && root.devResult.q === q) return;
        let cmd = "", label = "";
        if (kind === "uuid") { cmd = "cat /proc/sys/kernel/random/uuid"; label = "UUID v4"; }
        else if (kind === "b64e") { cmd = "printf '%s' " + root.shellQuote(arg) + " | base64 -w0"; label = "Base64"; }
        else if (kind === "b64d") { cmd = "printf '%s' " + root.shellQuote(arg) + " | base64 -d 2>/dev/null"; label = "Base64 decodificado"; }
        else { cmd = "printf '%s' " + root.shellQuote(arg) + " | " + kind + "sum | cut -d' ' -f1"; label = kind.toUpperCase(); }
        root._devQ = q;
        root._devLabel = label;
        const id = ++root._devReq;
        _dev.exec(["bash", "-c", "echo " + id + "; " + cmd]);
    }

    function checkContentSearch() {
        const m = root.query.trim().match(/^\/buscar\s+(.+)$/i);
        if (m && m[1].trim()) {
            const term = m[1].trim();
            if (term !== root._lastContentQuery) {
                root._lastContentQuery = term;
                root.runContentSearch(term);
            }
        } else {
            root._lastContentQuery = "";
        }
    }

    function runSideEffects() {
        root.checkWeather();
        root.checkDefine();
        root.checkCurrency();
        root.checkBattery();
        root.checkMyIp();
        root.checkPassword();
        root.checkAI();
        root.checkContentSearch();
        root.checkTime();
        root.checkKill();
        root.checkDev();
    }

    // =====================================================================
    //  BUSCA DE ARQUIVOS
    // =====================================================================
    function parseFdLines(lines) {
        const out = [];
        const seen = {};
        for (const line of lines) {
            if (!line) continue;
            const tab = line.indexOf("\t");
            const isDirectory = tab >= 0 && line.slice(0, tab) === "d";
            let p = tab >= 0 ? line.slice(tab + 1) : line;
            p = p.replace(/\/+$/, "");
            if (!p || seen[p]) continue;
            seen[p] = true;
            const sp = root.splitPath(p);
            out.push({ name: sp.name, path: p, dir: sp.dir, isDirectory: isDirectory });
        }
        return out;
    }

    function runFd() {
        if (root.slashMode || root.query.trim().length < 2 || root.aiPromptFor(root.query.trim()) !== "") {
            root.fileItems = [];
            root.scheduleRebuild();
            return;
        }
        const q = root.query.trim();
        const id = ++root._fdReq;
        _fd.exec(["bash", "-c",
            "echo " + id + "; " +
            "Q=" + root.shellQuote(q.toLowerCase()) + "; " +
            "fd -i -F -d 5 -- \"$Q\" ~ 2>/dev/null | head -80 | while IFS= read -r p; do " +
            "  if [ -d \"$p\" ]; then printf 'd\\t%s\\n' \"$p\"; else printf 'f\\t%s\\n' \"$p\"; fi; " +
            "done; " +
            "fd -i -F -t d -d 4 -- \"$Q\" ~ 2>/dev/null | head -5 | while IFS= read -r d; do " +
            "  fd . \"$d\" -d 1 2>/dev/null | head -40 | while IFS= read -r p; do " +
            "    if [ -d \"$p\" ]; then printf 'd\\t%s\\n' \"$p\"; else printf 'f\\t%s\\n' \"$p\"; fi; " +
            "  done; " +
            "done"
        ]);
    }

    function runContentSearch(term) {
        if (!term) return;
        const id = ++root._rgReq;
        _rg.exec(["bash", "-c", "echo " + id + "; rg -l -i -F --max-count 1 -e " + root.shellQuote(term) + " ~ 2>/dev/null | head -12"]);
    }

    function runRecents() {
        _recents.exec(["bash", "-c",
            "cd " + (root.browseDir !== "" ? root.shellQuote(root.browseDir) : "~") + " 2>/dev/null || exit 0; " +
            "pwd; " +
            "{ ls -1 --group-directories-first 2>/dev/null; " +
            "  ls -1A --group-directories-first 2>/dev/null | grep '^\\.'; " +
            "} | head -300 | while IFS= read -r n; do " +
            "  p=\"$PWD/$n\"; " +
            "  if [ -d \"$p\" ]; then printf 'd\\t%s\\n' \"$p\"; else printf 'f\\t%s\\n' \"$p\"; fi; " +
            "done"
        ]);
    }

    function runClip() { _clip.running = true; }
    function clearClipboard() { _clipClear.running = true; }

    function runInTerminal(command) {
        terminalProcess.commandText = command;
        terminalProcess.running = true;
    }

    function browseUp() {
        const i = root.browseDir.lastIndexOf("/");
        root.browseDir = i > 0 ? root.browseDir.slice(0, i) : "/";
        root.selectedIndex = 0;
        root.runRecents();
    }

    function naturalCompare(a, b) {
        const re = /(\d+)|(\D+)/g;
        const pa = String(a).match(re) || [];
        const pb = String(b).match(re) || [];
        const len = Math.max(pa.length, pb.length);
        for (let i = 0; i < len; i++) {
            const xa = pa[i], xb = pb[i];
            if (xa === undefined) return -1;
            if (xb === undefined) return 1;
            if (xa !== xb) {
                const na = /^\d/.test(xa), nb = /^\d/.test(xb);
                if (na && nb) {
                    const ia = parseInt(xa, 10), ib = parseInt(xb, 10);
                    if (ia !== ib) return ia - ib;
                    if (xa.length !== xb.length) return xa.length - xb.length;
                } else {
                    const c = xa.toLowerCase().localeCompare(xb.toLowerCase());
                    if (c !== 0) return c;
                }
            }
        }
        return 0;
    }

    function sortFileResults(arr, q) {
        const ql = q.trim().toLowerCase();
        let targetDir = null;
        for (const f of arr) {
            if (!f.isDirectory) continue;
            const n = f.name.toLowerCase();
            if (n === ql) { targetDir = f; break; }
            if (!targetDir && n.startsWith(ql)) targetDir = f;
        }
        if (!targetDir) {
            return arr.slice().sort((a, b) => {
                const da = a.isDirectory ? 1 : 0;
                const db = b.isDirectory ? 1 : 0;
                if (da !== db) return db - da;
                const ua = root.usageOf("file:" + a.path), ub = root.usageOf("file:" + b.path);
                if (ua !== ub) return ub - ua;
                return root.naturalCompare(a.name, b.name);
            });
        }
        const prefix = targetDir.path + "/";
        const groupOf = (f) => f === targetDir ? 0 : (f.path.startsWith(prefix) ? 1 : 2);
        return arr.slice().sort((a, b) => {
            const ga = groupOf(a), gb = groupOf(b);
            if (ga !== gb) return ga - gb;
            if (ga === 2) {
                const da = a.isDirectory ? 1 : 0;
                const db = b.isDirectory ? 1 : 0;
                if (da !== db) return db - da;
            }
            return root.naturalCompare(a.name, b.name);
        });
    }

    // =====================================================================
    //  IA (HERMES AGENT)
    // =====================================================================
    function structuredIntent(p) {
        const s = String(p).toLowerCase();
        for (const r of root._intentRules) if (r[1](s)) return r[0];
        return "";
    }

    function buildSystemPrompt(intent, nowStr) {
        const base = "Responda em português do Brasil, de forma curta e direta, a menos que peçam outro idioma.";
        const extra = {
            todo: `\nO usuário quer criar uma tarefa. Data atual: ${nowStr}. RESPONDA APENAS com JSON:\n{"action":"add_todo","text":"...","due":"YYYY-MM-DD HH:MM"}`,
            note: `\nO usuário quer criar uma nota. RESPONDA APENAS com JSON:\n{"action":"add_note","title":"...","content":"..."}`,
            email: `\nO usuário quer enviar email. RESPONDA APENAS com JSON:\n{"action":"send_email","to":"...","subject":"...","body":"..."}`,
            timer: `\nO usuário quer um timer. RESPONDA APENAS com JSON:\n{"action":"start_timer","seconds":N,"label":"..."}`,
            alias: `\nO usuário quer criar um atalho. RESPONDA APENAS com JSON:\n{"action":"create_alias","name":"...","actions":["..."]}`,
            block: `\nO usuário quer bloquear sites. RESPONDA APENAS com JSON:\n{"action":"block_sites","sites":["..."],"minutes":N}`,
            focus: `\nO usuário quer modo foco. RESPONDA APENAS com JSON:\n{"action":"focus_mode","minutes":N}`,
            screenshot: `\nO usuário quer analisar ou traduzir a tela. RESPONDA APENAS com JSON:\n{"action":"screenshot","selectArea":true,"translate":false,"lang":"pt"}\nUse translate:true se ele pedir tradução e lang com o código do idioma de destino.`,
            web: `\nO usuário quer resumir um link. RESPONDA APENAS com JSON:\n{"action":"web_summary","url":"<url>"}`,
            pdf: `\nO usuário quer resumir um PDF. RESPONDA APENAS com JSON:\n{"action":"pdf_summary","path":"<caminho>"}`
        };
        return base + (extra[intent] ? extra[intent] : "");
    }

    function pushHistory(role, content, label) {
        const h = root.aiHistory.slice();
        h.push(root._msg(role, content, label));
        while (h.length > 20) h.shift();
        root.aiHistory = h;
        if (role === "assistant" && root.aiPersistentHistory) SpotlightActions.saveHistory(JSON.stringify(root.aiHistory));
    }

    function aiFail(msg) {
        root.aiText = msg;
        root.aiLoading = false;
        root.rebuildIfShown();
    }

    // Reinicia o cache de "mesma pergunta" e envia um prompt interno.
    function runInternalAi(prompt, label) {
        root._lastAiQuery = "";
        root.runHermes(prompt, false, label);
    }

    function runHermes(prompt, isRetry, label) {
        isRetry = !!isRetry;
        if (!prompt) return;
        if (!root.hermesKey) {
            root.aiFail("Hermes Agent: configure HERMES_API_KEY no ambiente");
            return;
        }
        if (!isRetry && prompt === root._lastAiQuery && root.aiText && !root.aiLoading) return;

        if (!isRetry) root._aiRetries = 0;
        root._lastAiQuery = prompt;
        root.aiLoading = true;
        root.aiText = "Thinking…";

        if (!isRetry) {
            const h = root.aiHistory.slice();
            h.push(root._msg("user", prompt, label));
            while (h.length > 20) h.shift();
            root.aiHistory = h;
        }
        const history = root.aiHistory.slice();

        const now = new Date();
        const nowStr = now.getFullYear() + "-" + root.pad2(now.getMonth() + 1) + "-" + root.pad2(now.getDate())
                     + " " + root.pad2(now.getHours()) + ":" + root.pad2(now.getMinutes());
        const internal = /^(Translate the following text|Analise este texto extra|Resuma este|Gere mensagem de commit|Formate este briefing|Contexto da tela)/.test(prompt);
        const intent = internal ? "" : root.structuredIntent(prompt);
        const sysContent = root.buildSystemPrompt(intent, nowStr);

        const req = ++root._aiReq;
        root.abortXhr(root._aiXhr);
        const xhr = new XMLHttpRequest();
        root._aiXhr = xhr;

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (req !== root._aiReq) return;
            let answer = "";
            try {
                const data = JSON.parse(xhr.responseText);
                const msg = data.choices && data.choices[0] && data.choices[0].message;
                if (msg && msg.content) {
                    answer = String(msg.content)
                        .replace(/<think>[\s\S]*?<\/think>/g, "")
                        .replace(/^[\s\S]*<\/think>/, "")
                        .trim();
                }
                if (!answer) {
                    if (data.error) answer = "Hermes Agent error: " + (data.error.message || data.error);
                    else answer = "No AI response";
                }
            } catch (e) {
                if (xhr.status === 0) {
                    if (!isRetry && root._aiRetries < 1) {
                        root._aiRetries++;
                        root.aiLoading = false;
                        _aiRetryTimer.prompt = prompt;
                        _aiRetryTimer.restart();
                        return;
                    }
                    answer = "Sem resposta do Hermes Agent (gateway parado ou timeout)";
                }
                else if (xhr.status === 401) answer = "Hermes Agent: chave inválida (API_SERVER_KEY)";
                else answer = "Erro ao consultar a IA (HTTP " + xhr.status + ")";
            }
            root.finishAi(answer, prompt, req);
        };

        xhr.open("POST", root.hermesUrl + "/v1/chat/completions");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.hermesKey);
        xhr.timeout = 60000;
        xhr.send(JSON.stringify({
            model: root.hermesModel,
            stream: false,
            messages: [
                { role: "system", content: sysContent },
                ...history.map(m => ({ role: m.role, content: m.content }))
            ]
        }));
        root.scheduleRebuild();
    }

    // Trata a resposta final: JSON de ação estruturada ou texto normal.
    function finishAi(answer, prompt, req) {
        if (req !== root._aiReq) return;
        if (answer.length > 4000) answer = answer.slice(0, 4000) + "…";

        const cleaned = String(answer).trim()
            .replace(/^```json\s*/i, "")
            .replace(/^```\s*/i, "")
            .replace(/```\s*$/i, "")
            .trim();

        if (cleaned.startsWith("{") && cleaned.endsWith("}")) {
            try {
                const obj = JSON.parse(cleaned);
                if (obj.action === "screenshot") {
                    root._ocrMode = obj.translate === true ? "translate" : "analyze";
                    root._ocrLang = obj.lang || "pt";
                    root.aiText = "📸 Capturando tela…";
                    SpotlightActions.runScreenshotOcr(obj.selectArea === true);
                    return;
                }
                if (obj.action === "web_summary" && obj.url) {
                    root.aiText = "🌐 Baixando " + obj.url + "…";
                    SpotlightActions.scrapeUrl(obj.url);
                    return;
                }
                if (obj.action === "pdf_summary" && obj.path) {
                    root.aiText = "📄 Lendo " + obj.path + "…";
                    SpotlightActions.summarizePdf(obj.path);
                    return;
                }
                const handled = root.handleStructuredAction(obj, prompt);
                if (handled) {
                    root.aiText = handled;
                    root.aiLoading = false;
                    root._aiXhr = null;
                    root.pushHistory("assistant", handled);
                    root.notify(handled);
                    root.rebuildIfShown();
                    return;
                }
            } catch (e) { }
        }

        root.aiText = answer;
        root.aiLoading = false;
        root._aiXhr = null;
        if (!root.aiErrored) root.pushHistory("assistant", answer);
        root.rebuildIfShown();
    }

    function handleStructuredAction(obj, prompt) {
        if (!obj || !obj.action) return "";
        switch (obj.action) {
            case "add_todo": {
                if (!obj.text) return "";
                let due = undefined;
                let dueLabel = "";
                if (obj.due) {
                    const parts = String(obj.due).trim().split(/\s+/);
                    const timePart = parts[1] || "09:00";
                    const [y, m, d] = parts[0].split("-").map(Number);
                    const [hh, mm] = timePart.split(":").map(Number);
                    if ([y, m, d, hh, mm].every(n => !isNaN(n))) {
                        due = new Date(Date.UTC(y, m - 1, d, hh, mm));
                        dueLabel = root.pad2(d) + "/" + root.pad2(m) + " às " + root.pad2(hh) + ":" + root.pad2(mm);
                    }
                }
                Todo.addTask(obj.text, due);
                if (due && due.getTime() > Date.now()) {
                    const whenStr = due.getFullYear() + "-" + root.pad2(due.getMonth() + 1) + "-" + root.pad2(due.getDate())
                        + " " + root.pad2(due.getHours()) + ":" + root.pad2(due.getMinutes()) + ":00";
                    root.scheduleReminder(whenStr, obj.text);
                }
                return "✅ Tarefa criada: \"" + obj.text + "\"" + (dueLabel ? " · " + dueLabel : "");
            }
            case "add_note": return SpotlightActions.addObsidianNote(obj.title || "Nota", obj.content || "");
            case "send_email": return SpotlightActions.sendEmail(obj.to, obj.subject || "", obj.body || "");
            case "start_timer": {
                const s = parseInt(obj.seconds) || 0;
                if (s <= 0) return "";
                root.startTimer(s, obj.label || (s + "s"));
                return "⏱ Timer iniciado: " + (obj.label || (s + "s"));
            }
            case "create_alias": return SpotlightActions.createAlias(obj.name, obj.actions || []);
            case "block_sites": return SpotlightActions.blockSites(obj.sites || [], obj.minutes || 60);
            case "focus_mode": return SpotlightActions.enterFocusMode(obj.minutes || 120);
            default: return "";
        }
    }

    function buildResumePrompt(page, focus) {
        return "Resuma este conteúdo de página web de forma concisa"
            + (focus ? ", com foco em: " + focus : "") + ":\n\n"
            + "TÍTULO: " + (page.title || "") + "\n"
            + "LINK: " + page.url + "\n\n"
            + (page.text || "").slice(0, 5000);
    }

    function buildScreenPrompt(windows, ocr, question) {
        const ask = question
            || "Explique o que está sendo mostrado na tela: qual é a atividade do usuário, o que há em cada janela e o que for relevante ou fora do normal. Seja objetivo.";
        return "Contexto da tela do usuário (capturada agora).\n\n"
            + "JANELAS NA ÁREA DE TRABALHO ATUAL:\n" + (windows || "(indisponível)") + "\n\n"
            + "TEXTO LIDO NA TELA POR OCR (pode ter erros, ordem aproximada e texto de várias janelas misturado):\n"
            + (ocr ? ocr.slice(0, 6000) : "(nenhum texto reconhecido)") + "\n\n"
            + "PEDIDO: " + ask;
    }

    function aiIsAuto(s) {
        return root.aiAutoQuestion && !s.startsWith("/") && s.endsWith("?") && s.length > 3
            && !/^\/?(ai|gpt|ia)\s/i.test(s)
            && !/^(?:tr|traduzir|translate)\s+/i.test(s);
    }

    function aiPromptFor(s) {
        const tm = s.match(/^(?:tr|traduzir|translate)\s+([a-z]{2}(?:-[a-z]{2})?)\s+(.+)$/i);
        const m = s.match(/^\/?(ai|gpt|ia)\s+(.+)$/i);
        if (tm) return "Translate the following text to " + root.langName(tm[1]) +
                       ". Reply with ONLY the translation, without quotes or explanations.\n\n" + tm[2];
        if (m && m[2] && (!s.startsWith("/") || m[1].toLowerCase() === "ai")) return m[2].trim();
        if (root.aiIsAuto(s)) return s;
        return "";
    }

    function clearAi() {
        root._aiReq++;
        root.abortXhr(root._aiXhr);
        root._aiXhr = null;
        root.aiText = "";
        root.aiLoading = false;
        root._lastAiQuery = "";
        root._aiRetries = 0;
    }

    function newAiConversation() {
        root.aiHistory = [];
        root.clearAi();
        root.scheduleRebuild();
    }

    function sendChat(text) {
        const t = text.trim();
        if (t.length === 0 || root.aiLoading) return false;
        root.runHermes(t);
        return true;
    }

    function _aiResultItems() {
        if (root.aiText) {
            return [{
                kind: "info", isAi: true,
                name: root.aiLoading ? "Thinking…" : "Ver resposta no popup ao lado",
                category: root.aiLoading ? "Hermes Agent · thinking…" : "Hermes Agent — Enter to copy"
            }];
        }
        if (root.aiPromptFor(root.query.trim()) !== "") {
            return [{ kind: "info", isAi: true, name: "Perguntar ao Hermes Agent", category: "Pressione Enter para enviar" }];
        }
        return [];
    }

    function checkAI() {
        const s = root.query.trim();
        const isSlashOther = s.startsWith("/") && !/^\/ai\s/i.test(s);
        const prompt = isSlashOther ? "" : root.aiPromptFor(s);
        if (!prompt) {
            _aiDeb.stop();
            if (root.aiText !== "") {
                root.clearAi();
                root.rebuildIfShown();
            }
            return;
        }
        root._pendingAiPrompt = prompt;
        if (root.aiIsAuto(s)) _aiDeb.restart();
        else {
            _aiDeb.stop();
            if (prompt !== root._lastAiQuery && root.aiText !== "") {
                root.clearAi();
                root.rebuildIfShown();
            }
        }
    }

    // =====================================================================
    //  PREVIEW
    // =====================================================================
    function _fitPreview(maxW, maxH, minW, minH, fbW, fbH) {
        const w = root.previewNatW, h = root.previewNatH;
        if (!w || !h) return { w: fbW, h: fbH };
        const fit = Math.min(maxW / w, maxH / h);
        let outW = w * fit, outH = h * fit;
        if (outW < minW) { const s = minW / outW; outW = minW; outH *= s; }
        if (outH < minH) { const s = minH / outH; outH = minH; outW *= s; }
        return { w: Math.min(outW, maxW), h: Math.min(outH, maxH) };
    }
    function previewSize()      { return root._fitPreview(480, 480, 220, 160, 300, 260); }
    function previewSizeLarge() { return root._fitPreview(580, 700, 300, 400, 420, 560); }

    function previewKindFor(ext) {
        if (root._imgExts.indexOf(ext) !== -1) return "image";
        if (root._textExts.indexOf(ext) !== -1) return ext === "md" ? "markdown" : "text";
        if (root._videoExts.indexOf(ext) !== -1) return "video";
        if (root._audioExts.indexOf(ext) !== -1) return "audio";
        if (ext === "pdf") return "pdf";
        return "";
    }

    function resetPreview() {
        audioPlayer.stop();
        root.previewThumbPath = "";
        root.previewNatW = 0;
        root.previewNatH = 0;
        root.previewPath = "";
        root.previewKind = "";
        root.previewText = "";
    }

    function previewFile(p, isDirectory) {
        root.resetPreview();
        if (isDirectory) return;
        const kind = root.previewKindFor(p.split(".").pop().toLowerCase());
        if (!kind) return;
        root.previewKind = kind;
        root.previewPath = p;
        const q = root.shellQuote;
        const pend = (outPath) => { root._pendingPreview = { for: p, path: outPath, kind: kind }; };

        if (kind === "text" || kind === "markdown") {
            _preview.exec(["bash", "-c", "head -c 4000 " + q(p) + " 2>/dev/null | iconv -c -t UTF-8 2>/dev/null"]);
        } else if (kind === "video") {
            const out = "/tmp/spotlight_thumb_" + Date.now() + ".jpg";
            pend(out);
            _videoThumb.exec(["bash", "-c", "rm -f /tmp/spotlight_thumb_*.jpg; ffmpegthumbnailer -i " + q(p) + " -o " + q(out) + " -s 400 2>/dev/null"]);
        } else if (kind === "audio") {
            const out = "/tmp/spotlight_cover_" + Date.now() + ".jpg";
            pend(out);
            _audioCover.exec(["bash", "-c", "rm -f /tmp/spotlight_cover_*.jpg; ffmpeg -y -i " + q(p) + " -an -frames:v 1 " + q(out) + " 2>/dev/null"]);
        } else if (kind === "pdf") {
            const base = "/tmp/spotlight_pdf_" + Date.now();
            pend(base + ".jpg");
            _pdfThumb.exec(["bash", "-c",
                "rm -f /tmp/spotlight_pdf_*.jpg; " +
                "pdftoppm -jpeg -f 1 -l 1 -scale-to 1200 " + q(p) + " " + q(base) + " 2>/dev/null; " +
                "f=$(ls " + q(base) + "*.jpg 2>/dev/null | head -1); " +
                "[ -n \"$f\" ] && mv \"$f\" " + q(base + ".jpg")
            ]);
        }
    }

    function previewClipText(id) {
        root._clipPrevKey = root.selectedKey;
        const script = [
            "c=$(cliphist decode " + id + " 2>/dev/null | head -c 4000)",
            "n=$(printf '%s\\n' \"$c\" | wc -l)",
            "first=$(printf '%s\\n' \"$c\" | tr -d '\\r' | grep -m1 -E '^(file://|/)')",
            "case \"$first\" in",
            "  file://*) p=$(printf '%s' \"$first\" | sed 's#^file://##' | python3 -c 'import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read().strip()))' 2>/dev/null) ;;",
            "  /*) p=\"$first\" ;;",
            "  *) p=\"\" ;;",
            "esac",
            "if [ \"$n\" -le 3 ] && [ -n \"$p\" ] && [ -f \"$p\" ]; then printf 'FILE\\t%s\\n' \"$p\"; else printf 'TEXT\\n%s' \"$c\"; fi"
        ].join("\n");
        _clipPreview.exec(["bash", "-c", script]);
    }

    function updatePreview() {
        const key = root.selectedKey;
        if (key === root._previewKeyShown) return;
        root._previewKeyShown = key;
        const it = root.selectedItem;
        if (it && it.kind === "file") { root.previewFile(it.path, !!it.isDirectory); return; }
        if (it && it.kind === "clip") {
            if (it.isImage && it.imagePath) { root.previewFile(it.imagePath, false); return; }
            if (/^\d+$/.test(it.id || "")) { root.previewClipText(it.id); return; }
        }
        root.resetPreview();
    }

    // =====================================================================
    //  CONSTRUÇÃO DOS RESULTADOS
    // =====================================================================
    function computeResultsHeight() {
        const maxH = Math.round(root.screen.height * 0.65);
        if (!root.hasBody) return 0;
        if (root.mode === "apps") {
            const rows = Math.max(1, Math.ceil(root.items.length / 2));
            return Math.min(maxH, Math.min(8, rows) * root.rowH + 16);
        }
        const idleSearch = root.query.length === 0 && root.mode === "search";
        let h = 12;
        if (root.nowPlayingText.length > 0 && idleSearch) h += root.nowPlayingH;
        if (root.sysStatsText.length > 0 && idleSearch) h += 24;
        for (const r of root.results) h += r.isHeader ? root.headerH : root.rowH;
        if (root.items.length === 0 && root.query.length > 0) h += 56;
        return Math.min(maxH, Math.max(48, h + 12));
    }

    function _addItems(items, disp, arr, title) {
        if (!arr.length) return;
        if (title) disp.push({ isHeader: true, title: title });
        for (const it of arr) {
            if (!it) continue;
            const copy = Object.assign({}, it);
            copy._idx = items.length;
            copy._dispIdx = disp.length;
            items.push(copy);
            disp.push(copy);
        }
    }

    function _appRows(list) {
        return list.map(a => ({ kind: "app", name: a.name, icon: a.icon, exec: a.exec, category: a.category || "Application" }));
    }

    function _fileRows(arr) {
        return arr.map(f => ({ kind: "file", name: f.name, path: f.path, dir: f.dir, category: f.dir, isDirectory: f.isDirectory }));
    }

    function _infoRow(text, category) { return [{ kind: "info", name: text, category: category }]; }

    function _calcRow(text, raw, category, iconKey) {
        return [{ kind: "calc", name: text, raw: raw, category: category, iconKey: iconKey || "calc" }];
    }

    function _sortedApps(q) {
        const apps = SpotlightApps.search(q);
        apps.sort((a, b) => root.usageOf("app:" + b.exec) - root.usageOf("app:" + a.exec));
        return apps;
    }

    function _buildSlashMode(items, disp, q, ql) {
        const full = ql.slice(1);
        const spaceIdx = full.indexOf(" ");
        const cmdName = spaceIdx >= 0 ? full.slice(0, spaceIdx) : full;
        const cmdArgs = spaceIdx >= 0 ? full.slice(spaceIdx + 1).trim() : "";
        const rawArgs = spaceIdx >= 0 ? q.slice(1 + spaceIdx + 1) : "";
        const A = (arr, title) => root._addItems(items, disp, arr, title);
        const hasArgs = cmdArgs.length > 0;

        if (cmdName === "web" && hasArgs) {
            A([{ kind: "action", name: "Search the Web for \u201c" + cmdArgs + "\u201d", action: "web:" + cmdArgs, iconKey: "web", category: "Search" }], "WEB SEARCH");
            return;
        }
        if (cmdName === "calc" && hasArgs) {
            const cr = root.evalMath(cmdArgs);
            if (cr !== null) A(root._calcRow("= " + cr, String(cr), "Calculator"), "CALCULATOR");
            return;
        }
        if (cmdName === "buscar" && hasArgs) {
            A(root.contentResults.map(f => ({ kind: "file", name: f.name, path: f.path, category: f.dir })), "CONTENT: " + cmdArgs);
            return;
        }
        if (cmdName === "ai" && hasArgs) {
            A(root._aiResultItems(), "AI");
            return;
        }
        if (cmdName === "emoji") {
            const filter = cmdArgs.toLowerCase();
            let list = root.emojiList;
            if (filter.length > 0) list = list.filter(x => x.n.indexOf(filter) !== -1 || x.e.indexOf(filter) !== -1);
            A(list.slice(0, 100).map(x => ({ kind: "emoji", name: x.e + "  " + x.n, raw: x.e, category: "Emoji — Enter to copy" })),
              filter ? "EMOJI: " + filter : "EMOJI");
            return;
        }
        if ((cmdName === "todo" || cmdName === "notes") && hasArgs) {
            A([root.todoActionItem(root.parseTodoInput(rawArgs))], "TODO");
            return;
        }
        if ((cmdName === "calendar" || cmdName === "cal" || cmdName === "evento" || cmdName === "event") && hasArgs) {
            const ev = root.parseEventInput(rawArgs);
            if (!ev.dueStr) {
                A([{ kind: "info", name: "Informe data ou hora: /evento reunião 02/10 às 14h", category: "Evento" }], "EVENTO");
                return;
            }
            A([{
                kind: "action",
                name: "Add event: \u201c" + ev.text + "\u201d \u00b7 " + ev.dueLabel + (ev.remindAt ? " \u00b7 " + ev.duration + " min" : " \u00b7 dia inteiro"),
                action: "addevent:",
                evText: ev.text,
                evDate: ev.dueStr,
                evTime: ev.remindAt ? ev.remindAt.slice(11, 16) : "-",
                evDuration: ev.duration,
                evRemind: ev.remindAt,
                evRemindMs: ev.remindMs,
                iconKey: "note",
                category: "Calendário"
            }], "EVENTO");
            return;
        }
        if (cmdName === "nota" && hasArgs) {
            A([{ kind: "action", name: "📝 Create note: \u201c" + cmdArgs + "\u201d", action: "aiintent:note:" + cmdArgs, iconKey: "note", category: "Obsidian" }], "NOTE");
            return;
        }
        if (cmdName === "email" && hasArgs) {
            A([{ kind: "action", name: "📧 Send email: \u201c" + cmdArgs + "\u201d", action: "aiintent:email:" + cmdArgs, iconKey: "message", category: "Email" }], "EMAIL");
            return;
        }

        const filtered = cmdName.length > 0
            ? root.slashCommands.filter(c => c.name.slice(1).toLowerCase().startsWith(cmdName))
            : root.slashCommands;
        A(filtered, "COMMANDS");
    }

    function _buildAppsMode(items, disp, q, ql) {
        const list = (ql ? SpotlightApps.search(q) : SpotlightApps.apps).slice();
        list.sort((a, b) => root.usageOf("app:" + b.exec) - root.usageOf("app:" + a.exec));
        root._addItems(items, disp, root._appRows(list.slice(0, 60)), ql ? "APPLICATIONS" : "");
    }

    function _buildFilesMode(items, disp, ql) {
        let src;
        if (!ql) src = root.recentItems.slice();
        else if (root.fileItems.length) src = root.fileItems;
        else src = root.recentItems.filter(f => f.name.toLowerCase().indexOf(ql) !== -1);
        const fitems = ql ? root.sortFileResults(src, ql) : src;
        const home = root.browseDir.replace(/^\/home\/[^\/]+/, "~");
        root._addItems(items, disp, root._fileRows(fitems), ql ? "FILES" : (home || "~"));
    }

    function _buildClipboardMode(items, disp) {
        root._addItems(items, disp, root.clipItems.map(c => ({
            kind: "clip", name: c.isImage ? "Image" : c.text,
            id: c.id, category: c.isImage ? (c.text || "Image") : "Clipboard",
            isImage: !!c.isImage, imagePath: c.imagePath || ""
        })), "CLIPBOARD");
    }

    function _buildWindowsMode(items, disp, ql) {
        const wlist = ql ? root.windowItems.filter(w => w.title.toLowerCase().indexOf(ql) !== -1 || w.cls.toLowerCase().indexOf(ql) !== -1) : root.windowItems;
        root._addItems(items, disp, wlist.map(w => ({ kind: "window", name: w.title, address: w.address, category: w.cls })), "OPEN WINDOWS");
    }

    function _buildWifiMode(items, disp) {
        root._addItems(items, disp, root.wifiItems.map(w => ({ kind: "wifi", name: w.ssid, category: w.active ? "Connected" : "Available" })), "WI-FI NETWORKS");
    }

    function _buildBluetoothMode(items, disp) {
        root._addItems(items, disp, root.btItems.map(d => ({ kind: "bt", name: d.name, address: d.mac, category: d.mac })), "PAIRED BLUETOOTH");
    }

    function _buildActionsMode(items, disp) {
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
        root._addItems(items, disp, acts, "ACTIONS");
    }

    function _buildConfigMode(items, disp, q, ql) {
        if (!ql) {
            // Show top-level config sections
            const items = [];
            const pageMap = {
                "Quick": "QuickConfig.qml",
                "Wi-Fi": "WifiConfig.qml",
                "Bluetooth": "BluetoothConfig.qml",
                "Bar": "BarConfig.qml",
                "Dock": "DockConfig.qml",
                "Interface": "InterfaceConfig.qml",
                "appearance": "InterfaceConfig.qml",
                "Background": "BackgroundConfig.qml",
                "Decorations": "DecorationsConfig.qml",
                "Display": "DisplayConfig.qml",
                "Layouts": "LayoutsConfig.qml",
                "Keyboard": "KeyboardConfig.qml",
                "Mouse": "MouseConfig.qml",
                "Power": "PowerConfig.qml",
                "Accounts": "AccountsConfig.qml",
                "Services": "ServicesConfig.qml",
                "Manage": "ManageAppsConfig.qml"
            };
            for (const key in Config.options) {
                if (!Config.options.hasOwnProperty(key)) continue;
                const val = Config.options[key];
                if (val && typeof val === "object" && !Array.isArray(val)) {
                    const page = pageMap[key];
                    items.push({
                        kind: "configSection",
                        name: key,
                        path: key,
                        category: page ? "Open settings → " + key : "Section",
                        iconKey: page ? "settings" : "folder",
                        settingsPage: page
                    });
                } else {
                    let displayVal = "";
                    if (typeof val === "boolean") displayVal = val ? "true" : "false";
                    else if (typeof val === "number") displayVal = String(val);
                    else if (typeof val === "string") displayVal = val;
                    else if (Array.isArray(val)) displayVal = "[" + val.join(", ") + "]";
                    else displayVal = JSON.stringify(val);
                    
                    items.push({
                        kind: "configValue",
                        name: key + ": " + displayVal,
                        path: key,
                        value: val,
                        category: "Setting",
                        iconKey: "settings"
                    });
                }
            }
            root._addItems(items, disp, items, "SETTINGS");
        } else {
            // Filter config items by query
            const filtered = root.configItems.filter(it => 
                it.name.toLowerCase().includes(ql) || 
                it.path.toLowerCase().includes(ql)
            );
            root._addItems(items, disp, filtered, "CONFIG: " + root.configPath);
        }
    }

    // -- Modo busca, dividido em blocos (a ordem das seções é preservada)
    function _searchPrimary(items, disp, q, ql) {
        const A = (arr, title) => root._addItems(items, disp, arr, title);

        const aiItems = root._aiResultItems();
        if (aiItems.length) A(aiItems, "AI");

        const urlT = root.urlTarget(q);
        if (urlT) A([{ kind: "action", name: "Open " + q.trim(), action: "open:" + urlT, iconKey: "web", category: "Website" }], "OPEN WEBSITE");

        const bang = root.bangItem(q);
        if (bang) A([bang], "SITE SHORTCUT");

        const sc = root.sysControlItems(ql);
        if (sc.length) A(sc, "CONTROLS");

        if (root.procItems.length && /^(kill|matar|encerrar|pkill)\s/i.test(q)) {
                    A(root.procItems.map(pr => ({
                        kind: "proc", name: pr.name, pid: pr.pid,
                        category: "PID " + pr.pid + " · " + pr.mb + " MB · Enter = kill · Shift+Enter = force kill"
                    })), "PROCESSES");
                }
                if (root.timeText && /^(?:que\s+)?(?:hora|horas|time)\s/.test(ql)) A(root._infoRow(root.timeText, "Time"), "TIME");

        const colorIt = root.colorItem(q);
        if (colorIt) A([colorIt], "COLOR");

        if (root.devResult.q === q && root.devResult.text) {
            A(root._calcRow(root.devResult.text, root.devResult.text, root.devResult.label + " \u2014 click to copy"), "TOOLS");
        }
        A(root._appRows(root._sortedApps(q)), "APPLICATIONS");
    }

    function _searchInfo(items, disp, q, ql) {
        const A = (arr, title) => root._addItems(items, disp, arr, title);

        if ((ql.startsWith("clima") || ql.startsWith("weather")) && root.weatherText)
            A(root._infoRow(root.weatherText, "Weather"), "WEATHER");
        if ((ql.startsWith("define ") || ql.startsWith("significado ") || ql.startsWith("meaning ")) && root.dictText)
            A(root._infoRow(root.dictText, "Definition"), "DEFINITION");
        if (/^(senha|password)\s*(\d+)?$/.test(ql) && root.passText)
            A(root._calcRow(root.passText, root.passText, "Generated password — click to copy", "lock"), "PASSWORD");

        const todoMatch = q.match(/^(todo|tarefa|afazer)\s+(.+)$/i);
        if (todoMatch) A([root.todoActionItem(root.parseTodoInput(todoMatch[2]))], "TODO");

        if ((ql === "bateria" || ql === "battery") && root.batteryText) A(root._infoRow(root.batteryText, "Battery"), "BATTERY");
        if ((ql === "meu ip" || ql === "my ip") && root.ipText) A(root._infoRow(root.ipText, "Network"), "MY IP");
        if (root.currencyText) A(root._calcRow(root.currencyText, root.currencyText, "Currency"), "CURRENCY");
    }

    function _searchActions(items, disp, q, ql) {
        const A = (arr, title) => root._addItems(items, disp, arr, title);

        // Fuzzy match: split query into words, all must match somewhere
        const qWords = ql.split(/\s+/).filter(w => w.length > 0);

        const playMatch = q.match(/^(toque|tocar|play)\s+(.+)$/i);
        if (playMatch) {
            A([{ kind: "action", name: "Play \u201c" + playMatch[2] + "\u201d on Spotify", action: "spotifyplay:" + playMatch[2], iconKey: "music", category: "Spotify" }], "SPOTIFY");
        }

        const timerMatch = ql.match(/^timer\s+(\d+)\s*(min|m|s|sec|seg|h)?$/);
        if (timerMatch) {
            const n = parseInt(timerMatch[1]);
            const unit = timerMatch[2] || "min";
            let secs = n * 60;
            if (unit === "s" || unit === "sec" || unit === "seg") secs = n;
            else if (unit === "h") secs = n * 3600;
            A([{ kind: "action", name: "Start " + n + " " + unit + " timer", action: "realtimer:" + secs + ":" + n + " " + unit, iconKey: "timer", category: "Timer" }], "TIMER");
        }

        if ("lock screen sleep restart shut down log out".includes(ql)) {
            A([
                { kind: "action", name: "Lock Screen",   action: "lock",     iconKey: "lock",    category: "System" },
                { kind: "action", name: "Sleep",         action: "sleep",    iconKey: "moon",    category: "System" },
                { kind: "action", name: "Restart\u2026", action: "restart",  iconKey: "restart", category: "System" },
                { kind: "action", name: "Shut Down\u2026", action: "shutdown", iconKey: "power",  category: "System" },
                { kind: "action", name: "Log Out",       action: "logout",   iconKey: "logout",  category: "System" }
            ], "SYSTEM");
        }

        const mm = /^-?[\d.]+$/.test(q) ? null : root.evalMath(q);
        if (mm !== null) {
            A(root._calcRow("= " + mm, String(mm), "Calculator"), "CALCULATOR");
        } else {
            const cv = root.convertUnits(q);
            if (cv !== null) A(root._calcRow("= " + cv, cv, "Conversion"), "CONVERSION");
        }

        // Settings shortcuts in main search (fuzzy match on section names + deep search grouped by parent)
                const settingsMap = {
                    "interface": "InterfaceConfig.qml",
                    "appearance": "InterfaceConfig.qml",
                    "bar": "BarConfig.qml",
                    "dock": "DockConfig.qml",
                    "background": "BackgroundConfig.qml",
                    "wallpaper": "BackgroundConfig.qml",
                    "decorations": "DecorationsConfig.qml",
                    "display": "DisplayConfig.qml",
                    "layouts": "LayoutsConfig.qml",
                    "keyboard": "KeyboardConfig.qml",
                    "mouse": "MouseConfig.qml",
                    "power": "PowerConfig.qml",
                    "wifi": "WifiConfig.qml",
                    "bluetooth": "BluetoothConfig.qml",
                    "quick": "QuickConfig.qml",
                    "accounts": "AccountsConfig.qml",
                    "services": "ServicesConfig.qml",
                    "manage": "ManageAppsConfig.qml",
                    "settings": "InterfaceConfig.qml"  // generic entry point
                };
        
                // Track which parent sections we've already shown
                const shownParents = new Set();
                const allSectionItems = [];

                // 1. Direct section name matches from settingsMap
                const matchedSections = Object.keys(settingsMap).filter(k => 
                    qWords.every(w => k.includes(w))
                ).slice(0, 10);
                for (const k of matchedSections) {
                    const parent = k; // e.g., "background", "wallpaper"
                    if (!shownParents.has(parent)) {
                        shownParents.add(parent);
                        allSectionItems.push({
                            kind: "action",
                            name: "Open settings \u2192 " + k.charAt(0).toUpperCase() + k.slice(1),
                            action: "settings_open:" + settingsMap[k] + "|" + parent,
                            iconKey: "settings",
                            category: "Settings"
                        });
                    }
                }

                // 2. Deep search: find nested config items and group by parent SECTION
                let deepPaths = [];
                try {
                    deepPaths = root.flattenConfigPaths(Config.options || {});
                } catch (e) {
                    deepPaths = [];
                }
                const deepMatches = deepPaths.filter(c => 
                    !c.isSection && qWords.every(w => (c.path + " " + c.name).toLowerCase().includes(w))
                ).slice(0, 15);

                // Keyword aliases for settings not in Config.options (stored in hyprland/env)
                const keywordMap = {
                    "gap": ["decorations.gapsIn", "decorations.gapsOut", "interface.workspace_gap"],
                    "gaps": ["decorations.gapsIn", "decorations.gapsOut", "interface.workspace_gap"],
                    "workspace gap": ["interface.workspace_gap"],
                    "round": ["decorations.windowShape.cornerRadius", "appearance.fakeScreenRounding", "bar.floatRadius", "bar.widgetRadius", "dock.radius", "dock.topRadius"],
                    "corner": ["decorations.windowShape.cornerRadius", "appearance.fakeScreenRounding", "bar.floatRadius", "bar.widgetRadius", "dock.radius", "dock.topRadius", "bar.cornerStyle", "dock.cornerStyle"],
                    "radius": ["decorations.windowShape.cornerRadius", "appearance.fakeScreenRounding", "bar.floatRadius", "bar.widgetRadius", "dock.radius", "dock.topRadius"],
                    "blur": ["decorations.windowBlur.enable", "decorations.windowBlur.strength", "appearance.transparency.enable"],
                    "opacity": ["bar.backgroundOpacity", "bar.widgetOpacity", "appearance.transparency.backgroundTransparency", "appearance.transparency.contentTransparency", "dock.backgroundOpacity"],
                    "anim": ["decorations.animations.enabled"],
                    "animation": ["decorations.animations.enabled"],
                    "shadow": ["decorations.windowShadow.enable", "decorations.windowShadow.range", "decorations.windowShadow.renderPower", "bar.floatStyleShadow"],
                    "dock position": ["dock.position"],
                    "bar position": ["bar.bottom", "bar.vertical"],
                    "wallpaper": ["background.wallpaperPath", "background.slideshow.enable", "background.slideshow.folder"],
                    "slideshow": ["background.slideshow.enable", "background.slideshow.folder", "background.slideshow.intervalMinutes"],
                    "theme": ["appearance.palette.type", "appearance.palette.accentColor", "appearance.themeSchedule.mode"],
                    "color": ["appearance.palette.accentColor", "appearance.palette.type"],
                    "font": ["appearance.fonts.main", "appearance.fonts.monospace", "appearance.fonts.title"],
                    "cursor": ["cursor.shakeMode", "cursor.shakeZoomFactor", "cursor.shakeGrowFactor"],
                    "hotkey": ["bar.hotCorners.trigger", "bar.hotCorners.animationEnabled"],
                    "hotcorner": ["bar.hotCorners.trigger", "bar.hotCorners.animationEnabled"],
                    "overview": ["interface.workspace_gap", "interface.scrollOverviewWorkspaceGap"],
                };
        
                // Collect keyword matches
                const keywordMatches = [];
                for (const [keyword, paths] of Object.entries(keywordMap)) {
                    if (qWords.every(w => keyword.includes(w))) {
                        for (const p of paths) {
                            let found = deepPaths.find(d => d.path === p);
                            if (!found) {
                                const parts = p.split(".");
                                let prefix = "";
                                for (let i = 0; i < parts.length - 1; i++) {
                                    prefix += parts[i] + ".";
                                }
                                found = deepPaths.find(d => d.path === prefix) || { path: p, name: parts[parts.length - 1] + ": (hyprland)", isSection: false };
                            }
                            if (found) keywordMatches.push(found);
                        }
                    }
                }

                // Merge deepMatches + keywordMatches, then GROUP BY PARENT SECTION
                const allMatches = [...deepMatches, ...keywordMatches];
                const seen = new Set();
                const uniqueMatches = allMatches.filter(m => {
                    if (seen.has(m.path)) return false;
                    seen.add(m.path);
                    return true;
                });

                // Group by parent section (first part of path)
                const sectionGroups = {};
                for (const m of uniqueMatches) {
                    const parent = m.path.split(".")[0]; // e.g., "decorations", "appearance", "bar", "background"
                    if (!sectionGroups[parent]) sectionGroups[parent] = [];
                    sectionGroups[parent].push(m);
                }

                // Show ONE result per parent section (if not already shown from settingsMap)
                for (const parent of Object.keys(sectionGroups).slice(0, 8)) {
                    if (shownParents.has(parent)) continue;
                    shownParents.add(parent);
                    const pageMap = {
                        "bar": "BarConfig.qml",
                        "dock": "DockConfig.qml",
                        "interface": "InterfaceConfig.qml",
                        "appearance": "InterfaceConfig.qml",
                        "background": "BackgroundConfig.qml",
                        "decorations": "DecorationsConfig.qml",
                        "display": "DisplayConfig.qml",
                        "layouts": "LayoutsConfig.qml",
                        "keyboard": "KeyboardConfig.qml",
                        "mouse": "MouseConfig.qml",
                        "power": "PowerConfig.qml",
                        "wifi": "WifiConfig.qml",
                        "bluetooth": "BluetoothConfig.qml",
                        "quick": "QuickConfig.qml",
                        "accounts": "AccountsConfig.qml",
                        "services": "ServicesConfig.qml",
                        "manage": "ManageAppsConfig.qml",
                    };
                    const matchedPage = pageMap[parent] || parent + "Config.qml";
                    const count = sectionGroups[parent].length;
                    allSectionItems.push({
                        kind: "action",
                        name: "Open settings \u2192 " + parent.charAt(0).toUpperCase() + parent.slice(1) + " (" + count + " matches)",
                        action: "settings_open:" + matchedPage + "|" + parent,
                        iconKey: "settings",
                        category: "Settings"
                    });
                }

                if (allSectionItems.length) {
                    A(allSectionItems, "SETTINGS");
                }

        A([
            { kind: "action", name: "Search the Web for \u201c" + q + "\u201d", action: "web:" + q, iconKey: "web", category: "Search" },
            { kind: "action", name: "Search in Files", action: "filesearch:" + q, iconKey: "finder", category: "Search" }
        ], "SEARCH");
    }

    function _buildSearchMode(items, disp, q, ql) {
        if (!ql && root.nowPlayingText.length > 0) {
            root._addItems(items, disp, [{ kind: "media", name: root.nowPlayingText, category: root.nowPlayingStatus === "Playing" ? "Now playing" : "Paused" }], "NOW PLAYING");
        }
        if (!ql) return;
        root._searchPrimary(items, disp, q, ql);
        if (root.fileItems.length) root._addItems(items, disp, root._fileRows(root.sortFileResults(root.fileItems, q)), "FILES");
        root._searchInfo(items, disp, q, ql);
        root._searchActions(items, disp, q, ql);
    }

    function buildResults() {
        const q = root.query.trim();
        const ql = q.toLowerCase();
        const items = [];
        const disp = [];
        const m = root.mode;
        const prevKey = root.itemKey(root.items[root.selectedIndex]);
        const sig = m + "|" + q;

        if (ql.startsWith("/")) root._buildSlashMode(items, disp, q, ql);
        else switch (m) {
            case "apps":      root._buildAppsMode(items, disp, q, ql); break;
            case "files":     root._buildFilesMode(items, disp, ql); break;
            case "clipboard": root._buildClipboardMode(items, disp); break;
            case "windows":   root._buildWindowsMode(items, disp, ql); break;
            case "wifi":      root._buildWifiMode(items, disp); break;
            case "bluetooth": root._buildBluetoothMode(items, disp); break;
            case "actions":   root._buildActionsMode(items, disp); break;
            case "config":    root._buildConfigMode(items, disp, q, ql); break;
            default:          root._buildSearchMode(items, disp, q, ql);
        }

        root.items = items;
        root.results = disp;
        let idx = 0;
        if (sig === root._buildSig && prevKey && root._userNavigated) {
            const f = items.findIndex(i => root.itemKey(i) === prevKey);
            if (f >= 0) idx = f;
        }
        root._buildSig = sig;
        root.selectedIndex = idx;
        if (idx === 0) {
            if (resultList) resultList.positionViewAtBeginning();
            if (resultGrid) resultGrid.positionViewAtBeginning();
        }
    }

    function scheduleRebuild() { _rebuildDeb.restart(); }

    function setMode(m) {
        root.mode = m;
        root.selectedIndex = 0;
        if (m === "files") { root.browseDir = ""; root.runRecents(); }
        if (m === "clipboard") root.runClip();
        if (m === "windows") _windows.running = true;
        if (m === "wifi") _wifi.running = true;
        if (m === "bluetooth") _bt.running = true;
        if (m === "config") root.enterConfig();
        root.scheduleRebuild();
    }

    // =====================================================================
    //  CONFIG BROWSER
    // =====================================================================
    function enterConfig() {
        root.configPath = "";
        root.configDepth = 0;
        root.configStack = [];
        root.buildConfigItems(Config.options);
    }

    function buildConfigItems(obj, pathPrefix) {
        const items = [];
        const prefix = pathPrefix || "";
        for (const key in obj) {
            if (!obj.hasOwnProperty(key)) continue;
            const val = obj[key];
            const fullPath = prefix + key;
            if (val && typeof val === "object" && !Array.isArray(val)) {
                // It's a nested object (section)
                items.push({
                    kind: "configSection",
                    name: key,
                    path: fullPath,
                    category: "Seção",
                    iconKey: "folder"
                });
            } else {
                // It's a leaf value
                let displayVal = "";
                if (typeof val === "boolean") displayVal = val ? "true" : "false";
                else if (typeof val === "number") displayVal = String(val);
                else if (typeof val === "string") displayVal = val;
                else if (Array.isArray(val)) displayVal = "[" + val.join(", ") + "]";
                else displayVal = JSON.stringify(val);
                
                items.push({
                    kind: "configValue",
                    name: key + ": " + displayVal,
                    path: fullPath,
                    value: val,
                    category: "Configuração",
                    iconKey: "settings"
                });
            }
        }
        root.configItems = items;
        root.scheduleRebuild();
    }

    function navigateConfig(path) {
        const keys = path.split(".");
        let obj = Config.options;
        for (const k of keys) {
            if (!obj || !obj.hasOwnProperty(k)) return;
            obj = obj[k];
        }
        root.configStack.push({ path: root.configPath, items: root.configItems });
        root.configPath = path;
        root.configDepth++;
        root.buildConfigItems(obj, path + ".");
    }

    function goBackConfig() {
        if (root.configDepth > 0) {
            const prev = root.configStack.pop();
            root.configPath = prev.path;
            root.configDepth--;
            root.configItems = prev.items;
            root.scheduleRebuild();
        } else if (root.mode === "config") {
            root.setMode("search");
        }
    }

    function animateRail(target) {
        _railAnim.stop()
        _railAnim.from = root.railProgress
        _railAnim.to = target
        _railAnim.duration = Math.max(100, Math.round(620 * Math.abs(target - root.railProgress)))
        _railAnim.start()
    }

    // =====================================================================
    //  NAVEGAÇÃO E ATIVAÇÃO DE ITENS
    // =====================================================================
    function moveSelection(delta) {
        if (root.items.length === 0) return;
        root._userNavigated = true;
        root.selectedIndex = (root.selectedIndex + delta + root.items.length) % root.items.length;
        const it = root.items[root.selectedIndex];
        if (resultList && resultList.visible) {
            resultList.positionViewAtIndex(it._dispIdx, ListView.Contain);
        } else if (resultGrid && resultGrid.visible) {
            resultGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
        }
    }

    function submit(event) {
        root.openSelected(!!(event.modifiers & Qt.ShiftModifier));
        event.accepted = true;
    }

    // Atalhos do campo de busca. Retorna true se tratou a tecla.
    function handleSearchKey(event, hasSelection) {
        if (event.key === Qt.Key_Backspace && root.query === ""
                && root.mode === "files" && root.browseDir !== "" && root.browseDir !== "/") {
            root.browseUp();
            return true;
        }
        if (event.key === Qt.Key_Backspace && root.query === ""
                && root.mode === "config" && root.configDepth > 0) {
            root.goBackConfig();
            return true;
        }
        if (!(event.modifiers & Qt.ControlModifier)) return false;
        switch (event.key) {
            case Qt.Key_1: root.setMode("apps"); return true;
            case Qt.Key_2: root.setMode("files"); return true;
            case Qt.Key_3: root.setMode("actions"); return true;
            case Qt.Key_4: root.setMode("clipboard"); return true;
            case Qt.Key_5: root.setMode("config"); return true;
            case Qt.Key_C:
                if (!hasSelection && root.selectedItem && root.selectedItem.kind === "file") {
                    root.copyText(root.selectedItem.path);
                    SpotlightController.spotlightOpen = false;
                    return true;
                }
                return false;
            case Qt.Key_R:
                if (root.aiHistory.length > 0 && root._lastAiQuery) {
                    const p = root._lastAiQuery;
                    root._lastAiQuery = "";
                    root.runHermes(p);
                    return true;
                }
                return false;
        }
        return false;
    }

    function openSelected(alt) {
        const queryText = root.query.trim();
        if (queryText.startsWith(">")) {
            const command = queryText.slice(1).trim();
            if (command.length > 0) root.runInTerminal(command);
            return;
        }
        const aiPrompt = root.aiPromptFor(queryText);
        const sel = root.items[root.selectedIndex];
        const aiOk = !(queryText.startsWith("/") && !/^\/ai\s/i.test(queryText));
        if (aiPrompt && aiOk && (!sel || sel.isAi) && !root.aiLoading && root._lastAiQuery !== aiPrompt) {
            _aiDeb.stop();
            root.runHermes(aiPrompt);
            return;
        }
        if (!sel) return;
        const keepOpen = root._activate(sel, alt);
        if (!keepOpen) SpotlightController.spotlightOpen = false;
    }

    // Executa o item; retorna true se o Spotlight deve continuar aberto.
    function _activate(e, alt) {
        switch (e.kind) {
            case "app":
                root.recordUsage("app:" + e.exec);
                SpotlightApps.launch(e.exec);
                return false;
            case "file":
                return root._activateFile(e, alt);
            case "proc":
                if (/^\d+$/.test(String(e.pid))) {
                    const sig = alt ? "KILL" : "TERM";
                    SpotlightController.run("kill -" + sig + " " + e.pid + " 2>/dev/null; notify-send 'Spotlight' 'SIG" + sig + " enviado ao PID " + e.pid + "'");
                }
                return false;
            case "clip":
                if (/^\d+$/.test(e.id || "")) SpotlightController.run("cliphist decode " + e.id + " | wl-copy 2>/dev/null || true");
                return false;
            case "configSection":
                if (e.settingsPage) {
                    SpotlightController.run("qs -c ii ipc call settings showPage " + e.settingsPage);
                } else {
                    root.navigateConfig(e.path);
                }
                return true;
            case "configValue":
                root.copyText(JSON.stringify(e.value));
                root.notify("Copiado: " + e.path + " = " + JSON.stringify(e.value));
                return false;
            case "calc":
            case "emoji":
                root.copyText(e.raw);
                return false;
            case "media":
                SpotlightController.run("playerctl play-pause");
                return true;
            case "info":
                if (e.isAi) {
                    if (!root.aiLoading && root.aiText) root.copyText(root.aiText);
                    return true;
                }
                if (e.name && e.name !== "Thinking…") root.copyText(e.name);
                return false;
            case "window":
                root.focusWindow(e.address);
                return false;
            case "wifi":
                SpotlightController.run("nmcli connection up id " + root.shellQuote(e.name) + " 2>/dev/null || nmcli device wifi connect " + root.shellQuote(e.name) + " 2>/dev/null");
                return false;
            case "bt":
                SpotlightController.run("bluetoothctl connect " + root.shellQuote(e.address));
                return false;
            case "action":
                return root._activateAction(e);
            case "cmd":
                return root._activateCmd(e);
        }
        return false;
    }

    function _activateFile(e, alt) {
        root.recordUsage("file:" + e.path);
        if (root.mode === "files" && root.query.trim() === "" && e.isDirectory && !alt) {
            root.browseDir = e.path;
            root.selectedIndex = 0;
            root.runRecents();
            return true;
        }
        if (alt) {
            const i = e.path.lastIndexOf("/");
            root.xdgOpen(i > 0 ? e.path.slice(0, i) : "/");
        } else {
            root.xdgOpen(e.path);
        }
        return false;
    }

    function _activateAction(e) {
        const a = e.action;
        if (a === "shell") { SpotlightController.run(e.cmd); return false; }
        if (a.startsWith("open:")) { root.openUrl(a.slice(5)); return false; }
        if (a.startsWith("web:")) { root.openUrl("https://www.google.com/search?q=" + encodeURIComponent(a.slice(4))); return false; }
        if (a.startsWith("filesearch:")) {
            root.circlesLocked = true;
            root.setMode("files");
            root.runFd();
            return true;
        }
        if (a.startsWith("aiintent:")) {
            const rest = a.slice(9);
            const colon = rest.indexOf(":");
            const kind = colon >= 0 ? rest.slice(0, colon) : rest;
            const arg = colon >= 0 ? rest.slice(colon + 1) : "";
            const promptMap = { note: "crie uma nota: " + arg, email: "mande um email " + arg };
            root.runHermes(promptMap[kind] || arg);
            return true;
        }
        if (a.startsWith("spotifyplay:")) {
            const term = a.slice(12);
            SpotlightController.run(
                "pgrep -x spotify >/dev/null || (setsid flatpak run com.spotify.Client </dev/null >/dev/null 2>&1 &); " +
                "sleep 1; " + root.xdgOpenCmd("spotify:search:" + root.urlq(term)) + "; " +
                "sleep 1; wtype -k Return 2>/dev/null || true"
            );
            return false;
        }
        if (a.startsWith("realtimer:")) {
            const parts = a.slice(10).split(":");
            root.startTimer(parts[0], parts[1] || (parts[0] + "s"));
            return false;
        }
        if (a === "addtodo:") { root.addTodoFromItem(e); return false; }
        if (a === "addevent:") {
            if (!e.evText || !e.evDate) return true;
            _addEvent.title = e.evText;
            _addEvent.command = ["python3", Quickshell.shellPath("scripts/calendar/eds-add-event.py"),
                                e.evText, e.evDate, e.evTime, String(e.evDuration)];
            _addEvent.running = true;
            if (e.evRemind && e.evRemindMs > Date.now()) root.scheduleReminder(e.evRemind, e.evText);
            return false;
        }
        if (a.startsWith("action:")) {
            const sub = a.slice(7);
            if (sub === "msg") root.xdgOpen("https://messages.google.com/web");
            else if (sub === "note") root.xdgOpen("obsidian://new");
            else if (sub === "timer") root.startTimer(300, "5 min");
            else if (sub === "shortcut") root.xdgOpen("shortcuts://");
            else SpotlightController.requestAction(a);
            return false;
        }
        if (a === "clipboard:clear") { root.clearClipboard(); return true; }
        if (a.startsWith("settings_open:")) {
            const pagePart = a.slice("settings_open:".length);
            // Format: "PageConfig.qml|sectionHint" or just "PageConfig.qml"
            const [page, sectionHint] = pagePart.split("|");
            // Launch settings app with QS_SETTINGS_PAGE env var to open specific page
            SpotlightController.run(
                "QS_SETTINGS_PAGE=" + page + 
                (sectionHint ? " QS_SETTINGS_SECTION=" + sectionHint : "") + 
                " qs -p " + Quickshell.shellPath("settings.qml") + " --no-duplicate"
            );
            return false;
        }
        SpotlightController.requestAction(a);
        return false;
    }

    function _beginScreenshotSelect(mode, lang, hint) {
        root._ocrMode = mode;
        if (lang !== undefined) root._ocrLang = lang;
        root._screenshotSelecting = true;
        root.aiText = hint;
        _screenshotDeb.useSelectArea = true;
        _screenshotDeb.restart();
    }

    function _activateCmd(e) {
        const a = e.action;
        if (a === "screen:") {
            // /screen -> explica a tela | /screen <pergunta> -> responde sobre a tela
            root._screenQuestion = root.query.replace(/^\/screen\s*/i, "").trim();
            root.aiText = "🖥️ Capturando a tela…";
            root._capturing = true;          // some com o Spotlight antes do print
            _captureGuard.restart();
            SpotlightActions.runScreenContext();
            return true;
        }
        if (a === "ocrtr:") {
            // /traduzir -> português | /traduzir en -> inglês, etc.
            root._beginScreenshotSelect("translate",
                root.query.replace(/^\/traduzir\s*/i, "").trim().toLowerCase() || "pt",
                "📸 Selecione o texto a traduzir…");
            return true;
        }
        if (a === "screenshot:") {
            root._beginScreenshotSelect("analyze", undefined, "📸 Selecione a área…");
            return true;
        }
        if (a === "sum:") {
            const arg = root.query.replace(/^\/sum\s*/i, "").trim();
            if (!arg) return true;
            if (root.looksLikeUrl(arg) || /^https?:\/\//i.test(arg) || /^www\./i.test(arg)) {
                root.aiText = "🌐 Baixando…";
                SpotlightActions.scrapeUrl(/^https?:\/\//i.test(arg) ? arg : "https://" + arg);
            } else {
                root.aiText = "📄 Lendo…";
                SpotlightActions.summarizePdf(arg);
            }
            return true;
        }
        if (a === "mem-on:" || a === "mem-off:") {
            const on = a === "mem-on:";
            root.aiPersistentHistory = on;
            root.aiText = on ? "💾 Memória persistente ATIVADA" : "💾 Memória persistente DESATIVADA";
            root.scheduleRebuild();
            return true;
        }
        if (a.startsWith("focus:")) {
            root.notify(SpotlightActions.enterFocusMode(parseInt(a.slice(6)) || 120));
            return true;
        }
        if (a.startsWith("meeting:")) {
            root.notify(SpotlightActions.enterMeetingMode());
            return true;
        }
        if (a.startsWith("briefing:")) { SpotlightActions.runBriefing(); return true; }
        if (a.startsWith("git:")) { SpotlightActions.runGitCommit(); return true; }
        if (a.startsWith("mode:")) {
            searchField.text = "";
            root.query = "";
            root.setMode(a.slice(5));
            return true;
        }
        if (a.startsWith("sys:")) { SpotlightController.requestAction(a.slice(4)); return false; }
        if (a === "emoji:") {
            const em = SpotlightApps.apps.find(x => x.name.toLowerCase().indexOf("emoji") !== -1);
            if (em) SpotlightApps.launch(em.exec);
            else SpotlightController.run("rofimoji 2>/dev/null || wtype 2>/dev/null || true");
            return false;
        }
        if (a === "colorpick:") { SpotlightController.run("hyprpicker -a 2>/dev/null || true"); return false; }
        if (a.startsWith("ipc:")) {
            const parts = a.split(":");
            SpotlightController.run("qs -c ii ipc call " + parts[1] + " " + parts[2]);
            return false;
        }
        if (a === "ai-new:") {
            root.aiHistory = [];
            root.clearAi();
            searchField.text = "";
            root.query = "";
            root.scheduleRebuild();
            searchField.forceActiveFocus();
            return true;
        }
        if (a === "web:" || a === "calc:" || a === "buscar:" || a === "ai:" || a === "todo:") {
            searchField.text = e.name + " ";
            searchField.cursorPosition = searchField.text.length;
            searchField.forceActiveFocus();
            return true;
        }
        return false;
    }

    // =====================================================================
    //  REAÇÕES / CONEXÕES
    // =====================================================================
    onSelectedKeyChanged: _previewDeb.restart()
    onCirclesVisibleChanged: root.animateRail(circlesVisible ? 1.0 : 0.0)

    Connections {
        target: SpotlightActions
        function onScreenshotOcrReady(ocrText) {
            root._screenshotSelecting = false;
            const mode = root._ocrMode;
            root._ocrMode = "analyze";          // não deixa o modo "grudar"

            if (!ocrText || ocrText === "Nenhuma imagem capturada") {
                root.aiFail("❌ OCR não retornou texto (tela vazia?)");
                return;
            }
            if (mode === "translate") {
                root.runInternalAi("Translate the following text to " + root.langName(root._ocrLang)
                    + ". Reply with ONLY the translation, without quotes or explanations. Preserve line breaks.\n\n"
                    + ocrText.slice(0, 3000));
                return;
            }
            root.runInternalAi("Analise este texto extraído de uma screenshot e responda de forma útil:\n\n" + ocrText.slice(0, 3000));
        }
        function onPageReady(page) {
            const focus = root._resumeFocus;
            root._resumeFocus = "";
            if (!page || !page.ok) {
                root.aiFail("❌ " + ((page && page.error) || "Não consegui ler o link"));
                return;
            }
            root.runInternalAi(root.buildResumePrompt(page, focus), "🌐 Resumir: " + (page.title || page.url));
        }
        function onScreenContextReady(windows, ocr) {
            _captureGuard.stop();
            root._capturing = false;
            Qt.callLater(() => searchField.forceActiveFocus());
            const q = root._screenQuestion;
            root._screenQuestion = "";
            if (!windows && !ocr) {
                root.aiFail("❌ Não consegui capturar a tela (grim/hyprctl)");
                return;
            }
            root.runInternalAi(root.buildScreenPrompt(windows, ocr, q), "🖥️ " + (q || "O que está na minha tela?"));
        }
        function onScrapeReady(text) {
            if (!text) { root.aiFail("❌ Não consegui baixar o link"); return; }
            root.runInternalAi("Resuma este conteúdo de página web de forma concisa:\n\n" + text.slice(0, 5000));
        }
        function onPdfReady(text) {
            if (!text) { root.aiFail("❌ Não consegui ler o PDF"); return; }
            root.runInternalAi("Resuma este PDF de forma concisa:\n\n" + text.slice(0, 6000));
        }
        function onGitDiffReady(diff) {
            if (!diff) {
                root.aiText = "📭 Nada pra commitar";
                root.rebuildIfShown();
                return;
            }
            root.runInternalAi("Gere mensagem de commit (Conventional Commits) para:\n\n" + diff);
        }
        function onBriefingReady(text) {
            if (!text) {
                root.aiText = "❌ Briefing indisponível";
                root.rebuildIfShown();
                return;
            }
            root.runInternalAi("Formate este briefing matinal de forma bonita:\n\n" + text);
        }
        function onHistoryReady(history) {
            if (Array.isArray(history) && history.length > 0) root.aiHistory = history;
        }
    }

    Connections {
        target: SpotlightController
        function onSpotlightOpenChanged() {
            if (!SpotlightController.spotlightOpen) {
                root._opened = false;
                closeAnim.start();
                return;
            }
            root._userNavigated = false;
            root._opened = true;
            root._shown = true;
            root.query = "";
            root.mode = "search";
            root.selectedIndex = 0;
            searchField.text = "";
            root.circlesVisible = false;
            root.circlesLocked = false;
            root.clearAi();
            if (!root.aiPersistentHistory) root.aiHistory = [];
            else SpotlightActions.loadHistory();
            root.passText = "";
            root._passKey = "";
            root.timeText = "";
            root._timeKey = "";
            root.procItems = [];
            root._procKey = "";
            root.devResult = { q: "", text: "", label: "" };
            root._devQ = "";
            root._buildSig = "";
            root._previewKeyShown = "";
            root.previewKind = "";
            root.previewPath = "";
            root._lastContentQuery = "";
            root.scheduleRebuild();
            if (root._pendingMode !== "") {
                root.setMode(root._pendingMode);
                root._pendingMode = "";
            }
            openAnim.start();
            Qt.callLater(() => searchField.forceActiveFocus());
        }
    }

    Connections {
        target: SpotlightApps
        ignoreUnknownSignals: true
        function onReadyChanged() {
            if (SpotlightController.spotlightOpen) root.scheduleRebuild();
        }
    }

    IpcHandler {
        target: "spotlightMode"
        function openMode(mode: string): void {
            if (SpotlightController.spotlightOpen) {
                if (root.mode === mode) SpotlightController.spotlightOpen = false;
                else root.setMode(mode);
            } else {
                root._pendingMode = mode;
                SpotlightController.spotlightOpen = true;
            }
        }
    }

    IpcHandler {
        target: "todoReminder"
        function fire(text: string): void {
            Quickshell.execDetached(["notify-send", "Lembrete", text, "-a", "Shell"]);
            Quickshell.execDetached(["bash", "-c",
                "for f in /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga " +
                "/usr/share/sounds/*/stereo/alarm-clock-elapsed.oga " +
                "/usr/share/sounds/*/stereo/complete.oga; do " +
                "[ -f \"$f\" ] || continue; " +
                "pw-play \"$f\" || paplay \"$f\" || ffplay -nodisp -autoexit -loglevel quiet \"$f\"; " +
                "break; done >> /tmp/todo-reminder.log 2>&1"
            ]);
        }
    }

    // =====================================================================
    //  ANIMAÇÕES
    // =====================================================================
    NumberAnimation {
        id: _railAnim
        target: root
        property: "railProgress"
        duration: 620
        easing.type: Easing.Linear
    }

    SequentialAnimation {
        id: openAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "panelScale"; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "panelYOffset"; to: 0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "panelOpacity"; to: 1.0; duration: 160; easing.type: Easing.OutQuad }
        }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "panelScale"; to: 0.98; duration: 140; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "panelYOffset"; to: 8; duration: 140; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "panelOpacity"; to: 0.0; duration: 120; easing.type: Easing.InQuad }
        }
        ScriptAction { script: {
            root._shown = false; root.circlesVisible = false;
            videoPlayer.stop();
            audioPlayer.stop();
        } }
    }

    // =====================================================================
    //  INTERFACE
    // =====================================================================
    MouseArea {
        anchors.fill: parent
        enabled: !root._screenshotSelecting
        onClicked: SpotlightController.spotlightOpen = false
    }

    Item {
        id: outerWrap
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(root.screen.height * 0.22) + root.panelYOffset
        width: root.panelWidth
        height: root.searchH + (root.hasBody ? root.resultsHeight + 8 : 0)
        transformOrigin: Item.Top
        scale: root.panelScale
        opacity: root.panelOpacity

        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        // ---- Fundo "vidro"
        Rectangle {
            id: panelChrome
            anchors.left: parent.left
            anchors.top: parent.top
            width: root.hasBody ? parent.width : morphSurface.mainWidth
            height: root.searchH + (root.hasBody ? root.resultsHeight + 8 : 0)
            radius: root.panelRadius
            color: root.glassBg
            border.color: root.glassBorder
            border.width: 1
            z: 0
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: root.panelRadius - 1
                color: "transparent"
                border.color: root.glassHighlight
                border.width: 1
            }
        }

        // ---- Barra de busca
        Item {
            id: searchHeader
            anchors.left: parent.left
            anchors.top: parent.top
            width: parent.width
            height: root.searchH
            z: 2

            MouseArea { anchors.fill: parent; z: -2 }

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
                surfaceColor: "transparent"
                shadowColor: "transparent"
                z: -1
            }

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
                                ctx.lineWidth = 1.6; ctx.lineCap = "round"; ctx.lineJoin = "round"
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
                        anchors.right: parent.right; anchors.rightMargin: 28
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        color: root.sFg
                        font { family: "SF Pro Display"; pixelSize: 24; weight: Font.Light }
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true; clip: true; cursorVisible: root._opened
                        focus: true
                        onActiveFocusChanged: { if (activeFocus) root.circlesLocked = false }
                        Keys.onUpPressed: (event) => { root.moveSelection(-1); event.accepted = true }
                        Keys.onDownPressed: (event) => { root.moveSelection(1); event.accepted = true }
                        Keys.onReturnPressed: (event) => root.submit(event)
                        Keys.onEnterPressed: (event) => root.submit(event)
                        Keys.onEscapePressed: (event) => {
                            if (!root._screenshotSelecting) SpotlightController.spotlightOpen = false;
                            event.accepted = true;
                        }
                        Keys.onTabPressed: (event) => { root.circlesVisible = !root.circlesVisible; event.accepted = true }
                        Keys.onPressed: (event) => {
                            if (root.handleSearchKey(event, searchField.selectedText !== "")) event.accepted = true;
                        }
                        onTextChanged: {
                            root._userNavigated = false;
                            root.query = text;
                            if (text.length > 0 && !root.circlesLocked && root.mode !== "search") root.mode = "search";
                            root.scheduleRebuild();
                            _fdDeb.restart();
                            _sideEffectsDeb.restart();
                            if (text.length > 0) root.circlesVisible = false
                        }
                    }

                    Text {
                        anchors.left: searchIconWrap.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        text: root.placeholderText
                        font { family: "SF Pro Display"; pixelSize: 24; weight: Font.Light }
                        color: root.placeholderFg
                        visible: searchField.text.length === 0
                    }
                }
            }

            // ---- Botões circulares de modo
            Item {
                id: circlesContainer
                anchors.fill: parent
                visible: root.railProgress > 0.001
                z: 300

                Repeater {
                    model: [
                        { m: "apps",      tip: "Applications", icon: Quickshell.shellPath("assets/Apps.png") },
                        { m: "files",     tip: "Files",        icon: Quickshell.shellPath("assets/Finder.png") },
                        { m: "actions",   tip: "Actions",      icon: Quickshell.shellPath("assets/Shortcuts.png") },
                        { m: "clipboard", tip: "Clipboard",    icon: Quickshell.shellPath("assets/clipboard.png") },
                        { m: "config",    tip: "Settings",     icon: Quickshell.shellPath("assets/preferences-system.png") }
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
                            anchors.fill: parent; anchors.margins: 2; radius: width / 2
                            color: root.glassBg; border.width: 1; border.color: root.glassBorder
                        }
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 4; radius: width / 2
                            color: "transparent"; border.width: 1
                            border.color: circleBtn.isActive ? Qt.rgba(1, 1, 1, 0.28) : circleBtn.isHover ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.0)
                            Behavior on border.color { ColorAnimation { duration: 140 } }
                        }
                        Image {
                            anchors.centerIn: parent
                            width: 34; height: 34
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                        Rectangle {
                            id: tipBox
                            anchors.top: parent.bottom; anchors.topMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tipText.implicitWidth + 24; height: 30; radius: 8
                            color: root.glassBg; border.color: root.glassBorder; border.width: 1
                            visible: circleBtn.isHover
                            opacity: circleBtn.isHover ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            Text {
                                id: tipText
                                anchors.centerIn: parent
                                text: modelData.tip
                                color: root.sFgDim
                                font { family: "SF Pro Display"; pixelSize: 13 }
                            }
                        }
                        MouseArea {
                            id: circleMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.placeholderText = modelData.tip
                            onExited: root.placeholderText = "Search or Ask"
                            onClicked: {
                                root.circlesLocked = true
                                root.circlesVisible = false
                                root.setMode(root.mode === modelData.m ? "search" : modelData.m)
                            }
                        }
                    }
                }
            }

            // ---- Arrastar para abrir/fechar a trilha de modos
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
                onPressed: (mouse) => {
                    startMouseX = mouse.x
                    startProgress = root.railProgress
                    isDragging = true
                    _railAnim.stop()
                }
                onPositionChanged: (mouse) => {
                    if (!isDragging) return
                    var maxDist = root.circleSize * 4 + root.circlesGap * 4
                    root.railProgress = Math.max(0, Math.min(1, startProgress + (mouse.x - startMouseX) / maxDist))
                }
                onReleased: (mouse) => {
                    if (!isDragging) return
                    isDragging = false
                    const open = root.railProgress > 0.25
                    root.circlesVisible = open
                    root.animateRail(open ? 1.0 : 0.0)
                }
            }

            // ---- Botão limpar
            Rectangle {
                id: clearBtn
                x: morphSurface.mainWidth - width - 16
                y: (searchHeader.height - height) / 2
                width: 20; height: 20; radius: 10
                z: 100
                color: clearMA.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
                visible: root.query.length > 0
                Canvas {
                    anchors.centerIn: parent; width: 14; height: 14
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset()
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.85); ctx.lineWidth = 1.4
                        ctx.beginPath(); ctx.arc(width/2, height/2, width/2 - 1, 0, Math.PI * 2); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(width*0.35, height*0.35); ctx.lineTo(width*0.65, height*0.65)
                        ctx.moveTo(width*0.65, height*0.35); ctx.lineTo(width*0.35, height*0.65); ctx.stroke()
                    }
                }
                MouseArea { id: clearMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { searchField.text = ""; root.query = ""; root.scheduleRebuild(); searchField.forceActiveFocus() }
                }
            }
        }

        // ---- Botão que abre/fecha os modos
        Rectangle {
            id: modesToggle
            x: morphSurface.mainWidth - width - 10
            y: (searchHeader.height - height) / 2
            width: 28; height: 28; radius: 8
            z: 120
            visible: root.query.length === 0
            color: modesToggleMA.containsMouse || root.circlesVisible ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
            border.width: 1
            border.color: root.circlesVisible ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.12)
            Canvas {
                anchors.centerIn: parent
                width: 14; height: 14
                rotation: root.circlesVisible ? 0 : 180
                Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.9); ctx.lineWidth = 1.8
                    ctx.lineCap = "round"; ctx.lineJoin = "round"
                    ctx.beginPath(); ctx.moveTo(5, 3); ctx.lineTo(10, 7); ctx.lineTo(5, 11); ctx.stroke()
                }
            }
            MouseArea {
                id: modesToggleMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.circlesVisible = !root.circlesVisible
                    root.circlesLocked = true
                }
            }
        }

        // ---- Cartão de resultados
        Item {
            id: resultsCard
            anchors.top: searchHeader.bottom
            anchors.topMargin: 1
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.resultsHeight
            visible: root.hasBody && height > 0
            z: 1
            clip: true
            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Now playing
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
                    Repeater {
                        model: [
                            { cmd: "previous",   glyph: "\u23ee", size: 26 },
                            { cmd: "play-pause", glyph: "",       size: 28 },
                            { cmd: "next",       glyph: "\u23ed", size: 26 }
                        ]
                        delegate: Rectangle {
                            width: modelData.size; height: modelData.size; radius: modelData.size / 2
                            color: mediaBtnMA.containsMouse ? root.hoverBg : "transparent"
                            Text {
                                anchors.centerIn: parent
                                color: root.sFg
                                font.pixelSize: 13
                                text: modelData.cmd === "play-pause"
                                      ? (root.nowPlayingStatus === "Playing" ? "\u23f8" : "\u25b6")
                                      : modelData.glyph
                            }
                            MouseArea {
                                id: mediaBtnMA
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { _mediaCmd.command = ["bash", "-c", "playerctl " + modelData.cmd]; _mediaCmd.running = true; }
                            }
                        }
                    }
                }

                // Estatísticas do sistema
                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: 24
                    Layout.leftMargin: 14; Layout.rightMargin: 14
                    visible: root.sysStatsText.length > 0 && root.query.length === 0 && root.mode === "search"
                    Text {
                        Layout.fillWidth: true
                        text: root.sysStatsText
                        color: root.sFgDim
                        font { family: "SF Pro Text"; pixelSize: 11 }
                        elide: Text.ElideRight
                    }
                }

                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true

                    ListView {
                        id: resultList
                        visible: root.mode !== "apps"
                        anchors.fill: parent
                        anchors.topMargin: 4
                        anchors.bottomMargin: 8
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        model: root.results
                        spacing: 1
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        reuseItems: true

                        ScrollBar.vertical: ScrollBar {
                            id: resultScrollBar
                            policy: resultList.contentHeight > resultList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            width: 8
                            contentItem: Rectangle {
                                implicitWidth: 6; radius: 3
                                color: Qt.rgba(1, 1, 1, 0.35)
                                opacity: resultScrollBar.pressed ? 0.85 : 0.5
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }
                            background: Rectangle { implicitWidth: 6; color: "transparent" }
                        }

                        delegate: Item {
                            required property var modelData
                            readonly property bool isDanger: modelData.action === "clipboard:clear"
                            readonly property bool isHeader: modelData.isHeader === true
                            readonly property bool isClipImage: modelData.kind === "clip" && modelData.isImage === true && !!modelData.imagePath
                            width: resultList.width
                            height: isHeader ? root.headerH : root.rowH
                            Text {
                                visible: isHeader
                                anchors.left: parent.left; anchors.leftMargin: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                                text: modelData.title || ""
                                font { family: "SF Pro Display"; pixelSize: 11; weight: Font.DemiBold }
                                color: root.headerFg
                            }
                            Rectangle {
                                visible: !isHeader
                                anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4
                                radius: 8
                                color: {
                                    if (isDanger) return rowHover.containsMouse ? Qt.rgba(1, 0.27, 0.23, 0.20) : Qt.rgba(1, 0.27, 0.23, 0.10);
                                    if (root.selectedIndex === modelData._idx) return root.selectionBg;
                                    if (rowHover.containsMouse) return root.hoverBg;
                                    return "transparent";
                                }
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }
                            RowLayout {
                                visible: !isHeader
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 10
                                Image {
                                    visible: modelData.kind === "app"
                                    Layout.preferredWidth: root.iconSize; Layout.preferredHeight: root.iconSize; Layout.alignment: Qt.AlignVCenter
                                    source: modelData.icon || ""
                                    sourceSize { width: root.iconSize * 2; height: root.iconSize * 2 }
                                    asynchronous: true; smooth: true
                                }
                                Image {
                                    visible: isClipImage
                                    Layout.preferredWidth: 60; Layout.preferredHeight: 44; Layout.alignment: Qt.AlignVCenter
                                    source: visible ? ("file://" + modelData.imagePath) : ""
                                    sourceSize { width: 120; height: 88 }
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true; smooth: true; mipmap: true
                                    Rectangle { anchors.fill: parent; radius: 5; color: "transparent"; border.color: Qt.rgba(1, 1, 1, 0.18); border.width: 1 }
                                }
                                Item {
                                    visible: modelData.kind !== "app" && !isClipImage
                                    Layout.preferredWidth: root.iconSize; Layout.preferredHeight: root.iconSize; Layout.alignment: Qt.AlignVCenter
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 18; height: 18; radius: 5
                                        visible: !!modelData.swatch
                                        color: modelData.swatch || "transparent"
                                        border.color: Qt.rgba(1, 1, 1, 0.4); border.width: 1
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 0; Layout.alignment: Qt.AlignVCenter
                                    Text {
                                        Layout.fillWidth: true; text: modelData.name || ""
                                        font { family: "SF Pro Display"; pixelSize: 14; weight: Font.Medium }
                                        color: isDanger ? "#FF6961" : root.sFg
                                        elide: Text.ElideRight; maximumLineCount: 1
                                        wrapMode: modelData.kind === "info" ? Text.Wrap : Text.NoWrap
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        visible: !!modelData.category && modelData.category.length > 0
                                        text: modelData.category || ""
                                        font { family: "SF Pro Text"; pixelSize: 11 }
                                        color: root.sFgDim
                                        elide: Text.ElideRight; maximumLineCount: 1
                                    }
                                }
                            }
                            MouseArea {
                                id: rowHover
                                visible: !isHeader
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onPositionChanged: {
                                    if (root.selectedIndex !== modelData._idx) {
                                        root._userNavigated = true
                                        root.selectedIndex = modelData._idx
                                    }
                                }
                                onClicked: (mouse) => {
                                    root.selectedIndex = modelData._idx

                                    // Ctrl + clique → copia o caminho do arquivo
                                    if (mouse.modifiers & Qt.ControlModifier) {
                                        const it = root.items[root.selectedIndex]
                                        if (it && it.kind === "file" && it.path) {
                                            root.copyText(it.path)
                                            SpotlightController.spotlightOpen = false
                                        }
                                        return
                                    }
                                    // Shift + clique → abre a pasta | clique normal → abre o arquivo
                                    root.openSelected(!!(mouse.modifiers & Qt.ShiftModifier))
                                }
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
                        currentIndex: root.selectedIndex
                        reuseItems: true
                        ScrollBar.vertical: ScrollBar {
                            policy: resultGrid.contentHeight > resultGrid.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            width: 8
                            contentItem: Rectangle { implicitWidth: 6; radius: 3; color: Qt.rgba(1,1,1,0.35) }
                            background: Rectangle { implicitWidth: 6; color: "transparent" }
                        }
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: resultGrid.cellWidth
                            height: resultGrid.cellHeight
                            Rectangle {
                                anchors.fill: parent; anchors.margins: 3; radius: 8
                                color: {
                                    if (root.selectedIndex === index) return root.selectionBg;
                                    if (gridHover.containsMouse) return root.hoverBg;
                                    return "transparent";
                                }
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
                                    font { family: "SF Pro Display"; pixelSize: 13 }
                                    color: root.sFg
                                    elide: Text.ElideRight; maximumLineCount: 1
                                }
                            }
                            MouseArea { id: gridHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onPositionChanged: {
                                    if (root.selectedIndex !== index) {
                                        root._userNavigated = true;
                                        root.selectedIndex = index;
                                    }
                                }
                                onClicked: (mouse) => {
                                    root.selectedIndex = index;
                                    root.openSelected(!!(mouse.modifiers & Qt.ShiftModifier));
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent; text: "No Results Found"
                        font { family: "SF Pro Display"; pixelSize: 14 }
                        color: root.sFgDim
                        visible: root.query.length > 0 && root.items.length === 0
                    }
                }
            }
        }

        // ---- Popup de preview (imagem, texto, markdown, PDF, vídeo, áudio)
        Rectangle {
            id: previewPopup
            visible: root.previewKind !== ""
            anchors.left: searchHeader.right
            anchors.leftMargin: 16
            anchors.top: searchHeader.top
            width: root.previewBox.w
            height: root.previewBox.h
            radius: root.panelRadius
            color: root.glassBg
            border.color: root.glassBorder
            border.width: 1
            clip: true
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; z: -1 }

            Image {
                id: previewImg
                visible: root.previewKind === "image"
                anchors.fill: parent; anchors.margins: 10
                source: root.previewKind === "image" && root.previewPath ? root.fileUrl(root.previewPath) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true; cache: true
                sourceSize.width: 1400; sourceSize.height: 1400
                onStatusChanged: {
                    if (status === Image.Ready) { root.previewNatW = implicitWidth; root.previewNatH = implicitHeight; }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: root.previewKind === "image" && previewImg.status === Image.Error
                text: "Não foi possível carregar esta imagem"
                horizontalAlignment: Text.AlignHCenter
                color: root.sFgDim
                font { family: "SF Pro Text"; pixelSize: 12 }
            }
            Flickable {
                id: previewTextFlick
                visible: root.previewKind === "text"
                anchors.fill: parent; anchors.margins: 12; anchors.rightMargin: 22
                clip: true
                contentWidth: width; contentHeight: previewTextItem.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Text {
                    id: previewTextItem
                    width: previewTextFlick.width
                    text: root.previewText
                    color: root.sFgDim
                    font { family: "JetBrains Mono"; pixelSize: 16 }
                    wrapMode: Text.Wrap
                }
                ScrollBar.vertical: ScrollBar {
                    policy: previewTextFlick.contentHeight > previewTextFlick.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    width: 6
                    contentItem: Rectangle { implicitWidth: 6; radius: 3; color: Qt.rgba(1,1,1,0.35) }
                }
            }
            Flickable {
                id: previewMdFlick
                visible: root.previewKind === "markdown"
                anchors.fill: parent; anchors.margins: 12; anchors.rightMargin: 22
                clip: true
                contentWidth: width; contentHeight: previewMdItem.implicitHeight
                Text {
                    id: previewMdItem
                    width: previewMdFlick.width
                    text: root.previewText
                    textFormat: Text.MarkdownText
                    color: root.sFg
                    font { family: "SF Pro Text"; pixelSize: 15 }
                    wrapMode: Text.Wrap
                }
            }
            Image {
                visible: root.previewKind === "pdf"
                anchors.fill: parent; anchors.margins: 10
                source: root.previewKind === "pdf" && root.previewThumbPath ? root.fileUrl(root.previewThumbPath) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true; cache: true
                sourceSize.width: 1400; sourceSize.height: 1400
            }
            Item {
                visible: root.previewKind === "video"
                anchors.fill: parent; anchors.margins: 10
                MediaPlayer {
                    id: videoPlayer
                    source: root.previewKind === "video" && root.previewPath ? root.fileUrl(root.previewPath) : ""
                    videoOutput: videoOut
                    audioOutput: AudioOutput { volume: 0.7 }
                    onMetaDataChanged: {
                        const r = metaData.resolution;
                        if (root.previewKind === "video" && r && r.width > 0 && r.height > 0) {
                            root.previewNatW = r.width;
                            root.previewNatH = r.height;
                        }
                    }
                }
                VideoOutput { id: videoOut; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectFit }
                Image {
                    anchors.fill: parent
                    source: root.previewThumbPath ? root.fileUrl(root.previewThumbPath) : ""
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 1000; sourceSize.height: 1000
                    visible: videoPlayer.playbackState !== MediaPlayer.PlayingState
                            && videoPlayer.playbackState !== MediaPlayer.PausedState
                    asynchronous: true
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 48; height: 48; radius: 24
                    color: Qt.rgba(0, 0, 0, 0.45)
                    visible: videoPlayer.playbackState !== MediaPlayer.PlayingState
                    Text { anchors.centerIn: parent; text: "▶"; color: "#ffffff"; font.pixelSize: 20 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: videoPlayer.play() }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: videoPlayer.playbackState === MediaPlayer.PlayingState
                    onClicked: videoPlayer.pause()
                }
            }
            Item {
                visible: root.previewKind === "audio"
                anchors.fill: parent; anchors.margins: 10
                Image {
                    id: audioCoverImgPopup
                    anchors.fill: parent; anchors.bottomMargin: 40
                    source: root.previewThumbPath ? root.fileUrl(root.previewThumbPath) : ""
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 800; sourceSize.height: 800
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
                    color: audioPlayPopupMA.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.15)
                    Row {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: root.previewAudioPlaying ? "\u23f8" : "\u25b6"; color: "#ffffff"; font.pixelSize: 13 }
                        Text { text: root.previewAudioPlaying ? "Pause" : "Play"; color: "#ffffff"; font.pixelSize: 11 }
                    }
                    MouseArea {
                        id: audioPlayPopupMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (audioPlayer.playbackState === MediaPlayer.PlayingState) audioPlayer.pause();
                            else audioPlayer.play();
                        }
                    }
                }
                MediaPlayer {
                    id: audioPlayer
                    source: root.previewKind === "audio" && root.previewPath ? root.fileUrl(root.previewPath) : ""
                    audioOutput: AudioOutput { volume: 0.8 }
                }
            }
        }

        // ---- Popup da IA (Hermes Agent)
        Rectangle {
            id: aiPopup
            visible: root.aiText.length > 0 && root.previewKind === ""
            anchors.left: searchHeader.right
            anchors.leftMargin: 16
            anchors.top: searchHeader.top

            width: 460

            readonly property real aiMinH: 160
            readonly property real aiMaxH: 700
            readonly property real aiPad: 28
            readonly property real aiExtra: 8

            height: Math.min(aiMaxH, Math.max(aiMinH, aiBody.implicitHeight + aiPad + aiExtra))

            radius: root.panelRadius
            color: root.glassBg
            border.color: root.glassBorder
            border.width: 1
            clip: true

            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent; z: -1 }

            ColumnLayout {
                id: aiBody
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 8

                // Cabeçalho
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SiriOrb {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        size: 26
                        active: root.aiLoading
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!root.aiLoading) {
                                const turns = Math.floor(root.aiHistory.length / 2);
                                return turns > 0 ? "Hermes Agent · " + turns + " msg" : "Hermes Agent"
                            }
                            if (root.aiErrored) return "Hermes Agent · erro"
                            return "Hermes Agent" + ".".repeat((_dotsTimer.tick % 3) + 1)
                        }
                        color: root.aiErrored ? "#FF6961" : root.sFg
                        font { family: "SF Pro Display"; pixelSize: 13; weight: Font.DemiBold }
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        width: 24; height: 24; radius: 6
                        visible: !root.aiLoading && root.aiText.length > 0 && !root.aiErrored
                        color: copyMA.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        Text { anchors.centerIn: parent; text: "\u29c9"; color: root.sFg; font.pixelSize: 13 }
                        MouseArea {
                            id: copyMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.copyText(root.aiText)
                        }
                    }

                    Rectangle {
                        width: 24; height: 24; radius: 6
                        color: newConvMA.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        visible: root.aiHistory.length > 0
                        Canvas {
                            anchors.centerIn: parent
                            width: 12; height: 12
                            onPaint: {
                                var ctx = getContext("2d"); ctx.reset()
                                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.85); ctx.lineWidth = 1.4
                                ctx.lineCap = "round"
                                ctx.beginPath()
                                ctx.moveTo(2, 2); ctx.lineTo(10, 10)
                                ctx.moveTo(10, 2); ctx.lineTo(2, 10)
                                ctx.stroke()
                            }
                        }
                        MouseArea {
                            id: newConvMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.newAiConversation()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root.divider
                }

                // Mensagens
                ScrollView {
                    id: aiScroll
                    Layout.fillWidth: true
                    Layout.preferredHeight: {
                        const headerish = 40 + 1 + 8
                        const inputish = 40 + 8 + 18
                        const maxBody = aiPopup.aiMaxH - aiPopup.aiPad - headerish - inputish
                        return Math.min(Math.max(aiMessages.implicitHeight, 40), maxBody)
                    }
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical: ScrollBar {
                        width: 6
                        policy: aiScroll.contentHeight > aiScroll.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        contentItem: Rectangle {
                            implicitWidth: 6; radius: 3
                            color: Qt.rgba(1, 1, 1, 0.35)
                        }
                        background: Rectangle { implicitWidth: 6; color: "transparent" }
                    }

                    ColumnLayout {
                        id: aiMessages
                        width: aiScroll.availableWidth
                        spacing: 8

                        Repeater {
                            model: root.aiHistory
                            delegate: Item {
                                id: bubbleItem
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: bubble.implicitHeight + 22
                                readonly property bool isUser: modelData.role === "user"
                                property real anim: 0
                                readonly property string ts: modelData.ts || ""
                                Component.onCompleted: {
                                    if (index === root.aiHistory.length - 1) enterAnim.start()
                                    else anim = 1
                                }
                                SequentialAnimation {
                                    id: enterAnim
                                    NumberAnimation { target: bubbleItem; property: "anim"; from: 0; to: 1.08; duration: 200; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: bubbleItem; property: "anim"; to: 1.0; duration: 140; easing.type: Easing.OutBack }
                                }
                                SiriOrb {
                                    id: avatar
                                    visible: !isUser
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    width: 22; height: 22; size: 22
                                    active: false
                                    showRing: false
                                }
                                Rectangle {
                                    id: bubble
                                    anchors.right: isUser ? parent.right : undefined
                                    anchors.left: isUser ? undefined : avatar.right
                                    anchors.leftMargin: 8
                                    transform: [
                                        Translate { y: (1 - bubbleItem.anim) * 12 },
                                        Scale {
                                            origin.x: isUser ? bubble.width : 0
                                            origin.y: bubble.height
                                            xScale: 0.9 + 0.1 * bubbleItem.anim
                                            yScale: 0.9 + 0.1 * bubbleItem.anim
                                        }
                                    ]
                                    opacity: Math.min(1, bubbleItem.anim)
                                    radius: 18
                                    width: Math.min(parent.width * (isUser ? 0.78 : 0.85), implicitWidth)
                                    implicitWidth: bubbleText.implicitWidth + 24
                                    implicitHeight: bubbleText.implicitHeight + 20
                                    gradient: Gradient {
                                        orientation: Gradient.Diagonal
                                        GradientStop { position: 0.0; color: isUser ? Qt.rgba(0.20, 0.55, 1.0, 0.95) : Qt.rgba(1, 1, 1, 0.12) }
                                        GradientStop { position: 1.0; color: isUser ? Qt.rgba(0.10, 0.40, 0.95, 0.95) : Qt.rgba(1, 1, 1, 0.06) }
                                    }
                                    border.width: 1
                                    border.color: isUser ? Qt.rgba(0.40, 0.70, 1.0, 0.35) : Qt.rgba(1, 1, 1, 0.14)
                                    Text {
                                        id: bubbleText
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                        anchors.margins: 12
                                        text: modelData.label || modelData.content
                                        textFormat: isUser ? Text.PlainText : Text.MarkdownText
                                        color: "#ffffff"
                                        font { family: "SF Pro Text"; pixelSize: 14 }
                                        wrapMode: Text.Wrap
                                    }
                                }
                                Row {
                                    anchors.top: bubble.bottom; anchors.topMargin: 3
                                    anchors.right: isUser ? bubble.right : undefined
                                    anchors.left: isUser ? undefined : bubble.left
                                    spacing: 4
                                    Text { text: bubbleItem.ts; color: Qt.rgba(1, 1, 1, 0.28); font { family: "SF Pro Text"; pixelSize: 9 } }
                                    Text { visible: isUser; text: "✓✓"; color: Qt.rgba(0.4, 0.75, 1.0, 0.7); font { family: "SF Pro Text"; pixelSize: 9; weight: Font.Bold } }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.aiLoading ? 30 : 0
                            visible: root.aiLoading
                            SequentialAnimation on opacity {
                                running: root.aiLoading; loops: Animation.Infinite
                                NumberAnimation { to: 0.4; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                            Row {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Text { text: "Hermes está digitando"; color: root.sFgDim; font { family: "SF Pro Text"; pixelSize: 12; italic: true } }
                                Text { text: ".".repeat((_dotsTimer.tick % 3) + 1); color: root.sFgDim; font { family: "SF Pro Text"; pixelSize: 12; italic: true } }
                            }
                        }

                        Connections {
                            target: root
                            function onAiHistoryChanged() {
                                Qt.callLater(() => {
                                    scrollAnim.to = Math.max(0, aiScroll.contentHeight - aiScroll.height)
                                    scrollAnim.start()
                                })
                            }
                        }

                        NumberAnimation {
                            id: scrollAnim
                            target: aiScroll.contentItem
                            property: "contentY"
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // Entrada de chat
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: chatInput.activeFocus ? root.accent : Qt.rgba(1, 1, 1, 0.12)
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 6
                        spacing: 8
                        TextInput {
                            id: chatInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            color: root.sFg
                            font { family: "SF Pro Text"; pixelSize: 14 }
                            selectByMouse: true; clip: true
                            enabled: !root.aiLoading
                            Text {
                                anchors.fill: parent
                                text: root.aiLoading ? "Aguarde…" : "Continuar a conversa…"
                                color: root.placeholderFg
                                font: chatInput.font
                                verticalAlignment: Text.AlignVCenter
                                visible: chatInput.text.length === 0
                            }
                            function sendNow() {
                                const t = text;
                                if (root.sendChat(t)) text = "";
                            }
                            Keys.onReturnPressed: (event) => { sendNow(); event.accepted = true; }
                            Keys.onEnterPressed: (event) => { sendNow(); event.accepted = true; }
                        }
                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            color: {
                                if (root.aiLoading) return Qt.rgba(1, 1, 1, 0.04);
                                if (sendMA.containsMouse) return Qt.rgba(0.0, 0.48, 1.0, 0.55);
                                return Qt.rgba(0.0, 0.48, 1.0, 0.35);
                            }
                            Canvas {
                                anchors.centerIn: parent
                                width: 14; height: 14
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.reset()
                                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.9); ctx.lineWidth = 1.6
                                    ctx.lineCap = "round"; ctx.lineJoin = "round"
                                    ctx.beginPath()
                                    ctx.moveTo(2, 7); ctx.lineTo(12, 7)
                                    ctx.moveTo(8, 3); ctx.lineTo(12, 7); ctx.lineTo(8, 11)
                                    ctx.stroke()
                                }
                            }
                            MouseArea {
                                id: sendMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.aiLoading
                                onClicked: chatInput.sendNow()
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: !root.aiLoading && root.aiHistory.length === 0
                    text: "Enter para enviar · o histórico é limpo ao fechar o Spotlight"
                    color: root.headerFg
                    font { family: "SF Pro Text"; pixelSize: 10 }
                }
            }
        }
    }

    // =====================================================================
    //  TIMERS
    // =====================================================================
    Timer { id: _previewDeb; interval: 120; repeat: false; onTriggered: root.updatePreview() }
    Timer { id: _fdDeb; interval: 140; repeat: false; onTriggered: root.runFd() }
    Timer { id: _sideEffectsDeb; interval: 250; repeat: false; onTriggered: root.runSideEffects() }
    Timer { id: _rebuildDeb; interval: 30; repeat: false; onTriggered: root.buildResults() }
    Timer { id: _aiDeb; interval: 1200; repeat: false; onTriggered: root.runHermes(root._pendingAiPrompt) }

    Timer {
        id: _screenshotDeb
        interval: 150
        repeat: false
        property bool useSelectArea: true
        onTriggered: SpotlightActions.runScreenshotOcr(useSelectArea)
    }

    Timer {
        id: _captureGuard
        interval: 45000; repeat: false
        onTriggered: {
            if (!root._capturing) return;
            root._capturing = false;
            root._screenQuestion = "";
            root.aiFail("❌ A captura da tela demorou demais");
        }
    }

    Timer {
        id: _aiRetryTimer
        interval: 1000; repeat: false
        property string prompt: ""
        onTriggered: { if (prompt) root.runHermes(prompt, true); }
    }

    Timer {
        id: _dotsTimer
        interval: 400
        running: root.aiLoading
        repeat: true
        property int tick: 0
        onTriggered: tick++
    }

    Timer {
        id: _mprisTimer
        interval: 2000; running: root._shown; repeat: true
        triggeredOnStart: true
        onTriggered: _mprisPoll.running = true
    }

    Timer {
        id: _statsTimer
        interval: 3000; repeat: true
        running: root._shown && root.showSysStats
        triggeredOnStart: true
        onTriggered: { if (!_stats.running) _stats.running = true; }
    }

    // =====================================================================
    //  PROCESSOS
    // =====================================================================
    Process { id: _mediaCmd; running: false }
    Process { id: _saveUsage; running: false }

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
                    root.rebuildIfShown();
                }
            }
        }
    }

    Process {
        id: terminalProcess
        running: false
        property string commandText: ""
        command: [root.terminal, "--", "bash", "-lc", commandText + "; echo; read -n 1 -s -r -p 'Pressione qualquer tecla para fechar...'"]
    }

    Process {
        id: _fd; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const id = parseInt(lines.shift());
                if (id !== root._fdReq) return;
                root.fileItems = root.parseFdLines(lines);
                root.scheduleRebuild();
            }
        }
    }

    Process {
        id: _recents; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.browseDir = lines.shift().trim();
                root.recentItems = root.parseFdLines(lines);
                if (root.mode === "files") root.scheduleRebuild();
            }
        }
    }

    Process {
        id: _rg; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const id = parseInt(lines.shift());
                if (id !== root._rgReq) return;
                root.contentResults = lines.filter(Boolean).map(p => {
                    const sp = root.splitPath(p);
                    return { name: sp.name, path: p, dir: sp.dir };
                });
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _clip; running: false
        command: ["bash", "-c", "cache=\"$HOME/.cache/quickshell/spotlight-clipboard\"; mkdir -p \"$cache\"; cliphist list 2>/dev/null | head -n 30 | while IFS=$'\\t' read -r id preview; do [ -n \"$id\" ] || continue; mime=$(cliphist decode \"$id\" 2>/dev/null | file --brief --mime-type - 2>/dev/null); case \"$mime\" in image/*) ext=${mime#image/}; case \"$ext\" in jpeg) ext=jpg;; svg+xml) ext=svg;; esac; path=\"$cache/$id.$ext\"; cliphist decode \"$id\" > \"$path\" 2>/dev/null && printf '%s\\tIMAGE\\t%s\\t%s\\n' \"$id\" \"$path\" \"$mime\";; *) printf '%s\\tTEXT\\t\\t%s\\n' \"$id\" \"$preview\";; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const l of text.split("\n")) {
                    if (!l.trim()) continue;
                    const parts = l.split("\t");
                    const id = (parts[0] || "").trim();
                    const isImage = parts[1] === "IMAGE";
                    const imagePath = isImage ? (parts[2] || "").trim() : "";
                    const mime = isImage ? (parts[3] || "image") : "";
                    const t = isImage ? (mime + " image") : (parts.slice(3).join("\t") || parts[1] || "").trim();
                    if (!id) continue;
                    out.push({ id: id, text: t.length > 120 ? t.slice(0, 120) + "\u2026" : t, isImage: isImage, imagePath: imagePath });
                }
                root.clipItems = out; if (root.mode === "clipboard") root.scheduleRebuild();
            }
        }
    }

    Process {
        id: _clipClear
        running: false
        command: ["bash", "-c", "cliphist wipe && rm -f \"$HOME/.cache/quickshell/spotlight-clipboard/\"*"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.clipItems = [];
                if (root.mode === "clipboard") root.scheduleRebuild();
            }
        }
    }

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
                const s = root.query.trim().toLowerCase();
                const m = s.match(/^(define|significado|meaning)\s+(.+)$/);
                if (m) {
                    const pt = m[1] === "significado";
                    const lang = pt ? "pt-BR" : "en";
                    const word = m[2].trim().replace(pt ? /[^a-zà-ú-]/g : /[^a-z-]/g, "");
                    if (word) root.cacheSet("dict:" + lang + ":" + word, def);
                }
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _loadUsage; running: false
        command: ["bash", "-c", "cat ~/.cache/spotlight-usage.json 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.usageCounts = JSON.parse(text.trim() || "{}"); } catch (e) { root.usageCounts = {}; }
            }
        }
    }

    Process {
        id: _addEvent
        running: false
        property string title: ""
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                CalendarEvents.refresh();
                root.notify("Event added: " + title);
            } else {
                root.notify("Could not add event", true);
            }
        }
    }

    Process {
        id: _currency; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const p = root._pendingCurrency;
                    if (p && data.rates && data.rates[p.to] !== undefined) {
                        const result = (p.val * data.rates[p.to]).toFixed(p.to === "BTC" ? 8 : 2);
                        const txt = p.val + " " + p.from + " = " + result + " " + p.to;
                        root.currencyText = txt;
                        root.cacheSet("cur:" + p.from + ":" + p.to + ":" + p.val, txt);
                    } else {
                        root.currencyText = "";
                    }
                } catch (e) { root.currencyText = ""; }
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _battery; running: false
        command: ["bash", "-c", "upower -i $(upower -e | grep -m1 BAT) 2>/dev/null | grep -E 'percentage|state'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (!t) { root.batteryText = "No battery detected"; }
                else {
                    const pct = (t.match(/percentage:\s*(\S+)/) || [])[1] || "?";
                    const state = (t.match(/state:\s*(\S+)/) || [])[1] || "";
                    root.batteryText = pct + (state ? " \u2014 " + state : "");
                }
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _ipInfo; running: false
        command: ["bash", "-c", "echo \"Local: $(hostname -I 2>/dev/null | awk '{print $1}')\"; echo \"Public: $(curl -s --max-time 8 ifconfig.me 2>/dev/null)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ipText = text.trim().replace("\n", "  \u2022  ");
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _windows; running: false
        command: ["bash", "-c", "hyprctl clients -j 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.windowItems = data.map(w => ({ title: w.title || w.class || "(untitled)", address: w.address, cls: w.class || "" }));
                } catch (e) { root.windowItems = []; }
                if (root.mode === "windows") root.scheduleRebuild();
            }
        }
    }

    Process {
        id: _wifi; running: false
        command: ["bash", "-c", "nmcli -t -f active,ssid dev wifi list 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(Boolean);
                const seen = {}; const out = [];
                for (const l of lines) {
                    const parts = l.split(":");
                    const active = parts[0] === "yes";
                    const ssid = parts.slice(1).join(":");
                    if (!ssid || seen[ssid]) continue;
                    seen[ssid] = true;
                    out.push({ ssid: ssid, active: active });
                }
                root.wifiItems = out;
                if (root.mode === "wifi") root.scheduleRebuild();
            }
        }
    }

    Process {
        id: _bt; running: false
        command: ["bash", "-c", "bluetoothctl devices Paired 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(Boolean);
                root.btItems = lines.map(l => {
                    const p = l.trim().split(" ");
                    return { mac: p[1] || "", name: p.slice(2).join(" ") || l };
                });
                if (root.mode === "bluetooth") root.scheduleRebuild();
            }
        }
    }

    Process {
        id: _ps; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const id = parseInt(lines.shift());
                if (id !== root._psReq) return;
                const out = [];
                for (const l of lines) {
                    const m = l.trim().match(/^(\d+)\s+(\d+)\s+(.+)$/);
                    if (!m) continue;
                    out.push({ pid: parseInt(m[1]), mb: Math.round(parseInt(m[2]) / 1024), name: m[3] });
                }
                root.procItems = out;
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _dev; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const id = parseInt(lines.shift());
                if (id !== root._devReq) return;
                let out = lines.join("\n").trim();
                if (!out) out = root._devLabel.indexOf("decodificado") >= 0 ? "Base64 inválido" : "(vazio)";
                root.devResult = { q: root._devQ, text: out, label: root._devLabel };
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _stats; running: false
        command: ["bash", "-c", `
            read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat
            sleep 0.4
            read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat
            t1=$((u1+n1+s1+i1+w1+q1+sq1+st1)); t2=$((u2+n2+s2+i2+w2+q2+sq2+st2))
            dt=$((t2-t1)); di=$(((i2+w2)-(i1+w1)))
            if [ "$dt" -gt 0 ]; then cpu=$((100*(dt-di)/dt)); else cpu=0; fi
            ram=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%.1f/%.1f GB",(t-a)/1048576,t/1048576}' /proc/meminfo)
            disk=$(df --output=pcent / | tail -1 | tr -d ' ')
            echo "CPU $cpu% \u00b7 RAM $ram \u00b7 Disco $disk"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                root.sysStatsText = text.trim();
                if (root._shown && root.query.length === 0 && root.mode === "search") root.scheduleRebuild();
            }
        }
    }

    Process {
        id: _pass; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t.length !== root._passWanted) return;
                root.passText = t;
                root.rebuildIfShown();
            }
        }
    }

    Process {
        id: _preview; running: false
        stdout: StdioCollector { onStreamFinished: { root.previewText = text; } }
    }

    Process {
        id: _clipPreview; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._clipPrevKey !== root.selectedKey) return;
                const nl = text.indexOf("\n");
                const head = nl >= 0 ? text.slice(0, nl) : text;
                const body = nl >= 0 ? text.slice(nl + 1) : "";
                if (head.startsWith("FILE\t")) {
                    root.previewFile(head.slice(5), false);
                } else {
                    root.previewKind = "text";
                    root.previewPath = "clip:" + root.selectedKey;
                    root.previewText = body;
                }
            }
        }
    }

    Process {
        id: _pdfThumb; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.previewPath === root._pendingPreview.for && root.previewKind === "pdf")
                    root.previewThumbPath = root._pendingPreview.path;
            }
        }
    }

    Process {
        id: _videoThumb; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.previewPath === root._pendingPreview.for && root.previewKind === "video")
                    root.previewThumbPath = root._pendingPreview.path;
            }
        }
    }

    Process {
        id: _audioCover; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.previewPath === root._pendingPreview.for && root.previewKind === "audio")
                    root.previewThumbPath = root._pendingPreview.path;
            }
        }
    }

    Component.onCompleted: {
        root.buildResults();
        _loadUsage.running = true;
    }
}