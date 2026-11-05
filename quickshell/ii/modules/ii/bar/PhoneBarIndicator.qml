import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/*
 * The phone's battery and signal in the bar. Click opens a small panel with
 * the details and a "Ring phone" button, for when it is lost in the couch.
 */
MouseArea {
    id: root

    readonly property var device: KdeConnectService.activeDevice
    readonly property bool reachable: KdeConnectService.activeReachable
    readonly property int charge: device?.charge ?? -1
    readonly property bool charging: device?.charging ?? false
    readonly property int signalLevel: Math.max(0, Math.min(4, device?.signalStrength ?? 0))
    readonly property string signalType: device?.signalType ?? ""
    readonly property bool low: charge >= 0 && charge <= Config.options.battery.low && !charging

    implicitWidth: row.implicitWidth + 8
    implicitHeight: Appearance.sizes.baseBarHeight

    hoverEnabled: !Config.options.bar.tooltips.clickToShow
    onClicked: popup.open = !popup.open

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 2
        opacity: root.reachable ? 1 : 0.5

        MaterialSymbol {
            text: root.reachable ? "smartphone" : "phonelink_off"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer1
        }
        MaterialSymbol {
            visible: root.reachable && root.charge >= 0 && root.charging
            text: "bolt"
            fill: 1
            iconSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
        }
        StyledText {
            visible: root.charge >= 0
            text: root.charge + "%"
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: root.low ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
        }
        MaterialSymbol {
            visible: root.reachable && root.signalType !== ""
            text: "signal_cellular_" + root.signalLevel + "_bar"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer1
        }
    }

    StyledPopup {
        id: popup
        property bool open: false
        hoverTarget: root
        forceShow: open
        showOnHover: false
        onDismissed: open = false

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Appearance.spacing.xs

            StyledPopupHeaderRow {
                icon: "smartphone"
                label: KdeConnectService.activeDeviceDisplayName || Translation.tr("Phone")
            }
            StyledPopupValueRow {
                icon: root.charging ? "battery_charging_full" : "battery_android_full"
                label: Translation.tr("Battery:")
                value: root.charge >= 0 ? root.charge + "%" : "—"
            }
            StyledPopupValueRow {
                visible: root.signalType !== ""
                icon: "signal_cellular_alt"
                label: Translation.tr("Signal:")
                value: root.signalType
            }
            StyledPopupValueRow {
                icon: root.reachable ? "wifi" : "wifi_off"
                label: Translation.tr("Connection:")
                value: root.reachable ? Translation.tr("Connected") : Translation.tr("Not reachable")
            }

            RippleButtonWithIcon {
                Layout.fillWidth: true
                Layout.minimumWidth: 200
                enabled: root.reachable
                materialIcon: "notifications_active"
                mainText: Translation.tr("Ring phone")
                colBackground: Appearance.colors.colLayer2
                onClicked: {
                    KdeConnectService.findMyPhone(KdeConnectService.activeDeviceId);
                    popup.open = false;
                }
            }
            RippleButtonWithIcon {
                Layout.fillWidth: true
                enabled: root.reachable && KdeConnectService.scrcpyAvailable
                materialIcon: "open_in_new"
                mainText: KdeConnectService.scrcpyRunning || PhoneScrcpyService.mirrorRunning
                    ? Translation.tr("Focus Phone window") : Translation.tr("Open Phone window")
                colBackground: Appearance.colors.colLayer2
                onClicked: {
                    if (KdeConnectService.scrcpyRunning) KdeConnectService.focusScrcpyWindow();
                    else PhoneScrcpyService.openMirrorWindow();
                    popup.open = false;
                }
            }
            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "left_panel_open"
                mainText: Translation.tr("Open Phone tab")
                colBackground: Appearance.colors.colLayer2
                onClicked: {
                    GlobalStates.sidebarLeftRequestPage = "phone";
                    GlobalStates.sidebarLeftOpen = true;
                    popup.open = false;
                }
            }
        }
    }
}
