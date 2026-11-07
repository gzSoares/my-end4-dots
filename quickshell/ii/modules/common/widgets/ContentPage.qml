import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

StyledFlickable {
    id: root
    property real baseWidth: 600
    property bool forceWidth: false
    property real bottomContentPadding: 100
    // The gap between the sections of the page. Bare sections want room around
    // them; a page of cards can ask for less.
    property real sectionSpacing: 30

    default property alias contentData: contentColumn.data

    clip: true
    contentHeight: contentColumn.implicitHeight + root.bottomContentPadding // Add some padding at the bottom
    implicitWidth: contentColumn.implicitWidth

    // Deep links can name a section: settings.qml reads QS_SETTINGS_SECTION
    // and hands the name to the loaded page. Sections are direct children of
    // the content column by construction (the contentData default alias), so
    // one level is the whole search space. Returns whether it was found.
    function scrollToSection(name) {
        for (let i = 0; i < contentColumn.children.length; i++) {
            const child = contentColumn.children[i];
            if (child.objectName === name) {
                root.contentY = Math.max(0, Math.min(child.y, root.contentHeight - root.height));
                return true;
            }
        }
        return false;
    }
    
    // Search finds an option by its label wherever it sits on the page, unlike
    // scrollToSection above, then marks it so the eye lands in the right place.
    // Hidden branches are skipped: there is nothing there to scroll to.
    function findByLabel(item, label) {
        for (let i = 0; i < item.children.length; i++) {
            const child = item.children[i];
            if (!child.visible || child === revealMark) continue;
            if (child.title === label || child.text === label) return child;
            const found = root.findByLabel(child, label);
            if (found) return found;
        }
        return null;
    }
    function revealLabel(label) {
        const target = root.findByLabel(contentColumn, label);
        if (!target) return false;
        const at = target.mapToItem(revealMark.parent, 0, 0);
        root.contentY = Math.max(0, Math.min(at.y - 24, root.contentHeight - root.height));
        revealMark.x = at.x - 6;
        revealMark.y = at.y - 4;
        revealMark.width = target.width + 12;
        revealMark.height = Math.min(target.height, 120) + 8;
        revealAnim.restart();
        return true;
    }

    Rectangle {
        id: revealMark
        z: 10
        opacity: 0
        radius: Appearance.rounding.small
        color: "transparent"
        border.width: 2
        border.color: Appearance.colors.colPrimary
        SequentialAnimation {
            id: revealAnim
            NumberAnimation { target: revealMark; property: "opacity"; to: 1; duration: 120 }
            PauseAnimation { duration: 1100 }
            NumberAnimation { target: revealMark; property: "opacity"; to: 0; duration: 500 }
        }
    }

    ColumnLayout {
        id: contentColumn
        width: root.forceWidth ? root.baseWidth : Math.max(root.baseWidth, implicitWidth)
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            margins: 20
        }
        spacing: root.sectionSpacing
    }

}
