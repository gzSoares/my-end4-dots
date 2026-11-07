import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.models
import qs.modules.common.widgets
import "connectivity"

Item {
    id: root

    ShownWifiNetworks {
        id: shownNetworks
    }

    component WifiNotice: SubtleNoticeBox {
        Layout.fillWidth: true
        Layout.leftMargin: Appearance.spacing.sm
        Layout.rightMargin: Appearance.spacing.sm
        Layout.topMargin: Appearance.spacing.xs
        Layout.bottomMargin: Appearance.spacing.xs
    }

    ContentPage {
        anchors.fill: parent
        forceWidth: true
        baseWidth: 628

        CardSection {
            icon: "wifi"
            title: "Wi-Fi"

            headerExtra: [
                RippleButton {
                    visible: Network.wifiEnabled
                    implicitWidth: 90
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: Network.rescanWifi()

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: Appearance.spacing.xs
                        MaterialSymbol {
                            text: "refresh"
                            iconSize: 16
                            color: Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            text: Translation.tr("Scan")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                        }
                    }
                }
            ]

            ConfigRow {
                ConfigSwitch {
                    text: Translation.tr("Enable Wi-Fi")
                    checked: Network.wifiEnabled
                    onCheckedChanged: {
                        Network.enableWifi(checked, true);
                    }
                }
            }

            WifiNotice {
                visible: Network.frameAdapterPresent
                materialIcon: "view_in_ar"
                text: Translation.tr("Turning Wi-Fi off also turns off the wireless adapter for the Steam Frame (experimental), so the headset cannot stream through it until Wi-Fi is back on.")
            }

            StyledIndeterminateProgressBar {
                visible: Network.wifiScanning
                Layout.fillWidth: true
            }
        }

        // Connected network
        CardSection {
            icon: "wifi"
            title: Translation.tr("Connected")
            visible: Network.wifiEnabled && shownNetworks.active !== null

            ConnectivityWifiItem {
                wifiNetwork: shownNetworks.active
                Layout.fillWidth: true
            }
        }

        // Saved networks (not active)
        CardSection {
            icon: "bookmark"
            title: Translation.tr("Saved Networks")
            visible: Network.wifiEnabled && shownNetworks.savedNetworks.length > 0

            Repeater {
                model: ScriptModel {
                    values: shownNetworks.savedNetworks
                }

                ConnectivityWifiItem {
                    required property var modelData
                    wifiNetwork: modelData
                    Layout.fillWidth: true
                }
            }

            WifiNotice {
                // From the rows above, so it stays beside a Steam row a prompt holds there.
                visible: shownNetworks.savedNetworks.some(n => n?.frameProfile)
                materialIcon: "view_in_ar"
                text: Translation.tr("%1 is the link Steam makes to the Steam Frame (experimental), and Steam connects it by itself. If the headset will not pair, forgetting it and pairing again can help.").arg(Network.frameProfileName)
            }
        }

        CardSection {
            icon: "wifi_find"
            title: Translation.tr("Available Networks")
            visible: Network.wifiEnabled

            // Empty state
            ColumnLayout {
                visible: shownNetworks.availableNetworks.length === 0 && !Network.wifiScanning
                Layout.fillWidth: true
                Layout.topMargin: 20
                Layout.bottomMargin: 20
                spacing: Appearance.spacing.sm

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 64
                    implicitHeight: 64
                    radius: Appearance.rounding.fit(32)
                    color: Appearance.colors.colLayer3

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "wifi_find"
                        iconSize: 32
                        color: Appearance.colors.colSubtext
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No new networks found")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer2
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Click Scan to search for networks")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }

            // Network list (available = not saved)
            Repeater {
                model: ScriptModel {
                    values: shownNetworks.availableNetworks
                }

                ConnectivityWifiItem {
                    required property var modelData
                    wifiNetwork: modelData
                    Layout.fillWidth: true
                }
            }
        }

        CardSection {
            icon: "wifi_add"
            title: Translation.tr("Hidden Network")
            visible: Network.wifiEnabled

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialTextField {
                    id: hiddenSsidField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Network name (SSID)")
                }

                MaterialTextField {
                    id: hiddenPasswordField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Password (optional)")
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData
                }

                RippleButton {
                    Layout.alignment: Qt.AlignRight
                    implicitWidth: 140
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.full
                    enabled: hiddenSsidField.text.length > 0
                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimaryHover

                    onClicked: {
                        const ssid = hiddenSsidField.text;
                        const password = hiddenPasswordField.text;
                        if (password.length > 0) {
                            Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", ssid, "password", password]);
                        } else {
                            Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", ssid]);
                        }
                        hiddenSsidField.text = "";
                        hiddenPasswordField.text = "";
                    }

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            text: "add"
                            iconSize: 18
                            color: Appearance.colors.colOnPrimary
                        }
                        StyledText {
                            text: Translation.tr("Connect")
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }
        }
    }
}
