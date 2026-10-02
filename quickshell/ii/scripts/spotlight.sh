#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# spotlight.sh — Gera os arquivos do Spotlight no diretório correto
#
# Uso:
#   bash ~/.config/quickshell/ii/scripts/spotlight.sh
#
# Gera:
#   ~/.config/quickshell/ii/modules/spotlight/SiriOrb.qml
#   ~/.config/quickshell/ii/modules/spotlight/SpotlightActions.qml
#   ~/.config/quickshell/ii/modules/spotlight/.spotlight-patches.md
# ═══════════════════════════════════════════════════════════════════════
set -euo pipefail

# Caminhos relativos ao próprio script (mais portável)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST="$QS_ROOT/modules/spotlight"

mkdir -p "$DEST"

echo "📂 Destino: $DEST"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# 1) SiriOrb.qml
# ═══════════════════════════════════════════════════════════════════════
cat > "$DEST/SiriOrb.qml" << 'SIRIORB_EOF'
import QtQuick

Item {
    id: orb
    property real size: 26
    property color accentColor: "#5E5CE6"
    property bool active: false
    property bool showRing: true
    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.centerIn: parent
        width: orb.size * 0.9; height: orb.size * 0.9
        radius: width / 2
        color: "transparent"
        border.width: Math.max(1, orb.size * 0.077)
        border.color: orb.active ? Qt.rgba(0.6, 0.3, 1.0, 0.7) : Qt.rgba(0.5, 0.3, 0.9, 0.25)
        SequentialAnimation on scale {
            running: orb.active; loops: Animation.Infinite
            NumberAnimation { to: 1.15; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.90; duration: 800; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on opacity {
            running: orb.active; loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.00; duration: 800; easing.type: Easing.InOutSine }
        }
        Behavior on border.color { ColorAnimation { duration: 300 } }
    }

    Rectangle {
        id: core
        anchors.centerIn: parent
        width: orb.size * 0.72; height: orb.size * 0.72
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00B4FF" }
            GradientStop { position: 0.5; color: "#5E5CE6" }
            GradientStop { position: 1.0; color: "#BF5AF2" }
        }
        RotationAnimation on rotation {
            running: orb.active; loops: Animation.Infinite
            from: 0; to: 360; duration: 3000
        }
        SequentialAnimation on scale {
            running: true; loops: Animation.Infinite
            NumberAnimation { to: orb.active ? 1.12 : 1.03; duration: orb.active ? 600 : 1600; easing.type: Easing.InOutSine }
            NumberAnimation { to: orb.active ? 0.94 : 0.98; duration: orb.active ? 600 : 1600; easing.type: Easing.InOutSine }
        }
        opacity: orb.active ? 1.0 : 0.7
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    Rectangle {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -orb.size * 0.115
        width: core.width * 0.5; height: core.height * 0.35
        radius: width / 2
        color: Qt.rgba(1, 1, 1, 0.35)
        opacity: orb.active ? 0.6 : 0.3
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    Rectangle {
        anchors.centerIn: parent
        width: orb.size; height: orb.size
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(0.8, 0.5, 1.0, 0.6)
        visible: orb.active && orb.showRing
        opacity: orb.active ? 1.0 : 0.0
        RotationAnimation on rotation {
            running: orb.active; loops: Animation.Infinite
            from: 0; to: 360; duration: 1500
        }
    }
}
SIRIORB_EOF

echo "✅ SiriOrb.qml"

# ═══════════════════════════════════════════════════════════════════════
# 2) SpotlightActions.qml
# ═══════════════════════════════════════════════════════════════════════
cat > "$DEST/SpotlightActions.qml" << 'ACTIONS_EOF'
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var aliases: ({})
    property string historyPath: Quickshell.env("HOME") + "/.cache/spotlight-ai-history.json"

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // #1 Obsidian
    function addObsidianNote(title, content) {
        const t = String(title || "Nota").replace(/[^\w\sáéíóúâêôãõç-]/gi, "").slice(0, 80);
        const c = String(content || "").replace(/"/g, '\\"').replace(/\n/g, "\\n");
        const url = "obsidian://new?name=" + encodeURIComponent(t)
                  + "&content=" + encodeURIComponent(c) + "&silent=true";
        const cmd = "setsid nohup env XDG_RUNTIME_DIR=/run/user/$(id -u) "
                  + "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus "
                  + "xdg-open " + shellQuote(url) + " </dev/null >/dev/null 2>&1 &";
        SpotlightController.run(cmd);
        return "📝 Nota criada: " + t;
    }

    // #2 Email
    function sendEmail(to, subject, body) {
        const cmd = "setsid nohup env XDG_RUNTIME_DIR=/run/user/$(id -u) "
                  + "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus "
                  + "xdg-email --to " + shellQuote(to)
                  + " --subject " + shellQuote(subject || "(sem assunto)")
                  + " --body " + shellQuote(body || "")
                  + " </dev/null >/dev/null 2>&1 &";
        SpotlightController.run(cmd);
        return "📧 Email aberto para: " + to;
    }

    // #6 Bloquear sites
    function blockSites(sites, minutes) {
        const list = Array.isArray(sites) ? sites : [sites];
        const clean = list.map(s => String(s).replace(/^https?:\/\//, "").replace(/\/.*$/, "").trim()).filter(Boolean);
        if (!clean.length) return "❌ Nenhum site válido";
        const tag = "# spotlight-block-" + Date.now();
        const lines = clean.map(s => "0.0.0.0 " + s + " " + tag).join("\n");
        const unlock = "grep -v '" + tag + "' /etc/hosts | sudo tee /etc/hosts >/dev/null";
        const cmd = "echo " + shellQuote(lines + "\n") + " | sudo tee -a /etc/hosts >/dev/null "
                  + "&& systemd-run --user --quiet --collect --on-active=" + (minutes * 60) + "s "
                  + "bash -c " + shellQuote(unlock);
        SpotlightController.run(cmd);
        return "🚫 Bloqueado: " + clean.join(", ") + " por " + minutes + " min";
    }

    // #10 Git
    function runGitCommit() { _gitProc.running = true; }
    Process {
        id: _gitProc
        running: false
        command: ["bash", "-c", "cd \"$PWD\" 2>/dev/null; git diff --cached --stat 2>/dev/null | head -40 || git diff --stat 2>/dev/null | head -40"]
        stdout: StdioCollector { onStreamFinished: root.gitDiffReady(text.trim()) }
    }
    signal gitDiffReady(string diff)

    // #11 Aliases
    function createAlias(name, actions) {
        const a = Object.assign({}, root.aliases);
        a[name] = actions;
        root.aliases = a;
        const json = JSON.stringify(a, null, 2);
        SpotlightController.run(
            "mkdir -p ~/.config/spotlight && printf '%s' " + shellQuote(json)
            + " > ~/.config/spotlight/aliases.json"
        );
        return "🔗 Alias criado: " + name;
    }

    // #12 Screenshot + OCR
    function runScreenshotOcr(selectArea) {
        _ocrProc.selectArea = !!selectArea;
        _ocrProc.running = true;
    }
    Process {
        id: _ocrProc
        running: false
        property bool selectArea: false
        command: ["bash", "-c", selectArea
            ? `f="/tmp/spotlight-ocr-$(date +%s).png"; grim -g "$(slurp)" "$f" 2>/dev/null && tesseract "$f" stdout -l por+eng+jpn 2>/dev/null; rm -f "$f"`
            : `f="/tmp/spotlight-ocr-$(date +%s).png"; grim "$f" 2>/dev/null && tesseract "$f" stdout -l por+eng+jpn 2>/dev/null; rm -f "$f"`]
        stdout: StdioCollector { onStreamFinished: root.screenshotOcrReady(text.trim()) }
    }
    signal screenshotOcrReady(string ocrText)

    // #16 Web scraping
    function scrapeUrl(url) { _scrapeProc.url = url; _scrapeProc.running = true; }
    Process {
        id: _scrapeProc
        running: false
        property string url: ""
        command: ["bash", "-c",
            "curl -sL --max-time 15 -A 'Mozilla/5.0' " + shellQuote(url)
            + " 2>/dev/null | python3 -c 'import sys,re; t=sys.stdin.read(); t=re.sub(r\"<script[^>]*>.*?</script>\",\" \",t,flags=re.S); t=re.sub(r\"<style[^>]*>.*?</style>\",\" \",t,flags=re.S); t=re.sub(r\"<[^>]+>\",\" \",t); print(re.sub(r\"\\s+\",\" \",t)[:5000])'"]
        stdout: StdioCollector { onStreamFinished: root.scrapeReady(text.trim()) }
    }
    signal scrapeReady(string text)

    // #18 Memória persistente
    function saveHistory(historyJson) {
        _saveHist.command = ["bash", "-c",
            "mkdir -p ~/.cache && printf '%s' " + shellQuote(historyJson)
            + " > ~/.cache/spotlight-ai-history.json"];
        _saveHist.running = true;
    }
    Process { id: _saveHist; running: false }

    function loadHistory() { _loadHist.running = true; }
    Process {
        id: _loadHist
        running: false
        command: ["bash", "-c", "cat ~/.cache/spotlight-ai-history.json 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.historyReady(JSON.parse(text.trim() || "[]")); }
                catch (e) { root.historyReady([]); }
            }
        }
    }
    signal historyReady(var history)

    // #21 Modo foco
    function enterFocusMode(minutes) {
        const mins = Math.max(1, parseInt(minutes) || 120);
        const sites = ["twitter.com", "x.com", "reddit.com", "youtube.com",
                       "instagram.com", "tiktok.com", "facebook.com"];
        root.blockSites(sites, mins);
        const dnd = "if command -v makoctl >/dev/null; then makoctl mode -s dnd; "
                  + "elif command -v swaync-client >/dev/null; then swaync-client -d -sw; "
                  + "elif command -v dunstctl >/dev/null; then dunstctl set-paused true; fi";
        SpotlightController.run(dnd);
        return "🎯 Modo foco: " + mins + " min · DND · sites bloqueados";
    }

    // #22 Modo reunião
    function enterMeetingMode() {
        const dnd = "if command -v makoctl >/dev/null; then makoctl mode -s dnd; "
                  + "elif command -v swaync-client >/dev/null; then swaync-client -d -sw; "
                  + "elif command -v dunstctl >/dev/null; then dunstctl set-paused true; fi";
        SpotlightController.run(dnd);
        return "🎤 Modo reunião · notificações silenciadas";
    }

    // #23 Briefing
    function runBriefing() { _briefingProc.running = true; }
    Process {
        id: _briefingProc
        running: false
        command: ["bash", "-c", `
            echo "## Clima"
            curl -s --max-time 5 "https://wttr.in/Itapira?format=%c+%t+(sensação+%f)+·+umidade+%h" 2>/dev/null || echo "indisponível"
            echo ""
            echo "## Hoje"
            date "+%A, %d de %B de %Y — %H:%M"
            echo ""
            echo "## Tocando"
            playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null || echo "nada"
        `]
        stdout: StdioCollector { onStreamFinished: root.briefingReady(text.trim()) }
    }
    signal briefingReady(string text)

    // #7 PDF
    function summarizePdf(path) { _pdfProc.path = path; _pdfProc.running = true; }
    Process {
        id: _pdfProc
        running: false
        property string path: ""
        command: ["bash", "-c", "pdftotext -l 20 " + shellQuote(path) + " - 2>/dev/null | head -c 8000"]
        stdout: StdioCollector { onStreamFinished: root.pdfReady(text.trim()) }
    }
    signal pdfReady(string text)

    // Carrega aliases ao iniciar
    Process {
        id: _loadAliases
        running: true
        command: ["bash", "-c", "cat ~/.config/spotlight/aliases.json 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.aliases = JSON.parse(text.trim() || "{}"); }
                catch (e) { root.aliases = {}; }
            }
        }
    }
}
ACTIONS_EOF

echo "✅ SpotlightActions.qml"

# ═══════════════════════════════════════════════════════════════════════
# 3) Guia de patches
# ═══════════════════════════════════════════════════════════════════════
cat > "$DEST/.spotlight-patches.md" << 'PATCHES_EOF'
# Patches para aplicar no Spotlight.qml

Aplique estes patches no seu Spotlight.qml atual.

## 1. Nova property (perto de aiConversationMode)

    property bool aiPersistentHistory: false

## 2. Novas funções de intenção (após isGitIntent)

function isScreenshotIntent(p) {
    const s = String(p).toLowerCase();
    return /(o\s+que|analise?|analisa|veja?|olhe?|leia?|traduza?|explica?|explique)\s+(est[áa]|ness[ae]|na|essa?)\s+(tela|screenshot|captura|imagem)/i.test(s)
        || /(o\s+que\s+est[áa]\s+na\s+tela)/i.test(s);
}

function isWebSummaryIntent(p) {
    const s = String(p).toLowerCase();
    return /(resuma?|resumir|analise?|analisa|o\s+que\s+diz)\s+(esse\s+)?(link|url|site)/i.test(s)
        || /https?:\/\/\S+/i.test(s) && /(resuma?|analise?|o\s+que)/i.test(s);
}

function isPdfSummaryIntent(p) {
    const s = String(p).toLowerCase();
    return /(resuma?|resumir|analise?|analisa)\s+(o\s+|esse\s+|esta\s+)?(pdf|documento)/i.test(s);
}

## 3. structuredIntent — adicione estas linhas no final

    if (root.isScreenshotIntent(p))  return "screenshot";
    if (root.isWebSummaryIntent(p))  return "web";
    if (root.isPdfSummaryIntent(p))  return "pdf";

## 4. buildSystemPrompt — adicione ao objeto `extra`

    screenshot: `
O usuário quer analisar a tela. Responda APENAS com:
{"action":"screenshot","selectArea":false}`,

    web: `
O usuário quer resumir um link. Extraia a URL da mensagem e responda APENAS com:
{"action":"web_summary","url":"<url>"}`,

    pdf: `
O usuário quer resumir um PDF. Identifique o arquivo e responda APENAS com:
{"action":"pdf_summary","path":"<caminho completo>"}`

## 5. finish() dentro de runHermes — adicione ANTES do if que detecta JSON

    if (cleaned.startsWith("{") && cleaned.endsWith("}")) {
        try {
            const obj = JSON.parse(cleaned);
            if (obj.action === "screenshot") {
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
        } catch (e) { }
    }

## 6. Connections adicionais

Connections {
    target: SpotlightActions
    function onScreenshotOcrReady(ocrText) {
        if (!ocrText) {
            root.aiText = "❌ OCR não retornou texto";
            root.aiLoading = false;
            if (root._shown) root.scheduleRebuild();
            return;
        }
        root.runHermes("Analise este texto extraído de uma screenshot:\n\n" + ocrText.slice(0, 3000));
    }
    function onScrapeReady(text) {
        if (!text) {
            root.aiText = "❌ Não consegui baixar o link";
            root.aiLoading = false;
            if (root._shown) root.scheduleRebuild();
            return;
        }
        root.runHermes("Resuma este conteúdo web:\n\n" + text.slice(0, 5000));
    }
    function onPdfReady(text) {
        if (!text) {
            root.aiText = "❌ Não consegui ler o PDF";
            root.aiLoading = false;
            if (root._shown) root.scheduleRebuild();
            return;
        }
        root.runHermes("Resuma este PDF:\n\n" + text.slice(0, 6000));
    }
    function onGitDiffReady(diff) {
        if (!diff) {
            root.aiText = "📭 Nada pra commitar";
            if (root._shown) root.scheduleRebuild();
            return;
        }
        root.runHermes("Gere mensagem de commit (Conventional Commits):\n\n" + diff);
    }
    function onBriefingReady(text) {
        if (!text) {
            root.aiText = "❌ Briefing indisponível";
            if (root._shown) root.scheduleRebuild();
            return;
        }
        root.runHermes("Formate este briefing matinal:\n\n" + text);
    }
    function onHistoryReady(history) {
        if (Array.isArray(history) && history.length > 0) root.aiHistory = history;
    }
}

## 7. Salvar histórico (dentro do Connections { target: root; onAiHistoryChanged })

    if (root.aiPersistentHistory) {
        SpotlightActions.saveHistory(JSON.stringify(root.aiHistory));
    }

## 8. onSpotlightOpenChanged — trocar root.aiHistory = [] por

    if (!root.aiPersistentHistory) {
        root.aiHistory = [];
    } else {
        SpotlightActions.loadHistory();
    }

## 9. allCmds — adicionar

    { kind: "cmd", name: "/screenshot",  category: "Analyze screen with OCR + AI", action: "screenshot:" },
    { kind: "cmd", name: "/web-sum",     category: "Summarize a web link",          action: "web-sum:" },
    { kind: "cmd", name: "/pdf-sum",     category: "Summarize a PDF file",          action: "pdf-sum:" },
    { kind: "cmd", name: "/memoria-on",  category: "Enable persistent AI history",  action: "mem-on:" },
    { kind: "cmd", name: "/memoria-off", category: "Disable persistent AI history", action: "mem-off:" },

## 10. openSelected — no bloco `e.kind === "cmd"`, adicionar

    } else if (e.action === "screenshot:") {
        root.aiText = "📸 Capturando tela…";
        SpotlightActions.runScreenshotOcr(false);
        keepOpen = true;
        return;
    } else if (e.action === "web-sum:") {
        const url = root.query.replace(/^\/web-sum\s*/, "").trim();
        if (url) {
            root.aiText = "🌐 Baixando…";
            SpotlightActions.scrapeUrl(url);
            keepOpen = true;
        }
        return;
    } else if (e.action === "pdf-sum:") {
        const path = root.query.replace(/^\/pdf-sum\s*/, "").trim();
        if (path) {
            root.aiText = "📄 Lendo…";
            SpotlightActions.summarizePdf(path);
            keepOpen = true;
        }
        return;
    } else if (e.action === "mem-on:") {
        root.aiPersistentHistory = true;
        root.aiText = "💾 Memória persistente ATIVADA";
        root.scheduleRebuild();
        keepOpen = true;
        return;
    } else if (e.action === "mem-off:") {
        root.aiPersistentHistory = false;
        root.aiText = "💾 Memória persistente DESATIVADA";
        root.scheduleRebuild();
        keepOpen = true;
        return;
    }
PATCHES_EOF

echo "✅ .spotlight-patches.md"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  🎉 Arquivos criados em: $DEST"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Próximos passos:"
echo "  1. Aplique os patches do .spotlight-patches.md no Spotlight.qml"
echo "  2. Recarregue: qs -c ii 2>&1 | tail -30"
echo ""
