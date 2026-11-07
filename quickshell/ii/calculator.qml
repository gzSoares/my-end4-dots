//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// calculator.qml — a calculator in the shell's own look.
//
// The math is done by qalc, the engine behind the launcher's "=", so it also
// takes units and functions: "10 km to mi", "sin(30 deg)", "15% of 80".
//
// Open it with calculator/mainstream-calculator
// Needs: libqalculate.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

TranslucentAppWindow {
    id: root
    visible: true
    width: 340
    // Room for the scientific rows too: the compositor keeps the size of a
    // floating window, so it cannot grow when they appear.
    height: 620
    minimumWidth: 300
    minimumHeight: 560
    // Fixed, not translated: window rules can match on it
    title: "Calculator"

    property string preview: ""
    property bool previewValid: false
    property bool scientific: false
    property bool historyShown: false
    property bool formatting: false
    property string lastText: ""
    property var history: []
    // Waiting for the result of "=", to move it into the entry when it arrives.
    property bool committing: false
    property string committed: ""

    // The field shows numbers the Brazilian way, 1.234.567,89, and qalc reads them
    // plainly. A dot is only ever a thousands mark here and a comma the decimal
    // mark, so function arguments are separated with ";".
    function normalized(text) {
        const plain = text.replace(/\./g, "").replace(/,/g, ".");
        // "15% of 80" reads as a remainder to qalc, "15% * 80" as a percentage.
        return plain.replace(/%\s*(of|de)\s+/gi, "% * ").trim();
    }
    function grouped(digits) {
        return digits.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
    }
    // What qalc answers, for showing. Past 40 digits a number stops being readable,
    // so it goes back to a power of ten.
    function display(answer) {
        return answer.replace(/(\d+)(?:\.(\d+))?/g, (all, whole, decimals) => {
            if (whole.length > 40) return whole[0] + "," + whole.slice(1, 8) + "E" + (whole.length - 1);
            return root.grouped(whole) + (decimals ? "," + decimals : "");
        });
    }
    // Keeps the field in that format as it is typed in, the cursor staying put
    // relative to what follows it.
    function reformat() {
        if (root.formatting) return;
        const before = entry.text;
        // Typing a dot is caught as it happens, so a dot already here is a thousands
        // mark, however many digits now follow it. Only text arriving all at once
        // can hold a decimal dot, and there the groups tell them apart.
        const pasted = before.length - root.lastText.length > 1;
        const plain = pasted
            ? before.replace(/\d{1,3}(?:\.\d{3})+(?!\d)/g, group => group.replace(/\./g, "")).replace(/\./g, ",")
            : before.replace(/\./g, "");
        const after = plain.replace(/(,\d*)|(\d+)/g, (all, decimals, whole) => decimals ? all : root.grouped(whole));
        root.lastText = after;
        if (after === before) return;
        const tail = before.slice(entry.cursorPosition).replace(/\./g, "").length;
        root.formatting = true;
        entry.text = after;
        let position = after.length;
        for (let left = tail; left > 0 && position > 0; position--)
            if (after[position - 1] !== ".") left--;
        entry.cursorPosition = position;
        root.formatting = false;
    }
    // Loose letters are not a sum, though qalc reads them as units: "abc" comes
    // back in cubic picometres. It takes a number or a known constant.
    function hasValue(text) {
        return /\d/.test(text) || /\b(pi|tau|phi|e)\b/i.test(text);
    }
    function evaluate() {
        const text = root.normalized(entry.text);
        if (text === "" || !root.hasValue(text)) {
            root.preview = root.committing && text ? Translation.tr("Could not calculate this") : "";
            root.committing = false;
            root.previewValid = false;
            return;
        }
        calcProc.running = false;
        calcProc.command = ["qalc", "-t", "-s", "exp 0", "-s", "max decimals 10", "-s", "precision 40", "--", text];
        calcProc.running = true;
    }
    function commit() {
        const text = root.normalized(entry.text);
        if (text === "") return;
        root.committed = text;
        root.committing = true;
        root.evaluate();
    }
    function insert(text) {
        entry.insert(entry.cursorPosition, text);
        entry.forceActiveFocus();
    }
    function press(key) {
        switch (key) {
        case "C":
            entry.text = "";
            break;
        case "⌫":
            if (entry.cursorPosition > 0) entry.remove(entry.cursorPosition - 1, entry.cursorPosition);
            break;
        case "=":
            root.commit();
            break;
        case ".":
            root.insert(",");
            break;
        default:
            root.insert(key);
        }
        entry.forceActiveFocus();
    }

    Component.onCompleted: {
        // Started on its own, so it has to ask for the shell's colors itself.
        Quickshell.watchFiles = false;
        MaterialThemeLoader.reapplyTheme();
        entry.forceActiveFocus();
    }
    onClosing: Qt.quit()

    IpcHandler {
        target: "calculator"
        function calculate(text: string): void {
            entry.text = text;
            root.commit();
        }
        function key(name: string): void {
            root.press(name);
        }
        function scientificMode(on: bool): void {
            root.scientific = on;
        }
        function historyMode(on: bool): void {
            root.historyShown = on;
        }
        function value(): string {
            return entry.text + " | " + root.preview;
        }
    }

    Process {
        id: calcProc
        stdout: StdioCollector {
            onStreamFinished: {
                const answer = this.text.trim();
                // qalc hands an expression it could not reduce back, and prints
                // what it could not parse as an error.
                const unchanged = answer.replace(/\s/g, "") === root.normalized(entry.text).replace(/\s/g, "");
                const valid = answer !== "" && !answer.startsWith("error") && !answer.includes("error:")
                    && !/\/\s*0\b/.test(answer) && !answer.includes("()");
                // A bare number needs no "= itself" under it.
                root.preview = valid && !unchanged ? root.display(answer) : "";
                root.previewValid = valid;
                if (root.committing) {
                    root.committing = false;
                    if (valid) {
                        if (!unchanged) {
                            root.history = [{ expression: entry.text, result: root.display(answer) }].concat(root.history).slice(0, 50);
                            entry.text = root.display(answer);
                        }
                        root.preview = "";
                    } else {
                        root.preview = Translation.tr("Could not calculate this");
                    }
                }
            }
        }
    }

    Timer {
        id: previewTimer
        interval: 120
        onTriggered: root.evaluate()
    }

    component CalcKey: RippleButton {
        id: calcKey
        property string label
        property string insertText: calcKey.label
        property string symbol: ""
        property color fill: Appearance.colors.colLayer1
        property color fillHover: Appearance.colors.colLayer1Hover
        property color ink: Appearance.colors.colOnLayer0
        property real labelSize: Appearance.font.pixelSize.larger
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: keyHeight
        property real keyHeight: 48
        // The keyboard stays in the entry, so typing and clicking can mix.
        focusPolicy: Qt.NoFocus
        buttonRadius: Appearance.rounding.normal
        colBackground: fill
        colBackgroundHover: fillHover
        onClicked: root.press(calcKey.insertText)
        contentItem: Item {
            StyledText {
                anchors.centerIn: parent
                visible: calcKey.symbol === ""
                text: calcKey.label
                font.pixelSize: calcKey.labelSize
                color: calcKey.ink
            }
            MaterialSymbol {
                anchors.centerIn: parent
                visible: calcKey.symbol !== ""
                text: calcKey.symbol
                iconSize: Appearance.font.pixelSize.larger
                color: calcKey.ink
            }
        }
    }
    component OperatorKey: CalcKey {
        fill: Appearance.colors.colSecondaryContainer
        fillHover: Appearance.colors.colSecondaryContainerHover
        ink: Appearance.colors.colOnSecondaryContainer
        // These glyphs are drawn smaller than a digit at the same size.
        labelSize: Appearance.font.pixelSize.hugeass + 3
    }
    component FunctionKey: CalcKey {
        keyHeight: 36
        labelSize: Appearance.font.pixelSize.small
        ink: Appearance.colors.colSubtext
    }
    component HeaderButton: RippleButton {
        id: headerButton
        property string symbol
        property string tip
        implicitWidth: 36
        implicitHeight: 36
        focusPolicy: Qt.NoFocus
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colBackgroundToggled: Appearance.colors.colSecondaryContainer
        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: headerButton.symbol
            iconSize: 20
            fill: headerButton.toggled ? 1 : 0
            color: headerButton.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
        }
        StyledToolTip { text: headerButton.tip }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: 12
        }
        spacing: 6

        RowLayout {
            spacing: 2
            Item { Layout.fillWidth: true }
            HeaderButton {
                symbol: "history"
                tip: Translation.tr("History")
                toggled: root.historyShown
                onClicked: root.historyShown = !root.historyShown
            }
            HeaderButton {
                symbol: "function"
                tip: Translation.tr("Scientific")
                toggled: root.scientific
                onClicked: root.scientific = !root.scientific
            }
        }

        // Display: takes all the height the keys leave, as wide as they are
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.bottomMargin: 4
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            ColumnLayout {
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 14
                    rightMargin: 14
                }
                spacing: 6

                StyledTextInput {
                    id: entry
                    Layout.fillWidth: true
                    horizontalAlignment: TextInput.AlignRight
                    clip: true
                    color: Appearance.colors.colOnLayer0
                    // Sized to fit the whole number, as far as that stays readable.
                    font.family: Appearance.font.family.numbers
                    font.pixelSize: Math.round(Math.max(15, Math.min(52, entry.width / (Math.max(1, entry.length) * 0.58))))
                    font.weight: Font.Light
                    onTextChanged: {
                        root.reformat();
                        previewTimer.restart();
                    }
                    onAccepted: root.commit()
                    Keys.onEscapePressed: {
                        if (root.historyShown) root.historyShown = false;
                        else text = "";
                    }
                    Keys.onPressed: event => {
                        if (event.text === ".") {
                            root.insert(",");
                            event.accepted = true;
                        }
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    text: !root.preview ? " " : root.previewValid ? "= " + root.preview : root.preview
                    color: root.previewValid ? Appearance.colors.colSubtext : Appearance.m3colors.m3error
                    font.pixelSize: Appearance.font.pixelSize.large
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: keys.implicitHeight

            GridLayout {
                id: keys
                anchors {
                    left: parent.left
                    right: parent.right
                }
                visible: !root.historyShown
                columns: 4
                rowSpacing: 5
                columnSpacing: 5

                FunctionKey { visible: root.scientific; label: "sin"; insertText: "sin(" }
                FunctionKey { visible: root.scientific; label: "cos"; insertText: "cos(" }
                FunctionKey { visible: root.scientific; label: "tan"; insertText: "tan(" }
                FunctionKey { visible: root.scientific; label: "π"; insertText: "pi" }
                FunctionKey { visible: root.scientific; label: "ln"; insertText: "ln(" }
                FunctionKey { visible: root.scientific; label: "log"; insertText: "log10(" }
                FunctionKey { visible: root.scientific; label: "√"; insertText: "sqrt(" }
                FunctionKey { visible: root.scientific; label: "xʸ"; insertText: "^" }
                FunctionKey { visible: root.scientific; label: "(" }
                FunctionKey { visible: root.scientific; label: ")" }
                FunctionKey { visible: root.scientific; label: "e" }
                FunctionKey { visible: root.scientific; label: "!" }

                OperatorKey {
                    label: "C"
                    labelSize: Appearance.font.pixelSize.larger
                    fill: ColorUtils.mix(Appearance.colors.colErrorContainer, Appearance.colors.colSecondaryContainer, 0.35)
                    fillHover: ColorUtils.mix(Appearance.colors.colErrorContainer, Appearance.colors.colSecondaryContainer, 0.5)
                    ink: Appearance.m3colors.m3onErrorContainer
                }
                OperatorKey { insertText: "⌫"; symbol: "backspace" }
                OperatorKey { label: "%"; labelSize: Appearance.font.pixelSize.larger }
                OperatorKey { label: "÷"; insertText: "/" }

                CalcKey { label: "7" }
                CalcKey { label: "8" }
                CalcKey { label: "9" }
                OperatorKey { label: "×"; insertText: "*" }

                CalcKey { label: "4" }
                CalcKey { label: "5" }
                CalcKey { label: "6" }
                OperatorKey { label: "−"; insertText: "-" }

                CalcKey { label: "1" }
                CalcKey { label: "2" }
                CalcKey { label: "3" }
                OperatorKey { label: "+" }

                CalcKey {
                    Layout.columnSpan: 2
                    Layout.preferredWidth: 2
                    label: "0"
                }
                CalcKey { label: "," }
                CalcKey {
                    label: "="
                    fill: Appearance.colors.colPrimary
                    fillHover: Appearance.colors.colPrimaryHover
                    ink: Appearance.m3colors.m3onPrimary
                }
            }

            // History takes the keys' place
            ListView {
                id: historyList
                anchors.fill: parent
                visible: root.historyShown
                clip: true
                spacing: 2
                model: root.history
                delegate: RippleButton {
                    id: historyRow
                    required property var modelData
                    width: historyList.width
                    implicitHeight: 58
                    focusPolicy: Qt.NoFocus
                    buttonRadius: Appearance.rounding.normal
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: {
                        entry.text = historyRow.modelData.result;
                        root.historyShown = false;
                    }
                    contentItem: ColumnLayout {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 12
                            rightMargin: 12
                        }
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                            text: historyRow.modelData.expression
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                            text: "= " + historyRow.modelData.result
                            font.pixelSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnLayer0
                        }
                    }
                }
                StyledText {
                    anchors.centerIn: parent
                    visible: root.history.length === 0
                    text: Translation.tr("No calculations yet")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
