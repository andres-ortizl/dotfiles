import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: osd

    property bool shown: false
    property bool progressVisible: false
    property real progress: 0
    property string icon: "󰕾"
    property string title: ""
    property string subtitle: ""

    visible: shown
    color: "transparent"
    implicitWidth: 430
    implicitHeight: 112
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:desktop-osd"

    anchors {
        bottom: true
    }

    margins {
        bottom: 84
    }

    mask: Region {
        item: card
        radius: 18
    }

    function present() {
        shown = true
        dismissTimer.restart()
    }

    function showVolume(raw) {
        try {
            const payload = JSON.parse(raw)
            const value = Math.max(0, Number(payload.value) || 0)
            const muted = payload.muted === true
            progress = Math.min(value, 100) / 100
            progressVisible = true
            icon = muted || value === 0 ? "󰖁" : value < 35 ? "󰕿" : value < 70 ? "󰖀" : "󰕾"
            title = muted ? "Muted" : value + "%"
            subtitle = "Default audio output"
            present()
        } catch (error) {
            shown = false
        }
    }

    function showMedia(raw) {
        try {
            const payload = JSON.parse(raw)
            progressVisible = false
            icon = payload.status === "Playing" ? "󰏤" : "󰐊"
            title = String(payload.title || "Media")
            subtitle = String(payload.artist || payload.player || "")
            present()
        } catch (error) {
            shown = false
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 18
        color: Theme.alpha(Theme.panel, 0.96)
        border.width: 1
        border.color: Theme.alpha(Theme.surface2, 0.40)

        Row {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Rectangle {
                width: 64
                height: 64
                anchors.verticalCenter: parent.verticalCenter
                radius: 16
                color: Theme.surfaceRaised

                Text {
                    anchors.centerIn: parent
                    text: osd.icon
                    color: Theme.mauve
                    font.family: Ui.fontFamily
                    font.pixelSize: 30
                }
            }

            Column {
                width: parent.width - 80
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Text {
                    width: parent.width
                    text: osd.title
                    color: Theme.text
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.title
                    font.bold: true
                }

                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: osd.subtitle
                    color: Theme.mutedText
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.caption
                }

                Rectangle {
                    width: parent.width
                    height: osd.progressVisible ? 8 : 0
                    visible: osd.progressVisible
                    radius: 4
                    color: Theme.surface1

                    Rectangle {
                        width: parent.width * osd.progress
                        height: parent.height
                        radius: parent.radius
                        color: Theme.mauve

                        Behavior on width {
                            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: dismissTimer
        interval: 1800
        onTriggered: osd.shown = false
    }
}
