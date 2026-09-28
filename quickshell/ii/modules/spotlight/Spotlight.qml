import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtMultimedia
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
    property string terminal: "kitty"          // usado pelo prefixo ">" (sintaxe "-- bash -lc" é do kitty)
    property bool aiAutoQuestion: false        // true = qualquer texto terminado em "?" chama o Gemini
    readonly property string geminiModel: "gemini-3-flash-preview"

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
    property bool hasBody: root.mode !== "search" || root.query.length > 0 || root.items.length > 0 || root.nowPlayingText.length > 0 || root.sysStatsText.length > 0
    property bool slashMode: root.query.startsWith("/")

    property string nowPlayingText: ""
    property string nowPlayingStatus: ""
    property string weatherText: ""
    property string weatherCity: "Itapira"      // cidade usada quando você digita só "clima"
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

    // Contadores de requisição (ignoram respostas de processos antigos)
    property int _fdReq: 0
    property int _rgReq: 0

    // Senha gerada
    property string passText: ""
    property string _passKey: ""
    property int _passWanted: 0

    // ── AI (Gemini) ──
    property string aiText: ""
    property string _lastAiQuery: ""
    property bool aiLoading: false
    property int _aiReq: 0
    property var _aiXhr: null

    // ════════════════════════════════════════════════════════════════
    // HELPERS
    // ════════════════════════════════════════════════════════════════
    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // encodeURIComponent que também escapa ' (seguro dentro de aspas simples)
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

    // Abre URL no navegador: tenta o Qt (não depende de shell/env) e cai no xdg-open/gio
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
        SpotlightController.run(
            "notify-send 'Spotlight Timer' " + root.shellQuote("Timer started (" + label + ")") + "; " +
            "setsid nohup bash -c 'sleep " + n + "; notify-send \"Spotlight Timer\" \"Time is up!\"' " +
            "</dev/null >/dev/null 2>&1 &"
        );
    }

    // Isolado para facilitar portar para outro compositor
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
        root.usageCounts = counts;
        _saveUsage.command = ["bash", "-c", "mkdir -p ~/.cache && cat > ~/.cache/spotlight-usage.json << 'SPTEOF'\n" + JSON.stringify(counts) + "\nSPTEOF"];
        _saveUsage.running = true;
    }

    // "/a/b/c.txt" -> { name: "c.txt", dir: "/a/b" }
    function splitPath(p) {
        const i = p.lastIndexOf("/");
        return { name: i >= 0 ? p.slice(i + 1) : p, dir: i > 0 ? p.slice(0, i) : "~" };
    }

    // Linhas "d\tpath" / "f\tpath" -> [{name, path, dir, isDirectory}]
    function parseFdLines(lines) {
        const out = [];
        for (const line of lines) {
            if (!line) continue;
            const tab = line.indexOf("\t");
            const isDirectory = tab >= 0 && line.slice(0, tab) === "d";
            let p = tab >= 0 ? line.slice(tab + 1) : line;
            p = p.replace(/\/+$/, "");
            if (!p) continue;
            const sp = root.splitPath(p);
            out.push({ name: sp.name, path: p, dir: sp.dir, isDirectory: isDirectory });
        }
        return out;
    }

    // Tamanho pequeno (áudio)
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

    // Tamanho grande (PDF, imagem, vídeo)
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

    readonly property color glassBg: Qt.rgba(24 / 255, 25 / 255, 29 / 255, 0.88)
    readonly property color glassBorder: Qt.rgba(1, 1, 1, 0.20)
    readonly property color glassHighlight: Qt.rgba(1, 1, 1, 0.08)
    readonly property color selectionBg: Qt.rgba(72 / 255, 132 / 255, 235 / 255, 0.35)
    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.09)
    readonly property color divider: Qt.rgba(1, 1, 1, 0.12)
    readonly property color headerFg: Qt.rgba(235 / 255, 237 / 255, 242 / 255, 0.65)
    readonly property color sFg: "#ffffff"
    readonly property color sFgDim: Qt.rgba(245 / 255, 246 / 255, 250 / 255, 0.72)
    readonly property color placeholderFg: Qt.rgba(235 / 255, 237 / 255, 242 / 255, 0.48)
    readonly property color accent: "#0c84ff"

    readonly property real panelWidth: 720
    readonly property real panelRadius: 12
    readonly property real searchH: 68
    readonly property real circleSize: 60
    readonly property real circlesGap: 8
    readonly property real rowH: 48
    readonly property real headerH: 24
    readonly property real iconSize: 24
    readonly property real footerH: 28
    readonly property real stripH: 58
    readonly property real nowPlayingH: 46

    property real panelOpacity: 0.0
    property real panelScale: 0.94
    property real panelYOffset: 15
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
        // 1ª linha da saída = id da requisição (descarta resultados de processos antigos)
        _fd.exec(["bash", "-c",
            "echo " + id + "; " +
            "Q=" + root.shellQuote(q.toLowerCase()) + "; " +
            // matches normais (nome bate) — -F = texto literal, não regex
            "fd -i -F -d 5 -- \"$Q\" ~ 2>/dev/null | head -80 | while IFS= read -r p; do " +
            "  if [ -d \"$p\" ]; then printf 'd\\t%s\\n' \"$p\"; else printf 'f\\t%s\\n' \"$p\"; fi; " +
            "done; " +
            // conteúdo das pastas cujo nome bate
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
        const s = q.trim().toLowerCase().replace(",", ".");
        const m = s.match(/^(-?[\d.]+)\s*(km|mi|miles|milhas?|kg|lb|lbs|libras?|pounds?|m|metros|ft|feet|pes?|c|f|celsius|fahrenheit)\s*(?:in|to|em|para)\s*(km|mi|miles|milhas?|kg|lb|lbs|libras?|pounds?|m|metros|ft|feet|pes?|c|f|celsius|fahrenheit)$/);
        if (!m) return null;
        const val = parseFloat(m[1]);
        if (isNaN(val)) return null;
        const norm = (u) => ({ miles: "mi", mile: "mi", milhas: "mi", milha: "mi", lbs: "lb", pound: "lb", pounds: "lb", libras: "lb", libra: "lb", feet: "ft", foot: "ft", pes: "ft", pe: "ft", celsius: "c", fahrenheit: "f" }[u] || u);
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

    // Clima atual via Open-Meteo (geocoding + current). Sem shell, sem depender de IP.
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
            // aceita "clima campinas", "clima em campinas", "weather in london"...
            const typed = s.replace(/^(clima|weather)\s*/, "").replace(/^(em|in|de|para|no|na|do|da|for)\s+/, "").trim();
            if (/^(em|in|de|para|no|na|do|da|for)$/.test(typed)) return;   // ainda digitando a preposição
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

    function checkCurrency() {
        const s = root.query.trim().toLowerCase().replace(",", ".");
        const m = s.match(/^([\d.]+)\s*(usd|brl|eur|gbp|jpy|btc)\s*(?:in|to|em|para)\s*(usd|brl|eur|gbp|jpy|btc)$/);
        if (!m) { if (root.currencyText) root.currencyText = ""; return; }
        root._pendingCurrency = { val: parseFloat(m[1]), from: m[2].toUpperCase(), to: m[3].toUpperCase() };
        _currency.exec(["bash", "-c", "curl -s --max-time 10 'https://api.exchangerate-api.com/v4/latest/" + m[2].toUpperCase() + "' 2>/dev/null"]);
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

    // Senha gerada com /dev/urandom (não usa Math.random)
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

    // ── AI: Gemini (XMLHttpRequest — a chave não aparece em ps/proc) ──
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

        const req = ++root._aiReq;              // incrementa ANTES de abortar
        if (root._aiXhr) { try { root._aiXhr.abort(); } catch (e) {} }

        const xhr = new XMLHttpRequest();
        root._aiXhr = xhr;

        const finish = (answer) => {
            if (req !== root._aiReq) return;    // resposta de requisição antiga
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

    function checkAI() {
        const s = root.query.trim();
        const m = s.match(/^\/?(ai|gpt|ia)\s+(.+)$/i);
        const isSlashOther = s.startsWith("/") && !/^\/ai\s/i.test(s);
        const isQuestion = root.aiAutoQuestion && !s.startsWith("/") && s.endsWith("?") && s.length > 3;

        let prompt = "";
        if (m && m[2] && (!s.startsWith("/") || m[1].toLowerCase() === "ai")) prompt = m[2].trim();
        else if (isQuestion) prompt = s;

        if (!prompt || isSlashOther) {
            if (root.aiText !== "") {
                root._aiReq++;                  // invalida requisição em andamento
                if (root._aiXhr) { try { root._aiXhr.abort(); } catch (e) {} root._aiXhr = null; }
                root.aiText = "";
                root.aiLoading = false;
                root._lastAiQuery = "";
            }
            return;
        }
        root.runGemini(prompt);
    }

    function checkContentSearch() {
        const m = root.query.trim().match(/^\/buscar\s+(.+)$/i);
        if (m && m[1].trim()) root.runContentSearch(m[1].trim());
    }

    // ── Side effects unificados (debounce) ──
    function runSideEffects() {
        root.checkWeather();
        root.checkDefine();
        root.checkCurrency();
        root.checkBattery();
        root.checkMyIp();
        root.checkPassword();
        root.checkAI();
        root.checkContentSearch();
    }

    // ════════════════════════════════════════════════════════════════
    // PREVIEW
    // ════════════════════════════════════════════════════════════════
    function updatePreview() {
        // só recarrega se o item selecionado realmente mudou
        const key = root.selectedKey;
        if (key === root._previewKeyShown) return;
        root._previewKeyShown = key;

        audioPlayer.stop();

        root.previewThumbPath = "";
        root.previewNatW = 0;
        root.previewNatH = 0;

        const it = root.selectedItem;
        if (!it || it.kind !== "file") {
            root.previewPath = "";
            root.previewKind = "";
            root.previewText = "";
            return;
        }

        const p = it.path;
        const ext = p.split(".").pop().toLowerCase();
        const imgExts = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"];
        const textExts = ["txt", "md", "json", "qml", "js", "ts", "py", "sh", "conf", "yaml", "yml", "xml", "html", "css", "c", "cpp", "h", "lua", "toml", "ini", "log"];
        const videoExts = ["mp4", "mkv", "webm", "avi", "mov", "m4v", "flv"];
        const audioExts = ["mp3", "flac", "wav", "ogg", "opus", "m4a", "aac"];
        const pdfExts = ["pdf"];

        if (it.isDirectory) {
            root.previewKind = "";
            root.previewPath = "";
            root.previewText = "";
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
        } else if (pdfExts.indexOf(ext) !== -1) {
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
            root.previewKind = "";
            root.previewPath = "";
            root.previewText = "";
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
        if (root.sysStatsText.length > 0 && root.query.length === 0 && root.mode === "search") h += 24;
        for (const r of root.results) h += r.isHeader ? root.headerH : root.rowH;
        if (root.items.length === 0 && root.query.length > 0) h += 56;
        if (root.selectedItem !== null && root.mode !== "apps") h += root.stripH + 1;
        return Math.min(maxH, Math.max(48, h + root.footerH + 12));
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
        if (title) disp.push({ isHeader: true, title: title });   // só vai pra disp, NÃO pra items
        for (const it of arr) {
            it._idx = items.length;       // índice em items (seleção)
            it._dispIdx = disp.length;    // índice em disp/results (posição na ListView)
            items.push(it);
            disp.push(it);
        }
    }

    function sortFileResults(arr, q) {
        const ql = q.trim().toLowerCase();

        // 1) Acha a "pasta-alvo": pasta cujo nome bate exatamente com a query,
        //    ou (fallback) começa com a query.
        let targetDir = null;
        for (const f of arr) {
            if (!f.isDirectory) continue;
            const n = f.name.toLowerCase();
            if (n === ql) { targetDir = f; break; }
            if (!targetDir && n.startsWith(ql)) targetDir = f;
        }

        // 2) Sem pasta-alvo: alfabético, pastas primeiro.
        if (!targetDir) {
            return arr.slice().sort((a, b) => {
                const da = a.isDirectory ? 1 : 0;
                const db = b.isDirectory ? 1 : 0;
                if (da !== db) return db - da;
                return a.name.localeCompare(b.name, undefined, { sensitivity: "base", numeric: true });
            });
        }

        // 3) Com pasta-alvo: agrupa.
        const targetPath = targetDir.path;
        const prefix = targetPath + "/";

        const groupOf = (f) => {
            if (f === targetDir) return 0;              // a pasta em si
            if (f.path.startsWith(prefix)) return 1;    // conteúdo dela
            return 2;                                    // resto
        };

        return arr.slice().sort((a, b) => {
            const ga = groupOf(a), gb = groupOf(b);
            if (ga !== gb) return ga - gb;
            if (ga === 2) {
                const da = a.isDirectory ? 1 : 0;
                const db = b.isDirectory ? 1 : 0;
                if (da !== db) return db - da;
            }
            return a.name.localeCompare(b.name, undefined, { sensitivity: "base", numeric: true });
        });
    }

    // ════════════════════════════════════════════════════════════════
    // CONSTRUÇÃO DOS RESULTADOS (funções puras: não disparam processos)
    // ════════════════════════════════════════════════════════════════
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
            // a busca em si roda em checkContentSearch() (com debounce)
            _addItems(items, disp, root.contentResults.map(f => ({ kind: "file", name: f.name, path: f.path, category: f.dir })), "CONTENT: " + cmdArgs);
            return true;
        }
        if (cmdName === "ai" && cmdArgs.length > 0) {
            // a consulta em si roda em checkAI() (com debounce)
            if (root.aiText) {
                _addItems(items, disp, [{ kind: "info", name: root.aiLoading ? "Thinking…" : "Ver resposta no popup ao lado", category: root.aiLoading ? "Gemini · thinking…" : "Gemini — Enter to copy" }], "AI");
            }
            return true;
        }

        const allCmds = [
            { kind: "cmd", name: "/apps",      category: "Switch to Applications", action: "mode:apps" },
            { kind: "cmd", name: "/files",     category: "Switch to Files",        action: "mode:files" },
            { kind: "cmd", name: "/clipboard", category: "Switch to Clipboard",    action: "mode:clipboard" },
            { kind: "cmd", name: "/actions",   category: "Switch to Actions",      action: "mode:actions" },
            { kind: "cmd", name: "/emoji",     category: "Open emoji picker",      action: "emoji:" },
            { kind: "cmd", name: "/wallpaper", category: "Change wallpaper (ii)",  action: "ipc:wallpaperSelector:toggle" },
            { kind: "cmd", name: "/tema",      category: "Toggle light/dark theme (ii)", action: "ipc:theme:toggleLightDark" },
            { kind: "cmd", name: "/barra",     category: "Show/hide bar (ii)",     action: "ipc:bar:toggle" },
            { kind: "cmd", name: "/screenshot", category: "Take screenshot (ii)",  action: "ipc:region:screenshot" },
            { kind: "cmd", name: "/record",    category: "Record screen (ii)",     action: "ipc:region:record" },
            { kind: "cmd", name: "/ocr",       category: "Screen OCR (ii)",        action: "ipc:region:ocr" },
            { kind: "cmd", name: "/cor",       category: "Color picker (copies hex)", action: "colorpick:" },
            { kind: "cmd", name: "/janelas",   category: "Switch between open windows", action: "mode:windows" },
            { kind: "cmd", name: "/wifi",      category: "Wi-Fi networks",         action: "mode:wifi" },
            { kind: "cmd", name: "/bluetooth", category: "Paired Bluetooth devices", action: "mode:bluetooth" },
            { kind: "cmd", name: "/buscar",    category: "Search inside files (ripgrep)", action: "buscar:" },
            { kind: "cmd", name: "/ai",        category: "Ask Gemini",             action: "ai:" },
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
        _addItems(items, disp, filtered, "COMMANDS");
        return true;
    }

    function _buildAppsMode(items, disp, q, ql) {
        const list = (ql ? SpotlightApps.search(q) : SpotlightApps.apps).slice();
        list.sort((a, b) => (root.usageCounts["app:" + b.exec] || 0) - (root.usageCounts["app:" + a.exec] || 0));
        _addItems(items, disp, list.slice(0, 60).map(a => ({ kind: "app", name: a.name, icon: a.icon, exec: a.exec, category: a.category || "Application" })), ql ? "APPLICATIONS" : "");
    }

    function _buildFilesMode(items, disp, ql) {
        // sem query: recentes. Com query: resultado do fd (ou recentes filtrados até o fd responder)
        let src;
        if (!ql) src = root.recentItems.slice();
        else if (root.fileItems.length) src = root.fileItems;
        else src = root.recentItems.filter(f => f.name.toLowerCase().indexOf(ql) !== -1);
        const fitems = ql ? root.sortFileResults(src, ql) : src;
        _addItems(items, disp,
            fitems.map(f => ({
                kind: "file", name: f.name, path: f.path,
                dir: f.dir, category: f.dir, isDirectory: f.isDirectory
            })),
            ql ? "FILES" : "RECENT FILES");
    }

    function _buildClipboardMode(items, disp) {
        _addItems(items, disp, root.clipItems.map(c => ({ kind: "clip", name: c.text, id: c.id, category: "Clipboard" })), "CLIPBOARD");
        _addItems(items, disp, [{ kind: "action", name: "Clear clipboard history", action: "clipboard:clear", iconKey: "delete", category: "Clipboard" }], "");
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

    // Retorna a URL completa se o texto parecer um endereço web (gov.br, youtube.com/x...), senão ""
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

        const noteMatch = q.match(/^(nota|note)\s+(.+)$/i);
        if (noteMatch) {
            _addItems(items, disp, [{ kind: "action", name: "Save note: \u201c" + noteMatch[2] + "\u201d", action: "savenote:" + noteMatch[2], iconKey: "note", category: "Notes" }], "NOTE");
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
            // número solto ("2026") não vira resultado de calculadora
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

        // guarda a seleção atual para restaurar se só os resultados mudaram
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
        if (sig === root._buildSig && prevKey) {
            const f = items.findIndex(i => root.itemKey(i) === prevKey);
            if (f >= 0) idx = f;
        }
        root._buildSig = sig;
        root.selectedIndex = idx;
    }

    function setMode(m) {
        root.mode = m;
        root.selectedIndex = 0;
        if (m === "files" && root.recentItems.length === 0) runRecents();
        if (m === "clipboard") runClip();
        if (m === "windows") _windows.running = true;
        if (m === "wifi") _wifi.running = true;
        if (m === "bluetooth") _bt.running = true;
        root.buildResults();
    }

    function runRecents() {
        _recents.running = true;
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
        root.selectedIndex = (root.selectedIndex + delta + root.items.length) % root.items.length;
        const it = root.items[root.selectedIndex];
        // ListView usa `results` (com headers) -> posiciona pelo índice de exibição
        if (resultList.visible) {
            resultList.positionViewAtIndex(it._dispIdx, ListView.Contain);
        } else if (resultGrid.visible) {
            resultGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
        }
    }

    function openSelected() {
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
        else if (e.kind === "file") { root.xdgOpen(e.path); }
        else if (e.kind === "clip") {
            if (/^\d+$/.test(e.id || "")) SpotlightController.run("cliphist decode " + e.id + " | wl-copy 2>/dev/null || true");
        }
        else if (e.kind === "calc") root.copyText(e.raw);
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
            if (e.action.startsWith("open:")) {
                root.openUrl(e.action.slice(5));
            }
            else if (e.action.startsWith("web:")) {
                root.openUrl("https://www.google.com/search?q=" + encodeURIComponent(e.action.slice(4)));
            }
            else if (e.action.startsWith("filesearch:")) {
                // abre o modo Files mantendo a query (fd já roda pela busca normal)
                root.circlesLocked = true;
                root.setMode("files");
                root.runFd();
                keepOpen = true;
            }
            else if (e.action.startsWith("spotifyplay:")) {
                const term = e.action.slice(12);
                // pgrep -x: casa só o nome do processo (com -f casava o próprio bash -c e nunca abria o Spotify)
                SpotlightController.run(
                    "pgrep -x spotify >/dev/null || (setsid flatpak run com.spotify.Client </dev/null >/dev/null 2>&1 &); " +
                    "sleep 1.2; " + root.xdgOpenCmd("spotify:search:" + root.urlq(term)) + "; " +
                    "sleep 1.8; wtype -k Return 2>/dev/null || true"
                );
            }
            else if (e.action.startsWith("savenote:")) {
                const noteText = e.action.slice(9);
                SpotlightController.run(
                    "mkdir -p ~/Documents && " +
                    "printf '- %s %s\\n' \"$(date '+%Y-%m-%d %H:%M')\" " + root.shellQuote(noteText) +
                    " >> ~/Documents/spotlight-notes.md && notify-send 'Spotlight' 'Note saved'"
                );
            }
            else if (e.action.startsWith("realtimer:")) {
                const parts = e.action.slice(10).split(":");
                root.startTimer(parts[0], parts[1] || (parts[0] + "s"));
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
                root._buildSig = "";
                root._previewKeyShown = "";
                root.previewKind = "";
                root.previewPath = "";
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
        ignoreUnknownSignals: true
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
            videoPlayer.stop();
            audioPlayer.stop();
        } }
    }

    // Clique no fundo (fora do painel) fecha o Spotlight
    MouseArea {
        anchors.fill: parent
        onClicked: SpotlightController.spotlightOpen = false
    }

    Item {
        id: outerWrap
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(root.screen.height * 0.24) + root.panelYOffset
        width: root.panelWidth
        height: root.searchH + (root.hasBody ? root.computeResultsHeight() + 10 : 0)
        transformOrigin: Item.Top
        scale: root.panelScale
        opacity: root.panelOpacity

        Item {
            id: searchHeader
            anchors.left: parent.left
            anchors.top: parent.top
            width: parent.width
            height: root.searchH
            z: 2

            // absorve cliques no painel (não fecha)
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
                surfaceColor: root.glassBg
                shadowColor: Qt.rgba(0, 0, 0, 0.45)
                z: -1

                Rectangle {
                    anchors.fill: parent
                    radius: root.panelRadius
                    color: root.glassBg
                    border.color: root.glassBorder
                    border.width: 1
                    z: -2
                }
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
                        anchors.right: parent.right; anchors.rightMargin: 28   // espaço para o botão limpar
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        color: root.sFg
                        font { family: "SF Pro Display"; pixelSize: 22; weight: Font.Normal }
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true; clip: true; cursorVisible: root._opened
                        focus: true
                        onActiveFocusChanged: { if (activeFocus) root.circlesLocked = false }
                        Keys.onUpPressed: (event) => { root.moveSelection(-1); event.accepted = true }
                        Keys.onDownPressed: (event) => { root.moveSelection(1); event.accepted = true }
                        Keys.onReturnPressed: (event) => { root.openSelected(); event.accepted = true }
                        Keys.onEnterPressed: (event) => { root.openSelected(); event.accepted = true }
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
                            root.query = text;
                            // se o usuário está digitando livremente, garante modo search
                            // (a menos que ele tenha clicado num círculo)
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
                        font { family: "SF Pro Display"; pixelSize: 22; weight: Font.Normal }
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

            // Botão "limpar": fica ACIMA do dragZone (z 100) para receber o clique
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
            z: 1

            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            // absorve cliques no painel (não fecha)
            MouseArea { anchors.fill: parent }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: root.panelRadius - 1
                color: "transparent"
                border.color: root.glassHighlight
                border.width: 1
            }

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
                        anchors.bottomMargin: 4
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        model: root.results
                        spacing: 2
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
                                radius: 10
                                color: {
                                    if (root.selectedIndex === modelData._idx) return root.selectionBg;
                                    if (rowHover.containsMouse) return root.hoverBg;
                                    return "transparent";
                                }
                                border.color: root.selectedIndex === modelData._idx ? Qt.rgba(190 / 255, 210 / 255, 1, 0.22) : "transparent"
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
                                border.color: root.selectedIndex === index ? Qt.rgba(1, 1, 1, 0.4) : "transparent"
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
                                onEntered: root.selectedIndex = index
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
                        color: openBtnMA.containsMouse ? Qt.darker(root.accent, 1.2) : root.accent
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
                            Rectangle { width: 18; height: 16; radius: 4; color: Qt.rgba(1,1,1,0.15); border.color: Qt.rgba(1,1,1,0.25); border.width: 1
                                Text { anchors.centerIn: parent; text: "\u2191"; font { family: "SF Pro Text"; pixelSize: 10; weight: Font.Medium } color: root.sFgDim } }
                            Rectangle { width: 18; height: 16; radius: 4; color: Qt.rgba(1,1,1,0.15); border.color: Qt.rgba(1,1,1,0.25); border.width: 1
                                Text { anchors.centerIn: parent; text: "\u2193"; font { family: "SF Pro Text"; pixelSize: 10; weight: Font.Medium } color: root.sFgDim } }
                            Text { text: "Navigate"; font { family: "SF Pro Text"; pixelSize: 10; weight: Font.Normal } color: root.sFgDim; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Row { spacing: 4
                            Rectangle { width: 22; height: 16; radius: 4; color: Qt.rgba(1,1,1,0.15); border.color: Qt.rgba(1,1,1,0.25); border.width: 1
                                Text { anchors.centerIn: parent; text: "\u21a9"; font { family: "SF Pro Text"; pixelSize: 10; weight: Font.Medium } color: root.sFgDim } }
                            Text { text: "Open"; font { family: "SF Pro Text"; pixelSize: 10; weight: Font.Normal } color: root.sFgDim; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Row { spacing: 4
                            Rectangle { width: 30; height: 16; radius: 4; color: Qt.rgba(1,1,1,0.15); border.color: Qt.rgba(1,1,1,0.25); border.width: 1
                                Text { anchors.centerIn: parent; text: "esc"; font { family: "SF Pro Text"; pixelSize: 10; weight: Font.Medium } color: root.sFgDim } }
                            Text { text: "Close"; font { family: "SF Pro Text"; pixelSize: 10; weight: Font.Normal } color: root.sFgDim; anchors.verticalCenter: parent.verticalCenter }
                        }
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
                visible: root.previewKind === "image"
                anchors.fill: parent
                anchors.margins: 10
                source: root.previewKind === "image" && root.previewPath ? "file://" + root.previewPath : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                onStatusChanged: if (status === Image.Ready) { root.previewNatW = implicitWidth; root.previewNatH = implicitHeight; }
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
                source: root.previewKind === "pdf" && root.previewThumbPath ? "file://" + root.previewThumbPath : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                onStatusChanged: if (status === Image.Ready) { root.previewNatW = implicitWidth; root.previewNatH = implicitHeight; }
            }

            // Vídeo: só o MediaPlayer do QML (o mpv externo foi removido)
            Item {
                visible: root.previewKind === "video"
                anchors.fill: parent
                anchors.margins: 10

                MediaPlayer {
                    id: videoPlayer
                    source: root.previewKind === "video" && root.previewPath
                            ? "file://" + root.previewPath : ""
                    videoOutput: videoOut
                    audioOutput: AudioOutput { volume: 0.7 }
                    onErrorOccurred: console.log("Video error:", errorString)

                    // Qt 6: a resolução vem em metaData.resolution (QSize)
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
                    source: root.previewThumbPath ? "file://" + root.previewThumbPath : ""
                    fillMode: Image.PreserveAspectFit
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
                            ? "file://" + root.previewPath : ""
                    audioOutput: AudioOutput { volume: 0.8 }
                    onErrorOccurred: console.log("[spotlight] Audio error:", errorString)
                }
            }
        }

        // ── Popup de resposta da IA (Gemini) ──
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
                        text: root.aiLoading ? "Gemini \u00b7 pensando\u2026" : "Gemini"
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
                    text: "Enter para copiar a resposta"
                    color: root.headerFg
                    font { family: "SF Pro Text"; pixelSize: 10 }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════
    // TIMERS
    // ════════════════════════════════════════════════════════════════
    Timer { id: _fdDeb; interval: 140; repeat: false; onTriggered: root.runFd() }

    Timer { id: _sideEffectsDeb; interval: 250; repeat: false; onTriggered: root.runSideEffects() }

    Process { id: _mediaCmd; running: false }

    Timer {
        id: _mprisTimer
        interval: 2000; running: root._shown; repeat: true
        triggeredOnStart: true
        onTriggered: _mprisPoll.running = true
    }

    // ════════════════════════════════════════════════════════════════
    // PROCESSES
    // (os que dependem da query usam .exec(), que reinicia o processo
    //  se ele ainda estiver rodando)
    // ════════════════════════════════════════════════════════════════
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
                if (id !== root._fdReq) return;       // resposta de uma busca antiga
                root.fileItems = root.parseFdLines(lines);
                root.buildResults();
            }
        }
    }

    Process {
        id: _recents; running: false
        command: ["bash", "-c", "fd -H --changed-within 60d -E .git -d 6 ~ 2>/dev/null | head -40 | while IFS= read -r p; do if [ -d \"$p\" ]; then printf 'd\\t%s\\n' \"$p\"; else printf 'f\\t%s\\n' \"$p\"; fi; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.recentItems = root.parseFdLines(text.split("\n").slice(0, 40));
                if (root.mode === "files") root.buildResults();
            }
        }
    }

    Process {
        id: _clip; running: false
        // cliphist lista do mais recente para o mais antigo -> head
        command: ["bash", "-c", "cliphist list 2>/dev/null | head -n 30"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const l of text.split("\n")) {
                    if (!l.trim()) continue;
                    const tab = l.indexOf("\t");
                    const id = tab >= 0 ? l.slice(0, tab).trim() : "";
                    const t = (tab >= 0 ? l.slice(tab + 1) : l).trim();
                    if (!t) continue;
                    out.push({ id: id, text: t.length > 120 ? t.slice(0, 120) + "\u2026" : t });
                }
                root.clipItems = out; if (root.mode === "clipboard") root.buildResults();
            }
        }
    }

    Process {
        id: _clipClear
        running: false
        command: ["bash", "-c", "cliphist wipe"]

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

    Process { id: _saveUsage; running: false }
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
        id: _currency; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const p = root._pendingCurrency;
                    if (p && data.rates && data.rates[p.to] !== undefined) {
                        const result = (p.val * data.rates[p.to]).toFixed(2);
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
                if (id !== root._rgReq) return;       // resposta de uma busca antiga
                root.contentResults = lines.filter(Boolean).map(p => {
                    const sp = root.splitPath(p);
                    return { name: sp.name, path: p, dir: sp.dir };
                });
                if (root._shown) root.buildResults();
            }
        }
    }

    Process {
        id: _pass; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t.length !== root._passWanted) return;   // resposta de uma geração antiga
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