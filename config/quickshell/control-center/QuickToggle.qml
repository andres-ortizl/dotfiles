import QtQuick

Rectangle {
    id: root

    required property string icon
    required property string title
    required property string subtitle
    property bool active: false
    property bool available: true
    property bool hasDetails: false

    signal clicked()
    signal toggleClicked()

    height: 104
    radius: 16
    color: active ? "#3d354f80" : "#73414558"
    border.width: 1
    border.color: active ? "#809580ff" : "#33414558"
    opacity: available ? 1 : 0.45

    Behavior on color {
        ColorAnimation { duration: 140 }
    }

    Text {
        x: 15
        y: 16
        text: root.icon
        color: root.active ? "#d4ccff" : "#a7abbe"
        font.family: Ui.fontFamily
        font.pixelSize: 28
    }

    Text {
        x: 15
        y: 58
        width: parent.width - 30
        text: root.title
        color: "#f8f8f2"
        elide: Text.ElideRight
        font.family: Ui.fontFamily
        font.pixelSize: Ui.title
        font.bold: true
    }

    Text {
        x: 15
        y: 84
        text: root.subtitle
        color: root.active ? "#d4ccff" : "#a7abbe"
        font.family: Ui.fontFamily
        font.pixelSize: Ui.caption
    }

    Rectangle {
        id: switchControl

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 16
        anchors.rightMargin: 15
        width: 30
        height: 16
        radius: 8
        color: root.active ? "#9580ff" : "#626784"
        z: 2

        Rectangle {
            x: root.active ? 16 : 2
            y: 2
            width: 12
            height: 12
            radius: 6
            color: "#f8f8f2"

            Behavior on x {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleClicked()
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 15
        y: 80
        visible: root.hasDetails
        text: ">"
        color: "#a7abbe"
        font.family: Ui.fontFamily
        font.pixelSize: Ui.title
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
