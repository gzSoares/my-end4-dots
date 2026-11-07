//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// text-editor.qml — a text editor in the shell's own look.
//
// Disk access goes through editor/editor-io.py, which is what keeps a save from
// ever losing a file. Unsaved work is written to drafts every few seconds and
// comes back the next time the editor opens, crash or not.
//
// Open it with editor/mainstream-editor [files...]
// Needs: syntax-highlighting (KDE), python.

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import org.kde.syntaxhighlighting
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ApplicationWindow {
    id: root
    visible: true
    width: 1000
    height: 720
    minimumWidth: 560
    minimumHeight: 380
    color: Appearance.m3colors.m3background
    title: (root.pane?.displayName ?? "") + " — Text Editor"

    // ── Preferences, the same ones GNOME Text Editor has ───────────
    property var prefs: ({
        lineNumbers: true, highlightLine: false, matchBrackets: true, rightMargin: false, marginColumn: 80,
        wrap: true, autoIndent: true, useSpaces: false, tabWidth: 8, indentWidth: -1, fontSize: 14, restoreSession: false,
        showGrid: false, showMap: false, customFont: false, fontFamily: "Monospace", discover: true,
        scheme: "", variant: "follow"
    })
    function setPref(key, value) {
        // These move every line. The view jumps to the top before anything else
        // hears of it, so the line being read is noted first.
        if (["fontSize", "fontFamily", "customFont", "wrap"].includes(key)) {
            for (let i = 0; i < docs.count; i++) root.paneFor(docs.get(i).docId)?.holdLine();
            lineTimer.restart();
        }
        const next = Object.assign({}, root.prefs);
        next[key] = value;
        root.prefs = next;
        root.saveState();
    }

    // ── Documents ──────────────────────────────────────────────────
    property int nextId: 1
    property int currentId: 0
    property var pendingDocs: ({})
    property var recent: []
    property bool stateLoaded: false
    property string panel: ""        // "", "open", "menu", "language", "encoding"
    property string dialogName: ""   // "", "prefs", "shortcuts", "about"
    property var themeList: []
    // The font picker edits these, and nothing changes until it is confirmed.
    property bool fontPickerShown: false
    property string fontFamily: ""
    property int fontSize: 14
    property bool monospaceOnly: true
    property var monospaceFonts: []
    readonly property var fontChoices: {
        const wanted = fontFilter.text.toLowerCase();
        const source = root.monospaceOnly && root.monospaceFonts.length > 0 ? root.monospaceFonts : Qt.fontFamilies();
        return source.filter(name => name.toLowerCase().includes(wanted));
    }
    property string toast: ""
    property bool findShown: false
    property bool replaceShown: false
    property bool goToShown: false
    // A selected blank line searches for all of them, with no pattern to read.
    property bool emptyLinesMode: false
    // What is waiting on an answer: {kind: "close"|"quit", id}
    property var asking: null
    property var closingIds: []
    readonly property var pane: root.paneFor(root.currentId)
    readonly property bool fullscreen: root.visibility === Window.FullScreen
    readonly property string pendingFiles: Quickshell.env("EDITOR_FILES") ?? ""
    // Opened with New Window: the first window owns the drafts.
    readonly property bool secondWindow: Quickshell.env("EDITOR_SECOND_WINDOW") === "1"
    readonly property bool darkVariant: root.prefs.variant === "follow" ? Appearance.m3colors.darkmode : root.prefs.variant === "dark"
    readonly property string schemeName: {
        const chosen = root.themeList.find(theme => theme.name === root.prefs.scheme);
        return chosen && chosen.dark === root.darkVariant ? chosen.name : (root.darkVariant ? "Breeze Dark" : "Breeze Light");
    }
    readonly property var themeObject: Repository.theme(root.schemeName)
    readonly property var schemeColors: root.themeList.find(theme => theme.name === root.schemeName) ?? null
    // With no scheme chosen the editor takes the shell's own surface.
    readonly property bool shellSurface: root.schemeName === (Appearance.m3colors.darkmode ? "Breeze Dark" : "Breeze Light")
        && root.darkVariant === Appearance.m3colors.darkmode
    readonly property color editorBackground: root.shellSurface || !root.schemeColors ? Appearance.m3colors.m3background : root.schemeColors.background
    readonly property color editorText: root.shellSurface || !root.schemeColors ? Appearance.colors.colOnLayer0 : root.schemeColors.text
    readonly property string editorFont: root.prefs.customFont ? root.prefs.fontFamily : Appearance.font.family.monospace

    function paneFor(id) {
        const count = panes.count;
        for (let i = 0; i < count; i++) {
            const item = panes.itemAt(i);
            if (item && item.docId === id) return item;
        }
        return null;
    }
    function tabIndex(id) {
        for (let i = 0; i < docs.count; i++)
            if (docs.get(i).docId === id) return i;
        return -1;
    }
    function addDoc(config) {
        const id = root.nextId++;
        const pending = Object.assign({}, root.pendingDocs);
        pending[id] = config ?? {};
        root.pendingDocs = pending;
        docs.append({ docId: id, name: config?.name ?? Translation.tr("New Document"), dirty: false });
        root.currentId = id;
        return id;
    }
    function newDocument() {
        root.addDoc({});
        root.focusEditor();
    }
    function focusEditor() {
        Qt.callLater(() => root.pane?.focusText());
    }
    function isBlank(item) {
        return item && !item.filePath && !item.modified && item.textLength === 0;
    }
    function openPaths(paths) {
        paths.filter(p => p.length > 0).forEach(path => {
            for (let i = 0; i < docs.count; i++) {
                const item = root.paneFor(docs.get(i).docId);
                if (item && item.filePath === path) {
                    root.currentId = item.docId;
                    return;
                }
            }
            io.call({ op: "read", path: path }, reply => root.opened(path, reply));
        });
    }
    function opened(path, reply) {
        if (!reply.ok) {
            const reasons = {
                notfound: Translation.tr("File not found"), directory: Translation.tr("This is a folder"),
                binary: Translation.tr("This looks like a binary file"), toolarge: Translation.tr("File is too large")
            };
            root.showToast((reasons[reply.error] ?? reply.detail ?? reply.error) + ": " + path.replace(/^.*\//, ""));
            return;
        }
        // An empty untouched tab gives way to the file.
        const current = root.pane;
        if (docs.count === 1 && root.isBlank(current)) {
            current.load(path, reply);
        } else {
            root.addDoc({ path: path, reply: reply, name: path.replace(/^.*\//, "") });
        }
        root.remember(path);
        root.focusEditor();
    }
    function remember(path) {
        root.recent = [path].concat(root.recent.filter(p => p !== path)).slice(0, 15);
        root.saveState();
    }
    function saveState() {
        if (!root.stateLoaded) return;
        const session = [];
        for (let i = 0; i < docs.count; i++) {
            const item = root.paneFor(docs.get(i).docId);
            if (item?.filePath) session.push(item.filePath);
        }
        io.call({ op: "saveState", state: { prefs: root.prefs, recent: root.recent, session: session } });
    }
    function removeDoc(id) {
        const index = root.tabIndex(id);
        if (index === -1) return;
        const wasCurrent = id === root.currentId;
        root.paneFor(id)?.dropDraft();
        docs.remove(index);
        if (docs.count === 0) {
            root.addDoc({});
        } else if (wasCurrent) {
            root.currentId = docs.get(Math.min(index, docs.count - 1)).docId;
        }
        root.saveState();
        root.focusEditor();
    }
    function closeDoc(id) {
        const item = root.paneFor(id);
        if (item?.modified) {
            root.currentId = id;
            root.asking = { kind: "close", id: id };
        } else {
            root.removeDoc(id);
        }
    }
    function modifiedCount() {
        let count = 0;
        for (let i = 0; i < docs.count; i++)
            if (root.paneFor(docs.get(i).docId)?.modified) count++;
        return count;
    }
    function quit() {
        if (root.modifiedCount() > 0) {
            root.asking = { kind: "quit" };
            return;
        }
        root.finish();
    }
    function finish() {
        root.saveState();
        // Replies are in order, so this one means every write before it is done.
        io.call({ op: "stat", paths: [] }, () => Qt.quit());
        quitFallback.start();
    }
    function keepDraftsAndQuit() {
        for (let i = 0; i < docs.count; i++) root.paneFor(docs.get(i).docId)?.writeDraft();
        root.finish();
    }
    function discardAllAndQuit() {
        for (let i = 0; i < docs.count; i++) root.paneFor(docs.get(i).docId)?.dropDraft();
        root.finish();
    }
    function showToast(text) {
        root.toast = text;
        toastTimer.restart();
    }
    function newWindow() {
        Quickshell.execDetached(["env", "EDITOR_SECOND_WINDOW=1", "EDITOR_FILES=", "qs", "-p", Quickshell.shellPath("text-editor.qml")]);
    }
    function openFontPicker() {
        root.fontFamily = root.prefs.fontFamily;
        root.fontSize = root.prefs.fontSize;
        fontFilter.text = "";
        root.fontPickerShown = true;
        if (root.monospaceFonts.length === 0) monospaceProc.running = true;
        Qt.callLater(() => {
            fontFilter.forceActiveFocus();
            const index = root.fontChoices.indexOf(root.fontFamily);
            if (index !== -1) fontList.positionViewAtIndex(index, ListView.Center);
        });
    }
    function moveFontChoice(step) {
        const choices = root.fontChoices;
        if (choices.length === 0) return;
        const at = Math.max(0, Math.min(choices.length - 1, choices.indexOf(root.fontFamily) + step));
        root.fontFamily = choices[at];
        fontList.positionViewAtIndex(at, ListView.Contain);
    }
    function closeFontPicker() {
        root.fontPickerShown = false;
    }
    function applyFont() {
        root.setPref("fontFamily", root.fontFamily);
        root.setPref("fontSize", root.fontSize);
        root.closeFontPicker();
    }
    function clearHistory() {
        root.recent = [];
        root.saveState();
        root.showToast(Translation.tr("History cleared"));
    }
    function toggleFullscreen() {
        root.visibility = root.fullscreen ? Window.Windowed : Window.FullScreen;
    }
    function openFind(withReplace) {
        root.goToShown = false;
        root.findShown = true;
        root.replaceShown = withReplace;
        const selected = root.pane?.selectionText() ?? "";
        // A selected blank line means the blank lines. Taken literally it is one
        // line break, which matches every line of the document: replacing those
        // would glue the whole text together.
        if (selected.includes("\n") && selected.trim() === "") {
            root.findEmptyLines();
            return;
        }
        if (selected) {
            root.emptyLinesMode = false;
            findInput.text = root.fieldText(selected);
        }
        findInput.forceActiveFocus();
        findInput.selectAll();
        root.pane?.search();
    }
    // The fields are one line tall, so a line break is typed as \n, in both of them
    // and with or without a pattern, as GNOME Text Editor does. \\ is a backslash.
    function unescaped(text) {
        return text.replace(/\\(n|t|r|\\)/g, (all, ch) => ({ n: "\n", t: "\t", r: "\r", "\\": "\\" })[ch]);
    }
    function fieldText(text) {
        const source = regexButton.toggled ? text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") : text.replace(/\\/g, "\\\\");
        return source.replace(/\n/g, "\\n").replace(/\t/g, "\\t");
    }
    function findEmptyLines() {
        root.emptyLinesMode = true;
        findInput.text = "";
        replaceInput.text = "";
        root.pane?.search();
        replaceInput.forceActiveFocus();
    }
    function closeFind() {
        root.emptyLinesMode = false;
        root.findShown = false;
        root.replaceShown = false;
        root.pane?.clearSearch();
        root.focusEditor();
    }
    function saveAs(id) {
        root.currentId = id;
        saveDialog.docId = id;
        const item = root.paneFor(id);
        saveDialog.currentFile = "file://" + (item?.filePath || StandardPaths.writableLocation(StandardPaths.DocumentsLocation).toString().replace("file://", "") + "/" + item?.displayName + ".txt");
        saveDialog.open();
    }

    Component.onCompleted: {
        // Started on its own, so it has to ask for the shell's colors itself.
        Quickshell.watchFiles = false;
        MaterialThemeLoader.reapplyTheme();
        io.call({ op: "themes" }, reply => root.themeList = reply.themes ?? []);
        io.call({ op: "loadState" }, reply => {
            const saved = reply.state ?? {};
            root.prefs = Object.assign({}, root.prefs, saved.prefs ?? {});
            root.recent = saved.recent ?? [];
            root.stateLoaded = true;
            // Unsaved work always comes back; the session only if asked for.
            if (!root.secondWindow) (reply.drafts ?? []).forEach(draft => root.addDoc({ draft: draft, name: draft.name }));
            const files = root.pendingFiles.split("\n").filter(p => p.length > 0);
            const restored = root.prefs.restoreSession && !root.secondWindow ? (saved.session ?? []) : [];
            const drafted = (reply.drafts ?? []).map(d => d.path);
            root.openPaths(restored.filter(p => !drafted.includes(p) && !files.includes(p)).concat(files));
            if (docs.count === 0 && files.length === 0 && restored.length === 0) root.addDoc({});
            root.focusEditor();
        });
    }
    onClosing: close => {
        // The window going away does not end the process: left running it would keep
        // taking files sent to it, with nothing on screen to show them.
        close.accepted = false;
        root.quit();
    }

    // ── The disk helper ────────────────────────────────────────────
    QtObject {
        id: io
        property var waiting: ({})
        property int serial: 0
        // Held until the helper is up: a write before that goes nowhere.
        property bool started: false
        property var queued: []
        function call(request, reply) {
            serial++;
            const id = serial;
            if (reply) waiting[id] = reply;
            const line = JSON.stringify(Object.assign({ id: id }, request)) + "\n";
            if (started) ioProc.write(line);
            else queued.push(line);
        }
        function flush() {
            started = true;
            queued.forEach(line => ioProc.write(line));
            queued = [];
        }
        function received(line) {
            let reply;
            try {
                reply = JSON.parse(line);
            } catch (e) {
                return;
            }
            const handler = waiting[reply.id];
            delete waiting[reply.id];
            if (handler) handler(reply);
        }
    }
    Process {
        id: ioProc
        running: true
        stdinEnabled: true
        command: ["python3", "-I", Quickshell.shellPath("editor/editor-io.py")]
        stdout: SplitParser {
            onRead: line => io.received(line)
        }
        onStarted: io.flush()
        onExited: {
            io.started = false;
            root.showToast(Translation.tr("The disk helper stopped: saving will not work. Copy your text and restart."));
        }
    }

    IpcHandler {
        target: "editor"
        function open(paths: string): void {
            root.openPaths(paths.split("\n"));
        }
        function status(): string {
            const p = root.pane;
            return JSON.stringify({
                tabs: docs.count, path: p?.filePath ?? "", name: p?.displayName ?? "", modified: p?.modified ?? false,
                line: p?.currentLine ?? 0, column: p?.currentColumn ?? 0, language: p?.languageName ?? "",
                matches: p?.matches.length ?? 0, encoding: p?.encoding ?? "", eol: p?.eol ?? "", asking: root.asking?.kind ?? "",
                conflict: p?.conflict ?? "", toast: root.toast, cursor: p?.cursorPos() ?? 0, selection: p?.selectionText().length ?? 0, refreshes: p?.refreshCount ?? 0, text: (p?.textLength ?? 0) < 4000 ? p?.allText() : ""
            });
        }
        function save(): void {
            root.pane?.save(false);
        }
        function saveTo(path: string): void {
            root.pane?.saveTo(path);
        }
        function replaceMode(): void {
            root.openFind(true);
        }
        function emptyLines(): void {
            root.findEmptyLines();
        }
        function findText(text: string, regex: bool): void {
            regexButton.toggled = regex;
            findInput.text = text;
            root.pane?.search();
        }
        function replaceWith(text: string): void {
            replaceInput.text = text;
            root.pane?.replaceAll();
        }
        function fields(): string {
            return JSON.stringify({ find: findInput.text, replace: replaceInput.text, regex: regexButton.toggled, emptyLines: root.emptyLinesMode });
        }
        function panelName(name: string): void {
            root.panel = name;
        }
        function insertText(text: string): void {
            root.pane?.insertAtEnd(text);
        }
        function newDoc(): void {
            root.newDocument();
        }
        function revert(): void {
            root.asking = { kind: "revert", id: root.currentId };
        }
        function clearRecent(): void {
            root.clearHistory();
        }
        function fontPicker(): void {
            root.openFontPicker();
        }
        function fontState(): string {
            return JSON.stringify({ family: root.fontFamily, size: root.fontSize, choices: root.fontChoices.length, shown: root.fontPickerShown,
                                    prefFamily: root.prefs.fontFamily, prefSize: root.prefs.fontSize, current: root.editorFont });
        }
        function dialogTo(name: string): void {
            root.dialogName = name;
        }
        function scroll(y: real): void {
            dialogScroll.contentY = y;
        }
        function effective(): string {
            const p = root.pane;
            return JSON.stringify({ topLine: (p?.firstVisibleLine() ?? 0) + 1, useSpaces: p?.useSpaces, tabWidth: p?.tabWidth, indentWidth: p?.indentWidth, scheme: root.schemeName, charWidth: p?.charWidth,
                                    background: String(root.editorBackground), themes: root.themeList.length, recent: root.recent.length });
        }
        function pref(key: string, value: string): void {
            root.setPref(key, JSON.parse(value));
        }
        function answer(choice: string): void {
            dialog.choose(choice);
        }
        function quitApp(): void {
            root.quit();
        }
    }

    // Should the helper be gone, its reply never comes.
    Timer {
        id: quitFallback
        interval: 3000
        onTriggered: Qt.quit()
    }
    Timer {
        id: lineTimer
        interval: 90
        onTriggered: {
            for (let i = 0; i < docs.count; i++) root.paneFor(docs.get(i).docId)?.returnToLine();
        }
    }
    Timer {
        id: toastTimer
        interval: 5000
        onTriggered: root.toast = ""
    }
    // Drafts, every few seconds as long as something changed.
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            for (let i = 0; i < docs.count; i++) {
                const item = root.paneFor(docs.get(i).docId);
                if (item?.draftStale) item.writeDraft();
            }
        }
    }
    // Other programs changing an open file.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            const paths = [];
            for (let i = 0; i < docs.count; i++) {
                const item = root.paneFor(docs.get(i).docId);
                if (item?.filePath) paths.push(item.filePath);
            }
            if (paths.length === 0) return;
            io.call({ op: "stat", paths: paths }, reply => {
                for (let i = 0; i < docs.count; i++) {
                    const item = root.paneFor(docs.get(i).docId);
                    if (item?.filePath && item.filePath in reply.mtimes) item.diskChanged(reply.mtimes[item.filePath]);
                }
            });
        }
    }

    ListModel { id: docs }

    FileDialog {
        id: openDialog
        title: Translation.tr("Open")
        fileMode: FileDialog.OpenFiles
        onAccepted: root.openPaths(selectedFiles.map(url => decodeURIComponent(url.toString().replace("file://", ""))))
    }
    FileDialog {
        id: saveDialog
        property int docId: 0
        title: Translation.tr("Save as")
        fileMode: FileDialog.SaveFile
        onAccepted: root.paneFor(docId)?.saveTo(decodeURIComponent(selectedFile.toString().replace("file://", "")))
    }

    // ── One document ───────────────────────────────────────────────
    component EditorPane: Item {
        id: pane
        required property int docId
        property string draftId: ""
        property string filePath: ""
        property string untitled: Translation.tr("New Document")
        property string encoding: "utf-8"
        property bool bom: false
        property string eol: "lf"
        property string mtime: ""
        property var definition: null
        // "", "changed" (on disk), "deleted", "conflict" (found while saving)
        property string conflict: ""
        property bool draftStale: false
        property bool loading: false
        property bool mixedEol: false
        property var lineStarts: [0]
        property var visibleLines: []
        property var bracketPair: []
        property var matches: []
        property int matchIndex: -1
        property string searchError: ""
        property var visibleMatches: []
        property string mapText: ""
        property int topLine: 0
        property int refreshCount: 0
        property real laidTop: 0
        property real laidBottom: 0
        property bool holdingLine: false
        readonly property bool modified: edit.textDocument.modified
        readonly property string displayName: filePath ? filePath.replace(/^.*\//, "") : untitled
        readonly property string languageName: definition?.name || Translation.tr("Plain Text")
        readonly property int textLength: edit.length
        readonly property string selectedText: edit.selectedText
        readonly property int currentLine: pane.lineOf(edit.cursorPosition) + 1
        readonly property int currentColumn: edit.cursorPosition - (pane.lineStarts[pane.currentLine - 1] ?? 0) + 1
        readonly property real charWidth: metrics.advanceWidth
        // What the file asks for, through a modeline or .editorconfig, comes first.
        property var discovered: ({})
        readonly property var fileSettings: root.prefs.discover ? pane.discovered : ({})
        readonly property bool useSpaces: pane.fileSettings.useSpaces ?? root.prefs.useSpaces
        readonly property int tabWidth: pane.fileSettings.tabWidth ?? root.prefs.tabWidth
        readonly property int indentWidth: {
            const width = pane.fileSettings.indentWidth ?? root.prefs.indentWidth;
            return width > 0 ? width : pane.tabWidth;
        }
        readonly property string indentUnit: pane.useSpaces ? " ".repeat(pane.indentWidth) : "\t"

        anchors.fill: parent
        visible: root.currentId === pane.docId

        onModifiedChanged: {
            const index = root.tabIndex(pane.docId);
            if (index !== -1) docs.setProperty(index, "dirty", pane.modified);
            if (!pane.modified) pane.dropDraft();
        }
        onDisplayNameChanged: {
            const index = root.tabIndex(pane.docId);
            if (index !== -1) docs.setProperty(index, "name", pane.displayName);
        }
        onVisibleChanged: if (pane.visible) {
            pane.refreshView();
            pane.focusText();
        }

        Component.onCompleted: {
            const config = root.pendingDocs[pane.docId] ?? {};
            pane.draftId = config.draft?.id ?? ("d" + Date.now() + "-" + pane.docId);
            if (config.draft) pane.restore(config.draft);
            else if (config.reply) pane.load(config.path, config.reply);
            else pane.updateLines();
        }

        function focusText() {
            edit.forceActiveFocus();
        }
        // Encoding and line endings are not text, but saving would change the file.
        function edit_markChanged() {
            edit.textDocument.modified = true;
        }
        function allText() {
            return edit.text;
        }
        function redo() {
            edit.redo();
        }
        function cursorPos() {
            return edit.cursorPosition;
        }
        function insertAtEnd(text) {
            edit.insert(edit.length, text);
        }
        // selectedText hands line breaks over as U+2029, which match nothing.
        function selectionText() {
            return edit.getText(edit.selectionStart, edit.selectionEnd);
        }
        function detectLanguage() {
            const found = pane.filePath ? Repository.definitionForFileName(pane.filePath) : null;
            // "None" is what plain text comes back as.
            pane.definition = found && found.name && found.name !== "None" ? found : null;
        }
        function setText(text) {
            pane.loading = true;
            edit.text = text;
            edit.textDocument.modified = false;
            pane.loading = false;
            pane.updateLines();
        }
        function load(path, reply) {
            pane.filePath = path;
            pane.encoding = reply.encoding;
            pane.bom = reply.bom;
            pane.eol = reply.eol;
            pane.mixedEol = reply.mixedEol;
            pane.mtime = reply.mtime;
            pane.conflict = "";
            pane.discovered = reply.settings ?? ({});
            pane.detectLanguage();
            // Marks from a search hold positions in the text being replaced.
            pane.clearSearch();
            pane.setText(reply.text);
            edit.cursorPosition = 0;
            if (reply.mixedEol) root.showToast(Translation.tr("This file mixes line endings; saving makes them all %1").arg(reply.eol.toUpperCase()));
        }
        function restore(draft) {
            pane.filePath = draft.path ?? "";
            pane.encoding = draft.encoding ?? "utf-8";
            pane.bom = draft.bom ?? false;
            pane.eol = draft.eol ?? "lf";
            pane.mtime = draft.mtime ?? "";
            pane.detectLanguage();
            pane.setText(draft.text ?? "");
            edit.textDocument.modified = true;
            edit.cursorPosition = Math.min(draft.cursor ?? 0, edit.length);
        }
        function reload() {
            io.call({ op: "read", path: pane.filePath }, reply => {
                if (reply.ok) pane.load(pane.filePath, reply);
                else root.showToast(Translation.tr("Could not read the file again"));
            });
        }
        function writeDraft() {
            if (!pane.modified) return;
            pane.draftStale = false;
            io.call({ op: "saveDraft", draft: {
                id: pane.draftId, name: pane.displayName, path: pane.filePath, text: edit.text, encoding: pane.encoding,
                bom: pane.bom, eol: pane.eol, mtime: pane.mtime, cursor: edit.cursorPosition
            } });
        }
        function dropDraft() {
            pane.draftStale = false;
            io.call({ op: "deleteDraft", id: pane.draftId });
        }
        function save(force) {
            if (!pane.filePath) {
                root.saveAs(pane.docId);
                return;
            }
            pane.write(pane.filePath, force, null);
        }
        function saveTo(path) {
            pane.write(path, true, () => {
                pane.filePath = path;
                pane.detectLanguage();
                root.remember(path);
            });
        }
        function write(path, force, done) {
            const snapshot = edit.text;
            io.call({ op: "write", path: path, text: snapshot, encoding: pane.encoding, bom: pane.bom, eol: pane.eol,
                      expectedMtime: path === pane.filePath ? pane.mtime : "", force: force }, reply => {
                if (!reply.ok) {
                    if (reply.error === "changed") pane.conflict = "conflict";
                    else if (reply.error === "encoding") root.showToast(Translation.tr("Some characters do not fit %1. Change the encoding and save again.").arg(pane.encoding));
                    else root.showToast(Translation.tr("Could not save: %1").arg(reply.detail ?? reply.error));
                    return;
                }
                pane.mtime = reply.mtime;
                pane.conflict = "";
                pane.mixedEol = false;
                if (done) done();
                // Typing while the save ran leaves those changes unsaved.
                if (edit.text === snapshot) edit.textDocument.modified = false;
                pane.continueClosing();
            });
        }
        function continueClosing() {
            if (root.closingIds.includes(pane.docId)) {
                root.closingIds = root.closingIds.filter(id => id !== pane.docId);
                root.removeDoc(pane.docId);
            }
        }
        function diskChanged(now) {
            if (now === "") {
                pane.conflict = "deleted";
            } else if (now !== pane.mtime && pane.conflict === "") {
                pane.conflict = "changed";
            }
        }

        // ── Lines ──────────────────────────────────────────────────
        function updateLines() {
            const text = edit.text;
            const starts = [0];
            let at = text.indexOf("\n");
            while (at !== -1) {
                starts.push(at + 1);
                at = text.indexOf("\n", at + 1);
            }
            pane.lineStarts = starts;
            if (root.prefs.showMap) pane.mapText = text.slice(0, 150000);
            pane.refreshView();
        }
        function lineOf(position) {
            const starts = pane.lineStarts;
            let low = 0;
            let high = starts.length - 1;
            while (low < high) {
                const mid = (low + high + 1) >> 1;
                if (starts[mid] <= position) low = mid;
                else high = mid - 1;
            }
            return low;
        }
        // Line numbers and search marks exist only for what is on screen.
        function holdLine() {
            scrollAnim.stop();
            if (!pane.holdingLine) pane.topLine = pane.firstVisibleLine();
            pane.holdingLine = true;
        }
        function returnToLine() {
            if (!pane.holdingLine) return;
            const start = pane.lineStarts[pane.topLine] ?? 0;
            flick.contentY = pane.clampedY(edit.positionToRectangle(start).y);
            pane.holdingLine = false;
            pane.refreshView();
        }
        function clampedY(y) {
            return Math.max(0, Math.min(flick.contentHeight + flick.bottomMargin - flick.height, y));
        }
        // Each notch adds to where the text is heading, so turning the wheel again
        // while it glides carries on from there instead of starting over.
        function glide(pixels) {
            const base = scrollAnim.running ? scrollAnim.to : flick.contentY;
            scrollAnim.to = pane.clampedY(base + pixels);
            scrollAnim.restart();
        }
        function firstVisibleLine() {
            const top = flick.contentY;
            const starts = pane.lineStarts;
            let low = 0;
            let high = starts.length - 1;
            while (low < high) {
                const mid = (low + high + 1) >> 1;
                if (edit.positionToRectangle(starts[mid]).y <= top) low = mid;
                else high = mid - 1;
            }
            return low;
        }
        // Line numbers and search marks exist for what is on screen and a stretch to
        // either side. Scrolling only slides them, until it leaves that stretch.
        function refreshView() {
            if (!pane.visible) return;
            pane.refreshCount++;
            const margin = flick.height * 1.5;
            const top = Math.max(0, flick.contentY - margin);
            const bottom = flick.contentY + flick.height + margin;
            const starts = pane.lineStarts;
            let low = 0;
            let high = starts.length - 1;
            while (low < high) {
                const mid = (low + high + 1) >> 1;
                if (edit.positionToRectangle(starts[mid]).y <= top) low = mid;
                else high = mid - 1;
            }
            const lines = [];
            for (let i = low; i < starts.length; i++) {
                const y = edit.positionToRectangle(starts[i]).y;
                if (y > bottom) break;
                lines.push({ number: i + 1, y: y });
            }
            pane.visibleLines = lines;
            pane.laidTop = top;
            pane.laidBottom = bottom;
            const shown = [];
            const first = starts[low] ?? 0;
            let from = 0;
            let to = pane.matches.length;
            while (from < to) {
                const mid = (from + to) >> 1;
                if (pane.matches[mid][0] < first) from = mid + 1;
                else to = mid;
            }
            for (let i = from; i < pane.matches.length && shown.length < 600; i++) {
                const start = edit.positionToRectangle(pane.matches[i][0]);
                if (start.y > bottom) break;
                const end = edit.positionToRectangle(pane.matches[i][1]);
                // A match running onto the next line is marked up to the end of this one.
                const lineEnd = starts[pane.lineOf(pane.matches[i][0]) + 1];
                const right = end.y === start.y || lineEnd === undefined ? end.x : edit.positionToRectangle(lineEnd - 1).x;
                shown.push({ x: start.x, y: start.y, width: Math.max(pane.charWidth, right - start.x),
                             height: start.height, current: i === pane.matchIndex });
            }
            pane.visibleMatches = shown;
        }
        function goToLine(line) {
            const index = Math.max(0, Math.min(pane.lineStarts.length - 1, line - 1));
            edit.cursorPosition = pane.lineStarts[index];
            pane.focusText();
        }

        // ── Brackets ───────────────────────────────────────────────
        function updateBrackets() {
            pane.bracketPair = [];
            if (!root.prefs.matchBrackets) return;
            const pairs = { "(": ")", "[": "]", "{": "}" };
            const closers = { ")": "(", "]": "[", "}": "{" };
            const position = edit.cursorPosition;
            const before = position > 0 ? edit.getText(position - 1, position) : "";
            const after = edit.getText(position, position + 1);
            let at = -1;
            let ch = "";
            if (pairs[after] || closers[after]) {
                at = position;
                ch = after;
            } else if (pairs[before] || closers[before]) {
                at = position - 1;
                ch = before;
            }
            if (at === -1) return;
            const forward = !!pairs[ch];
            const other = forward ? pairs[ch] : closers[ch];
            const window = 20000;
            const from = forward ? at + 1 : Math.max(0, at - window);
            const to = forward ? Math.min(edit.length, at + 1 + window) : at;
            const chunk = edit.getText(from, to);
            let depth = 1;
            for (let i = forward ? 0 : chunk.length - 1; forward ? i < chunk.length : i >= 0; i += forward ? 1 : -1) {
                if (chunk[i] === ch) depth++;
                else if (chunk[i] === other) depth--;
                if (depth === 0) {
                    pane.bracketPair = [at, from + i];
                    return;
                }
            }
        }

        // ── Find and replace ───────────────────────────────────────
        function searchPattern() {
            // With its line break, so that replacing it with nothing removes the line.
            if (root.emptyLinesMode) return /^[ \t]*\n/gm;
            const text = findInput.text;
            if (!text) return null;
            let source = regexButton.toggled ? text : root.unescaped(text).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
            if (wordButton.toggled) source = "\\b" + source + "\\b";
            return new RegExp(source, caseButton.toggled ? "gm" : "gim");
        }
        function search() {
            pane.searchError = "";
            pane.matches = [];
            pane.matchIndex = -1;
            let pattern = null;
            try {
                pattern = pane.searchPattern();
            } catch (e) {
                pane.searchError = Translation.tr("Invalid pattern");
            }
            if (pattern) {
                const text = edit.text;
                const found = [];
                let hit;
                while ((hit = pattern.exec(text)) !== null && found.length < 10000) {
                    // An empty match is real ("^$" is an empty line), but exec()
                    // would stay on it forever.
                    if (hit[0].length === 0) pattern.lastIndex++;
                    found.push([hit.index, hit.index + hit[0].length]);
                }
                pane.matches = found;
                const from = edit.selectionStart;
                pane.matchIndex = found.length === 0 ? -1 : Math.max(0, found.findIndex(m => m[0] >= from));
            }
            pane.refreshView();
        }
        function clearSearch() {
            pane.matches = [];
            pane.matchIndex = -1;
            pane.refreshView();
        }
        function selectMatch() {
            const match = pane.matches[pane.matchIndex];
            if (!match) return;
            edit.select(match[0], match[1]);
            pane.refreshView();
        }
        function nextMatch(step) {
            if (pane.matches.length === 0) return;
            pane.matchIndex = (pane.matchIndex + step + pane.matches.length) % pane.matches.length;
            pane.selectMatch();
        }
        function replaced(matched) {
            if (!regexButton.toggled || root.emptyLinesMode) return root.unescaped(replaceInput.text);
            // Only a pattern can refer back to what it matched. A function keeps
            // its result from being read a second time for "$".
            const template = replaceInput.text.replace(/\\n/g, "\n").replace(/\\t/g, "\t");
            return matched.replace(new RegExp(pane.searchPattern().source, caseButton.toggled ? "m" : "im"), template);
        }
        function replaceCurrent() {
            const match = pane.matches[pane.matchIndex];
            if (!match) return;
            const value = pane.replaced(edit.getText(match[0], match[1]));
            // Out first: the marks would be redrawn at positions about to go stale.
            pane.matches = [];
            edit.remove(match[0], match[1]);
            edit.insert(match[0], value);
            edit.cursorPosition = match[0] + value.length;
            pane.search();
            pane.selectMatch();
        }
        function replaceAll() {
            // Taken out first: redrawing the marks mid-way would use stale positions.
            const list = pane.matches;
            const count = list.length;
            pane.matches = [];
            for (let i = count - 1; i >= 0; i--) {
                const match = list[i];
                const value = pane.replaced(edit.getText(match[0], match[1]));
                edit.remove(match[0], match[1]);
                edit.insert(match[0], value);
            }
            pane.search();
            root.showToast(Translation.tr("%1 replaced").arg(count));
        }

        // ── Typing ─────────────────────────────────────────────────
        function lineStartAt(position) {
            return pane.lineStarts[pane.lineOf(position)] ?? 0;
        }
        function indentSelection(outdent) {
            const first = pane.lineOf(edit.selectionStart);
            const last = pane.lineOf(Math.max(edit.selectionStart, edit.selectionEnd - 1));
            for (let line = last; line >= first; line--) {
                const start = pane.lineStarts[line];
                if (!outdent) {
                    edit.insert(start, pane.indentUnit);
                    continue;
                }
                const head = edit.getText(start, start + pane.indentWidth);
                const remove = head.startsWith("\t") ? 1 : head.match(/^ */)[0].length;
                if (remove > 0) edit.remove(start, start + remove);
            }
            pane.updateLines();
        }
        function newLine() {
            if (edit.selectedText) edit.remove(edit.selectionStart, edit.selectionEnd);
            let insert = "\n";
            if (root.prefs.autoIndent) {
                const start = pane.lineStartAt(edit.cursorPosition);
                insert += edit.getText(start, edit.cursorPosition).match(/^[ \t]*/)[0];
            }
            edit.insert(edit.cursorPosition, insert);
        }

        // TextMetrics and not FontMetrics.advanceWidth(): a function call in a binding
        // is not repeated when the font changes, and everything sized by the
        // character would stay at the size the window opened with.
        TextMetrics {
            id: metrics
            font: edit.font
            text: "0"
        }
        NumberAnimation {
            id: scrollAnim
            target: flick
            property: "contentY"
            duration: 260
            easing.type: Easing.OutCubic
        }
        SyntaxHighlighter {
            textEdit: edit
            definition: pane.definition ?? ""
            theme: root.themeObject
        }
        Timer {
            id: linesTimer
            interval: 80
            onTriggered: {
                pane.updateLines();
                if (root.findShown) pane.search();
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Something happened to the file on disk
            Rectangle {
                Layout.fillWidth: true
                visible: pane.conflict !== ""
                implicitHeight: 46
                color: Appearance.colors.colSecondaryContainer
                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 14
                        rightMargin: 8
                    }
                    spacing: 6
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        color: Appearance.colors.colOnSecondaryContainer
                        text: pane.conflict === "deleted" ? Translation.tr("The file was deleted or moved. Save to create it again.")
                            : Translation.tr("The file changed on disk.")
                    }
                    BarTextButton {
                        visible: pane.conflict !== "deleted"
                        text: Translation.tr("Reload")
                        onClicked: pane.reload()
                    }
                    BarTextButton {
                        text: pane.conflict === "deleted" ? Translation.tr("Save") : Translation.tr("Overwrite")
                        onClicked: pane.save(true)
                    }
                    BarTextButton {
                        text: Translation.tr("Ignore")
                        onClicked: {
                            pane.conflict = "";
                            io.call({ op: "stat", paths: [pane.filePath] }, reply => pane.mtime = reply.mtimes[pane.filePath] || pane.mtime);
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Rectangle { // Behind the numbers and the text
                    parent: pane
                    anchors.fill: parent
                    z: -2
                    color: root.editorBackground
                    Canvas {
                        anchors.fill: parent
                        visible: root.prefs.showGrid
                        readonly property color line: root.darkVariant ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.06)
                        onLineChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onVisibleChanged: requestPaint()
                        onPaint: {
                            const context = getContext("2d");
                            context.clearRect(0, 0, width, height);
                            context.strokeStyle = line;
                            context.lineWidth = 1;
                            context.beginPath();
                            for (let x = 0.5; x < width; x += 20) {
                                context.moveTo(x, 0);
                                context.lineTo(x, height);
                            }
                            for (let y = 0.5; y < height; y += 20) {
                                context.moveTo(0, y);
                                context.lineTo(width, y);
                            }
                            context.stroke();
                        }
                    }
                }

                // Line numbers
                Item {
                    visible: root.prefs.lineNumbers
                    Layout.fillHeight: true
                    Layout.preferredWidth: Math.max(3, String(pane.lineStarts.length).length) * pane.charWidth + 22
                    clip: true
                    Item { // Moves with the text, so scrolling redoes nothing
                        y: -flick.contentY
                        width: parent.width
                    Repeater {
                        model: pane.visibleLines
                        delegate: Text {
                            required property var modelData
                            x: 0
                            y: modelData.y
                            width: parent.width - 10
                            horizontalAlignment: Text.AlignRight
                            text: modelData.number
                            font: edit.font
                            color: root.editorText
                            opacity: modelData.number === pane.currentLine ? 1 : 0.55
                        }
                    }
                    }
                }

                Flickable {
                    id: flick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    bottomMargin: 40
                    // Not interactive: a Flickable holds on to a press to see whether it
                    // becomes a drag, so the cursor moved late and a selection started
                    // late. The mouse goes straight to the text; the wheel is below.
                    interactive: false
                    boundsBehavior: Flickable.StopAtBounds
                    onContentYChanged: {
                        if (contentY < pane.laidTop || contentY + height > pane.laidBottom) Qt.callLater(pane.refreshView);
                    }
                    onWidthChanged: linesTimer.restart()
                    onHeightChanged: pane.refreshView()
                    ScrollBar.vertical: StyledScrollBar {}

                    MouseArea { // On top of the text, taking the wheel and no buttons
                        parent: flick
                        anchors.fill: parent
                        z: 1
                        acceptedButtons: Qt.NoButton
                        cursorShape: Qt.IBeamCursor
                        onWheel: wheel => {
                            // A touchpad already moves in small, continuous steps. On
                            // Wayland a wheel sends a pixelDelta as well, so the size of
                            // the step is what tells the two apart.
                            if (Math.abs(wheel.angleDelta.y) < 60) {
                                scrollAnim.stop();
                                flick.contentY = pane.clampedY(flick.contentY - wheel.angleDelta.y);
                            } else {
                                pane.glide(-wheel.angleDelta.y * 1.2);
                            }
                        }
                    }

                    ScrollBar.horizontal: ScrollBar {
                        policy: root.prefs.wrap ? ScrollBar.AlwaysOff : ScrollBar.AsNeeded
                    }

                    TextArea.flickable: TextArea {
                        id: edit
                        textFormat: TextEdit.PlainText
                        wrapMode: root.prefs.wrap ? TextEdit.Wrap : TextEdit.NoWrap
                        selectByMouse: true
                        persistentSelection: true
                        color: root.editorText
                        selectionColor: Appearance.colors.colSecondaryContainer
                        selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                        font.family: root.editorFont
                        font.pixelSize: root.prefs.fontSize
                        tabStopDistance: pane.tabWidth * pane.charWidth
                        leftPadding: 6
                        rightPadding: 12
                        topPadding: 8
                        // Room at the end comes from the Flickable's bottomMargin: padding
                        // here makes the text stop drawing that far above the window's edge.
                        bottomPadding: 0
                        onTextChanged: {
                            pane.bracketPair = [];
                            linesTimer.restart();
                            if (!pane.loading) pane.draftStale = true;
                        }
                        onCursorPositionChanged: {
                            scrollAnim.stop();
                            Qt.callLater(pane.updateBrackets);
                        }
                        // The control waits for a move or a release to place the cursor.
                        // It belongs under the pointer the moment the button goes down.
                        onPressed: event => {
                            if (event.button !== Qt.LeftButton || (event.modifiers & Qt.ShiftModifier)) return;
                            edit.forceActiveFocus();
                            edit.cursorPosition = edit.positionAt(event.x, event.y);
                        }

                        // Watches the pointer without taking it from the text.
                        PointHandler {
                            id: pointer
                            acceptedButtons: Qt.LeftButton
                            grabPermissions: PointerHandler.CanTakeOverFromAnything
                        }
                        // Holding a selection past the top or bottom keeps scrolling.
                        Timer {
                            interval: 16
                            repeat: true
                            running: pointer.active
                            onTriggered: {
                                const y = pointer.point.position.y - flick.contentY;
                                const edge = y < 0 ? y : y > flick.height ? y - flick.height : 0;
                                if (edge === 0) return;
                                const speed = Math.max(-40, Math.min(40, edge / 3));
                                flick.contentY = pane.clampedY(flick.contentY + speed);
                                const target = edge > 0 ? flick.contentY + flick.height - 2 : flick.contentY + 2;
                                edit.moveCursorSelection(edit.positionAt(pointer.point.position.x, target), TextEdit.SelectCharacters);
                            }
                        }

                        // Qt's text control keeps Emacs-style bindings that would act on
                        // the document: Ctrl+H deletes a character, Ctrl+K a line.
                        Keys.onShortcutOverride: event => {
                            if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_H || event.key === Qt.Key_K || event.key === Qt.Key_F))
                                event.accepted = true;
                        }
                        Keys.onPressed: event => {
                            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_H) {
                                root.openFind(true);
                                event.accepted = true;
                            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
                                root.openFind(false);
                                event.accepted = true;
                            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_K) {
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                const outdent = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier);
                                if (edit.selectedText.includes("\n") || outdent) {
                                    if (!edit.selectedText) edit.select(edit.cursorPosition, edit.cursorPosition);
                                    pane.indentSelection(outdent);
                                } else {
                                    if (edit.selectedText) edit.remove(edit.selectionStart, edit.selectionEnd);
                                    edit.insert(edit.cursorPosition, pane.indentUnit);
                                }
                                event.accepted = true;
                            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ControlModifier)) {
                                pane.newLine();
                                event.accepted = true;
                            }
                        }

                        background: null

                        // Inside the text so they scroll with it, and below it so they
                        // sit behind the letters. The control's background would not
                        // do: with a Flickable it stays put while the text moves.
                        Item {
                            anchors.fill: parent
                            z: -1
                            Rectangle { // Current line
                                visible: root.prefs.highlightLine
                                x: 0
                                y: edit.cursorRectangle.y
                                width: parent.width
                                height: edit.cursorRectangle.height
                                color: Appearance.colors.colLayer1
                            }
                            Rectangle { // Right margin
                                visible: root.prefs.rightMargin
                                x: edit.leftPadding + root.prefs.marginColumn * pane.charWidth
                                width: 1
                                height: parent.height
                                color: Appearance.colors.colLayer0Border
                            }
                            Repeater { // Search matches
                                model: pane.visibleMatches
                                delegate: Rectangle {
                                    required property var modelData
                                    x: modelData.x
                                    y: modelData.y
                                    width: modelData.width
                                    height: modelData.height
                                    radius: 3
                                    color: modelData.current ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer
                                    opacity: modelData.current ? 0.55 : 0.8
                                }
                            }
                            Repeater { // Matching brackets
                                model: pane.bracketPair
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property rect at: edit.positionToRectangle(modelData)
                                    x: at.x
                                    y: at.y
                                    width: pane.charWidth
                                    height: at.height
                                    radius: 3
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Appearance.colors.colPrimary
                                }
                            }
                        }
                    }
                }

                // Overview map
                Item {
                    id: overview
                    visible: root.prefs.showMap
                    Layout.fillHeight: true
                    Layout.preferredWidth: 130
                    clip: true
                    readonly property real shrink: 0.22
                    readonly property real mapHeight: mapContent.implicitHeight * shrink
                    readonly property real progress: flick.contentHeight > flick.height ? flick.contentY / (flick.contentHeight - flick.height) : 0
                    readonly property real offset: Math.min(0, (height - mapHeight) * progress)
                    onVisibleChanged: if (visible) pane.updateLines()

                    Rectangle {
                        anchors.left: parent.left
                        width: 1
                        height: parent.height
                        color: Appearance.colors.colLayer0Border
                    }
                    Text {
                        id: mapContent
                        x: 6
                        y: overview.offset
                        transformOrigin: Item.TopLeft
                        scale: overview.shrink
                        text: pane.mapText
                        textFormat: Text.PlainText
                        font.family: edit.font.family
                        font.pixelSize: 11
                        color: root.editorText
                        opacity: 0.8
                    }
                    Rectangle { // What is on screen
                        width: parent.width
                        y: overview.offset + flick.contentY / Math.max(1, flick.contentHeight) * overview.mapHeight
                        height: Math.max(12, flick.height / Math.max(1, flick.contentHeight) * overview.mapHeight)
                        color: Appearance.colors.colPrimary
                        opacity: 0.16
                    }
                    MouseArea {
                        anchors.fill: parent
                        function jump(y) {
                            const fraction = (y - overview.offset) / Math.max(1, overview.mapHeight);
                            flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, fraction * flick.contentHeight - flick.height / 2));
                        }
                        onPressed: mouse => jump(mouse.y)
                        onPositionChanged: mouse => { if (pressed) jump(mouse.y); }
                    }
                }
            }
        }
    }

    component MenuLine: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 3
        Layout.bottomMargin: 3
        implicitHeight: 1
        color: Appearance.colors.colLayer0Border
    }

    // ── Rows of the preferences, Adwaita's boxed lists ─────────────
    component PrefGroup: ColumnLayout {
        id: prefGroup
        property string title: ""
        default property alias rows: groupRows.data
        Layout.fillWidth: true
        Layout.bottomMargin: 18
        spacing: 8
        StyledText {
            visible: prefGroup.title !== ""
            Layout.leftMargin: 4
            text: prefGroup.title
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: groupRows.implicitHeight
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            ColumnLayout {
                id: groupRows
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                spacing: 0
            }
        }
    }
    component PrefRow: Item {
        id: prefRow
        property string title
        property string subtitle: ""
        property bool separated: true
        default property alias trailing: rowEnd.data
        Layout.fillWidth: true
        implicitHeight: subtitle ? 62 : 50
        Rectangle {
            visible: prefRow.separated
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: 1
            color: Appearance.colors.colLayer0Border
        }
        RowLayout {
            anchors {
                fill: parent
                leftMargin: 14
                rightMargin: 14
            }
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText {
                    Layout.fillWidth: true
                    text: prefRow.title
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: prefRow.subtitle !== ""
                    text: prefRow.subtitle
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
            RowLayout {
                id: rowEnd
                spacing: 8
            }
        }
    }
    component SwitchRow: PrefRow {
        id: switchRow
        property string key
        property bool available: true
        opacity: available ? 1 : 0.5
        StyledSwitch {
            enabled: switchRow.available
            checked: root.prefs[switchRow.key] ?? false
            onClicked: root.setPref(switchRow.key, checked)
        }
    }
    component SpinRow: PrefRow {
        id: spinRow
        property string key
        property int from: 1
        property int to: 200
        StyledSpinBox {
            from: spinRow.from
            to: spinRow.to
            value: root.prefs[spinRow.key]
            onValueModified: root.setPref(spinRow.key, value)
        }
    }

    component BarTextButton: RippleButton {
        id: barTextButton
        property color ink: Appearance.colors.colOnLayer1
        // Clicking must leave the keyboard where it was typing.
        focusPolicy: Qt.NoFocus
        implicitHeight: 32
        implicitWidth: barTextLabel.implicitWidth + 24
        buttonRadius: Appearance.rounding.small
        colBackground: Appearance.colors.colLayer1
        colBackgroundHover: Appearance.colors.colLayer1Hover
        contentItem: StyledText {
            id: barTextLabel
            anchors.centerIn: parent
            text: barTextButton.text
            font.pixelSize: Appearance.font.pixelSize.small
            color: barTextButton.ink
        }
    }
    component IconButton: RippleButton {
        id: iconButton
        property string symbol
        property string tip: ""
        focusPolicy: Qt.NoFocus
        implicitWidth: 36
        implicitHeight: 36
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colBackgroundToggled: Appearance.colors.colPrimary
        colBackgroundToggledHover: Appearance.colors.colPrimaryHover
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: iconButton.symbol
            iconSize: 20
            fill: iconButton.toggled ? 1 : 0
            color: iconButton.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
        }
        StyledToolTip {
            text: iconButton.tip
            extraVisibleCondition: iconButton.tip.length > 0
        }
    }
    component StatusButton: RippleButton {
        id: statusButton
        implicitHeight: 28
        implicitWidth: statusLabel.implicitWidth + 18
        buttonRadius: Appearance.rounding.small
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        contentItem: StyledText {
            id: statusLabel
            anchors.centerIn: parent
            text: statusButton.text
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
    }
    component Choice: RippleButton {
        id: choice
        property string detail: ""
        property bool selected: false
        Layout.fillWidth: true
        implicitHeight: detail ? 48 : 36
        buttonRadius: Appearance.rounding.small
        colBackground: selected ? Appearance.colors.colSecondaryContainer : "transparent"
        colBackgroundHover: selected ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer1Hover
        contentItem: ColumnLayout {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 10
                rightMargin: 10
            }
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: choice.text
                elide: Text.ElideMiddle
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                visible: choice.detail !== ""
                text: choice.detail
                elide: Text.ElideMiddle
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }
    component Popover: Rectangle {
        radius: Appearance.rounding.normal
        color: Appearance.m3colors.m3surfaceContainer
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            color: Appearance.m3colors.m3surfaceContainer

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 8
                    rightMargin: 8
                }
                spacing: 2

                IconButton {
                    symbol: "folder_open"
                    tip: Translation.tr("Open") + " (Ctrl+O)"
                    toggled: root.panel === "open"
                    onClicked: root.panel = root.panel === "open" ? "" : "open"
                }
                IconButton {
                    symbol: "note_add"
                    tip: Translation.tr("New") + " (Ctrl+N)"
                    onClicked: root.newDocument()
                }

                ListView {
                    id: tabs
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    orientation: ListView.Horizontal
                    spacing: 4
                    clip: true
                    model: docs
                    delegate: RippleButton {
                        id: tab
                        required property int index
                        required property int docId
                        required property string name
                        required property bool dirty
                        readonly property bool active: root.currentId === tab.docId
                        height: tabs.height
                        implicitWidth: Math.min(220, tabRow.implicitWidth + 16)
                        buttonRadius: Appearance.rounding.small
                        colBackground: active ? Appearance.colors.colSecondaryContainer : "transparent"
                        colBackgroundHover: active ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer1Hover
                        onClicked: root.currentId = tab.docId
                        middleClickAction: () => root.closeDoc(tab.docId)
                        contentItem: RowLayout {
                            id: tabRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 10
                                rightMargin: 4
                            }
                            spacing: 6
                            Rectangle {
                                visible: tab.dirty
                                implicitWidth: 7
                                implicitHeight: 7
                                radius: 4
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: tab.name
                                elide: Text.ElideMiddle
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: tab.active ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                            }
                            RippleButton {
                                id: closeTab
                                implicitWidth: 22
                                implicitHeight: 22
                                buttonRadius: Appearance.rounding.full
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Active
                                onClicked: root.closeDoc(tab.docId)
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "close"
                                    iconSize: 15
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                    }
                }

                IconButton {
                    symbol: "save"
                    tip: Translation.tr("Save") + " (Ctrl+S)"
                    enabled: root.pane?.modified ?? false
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.pane?.save(false)
                }
                IconButton {
                    symbol: "search"
                    tip: Translation.tr("Find") + " (Ctrl+F)"
                    toggled: root.findShown
                    onClicked: root.findShown ? root.closeFind() : root.openFind(false)
                }
                IconButton {
                    symbol: "menu"
                    tip: Translation.tr("Main Menu")
                    toggled: root.panel === "menu"
                    onClicked: root.panel = root.panel === "menu" ? "" : "menu"
                }
            }
        }

        // ── Documents ──────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Repeater {
                id: panes
                model: docs
                delegate: EditorPane {}
            }
        }

        // ── Find ───────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: root.findShown
            implicitHeight: findColumn.implicitHeight + 12
            color: Appearance.m3colors.m3surfaceContainerLow

            ColumnLayout {
                id: findColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                    rightMargin: 8
                }
                spacing: 4

                RowLayout {
                    spacing: 4
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer1
                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 10
                            }
                            StyledTextInput {
                                id: findInput
                                Layout.fillWidth: true
                                clip: true
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: findInput.text.length === 0
                                    text: Translation.tr("Find")
                                    color: Appearance.colors.colSubtext
                                }
                                onTextChanged: {
                                    if (text.length > 0) root.emptyLinesMode = false;
                                    root.pane?.search();
                                }
                                KeyNavigation.tab: replaceInput
                                Keys.onShortcutOverride: event => {
                                    if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_H || event.key === Qt.Key_F)) event.accepted = true;
                                }
                                Keys.onPressed: event => {
                                    if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_H || event.key === Qt.Key_F)) {
                                        root.openFind(event.key === Qt.Key_H || root.replaceShown);
                                        event.accepted = true;
                                    }
                                }
                                Keys.onReturnPressed: event => root.pane?.nextMatch((event.modifiers & Qt.ShiftModifier) ? -1 : 1)
                                Keys.onEscapePressed: root.closeFind()
                            }
                            StyledText {
                                visible: findInput.text.length > 0 || root.emptyLinesMode
                                text: root.pane?.searchError || ((root.pane?.matches.length ?? 0) > 0
                                    ? (root.pane.matchIndex + 1) + " / " + root.pane.matches.length : Translation.tr("No results"))
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                    IconButton {
                        id: caseButton
                        symbol: "match_case"
                        tip: Translation.tr("Match case")
                        onClicked: {
                            toggled = !toggled;
                            root.pane?.search();
                        }
                    }
                    IconButton {
                        id: wordButton
                        symbol: "match_word"
                        tip: Translation.tr("Whole word")
                        onClicked: {
                            toggled = !toggled;
                            root.pane?.search();
                        }
                    }
                    IconButton {
                        id: regexButton
                        symbol: "regular_expression"
                        tip: Translation.tr("Regular expression")
                        onClicked: {
                            toggled = !toggled;
                            root.pane?.search();
                        }
                    }
                    IconButton {
                        symbol: "keyboard_arrow_up"
                        tip: Translation.tr("Previous") + " (Shift+Enter)"
                        onClicked: root.pane?.nextMatch(-1)
                    }
                    IconButton {
                        symbol: "keyboard_arrow_down"
                        tip: Translation.tr("Next") + " (Enter)"
                        onClicked: root.pane?.nextMatch(1)
                    }
                    IconButton {
                        symbol: "find_replace"
                        tip: Translation.tr("Replace") + " (Ctrl+H)"
                        toggled: root.replaceShown
                        onClicked: root.replaceShown = !root.replaceShown
                    }
                    IconButton {
                        symbol: "close"
                        onClicked: root.closeFind()
                    }
                }
            }
        }

        // ── Replace ────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: root.replaceShown
            implicitHeight: 46
            color: Appearance.m3colors.m3surfaceContainerLow

                RowLayout {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 12
                        rightMargin: 8
                    }
                    spacing: 6
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer1
                        StyledTextInput {
                            id: replaceInput
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 10
                                rightMargin: 10
                            }
                            clip: true
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: replaceInput.text.length === 0
                                text: Translation.tr("Replace with (empty removes)")
                                color: Appearance.colors.colSubtext
                            }
                            KeyNavigation.backtab: findInput
                            Keys.onShortcutOverride: event => {
                                if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_H || event.key === Qt.Key_F)) event.accepted = true;
                            }
                            Keys.onPressed: event => {
                                if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_H || event.key === Qt.Key_F)) {
                                    root.openFind(event.key === Qt.Key_H || root.replaceShown);
                                    event.accepted = true;
                                }
                            }
                            Keys.onReturnPressed: event => {
                                if (event.modifiers & Qt.ControlModifier) root.pane?.replaceAll();
                                else root.pane?.replaceCurrent();
                            }
                            Keys.onEscapePressed: root.closeFind()
                        }
                    }
                    BarTextButton {
                        text: Translation.tr("Replace")
                        onClicked: root.pane?.replaceCurrent()
                    }
                    BarTextButton {
                        text: Translation.tr("Replace all")
                        onClicked: root.pane?.replaceAll()
                    }
                }
        }

        // ── Go to line ─────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: root.goToShown
            implicitHeight: 44
            color: Appearance.m3colors.m3surfaceContainerLow
            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 14
                    rightMargin: 8
                }
                StyledText {
                    text: Translation.tr("Go to line")
                    color: Appearance.colors.colOnLayer1
                }
                Rectangle {
                    implicitWidth: 90
                    implicitHeight: 30
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer1
                    StyledTextInput {
                        id: goToInput
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: 8
                        }
                        validator: IntValidator { bottom: 1 }
                        onAccepted: {
                            root.pane?.goToLine(parseInt(text));
                            root.goToShown = false;
                        }
                        Keys.onEscapePressed: {
                            root.goToShown = false;
                            root.focusEditor();
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }

        // ── Status ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 32
            color: Appearance.m3colors.m3surfaceContainer
            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 8
                }
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: root.pane?.filePath ?? ""
                    elide: Text.ElideMiddle
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                StatusButton {
                    text: Translation.tr("Ln %1, Col %2").arg(root.pane?.currentLine ?? 1).arg(root.pane?.currentColumn ?? 1)
                    onClicked: {
                        root.goToShown = true;
                        goToInput.text = "";
                        goToInput.forceActiveFocus();
                    }
                }
                StatusButton {
                    text: root.pane?.useSpaces ? Translation.tr("Spaces: %1").arg(root.pane.indentWidth) : Translation.tr("Tabs: %1").arg(root.pane?.tabWidth ?? 8)
                    onClicked: root.dialogName = "prefs"
                }
                StatusButton {
                    text: (root.pane?.encoding ?? "utf-8").toUpperCase() + " · " + (root.pane?.eol ?? "lf").toUpperCase()
                    onClicked: root.panel = root.panel === "encoding" ? "" : "encoding"
                }
                StatusButton {
                    text: root.pane?.languageName ?? ""
                    onClicked: {
                        root.panel = root.panel === "language" ? "" : "language";
                        languageFilter.text = "";
                        languageFilter.forceActiveFocus();
                    }
                }
            }
        }
    }

    DropArea {
        anchors.fill: parent
        onDropped: drop => {
            if (!drop.hasUrls) return;
            root.openPaths(drop.urls.map(url => decodeURIComponent(url.toString().replace("file://", ""))));
            drop.accept(Qt.CopyAction);
        }
    }

    // ── Popovers ───────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        visible: root.panel !== ""
        onClicked: {
            root.panel = "";
            root.focusEditor();
        }
    }

    Popover { // Open and recent files
        visible: root.panel === "open"
        x: 8
        y: 56
        width: 340
        height: Math.min(openColumn.implicitHeight + 20, root.height - 120)
        ColumnLayout {
            id: openColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 10
            }
            spacing: 2
            Choice {
                text: Translation.tr("Open a file…")
                onClicked: {
                    root.panel = "";
                    openDialog.open();
                }
            }
            ContentSubsectionLabel {
                visible: root.recent.length > 0
                text: Translation.tr("Recent")
            }
            Repeater {
                model: root.recent
                delegate: Choice {
                    required property string modelData
                    text: modelData.replace(/^.*\//, "")
                    detail: modelData.replace(/\/[^\/]*$/, "")
                    onClicked: {
                        root.panel = "";
                        root.openPaths([modelData]);
                    }
                }
            }
        }
    }

    Popover { // Main menu, in the order of GNOME Text Editor
        visible: root.panel === "menu"
        anchors {
            right: parent.right
            top: parent.top
            topMargin: 56
            rightMargin: 8
        }
        width: 280
        height: menuColumn.implicitHeight + 20
        ColumnLayout {
            id: menuColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 10
            }
            spacing: 2

            RowLayout { // Follow, light, dark
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                spacing: 6
                Repeater {
                    model: [["follow", "routine"], ["light", "light_mode"], ["dark", "dark_mode"]]
                    delegate: RippleButton {
                        id: variantButton
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 36
                        focusPolicy: Qt.NoFocus
                        toggled: root.prefs.variant === modelData[0]
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colLayer1
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        colBackgroundToggled: Appearance.colors.colPrimary
                        colBackgroundToggledHover: Appearance.colors.colPrimaryHover
                        onClicked: root.setPref("variant", modelData[0])
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            text: variantButton.modelData[1]
                            iconSize: 20
                            color: variantButton.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                        }
                    }
                }
            }
            RowLayout { // Zoom
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                IconButton {
                    symbol: "remove"
                    tip: Translation.tr("Zoom Out") + " (Ctrl+-)"
                    onClicked: root.setPref("fontSize", Math.max(8, root.prefs.fontSize - 1))
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Math.round(root.prefs.fontSize / 14 * 100) + "%"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                }
                IconButton {
                    symbol: "add"
                    tip: Translation.tr("Zoom In") + " (Ctrl++)"
                    onClicked: root.setPref("fontSize", Math.min(40, root.prefs.fontSize + 1))
                }
            }
            MenuLine {}
            Choice {
                text: Translation.tr("New Window")
                onClicked: { root.panel = ""; root.newWindow(); }
            }
            MenuLine {}
            Choice {
                text: Translation.tr("Save")
                onClicked: { root.panel = ""; root.pane?.save(false); }
            }
            Choice {
                text: Translation.tr("Save As…")
                onClicked: { root.panel = ""; root.saveAs(root.currentId); }
            }
            Choice {
                text: Translation.tr("Discard Changes…")
                enabled: (root.pane?.modified ?? false) && (root.pane?.filePath ?? "") !== ""
                opacity: enabled ? 1 : 0.4
                onClicked: {
                    root.panel = "";
                    root.asking = { kind: "revert", id: root.currentId };
                }
            }
            MenuLine {}
            Choice {
                text: Translation.tr("Find/Replace…")
                onClicked: { root.panel = ""; root.openFind(true); }
            }
            Choice {
                text: Translation.tr("Print…")
                detail: Translation.tr("No printing service on this system")
                enabled: false
                opacity: 0.4
            }
            MenuLine {}
            Choice {
                text: root.fullscreen ? Translation.tr("Leave Fullscreen") : Translation.tr("Fullscreen")
                onClicked: { root.panel = ""; root.toggleFullscreen(); }
            }
            MenuLine {}
            Choice {
                text: Translation.tr("Preferences")
                onClicked: { root.panel = ""; root.dialogName = "prefs"; }
            }
            Choice {
                text: Translation.tr("Keyboard Shortcuts")
                onClicked: { root.panel = ""; root.dialogName = "shortcuts"; }
            }
            Choice {
                text: Translation.tr("About Text Editor")
                onClicked: { root.panel = ""; root.dialogName = "about"; }
            }
        }
    }

    Popover { // Encoding and line endings
        visible: root.panel === "encoding"
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: 60
            bottomMargin: 38
        }
        width: 260
        height: encodingColumn.implicitHeight + 20
        ColumnLayout {
            id: encodingColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 10
            }
            spacing: 2
            ContentSubsectionLabel { text: Translation.tr("Encoding") }
            Repeater {
                model: [["utf-8", "UTF-8"], ["utf-16-le", "UTF-16"], ["cp1252", "Windows-1252"], ["latin-1", "ISO-8859-1"]]
                delegate: Choice {
                    required property var modelData
                    text: modelData[1]
                    selected: root.pane?.encoding === modelData[0]
                    onClicked: {
                        root.pane.encoding = modelData[0];
                        root.pane.bom = modelData[0].startsWith("utf-16");
                        root.pane.edit_markChanged();
                    }
                }
            }
            ContentSubsectionLabel { text: Translation.tr("Line endings") }
            Repeater {
                model: [["lf", "Unix (LF)"], ["crlf", "Windows (CRLF)"], ["cr", "Classic Mac (CR)"]]
                delegate: Choice {
                    required property var modelData
                    text: modelData[1]
                    selected: root.pane?.eol === modelData[0]
                    onClicked: {
                        root.pane.eol = modelData[0];
                        root.pane.edit_markChanged();
                    }
                }
            }
        }
    }

    Popover { // Language
        visible: root.panel === "language"
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: 8
            bottomMargin: 38
        }
        width: 280
        height: 380
        ColumnLayout {
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 6
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1
                StyledTextInput {
                    id: languageFilter
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: 10
                    }
                    clip: true
                }
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: root.panel === "language" ? Repository.definitions.filter(d => !d.hidden
                    && d.name.toLowerCase().includes(languageFilter.text.toLowerCase())) : []
                delegate: RippleButton {
                    id: languageRow
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: {
                        root.pane.definition = languageRow.modelData;
                        root.panel = "";
                        root.focusEditor();
                    }
                    contentItem: StyledText {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 10
                        }
                        text: languageRow.modelData.name
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }
        }
    }

    // ── Preferences, Keyboard Shortcuts, About ─────────────────────
    Rectangle {
        anchors.fill: parent
        visible: root.dialogName !== ""
        color: Qt.rgba(0, 0, 0, 0.45)
        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.dialogName = "";
                root.focusEditor();
            }
        }

        Popover {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 620)
            height: Math.min(parent.height - 40, root.dialogName === "about" ? 300 : 680)
            MouseArea { anchors.fill: parent }

            RowLayout {
                id: dialogHeader
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 8
                }
                Item { implicitWidth: 36 }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.dialogName === "prefs" ? Translation.tr("Preferences")
                        : root.dialogName === "shortcuts" ? Translation.tr("Keyboard Shortcuts") : Translation.tr("About Text Editor")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
                IconButton {
                    symbol: "close"
                    onClicked: {
                        root.dialogName = "";
                        root.focusEditor();
                    }
                }
            }

            StyledFlickable {
                id: dialogScroll
                anchors {
                    left: parent.left
                    right: parent.right
                    top: dialogHeader.bottom
                    bottom: parent.bottom
                    margins: 8
                }
                clip: true
                contentHeight: dialogBody.implicitHeight + 16

                ColumnLayout {
                    id: dialogBody
                    x: 14
                    width: dialogScroll.width - 28
                    spacing: 0

                    // Preferences: the groups and rows of GNOME Text Editor, in order
                    ColumnLayout {
                        visible: root.dialogName === "prefs"
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.leftMargin: 4
                            Layout.topMargin: 4
                            Layout.bottomMargin: 8
                            text: Translation.tr("Appearance")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer0
                        }
                        Flow {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 14
                            spacing: 8
                            Repeater {
                                model: root.themeList.filter(theme => theme.dark === root.darkVariant)
                                delegate: Rectangle {
                                    id: schemeCard
                                    required property var modelData
                                    readonly property bool chosen: root.schemeName === modelData.name
                                    width: 132
                                    height: 78
                                    radius: Appearance.rounding.small
                                    color: modelData.background
                                    border.width: chosen ? 3 : 1
                                    border.color: chosen ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                                    StyledText {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -8
                                        text: "Aa"
                                        font.pixelSize: Appearance.font.pixelSize.huge
                                        color: schemeCard.modelData.text
                                    }
                                    StyledText {
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            bottom: parent.bottom
                                            margins: 6
                                        }
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: schemeCard.modelData.name
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: schemeCard.modelData.text
                                    }
                                    MaterialSymbol {
                                        visible: schemeCard.chosen
                                        anchors {
                                            right: parent.right
                                            top: parent.top
                                            margins: 4
                                        }
                                        text: "check_circle"
                                        fill: 1
                                        iconSize: 18
                                        color: Appearance.colors.colPrimary
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.setPref("scheme", schemeCard.modelData.name)
                                    }
                                }
                            }
                        }

                        PrefGroup {
                            SwitchRow {
                                separated: false
                                title: Translation.tr("Custom Font")
                                key: "customFont"
                            }
                            PrefRow {
                                visible: root.prefs.customFont
                                title: root.prefs.fontFamily + " " + root.prefs.fontSize
                                BarTextButton {
                                    text: Translation.tr("Select…")
                                    onClicked: root.openFontPicker()
                                }
                            }
                        }
                        PrefGroup {
                            SwitchRow {
                                separated: false
                                title: Translation.tr("Show Grid Pattern")
                                key: "showGrid"
                            }
                            SwitchRow {
                                title: Translation.tr("Display Line Numbers")
                                key: "lineNumbers"
                            }
                            SwitchRow {
                                title: Translation.tr("Highlight Current Line")
                                key: "highlightLine"
                            }
                            SwitchRow {
                                title: Translation.tr("Display Overview Map")
                                key: "showMap"
                            }
                        }
                        PrefGroup {
                            SwitchRow {
                                separated: false
                                title: Translation.tr("Check Spelling")
                                subtitle: Translation.tr("Not available: no dictionary is installed")
                                key: "spellcheck"
                                available: false
                            }
                        }
                        PrefGroup {
                            title: Translation.tr("Line Wrap")
                            SwitchRow {
                                separated: false
                                title: Translation.tr("Show Right Margin")
                                key: "rightMargin"
                            }
                            SpinRow {
                                title: Translation.tr("Margin Position")
                                key: "marginColumn"
                                from: 1
                                to: 1000
                            }
                            SwitchRow {
                                title: Translation.tr("Wrap Lines Automatically (Alt+W)")
                                key: "wrap"
                            }
                        }
                        PrefGroup {
                            title: Translation.tr("Indentation")
                            SwitchRow {
                                separated: false
                                title: Translation.tr("Auto Indentation")
                                key: "autoIndent"
                            }
                            PrefRow {
                                title: Translation.tr("Character")
                                StyledComboBox {
                                    id: indentCharacter
                                    Layout.fillWidth: false
                                    Layout.preferredWidth: 130
                                    textRole: "displayName"
                                    model: [{ displayName: Translation.tr("Tab"), icon: "" }, { displayName: Translation.tr("Space"), icon: "" }]
                                    currentIndex: root.prefs.useSpaces ? 1 : 0
                                    onActivated: index => root.setPref("useSpaces", index === 1)
                                }
                            }
                            SpinRow {
                                title: Translation.tr("Spaces Per Tab")
                                key: "tabWidth"
                                from: 1
                                to: 32
                            }
                            SpinRow {
                                title: Translation.tr("Spaces Per Indent")
                                key: "indentWidth"
                                from: -1
                                to: 32
                            }
                        }
                        PrefGroup {
                            title: Translation.tr("Behavior")
                            SwitchRow {
                                separated: false
                                title: Translation.tr("Discover Document Settings")
                                subtitle: Translation.tr("Apply settings using modelines, editorconfig, or sensible defaults")
                                key: "discover"
                            }
                            SwitchRow {
                                title: Translation.tr("Restore Session")
                                subtitle: Translation.tr("Return to your previous session when Text Editor is started")
                                key: "restoreSession"
                            }
                        }
                        PrefGroup {
                            PrefRow {
                                separated: false
                                title: Translation.tr("Clear History")
                                BarTextButton {
                                    text: Translation.tr("Clear")
                                    onClicked: root.clearHistory()
                                }
                            }
                        }
                    }

                    // Keyboard Shortcuts
                    ColumnLayout {
                        visible: root.dialogName === "shortcuts"
                        Layout.fillWidth: true
                        spacing: 0
                        Repeater {
                            model: [
                                [Translation.tr("Documents"), [["Ctrl+N", Translation.tr("New document")], ["Ctrl+O", Translation.tr("Open")], ["Ctrl+S", Translation.tr("Save")], ["Ctrl+Shift+S", Translation.tr("Save as")], ["Ctrl+W", Translation.tr("Close document")], ["Ctrl+Tab", Translation.tr("Next document")], ["Ctrl+Q", Translation.tr("Quit")]]],
                                [Translation.tr("Editing"), [["Ctrl+Z", Translation.tr("Undo")], ["Ctrl+Shift+Z", Translation.tr("Redo")], ["Ctrl+F", Translation.tr("Find")], ["Ctrl+H", Translation.tr("Find and replace")], ["Ctrl+G", Translation.tr("Next match")], ["Ctrl+Shift+G", Translation.tr("Previous match")], ["Ctrl+I", Translation.tr("Go to line")], ["Tab / Shift+Tab", Translation.tr("Indent / unindent")]]],
                                [Translation.tr("View"), [["Ctrl++", Translation.tr("Zoom in")], ["Ctrl+-", Translation.tr("Zoom out")], ["Ctrl+0", Translation.tr("Reset zoom")], ["Alt+W", Translation.tr("Wrap lines")], ["F11", Translation.tr("Fullscreen")]]]
                            ]
                            delegate: PrefGroup {
                                required property var modelData
                                title: modelData[0]
                                Repeater {
                                    model: modelData[1]
                                    delegate: PrefRow {
                                        required property var modelData
                                        required property int index
                                        separated: index > 0
                                        title: modelData[1]
                                        StyledText {
                                            text: modelData[0]
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // About
                    ColumnLayout {
                        visible: root.dialogName === "about"
                        Layout.fillWidth: true
                        Layout.topMargin: 18
                        spacing: 8
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "edit_note"
                            iconSize: 64
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Text Editor"
                            font.pixelSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: Translation.tr("A text editor for this shell, built on Quickshell and KSyntaxHighlighting.")
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }
    }

    // ── Font picker ────────────────────────────────────────────────
    Process {
        id: monospaceProc
        command: ["fc-list", ":spacing=100", "family"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Icon fonts report themselves as monospaced but hold no text.
                const names = this.text.split("\n").map(line => line.split(",")[0].trim())
                    .filter(name => name && !/symbol|icon|emoji|dingbat/i.test(name));
                root.monospaceFonts = [...new Set(names)].sort((a, b) => a.localeCompare(b));
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.fontPickerShown
        color: Qt.rgba(0, 0, 0, 0.45)
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeFontPicker()
        }

        Popover {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 520)
            height: Math.min(parent.height - 40, 640)
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: 10

                RowLayout {
                    Item { implicitWidth: 36 }
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Translation.tr("Select Font")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                    }
                    IconButton {
                        symbol: "close"
                        onClicked: root.closeFontPicker()
                    }
                }

                RowLayout {
                    spacing: 8
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer1
                        border.width: fontFilter.activeFocus ? 2 : 1
                        border.color: fontFilter.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 8
                            MaterialSymbol {
                                text: "search"
                                iconSize: 20
                                color: Appearance.colors.colSubtext
                            }
                            StyledTextInput {
                                id: fontFilter
                                Layout.fillWidth: true
                                clip: true
                                Keys.onEscapePressed: root.closeFontPicker()
                                Keys.onReturnPressed: root.applyFont()
                                Keys.onDownPressed: root.moveFontChoice(1)
                                Keys.onUpPressed: root.moveFontChoice(-1)
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: fontFilter.text.length === 0
                                    text: Translation.tr("Search fonts")
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                    }
                    BarTextButton {
                        implicitHeight: 40
                        text: Translation.tr("Monospace")
                        colBackground: root.monospaceOnly ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
                        colBackgroundHover: root.monospaceOnly ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer1Hover
                        ink: root.monospaceOnly ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                        onClicked: root.monospaceOnly = !root.monospaceOnly
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    clip: true

                    StyledListView {
                        id: fontList
                        anchors {
                            fill: parent
                            margins: 6
                        }
                        clip: true
                        spacing: 2
                        model: root.fontChoices
                        delegate: RippleButton {
                            id: fontRow
                            required property string modelData
                            readonly property bool chosen: root.fontFamily === modelData
                            width: ListView.view.width
                            implicitHeight: 42
                            focusPolicy: Qt.NoFocus
                            buttonRadius: Appearance.rounding.small
                            colBackground: chosen ? Appearance.colors.colSecondaryContainer : "transparent"
                            colBackgroundHover: chosen ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer1Hover
                            onClicked: root.fontFamily = fontRow.modelData
                            contentItem: RowLayout {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 12
                                    rightMargin: 12
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: fontRow.modelData
                                    elide: Text.ElideRight
                                    font.family: fontRow.modelData
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: fontRow.chosen ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
                                }
                                MaterialSymbol {
                                    visible: fontRow.chosen
                                    text: "check"
                                    iconSize: 18
                                    color: Appearance.m3colors.m3onSecondaryContainer
                                }
                            }
                        }
                    }
                    StyledText {
                        anchors.centerIn: parent
                        visible: root.fontChoices.length === 0
                        text: Translation.tr("No fonts found")
                        color: Appearance.colors.colSubtext
                    }
                }

                // Preview, in the editor's own colors
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 76
                    radius: Appearance.rounding.normal
                    color: root.editorBackground
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    clip: true
                    Text {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: 14
                        }
                        text: "The quick brown fox 0123456789 {}[]()"
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        color: root.editorText
                    }
                }

                RowLayout {
                    spacing: 8
                    StyledText {
                        text: Translation.tr("Size")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledSpinBox {
                        from: 8
                        to: 40
                        value: root.fontSize
                        onValueModified: root.fontSize = value
                    }
                    Item { Layout.fillWidth: true }
                    BarTextButton {
                        text: Translation.tr("Cancel")
                        onClicked: root.closeFontPicker()
                    }
                    BarTextButton {
                        text: Translation.tr("Select")
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        ink: Appearance.m3colors.m3onPrimary
                        onClicked: root.applyFont()
                    }
                }
            }
        }
    }

    // ── Unsaved changes ────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: root.asking !== null
        color: Qt.rgba(0, 0, 0, 0.45)
        MouseArea { anchors.fill: parent }

        Popover {
            id: dialog
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 420)
            height: dialogColumn.implicitHeight + 32

            function choose(choice) {
                const asking = root.asking;
                root.asking = null;
                if (!asking || choice === "cancel") return;
                if (asking.kind === "revert") {
                    if (choice === "discard") root.paneFor(asking.id)?.reload();
                    else root.paneFor(asking.id)?.save(false);
                } else if (asking.kind === "close") {
                    if (choice === "discard") {
                        root.removeDoc(asking.id);
                    } else {
                        root.closingIds = root.closingIds.concat([asking.id]);
                        root.paneFor(asking.id)?.save(false);
                    }
                } else if (choice === "discard") {
                    root.discardAllAndQuit();
                } else {
                    root.keepDraftsAndQuit();
                }
            }

            ColumnLayout {
                id: dialogColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 16
                }
                spacing: 12
                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer0
                    text: root.asking?.kind === "quit" ? Translation.tr("You have unsaved documents")
                        : Translation.tr("Save changes to “%1”?").arg(root.pane?.displayName ?? "")
                }
                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Appearance.colors.colSubtext
                    text: root.asking?.kind === "quit" ? Translation.tr("Keep them as drafts to find them here next time.")
                        : Translation.tr("Discarded changes cannot be recovered.")
                }
                RowLayout {
                    spacing: 6
                    Item { Layout.fillWidth: true }
                    BarTextButton {
                        text: Translation.tr("Cancel")
                        onClicked: dialog.choose("cancel")
                    }
                    BarTextButton {
                        text: Translation.tr("Discard")
                        onClicked: dialog.choose("discard")
                    }
                    BarTextButton {
                        text: root.asking?.kind === "quit" ? Translation.tr("Keep drafts") : Translation.tr("Save")
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        ink: Appearance.m3colors.m3onPrimary
                        onClicked: dialog.choose("save")
                    }
                }
            }
        }
    }

    // Messages
    Popover {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 44
        }
        visible: root.toast !== ""
        width: Math.min(toastText.implicitWidth + 32, parent.width - 40)
        height: toastText.implicitHeight + 20
        StyledText {
            id: toastText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, root.width - 72)
            wrapMode: Text.Wrap
            text: root.toast
            color: Appearance.colors.colOnLayer1
        }
    }

    component Key: Shortcut { context: Qt.WindowShortcut }
    Key { sequences: ["Ctrl+N", "Ctrl+T"]; onActivated: root.newDocument() }
    Key { sequence: "Ctrl+O"; onActivated: openDialog.open() }
    Key { sequence: "Ctrl+S"; onActivated: root.pane?.save(false) }
    Key { sequence: "Ctrl+Shift+S"; onActivated: root.saveAs(root.currentId) }
    Key { sequence: "Ctrl+W"; onActivated: root.closeDoc(root.currentId) }
    Key { sequence: "Ctrl+Q"; onActivated: root.quit() }
    Key { sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]; onActivated: root.pane?.redo() }
    Key { sequence: "Ctrl+F"; onActivated: root.openFind(false) }
    Key { sequence: "Ctrl+H"; onActivated: root.openFind(true) }
    Key { sequence: "Ctrl+G"; onActivated: root.pane?.nextMatch(1) }
    Key { sequence: "Ctrl+Shift+G"; onActivated: root.pane?.nextMatch(-1) }
    Key {
        sequence: "Ctrl+I"
        onActivated: {
            root.goToShown = true;
            goToInput.text = "";
            goToInput.forceActiveFocus();
        }
    }
    Key { sequences: ["Ctrl++", "Ctrl+="]; onActivated: root.setPref("fontSize", Math.min(40, root.prefs.fontSize + 1)) }
    Key { sequence: "Ctrl+-"; onActivated: root.setPref("fontSize", Math.max(8, root.prefs.fontSize - 1)) }
    Key { sequence: "Ctrl+0"; onActivated: root.setPref("fontSize", 14) }
    Key {
        sequence: "Ctrl+Tab"
        onActivated: root.currentId = docs.get((root.tabIndex(root.currentId) + 1) % docs.count).docId
    }
    Key {
        sequence: "Ctrl+Shift+Tab"
        onActivated: root.currentId = docs.get((root.tabIndex(root.currentId) - 1 + docs.count) % docs.count).docId
    }
    Key { sequence: "F11"; onActivated: root.toggleFullscreen() }
    Key { sequence: "Alt+W"; onActivated: root.setPref("wrap", !root.prefs.wrap) }
    Key {
        sequence: "Esc"
        onActivated: {
            if (root.fontPickerShown) {
                root.closeFontPicker();
            } else if (root.dialogName !== "") {
                root.dialogName = "";
                root.focusEditor();
            } else if (root.panel !== "") root.panel = "";
            else if (root.findShown) root.closeFind();
            else if (root.fullscreen) root.toggleFullscreen();
        }
    }
}
