import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.modules.common as C

NestableObject {
    id: root
    onBiggestWindowChanged: console.log("ws ids:", JSON.stringify(workspaceIds), "classes:", JSON.stringify(biggestWindow.map(w => w?.class ?? null)))

    required property HyprlandMonitor monitor
    readonly property var liveMonitorData: HyprlandData.monitors.find(m => m.id === monitor?.id)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    readonly property int activeWorkspace: liveMonitorData?.activeWorkspace?.id ?? monitor?.activeWorkspace?.id ?? 1
    // Workspace ativo vazio = "fake". Checado pelas janelas do próprio workspace.
    readonly property bool currentWorkspaceNotFake: !!HyprlandData.biggestWindowForWorkspace(activeWorkspace)
    readonly property int fakeWorkspace: currentWorkspaceNotFake ? -9999 : activeWorkspace
    readonly property var specialWorkspace: liveMonitorData?.specialWorkspace
    readonly property string specialWorkspaceName: specialWorkspace?.name.replace("special:", "") ?? "special"
    readonly property bool specialWorkspaceActive: specialWorkspaceName !== ""

    // NOVO: máximo de slots por página (vem da config). Antes era o shownCount fixo.
    readonly property int maxShown: C.Config.options.bar.workspaces.shown

    // ---- Workspaces deste monitor ---------------------------------------
    // NOVO: só entram workspaces que têm janela, mais a ativa (mesmo vazia).
    // Ignora especiais (id < 0) e o temporário da lock screen (id enorme).
    readonly property var monitorWorkspaceIds: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.id < 100000 && w.monitor?.id === root.monitor?.id
                     && (w.id === root.activeWorkspace || !!HyprlandData.biggestWindowForWorkspace(w.id)))
        .map(w => w.id)
        .sort((a, b) => a - b)

    // Posição do workspace ativo na lista do monitor, e página (grupo) dela.
    readonly property int activeIndex: Math.max(0, monitorWorkspaceIds.indexOf(activeWorkspace))
    readonly property int group: Math.floor(activeIndex / maxShown)      // NOVO: usa maxShown
    readonly property int pageStart: group * maxShown                    // NOVO: usa maxShown

    // NOVO: dinâmico. Quantos slots existem nesta página (mínimo 1, máximo maxShown).
    readonly property int shownCount: Math.max(1, Math.min(maxShown, monitorWorkspaceIds.length - pageStart))

    // Posição do workspace ativo dentro da página exibida.
    readonly property int activeIndexInPage: activeIndex - pageStart     // NOVO

    // ID real de cada slot da página (-1 = slot vazio).
    readonly property var workspaceIds: Array.from({
        length: shownCount
    }, (_, i) => monitorWorkspaceIds[pageStart + i] ?? -1)

    readonly property var occupied: workspaceIds.map(id => id > 0)
    readonly property var biggestWindow: workspaceIds.map(id => id > 0 ? HyprlandData.biggestWindowForWorkspace(id) : null)

    function getWorkspaceId(group, index) {
        return root.monitorWorkspaceIds[group * root.maxShown + index] ?? -1;   // NOVO: maxShown
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