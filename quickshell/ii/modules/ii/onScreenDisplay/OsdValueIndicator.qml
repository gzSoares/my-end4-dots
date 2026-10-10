import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root
    required property real value
    required property string icon
    required property string name
    property bool rotateIcon: false
    property bool scaleIcon: false
    property alias from: valueProgressBar.from
    property alias to: valueProgressBar.to

    property real valueIndicatorVerticalPadding: 9
    property real valueIndicatorLeftPadding: 10
    property real valueIndicatorRightPadding: 20 // An icon is circle ish, a column isn't, hence the extra padding

    implicitWidth: Appearance.sizes.osdWidth + 2 * Appearance.sizes.elevationMargin
    implicitHeight: valueIndicator.implicitHeight + 2 * Appearance.sizes.elevationMargin

    StyledRectangularShadow {
        target: valueIndicator
    }
    Rectangle {
        id: valueIndicator
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.rounding.full
        color: Appearance.colors.colLayer0

        implicitWidth: valueRow.implicitWidth
        implicitHeight: valueRow.implicitHeight

        RowLayout { // Icon on the left, stuff on the right
            id: valueRow
            Layout.margins: 10
            anchors.fill: parent
            spacing: 10

            Item {
                implicitWidth: 30
                implicitHeight: 30
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: valueIndicatorLeftPadding
                Layout.topMargin: valueIndicatorVerticalPadding
                Layout.bottomMargin: valueIndicatorVerticalPadding

                MaterialSymbol { // Icon
                    anchors {
                        centerIn: parent
                        alignWhenCentered: !root.rotateIcon
                    }
                    color: Appearance.colors.colOnLayer0
                    // Distance field whatever the screen does, and not the pin
                    // MaterialSymbol carries. This icon is rotated through 180
                    // degrees and scaled while it animates, and a hinted glyph
                    // under a transform is pixelated at any scale.
                    renderType: Text.QtRendering

                    text: root.icon
                    iconSize: 20 + 10 * (root.scaleIcon ? value : 1)
                    rotation: 180 * (root.rotateIcon ? value : 0)

                    Behavior on iconSize {
                        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                    }
                    Behavior on rotation {
                        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                    }
                
                }
            }
            ColumnLayout { // Stuff
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: valueIndicatorRightPadding
                spacing: 5

                RowLayout { // Name fill left, value on the right end
                    Layout.leftMargin: valueProgressBar.height / 2 // Align text with progressbar radius curve's left end
                    Layout.rightMargin: valueProgressBar.height / 2 // Align text with progressbar radius curve's left end

                    StyledText {
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.small
                        Layout.fillWidth: true
                        text: root.name
                    }

                    StyledText {
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.small
                        Layout.fillWidth: false
                        text: Math.round(root.value * 100)
                    }
                }
                
                StyledProgressBar {
                    id: valueProgressBar
                    Layout.fillWidth: true
                    value: root.value
                    
                    // Mouse drag to control volume
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        drag.target: undefined
                        property real dragStartX: 0
                        property real dragStartValue: 0
                        onPressed: (mouse) => {
                            dragStartX = mouse.x;
                            dragStartValue = root.value;
                            // Keep OSD open while dragging
                            if (root.currentIndicator === "volume") {
                                osdTimeout.stop();
                            }
                        }
                        onMouseXChanged: (mouse) => {
                            if (mouse.pressed && root.currentIndicator === "volume" && Audio.ready) {
                                const width = valueProgressBar.width;
                                const deltaX = mouse.x - dragStartX;
                                const deltaValue = deltaX / width;
                                const newValue = Math.max(0, Math.min(1, dragStartValue + deltaValue));
                                Audio.sink.audio.volume = newValue;
                                root.value = newValue; // update progress bar visually
                                root.triggerOsd(); // restart timeout
                            }
                        }
                        onReleased: {
                            if (root.currentIndicator === "volume") {
                                osdTimeout.restart();
                            }
                        }
                        // Wheel also works
                        onWheel: (wheel) => {
                            if (root.currentIndicator === "volume" && Audio.ready) {
                                const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                const newValue = Math.max(0, Math.min(1, root.value + delta));
                                Audio.sink.audio.volume = newValue;
                                root.value = newValue;
                                root.triggerOsd();
                            }
                        }
                    }
                }
            }
        }
    }
}
