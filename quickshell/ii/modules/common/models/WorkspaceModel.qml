import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.modules.common as C

NestableObject {
    id: root

    required property HyprlandMonitor monitor
    readonly property var liveMonitorData: HyprlandData.monitors.find(m => m.id === monitor?.id)
    property int workspaceIndexInGroup: wsModel.activeIndexInPage
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
      readonly property int activeWorkspace: liveMonitorData?.activeWorkspace?.id ?? monitor?.activeWorkspace?.id ?? 1
    // Workspace ativo vazio = "fake". Agora é checado pelas janelas do próprio
    // workspace (antes usava a janela ativa global, que errava no outro monitor).
    readonly property bool currentWorkspaceNotFake: !!HyprlandData.biggestWindowForWorkspace(activeWorkspace)
    readonly property int fakeWorkspace: currentWorkspaceNotFake ? -9999 : activeWorkspace
    readonly property int shownCount: C.Config.options.bar.workspaces.shown
    readonly property var specialWorkspace: liveMonitorData?.specialWorkspace
    readonly property string specialWorkspaceName: specialWorkspace?.name.replace("special:", "") ?? "special"
    readonly property bool specialWorkspaceActive: specialWorkspaceName !== ""

    // ---- Workspaces deste monitor ---------------------------------------
    // IDs (crescentes) dos workspaces normais que pertencem a ESTE monitor.
    // Ignora especiais (id < 0) e o temporário da lock screen (id enorme).
    readonly property var monitorWorkspaceIds: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.id < 100000 && w.monitor?.id === root.monitor?.id)
        .map(w => w.id)
        .sort((a, b) => a - b)

    // Posição do workspace ativo na lista do monitor, e página (grupo) dela.
    readonly property int activeIndex: Math.max(0, monitorWorkspaceIds.indexOf(activeWorkspace))
    readonly property int group: Math.floor(activeIndex / shownCount)
    readonly property int pageStart: group * shownCount
    // Posição do workspace ativo dentro da página exibida (0..shownCount-1).
    readonly property int activeIndexInPage: activeIndex % shownCount

    // ID real de cada slot da página (-1 = slot vazio, monitor com poucos workspaces).
    readonly property var workspaceIds: Array.from({
        length: shownCount
    }, (_, i) => monitorWorkspaceIds[pageStart + i] ?? -1)

    readonly property var occupied: workspaceIds.map(id => id > 0)
    readonly property var biggestWindow: workspaceIds.map(id => id > 0 ? HyprlandData.biggestWindowForWorkspace(id) : null)

    function getWorkspaceId(group, index) {
        return root.monitorWorkspaceIds[group * root.shownCount + index] ?? -1;
    }
    // ID real do workspace no slot `index` da página (-1 se vazio).
    function getWorkspaceIdAt(index) {
        return root.workspaceIds[index] ?? -1;
    }
    // Número mostrado no slot: sequencial por monitor (1, 2, 3...).
    function getLabelAt(index) {
        return root.pageStart + index + 1;
    }
}