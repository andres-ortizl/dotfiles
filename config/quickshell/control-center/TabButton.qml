import QtQuick

Rectangle {
    id: root

    required property string icon
    required property string label
    property bool active: false

    signal clicked()

    height: 44
    radius: 12
    color: active ? "#3d354f80" : tabMouse.containsMouse ? "#4d414558" : "transparent"

    Row {
        anchors.centerIn: parent
        spacing: 7

        Text {
            text: root.icon
            color: root.active ? "#d4ccff" : "#a7abbe"
            font.family: Ui.fontFamily
            font.pixelSize: 16
        }

        Text {
            text: root.label
            color: root.active ? "#f8f8f2" : "#a7abbe"
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
