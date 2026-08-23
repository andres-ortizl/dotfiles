import QtQuick
import Quickshell
import Quickshell.Networking

Item {
    id: root

    required property var host
    property var passwordNetwork: null
    property string errorMessage: ""
    readonly property var sortedNetworks: [...root.host.wifiNetworks].sort((left, right) => {
        if (left.connected !== right.connected)
            return left.connected ? -1 : 1;
        if (left.known !== right.known)
            return left.known ? -1 : 1;
        return (right.signalStrength ?? 0) - (left.signalStrength ?? 0);
    })

    function iconFor(strength) {
        if (strength >= 0.75)
            return "󰤨";
        if (strength >= 0.5)
            return "󰤥";
        if (strength >= 0.25)
            return "󰤢";
        return "󰤟";
    }

    function connectWithPassword() {
        if (!passwordNetwork || passwordInput.text.length === 0)
            return;
        errorMessage = "";
        passwordNetwork.connectWithPsk(passwordInput.text);
        passwordInput.text = "";
        passwordNetwork = null;
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 44

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: 11
            color: backMouse.containsMouse ? Theme.alpha(Theme.surface, 0.45) : Theme.alpha(Theme.surface, 0.30)

            Text {
                anchors.centerIn: parent
                text: "<"
                color: Theme.accentText
                font.family: Ui.fontFamily
                font.pixelSize: Ui.heading
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.showWifi = false
            }
        }

        Text {
            x: 58
            anchors.verticalCenter: parent.verticalCenter
            text: "WI-FI NETWORKS"
            color: Theme.primaryText
            font.family: Ui.fontFamily
            font.pixelSize: Ui.title
            font.bold: true
            font.letterSpacing: 1
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 70
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 26
            radius: 9
            color: qrMouse.containsMouse ? Theme.alpha(Theme.surface, 0.45) : Theme.alpha(Theme.surface, 0.30)
            opacity: root.host.connectedWifi ? 1 : 0.45

            Text {
                anchors.centerIn: parent
                text: "󰐲"
                color: Theme.accentText
                font.family: Ui.fontFamily
                font.pixelSize: Ui.body
            }

            MouseArea {
                id: qrMouse
                anchors.fill: parent
                enabled: root.host.connectedWifi !== null
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: wifiQr.show()
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 58
            height: 26
            radius: 10
            color: root.host.networking.wifiEnabled ? Theme.alpha(Theme.accent, 0.30) : Theme.alpha(Theme.surface, 0.30)

            Text {
                anchors.centerIn: parent
                text: root.host.networking.wifiEnabled ? "ON" : "OFF"
                color: root.host.networking.wifiEnabled ? Theme.accentText : Theme.mutedText
                font.family: Ui.fontFamily
                font.pixelSize: Ui.caption
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.networking.wifiEnabled = !root.host.networking.wifiEnabled
            }
        }
    }

    Flickable {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: 8
        anchors.bottom: passwordCard.visible ? passwordCard.top : advancedSettings.top
        anchors.bottomMargin: 8
        contentHeight: networkList.implicitHeight
        clip: true

        Column {
            id: networkList
            width: parent.width
            spacing: 4

            Repeater {
                model: root.sortedNetworks

                delegate: Rectangle {
                    id: networkRow

                    required property var modelData

                    width: networkList.width
                    height: 68
                    radius: 12
                    color: networkMouse.containsMouse ? Theme.alpha(Theme.surface, 0.45) : modelData.connected ? Theme.alpha(Theme.activeSurface, 0.24) : Theme.alpha(Theme.surface, 0.30)

                    Text {
                        x: 13
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.iconFor(networkRow.modelData.signalStrength)
                        color: networkRow.modelData.connected ? Theme.accentText : Theme.mutedText
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.icon
                    }

                    Text {
                        x: 49
                        y: 9
                        width: parent.width - 112
                        text: networkRow.modelData.name || "Hidden network"
                        color: Theme.primaryText
                        elide: Text.ElideRight
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.body
                        font.bold: true
                    }

                    Text {
                        x: 49
                        y: 40
                        text: networkRow.modelData.connected ? "Connected" : networkRow.modelData.stateChanging ? "Connecting..." : networkRow.modelData.known ? "Saved" : `${Math.round(networkRow.modelData.signalStrength * 100)}% signal`
                        color: networkRow.modelData.connected ? Theme.success : Theme.mutedText
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.caption
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: networkRow.modelData.security === WifiSecurityType.Open ? "" : "󰌾"
                        color: Theme.mutedText
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.title
                    }

                    MouseArea {
                        id: networkMouse
                        anchors.fill: parent
                        enabled: !networkRow.modelData.stateChanging
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.errorMessage = "";
                            if (networkRow.modelData.connected) {
                                networkRow.modelData.disconnect();
                            } else if (networkRow.modelData.known || networkRow.modelData.security === WifiSecurityType.Open) {
                                networkRow.modelData.connect();
                            } else {
                                root.passwordNetwork = networkRow.modelData;
                                passwordInput.text = "";
                                passwordInput.forceActiveFocus();
                            }
                        }
                    }

                    Connections {
                        target: networkRow.modelData
                        function onConnectionFailed() {
                            root.errorMessage = "Connection failed. Check the password or use advanced settings.";
                        }
                    }
                }
            }

            Text {
                width: parent.width
                height: root.sortedNetworks.length === 0 ? 70 : 0
                visible: root.sortedNetworks.length === 0
                text: root.host.networking.wifiEnabled ? "Scanning for networks..." : "Wi-Fi is disabled"
                color: Theme.mutedText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: Ui.fontFamily
                font.pixelSize: Ui.body
            }
        }
    }

    Rectangle {
        id: passwordCard
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: advancedSettings.top
        anchors.bottomMargin: 8
        height: visible ? 96 : 0
        visible: root.passwordNetwork !== null
        radius: 13
        color: Theme.alpha(Theme.surface, 0.45)

        Text {
            x: 13
            y: 9
            text: `Password for ${root.passwordNetwork?.name ?? "network"}`
            color: Theme.primaryText
            font.family: Ui.fontFamily
            font.pixelSize: Ui.body
            font.bold: true
        }

        Rectangle {
            x: 13
            y: 43
            width: parent.width - 104
            height: 40
            radius: 9
            color: Theme.alpha(Theme.panel, 0.80)

            TextInput {
                id: passwordInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                color: Theme.primaryText
                selectionColor: Theme.accent
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                font.family: Ui.fontFamily
                font.pixelSize: Ui.body
                onAccepted: root.connectWithPassword()
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 13
            y: 43
            width: 70
            height: 40
            radius: 9
            color: Theme.accent

            Text {
                anchors.centerIn: parent
                text: "Connect"
                color: Theme.panel
                font.family: Ui.fontFamily
                font.pixelSize: Ui.body
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.connectWithPassword()
            }
        }
    }

    Rectangle {
        id: advancedSettings
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 44
        radius: 11
        color: advancedMouse.containsMouse ? Theme.alpha(Theme.surface, 0.45) : Theme.alpha(Theme.surface, 0.30)

        Text {
            anchors.centerIn: parent
            text: root.errorMessage || "Advanced network settings"
            color: root.errorMessage ? Theme.warning : Theme.accentText
            elide: Text.ElideRight
            font.family: Ui.fontFamily
            font.pixelSize: Ui.body
        }

        MouseArea {
            id: advancedMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.host.open = false;
                Ui.launch(["ghostty", "-e", "nmtui"]);
            }
        }
    }

    WifiQrOverlay {
        id: wifiQr
        anchors.fill: parent
    }
}
