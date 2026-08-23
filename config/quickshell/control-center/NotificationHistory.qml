import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: historyPanel

    property bool open: false
    property bool grabReady: false
    property bool paused: false
    property var entries: []

    visible: open
    color: "transparent"
    implicitWidth: 500
    implicitHeight: 720
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:notification-history"

    anchors {
        top: true
        right: true
    }

    margins {
        top: 78
        right: 12
    }

    mask: Region {
        item: card
        radius: 18
    }

    function value(field, fallback) {
        if (field && typeof field === "object" && field.data !== undefined)
            return field.data
        return field ?? fallback
    }

    function parseHistory(raw) {
        try {
            const payload = JSON.parse(raw)
            const outer = Array.isArray(payload.data) ? payload.data : []
            const notifications = outer.length > 0 && Array.isArray(outer[0]) ? outer[0] : outer
            entries = notifications.slice(0, 10).map(notification => ({
                app: String(value(notification.appname, "Notification")),
                summary: String(value(notification.summary, "Notification")),
                body: String(value(notification.body, "")),
                urgency: String(value(notification.urgency, "NORMAL")),
            }))
        } catch (error) {
            entries = []
        }
    }

    function refresh() {
        if (!historyProcess.running)
            historyProcess.running = true
        if (!pauseProcess.running)
            pauseProcess.running = true
    }

    function runAction(arguments) {
        Quickshell.execDetached(["dunstctl"].concat(arguments))
        actionRefresh.restart()
    }

    onOpenChanged: {
        grabReady = false
        if (open) {
            refresh()
            focusDelay.restart()
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 18
        color: Theme.alpha(Theme.panel, 0.96)
        border.width: 1
        border.color: Theme.alpha(Theme.surface, 0.40)

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            Item {
                width: parent.width
                height: 42

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "NOTIFICATIONS"
                        color: Theme.text
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.title
                        font.bold: true
                        font.letterSpacing: 1
                    }

                    Text {
                        text: historyPanel.entries.length + " recent"
                        color: Theme.mutedText
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.caption
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 96
                        height: 34
                        radius: 10
                        color: historyPanel.paused ? Theme.dangerSurface : Theme.surfaceInset
                        border.width: 1
                        border.color: historyPanel.paused ? Theme.red : Theme.surface2

                        Text {
                            anchors.centerIn: parent
                            text: historyPanel.paused ? "DND ON" : "DND OFF"
                            color: historyPanel.paused ? Theme.red : Theme.subtext1
                            font.family: Ui.fontFamily
                            font.pixelSize: Ui.caption
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: historyPanel.runAction(["set-paused", "toggle"])
                        }
                    }

                    Rectangle {
                        width: 70
                        height: 34
                        radius: 10
                        color: Theme.surfaceInset
                        border.width: 1
                        border.color: Theme.surface2

                        Text {
                            anchors.centerIn: parent
                            text: "CLEAR"
                            color: Theme.subtext1
                            font.family: Ui.fontFamily
                            font.pixelSize: Ui.caption
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: historyPanel.runAction(["history-clear"])
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surface1
            }

            ListView {
                id: historyList
                width: parent.width
                height: parent.height - 112
                spacing: 8
                clip: true
                model: historyPanel.entries

                delegate: Rectangle {
                    required property var modelData

                    width: historyList.width
                    height: content.implicitHeight + 24
                    radius: 12
                    color: Theme.surfaceInset
                    border.width: 1
                    border.color: modelData.urgency === "CRITICAL" ? Theme.red : Theme.surface1

                    Column {
                        id: content
                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 5

                        Row {
                            width: parent.width
                            spacing: 8

                            Text {
                                width: parent.width - 92
                                text: modelData.summary
                                color: Theme.text
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                font.family: Ui.fontFamily
                                font.pixelSize: Ui.body
                                font.bold: true
                            }

                            Text {
                                width: 84
                                text: modelData.app
                                color: Theme.blue
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                font.family: Ui.fontFamily
                                font.pixelSize: Ui.caption
                            }
                        }

                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: modelData.body
                            color: Theme.subtext1
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            font.family: Ui.fontFamily
                            font.pixelSize: Ui.caption
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: historyPanel.entries.length === 0
                    text: "No notification history"
                    color: Theme.overlay1
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.body
                }
            }

            Rectangle {
                width: parent.width
                height: 42
                radius: 12
                color: Theme.surfaceRaised
                border.width: 1
                border.color: Theme.surface2

                Text {
                    anchors.centerIn: parent
                    text: "REPLAY MOST RECENT"
                    color: Theme.text
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.body
                    font.bold: true
                    font.letterSpacing: 0.5
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: historyPanel.runAction(["history-pop"])
                }
            }
        }
    }

    Process {
        id: historyProcess
        command: ["dunstctl", "history"]
        stdout: StdioCollector {
            onStreamFinished: historyPanel.parseHistory(text)
        }
    }

    Process {
        id: pauseProcess
        command: ["dunstctl", "is-paused"]
        stdout: StdioCollector {
            onStreamFinished: historyPanel.paused = text.trim() === "true"
        }
    }

    Timer {
        id: focusDelay
        interval: 150
        onTriggered: historyPanel.grabReady = historyPanel.open
    }

    Timer {
        id: actionRefresh
        interval: 150
        onTriggered: historyPanel.refresh()
    }

    Timer {
        interval: 5000
        repeat: true
        running: historyPanel.open
        onTriggered: historyPanel.refresh()
    }

    HyprlandFocusGrab {
        windows: [historyPanel]
        active: historyPanel.grabReady
        onCleared: {
            if (historyPanel.grabReady)
                historyPanel.open = false
        }
    }

    Item {
        anchors.fill: parent
        focus: historyPanel.open
        Keys.onEscapePressed: historyPanel.open = false
    }
}
