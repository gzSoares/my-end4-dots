import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sysmonitor

/**
 * Modal editor for an RDP connection. open(conn|null) → emits save(conn, passwordOrNull).
 * Password: empty field keeps the saved one; "Forget saved password" clears it.
 */
Item {
    id: editor

    property var original: null
    property bool keyring: true
    property bool hasSavedPassword: false
    property bool forgetPassword: false
    property string errorText: ""

    // editable state
    property string display: "fit"
    property bool multimon: false
    property int scale: 100
    property bool sound: true
    property bool microphone: false
    property bool clipboard: true
    property bool ignoreCert: false
    property string network: "auto"
    property bool showAdvanced: false

    signal save(var conn, var password)

    visible: opacity > 0
    opacity: 0
    Behavior on opacity {
        NumberAnimation {
            duration: 160
        }
    }

    function open(c, saved) {
        original = c;
        hasSavedPassword = !!saved;
        forgetPassword = false;
        errorText = "";
        showAdvanced = false;
        const d = c || {};
        nameField.text = d.name || "";
        hostField.text = d.host || "";
        portField.text = String(d.port || 3389);
        userField.text = d.user || "";
        domainField.text = d.domain || "";
        passField.text = "";
        groupField.text = d.group || "";
        display = d.display || "fit";
        widthField.text = String(d.width || 1920);
        heightField.text = String(d.height || 1080);
        multimon = !!d.multimon;
        scale = d.scale || 100;
        sound = d.sound === undefined ? true : d.sound;
        microphone = !!d.microphone;
        clipboard = d.clipboard === undefined ? true : d.clipboard;
        ignoreCert = !!d.ignoreCert;
        network = d.network || "auto";
        folderField.text = d.shareFolder || "";
        gatewayField.text = d.gateway || "";
        gatewayUserField.text = d.gatewayUser || "";
        extraField.text = d.extraArgs || "";
        flick.contentY = 0;
        opacity = 1;
        (c ? nameField : hostField).field.forceActiveFocus();
    }
    function close() {
        opacity = 0;
    }
    function submit() {
        const host = hostField.text.trim();
        if (!host) {
            errorText = "Host is required";
            return;
        }
        const port = parseInt(portField.text) || 3389;
        const conn = Object.assign({}, original || {}, {
            name: nameField.text.trim() || host,
            host: host,
            port: port,
            user: userField.text.trim(),
            domain: domainField.text.trim(),
            group: groupField.text.trim(),
            display: display,
            width: parseInt(widthField.text) || 1920,
            height: parseInt(heightField.text) || 1080,
            multimon: multimon,
            scale: scale,
            sound: sound,
            microphone: microphone,
            clipboard: clipboard,
            ignoreCert: ignoreCert,
            network: network,
            shareFolder: folderField.text.trim(),
            gateway: gatewayField.text.trim(),
            gatewayUser: gatewayUserField.text.trim(),
            extraArgs: extraField.text.trim()
        });
        delete conn.hasPassword;
        const pw = forgetPassword ? "" : (passField.text.length > 0 ? passField.text : null);
        save(conn, pw);
        close();
    }

    component FormLabel: StyledText {
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.Medium
        color: Appearance.colors.colSubtext
        Layout.topMargin: 4
    }
    component Choice: SysButton {
        property string value
        property string current
        toggled: value === current
        implicitHeight: 32
    }
    component ToggleRow: RowLayout {
        property alias label: lbl.text
        property alias checked: sw.checked
        property string icon
        signal toggled(bool on)
        Layout.fillWidth: true
        spacing: 10
        MaterialSymbol {
            text: parent.icon
            iconSize: 18
            color: Appearance.colors.colSubtext
        }
        StyledText {
            id: lbl
            Layout.fillWidth: true
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.small
        }
        SysSwitch {
            id: sw
            onToggled: on => parent.toggled(on)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.6
        MouseArea {
            anchors.fill: parent
            onClicked: editor.close()
        }
    }

    Rectangle {
        id: sheet
        anchors.centerIn: parent
        width: Math.min(660, parent.width - 40)
        height: Math.min(parent.height - 40, 760)
        radius: Appearance.rounding.large
        color: Qt.rgba(Appearance.colors.colLayer1.r, Appearance.colors.colLayer1.g, Appearance.colors.colLayer1.b, 1)
        border.width: 1
        border.color: Appearance.m3colors.m3outlineVariant
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                MaterialSymbol {
                    text: "desktop_windows"
                    iconSize: 24
                    color: Appearance.m3colors.m3primary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: editor.original ? "Edit connection" : "New connection"
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer1
                }
            }

            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: form.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: form
                    width: flick.width - 12
                    spacing: 8

                    FormLabel {
                        text: "Computer"
                    }
                    SysTextField {
                        id: nameField
                        Layout.fillWidth: true
                        icon: "label"
                        placeholderText: "Name (e.g. PC do trabalho)"
                        onAccepted: editor.submit()
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        SysTextField {
                            id: hostField
                            Layout.fillWidth: true
                            icon: "dns"
                            placeholderText: "Host or IP  (192.168.0.20)"
                            onAccepted: editor.submit()
                        }
                        SysTextField {
                            id: portField
                            Layout.preferredWidth: 120
                            icon: "tag"
                            placeholderText: "3389"
                            onAccepted: editor.submit()
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        SysTextField {
                            id: userField
                            Layout.fillWidth: true
                            icon: "person"
                            placeholderText: "Username"
                            onAccepted: editor.submit()
                        }
                        SysTextField {
                            id: domainField
                            Layout.preferredWidth: 200
                            icon: "domain"
                            placeholderText: "Domain (optional)"
                            onAccepted: editor.submit()
                        }
                    }
                    SysTextField {
                        id: passField
                        Layout.fillWidth: true
                        icon: "key"
                        field.echoMode: TextInput.Password
                        enabled: !editor.forgetPassword
                        placeholderText: !editor.keyring ? "No keyring found — you'll be asked on connect" : editor.hasSavedPassword ? "Saved in keyring — type to replace" : "Password (stored in the system keyring)"
                        onAccepted: editor.submit()
                    }
                    SysButton {
                        visible: editor.hasSavedPassword
                        icon: editor.forgetPassword ? "undo" : "key_off"
                        text: editor.forgetPassword ? "Keep saved password" : "Forget saved password"
                        implicitHeight: 30
                        onClicked: editor.forgetPassword = !editor.forgetPassword
                    }
                    SysTextField {
                        id: groupField
                        Layout.fillWidth: true
                        icon: "folder"
                        placeholderText: "Group (optional — Work, Home…)"
                        onAccepted: editor.submit()
                    }

                    FormLabel {
                        text: "Display"
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Choice {
                            value: "fit"
                            current: editor.display
                            icon: "fit_screen"
                            text: "Fit window"
                            onClicked: editor.display = value
                        }
                        Choice {
                            value: "fullscreen"
                            current: editor.display
                            icon: "fullscreen"
                            text: "Fullscreen"
                            onClicked: editor.display = value
                        }
                        Choice {
                            value: "custom"
                            current: editor.display
                            icon: "aspect_ratio"
                            text: "Fixed size"
                            onClicked: editor.display = value
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: editor.display !== "fullscreen"
                        spacing: 8
                        SysTextField {
                            id: widthField
                            Layout.fillWidth: true
                            icon: "width"
                            placeholderText: "Width"
                        }
                        StyledText {
                            text: "×"
                            color: Appearance.colors.colSubtext
                        }
                        SysTextField {
                            id: heightField
                            Layout.fillWidth: true
                            icon: "height"
                            placeholderText: "Height"
                        }
                    }
                    ToggleRow {
                        visible: editor.display === "fullscreen"
                        icon: "desktop_windows"
                        label: "Use all monitors (DP-1 + eDP-1)"
                        checked: editor.multimon
                        onToggled: on => editor.multimon = on
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        StyledText {
                            text: "Remote scaling"
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.small
                            Layout.fillWidth: true
                        }
                        Repeater {
                            model: [100, 125, 140, 180]
                            delegate: Choice {
                                required property int modelData
                                value: String(modelData)
                                current: String(editor.scale)
                                text: modelData + "%"
                                onClicked: editor.scale = modelData
                            }
                        }
                    }

                    FormLabel {
                        text: "Devices"
                    }
                    ToggleRow {
                        icon: "volume_up"
                        label: "Play remote sound here"
                        checked: editor.sound
                        onToggled: on => editor.sound = on
                    }
                    ToggleRow {
                        icon: "mic"
                        label: "Share microphone"
                        checked: editor.microphone
                        onToggled: on => editor.microphone = on
                    }
                    ToggleRow {
                        icon: "content_paste"
                        label: "Share clipboard"
                        checked: editor.clipboard
                        onToggled: on => editor.clipboard = on
                    }
                    SysTextField {
                        id: folderField
                        Layout.fillWidth: true
                        icon: "folder_shared"
                        placeholderText: "Share a local folder as a drive (e.g. ~/Downloads)"
                    }

                    SysButton {
                        Layout.topMargin: 4
                        icon: editor.showAdvanced ? "expand_less" : "expand_more"
                        text: "Advanced"
                        onClicked: editor.showAdvanced = !editor.showAdvanced
                    }
                    ColumnLayout {
                        visible: editor.showAdvanced
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            StyledText {
                                text: "Network"
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                                Layout.fillWidth: true
                            }
                            Repeater {
                                model: ["auto", "lan", "broadband", "modem"]
                                delegate: Choice {
                                    required property string modelData
                                    value: modelData
                                    current: editor.network
                                    text: modelData === "lan" ? "LAN" : modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                    onClicked: editor.network = modelData
                                }
                            }
                        }
                        ToggleRow {
                            icon: "gpp_maybe"
                            label: "Ignore certificate errors"
                            checked: editor.ignoreCert
                            onToggled: on => editor.ignoreCert = on
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            SysTextField {
                                id: gatewayField
                                Layout.fillWidth: true
                                icon: "vpn_lock"
                                placeholderText: "RD Gateway (optional)"
                            }
                            SysTextField {
                                id: gatewayUserField
                                Layout.preferredWidth: 200
                                icon: "person"
                                placeholderText: "Gateway user"
                            }
                        }
                        SysTextField {
                            id: extraField
                            Layout.fillWidth: true
                            icon: "terminal"
                            placeholderText: "Extra FreeRDP arguments (e.g. /gfx:AVC444 /kbd:layout:0x416)"
                        }
                    }
                }
            }

            StyledText {
                visible: editor.errorText.length > 0
                text: editor.errorText
                color: Appearance.m3colors.m3error
                font.pixelSize: Appearance.font.pixelSize.small
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item {
                    Layout.fillWidth: true
                }
                SysButton {
                    text: "Cancel"
                    onClicked: editor.close()
                }
                SysButton {
                    icon: "check"
                    text: "Save"
                    tonal: true
                    onClicked: editor.submit()
                }
            }
        }
    }
}
