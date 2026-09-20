import QtQuick

Rectangle {
    id: root

    required property string label
    required property int minutes
    required property int step
    required property int minimum
    required property int maximum
    property color accent: Theme.accent

    readonly property bool canDecrease: minutes > minimum
    readonly property bool canIncrease: minutes < maximum

    signal decreaseRequested()
    signal increaseRequested()

    radius: 15
    color: Theme.alpha(Theme.surface, 0.24)
    border.width: 1
    border.color: Theme.alpha(Theme.surface, 0.18)

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 12
        text: root.label
        color: Theme.mutedText
        font.family: Ui.fontFamily
        font.pixelSize: Ui.caption
        font.bold: true
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 42
        height: 42
        spacing: 12

        Rectangle {
            width: 38
            height: parent.height
            radius: 12
            color: Theme.alpha(Theme.surface, decreaseMouse.containsMouse ? 0.55 : 0.36)
            opacity: root.canDecrease ? 1 : 0.35
            scale: decreaseMouse.pressed ? 0.94 : 1

            Behavior on scale {
                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
            }

            Text {
                anchors.centerIn: parent
                text: "−"
                color: Theme.primaryText
                font.family: Ui.fontFamily
                font.pixelSize: Ui.heading
                font.bold: true
            }

            MouseArea {
                id: decreaseMouse

                anchors.fill: parent
                enabled: root.canDecrease
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.decreaseRequested()
            }
        }

        Text {
            width: 74
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: `${root.minutes} min`
            color: root.accent
            font.family: Ui.fontFamily
            font.pixelSize: Ui.title
            font.bold: true
        }

        Rectangle {
            width: 38
            height: parent.height
            radius: 12
            color: Theme.alpha(root.accent, increaseMouse.containsMouse ? 0.26 : 0.16)
            border.width: 1
            border.color: Theme.alpha(root.accent, 0.35)
            opacity: root.canIncrease ? 1 : 0.35
            scale: increaseMouse.pressed ? 0.94 : 1

            Behavior on scale {
                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
            }

            Text {
                anchors.centerIn: parent
                text: "+"
                color: root.accent
                font.family: Ui.fontFamily
                font.pixelSize: Ui.heading
                font.bold: true
            }

            MouseArea {
                id: increaseMouse

                anchors.fill: parent
                enabled: root.canIncrease
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.increaseRequested()
            }
        }
    }
}
