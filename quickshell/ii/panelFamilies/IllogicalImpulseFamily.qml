import QtQuick
import Quickshell

import qs.modules.common
import qs.modules.ii.background
import qs.modules.ii.bar
import qs.modules.ii.cheatsheet
import qs.modules.ii.desktopMenu
import qs.modules.ii.dock
import qs.modules.ii.lock
import qs.modules.ii.mediaControls
import qs.modules.ii.notificationPopup
import qs.modules.ii.onScreenDisplay
import qs.modules.ii.onScreenKeyboard
import qs.modules.ii.overview
import qs.modules.ii.polkit
import qs.modules.ii.regionSelector
import qs.modules.ii.screenCorners
import qs.modules.ii.screenTranslator
import qs.modules.ii.sessionScreen
import qs.modules.ii.sidebarLeft
import qs.modules.ii.sidebarRight
import qs.modules.ii.overlay
import qs.modules.ii.verticalBar
import qs.modules.ii.wallpaperSelector
import qs.modules.sysmonitor
import qs.modules.audiomixer
import qs.modules.containers
import qs.modules.agenda
import qs.modules.smarthome
import qs.modules.remote

Scope {
    PanelLoader { extraCondition: !Config.options.bar.vertical; component: Bar {} }
    // After Bar so most compositors stack the ripple above the bar within
    // the Overlay layer (creation-order tiebreak). Loads regardless of
    // bar orientation since HotCornerRipple anchors itself to the screen's
    // top-left and works without a horizontal bar present.
    PanelLoader { component: HotCornerRipple {} }
    PanelLoader { component: Background {} }
    PanelLoader { component: Cheatsheet {} }
    PanelLoader { component: DesktopMenu {} }
    PanelLoader { extraCondition: Config.options.dock.enable; component: Dock {} }
    PanelLoader { component: Lock {} }
    PanelLoader { component: MediaControls {} }
    PanelLoader { component: NotificationPopup {} }
    PanelLoader { component: OnScreenDisplay {} }
    PanelLoader { component: OnScreenKeyboard {} }
    PanelLoader { component: Overlay {} }
    PanelLoader { component: Overview {} }
    PanelLoader { component: OverviewDim {} }
    PanelLoader { component: Polkit {} }
    PanelLoader { component: RegionSelector {} }
    PanelLoader { component: ScreenCorners {} }
    PanelLoader { component: ScreenTranslator {} }
    PanelLoader { component: SessionScreen {} }
    PanelLoader { component: SidebarLeft {} }
    PanelLoader { component: SidebarRight {} }
    PanelLoader { extraCondition: Config.options.bar.vertical; component: VerticalBar {} }
    PanelLoader { component: WallpaperSelector {} }

    // Spotlight is ~8k lines. Referencing it as a type here would compile it
    // with this file, before the bar can appear. Loading by URL once the panels
    // are up takes it off that path. It must still load on its own (not on first
    // open): its IPC targets, including todoReminder, live inside it.
    LazyLoader {
        id: spotlightLoader
        source: Qt.resolvedUrl("../modules/spotlight/Spotlight.qml")
    }
    Timer {
        interval: 1000
        running: Config.ready
        onTriggered: spotlightLoader.activeAsync = true
    }

    SysMonitor {}
    AudioMixer {}
    ContainersApp {}
    AgendaApp {}
    SmartHomeApp {}
    RemoteApp {}
}