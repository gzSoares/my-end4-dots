pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    required property var screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property var toplevels: ToplevelManager.toplevels
    property bool monitorIsFocused: (Hyprland.focusedMonitor?.name == monitor.name)
    property var windows: HyprlandData.windowList
    property var windowByAddress: HyprlandData.windowByAddress
    property var windowAddresses: HyprlandData.addresses
    property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)

    // ---- Uma linha por monitor ------------------------------------------
    // Cada item é um monitor: nome ("DP-1") ou ID numérico (1). A primeira
    // posição é a linha de cima. Cada linha mostra só os workspaces que
    // pertencem àquele monitor, em ordem crescente de ID, `columns` por página
    // (a página acompanha o workspace ativo do monitor).
    // Obs.: Config.options.overview.rows é ignorado; o nº de linhas é o nº de monitores.
    property var rowMonitors: ["DP-1", "eDP-1"]
    readonly property int rowCount: rowMonitors.length
    readonly property int columnCount: Config.options.overview.columns
    readonly property int workspacesShown: rowCount * columnCount

    function isMonitor(mon, key) {
        if (!mon) return false
        return typeof key === "number" ? mon.id === key : mon.name === key
    }

    // IDs (ordenados) dos workspaces normais que pertencem ao monitor.
    // Ignora especiais (id < 0) e o workspace temporário da lock screen (id enorme).
    function monitorWorkspaceIds(key) {
        return Hyprland.workspaces.values
            .filter(w => w.id > 0 && w.id < 100000 && root.isMonitor(w.monitor, key))
            .map(w => w.id)
            .sort((a, b) => a - b)
    }

    // Grade já na ordem de exibição: cellGrid[linha][coluna] = { id, label }.
    // `id` é o ID real do workspace (-1 se a célula está vazia, monitor com
    // poucos workspaces); `label` é o número mostrado, sequencial por linha
    // (1, 2, 3...), independente do ID real.
    readonly property var cellGrid: {
        const cols = root.columnCount
        const rows = root.rowMonitors.map(key => {
            const ids = root.monitorWorkspaceIds(key)
            const mon = Hyprland.monitors.values.find(m => root.isMonitor(m, key))
            const activeIdx = Math.max(0, ids.indexOf(mon?.activeWorkspace?.id ?? -1))
            const start = Math.floor(activeIdx / cols) * cols
            const page = []
            for (let c = 0; c < cols; c++) page.push({ id: ids[start + c] ?? -1, label: start + c + 1 })
            if (Config.options.overview.orderRightLeft) page.reverse()
            return page
        })
        if (Config.options.overview.orderBottomUp) rows.reverse()
        return rows
    }

    readonly property var cellWorkspaceIds: root.cellGrid.map(r => r.map(c => c.id))

    function wsId(row, col) { return root.cellWorkspaceIds[row]?.[col] ?? -1 }
    function wsLabel(row, col) { return root.cellGrid[row]?.[col]?.label ?? "" }

    // Posição {row, col} do workspace na grade, ou null se não estiver visível.
    function cellOf(ws) {
        if (!(ws > 0)) return null
        const g = root.cellWorkspaceIds
        for (let r = 0; r < g.length; r++) {
            const c = g[r].indexOf(ws)
            if (c >= 0) return { row: r, col: c }
        }
        return null
    }

    // Per-workspace scale that fits the whole grid on screen: `size` (1–100%)
    // picks how much of the largest-that-fits to use. 100% fills ~90% of the
    // screen; the scale shrinks automatically as rows/columns grow so the grid
    // never overflows. The default 5×2 at 100% resolves to the historic 0.18.
    property real scale: (Config.options.overview.size / 100)
                         * Math.min(0.9 / Math.max(1, root.columnCount),
                                    0.9 / Math.max(1, root.rowCount))
    property color activeBorderColor: Appearance.colors.colSecondary

    property real workspaceImplicitWidth: (monitorData?.transform % 2 === 1) ? 
        ((monitor.height - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale) :
        ((monitor.width - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale)
    property real workspaceImplicitHeight: (monitorData?.transform % 2 === 1) ? 
        ((monitor.width - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale) :
        ((monitor.height - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale)
    property real largeWorkspaceRadius: Appearance.rounding.large
    property real smallWorkspaceRadius: Appearance.rounding.verysmall

    property real workspaceNumberMargin: 80
    property real workspaceNumberSize: 250 * monitor.scale
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: 5

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    // Set by Overview.qml during an app-drawer drag to highlight the hovered workspace
    property int appDragHoverWorkspace: -1

    // Returns the workspace id at the given scene coordinates, or -1 if none
    // (also -1 for an empty cell).
    function workspaceAtScenePoint(sceneX, sceneY) {
        const lp = workspaceColumnLayout.mapFromItem(null, sceneX, sceneY)
        const cellW = root.workspaceImplicitWidth + workspaceSpacing
        const cellH = root.workspaceImplicitHeight + workspaceSpacing
        const col = Math.floor(lp.x / cellW)
        const row = Math.floor(lp.y / cellH)
        if (col < 0 || col >= root.columnCount) return -1
        if (row < 0 || row >= root.rowCount) return -1
        return root.wsId(row, col)
    }

    implicitWidth: overviewBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: overviewBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

    property Component windowComponent: OverviewWindow {}
    property list<OverviewWindow> windowWidgets: []

    StyledRectangularShadow {
        target: overviewBackground
    }
    Rectangle { // Background
        id: overviewBackground
        property real padding: 10
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin

        implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
        radius: root.largeWorkspaceRadius + padding
        color: Appearance.colors.colBackgroundSurfaceContainer

        Column { // Workspaces
            id: workspaceColumnLayout

            z: root.workspaceZ
            anchors.centerIn: parent
            spacing: workspaceSpacing
            
            Repeater {
                model: root.rowCount
                delegate: Row {
                    id: row
                    required property int index
                    spacing: workspaceSpacing

                    Repeater { // Workspace repeater
                        model: root.columnCount
                        Rectangle { // Workspace
                            id: workspace
                            required property int index
                            property int colIndex: index
                            property int workspaceValue: root.wsId(row.index, colIndex)
                            // Número mostrado: sequencial por linha, não o ID real.
                            readonly property var label: root.wsLabel(row.index, colIndex)
                            // Célula vazia: o monitor tem menos workspaces que colunas.
                            readonly property bool exists: workspaceValue > 0
                            property color defaultWorkspaceColor: Appearance.colors.colSurfaceContainerLow
                            property color hoveredWorkspaceColor: ColorUtils.mix(defaultWorkspaceColor, Appearance.colors.colLayer1Hover, 0.1)
                            property color hoveredBorderColor: Appearance.colors.colLayer2Hover
                            property bool hoveredWhileDragging: false
                            property bool appDragHovered: exists && root.appDragHoverWorkspace === workspaceValue

                            implicitWidth: root.workspaceImplicitWidth
                            implicitHeight: root.workspaceImplicitHeight
                            opacity: exists ? 1 : 0.35
                            color: (hoveredWhileDragging || appDragHovered) ? hoveredWorkspaceColor : defaultWorkspaceColor
                            property bool workspaceAtLeft: colIndex === 0
                            property bool workspaceAtRight: colIndex === root.columnCount - 1
                            property bool workspaceAtTop: row.index === 0
                            property bool workspaceAtBottom: row.index === root.rowCount - 1
                            topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            topRightRadius: (workspaceAtRight && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            border.width: 2
                            border.color: (hoveredWhileDragging || appDragHovered) ? hoveredBorderColor : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: workspace.label
                                font {
                                    pixelSize: root.workspaceNumberSize * root.scale
                                    weight: Font.DemiBold
                                    family: Appearance.font.family.expressive
                                }
                                color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: workspaceArea
                                anchors.fill: parent
                                enabled: workspace.exists
                                acceptedButtons: Qt.LeftButton
                                onPressed: {
                                    if (root.draggingTargetWorkspace === -1) {
                                        GlobalStates.overviewOpen = false
                                        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspace.workspaceValue} })`)
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                enabled: workspace.exists
                                onEntered: {
                                    root.draggingTargetWorkspace = workspace.workspaceValue
                                    if (root.draggingFromWorkspace == root.draggingTargetWorkspace) return;
                                    hoveredWhileDragging = true
                                }
                                onExited: {
                                    hoveredWhileDragging = false
                                    if (root.draggingTargetWorkspace == workspace.workspaceValue) root.draggingTargetWorkspace = -1
                                }
                            }

                        }
                    }
                }
            }
        }

        Item { // Windows & focused workspace indicator
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            Repeater { // Window repeater
                model: ScriptModel {
                    values: {
                        return ToplevelManager.toplevels.values.filter((toplevel) => {
                            const address = `0x${toplevel.HyprlandToplevel?.address}`
                            const win = windowByAddress[address]
                            // Só janelas de workspaces visíveis na grade atual.
                            return root.cellOf(win?.workspace?.id) !== null
                        })
                    }
                }
                delegate: OverviewWindow {
                    id: window
                    required property var modelData
                    property int monitorId: windowData?.monitor
                    property var monitor: HyprlandData.monitors.find(m => m.id == monitorId)
                    property var address: `0x${modelData.HyprlandToplevel.address}`
                    toplevel: modelData
                    monitorData: this.monitor
                    scale: root.scale
                    widgetMonitor: HyprlandData.monitors.find(m => m.id == root.monitor.id)
                    windowData: windowByAddress[address]

                    property bool atInitPosition: (initX == x && initY == y)

                    // Offset on the canvas
                    property var cell: root.cellOf(windowData?.workspace?.id)
                    property int workspaceColIndex: cell?.col ?? 0
                    property int workspaceRowIndex: cell?.row ?? 0
                    xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex
                    yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * workspaceRowIndex
                    property real xWithinWorkspaceWidget: Math.max((windowData?.at[0] - (monitor?.x ?? 0) - monitorData?.reserved[0]) * root.scale, 0)
                    property real yWithinWorkspaceWidget: Math.max((windowData?.at[1] - (monitor?.y ?? 0) - monitorData?.reserved[1]) * root.scale, 0)

                    // Radius
                    property real minRadius: Appearance.rounding.small
                    property bool workspaceAtLeft: workspaceColIndex === 0
                    property bool workspaceAtRight: workspaceColIndex === root.columnCount - 1
                    property bool workspaceAtTop: workspaceRowIndex === 0
                    property bool workspaceAtBottom: workspaceRowIndex === root.rowCount - 1
                    property bool workspaceAtTopLeft: (workspaceAtLeft && workspaceAtTop) 
                    property bool workspaceAtTopRight: (workspaceAtRight && workspaceAtTop) 
                    property bool workspaceAtBottomLeft: (workspaceAtLeft && workspaceAtBottom) 
                    property bool workspaceAtBottomRight: (workspaceAtRight && workspaceAtBottom) 
                    property real distanceFromLeftEdge: xWithinWorkspaceWidget
                    property real distanceFromRightEdge: root.workspaceImplicitWidth - (xWithinWorkspaceWidget + targetWindowWidth)
                    property real distanceFromTopEdge: yWithinWorkspaceWidget
                    property real distanceFromBottomEdge: root.workspaceImplicitHeight - (yWithinWorkspaceWidget + targetWindowHeight)
                    property real distanceFromTopLeftCorner: Math.max(distanceFromLeftEdge, distanceFromTopEdge)
                    property real distanceFromTopRightCorner: Math.max(distanceFromRightEdge, distanceFromTopEdge)
                    property real distanceFromBottomLeftCorner: Math.max(distanceFromLeftEdge, distanceFromBottomEdge)
                    property real distanceFromBottomRightCorner: Math.max(distanceFromRightEdge, distanceFromBottomEdge)
                    topLeftRadius: Math.max((workspaceAtTopLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromTopLeftCorner, minRadius)
                    topRightRadius: Math.max((workspaceAtTopRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromTopRightCorner, minRadius)
                    bottomLeftRadius: Math.max((workspaceAtBottomLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromBottomLeftCorner, minRadius)
                    bottomRightRadius: Math.max((workspaceAtBottomRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromBottomRightCorner, minRadius)

                    Timer {
                        id: updateWindowPosition
                        interval: Config.options.hacks.arbitraryRaceConditionDelay
                        repeat: false
                        running: false
                        onTriggered: {
                            window.x = Math.round(xWithinWorkspaceWidget + xOffset)
                            window.y = Math.round(yWithinWorkspaceWidget + yOffset)
                        }
                    }

                    z: Drag.active ? root.windowDraggingZ : (root.windowZ + windowData?.floating + windowData?.fullscreen * 2)
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        enabled: !window.closing
                        hoverEnabled: !window.closing
                        onEntered: hovered = true // For hover color change
                        onExited: hovered = false // For hover color change
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent
                        onPressed: (mouse) => {
                            if (mouse.button !== Qt.LeftButton) return
                            root.draggingFromWorkspace = windowData?.workspace.id
                            window.pressed = true
                            window.Drag.active = true
                            window.Drag.source = window
                            window.Drag.hotSpot.x = mouse.x
                            window.Drag.hotSpot.y = mouse.y
                        }
                        onReleased: (mouse) => {
                            if (mouse.button !== Qt.LeftButton) return
                            const targetWorkspace = root.draggingTargetWorkspace
                            window.pressed = false
                            window.Drag.active = false
                            root.draggingFromWorkspace = -1
                            if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace.id) {
                                Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${targetWorkspace}, follow = false, window = "address:${window.windowData?.address}" })`)
                                updateWindowPosition.restart()
                            }
                            else {
                                if (!window.windowData?.floating) {
                                    updateWindowPosition.restart()
                                    return
                                }
                                const percentageX = (window.x - xOffset) / root.workspaceImplicitWidth
                                const percentageY = (window.y - yOffset) / root.workspaceImplicitHeight
                                // The thumbnail shows the screen less what the panels reserve, so the
                                // drop maps into that room; spreading it over the whole screen put a
                                // window dropped near the top under the bar. The config turns the
                                // spot into the move to make, with the title bar kept within reach.
                                const reserved = monitorData?.reserved ?? [0, 0, 0, 0]
                                const roomX = reserved[0] + percentageX * (root.screen.width - reserved[0] - reserved[2])
                                const roomY = reserved[1] + percentageY * (root.screen.height - reserved[1] - reserved[3])
                                Hyprland.dispatch(`MainstreamFloatMoveWithinReach("address:${window.windowData?.address}", ${Math.round(roomX)}, ${Math.round(roomY)})`)
                            }
                        }
                        onClicked: (event) => {
                            if (!windowData) return;

                            if (event.button === Qt.LeftButton) {
                                GlobalStates.overviewOpen = false
                                Hyprland.dispatch(`hl.dsp.focus({window = "address:${windowData.address}"})`)
                                event.accepted = true
                            } else if (event.button === Qt.MiddleButton) {
                                window.closing = true
                                Hyprland.dispatch(`hl.dsp.window.close({window = "address:${windowData.address}"})`)
                                event.accepted = true
                            }
                        }

                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: dragArea.containsMouse && !window.Drag.active && !window.closing
                            text: `${windowData?.title}\n[${windowData?.class}] ${windowData?.xwayland ? "[XWayland] " : ""}`
                        }
                    }
                }
            }

            // Indicador do workspace ativo: um por monitor (cada linha tem o seu).
            // O do monitor focado usa a cor cheia; o outro fica mais discreto.
            Repeater {
                model: root.rowCount
                delegate: Rectangle {
                    id: focusedWorkspaceIndicator
                    required property int index
                    readonly property var rowMon: Hyprland.monitors.values.find(m => root.isMonitor(m, root.rowMonitors[index]))
                    readonly property var cell: root.cellOf(rowMon?.activeWorkspace?.id)
                    readonly property bool monitorFocused: !!rowMon && Hyprland.focusedMonitor?.id === rowMon.id
                    visible: cell !== null
                    property int rowIndex: cell?.row ?? 0
                    property int colIndex: cell?.col ?? 0
                    x: (root.workspaceImplicitWidth + workspaceSpacing) * colIndex
                    y: (root.workspaceImplicitHeight + workspaceSpacing) * rowIndex
                    z: root.windowZ
                    width: root.workspaceImplicitWidth
                    height: root.workspaceImplicitHeight
                    color: "transparent"
                    property bool workspaceAtLeft: colIndex === 0
                    property bool workspaceAtRight: colIndex === root.columnCount - 1
                    property bool workspaceAtTop: rowIndex === 0
                    property bool workspaceAtBottom: rowIndex === root.rowCount - 1
                    topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    topRightRadius: (workspaceAtRight && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    border.width: 2
                    border.color: monitorFocused ? root.activeBorderColor : ColorUtils.transparentize(root.activeBorderColor, 0.6)
                    Behavior on x {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    Behavior on y {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    Behavior on topLeftRadius {
                        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                    }
                    Behavior on topRightRadius {
                        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                    }
                    Behavior on bottomLeftRadius {
                        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                    }
                    Behavior on bottomRightRadius {
                        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                    }
                }
            }
        }
    }
}