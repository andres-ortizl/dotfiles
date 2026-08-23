import QtQuick

Rectangle {
    id: root

    required property string icon
    required property string label
    property bool active: false

    signal clicked()

    height: 44
    radius: 12
    color: active ? Theme.alpha(Theme.activeSurface, 0.24) : tabMouse.containsMouse ? Theme.alpha(Theme.surface, 0.30) : "transparent"

    Row {
        anchors.centerIn: parent
        spacing: 7

        Text {
            text: root.icon
            color: root.active ? Theme.accentText : Theme.mutedText
            font.family: Ui.fontFamily
            font.pixelSize: 16
        }

        Text {
            text: root.label
            color: root.active ? Theme.primaryText : Theme.mutedText
            font.family: Ui.fontFamily
            font.pixelSize: Ui.body
            font.bold: root.active
        }
    }

    MouseArea {
        id: tabMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
