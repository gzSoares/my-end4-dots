import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool alwaysShowAllResources: true
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.baseBarHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow
    acceptedButtons: Qt.LeftButton
    onClicked: Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "sysmonitor", "toggle"])

    RowLayout {
        id: rowLayout

        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: Appearance.spacing.xs
        anchors.rightMargin: Appearance.spacing.xs

        Resource {
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            warningThreshold: Config.options.bar.resources.memoryWarningThreshold
        }

        Resource {
            iconName: "thermostat"
            shown: Config.options.bar.resources.alwaysShowCpuTemp
            percentage: ResourceUsage.cpuTemp / 100
            Layout.leftMargin: shown ? 6 : 0
        }

        Resource {
            iconName: "planner_review"
            percentage: ResourceUsage.cpuUsage
            shown: Config.options.bar.resources.alwaysShowCpu || !(MprisController.activePlayer?.trackTitle?.length > 0) || root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0

            warningThreshold: Config.options.bar.resources.cpuWarningThreshold
          }

         Resource {
            iconName: "empty_dashboard"
            percentage: (Config.options.bar.resources.gpuLayout == 0 || Config.options.bar.resources.gpuLayout ==2) ? GpuUsage.dGpuUsage : GpuUsage.iGpuUsage
            shown: (Config.options.bar.resources.alwaysShowGPU ||
                !(MprisController.activePlayer?.trackTitle?.length > 0) ||
                root.alwaysShowAllResources) && (  (GpuUsage.dGpuAvailable &&  (Config.options.bar.resources.gpuLayout == 0 || Config.options.bar.resources.gpuLayout ==2) )
                ||  (GpuUsage.iGpuAvailable &&  (Config.options.bar.resources.gpuLayout == 1)  ))
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.gpuWarningThreshold

        }

        Resource {
            iconName: "thermostat"
            percentage: (Config.options.bar.resources.gpuLayout == 0 || Config.options.bar.resources.gpuLayout == 2)
                ? GpuUsage.dGpuTemperature / 100
                : GpuUsage.iGpuTemperature / 100
            shown: (
                (GpuUsage.dGpuAvailable && (Config.options.bar.resources.gpuLayout == 0 || Config.options.bar.resources.gpuLayout == 2))
                || (GpuUsage.iGpuAvailable && (Config.options.bar.resources.gpuLayout == 1))
            )
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.gpuWarningThreshold
        }
    }

    ResourcesPopup {
        hoverTarget: root
    }
}