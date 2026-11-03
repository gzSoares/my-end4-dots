import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

// A wallpaper (or folder) card. Image-first: the name only shows over a
// gradient when the card is highlighted or hovered.
MouseArea {
    id: root
    required property var fileModelData
    property bool isDirectory: fileModelData.fileIsDir

    property bool isVideo: {
        const path = fileModelData.fileName.toLowerCase();
        return path.endsWith('.mp4') || path.endsWith('.webm') ||
                path.endsWith('.mkv') || path.endsWith('.avi') ||
                path.endsWith('.mov') || path.endsWith('.m4v') ||
                path.endsWith('.ogv');
    }
    property bool useThumbnail: Images.isValidImageByName(fileModelData.fileName) || root.isVideo

    // Focused card (centered in the carousel / selected in the grid)
    property bool highlighted: false
    // This is the wallpaper in use right now
    property bool applied: false
    // Nominal size used to pick the thumbnail cache bucket (see WallpaperThumb)
    property real thumbWidth: width
    property real thumbHeight: height
    property real cornerRadius: Appearance.rounding.large
    // Fade the original image in over the thumbnail once the card has been focused for a moment
    property bool loadFullResolution: true
    // Lets the parent hold the full-resolution decode back for a moment
    property bool allowFullResolution: true

    readonly property bool emphasized: root.highlighted || root.containsMouse
    property bool wantFullResolution: false

    signal activated()

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()

    onHighlightedChanged: if (!root.highlighted) root.wantFullResolution = false
    Timer {
        interval: 220
        running: root.highlighted && !root.wantFullResolution && root.allowFullResolution
        onTriggered: root.wantFullResolution = true
    }

    Loader {
        active: root.highlighted
        anchors.fill: card
        sourceComponent: StyledRectangularShadow {
            target: card
            anchors.fill: undefined
            radius: root.cornerRadius
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: root.cornerRadius
        color: Appearance.colors.colLayer1

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: card.width
                height: card.height
                radius: root.cornerRadius
            }
        }

        Loader {
            id: thumbnailLoader
            anchors.fill: parent
            active: root.useThumbnail
            sourceComponent: WallpaperThumb {
                sourcePath: root.fileModelData.filePath
                sizeWidth: root.thumbWidth
                sizeHeight: root.thumbHeight
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
            }
        }

        // Original image, crossfaded in over the thumbnail for the focused card
        Loader {
            id: fullResolutionLoader
            anchors.fill: parent
            active: root.loadFullResolution && root.wantFullResolution && root.useThumbnail && !root.isVideo
            sourceComponent: Image {
                source: Qt.resolvedUrl(root.fileModelData.filePath)
                asynchronous: true
                cache: false
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 1280
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                }
            }
        }

        Loader {
            id: iconLoader
            anchors.fill: parent
            anchors.margins: 16
            active: !root.useThumbnail
            sourceComponent: DirectoryIcon {
                fileModelData: root.fileModelData
            }
        }

        // Name over a gradient
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: Math.min(parent.height, 64)
            opacity: (root.emphasized || root.isDirectory) ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: root.isDirectory ? "#00000000" : "#B3000000" }
            }

            StyledText {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: 10
                }
                text: root.fileModelData.fileName
                color: root.isDirectory ? Appearance.colors.colOnLayer1 : "#ffffff"
                elide: Text.ElideRight
                horizontalAlignment: root.isDirectory ? Text.AlignHCenter : Text.AlignLeft
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
            }
        }

        // "In use" badge
        Rectangle {
            visible: root.applied
            anchors {
                top: parent.top
                right: parent.right
                margins: 8
            }
            width: 26
            height: 26
            radius: 13
            color: Appearance.colors.colPrimary

            MaterialSymbol {
                anchors.centerIn: parent
                text: "check"
                iconSize: 18
                fill: 1
                color: Appearance.colors.colOnPrimary
            }
        }

        // Video badge
        Rectangle {
            visible: root.isVideo && root.useThumbnail
            anchors {
                top: parent.top
                left: parent.left
                margins: 8
            }
            width: 26
            height: 26
            radius: 13
            color: "#99000000"

            MaterialSymbol {
                anchors.centerIn: parent
                text: "play_arrow"
                iconSize: 18
                fill: 1
                color: "#ffffff"
            }
        }
    }

    // Highlight ring
    Rectangle {
        anchors.fill: card
        radius: root.cornerRadius
        color: "transparent"
        border.width: 3
        border.color: Appearance.colors.colPrimary
        opacity: root.highlighted ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
    }
}
