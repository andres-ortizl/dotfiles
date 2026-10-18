import QtQuick

Rectangle {
    id: root

    required property var weather

    implicitHeight: Math.max(88, details.implicitHeight + 24)
    height: implicitHeight
    radius: 16
    color: Theme.alpha(Theme.surface, 0.30)
    border.width: 1
    border.color: Theme.alpha(Theme.surface, 0.20)

    Text {
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.weather.icon
        color: Theme.accentText
        font.family: Ui.fontFamily
        font.pixelSize: Ui.icon
    }

    Column {
        id: details

        x: 64
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 80
        spacing: 4

        Text {
            text: "MADRID"
            color: Theme.mutedText
            font.family: Ui.fontFamily
            font.pixelSize: Ui.caption
            font.bold: true
            font.letterSpacing: 1
        }

        Text {
            width: parent.width
            text: `${root.weather.temperature}° · ${root.weather.description}`
            color: Theme.primaryText
            elide: Text.ElideRight
            font.family: Ui.fontFamily
            font.pixelSize: Ui.title
            font.bold: true
        }

        Text {
            width: parent.width
            text: `Feels ${root.weather.feels}°  |  ${root.weather.min}°/${root.weather.max}°  |  Rain ${root.weather.rain}%`
            color: Theme.mutedText
            wrapMode: Text.WordWrap
            font.family: Ui.fontFamily
            font.pixelSize: Ui.caption
        }
    }
}
