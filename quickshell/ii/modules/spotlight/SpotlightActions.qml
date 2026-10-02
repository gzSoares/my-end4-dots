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
            ? `printf '' | wl-copy 2>/dev/null
               qs -c ii ipc call region screenshot
               for i in $(seq 1 60); do
                   sleep 0.25
                   wl-paste --list-types 2>/dev/null | grep -q '^image/' && break
               done
               f="/tmp/spotlight-region-$(date +%s).png"
               wl-paste --type image > "$f" 2>/dev/null
               if [ -s "$f" ]; then
                   tesseract "$f" stdout -l por+eng+jpn 2>/dev/null
                   rm -f "$f"
               else
                   rm -f "$f"
                   echo "Nenhuma imagem capturada"
               fi`
            : `f="/tmp/spotlight-ocr-$(date +%s).png"; grim "$f" 2>/dev/null && tesseract "$f" stdout -l por+eng+jpn 2>/dev/null; rm -f "$f"`]
                stdout: StdioCollector { onStreamFinished: root.screenshotOcrReady(text.trim()) }
            }
        signal screenshotOcrReady(string ocrText)

    // Tela inteira: janelas (hyprctl) + OCR do monitor focado
    function runScreenContext() {
        if (_screenProc.running) return;
        _screenProc.running = true;
    }
    Process {
        id: _screenProc
        running: false
        command: ["bash", "-c", `
sleep 0.4
f="/tmp/spotlight-screen-$(date +%s).png"
info=$(python3 - <<'PYEOF'
import json, subprocess

def hc(*a):
    try:
        return json.loads(subprocess.check_output(["hyprctl", *a, "-j"], text=True))
    except Exception:
        return None

mons = hc("monitors") or []
mon = next((m for m in mons if m.get("focused")), mons[0] if mons else None)
name = mon["name"] if mon else ""
ws = mon["activeWorkspace"]["id"] if mon else None
act = hc("activewindow") or {}
print("MON::" + name)
if act.get("class") or act.get("title"):
    print("ACTIVE::%s | %s" % (act.get("class", ""), act.get("title", "")))
for c in hc("clients") or []:
    if c.get("mapped") and not c.get("hidden") and c.get("workspace", {}).get("id") == ws:
        print("WIN::%s | %s" % (c.get("class", ""), c.get("title", "")))
PYEOF
)
mon=$(echo "$info" | sed -n 's/^MON:://p' | head -1)
if [ -n "$mon" ]; then grim -o "$mon" "$f" 2>/dev/null; else grim "$f" 2>/dev/null; fi
echo "$info" | grep -v '^MON::' | sed -e 's/^ACTIVE::/Janela em foco: /' -e 's/^WIN::/- /'
echo '@@OCR@@'
if [ -s "$f" ]; then timeout 30 tesseract "$f" stdout -l por+eng+jpn --psm 11 2>/dev/null; fi
rm -f "$f"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("@@OCR@@");
                root.screenContextReady((parts[0] || "").trim(), (parts[1] || "").trim());
            }
        }
    }
    signal screenContextReady(string windows, string ocr)

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