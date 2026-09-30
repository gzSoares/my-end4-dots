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

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: root._shown
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "macos:spotlight"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root._shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── Configuração ──
    property string terminal: "kitty"
    property bool aiAutoQuestion: false
    readonly property string geminiModel: "gemini-3-flash-preview"

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

    property bool _shown: false
    property string query: ""
    property int selectedIndex: 0
    property var items: []
    property var results: []
    property var fileItems: []
    property string mode: "search"
    property var recentItems: []
    property string browseDir: ""   // "" = home foldeer
    property bool _userNavigated: false
    property string _clipPrevKey: ""
    property string _pendingMode: ""
    property var clipItems: []
    property bool _opened: false
    property bool railOpen: root.railProgress > 0.001
    property bool hasBody: (root.mode !== "search"
            || root.query.length > 0
            || root.items.length > 0
            || root.nowPlayingText.length > 0)
        // com os círculos abertos e sem texto, só o header aparece (pílula + círculos)
        && !(root.railOpen && root.query.length === 0)
    // sysStatsText NÃO entra aqui — evita a "faixa" escura com a linha
    property bool slashMode: root.query.startsWith("/")
    property string nowPlayingText: ""
    property string nowPlayingStatus: ""
    property string weatherText: ""
    property string timeText: ""
    property string _timeKey: ""
    property int _timeReq: 0
    property var _timeXhr: null
    property var devResult: ({ q: "", text: "", label: "" })
    property string _devQ: ""
    property string _devLabel: ""
    property int _devReq: 0
    property var procItems: []
    property string _procKey: ""
    property int _psReq: 0
    property bool showSysStats: true
    property string weatherCity: "Itapira"
    property string _wxLastCity: ""
    property int _wxReq: 0
    property var _wxXhr: null
    property string dictText: ""
    property string previewPath: ""
    property string previewKind: ""
    property string previewText: ""
    property string previewThumbPath: ""
    readonly property bool previewAudioPlaying: audioPlayer.playbackState === MediaPlayer.PlayingState
    property string _previewKeyShown: ""
    property real previewNatW: 0
    property real previewNatH: 0
    property string batteryText: ""
    property string ipText: ""
    property string sysStatsText: ""
    property string currencyText: ""
    property var _pendingCurrency: null
    property var windowItems: []
    property var wifiItems: []
    property var btItems: []
    property var contentResults: []
    property string _lastContentQuery: ""
    property var usageCounts: ({})
    property var _pendingPreview: ({ for: "", path: "", kind: "" })
    property string _buildSig: ""

    property int _fdReq: 0
    property int _rgReq: 0

    property string passText: ""
    property string _passKey: ""
    property int _passWanted: 0

    property string aiText: ""
    property string _lastAiQuery: ""
    property bool aiLoading: false
    property int _aiReq: 0
    property var _aiXhr: null

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

    // ════════════════════════════════════════════════════════════════
    // HELPERS
    // ════════════════════════════════════════════════════════════════
    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function urlq(s) {
        return encodeURIComponent(String(s)).replace(/'/g, "%27");
    }

    function xdgOpenCmd(target) {
        return "setsid nohup env XDG_RUNTIME_DIR=/run/user/$(id -u) " +
               "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus " +
               "xdg-open " + root.shellQuote(target) + " </dev/null >/dev/null 2>&1";
    }

    function xdgOpen(target) {
        SpotlightController.run(root.xdgOpenCmd(target) + " &");
    }

    function fileUrl(path) {
        if (!path) return "";
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function openUrl(u) {
        console.log("[spotlight] openUrl:", u);
        let ok = false;
        try { ok = Qt.openUrlExternally(u); } catch (e) { console.warn("[spotlight] Qt.openUrlExternally falhou:", e); }
        if (!ok) {
            console.warn("[spotlight] Qt.openUrlExternally retornou false; usando xdg-open/gio");
            SpotlightController.run(
                "(" + root.xdgOpenCmd(u) + ") || gio open " + root.shellQuote(u) + " >/dev/null 2>&1 &"
            );
        }
    }

    function copyText(s) {
        SpotlightController.run("printf '%s' " + root.shellQuote(s) + " | wl-copy 2>/dev/null || true");
    }

    function startTimer(secs, label) {
        const n = parseInt(secs);
        if (isNaN(n) || n <= 0) return;
        TimerService.setCountdownTime(n);
        TimerService.toggleCountdown();
        SpotlightController.run("notify-send 'Spotlight Timer' " + root.shellQuote("Timer started (" + label + ")"));
    }

    function parseTodoInput(raw) {
        let text = String(raw).trim();
        const pad = n => (n < 10 ? "0" : "") + n;
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
            if (hasDate) {
                target = new Date(dY, dM - 1, dD, hh, mm);
            } else {
                // sem data: hoje se a hora ainda não passou, senão amanhã
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
        return { text: t.text, dueStr: t.dueStr, dueLabel: t.dueLabel,
                remindAt: t.remindAt, remindMs: t.remindMs, duration: duration };
    }

    function scheduleReminder(whenStr, text) {
        const script = 'qs -c ii ipc call todoReminder fire "$1" || notify-send -a Shell Lembrete "$1"';
        SpotlightController.run(
            "systemd-run --user --quiet --collect --on-calendar=" + root.shellQuote(whenStr) +
            " --timer-property=AccuracySec=1s" +
            " bash -c " + root.shellQuote(script) + " _ " + root.shellQuote(text)
        );
    }

    function focusWindow(address) {
        SpotlightController.run("hyprctl dispatch focuswindow " + root.shellQuote("address:" + address));
    }

    function itemKey(it) {
        if (!it) return "";
        return it.kind + ":" + (it.path || it.exec || it.address || it.action || it.id || it.text || it.name || "");
    }

    function recordUsage(key) {
        const counts = Object.assign({}, root.usageCounts);
        counts[key] = (counts[key] || 0) + 1;

        const keys = Object.keys(counts);
        if (keys.length > 600) {
            const fk = keys.filter(k => k.startsWith("file:")).sort((a, b) => counts[a] - counts[b]);
            for (let i = 0; i < keys.length - 500 && i < fk.length; i++) delete counts[fk[i]];
        }

        root.usageCounts = counts;
        _saveUsage.command = ["bash", "-c", "mkdir -p ~/.cache && cat > ~/.cache/spotlight-usage.json << 'SPTEOF'\n" + JSON.stringify(counts) + "\nSPTEOF"];
        _saveUsage.running = true;
    }

    function hasOwn(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }

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

        if ((m = ql.match(/^(?:volume|vol|som)\s*([+-])?\s*(\d{1,3})$/))) {
            const n = clamp(parseInt(m[2]), 0, 150);
            const fb = "; notify-send -t 1500 Volume \"$(wpctl get-volume @DEFAULT_AUDIO_SINK@)\"";
            if (m[1]) add("Volume " + m[1] + n + "%", "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ " + n + "%" + m[1] + fb);
            else add("Volume: " + n + "%", "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ " + n + "%" + fb);
        } else if (/^(mudo|mute|silenciar)$/.test(ql)) {
            add("Alternar mudo", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle");
        } else if ((m = ql.match(/^(?:brilho|brightness|bright)\s*([+-])?\s*(\d{1,3})$/))) {
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

    function splitPath(p) {
        const i = p.lastIndexOf("/");
        return { name: i >= 0 ? p.slice(i + 1) : p, dir: i > 0 ? p.slice(0, i) : "~" };
    }

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

    function previewSizeLarge() {
        const maxW = 580, maxH = 700, minW = 300, minH = 400;
        const w = root.previewNatW, h = root.previewNatH;
        if (!w || !h) return { w: 420, h: 560 };
        let scaleFit = Math.min(maxW / w, maxH / h);
        let outW = w * scaleFit, outH = h * scaleFit;
        if (outW < minW) { const s = minW / outW; outW = minW; outH = outH * s; }
        if (outH < minH) { const s = minH / outH; outH = minH; outW = outW * s; }
        outW = Math.min(outW, maxW); outH = Math.min(outH, maxH);
        return { w: outW, h: outH };
    }

    // ── Visual macOS Spotlight ──
    readonly property color glassBg: Qt.rgba(30 / 255, 30 / 255, 30 / 255, 0.72)
    readonly property color glassBorder: Qt.rgba(1, 1, 1, 0.12)
    readonly property color glassHighlight: Qt.rgba(1, 1, 1, 0.06)
    readonly property color selectionBg: Qt.rgba(0.0, 0.48, 1.0, 0.45)
    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.08)
    readonly property color divider: Qt.rgba(1, 1, 1, 0.10)
    readonly property color headerFg: Qt.rgba(1, 1, 1, 0.45)
    readonly property color sFg: Qt.rgba(1, 1, 1, 0.92)
    readonly property color sFgDim: Qt.rgba(1, 1, 1, 0.55)
    readonly property color placeholderFg: Qt.rgba(1, 1, 1, 0.40)
    readonly property color accent: "#0A84FF"

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

    property real panelOpacity: 0.0
    property real panelScale: 0.96
    property real panelYOffset: 12
    property bool circlesVisible: false
    property bool circlesLocked: false
    property string placeholderText: "Spotlight Search"
    property real railProgress: 0.0

    function animateRail(target) {
        _railAnim.stop()
        _railAnim.from = root.railProgress
        _railAnim.to = target
        _railAnim.duration = Math.max(100, Math.round(620 * Math.abs(target - root.railProgress)))
        _railAnim.start()
    }

    onCirclesVisibleChanged: root.animateRail(circlesVisible ? 1.0 : 0.0)

    NumberAnimation {
        id: _railAnim
        target: root
        property: "railProgress"
        duration: 620
        easing.type: Easing.Linear
    }

    // ════════════════════════════════════════════════════════════════
    // BUSCAS ASSÍNCRONAS
    // ════════════════════════════════════════════════════════════════
    function runFd() {
        if (root.slashMode || root.query.trim().length < 2) { root.fileItems = []; root.buildResults(); return; }
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
        if (!term || root._lastContentQuery === term) return;
        root._lastContentQuery = term;
        const id = ++root._rgReq;
        _rg.exec(["bash", "-c",
            "echo " + id + "; rg -l -i -F --max-count 1 -e " + root.shellQuote(term) + " ~ 2>/dev/null | head -12"
        ]);
    }

    function convertUnits(q) {
        const s = q.trim().toLowerCase().replace(/,/g, ".");
        const m = s.match(/^(-?[\d.]+)\s*([a-zçãõáéíóúâêô°\/]+)\s+(?:in|to|em|para|->|=)\s+([a-zçãõáéíóúâêô°\/]+)$/);
        if (!m) return null;
        const val = parseFloat(m[1]);
        if (isNaN(val)) return null;

        const alias = {
            milha: "mi", milhas: "mi", mile: "mi", miles: "mi",
            libra: "lb", libras: "lb", pound: "lb", pounds: "lb", lbs: "lb",
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
        const req = ++root._wxReq;
        if (root._wxXhr) { try { root._wxXhr.abort(); } catch (e) {} }

        const geo = new XMLHttpRequest();
        root._wxXhr = geo;
        geo.timeout = 10000;
        geo.onreadystatechange = function () {
            if (geo.readyState !== XMLHttpRequest.DONE || req !== root._wxReq) return;
            let place = null;
            try {
                const data = JSON.parse(geo.responseText);
                const list = data.results || [];
                place = (preferBR && list.find(r => r.country_code === "BR")) || list[0] || null;
            } catch (e) { place = null; }
            if (!place) { root.weatherText = "Cidade não encontrada: " + city; if (root._shown) root.buildResults(); return; }

            const wx = new XMLHttpRequest();
            root._wxXhr = wx;
            wx.timeout = 10000;
            wx.onreadystatechange = function () {
                if (wx.readyState !== XMLHttpRequest.DONE || req !== root._wxReq) return;
                try {
                    const c = JSON.parse(wx.responseText).current;
                    const d = root.wxDescribe(c.weather_code);
                    const where = place.name + (place.admin1 ? ", " + place.admin1 : "") +
                                  (place.country_code !== "BR" && place.country ? ", " + place.country : "");
                    root.weatherText = where + ": " + d[0] + " " + Math.round(c.temperature_2m) + "°C" +
                        " (sensação " + Math.round(c.apparent_temperature) + "°C) · " + d[1] +
                        " · umidade " + Math.round(c.relative_humidity_2m) + "% · vento " + Math.round(c.wind_speed_10m) + " km/h";
                } catch (e) { root.weatherText = "Não foi possível obter o clima"; }
                if (root._shown) root.buildResults();
            };
            wx.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=" + place.latitude + "&longitude=" + place.longitude +
                "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m&timezone=auto");
            wx.send();
        };
        geo.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=10&language=pt&name=" + encodeURIComponent(city));
        geo.send();
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
        root._pendingCurrency = { val: parseFloat(m[1]), from: from.toUpperCase(), to: to.toUpperCase() };
        _currency.exec(["bash", "-c", "curl -s --max-time 10 'https://api.exchangerate-api.com/v4/latest/" + from.toUpperCase() + "' 2>/dev/null"]);
    }

    function checkBattery() {
        const s = root.query.trim().toLowerCase();
        if (s === "bateria" || s === "battery") {
            _battery.running = true;
        } else if (root.batteryText) {
            root.batteryText = "";
        }
    }

    function checkMyIp() {
        const s = root.query.trim().toLowerCase();
        if (s === "meu ip" || s === "my ip") {
            _ipInfo.running = true;
        } else if (root.ipText) {
            root.ipText = "";
        }
    }

    function checkPassword() {
        const s = root.query.trim().toLowerCase();
        const m = s.match(/^(senha|password)\s*(\d+)?$/);
        if (!m) {
            if (root.passText) root.passText = "";
            root._passKey = "";
            return;
        }
        if (root._passKey === s) return;
        root._passKey = s;
        const len = Math.max(4, Math.min(64, parseInt(m[2] || "16")));
        root._passWanted = len;
        _pass.exec(["bash", "-c", "LC_ALL=C tr -dc 'A-Za-z0-9!@#$%&*' </dev/urandom | head -c " + len]);
    }

    function runGemini(prompt) {
        if (!prompt) return;
        if (prompt === root._lastAiQuery && root.aiText && !root.aiLoading) return;

        const key = Quickshell.env("GEMINI_API_KEY");
        if (!key) {
            root._lastAiQuery = prompt;
            root.aiLoading = false;
            root.aiText = "GEMINI_API_KEY não está definida no ambiente do Quickshell";
            root.buildResults();
            return;
        }

        root._lastAiQuery = prompt;
        root.aiLoading = true;
        root.aiText = "Thinking…";

        const req = ++root._aiReq;
        if (root._aiXhr) { try { root._aiXhr.abort(); } catch (e) {} }

        const xhr = new XMLHttpRequest();
        root._aiXhr = xhr;

        const finish = (answer) => {
            if (req !== root._aiReq) return;
            if (answer.length > 2000) answer = answer.slice(0, 2000) + "…";
            root.aiText = answer;
            root.aiLoading = false;
            root._aiXhr = null;
            if (root._shown) root.buildResults();
        };

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (req !== root._aiReq) return;
            let answer = "";
            try {
                const data = JSON.parse(xhr.responseText);
                const cand = data.candidates && data.candidates[0];
                const parts = cand && cand.content && cand.content.parts;
                if (parts && parts.length) {
                    answer = parts.map(p => p.text || "").join("").trim();
                }
                if (!answer) {
                    if (data.error && data.error.message) answer = "Gemini error: " + data.error.message;
                    else if (cand && cand.finishReason === "MAX_TOKENS") answer = "Resposta cortada (MAX_TOKENS) — aumente maxOutputTokens";
                    else answer = "No AI response";
                }
            } catch (e) {
                answer = xhr.status === 0 ? "Sem resposta da API (rede/timeout)" : "Erro ao consultar a IA (HTTP " + xhr.status + ")";
            }
            finish(answer);
        };

        xhr.open("POST", "https://generativelanguage.googleapis.com/v1beta/models/" + root.geminiModel + ":generateContent");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("x-goog-api-key", key);
        xhr.timeout = 20000;
        xhr.send(JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: { maxOutputTokens: 2048 }
        }));

        root.buildResults();
    }

    function langName(c) {
        const n = { en: "English", pt: "Brazilian Portuguese", es: "Spanish", fr: "French", de: "German", it: "Italian",
                    ja: "Japanese", ko: "Korean", zh: "Chinese", ru: "Russian", ar: "Arabic", nl: "Dutch", pl: "Polish", tr: "Turkish" };
        const k = c.toLowerCase();
        return root.hasOwn(n, k) ? n[k] : c;
    }

    function checkAI() {
        const s = root.query.trim();
        const tm = s.match(/^(?:tr|traduzir|translate)\s+([a-z]{2}(?:-[a-z]{2})?)\s+(.+)$/i);
        const m = s.match(/^\/?(ai|gpt|ia)\s+(.+)$/i);
        const isSlashOther = s.startsWith("/") && !/^\/ai\s/i.test(s);
        const isQuestion = root.aiAutoQuestion && !s.startsWith("/") && s.endsWith("?") && s.length > 3;

        let prompt = "";
        if (tm) prompt = "Translate the following text to " + root.langName(tm[1]) +
                         ". Reply with ONLY the translation, without quotes or explanations.\n\n" + tm[2];
        else if (m && m[2] && (!s.startsWith("/") || m[1].toLowerCase() === "ai")) prompt = m[2].trim();
        else if (isQuestion) prompt = s;

        if (!prompt || isSlashOther) {
            if (root.aiText !== "") {
                root._aiReq++;
                if (root._aiXhr) { try { root._aiXhr.abort(); } catch (e) {} root._aiXhr = null; }
                root.aiText = "";
                root.aiLoading = false;
                root._lastAiQuery = "";
            }
            return;
        }
        root.runGemini(prompt);
    }

    function fetchTime(city) {
        const req = ++root._timeReq;
        if (root._timeXhr) { try { root._timeXhr.abort(); } catch (e) {} }

        const geo = new XMLHttpRequest();
        root._timeXhr = geo;
        geo.timeout = 10000;
        geo.onreadystatechange = function () {
            if (geo.readyState !== XMLHttpRequest.DONE || req !== root._timeReq) return;
            let place = null;
            try { place = (JSON.parse(geo.responseText).results || [])[0] || null; } catch (e) { place = null; }
            if (!place) { root.timeText = "Cidade não encontrada: " + city; if (root._shown) root.buildResults(); return; }

            const tz = new XMLHttpRequest();
            root._timeXhr = tz;
            tz.timeout = 10000;
            tz.onreadystatechange = function () {
                if (tz.readyState !== XMLHttpRequest.DONE || req !== root._timeReq) return;
                try {
                    const data = JSON.parse(tz.responseText);
                    const off = data.utc_offset_seconds;
                    const now = new Date();
                    const there = new Date(now.getTime() + now.getTimezoneOffset() * 60000 + off * 1000);
                    const pad = (n) => (n < 10 ? "0" : "") + n;
                    const wd = ["dom", "seg", "ter", "qua", "qui", "sex", "s\u00e1b"][there.getDay()];
                    const localOff = -now.getTimezoneOffset() * 60;
                    const diff = (off - localOff) / 3600;
                    const diffStr = diff === 0 ? "mesmo fuso que você"
                                  : (diff > 0 ? "+" : "") + (Number.isInteger(diff) ? diff : diff.toFixed(1)) + "h em relação a você";
                    const where = place.name + (place.admin1 ? ", " + place.admin1 : "") +
                                  (place.country ? ", " + place.country : "");
                    root.timeText = where + ": " + pad(there.getHours()) + ":" + pad(there.getMinutes()) +
                                    " \u00b7 " + wd + " " + pad(there.getDate()) + "/" + pad(there.getMonth() + 1) +
                                    " \u00b7 " + diffStr + " (" + data.timezone + ")";
                } catch (e) { root.timeText = "Não foi possível obter a hora"; }
                if (root._shown) root.buildResults();
            };
            tz.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=" + place.latitude + "&longitude=" + place.longitude +
                    "&current=temperature_2m&timezone=auto");
            tz.send();
        };
        geo.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=3&language=pt&name=" + encodeURIComponent(city));
        geo.send();
    }

    function checkTime() {
        const s = root.query.trim().toLowerCase();
        const m = s.match(/^(?:que\s+)?(?:hora|horas|time)\s+(?:em|in|de|no|na|do|da|for)\s+(.+)$/);
        if (!m) {
            if (root.timeText) { root._timeReq++; root._timeKey = ""; root.timeText = ""; }
            return;
        }
        const city = m[1].trim();
        if (!city || (root._timeKey === city && root.timeText)) return;
        root._timeKey = city;
        root.fetchTime(city);
    }

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
        _ps.exec(["bash", "-c",
            "echo " + id + "; ps -u \"$USER\" -o pid=,rss=,comm= --sort=-rss | grep -i -F -- " + root.shellQuote(name) + " | head -12"
        ]);
    }

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
        else {
            cmd = "printf '%s' " + root.shellQuote(arg) + " | " + kind + "sum | cut -d' ' -f1";
            label = kind.toUpperCase();
        }
        root._devQ = q;
        root._devLabel = label;
        const id = ++root._devReq;
        _dev.exec(["bash", "-c", "echo " + id + "; " + cmd]);
    }

    function checkContentSearch() {
        const m = root.query.trim().match(/^\/buscar\s+(.+)$/i);
        if (m && m[1].trim()) root.runContentSearch(m[1].trim());
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

    // ════════════════════════════════════════════════════════════════
    // PREVIEW
    // ════════════════════════════════════════════════════════════════
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
    audioPlayer.stop();
    root.previewThumbPath = "";
    root.previewNatW = 0;
    root.previewNatH = 0;

    const ext = p.split(".").pop().toLowerCase();
    const imgExts = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"];
    const textExts = ["txt", "md", "json", "qml", "js", "ts", "py", "sh", "conf", "yaml", "yml", "xml", "html", "css", "c", "cpp", "h", "lua", "toml", "ini", "log"];
    const videoExts = ["mp4", "mkv", "webm", "avi", "mov", "m4v", "flv"];
    const audioExts = ["mp3", "flac", "wav", "ogg", "opus", "m4a", "aac"];

    if (isDirectory) {
        root.previewKind = ""; root.previewPath = ""; root.previewText = "";
    } else if (imgExts.indexOf(ext) !== -1) {
        root.previewKind = "image";
        root.previewPath = p;
        root.previewText = "";
    } else if (textExts.indexOf(ext) !== -1) {
        root.previewKind = "text";
        root.previewPath = p;
        _preview.exec(["bash", "-c", "head -c 1500 " + root.shellQuote(p) + " 2>/dev/null | iconv -c -t UTF-8 2>/dev/null"]);
    } else if (videoExts.indexOf(ext) !== -1) {
        root.previewKind = "video";
        root.previewPath = p;
        const thumbPath = "/tmp/spotlight_thumb_" + Date.now() + ".jpg";
        root._pendingPreview = { for: p, path: thumbPath, kind: "video" };
        _videoThumb.exec(["bash", "-c",
            "rm -f /tmp/spotlight_thumb_*.jpg; ffmpegthumbnailer -i " + root.shellQuote(p) +
            " -o " + root.shellQuote(thumbPath) + " -s 400 2>/dev/null"
        ]);
    } else if (audioExts.indexOf(ext) !== -1) {
        root.previewKind = "audio";
        root.previewPath = p;
        const coverPath = "/tmp/spotlight_cover_" + Date.now() + ".jpg";
        root._pendingPreview = { for: p, path: coverPath, kind: "audio" };
        _audioCover.exec(["bash", "-c",
            "rm -f /tmp/spotlight_cover_*.jpg; ffmpeg -y -i " + root.shellQuote(p) +
            " -an -frames:v 1 " + root.shellQuote(coverPath) + " 2>/dev/null"
        ]);
    } else if (ext === "pdf") {
        root.previewKind = "pdf";
        root.previewPath = p;
        const thumbBase = "/tmp/spotlight_pdf_" + Date.now();
        root._pendingPreview = { for: p, path: thumbBase + ".jpg", kind: "pdf" };
        _pdfThumb.exec(["bash", "-c",
            "rm -f /tmp/spotlight_pdf_*.jpg; " +
            "pdftoppm -jpeg -f 1 -l 1 -scale-to 1200 " + root.shellQuote(p) + " " + root.shellQuote(thumbBase) + " 2>/dev/null; " +
            "f=$(ls " + root.shellQuote(thumbBase) + "*.jpg 2>/dev/null | head -1); " +
            "[ -n \"$f\" ] && mv \"$f\" " + root.shellQuote(thumbBase + ".jpg")
        ]);
    } else {
        root.previewKind = ""; root.previewPath = ""; root.previewText = "";
    }
}

function previewClipText(id) {
    root._clipPrevKey = root.selectedKey;
    const script = [
        "c=$(cliphist decode " + id + " 2>/dev/null | head -c 4000)",
        "n=$(printf '%s\\n' \"$c\" | wc -l)",
        "first=$(printf '%s\\n' \"$c\" | tr -d '\\r' | grep -m1 -E '^(file://|/)')",
        "case \"$first\" in",
        "  file://*) p=$(printf '%b' \"$(printf '%s' \"$first\" | sed 's#^file://##; s/%/\\\\x/g')\") ;;",
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

    if (it && it.kind === "file") {
        root.previewFile(it.path, !!it.isDirectory);
        return;
    }

    if (it && it.kind === "clip") {
        if (it.isImage && it.imagePath) { root.previewFile(it.imagePath, false); return; }
        if (/^\d+$/.test(it.id || "")) { root.previewClipText(it.id); return; }
    }

    root.resetPreview();
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
        if (root.sysStatsText.length > 0 && root.query.length === 0 && root.mode === "search") h += 24;
        for (const r of root.results) h += r.isHeader ? root.headerH : root.rowH;
        if (root.items.length === 0 && root.query.length > 0) h += 56;
        return Math.min(maxH, Math.max(48, h + 12));
    }

    function evalMath(q) {
        if (!/^[0-9+\-*/%.()\s]+$/.test(q)) return null;
        try {
            const r = Function('"use strict";return (' + q + ')')();
            if (typeof r !== "number" || !isFinite(r)) return null;
            return r;
        } catch (e) { return null; }
    }

    function _addItems(items, disp, arr, title) {
        if (!arr.length) return;
        if (title) disp.push({ isHeader: true, title: title });
        for (const it of arr) {
            it._idx = items.length;
            it._dispIdx = disp.length;
            items.push(it);
            disp.push(it);
        }
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
                const ua = root.usageCounts["file:" + a.path] || 0, ub = root.usageCounts["file:" + b.path] || 0;
                if (ua !== ub) return ub - ua;
                return root.naturalCompare(a.name, b.name);
            });
        }

        const targetPath = targetDir.path;
        const prefix = targetPath + "/";

        const groupOf = (f) => {
            if (f === targetDir) return 0;
            if (f.path.startsWith(prefix)) return 1;
            return 2;
        };

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

    function _buildSlashMode(items, disp, ql) {
        const full = ql.slice(1);
        const spaceIdx = full.indexOf(" ");
        const cmdName = spaceIdx >= 0 ? full.slice(0, spaceIdx) : full;
        const cmdArgs = spaceIdx >= 0 ? full.slice(spaceIdx + 1).trim() : "";

        if (cmdName === "web" && cmdArgs.length > 0) {
            _addItems(items, disp, [{ kind: "action", name: "Search the Web for \u201c" + cmdArgs + "\u201d", action: "web:" + cmdArgs, iconKey: "web", category: "Search" }], "WEB SEARCH");
            return true;
        }
        if (cmdName === "calc" && cmdArgs.length > 0) {
            const cr = root.evalMath(cmdArgs);
            if (cr !== null) _addItems(items, disp, [{ kind: "calc", name: "= " + cr, raw: String(cr), category: "Calculator", iconKey: "calc" }], "CALCULATOR");
            return true;
        }
        if (cmdName === "buscar" && cmdArgs.length > 0) {
            _addItems(items, disp, root.contentResults.map(f => ({ kind: "file", name: f.name, path: f.path, category: f.dir })), "CONTENT: " + cmdArgs);
            return true;
        }
        if (cmdName === "ai" && cmdArgs.length > 0) {
            if (root.aiText) {
                _addItems(items, disp, [{ kind: "info", name: root.aiLoading ? "Thinking…" : "Ver resposta no popup ao lado", category: root.aiLoading ? "Gemini · thinking…" : "Gemini — Enter to copy" }], "AI");
            }
            return true;
        }
        if (cmdName === "emoji") {
            const filter = cmdArgs.toLowerCase()
            let list = root.emojiList
            if (filter.length > 0) {
                list = list.filter(function (x) {
                    return x.n.indexOf(filter) !== -1 || x.e.indexOf(filter) !== -1
                })
            }
            const shown = list.slice(0, 100).map(function (x) {
                return {
                    kind: "emoji",
                    name: x.e + "  " + x.n,
                    raw: x.e,
                    category: "Emoji — Enter to copy"
                }
            })
            _addItems(items, disp, shown, filter ? "EMOJI: " + filter : "EMOJI")
            return true
        }

        if ((cmdName === "todo" || cmdName === "notes") && cmdArgs.length > 0) {
            // o ql vem em minúsculas; pega o texto original para manter maiúsculas
            const orig = root.query.trim().slice(1);
            const t = root.parseTodoInput(orig.slice(spaceIdx + 1));
            _addItems(items, disp, [{
                kind: "action",
                name: "Add to ToDo: \u201c" + t.text + "\u201d" + (t.dueLabel ? " \u00b7 " + t.dueLabel : ""),
                action: "addtodo:",
                todoText: t.text,
                todoDue: t.dueStr,
                todoRemind: t.remindAt,
                todoRemindMs: t.remindMs,
                iconKey: "note",
                category: t.remindAt ? "ToDo \u00b7 vai avisar na hora" : "ToDo"
            }], "TODO");
            return true;
        }

        if ((cmdName === "calendar" || cmdName === "cal" || cmdName === "evento" || cmdName === "event") && cmdArgs.length > 0) {
            const orig = root.query.trim().slice(1);
            const ev = root.parseEventInput(orig.slice(spaceIdx + 1));
            if (!ev.dueStr) {
                _addItems(items, disp, [{ kind: "info", name: "Informe data ou hora: /evento reunião 02/10 às 14h", category: "Evento" }], "EVENTO");
                return true;
            }
            _addItems(items, disp, [{
                kind: "action",
                name: "Add event: \u201c" + ev.text + "\u201d \u00b7 " + ev.dueLabel +
                    (ev.remindAt ? " \u00b7 " + ev.duration + " min" : " \u00b7 dia inteiro"),
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
            return true;
        }

        const allCmds = [
            { kind: "cmd", name: "/apps",       category: "Switch to Applications",         action: "mode:apps" },
            { kind: "cmd", name: "/files",      category: "Switch to Files",                action: "mode:files" },
            { kind: "cmd", name: "/clipboard",  category: "Switch to Clipboard",            action: "mode:clipboard" },
            { kind: "cmd", name: "/actions",    category: "Switch to Actions",              action: "mode:actions" },
            { kind: "cmd", name: "/wallpaper",  category: "Change wallpaper (ii)",          action: "ipc:wallpaperSelector:toggle" },
            { kind: "cmd", name: "/tema",       category: "Toggle light/dark theme (ii)",   action: "ipc:theme:toggleLightDark" },
            { kind: "cmd", name: "/barra",      category: "Show/hide bar (ii)",             action: "ipc:bar:toggle" },
            { kind: "cmd", name: "/screenshot", category: "Take screenshot (ii)",           action: "ipc:region:screenshot" },
            { kind: "cmd", name: "/record",     category: "Record screen (ii)",             action: "ipc:region:record" },
            { kind: "cmd", name: "/ocr",        category: "Screen OCR (ii)",                action: "ipc:region:ocr" },
            { kind: "cmd", name: "/cor",        category: "Color picker (copies hex)",      action: "colorpick:" },
            { kind: "cmd", name: "/janelas",    category: "Switch between open windows",    action: "mode:windows" },
            { kind: "cmd", name: "/wifi",       category: "Wi-Fi networks",                 action: "mode:wifi" },
            { kind: "cmd", name: "/bluetooth",  category: "Paired Bluetooth devices",       action: "mode:bluetooth" },
            { kind: "cmd", name: "/buscar",     category: "Search inside files (ripgrep)",  action: "buscar:" },
            { kind: "cmd", name: "/ai",         category: "Ask Gemini",                     action: "ai:" },
            { kind: "cmd", name: "/todo",       category: "Add a ToDo task",                action: "todo:" },
            { kind: "cmd", name: "/evento",     category: "Add a calendar event",           action: "todo:" },
            { kind: "cmd", name: "/calendar",        category: "Add a calendar event",           action: "todo:" },
            { kind: "cmd", name: "/notes",      category: "Add a ToDo task",                action: "todo:" },
            { kind: "cmd", name: "/lock",       category: "Lock Screen",                    action: "sys:lock" },
            { kind: "cmd", name: "/sleep",      category: "Sleep",                          action: "sys:sleep" },
            { kind: "cmd", name: "/restart",    category: "Restart",                        action: "sys:restart" },
            { kind: "cmd", name: "/shutdown",   category: "Shut Down",                      action: "sys:shutdown" },
            { kind: "cmd", name: "/logout",     category: "Log Out",                        action: "sys:logout" },
            { kind: "cmd", name: "/web",        category: "Search the Web",                 action: "web:" },
            { kind: "cmd", name: "/calc",       category: "Calculator",                     action: "calc:" },
        ];
        const filtered = cmdName.length > 0
            ? allCmds.filter(c => c.name.slice(1).toLowerCase().startsWith(cmdName))
            : allCmds;
        _addItems(items, disp, filtered, "COMMANDS");
        return true;
    }

    function _buildAppsMode(items, disp, q, ql) {
        const list = (ql ? SpotlightApps.search(q) : SpotlightApps.apps).slice();
        list.sort((a, b) => (root.usageCounts["app:" + b.exec] || 0) - (root.usageCounts["app:" + a.exec] || 0));
        _addItems(items, disp, list.slice(0, 60).map(a => ({ kind: "app", name: a.name, icon: a.icon, exec: a.exec, category: a.category || "Application" })), ql ? "APPLICATIONS" : "");
    }

    function _buildFilesMode(items, disp, ql) {
        let src;
        if (!ql) src = root.recentItems.slice();
        else if (root.fileItems.length) src = root.fileItems;
        else src = root.recentItems.filter(f => f.name.toLowerCase().indexOf(ql) !== -1);
        const fitems = ql ? root.sortFileResults(src, ql) : src;
        const home = root.browseDir.replace(/^\/home\/[^\/]+/, "~");
        _addItems(items, disp,
            fitems.map(f => ({
                kind: "file", name: f.name, path: f.path,
                dir: f.dir, category: f.dir, isDirectory: f.isDirectory
            })),
            ql ? "FILES" : (home || "~"));
    }

    function _buildClipboardMode(items, disp) {
        _addItems(items, disp, root.clipItems.map(c => ({
            kind: "clip", name: c.isImage ? "Image" : c.text,
            id: c.id, category: c.isImage ? (c.text || "Image") : "Clipboard",
            isImage: !!c.isImage, imagePath: c.imagePath || ""
        })), "CLIPBOARD");
    }

    function _buildWindowsMode(items, disp, ql) {
        const wlist = ql ? root.windowItems.filter(w => w.title.toLowerCase().indexOf(ql) !== -1 || w.cls.toLowerCase().indexOf(ql) !== -1) : root.windowItems;
        _addItems(items, disp, wlist.map(w => ({ kind: "window", name: w.title, address: w.address, category: w.cls })), "OPEN WINDOWS");
    }

    function _buildWifiMode(items, disp) {
        _addItems(items, disp, root.wifiItems.map(w => ({ kind: "wifi", name: w.ssid, category: w.active ? "Connected" : "Available" })), "WI-FI NETWORKS");
    }

    function _buildBluetoothMode(items, disp) {
        _addItems(items, disp, root.btItems.map(d => ({ kind: "bt", name: d.name, address: d.mac, category: d.mac })), "PAIRED BLUETOOTH");
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
        _addItems(items, disp, acts, "ACTIONS");
    }

    function urlTarget(q) {
        const t = q.trim();
        const isUrl = /^(https?:\/\/)?(www\.)?[\w-]+(\.[\w-]+)+(:\d+)?(\/\S*)?$/i.test(t)
                   && /\.(com|org|net|io|dev|app|br|pt|co|uk|edu|gov|xyz|me|tv|info|biz|gg|ai|sh|so)(\/|$|:|\?)/i.test(t);
        if (!isUrl) return "";
        return /^https?:\/\//i.test(t) ? t : "https://" + t;
    }

    function _buildSearchMode(items, disp, q, ql) {
        if (!ql && root.nowPlayingText.length > 0) {
            _addItems(items, disp, [{ kind: "media", name: root.nowPlayingText, category: root.nowPlayingStatus === "Playing" ? "Now playing" : "Paused" }], "NOW PLAYING");
        }

        if (ql) {
            const urlT = root.urlTarget(q);
            if (urlT) {
                _addItems(items, disp, [{ kind: "action", name: "Open " + q.trim(), action: "open:" + urlT, iconKey: "web", category: "Website" }], "OPEN WEBSITE");
            }

            const bang = root.bangItem(q);
            if (bang) _addItems(items, disp, [bang], "ATALHO DE SITE");

            const sc = root.sysControlItems(ql);
            if (sc.length) _addItems(items, disp, sc, "CONTROLES");

            if (root.procItems.length && /^(kill|matar|encerrar|pkill)\s/i.test(q)) {
                _addItems(items, disp, root.procItems.map(pr => ({
                    kind: "proc", name: pr.name, pid: pr.pid,
                    category: "PID " + pr.pid + " \u00b7 " + pr.mb + " MB \u00b7 Enter = encerrar \u00b7 \u21e7Enter = for\u00e7ar (SIGKILL)"
                })), "PROCESSOS");
            }

            if (root.timeText && /^(?:que\s+)?(?:hora|horas|time)\s/.test(ql)) {
                _addItems(items, disp, [{ kind: "info", name: root.timeText, category: "Hora" }], "HORA");
            }

            const colorIt = root.colorItem(q);
            if (colorIt) _addItems(items, disp, [colorIt], "COR");

            if (root.devResult.q === q && root.devResult.text) {
                _addItems(items, disp, [{ kind: "calc", name: root.devResult.text, raw: root.devResult.text,
                                          category: root.devResult.label + " \u2014 clique para copiar", iconKey: "calc" }], "FERRAMENTAS");
            }

            const apps = SpotlightApps.search(q);
            apps.sort((a, b) => (root.usageCounts["app:" + b.exec] || 0) - (root.usageCounts["app:" + a.exec] || 0));
            _addItems(items, disp, apps.map(a => ({ kind: "app", name: a.name, icon: a.icon, exec: a.exec, category: a.category || "Application" })), "APPLICATIONS");
        }
        if (ql && root.fileItems.length) {
            const fitems = root.sortFileResults(root.fileItems, q);
            _addItems(items, disp,
                fitems.map(f => ({
                    kind: "file", name: f.name, path: f.path,
                    dir: f.dir, category: f.dir, isDirectory: f.isDirectory
                })),
                "FILES");
        }

        if (ql && (ql.startsWith("clima") || ql.startsWith("weather")) && root.weatherText) {
            _addItems(items, disp, [{ kind: "info", name: root.weatherText, category: "Weather" }], "WEATHER");
        }
        if (ql && (ql.startsWith("define ") || ql.startsWith("significado ") || ql.startsWith("meaning ")) && root.dictText) {
            _addItems(items, disp, [{ kind: "info", name: root.dictText, category: "Definition" }], "DEFINITION");
        }

        if (/^(senha|password)\s*(\d+)?$/.test(ql) && root.passText) {
            _addItems(items, disp, [{ kind: "calc", name: root.passText, raw: root.passText, category: "Generated password — click to copy", iconKey: "lock" }], "PASSWORD");
        }

        const todoMatch = q.match(/^(todo|tarefa|afazer)\s+(.+)$/i);
        if (todoMatch) {
            let text = todoMatch[2].trim();
            let dueStr = "";
            let dueLabel = "";

            // data opcional no fim: YYYY-MM-DD, DD/MM ou DD/MM/YYYY
            const dm = text.match(/\s+(?:(\d{4})-(\d{1,2})-(\d{1,2})|(\d{1,2})\/(\d{1,2})(?:\/(\d{4}))?)$/);
            if (dm) {
                const iso = !!dm[1];
                const mo = parseInt(iso ? dm[2] : dm[5]);
                const d = parseInt(iso ? dm[3] : dm[4]);
                const today = new Date();
                let y = iso ? parseInt(dm[1]) : (dm[6] ? parseInt(dm[6]) : today.getFullYear());
                // sem ano e já passou este ano: usa o próximo
                if (!iso && !dm[6] && new Date(y, mo - 1, d, 23, 59) < today) y += 1;

                const check = new Date(Date.UTC(y, mo - 1, d, 12));
                if (mo >= 1 && mo <= 12 && check.getUTCMonth() === mo - 1 && check.getUTCDate() === d) {
                    const pad = n => (n < 10 ? "0" : "") + n;
                    dueStr = y + "-" + pad(mo) + "-" + pad(d);
                    dueLabel = pad(d) + "/" + pad(mo) + "/" + y;
                    const rest = text.slice(0, text.length - dm[0].length).trim();
                    if (rest) text = rest;
                }
            }

            _addItems(items, disp, [{
                kind: "action",
                name: "Add to ToDo: \u201c" + text + "\u201d" + (dueLabel ? " \u00b7 " + dueLabel : ""),
                action: "addtodo:",
                todoText: text,
                todoDue: dueStr,
                iconKey: "note",
                category: "ToDo"
            }], "TODO");
        }

        if (ql && (ql === "bateria" || ql === "battery") && root.batteryText) {
            _addItems(items, disp, [{ kind: "info", name: root.batteryText, category: "Battery" }], "BATTERY");
        }
        if (ql && (ql === "meu ip" || ql === "my ip") && root.ipText) {
            _addItems(items, disp, [{ kind: "info", name: root.ipText, category: "Network" }], "MY IP");
        }
        if (ql && root.currencyText) {
            _addItems(items, disp, [{ kind: "calc", name: root.currencyText, raw: root.currencyText, category: "Currency", iconKey: "calc" }], "CURRENCY");
        }

        if (ql && root.aiText) {
            _addItems(items, disp, [{
                kind: "info",
                name: root.aiLoading ? "Thinking…" : "Ver resposta no popup ao lado",
                category: root.aiLoading ? "Gemini · thinking…" : "Gemini — Enter to copy"
            }], "AI");
        }

        const playMatch = q.match(/^(toque|tocar|play)\s+(.+)$/i);
        if (playMatch) {
            _addItems(items, disp, [{ kind: "action", name: "Play \u201c" + playMatch[2] + "\u201d on Spotify", action: "spotifyplay:" + playMatch[2], iconKey: "music", category: "Spotify" }], "SPOTIFY");
        }

        const timerMatch = ql.match(/^timer\s+(\d+)\s*(min|m|s|sec|seg|h)?$/);
        if (timerMatch) {
            const n = parseInt(timerMatch[1]);
            const unit = timerMatch[2] || "min";
            let secs = n * 60;
            if (unit === "s" || unit === "sec" || unit === "seg") secs = n;
            else if (unit === "h") secs = n * 3600;
            _addItems(items, disp, [{ kind: "action", name: "Start " + n + " " + unit + " timer", action: "realtimer:" + secs + ":" + n + " " + unit, iconKey: "timer", category: "Timer" }], "TIMER");
        }

        const sys = [];
        if (ql && "lock screen sleep restart shut down log out".includes(ql)) {
            sys.push({ kind: "action", name: "Lock Screen", action: "lock", iconKey: "lock", category: "System" });
            sys.push({ kind: "action", name: "Sleep", action: "sleep", iconKey: "moon", category: "System" });
            sys.push({ kind: "action", name: "Restart\u2026", action: "restart", iconKey: "restart", category: "System" });
            sys.push({ kind: "action", name: "Shut Down\u2026", action: "shutdown", iconKey: "power", category: "System" });
            sys.push({ kind: "action", name: "Log Out", action: "logout", iconKey: "logout", category: "System" });
        }
        _addItems(items, disp, sys, "SYSTEM");

        if (ql) {
            const mm = /^-?[\d.]+$/.test(q) ? null : root.evalMath(q);
            if (mm !== null) {
                _addItems(items, disp, [{ kind: "calc", name: "= " + mm, raw: String(mm), category: "Calculator", iconKey: "calc" }], "CALCULATOR");
            } else {
                const cv = root.convertUnits(q);
                if (cv !== null) _addItems(items, disp, [{ kind: "calc", name: "= " + cv, raw: cv, category: "Conversion", iconKey: "calc" }], "CONVERSION");
            }

            const searchActions = [];
            searchActions.push({ kind: "action", name: "Search the Web for \u201c" + q + "\u201d", action: "web:" + q, iconKey: "web", category: "Search" });
            searchActions.push({ kind: "action", name: "Search in Files", action: "filesearch:" + q, iconKey: "finder", category: "Search" });
            _addItems(items, disp, searchActions, "SEARCH");
        }
    }

    function buildResults() {
        const q = root.query.trim();
        const ql = q.toLowerCase();
        const items = [];
        const disp = [];
        const m = root.mode;

        const prevKey = root.itemKey(root.items[root.selectedIndex]);
        const sig = m + "|" + q;

        if (ql.startsWith("/")) {
            root._buildSlashMode(items, disp, ql);
        } else if (m === "apps") {
            root._buildAppsMode(items, disp, q, ql);
        } else if (m === "files") {
            root._buildFilesMode(items, disp, ql);
        } else if (m === "clipboard") {
            root._buildClipboardMode(items, disp);
        } else if (m === "windows") {
            root._buildWindowsMode(items, disp, ql);
        } else if (m === "wifi") {
            root._buildWifiMode(items, disp);
        } else if (m === "bluetooth") {
            root._buildBluetoothMode(items, disp);
        } else if (m === "actions") {
            root._buildActionsMode(items, disp);
        } else {
            root._buildSearchMode(items, disp, q, ql);
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
            resultList.positionViewAtBeginning();
            resultGrid.positionViewAtBeginning();
        }
    }

    function setMode(m) {
        root.mode = m;
        root.selectedIndex = 0;
        if (m === "files") { root.browseDir = ""; runRecents(); }
        if (m === "clipboard") runClip();
        if (m === "windows") _windows.running = true;
        if (m === "wifi") _wifi.running = true;
        if (m === "bluetooth") _bt.running = true;
        root.buildResults();
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

    function runClip() {
        _clip.running = true;
    }

    function clearClipboard() {
        _clipClear.running = true;
    }

    function runInTerminal(command) {
        terminalProcess.commandText = command;
        terminalProcess.running = true;
    }

    function moveSelection(delta) {
        if (root.items.length === 0) return;
        root._userNavigated = true;
        root.selectedIndex = (root.selectedIndex + delta + root.items.length) % root.items.length;
        const it = root.items[root.selectedIndex];
        if (resultList.visible) {
            resultList.positionViewAtIndex(it._dispIdx, ListView.Contain);
        } else if (resultGrid.visible) {
            resultGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
        }
    }

    function openSelected(alt) {
        const queryText = root.query.trim();

        if (queryText.startsWith(">")) {
            const command = queryText.slice(1).trim();
            if (command.length > 0) root.runInTerminal(command);
            return;
        }
        const e = root.items[root.selectedIndex];
        if (!e) return;

        let keepOpen = false;

        if (e.kind === "app") { root.recordUsage("app:" + e.exec); SpotlightApps.launch(e.exec); }
        else if (e.kind === "file") {
            root.recordUsage("file:" + e.path);
            if (root.mode === "files" && root.query.trim() === "" && e.isDirectory && !alt) {
                root.browseDir = e.path;
                root.selectedIndex = 0;
                root.runRecents();
                return;              // mantém o Spotlight aberto
            }
            if (alt) {
                const i = e.path.lastIndexOf("/");
                root.xdgOpen(i > 0 ? e.path.slice(0, i) : "/");
            } else {
                root.xdgOpen(e.path);
            }
        }
        else if (e.kind === "proc") {
            if (/^\d+$/.test(String(e.pid))) {
                const sig = alt ? "KILL" : "TERM";
                SpotlightController.run("kill -" + sig + " " + e.pid + " 2>/dev/null; notify-send 'Spotlight' 'SIG" + sig + " enviado ao PID " + e.pid + "'");
            }
        }
        else if (e.kind === "clip") {
            if (/^\d+$/.test(e.id || "")) SpotlightController.run("cliphist decode " + e.id + " | wl-copy 2>/dev/null || true");
        }
        else if (e.kind === "calc") root.copyText(e.raw);
        else if (e.kind === "emoji") {
            root.copyText(e.raw)
        }
        else if (e.kind === "media") { SpotlightController.run("playerctl play-pause"); keepOpen = true; }
        else if (e.kind === "info") {
            if (root.aiText && e.category && e.category.indexOf("Gemini") !== -1) {
                if (!root.aiLoading) root.copyText(root.aiText);
                keepOpen = true;
            } else if (e.name && e.name !== "Thinking…") {
                root.copyText(e.name);
            }
        }
        else if (e.kind === "window") { root.focusWindow(e.address); }
        else if (e.kind === "wifi") { SpotlightController.run("nmcli connection up id " + root.shellQuote(e.name) + " 2>/dev/null || nmcli device wifi connect " + root.shellQuote(e.name) + " 2>/dev/null"); }
        else if (e.kind === "bt") { SpotlightController.run("bluetoothctl connect " + root.shellQuote(e.address)); }
        else if (e.kind === "action") {
            if (e.action === "shell") {
                SpotlightController.run(e.cmd);
            }
            else if (e.action.startsWith("open:")) {
                root.openUrl(e.action.slice(5));
            }
            else if (e.action.startsWith("web:")) {
                root.openUrl("https://www.google.com/search?q=" + encodeURIComponent(e.action.slice(4)));
            }
            else if (e.action.startsWith("filesearch:")) {
                root.circlesLocked = true;
                root.setMode("files");
                root.runFd();
                keepOpen = true;
            }
            else if (e.action.startsWith("spotifyplay:")) {
                const term = e.action.slice(12);
                SpotlightController.run(
                    "pgrep -x spotify >/dev/null || (setsid flatpak run com.spotify.Client </dev/null >/dev/null 2>&1 &); " +
                    "sleep 1; " + root.xdgOpenCmd("spotify:search:" + root.urlq(term)) + "; " +
                    "sleep 1; wtype -k Return 2>/dev/null || true"
                );
            }
            else if (e.action.startsWith("realtimer:")) {
                const parts = e.action.slice(10).split(":");
                root.startTimer(parts[0], parts[1] || (parts[0] + "s"));
            }
            else if (e.action === "addtodo:") {
                let due = undefined;
                if (e.todoDue) {
                    const p = e.todoDue.split("-").map(Number);
                    due = new Date(Date.UTC(p[0], p[1] - 1, p[2], 12));
                }
                Todo.addTask(e.todoText, due);
                if (e.todoRemind && e.todoRemindMs > Date.now()) {
                    root.scheduleReminder(e.todoRemind, e.todoText);
                    SpotlightController.run("notify-send 'Spotlight' 'Added to ToDo \u00b7 aviso agendado'");
                } else {
                    SpotlightController.run("notify-send 'Spotlight' 'Added to ToDo'");
                }
            }
            else if (e.action === "addevent:") {
                _addEvent.title = e.evText;
                _addEvent.command = ["python3", Quickshell.shellPath("scripts/calendar/eds-add-event.py"),
                                    e.evText, e.evDate, e.evTime, String(e.evDuration)];
                _addEvent.running = true;
                // aviso na hora do evento (apague esta linha se não quiser)
                if (e.evRemind && e.evRemindMs > Date.now()) root.scheduleReminder(e.evRemind, e.evText);
            }
            else if (e.action.startsWith("action:")) {
                const sub = e.action.slice(7);
                if (sub === "msg") root.xdgOpen("https://messages.google.com/web");
                else if (sub === "note") root.xdgOpen("obsidian://new");
                else if (sub === "timer") root.startTimer(300, "5 min");
                else if (sub === "shortcut") root.xdgOpen("shortcuts://");
                else SpotlightController.requestAction(e.action);
            }
            else if (e.action === "clipboard:clear") {
                root.clearClipboard();
                keepOpen = true;
            }
            else {
                SpotlightController.requestAction(e.action);
            }
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
            } else if (e.action === "colorpick:") {
                SpotlightController.run("hyprpicker -a 2>/dev/null || true");
            } else if (e.action.startsWith("ipc:")) {
                const parts = e.action.split(":");
                SpotlightController.run("qs -c ii ipc call " + parts[1] + " " + parts[2]);
            } else if (e.action === "web:" || e.action === "calc:" || e.action === "buscar:" || e.action === "ai:") {
                if (!searchField.text.endsWith(" ")) searchField.text = searchField.text + " ";
                searchField.cursorPosition = searchField.text.length;
                searchField.forceActiveFocus();
            } else if (e.action === "todo:") {
                searchField.text = e.name + " ";
                searchField.cursorPosition = searchField.text.length;
                searchField.forceActiveFocus();
            return;
            }
        }

        if (!keepOpen) SpotlightController.spotlightOpen = false;
    }

    property var selectedItem: (root.items.length ? root.items[root.selectedIndex] : null)
    readonly property string selectedKey: root.itemKey(root.selectedItem)
    onSelectedKeyChanged: _previewDeb.restart()

    Connections {
        target: SpotlightController
        function onSpotlightOpenChanged() {
            if (SpotlightController.spotlightOpen) {
                root._userNavigated = false;
                root._opened = true;
                root._shown = true;
                root.query = "";
                root.mode = "search";
                root.selectedIndex = 0;
                searchField.text = "";
                root.circlesVisible = false;
                root.circlesLocked = false;
                root._aiReq++;
                if (root._aiXhr) { try { root._aiXhr.abort(); } catch (e) {} root._aiXhr = null; }
                root.aiText = "";
                root.aiLoading = false;
                root._lastAiQuery = "";
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
                root.buildResults();
                    if (root._pendingMode !== "") {
                        root.setMode(root._pendingMode);
                        root._pendingMode = "";
                    }
                    openAnim.start();
                openAnim.start();
                Qt.callLater(() => searchField.forceActiveFocus());
            } else {
                root._opened = false;
                closeAnim.start();
            }
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

    Connections {
        target: SpotlightApps
        ignoreUnknownSignals: true
        function onReadyChanged() {
            if (SpotlightController.spotlightOpen) root.buildResults();
        }
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

    MouseArea {
        anchors.fill: parent
        onClicked: SpotlightController.spotlightOpen = false
    }

    Item {
        id: outerWrap
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(root.screen.height * 0.22) + root.panelYOffset
        width: root.panelWidth
        height: root.searchH + (root.hasBody ? root.computeResultsHeight() + 8 : 0)
        transformOrigin: Item.Top
        scale: root.panelScale
        opacity: root.panelOpacity

        Behavior on height {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        // Chrome único: barra + resultados (visual macOS)
        Rectangle {
            id: panelChrome
            anchors.left: parent.left
            anchors.top: parent.top
            width: root.hasBody ? parent.width : morphSurface.mainWidth
            height: root.searchH + (root.hasBody ? root.computeResultsHeight() + 8 : 0)
            radius: root.panelRadius
            color: root.glassBg
            border.color: root.glassBorder
            border.width: 1
            z: 0
            clip: true

            Behavior on height {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: root.panelRadius - 1
                color: "transparent"
                border.color: root.glassHighlight
                border.width: 1
            }
        }

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
                        Keys.onReturnPressed: (event) => { root.openSelected(!!(event.modifiers & Qt.ShiftModifier)); event.accepted = true }
                        Keys.onEnterPressed: (event) => { root.openSelected(!!(event.modifiers & Qt.ShiftModifier)); event.accepted = true }
                        Keys.onEscapePressed: (event) => { SpotlightController.spotlightOpen = false; event.accepted = true }
                        Keys.onTabPressed: (event) => { root.circlesVisible = !root.circlesVisible; event.accepted = true }
                        Keys.onPressed: (event) => {
                            // Backspace com a busca vazia no modo Files: sobe um nível
                            if (event.key === Qt.Key_Backspace && searchField.text === ""
                                    && root.mode === "files" && root.browseDir !== "" && root.browseDir !== "/") {
                                const i = root.browseDir.lastIndexOf("/");
                                root.browseDir = i > 0 ? root.browseDir.slice(0, i) : "/";
                                root.selectedIndex = 0;
                                root.runRecents();
                                event.accepted = true;
                                return;
                            }

                            if (event.modifiers & Qt.ControlModifier) {
                                if (event.key === Qt.Key_1) { root.setMode("apps"); event.accepted = true; }
                                else if (event.key === Qt.Key_2) { root.setMode("files"); event.accepted = true; }
                                else if (event.key === Qt.Key_3) { root.setMode("actions"); event.accepted = true; }
                                else if (event.key === Qt.Key_4) { root.setMode("clipboard"); event.accepted = true; }
                                else if (event.key === Qt.Key_C && searchField.selectedText === "" && root.selectedItem && root.selectedItem.kind === "file") {
                                    root.copyText(root.selectedItem.path);
                                    SpotlightController.spotlightOpen = false;
                                    event.accepted = true;
                                }
                            }
                        }
                        onTextChanged: {
                            root._userNavigated = false;
                            root.query = text;
                            if (text.length > 0 && !root.circlesLocked && root.mode !== "search") {
                                root.mode = "search";
                            }
                            root.buildResults();
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
                        { m: "clipboard", tip: "Clipboard",    icon: Quickshell.shellPath("assets/clipboard.png") }
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
                            anchors.margins: 2
                            radius: width / 2
                            color: root.glassBg
                            border.width: 1
                            border.color: root.glassBorder
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: width / 2
                            color: "transparent"
                            border.width: 1
                            border.color: circleBtn.isActive ? Qt.rgba(1, 1, 1, 0.28)
                                        : circleBtn.isHover ? Qt.rgba(1, 1, 1, 0.14)
                                        : Qt.rgba(1, 1, 1, 0.0)

                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: circleBtn.isActive ? Qt.rgba(1, 1, 1, 0.22)
                                        : circleBtn.isHover ? Qt.rgba(1, 1, 1, 0.14)
                                        : Qt.rgba(1, 1, 1, 0.0)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: circleBtn.isActive ? Qt.rgba(1, 1, 1, 0.08)
                                        : circleBtn.isHover ? Qt.rgba(1, 1, 1, 0.05)
                                        : Qt.rgba(1, 1, 1, 0.0)
                                }
                            }

                            Behavior on border.color { ColorAnimation { duration: 140 } }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 38; height: 38
                            radius: 11
                            color: Qt.rgba(0, 0, 0, 0.28)
                            visible: !!modelData.icon
                            z: -1
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 34; height: 34
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                        }

                        Rectangle {
                            id: tipBox
                            anchors.top: parent.bottom
                            anchors.topMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tipText.implicitWidth + 24
                            height: 30
                            radius: 8
                            color: root.glassBg
                            border.color: root.glassBorder
                            border.width: 1
                            visible: circleBtn.isHover
                            opacity: circleBtn.isHover ? 1.0 : 0.0
                            scale: circleBtn.isHover ? 1.0 : 0.85
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                            Text {
                                id: tipText
                                anchors.centerIn: parent
                                text: modelData.tip
                                color: root.sFgDim
                                font { family: "SF Pro Display"; pixelSize: 13; weight: Font.Normal }
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
                            }
                            onClicked: {
                                root.circlesLocked = true
                                root.circlesVisible = false
                                if (root.mode === modelData.m) root.setMode("search")
                                else root.setMode(modelData.m)
                            }
                        }
                    }
                }
            }

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

                // NÃO abrir no hover
                onEntered: { }
                onExited: { }

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
                    onClicked: { searchField.text = ""; root.query = ""; root.buildResults(); searchField.forceActiveFocus() }
                }
            }
        }

        Rectangle {
            id: modesToggle
            // à direita do campo de busca — acompanha o morph ao abrir os círculos
            x: morphSurface.mainWidth - width - 10
            y: (searchHeader.height - height) / 2
            width: 28
            height: 28
            radius: 8
            z: 120

            visible: root.query.length === 0

            // opcional: esconde o toggle enquanto os modos estão abertos
            // visible: root.railProgress < 0.15

            color: modesToggleMA.containsMouse || root.circlesVisible
                ? Qt.rgba(1, 1, 1, 0.14)
                : "transparent"
            border.width: 1
            border.color: root.circlesVisible
                        ? Qt.rgba(1, 1, 1, 0.28)
                        : Qt.rgba(1, 1, 1, 0.12)

        Canvas {
            id: toggleArrow
            anchors.centerIn: parent
            width: 14
            height: 14
            rotation: root.circlesVisible ? 0 : 180

            Behavior on rotation {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.9)
                ctx.lineWidth = 1.8
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                // chevron ▶ (abre para a direita)
                ctx.beginPath()
                ctx.moveTo(5, 3)
                ctx.lineTo(10, 7)
                ctx.lineTo(5, 11)
                ctx.stroke()
            }
        }

            MouseArea {
                id: modesToggleMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // importante: o clique não deve “vazar” para a dragZone
                onClicked: {
                    root.circlesVisible = !root.circlesVisible
                    root.circlesLocked = true   // impede hover de outra zona reabrir depois
                }
            }
        }

        Rectangle {
            id: clearClipBtn
            // centralizado logo abaixo do toggle, na altura da linha "CLIPBOARD"
            x: morphSurface.mainWidth - 36
            y: root.searchH + 4
            width: 24
            height: 24
            radius: 7
            z: 120
            visible: root.mode === "clipboard" && root.query.length === 0 && root.clipItems.length > 0

            color: clearClipMA.containsMouse ? Qt.rgba(1, 0.27, 0.23, 0.28) : Qt.rgba(1, 0.27, 0.23, 0.12)
            border.width: 1
            border.color: Qt.rgba(1, 0.27, 0.23, 0.25)
            Behavior on color { ColorAnimation { duration: 100 } }

            Canvas {
                anchors.centerIn: parent
                width: 14; height: 14
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    ctx.strokeStyle = "#FF6961"; ctx.lineWidth = 1.4
                    ctx.lineCap = "round"; ctx.lineJoin = "round"
                    ctx.beginPath(); ctx.moveTo(2, 3.5); ctx.lineTo(12, 3.5); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(5.2, 3.5); ctx.lineTo(5.2, 2); ctx.lineTo(8.8, 2); ctx.lineTo(8.8, 3.5); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(3.5, 3.5); ctx.lineTo(4.2, 12); ctx.lineTo(9.8, 12); ctx.lineTo(10.5, 3.5); ctx.stroke()
                }
            }

            Rectangle {
                anchors.right: parent.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: clearTipText.implicitWidth + 16
                height: 24
                radius: 7
                color: root.glassBg
                border.color: root.glassBorder
                border.width: 1
                visible: clearClipMA.containsMouse
                Text {
                    id: clearTipText
                    anchors.centerIn: parent
                    text: "Clear history"
                    color: root.sFgDim
                    font { family: "SF Pro Display"; pixelSize: 12 }
                }
            }

            MouseArea {
                id: clearClipMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clearClipboard()
            }
        }



        Item {
            id: resultsCard
            anchors.top: searchHeader.bottom
            anchors.topMargin: 1
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.computeResultsHeight()
            visible: root.hasBody && height > 0
            z: 1
            clip: true

            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

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
                            policy: resultList.contentHeight > resultList.height
                                    ? ScrollBar.AlwaysOn
                                    : ScrollBar.AlwaysOff
                            width: 8

                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: 3
                                color: Qt.rgba(1, 1, 1, 0.35)
                                opacity: resultScrollBar.pressed ? 0.85 : 0.5
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            background: Rectangle {
                                implicitWidth: 6
                                color: "transparent"
                            }
                        }

                        delegate: Item {
                            required property var modelData
                            readonly property bool isDanger: modelData.action === "clipboard:clear"
                            width: resultList.width
                            height: modelData.isHeader === true ? root.headerH : root.rowH

                            Text {
                                visible: modelData.isHeader === true
                                anchors.left: parent.left; anchors.leftMargin: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                                text: modelData.title || ""
                                font { family: "SF Pro Display"; pixelSize: 11; weight: Font.DemiBold }
                                color: root.headerFg
                            }

                            Rectangle {
                                visible: modelData.isHeader !== true
                                anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4
                                radius: 8
                                color: {
                                    if (isDanger) {
                                        if (rowHover.containsMouse) return Qt.rgba(1, 0.27, 0.23, 0.20);
                                        return Qt.rgba(1, 0.27, 0.23, 0.10);
                                    }
                                    if (root.selectedIndex === modelData._idx) return root.selectionBg;
                                    if (rowHover.containsMouse) return root.hoverBg;
                                    return "transparent";
                                }
                                border.width: isDanger ? 1 : 0
                                border.color: Qt.rgba(1, 0.27, 0.23, 0.22)
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

                                Image {
                                    visible: modelData.kind === "clip" && modelData.isImage === true && !!modelData.imagePath
                                    Layout.preferredWidth: 60; Layout.preferredHeight: 44; Layout.alignment: Qt.AlignVCenter
                                    source: visible ? ("file://" + modelData.imagePath) : ""
                                    sourceSize { width: 120; height: 88 }
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true; smooth: true
                                    mipmap: true
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 5
                                        color: "transparent"
                                        border.color: Qt.rgba(1, 1, 1, 0.18)
                                        border.width: 1
                                    }
                                }

                                Item {
                                    visible: modelData.kind !== "app" && !(modelData.kind === "clip" && modelData.isImage === true && !!modelData.imagePath)
                                    Layout.preferredWidth: root.iconSize; Layout.preferredHeight: root.iconSize; Layout.alignment: Qt.AlignVCenter

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 18; height: 18; radius: 5
                                        visible: !!modelData.swatch
                                        color: modelData.swatch || "transparent"
                                        border.color: Qt.rgba(1, 1, 1, 0.4); border.width: 1
                                    }

                                    Canvas {
                                        anchors.centerIn: parent
                                        width: 20; height: 20
                                        visible: modelData.kind === "file" && modelData.isDirectory === true
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            ctx.lineWidth = 1.6
                                            ctx.lineCap = "round"
                                            ctx.lineJoin = "round"
                                            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.18)
                                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.75)
                                            ctx.beginPath()
                                            ctx.moveTo(2, 6)
                                            ctx.lineTo(2, 16)
                                            ctx.quadraticCurveTo(2, 17.5, 3.5, 17.5)
                                            ctx.lineTo(16.5, 17.5)
                                            ctx.quadraticCurveTo(18, 17.5, 18, 16)
                                            ctx.lineTo(18, 8)
                                            ctx.quadraticCurveTo(18, 6.5, 16.5, 6.5)
                                            ctx.lineTo(9.5, 6.5)
                                            ctx.lineTo(8, 4.5)
                                            ctx.lineTo(3.5, 4.5)
                                            ctx.quadraticCurveTo(2, 4.5, 2, 6)
                                            ctx.closePath()
                                            ctx.fill()
                                            ctx.stroke()
                                            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.28)
                                            ctx.beginPath()
                                            ctx.moveTo(2, 8)
                                            ctx.lineTo(18, 8)
                                            ctx.lineTo(18, 7)
                                            ctx.quadraticCurveTo(18, 5.8, 16.8, 5.8)
                                            ctx.lineTo(9.2, 5.8)
                                            ctx.lineTo(7.8, 4)
                                            ctx.lineTo(3.2, 4)
                                            ctx.quadraticCurveTo(2, 4, 2, 5.2)
                                            ctx.closePath()
                                            ctx.fill()
                                        }
                                    }

                                    Canvas {
                                        anchors.centerIn: parent
                                        width: 18; height: 20
                                        visible: modelData.kind === "file" && modelData.isDirectory !== true
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            ctx.lineWidth = 1.5
                                            ctx.lineCap = "round"
                                            ctx.lineJoin = "round"
                                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.75)
                                            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.12)
                                            ctx.beginPath()
                                            ctx.moveTo(4, 1.5)
                                            ctx.lineTo(11, 1.5)
                                            ctx.lineTo(14.5, 5)
                                            ctx.lineTo(14.5, 18.5)
                                            ctx.quadraticCurveTo(14.5, 19.5, 13.5, 19.5)
                                            ctx.lineTo(4.5, 19.5)
                                            ctx.quadraticCurveTo(3.5, 19.5, 3.5, 18.5)
                                            ctx.lineTo(3.5, 2.5)
                                            ctx.quadraticCurveTo(3.5, 1.5, 4.5, 1.5)
                                            ctx.closePath()
                                            ctx.fill()
                                            ctx.stroke()
                                            ctx.beginPath()
                                            ctx.moveTo(11, 1.5)
                                            ctx.lineTo(11, 5)
                                            ctx.lineTo(14.5, 5)
                                            ctx.stroke()
                                        }
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
                                onPositionChanged: {
                                    if (root.selectedIndex !== modelData._idx) {
                                        root._userNavigated = true;
                                        root.selectedIndex = modelData._idx;
                                    }
                                }
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
                        currentIndex: root.selectedIndex
                        reuseItems: true
                        ScrollBar.vertical: ScrollBar {
                            policy: resultGrid.contentHeight > resultGrid.height
                                    ? ScrollBar.AlwaysOn
                                    : ScrollBar.AlwaysOff
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
                                border.width: 0
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
                                onPositionChanged: {
                                    if (root.selectedIndex !== index) {
                                        root._userNavigated = true;
                                        root.selectedIndex = index;
                                    }
                                }
                                onClicked: { root.selectedIndex = index; root.openSelected() }
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
            }
        }

        Rectangle {
            id: previewPopup
            visible: root.previewKind !== ""
            anchors.left: searchHeader.right
            anchors.leftMargin: 16
            anchors.top: searchHeader.top
            width: root.previewKind === "text" ? 420
                 : (root.previewKind === "pdf" || root.previewKind === "image" || root.previewKind === "video") ? root.previewSizeLarge().w
                 : root.previewSize().w
            height: root.previewKind === "text" ? 660
                  : (root.previewKind === "pdf" || root.previewKind === "image" || root.previewKind === "video") ? root.previewSizeLarge().h
                  : root.previewSize().h
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
                anchors.fill: parent
                anchors.margins: 10
                source: root.previewKind === "image" && root.previewPath ? root.fileUrl(root.previewPath) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                sourceSize.width: 1400
                sourceSize.height: 1400
                onStatusChanged: {
                    if (status === Image.Ready) { root.previewNatW = implicitWidth; root.previewNatH = implicitHeight; }
                    else if (status === Image.Error) console.warn("[spotlight] Falha ao carregar imagem:", root.previewPath);
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.previewKind === "image" && previewImg.status === Image.Error
                text: "Não foi possível carregar esta imagem\n(formato não suportado ou arquivo corrompido)"
                horizontalAlignment: Text.AlignHCenter
                color: root.sFgDim
                font { family: "SF Pro Text"; pixelSize: 12 }
            }

            Flickable {
                id: previewTextFlick
                visible: root.previewKind === "text"
                anchors.fill: parent
                anchors.margins: 12
                anchors.rightMargin: 22
                clip: true
                contentWidth: width
                contentHeight: previewTextItem.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: previewTextItem
                    width: previewTextFlick.width
                    text: root.previewText
                    color: root.sFgDim
                    font { family: "JetBrains Mono"; pixelSize: 16 }
                    wrapMode: Text.Wrap
                    lineHeight: 1.35
                    lineHeightMode: Text.ProportionalHeight
                }

                ScrollBar.vertical: ScrollBar {
                    id: previewScrollBar
                    policy: previewTextFlick.contentHeight > previewTextFlick.height
                        ? ScrollBar.AlwaysOn
                        : ScrollBar.AlwaysOff
                    width: 6

                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.35)
                        opacity: previewScrollBar.pressed ? 0.8 : 0.5
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    background: Rectangle {
                        implicitWidth: 6
                        color: "transparent"
                    }
                }
            }

            Image {
                visible: root.previewKind === "pdf"
                anchors.fill: parent
                anchors.margins: 10
                source: root.previewKind === "pdf" && root.previewThumbPath ? root.fileUrl(root.previewThumbPath) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                sourceSize.width: 1400
                sourceSize.height: 1400
                onStatusChanged: {
                    if (status === Image.Ready) { root.previewNatW = implicitWidth; root.previewNatH = implicitHeight; }
                    else if (status === Image.Error) console.warn("[spotlight] Falha ao carregar thumbnail do PDF:", root.previewThumbPath);
                }
            }

            Item {
                visible: root.previewKind === "video"
                anchors.fill: parent
                anchors.margins: 10

                MediaPlayer {
                    id: videoPlayer
                    source: root.previewKind === "video" && root.previewPath
                            ? root.fileUrl(root.previewPath) : ""
                    videoOutput: videoOut
                    audioOutput: AudioOutput { volume: 0.7 }
                    onErrorOccurred: console.log("Video error:", errorString)

                    onMetaDataChanged: {
                        const r = metaData.resolution;
                        if (root.previewKind === "video" && r && r.width > 0 && r.height > 0) {
                            root.previewNatW = r.width;
                            root.previewNatH = r.height;
                        }
                    }
                }

                VideoOutput {
                    id: videoOut
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectFit
                    onSourceRectChanged: {
                        if (root.previewKind === "video" && sourceRect.width > 0 && sourceRect.height > 0) {
                            root.previewNatW = sourceRect.width;
                            root.previewNatH = sourceRect.height;
                        }
                    }
                }

                Image {
                    anchors.fill: parent
                    source: root.previewThumbPath ? root.fileUrl(root.previewThumbPath) : ""
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 1000
                    sourceSize.height: 1000
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
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: videoPlayer.play()
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: videoPlayer.playbackState === MediaPlayer.PlayingState
                    onClicked: videoPlayer.pause()
                }
            }

            Item {
                visible: root.previewKind === "audio"
                anchors.fill: parent
                anchors.margins: 10
                Image {
                    id: audioCoverImgPopup
                    anchors.fill: parent
                    anchors.bottomMargin: 40
                    source: root.previewThumbPath ? root.fileUrl(root.previewThumbPath) : ""
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 800
                    sourceSize.height: 800
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
                    source: root.previewKind === "audio" && root.previewPath
                            ? root.fileUrl(root.previewPath) : ""
                    audioOutput: AudioOutput { volume: 0.8 }
                    onErrorOccurred: console.log("[spotlight] Audio error:", errorString)
                }
            }
        }

        Rectangle {
            id: aiPopup
            visible: root.aiText.length > 0 && root.previewKind === ""
            anchors.left: searchHeader.right
            anchors.leftMargin: 16
            anchors.top: searchHeader.top
            width: 420
            height: 380
            radius: root.panelRadius
            color: root.glassBg
            border.color: root.glassBorder
            border.width: 1
            clip: true
            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent; z: -1 }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "\u2728"; font.pixelSize: 15 }
                    Text {
                        Layout.fillWidth: true
                        text: root.aiLoading ? "Gemini \u00b7 thinking\u2026" : "Gemini"
                        color: root.sFg
                        font { family: "SF Pro Display"; pixelSize: 13; weight: Font.DemiBold }
                        elide: Text.ElideRight
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.divider }

                ScrollView {
                    id: aiScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth

                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ScrollBar.vertical: ScrollBar {
                        width: 6
                        policy: aiScroll.contentHeight > aiScroll.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

                        contentItem: Rectangle {
                            implicitWidth: 6
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.35)
                        }

                        background: Rectangle {
                            implicitWidth: 6
                            color: "transparent"
                        }
                    }

                    Text {
                        width: aiScroll.availableWidth
                        text: root.aiText
                        color: root.sFgDim
                        font { family: "SF Pro Text"; pixelSize: 16 }
                        wrapMode: Text.Wrap
                        lineHeight: 1.35
                        lineHeightMode: Text.ProportionalHeight
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: !root.aiLoading
                    text: "Press ENTER to copy."
                    color: root.headerFg
                    font { family: "SF Pro Text"; pixelSize: 10 }
                }
            }
        }
    }

    Timer { id: _fdDeb; interval: 140; repeat: false; onTriggered: root.runFd() }
    Timer { id: _sideEffectsDeb; interval: 250; repeat: false; onTriggered: root.runSideEffects() }
    Process { id: _mediaCmd; running: false }

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
        id: terminalProcess
        running: false
        property string commandText: ""
        command: [
            root.terminal,
            "--",
            "bash",
            "-lc",
            commandText + "; echo; read -n 1 -s -r -p 'Pressione qualquer tecla para fechar...'"
        ]
    }

    Process {
        id: _fd; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const id = parseInt(lines.shift());
                if (id !== root._fdReq) return;
                root.fileItems = root.parseFdLines(lines);
                root.buildResults();
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
                if (root.mode === "files") root.buildResults();
            }
        }
    }

    Process {
        id: _clip; running: false
        // Decode clipboard entries only to identify image MIME types and cache image bytes locally.
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
                    out.push({ id: id, text: t.length > 120 ? t.slice(0, 120) + "\u2026" : t,
                               isImage: isImage, imagePath: imagePath });
                }
                root.clipItems = out; if (root.mode === "clipboard") root.buildResults();
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
                if (root.mode === "clipboard")
                    root.buildResults();
                console.log("Clipboard history cleared");
            } else {
                console.warn("Failed to clear clipboard history. Exit code:", exitCode);
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
                if (root._shown) root.buildResults();
            }
        }
    }

    Process {
        id: _saveUsage; running: false
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
            stderr: StdioCollector {
                onStreamFinished: { if (text.trim()) console.warn("[spotlight] eds-add-event:", text.trim()); }
            }
            onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) {
                    CalendarEvents.refresh();
                    SpotlightController.run("notify-send 'Spotlight' " + root.shellQuote("Event added: " + title));
                } else {
                    SpotlightController.run("notify-send -u critical 'Spotlight' 'Could not add event (see qs log)'");
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
                        root.currencyText = p.val + " " + p.from + " = " + result + " " + p.to;
                    } else {
                        root.currencyText = "";
                    }
                } catch (e) { root.currencyText = ""; }
                if (root._shown) root.buildResults();
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
                if (root._shown) root.buildResults();
            }
        }
    }

    Process {
        id: _ipInfo; running: false
        command: ["bash", "-c", "echo \"Local: $(hostname -I 2>/dev/null | awk '{print $1}')\"; echo \"Public: $(curl -s --max-time 8 ifconfig.me 2>/dev/null)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ipText = text.trim().replace("\n", "  \u2022  ");
                if (root._shown) root.buildResults();
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
                if (root.mode === "windows") root.buildResults();
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
                if (root.mode === "wifi") root.buildResults();
            }
        }
    }

    Process {
        id: _bt; running: false
        command: ["bash", "-c", "bluetoothctl devices Paired 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(Boolean);
                const out = lines.map(l => {
                    const p = l.trim().split(" ");
                    return { mac: p[1] || "", name: p.slice(2).join(" ") || l };
                });
                root.btItems = out;
                if (root.mode === "bluetooth") root.buildResults();
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
                if (root._shown) root.buildResults();
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
                if (root._shown) root.buildResults();
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
                if (root._shown) root.buildResults();
            }
        }
    }

    Timer {
        id: _statsTimer
        interval: 3000; repeat: true
        running: root._shown && root.showSysStats
        triggeredOnStart: true
        onTriggered: { if (!_stats.running) _stats.running = true; }
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
                if (root._shown && root.query.length === 0 && root.mode === "search") root.buildResults();
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
                if (root._shown) root.buildResults();
            }
        }
    }

    Process {
        id: _preview; running: false
        stdout: StdioCollector {
            onStreamFinished: { root.previewText = text; }
        }
    }

    Process {
    id: _clipPreview; running: false
    stdout: StdioCollector {
        onStreamFinished: {
            if (root._clipPrevKey !== root.selectedKey) return;   // a seleção já mudou
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