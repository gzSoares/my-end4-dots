pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property alias currentIndex: tabBar.currentIndex
    required property var tabButtonList
    // The width the strip may take. When every label will not fit in it the
    // tabs drop their labels and name themselves in a tooltip instead, which
    // is decided from the labels as this font and language actually draw
    // them. Below zero leaves the strip as wide as its labels need.
    property real availableWidth: -1

    // Tabs can be picked up after holding one for holdInterval and dragged
    // sideways; letting go says where it ended up through reordered(). Off
    // unless the owner asks for it.
    property bool reorderable: false
    property int holdInterval: 1000
    signal reordered(int from, int to)

    property int dragIndex: -1
    property int dragTarget: -1
    property real dragPointerX: 0
    property real dragGrabDx: 0
    property int pressIndex: -1
    property real pressX: 0
    property bool dragJustEnded: false

    function tabItems() {
        const out = [];
        const kids = contentItem.children;
        for (let i = 0; i < kids.length; i++) {
            if (kids[i].labeledWidth !== undefined) out.push(kids[i]);
        }
        return out;
    }
    function tabIndexAt(x) {
        const px = contentItem.mapFromItem(root, x, 0).x;
        const tabs = root.tabItems();
        for (let i = 0; i < tabs.length; i++) {
            if (px >= tabs[i].x && px <= tabs[i].x + tabs[i].width) return i;
        }
        return -1;
    }
    function beginDrag(index, x) {
        const tabs = root.tabItems();
        if (index < 0 || index >= tabs.length) return;
        const px = contentItem.mapFromItem(root, x, 0).x;
        root.dragGrabDx = px - tabs[index].x;
        root.dragPointerX = px;
        root.dragIndex = index;
        root.dragTarget = index;
    }
    function updateDrag(x) {
        if (root.dragIndex < 0) return;
        const tabs = root.tabItems();
        const px = contentItem.mapFromItem(root, x, 0).x;
        root.dragPointerX = px;
        const dragged = tabs[root.dragIndex];
        const center = px - root.dragGrabDx + dragged.width / 2;
        let target = 0;
        for (let i = 0; i < tabs.length; i++) {
            if (i === root.dragIndex) continue;
            if (tabs[i].x + tabs[i].width / 2 < center) target++;
        }
        root.dragTarget = target;
    }
    function endDrag() {
        if (root.dragIndex < 0) return;
        const from = root.dragIndex;
        const to = root.dragTarget;
        root.dragIndex = -1;
        root.dragTarget = -1;
        root.dragJustEnded = true;
        dragSettle.restart();
        if (from !== to) root.reordered(from, to);
    }
    Timer {
        id: dragSettle
        interval: 200
        onTriggered: root.dragJustEnded = false
    }
    Timer {
        id: holdTimer
        interval: root.holdInterval
        onTriggered: root.beginDrag(root.pressIndex, root.pressX)
    }
    readonly property real labeledWidth: {
        const tabs = contentItem.children;
        let total = 0;
        let count = 0;
        for (let i = 0; i < tabs.length; i++) {
            if (tabs[i].labeledWidth === undefined) continue;
            total += tabs[i].labeledWidth;
            count++;
        }
        return total + Math.max(0, count - 1) * contentItem.spacing;
    }
    readonly property bool compact: root.availableWidth >= 0 && root.labeledWidth > root.availableWidth

    function incrementCurrentIndex() {
        tabBar.incrementCurrentIndex();
    }
    function decrementCurrentIndex() {
        tabBar.decrementCurrentIndex();
    }
    function setCurrentIndex(index) {
        tabBar.setCurrentIndex(index);
    }

    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    implicitWidth: contentItem.implicitWidth
    implicitHeight: 40

    property Component delegate: ToolbarTabButton {
        id: tabButton
        required property int index
        required property var modelData
        current: index == root.currentIndex
        text: modelData.name
        materialSymbol: modelData.icon
        showLabel: !root.compact

        // Picked-up tab follows the pointer; the ones it passes make room.
        readonly property bool isDragged: root.dragIndex === index
        readonly property real shiftBy: {
            if (root.dragIndex < 0) return 0;
            const dragged = root.tabItems()[root.dragIndex];
            const room = (dragged?.width ?? 0) + contentItem.spacing;
            if (isDragged) return root.dragPointerX - root.dragGrabDx - tabButton.x;
            if (root.dragIndex < index && index <= root.dragTarget) return -room;
            if (root.dragTarget <= index && index < root.dragIndex) return room;
            return 0;
        }
        transform: Translate {
            x: tabButton.shiftBy
            Behavior on x {
                enabled: !tabButton.isDragged
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
        z: isDragged ? 10 : 0
        scale: isDragged ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
        // The strip's own highlight stays put while a tab is in the air, so
        // the current tab and the one held carry theirs along.
        colBackground: (root.dragIndex >= 0 && (isDragged || current))
            ? Appearance.colors.colSecondaryContainer
            : ColorUtils.transparentize(Appearance.colors.colSurfaceContainer)

        onClicked: {
            if (root.dragIndex >= 0 || root.dragJustEnded) return;
            root.setCurrentIndex(index);
        }

        StyledToolTip {
            text: tabButton.text
            extraVisibleCondition: root.compact
        }
    }

    Row {
        id: contentItem
        z: 1
        anchors.centerIn: parent
        spacing: Appearance.spacing.xs

        Repeater {
            model: root.tabButtonList
            delegate: root.delegate
        }
    }

    Rectangle {
        id: activeIndicator
        z: 0
        color: Appearance.colors.colSecondaryContainer
        opacity: root.dragIndex >= 0 ? 0 : 1
        implicitWidth: contentItem.children[root.currentIndex]?.implicitWidth ?? 0
        implicitHeight: contentItem.children[root.currentIndex]?.implicitHeight ?? 0
        radius: height / 2
        // Animation
        //
        // A TabBar with no current tab reports -1, and it passes through that
        // for an instant whenever the tabs are rebuilt or the view driving the
        // index empties. Nothing sits at that index, and an item property
        // cannot be handed nothing at all, so the indicator keeps the tab it
        // already had until a real one is there. It must not be restored when
        // the gap opens either: that is the same as dropping the indicator on
        // the left edge and letting it slide back once the tabs return. The
        // bounds below read it for the moment before it has anything, which is
        // where it starts from anyway: the first tab is laid out at zero.
        property Item targetItem: null
        Binding {
            target: activeIndicator
            property: "targetItem"
            value: contentItem.children[root.currentIndex] ?? null
            when: root.currentIndex >= 0 && root.currentIndex < contentItem.children.length
            restoreMode: Binding.RestoreNone
        }
        AnimatedTabIndexPair {
            id: leftBound
            idx1Duration: 50
            idx2Duration: 200
            index: activeIndicator.targetItem?.x ?? 0
        }
        AnimatedTabIndexPair {
            id: rightBound
            idx1Duration: 50
            idx2Duration: 200
            index: (activeIndicator.targetItem?.x ?? 0) + (activeIndicator.targetItem?.width ?? 0)
        }
        x: Math.min(leftBound.idx1, leftBound.idx2)
        width: Math.max(rightBound.idx1, rightBound.idx2) - x
    }

    MouseArea {
        anchors.fill: parent
        z: 2
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        onWheel: event => {
            if (event.angleDelta.y < 0) {
                root.incrementCurrentIndex();
            } else {
                root.decrementCurrentIndex();
            }
        }
    }

    // Sits over the tabs while they can be reordered. A button's own mouse
    // area takes the press before a handler on the strip could see it, so
    // this one takes it instead and passes a plain click on by itself. Hover
    // is not taken, so the tabs still light up and show their tooltips.
    MouseArea {
        id: reorderArea
        anchors.fill: parent
        z: 3
        enabled: root.reorderable
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        property bool moved: false
        function finish(cancelled) {
            holdTimer.stop();
            if (root.dragIndex >= 0) root.endDrag();
            else if (!cancelled && !reorderArea.moved && root.pressIndex >= 0) root.setCurrentIndex(root.pressIndex);
            root.pressIndex = -1;
        }
        onPressed: mouse => {
            reorderArea.moved = false;
            root.pressX = mouse.x;
            root.pressIndex = root.tabIndexAt(mouse.x);
            if (root.pressIndex >= 0) holdTimer.restart();
        }
        onPositionChanged: mouse => {
            if (root.dragIndex >= 0) root.updateDrag(mouse.x);
            // Moving off before the hold is up is a swipe, not a pick-up
            else if (Math.abs(mouse.x - root.pressX) > 10) {
                reorderArea.moved = true;
                holdTimer.stop();
            }
        }
        onReleased: reorderArea.finish(false)
        onCanceled: reorderArea.finish(true)
    }

    // TabBar doesn't allow tabs to be of different sizes. That's what I thought...
    // We use it only for the logic and draw stuff manually
    TabBar {
        id: tabBar
        z: -1
        background: null
        Repeater {
            // This is to fool the TabBar that it has tabs so it does the indices properly
            model: root.tabButtonList.length
            delegate: TabButton {
                background: null
            }
        }
    }
}
