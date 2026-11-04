import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * An IPv4 address entered one number per box: 1 . 1 . 1 . 1
 *
 * `value` is the dotted string ("1.1.1.1", or "" when every box is empty, or a
 * partly filled "8.8.." while someone is still typing) and `edited` carries the
 * new string. The field never writes `value` itself, so a page can bind it to
 * its config and save from `edited`.
 *
 * Typing: digits fill a box and move on by themselves once the number cannot
 * grow any more (three digits, two digits from 26 up, or a lone 0). A dot moves
 * on early, backspace in an empty box steps back, and the arrow keys cross
 * between boxes at the edges. A whole address pasted into any box is spread
 * over the boxes from that one.
 */
ColumnLayout {
    id: root
    property string label: ""
    property string value: ""
    signal edited(string value)

    spacing: 4
    Layout.fillWidth: true

    // The text of the four boxes, "" when all are empty.
    function join() {
        if (boxes.count < 4) return root.value
        const parts = []
        for (let i = 0; i < 4; i++) parts.push(boxes.itemAt(i).field.text)
        return parts.every(p => p === "") ? "" : parts.join(".")
    }

    // One number as a box shows it: digits only, at most 255, no leading zero
    // (some parsers read "010" as octal).
    function clean(raw) {
        const digits = String(raw).replace(/\D/g, "").slice(0, 3)
        return digits.length > 1 ? String(Math.min(255, parseInt(digits, 10))) : digits
    }

    function load() {
        if (boxes.count < 4) return
        const parts = String(root.value).split(".")
        for (let i = 0; i < 4; i++) boxes.itemAt(i).field.text = root.clean(parts[i] ?? "")
    }

    function focusBox(i, selectAll) {
        const f = boxes.itemAt(i).field
        f.forceActiveFocus()
        if (selectAll) f.selectAll()
        else { f.deselect(); f.cursorPosition = f.text.length }
    }

    // Text with dots, from a paste: one number per part, from box `from` on.
    function spread(from, raw) {
        const parts = String(raw).split(".")
        let used = 0
        for (; used < parts.length && from + used < 4; used++)
            boxes.itemAt(from + used).field.text = root.clean(parts[used])
        root.focusBox(Math.min(3, from + used - 1), false)
        root.edited(root.join())
    }

    function boxEdited(i) {
        const f = boxes.itemAt(i).field
        if (f.text.indexOf(".") >= 0) { root.spread(i, f.text); return }
        const t = root.clean(f.text)
        if (t !== f.text) f.text = t
        const n = parseInt(t, 10)
        const done = t.length === 3 || t === "0" || (t.length === 2 && n >= 26)
        root.edited(root.join())
        if (done && i < 3 && f.cursorPosition === t.length) root.focusBox(i + 1, true)
    }

    // A change that came from outside (a reset, a config reload) reaches the
    // boxes; one this field just reported is already what they show.
    onValueChanged: if (root.value !== root.join()) root.load()
    Component.onCompleted: root.load()

    StyledText {
        visible: root.label !== ""
        text: root.label
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
    }

    RowLayout {
        spacing: 6

        Repeater {
            id: boxes
            model: 4

            delegate: RowLayout {
                id: cell
                required property int index
                property alias field: box
                spacing: 6

                MaterialTextField {
                    id: box
                    Layout.preferredWidth: 64
                    horizontalAlignment: TextInput.AlignHCenter
                    // Room for a pasted address; a single number is cut to
                    // three digits as soon as it is typed.
                    maximumLength: 15
                    validator: RegularExpressionValidator { regularExpression: /^[0-9.]*$/ }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    selectByMouse: true
                    onTextEdited: root.boxEdited(cell.index)

                    Keys.onPressed: event => {
                        if (event.text === "." || event.text === "," || event.key === Qt.Key_Period
                                || event.key === Qt.Key_Comma || event.key === Qt.Key_Space) {
                            // A dot never lands in a box; it only says "next".
                            if (box.text.length > 0 && cell.index < 3) root.focusBox(cell.index + 1, true)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Backspace && box.text === "" && cell.index > 0) {
                            root.focusBox(cell.index - 1, false)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Left && box.cursorPosition === 0
                                && box.selectedText === "" && cell.index > 0) {
                            root.focusBox(cell.index - 1, false)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Right && box.cursorPosition === box.text.length
                                && box.selectedText === "" && cell.index < 3) {
                            root.focusBox(cell.index + 1, false)
                            event.accepted = true
                        }
                    }
                }

                StyledText {
                    visible: cell.index < 3
                    text: "."
                    font.pixelSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
