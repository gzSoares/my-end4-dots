pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services

// The left sidebar's tabs, in the order its tab strip shows them. The
// sidebar, its bar button and the bar's slot for that button all read this,
// so they cannot disagree about whether there is anything to open. A new tab
// is an entry here and a page for its id in SidebarLeftContent.
Singleton {
    id: root

    readonly property var definitions: [
        { id: "ai", icon: "neurology", name: Translation.tr("AI Assistant"), enabled: Config.options.policies.ai !== 0 },
        { id: "calendarTodo", icon: "calendar_month", name: Translation.tr("Calendar / ToDo"), enabled: Config.options.sidebar.calendarTodo?.enable ?? false },
        { id: "phone", icon: "smartphone", name: Translation.tr("Phone"), enabled: Config.options.policies.phone !== 0 },
        { id: "discord", icon: "headset_mic", name: Translation.tr("Chat"), enabled: Config.options.sidebar.discord?.enable ?? false },
        { id: "media", icon: "music_note", name: Translation.tr("Media"), enabled: Config.options.sidebar.media.enable },
        { id: "translator", icon: "translate", name: Translation.tr("Translator"), enabled: Config.options.sidebar.translator.enable },
        { id: "anime", icon: "bookmark_heart", name: Translation.tr("Anime"), enabled: Config.options.policies.weeb !== 0 }
    ]

    // Kept in the closet, the anime page is there to be swiped to but has no
    // button of its own.
    readonly property bool animeCloset: Config.options.policies.weeb === 2

    // The order the user dragged the tabs into (Config sidebar.tabOrder); a
    // tab that is not in it keeps its stock place after the ones that are.
    readonly property var tabs: {
        const order = Config.options.sidebar.tabOrder ?? [];
        const rank = id => { const at = order.indexOf(id); return at === -1 ? order.length : at; };
        return root.definitions
            .map((tab, i) => ({ tab: tab, i: i }))
            .filter(e => e.tab.enabled && !(e.tab.id === "anime" && root.animeCloset))
            .sort((a, b) => (rank(a.tab.id) - rank(b.tab.id)) || (a.i - b.i))
            .map(e => e.tab);
    }

    // Puts the tab with this id at this place among the tabs on show.
    function moveTab(id, toIndex) {
        const ids = root.tabs.map(tab => tab.id);
        const from = ids.indexOf(id);
        if (from === -1 || from === toIndex) return;
        ids.splice(from, 1);
        ids.splice(Math.max(0, Math.min(toIndex, ids.length)), 0, id);
        // Keeps the place of tabs that are switched off right now, after these
        const rest = (Config.options.sidebar.tabOrder ?? []).filter(x => ids.indexOf(x) === -1);
        Config.options.sidebar.tabOrder = [...ids, ...rest];
    }

    // Pages in swipe order: one per tab, a placeholder when there are no
    // tabs at all, and last the closeted anime page.
    readonly property list<string> pageIds: [
        ...root.tabs.map(tab => tab.id),
        ...(root.tabs.length === 0 ? ["placeholder"] : []),
        ...(root.animeCloset ? ["anime"] : [])
    ]

    readonly property bool hasPages: root.definitions.some(tab => tab.enabled)

    // The bar button's stock icon is the logo of the AI model picked in the
    // sidebar, so with AI off it has nothing to show and stays off the bar. A
    // distro or custom icon still shows whenever there is a page to open.
    readonly property bool buttonShown: root.hasPages
        && (Config.options.bar.topLeftIcon !== "spark" || root.tabs.some(tab => tab.id === "ai"))
}
