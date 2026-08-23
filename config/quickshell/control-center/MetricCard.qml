import QtQuick

Rectangle {
    id: root

    required property string icon
    required property string title
    required property string value
    required property string detail
    property bool critical: false
    property bool interactive: false

    signal clicked()

    height: 84
    radius: 14
    color: interactive && cardMouse.containsMouse ? Theme.alpha(Theme.surface, 0.45) : Theme.alpha(Theme.surface, 0.30)
    border.width: critical ? 1 : 0
    border.color: Theme.alpha(Theme.danger, 0.60)

    Text {
        x: 13
        y: 14
        text: root.icon
        color: root.critical ? Theme.danger : Theme.accent
        font.family: Ui.fontFamily
        font.pixelSize: Ui.icon
    }

    Text {
        x: 42
        y: 16
        width: parent.width - 72
        text: root.title
        color: Theme.mutedText
        elide: Text.ElideRight
        font.family: Ui.fontFamily
        font.pixelSize: 12
        font.bold: true
    }

    Text {
        x: 13
        y: 48
        text: root.value
        color: root.critical ? Theme.danger : Theme.primaryText
        font.family: Ui.fontFamily
        font.pixelSize: Ui.heading
        font.bold: true
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 51
        text: root.detail
        color: Theme.mutedText
        font.family: Ui.fontFamily
        font.pixelSize: Ui.caption
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 11
        y: 14
        visible: root.interactive
        text: ">"
        color: Theme.quietText
        font.family: Ui.fontFamily
        font.pixelSize: Ui.body
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
