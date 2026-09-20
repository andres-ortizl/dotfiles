import QtQuick

Rectangle {
    id: root

    required property string icon
    required property string label
    property bool primary: false
    property color foreground: primary ? Theme.accentText : Theme.primaryText

    signal clicked()

    radius: 14
    color: primary
        ? Theme.alpha(Theme.activeSurface, buttonMouse.containsMouse ? 0.42 : 0.30)
        : Theme.alpha(Theme.surface, buttonMouse.containsMouse ? 0.48 : 0.30)
    border.width: 1
    border.color: primary
        ? Theme.alpha(Theme.accent, 0.55)
        : Theme.alpha(Theme.surface, 0.26)
    scale: buttonMouse.pressed ? 0.97 : 1

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: root.icon
            color: root.foreground
            font.family: Ui.fontFamily
            font.pixelSize: Ui.title
        }

        Text {
            text: root.label
            color: root.foreground
            font.family: Ui.fontFamily
            font.pixelSize: Ui.body
            font.bold: root.primary
        }
    }

    MouseArea {
        id: buttonMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
