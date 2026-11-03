import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick

// Thumbnail used by both the cards and the ambient backdrop.
// The size bucket comes from sizeWidth/sizeHeight (the nominal card size), not
// from the item's own size, so it always matches what the bulk generator in
// WallpaperSelectorContent wrote, even when the item is scaled or blurred.
ThumbnailImage {
    id: thumb

    property real sizeWidth: width
    property real sizeHeight: height

    generateThumbnail: false
    thumbnailSizeName: Images.thumbnailSizeNameForDimensions(thumb.sizeWidth, thumb.sizeHeight)
    cache: false
    fillMode: Image.PreserveAspectCrop
    clip: true

    Connections {
        target: Wallpapers
        function onThumbnailGenerated(directory) {
            if (thumb.status !== Image.Error) return;
            if (FileUtils.parentDirectory(thumb.sourcePath) !== FileUtils.trimFileProtocol(directory)) return;
            thumb.source = "";
            thumb.source = thumb.thumbnailPath;
        }
        function onThumbnailGeneratedFile(filePath) {
            if (thumb.status !== Image.Error) return;
            if (Qt.resolvedUrl(thumb.sourcePath) !== Qt.resolvedUrl(filePath)) return;
            thumb.source = "";
            thumb.source = thumb.thumbnailPath;
        }
    }
}
