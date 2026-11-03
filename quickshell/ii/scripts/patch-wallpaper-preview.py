#!/usr/bin/env python3
"""Patches Background.qml and GlobalStates.qml for the wallpaper picker's live preview
(version 3: the new picture and its geometry change in the same frame, and the
crossfade waits for the GPU upload so it does not jerk at its start).

Usage: python3 patch-wallpaper-preview.py [quickshell ii dir]
Default dir: ~/.config/quickshell/ii

It starts from a Background.qml in any of these states: the original, the first version
of this patch, or an older hand-made preview (previewPath / effectiveWallpaperPath).
Every anchor is checked before anything is written; if one is missing (your copy
differs from what is expected), nothing is changed. Backups go to *.bak.
"""
import os, sys, shutil

root = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/.config/quickshell/ii")
bg_path = os.path.join(root, "modules/ii/background/Background.qml")
gs_path = os.path.join(root, "GlobalStates.qml")

def read(p): return open(p).read()
def fail(msg):
    print(msg)
    print("Nothing was changed. Send me your Background.qml (and GlobalStates.qml) and I will adapt the patch.")
    sys.exit(1)

V3 = "swapWarmup"                  # this version
V2 = "pendingWallpaperWidth"       # version 2
V1 = "displayedWallpaperPath"      # first version of this patch (this one is also in V2)
OLD = "effectiveWallpaperPath"     # hand-made preview that was in some copies

bg_cur, gs_cur = read(bg_path), read(gs_path)
if V3 in bg_cur:
    print("Already patched (version 3), nothing to do.")
    sys.exit(0)

# Version 3 on top of version 2
bg_edits_v3 = [
# the effect starts once the textures have been uploaded
("""            wallpaperSwapPending = false;
            swapEffect = TransitionEffects.resolve(Config.options.background.wallpaperTransition);
            swapAnimation.restart();""",
"""            wallpaperSwapPending = false;
            swapEffect = TransitionEffects.resolve(Config.options.background.wallpaperTransition);
            // Both pictures are decoded, but a texture only goes to the GPU on the first
            // frames that draw it. Starting the effect right away puts that stall inside the
            // first frames of the fade, where it shows as a jerk. Waiting a moment lets it
            // happen while the old picture still covers the screen.
            swapWarmup.restart();"""),
("""        property string swapEffect: "fade"
""",
"""        property string swapEffect: "fade"
        Timer {
            id: swapWarmup
            interval: 120
            onTriggered: {
                // A newer change took over, or this one was cancelled meanwhile
                if (bgRoot.wallpaperSwapPending || outgoing.status !== Image.Ready) return;
                swapAnimation.restart();
            }
        }
"""),
# the outgoing picture is drawn at about 1:1 and only for the length of the fade
("""                    id: outgoing
                    asynchronous: true
                    cache: false
                    smooth: true
                    mipmap: true""",
"""                    id: outgoing
                    asynchronous: true
                    cache: false
                    smooth: true
                    // Shown about 1:1 and only for the length of the fade, so the mip chain
                    // is not worth the extra upload time.
                    mipmap: false"""),
]

def check_edits(text, edits, name):
    missing = [e[0].strip().splitlines()[0][:90] for e in edits if text.count(e[0]) != 1]
    if missing:
        print(f"{name}: anchor not found (or not unique):")
        for m in missing: print("   ", m)
    return not missing

if V2 in bg_cur:
    if not check_edits(bg_cur, bg_edits_v3, "Background.qml"):
        fail("Background.qml has version 2 of the patch, but the places for version 3 were not found.")
    new = bg_cur
    for old, repl in bg_edits_v3: new = new.replace(old, repl)
    shutil.copy(bg_path, bg_path + ".bak")
    open(bg_path, "w").write(new)
    print("Patched (version 3, on top of version 2). Backup: Background.qml.bak")
    sys.exit(0)

V1_UNDO = [
("""        property string wallpaperPath: bgRoot.monitorPicture ? bgRoot.monitorPicture.path
            : (GlobalStates.wallpaperPreviewPath !== "" ? GlobalStates.wallpaperPreviewPath
            : (bgRoot.mainWallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath))

        // The picture handed to the Image. It follows wallpaperPath only once that
        // picture has been measured, so the path and the size it is decoded at change
        // together: one decode instead of a first one at the old size and a second
        // one, mid-transition, at the new size.
        property string displayedWallpaperPath: ""

        // The picker's preview is a value in memory; once the config holds that same
        // wallpaper (or any other, after the picker closed) it is not needed anymore.
        Connections {
            target: Config.options.background
            function onWallpaperPathChanged() {
                if (GlobalStates.wallpaperPreviewPath !== "" && !GlobalStates.wallpaperSelectorOpen)
                    GlobalStates.wallpaperPreviewPath = "";
            }
        }""",
"""        property string wallpaperPath: bgRoot.monitorPicture ? bgRoot.monitorPicture.path
            : (bgRoot.mainWallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath)"""),
("""                source: bgRoot.displayedWallpaperPath || bgRoot.wallpaperPath || Quickshell.shellPath("assets/images/default_wallpaper.webp")""",
"""                source: bgRoot.wallpaperPath || Quickshell.shellPath("assets/images/default_wallpaper.webp")"""),
("""                bgRoot.displayedWallpaperPath = bgRoot.wallpaperPath;
                bgRoot.wallpaperWidth = picture.width;""",
"""                bgRoot.wallpaperWidth = picture.width;"""),
("""                bgRoot.displayedWallpaperPath = bgRoot.wallpaperPath;
                bgRoot.wallpaperWidth = measured ? width : bgRoot.modelData.width;""",
"""                bgRoot.wallpaperWidth = measured ? width : bgRoot.modelData.width;"""),
("""                            || source == bgRoot.shownWallpaper || Date.now() < GlobalStates.wallpaperPreviewUntil) {""",
"""                            || source == bgRoot.shownWallpaper) {"""),
]


# The hand-made preview: what it added -> what it replaced (nothing, except the source line).
OLD_UNDO = [
("""        // Live preview from wallpaper selector: when set, this overrides the main wallpaper
        // on the desktop while browsing. Cleared when the selector closes or confirms.
        property string previewPath: GlobalStates.wallpaperPreviewPath ?? ""
        // Use preview if available and valid, otherwise fall back to the regular wallpaper
        property string effectiveWallpaperPath: bgRoot.previewPath && bgRoot.previewPath.length > 0 ? bgRoot.previewPath : bgRoot.wallpaperPath
""", ""),
("""        // React to live preview changes from the wallpaper selector
        Binding {
            target: bgRoot
            property: "previewPath"
            value: GlobalStates.wallpaperPreviewPath ?? ""
        }
        // Use instant transition while the preview timer is active (wallpaperPreviewUntil in the future)
        Binding {
            target: bgRoot
            property: "swapEffect"
            value: (GlobalStates.wallpaperPreviewUntil > Date.now()) ? "none" : Config.options.background.wallpaperTransition
        }
""", ""),
("""            // If we have a preview path, use it for sizing
            if (bgRoot.previewPath && bgRoot.previewPath.length > 0) {
                if (getWallpaperSizeProc.running) return;
                getWallpaperSizeProc.path = bgRoot.previewPath;
                getWallpaperSizeProc.running = true;
                return;
            }
""", ""),
("""                source: bgRoot.effectiveWallpaperPath || Quickshell.shellPath("assets/images/default_wallpaper.webp")""",
"""                source: bgRoot.wallpaperPath || Quickshell.shellPath("assets/images/default_wallpaper.webp")"""),
]

def undo(text, pairs, what):
    for new, old in pairs:
        if text.count(new) != 1:
            fail(f"Background.qml carries {what}, but it differs from what this script knows and cannot be undone safely.")
        text = text.replace(new, old)
    return text

# Base for Background.qml: the original
bg_base = bg_cur
if OLD in bg_base:
    bg_base = undo(bg_base, OLD_UNDO, "an older hand-made preview")
    print("Undid the older hand-made preview.")
if V1 in bg_base:
    bak = bg_path + ".bak"
    if os.path.exists(bak) and not any(m in read(bak) for m in (V1, V2, OLD)):
        bg_base = read(bak)
    else:
        bg_base = undo(bg_base, V1_UNDO, "the first version of this patch")
        print("Undid the first version of this patch.")
if any(m in bg_base for m in (V1, V2, OLD)):
    fail("Could not bring Background.qml back to the original.")

bg_edits = [
# 1) main wallpaper follows the picker's preview; state for the measured picture
("""        property string wallpaperPath: bgRoot.monitorPicture ? bgRoot.monitorPicture.path
            : (bgRoot.mainWallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath)""",
"""        property string wallpaperPath: bgRoot.monitorPicture ? bgRoot.monitorPicture.path
            : (GlobalStates.wallpaperPreviewPath !== "" ? GlobalStates.wallpaperPreviewPath
            : (bgRoot.mainWallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath))

        // The picture handed to the Image, and its measured size. They change together,
        // so the Image decodes once. The size that positions the picture on screen
        // (wallpaperWidth/Height) follows only when the new picture is ready, so the
        // old one is never re-laid-out while the new one decodes.
        property string displayedWallpaperPath: ""
        property int pendingWallpaperWidth: 0
        property int pendingWallpaperHeight: 0
        // True for the one frame in which the geometry changes with a new picture, so
        // the position animations below do not slide it in.
        property bool snapGeometry: false

        // The picker's preview is a value in memory; once the config holds that same
        // wallpaper (or any other, after the picker closed) it is not needed anymore.
        Connections {
            target: Config.options.background
            function onWallpaperPathChanged() {
                if (GlobalStates.wallpaperPreviewPath !== "" && !GlobalStates.wallpaperSelectorOpen)
                    GlobalStates.wallpaperPreviewPath = "";
            }
        }"""),
# 2) decode size worked out from the picture that is loading
("""        property real scaledWallpaperHeight: wallpaperHeight * effectiveWallpaperScale
""",
"""        property real scaledWallpaperHeight: wallpaperHeight * effectiveWallpaperScale
        // Same figure as before for the size to decode at, but from the picture that is
        // loading (its measured size) instead of the one on screen.
        readonly property real decodeBaseWidth: pendingWallpaperWidth > 0 ? pendingWallpaperWidth : wallpaperWidth
        readonly property real decodeBaseHeight: pendingWallpaperHeight > 0 ? pendingWallpaperHeight : wallpaperHeight
        readonly property real decodeScale: (decodeBaseWidth > 0 && decodeBaseHeight > 0 && logicalScreenWidth > 0 && logicalScreenHeight > 0)
            ? Math.max(logicalScreenWidth / decodeBaseWidth, logicalScreenHeight / decodeBaseHeight) * parallaxRation
            : effectiveWallpaperScale
        readonly property real decodeWidth: Math.min(decodeBaseWidth, decodeBaseWidth * decodeScale * Math.max(1, bgRoot.monitor?.scale ?? 1))
        readonly property real decodeHeight: Math.min(decodeBaseHeight, decodeBaseHeight * decodeScale * Math.max(1, bgRoot.monitor?.scale ?? 1))
"""),
# 3) helpers
("""        // Wallpaper zoom scale
""",
"""        // A measured picture: it goes to the Image together with the size to decode it at.
        // Its place on screen is updated when it is ready (applyPendingGeometry), except
        // for the first picture or the same one measured again, which have nothing to keep.
        function commitMeasured(path, width, height) {
            const samePicture = bgRoot.displayedWallpaperPath === path;
            bgRoot.pendingWallpaperWidth = width;
            bgRoot.pendingWallpaperHeight = height;
            if (samePicture || bgRoot.shownWallpaper == "") {
                bgRoot.wallpaperWidth = width;
                bgRoot.wallpaperHeight = height;
            }
            bgRoot.displayedWallpaperPath = path;
        }

        function applyPendingGeometry() {
            if (bgRoot.pendingWallpaperWidth <= 0 || bgRoot.pendingWallpaperHeight <= 0) return;
            if (bgRoot.wallpaperWidth === bgRoot.pendingWallpaperWidth && bgRoot.wallpaperHeight === bgRoot.pendingWallpaperHeight) return;
            bgRoot.snapGeometry = true;
            bgRoot.wallpaperWidth = bgRoot.pendingWallpaperWidth;
            bgRoot.wallpaperHeight = bgRoot.pendingWallpaperHeight;
            Qt.callLater(() => bgRoot.snapGeometry = false);
        }

        // Wallpaper zoom scale
"""),
# 4) measured sizes go through commitMeasured
("""                bgRoot.wallpaperWidth = picture.width;
                bgRoot.wallpaperHeight = picture.height;
                return;""",
"""                bgRoot.commitMeasured(bgRoot.wallpaperPath, picture.width, picture.height);
                return;"""),
("""                bgRoot.wallpaperWidth = measured ? width : bgRoot.modelData.width;
                bgRoot.wallpaperHeight = measured ? height : bgRoot.modelData.height;""",
"""                bgRoot.commitMeasured(bgRoot.wallpaperPath,
                    measured ? width : bgRoot.modelData.width,
                    measured ? height : bgRoot.modelData.height);"""),
# 5) previews swap without a transition
("""                    if (bgRoot.shownWallpaper == "" || !bgRoot.pictureSettled || effect === "none" || bgRoot.wallpaperIsVideo
                            || source == bgRoot.shownWallpaper) {""",
"""                    if (bgRoot.shownWallpaper == "" || !bgRoot.pictureSettled || effect === "none" || bgRoot.wallpaperIsVideo
                            || source == bgRoot.shownWallpaper || Date.now() < GlobalStates.wallpaperPreviewUntil) {"""),
# 6) geometry follows the picture the moment it is ready
("""                    if (status === Image.Ready) {
                        bgRoot.shownWallpaper = source;
                        bgRoot.maybeStartSwap();""",
"""                    if (status === Image.Ready) {
                        bgRoot.applyPendingGeometry();
                        bgRoot.shownWallpaper = source;
                        bgRoot.maybeStartSwap();"""),
# 7) the Image takes the measured path and decodes at the pending size
("""                source: bgRoot.wallpaperPath || Quickshell.shellPath("assets/images/default_wallpaper.webp")""",
"""                source: bgRoot.displayedWallpaperPath || bgRoot.wallpaperPath || Quickshell.shellPath("assets/images/default_wallpaper.webp")"""),
("""                    width: Math.min(bgRoot.wallpaperWidth, bgRoot.scaledWallpaperWidth * Math.max(1, bgRoot.monitor?.scale ?? 1))
                    height: Math.min(bgRoot.wallpaperHeight, bgRoot.scaledWallpaperHeight * Math.max(1, bgRoot.monitor?.scale ?? 1))""",
"""                    width: bgRoot.decodeWidth
                    height: bgRoot.decodeHeight"""),
# 8) no slide-in when the geometry snaps
("""                Behavior on x {
                    NumberAnimation {
                        duration: 600""",
"""                Behavior on x {
                    enabled: !bgRoot.snapGeometry
                    NumberAnimation {
                        duration: 600"""),
("""                Behavior on y {
                    NumberAnimation {
                        duration: 600""",
"""                Behavior on y {
                    enabled: !bgRoot.snapGeometry
                    NumberAnimation {
                        duration: 600"""),
]

# GlobalStates.qml: only what is missing is added (an older preview may have part of it).
gs_parts = []
if "wallpaperPreviewPath" not in gs_cur:
    gs_parts.append("""    // Live preview from the wallpaper picker: drawn by the background layer without
    // touching the config. Cleared when the config catches up (see Background.qml),
    // on cancel, or by the timer if a confirmed pick never lands.
    property string wallpaperPreviewPath: ""
""")
if "wallpaperPreviewUntil" not in gs_cur:
    gs_parts.append("""    property double wallpaperPreviewUntil: 0 // swaps before this time (ms) skip the transition
""")
if "releaseWallpaperPreview" not in gs_cur:
    gs_parts.append("""    Timer {
        id: wallpaperPreviewSafety
        interval: 15000
        onTriggered: root.wallpaperPreviewPath = ""
    }
    function releaseWallpaperPreview() {
        wallpaperPreviewSafety.restart();
    }
""")
gs_anchor = "    property var wallpaperSelectorScreen: null\n"
gs_edits = [(gs_anchor, gs_anchor + "".join(gs_parts))] if gs_parts else []

def check(text, edits, name):
    missing = [e[0].strip().splitlines()[0][:90] for e in edits if text.count(e[0]) != 1]
    if missing:
        print(f"{name}: anchor not found (or not unique):")
        for m in missing: print("   ", m)
    return not missing

if not (check(bg_base, bg_edits, "Background.qml") & check(gs_cur, gs_edits, "GlobalStates.qml")):
    fail("The anchors above were not found.")

bg_new = bg_base
for old, new in bg_edits: bg_new = bg_new.replace(old, new)
if not check_edits(bg_new, bg_edits_v3, "Background.qml (version 3 part)"):
    fail("The places for version 3 were not found.")
for old, new in bg_edits_v3: bg_new = bg_new.replace(old, new)
gs_new = gs_cur
for old, new in gs_edits: gs_new = gs_new.replace(old, new)

# Backups hold the file as it was before this run
shutil.copy(bg_path, bg_path + ".bak")
if gs_edits: shutil.copy(gs_path, gs_path + ".bak")
open(bg_path, "w").write(bg_new)
if gs_edits: open(gs_path, "w").write(gs_new)
print("Patched (version 3). Backups: Background.qml.bak" + (", GlobalStates.qml.bak" if gs_edits else ""))
