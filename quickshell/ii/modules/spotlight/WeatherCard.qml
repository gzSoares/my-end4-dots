import QtQuick

// Weather card: current conditions, 12-hour outlook and footer.
// info = { city, country, temp, desc, kind, high, low, feels, summary, url,
//          hours: [{ label, temp, kind }] }   (hours[0] is "Now")
Item {
    id: card

    property var info: null
    property string fontFamily: "sans-serif"
    property color fg: Qt.rgba(1, 1, 1, 0.92)
    property color muted: Qt.rgba(1, 1, 1, 0.55)
    property color panel: Qt.rgba(1, 1, 1, 0.06)
    property color panelBorder: Qt.rgba(1, 1, 1, 0.10)

    signal openBrowser()

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: card.panel
        border.color: card.panelBorder
        border.width: 1
    }

    // ---- current conditions
    WeatherGlyph {
        id: mainIcon
        x: 18; y: 14
        width: 46; height: 46
        kind: card.info ? card.info.kind : "cloud"
        fg: card.fg
    }
    Text {
        id: tempText
        anchors.left: mainIcon.right; anchors.leftMargin: 10
        anchors.verticalCenter: mainIcon.verticalCenter
        text: card.info ? card.info.temp + "\u00b0" : ""
        color: card.fg
        font { family: card.fontFamily; pixelSize: 40; weight: Font.Light }
    }
    Column {
        anchors.left: tempText.right; anchors.leftMargin: 18
        anchors.verticalCenter: mainIcon.verticalCenter
        spacing: 2
        Text {
            text: card.info ? card.info.desc : ""
            color: card.fg
            font { family: card.fontFamily; pixelSize: 15; weight: Font.DemiBold }
        }
        Text {
            text: card.info ? "High " + card.info.high + "\u00b0  \u00b7  Low " + card.info.low
                              + "\u00b0  \u00b7  Feels like " + card.info.feels + "\u00b0" : ""
            color: card.muted
            font { family: card.fontFamily; pixelSize: 12 }
        }
    }
    Column {
        anchors.right: parent.right; anchors.rightMargin: 18
        anchors.verticalCenter: mainIcon.verticalCenter
        spacing: 2
        Text {
            anchors.right: parent.right
            text: card.info ? card.info.city : ""
            color: card.fg
            font { family: card.fontFamily; pixelSize: 15; weight: Font.DemiBold }
        }
        Text {
            anchors.right: parent.right
            text: card.info ? card.info.country : ""
            color: card.muted
            font { family: card.fontFamily; pixelSize: 12 }
        }
    }

    // ---- summary
    Text {
        x: 18; y: 74
        text: card.info ? card.info.summary : ""
        color: card.muted
        font { family: card.fontFamily; pixelSize: 12 }
    }

    // ---- hourly outlook
    Row {
        id: hoursRow
        x: 18; y: 98
        width: card.width - 36
        height: 58
        Repeater {
            model: card.info ? card.info.hours : []
            delegate: Item {
                width: hoursRow.width / 7
                height: hoursRow.height
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0
                    text: modelData.label
                    color: card.muted
                    font { family: card.fontFamily; pixelSize: 11 }
                }
                WeatherGlyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 17
                    width: 22; height: 22
                    kind: modelData.kind
                    fg: card.fg
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 43
                    text: modelData.temp + "\u00b0"
                    color: card.fg
                    font { family: card.fontFamily; pixelSize: 12; weight: Font.DemiBold }
                }
            }
        }
    }

    // ---- footer
    Text {
        x: 18
        anchors.bottom: parent.bottom; anchors.bottomMargin: 10
        text: "Open-Meteo"
        color: card.muted
        font { family: card.fontFamily; pixelSize: 10 }
    }
    Text {
        id: browserLink
        anchors.right: parent.right; anchors.rightMargin: 18
        anchors.bottom: parent.bottom; anchors.bottomMargin: 10
        text: "Open in browser \u2197"
        color: linkMA.containsMouse ? card.fg : card.muted
        font { family: card.fontFamily; pixelSize: 10 }
        Behavior on color { ColorAnimation { duration: 100 } }
        MouseArea {
            id: linkMA
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.openBrowser()
        }
    }
}
