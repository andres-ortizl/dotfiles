import QtQuick

Rectangle {
    id: root

    required property string icon
    required property string title
    required property string subtitle

    signal clicked()

    height: 116
    radius: 15
    color: actionMouse.containsMouse ? "#73414558" : "#4d414558"
    border.width: 1
    border.color: "#33414558"

    Text {
        x: 15
        y: 19
        text: root.icon
        color: "#9580ff"
        font.family: Ui.fontFamily
        font.pixelSize: 28
    }

    Text {
        x: 52
        y: 20
        width: parent.width - 70
        text: root.title
        color: "#f8f8f2"
        elide: Text.ElideRight
        font.family: Ui.fontFamily
        font.pixelSize: Ui.title
        font.bold: true
    }

    Text {
        x: 15
        y: 78
        width: parent.width - 38
        text: root.subtitle
        color: "#a7abbe"
        elide: Text.ElideRight
        font.family: Ui.fontFamily
        font.pixelSize: Ui.caption
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 15
        y: 78
        text: ">"
        color: "#626784"
        font.family: Ui.fontFamily
        font.pixelSize: Ui.body
    }

    MouseArea {
        id: actionMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
