import QtQuick

Item {
    id: root

    required property var service

    readonly property color phaseColor: service.phase === "focus"
        ? Theme.accent
        : service.phase === "longBreak" ? Theme.teal : Theme.green

    Column {
        anchors.fill: parent
        spacing: Ui.gap

        Rectangle {
            width: parent.width
            height: 224
            radius: 16
            color: Theme.alpha(Theme.surface, 0.30)
            border.width: 1
            border.color: Theme.alpha(root.phaseColor, 0.35)

            Text {
                x: 20
                y: 18
                text: service.phaseLabel
                color: Theme.primaryText
                font.family: Ui.fontFamily
                font.pixelSize: Ui.heading
                font.bold: true
            }

            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 16
                anchors.rightMargin: 18
                width: statusText.implicitWidth + 20
                height: 26
                radius: 13
                color: Theme.alpha(root.phaseColor, 0.16)

                Text {
                    id: statusText

                    anchors.centerIn: parent
                    text: service.statusLabel
                    color: root.phaseColor
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.caption
                    font.bold: true
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 62
                text: service.formattedTime
                color: Theme.primaryText
                font.family: Ui.fontFamily
                font.pixelSize: Math.round(Ui.display * 1.65)
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 132
                text: service.running ? "Stay with one task" : service.paused ? "Resume when ready" : "Start when you are ready"
                color: Theme.mutedText
                font.family: Ui.fontFamily
                font.pixelSize: Ui.body
            }

            Rectangle {
                x: 24
                y: 170
                width: parent.width - 48
                height: 8
                radius: 4
                color: Theme.alpha(Theme.quietText, 0.35)

                Rectangle {
                    width: parent.width * service.progress
                    height: parent.height
                    radius: parent.radius
                    color: root.phaseColor
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 195
                spacing: 9

                Repeater {
                    model: service.sessionsPerCycle

                    Rectangle {
                        required property int index

                        width: 9
                        height: 9
                        radius: 5
                        color: index < service.completedInCycle
                            ? root.phaseColor
                            : Theme.alpha(Theme.quietText, 0.45)
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: 64
            spacing: Ui.gap

            PomodoroButton {
                width: (parent.width - parent.spacing * 2) / 2
                height: parent.height
                icon: service.running ? "󰏤" : "󰐊"
                label: service.primaryActionLabel
                primary: true
                onClicked: service.toggle()
            }

            PomodoroButton {
                width: (parent.width - parent.spacing * 2) / 4
                height: parent.height
                icon: "󰒭"
                label: "Skip"
                foreground: Theme.mutedText
                onClicked: service.skip()
            }

            PomodoroButton {
                width: (parent.width - parent.spacing * 2) / 4
                height: parent.height
                icon: "󰑐"
                label: "Reset"
                foreground: Theme.danger
                onClicked: service.reset()
            }
        }

        Row {
            width: parent.width
            height: 100
            spacing: Ui.gap

            PomodoroDurationSelector {
                width: (parent.width - parent.spacing * 2) / 3
                height: parent.height
                label: "Focus"
                minutes: service.focusMinutes
                step: 5
                minimum: 5
                maximum: 120
                accent: Theme.accent
                onDecreaseRequested: service.adjustDuration("focus", -step)
                onIncreaseRequested: service.adjustDuration("focus", step)
            }

            PomodoroDurationSelector {
                width: (parent.width - parent.spacing * 2) / 3
                height: parent.height
                label: "Short break"
                minutes: service.shortBreakMinutes
                step: 1
                minimum: 1
                maximum: 60
                accent: Theme.green
                onDecreaseRequested: service.adjustDuration("shortBreak", -step)
                onIncreaseRequested: service.adjustDuration("shortBreak", step)
            }

            PomodoroDurationSelector {
                width: (parent.width - parent.spacing * 2) / 3
                height: parent.height
                label: "Long break"
                minutes: service.longBreakMinutes
                step: 5
                minimum: 5
                maximum: 60
                accent: Theme.teal
                onDecreaseRequested: service.adjustDuration("longBreak", -step)
                onIncreaseRequested: service.adjustDuration("longBreak", step)
            }
        }
    }
}
