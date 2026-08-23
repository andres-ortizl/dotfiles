import QtQuick

Rectangle {
    id: root

    required property var weather

    height: 200
    radius: 16
    color: Theme.alpha(Theme.surface, 0.30)
    border.width: 1
    border.color: Theme.alpha(Theme.surface, 0.20)

    Text {
        x: 14
        y: 13
        text: "MADRID"
        color: Theme.mutedText
        font.family: Ui.fontFamily
        font.pixelSize: 12
        font.bold: true
        font.letterSpacing: 1
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 44
        text: root.weather.icon
        color: Theme.accentText
        font.family: Ui.fontFamily
        font.pixelSize: 44
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 96
        text: `${root.weather.temperature}°`
        color: Theme.primaryText
        font.family: Ui.fontFamily
        font.pixelSize: Ui.display
        font.bold: true
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 144
        width: parent.width - 20
        text: root.weather.description
        color: Theme.primaryText
        elide: Text.ElideRight
        font.family: Ui.fontFamily
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 14
        font.bold: true
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 173
        width: parent.width - 16
        text: `Feels ${root.weather.feels}°  |  ${root.weather.min}°/${root.weather.max}°  |  Rain ${root.weather.rain}%`
        color: Theme.mutedText
        font.family: Ui.fontFamily
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Ui.caption
    }
}
