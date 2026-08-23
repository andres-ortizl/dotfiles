import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: overlay

    property bool open: false
    property string imagePath: ""
    property string errorMessage: ""

    visible: open
    z: 200

    function show() {
        open = true
        errorMessage = "Generating QR code..."
        cleanupImage()
        if (!qrProcess.running)
            qrProcess.running = true
    }

    function close() {
        open = false
        cleanupImage()
    }

    function cleanupImage() {
        if (imagePath.length > 0)
            Quickshell.execDetached(["rm", "-f", imagePath])
        imagePath = ""
    }

    function handleResult(raw) {
        const result = raw.trim()
        if (result.startsWith("ERROR:")) {
            errorMessage = result.slice(6)
            return
        }
        if (result.length === 0) {
            errorMessage = "Could not generate the Wi-Fi QR code"
            return
        }

        imagePath = result
        errorMessage = ""
        qrImage.source = "file://" + result + "?updated=" + Date.now()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.crust, 0.82)

        MouseArea {
            anchors.fill: parent
            onClicked: overlay.close()
        }
    }

    Rectangle {
        width: 390
        height: 430
        anchors.centerIn: parent
        radius: 18
        color: Theme.panel
        border.width: 1
        border.color: Theme.surface2

        MouseArea {
            anchors.fill: parent
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Text {
                width: parent.width
                text: "SHARE WI-FI"
                color: Theme.primaryText
                horizontalAlignment: Text.AlignHCenter
                font.family: Ui.fontFamily
                font.pixelSize: Ui.title
                font.bold: true
                font.letterSpacing: 1
            }

            Text {
                width: parent.width
                text: "Scan to join the current network"
                color: Theme.mutedText
                horizontalAlignment: Text.AlignHCenter
                font.family: Ui.fontFamily
                font.pixelSize: Ui.caption
            }

            Rectangle {
                width: 310
                height: 310
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 12
                color: "white"

                Image {
                    id: qrImage
                    anchors.fill: parent
                    anchors.margins: 10
                    cache: false
                    fillMode: Image.PreserveAspectFit
                    visible: overlay.imagePath.length > 0
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 30
                    visible: overlay.imagePath.length === 0
                    text: overlay.errorMessage
                    color: Theme.panel
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.body
                }
            }

            Rectangle {
                width: parent.width
                height: 38
                radius: 10
                color: Theme.alpha(Theme.surface, 0.45)

                Text {
                    anchors.centerIn: parent
                    text: "CLOSE"
                    color: Theme.accentText
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.body
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: overlay.close()
                }
            }
        }
    }

    Process {
        id: qrProcess
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/wifi-qr"]
        stdout: StdioCollector {
            onStreamFinished: overlay.handleResult(text)
        }
    }
}
