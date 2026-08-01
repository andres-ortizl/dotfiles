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
            color: backMouse.containsMouse ? "#73414558" : "#4d414558"

            Text {
                anchors.centerIn: parent
                text: "<"
                color: "#d4ccff"
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
            color: "#f8f8f2"
            font.family: Ui.fontFamily
            font.pixelSize: Ui.title
            font.bold: true
            font.letterSpacing: 1
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 58
            height: 26
            radius: 10
            color: root.host.networking.wifiEnabled ? "#4d9580ff" : "#4d414558"

            Text {
                anchors.centerIn: parent
                text: root.host.networking.wifiEnabled ? "ON" : "OFF"
                color: root.host.networking.wifiEnabled ? "#d4ccff" : "#a7abbe"
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
                    color: networkMouse.containsMouse ? "#73414558" : modelData.connected ? "#3d354f80" : "#4d414558"

                    Text {
                        x: 13
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.iconFor(networkRow.modelData.signalStrength)
                        color: networkRow.modelData.connected ? "#d4ccff" : "#a7abbe"
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.icon
                    }

                    Text {
                        x: 49
                        y: 9
                        width: parent.width - 112
                        text: networkRow.modelData.name || "Hidden network"
                        color: "#f8f8f2"
                        elide: Text.ElideRight
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.body
                        font.bold: true
                    }

                    Text {
                        x: 49
                        y: 40
                        text: networkRow.modelData.connected ? "Connected" : networkRow.modelData.stateChanging ? "Connecting..." : networkRow.modelData.known ? "Saved" : `${Math.round(networkRow.modelData.signalStrength * 100)}% signal`
                        color: networkRow.modelData.connected ? "#8aff80" : "#a7abbe"
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.caption
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: networkRow.modelData.security === WifiSecurityType.Open ? "" : "󰌾"
                        color: "#a7abbe"
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
                color: "#a7abbe"
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
        color: "#73414558"

        Text {
            x: 13
            y: 9
            text: `Password for ${root.passwordNetwork?.name ?? "network"}`
            color: "#f8f8f2"
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
            color: "#cc21222c"

            TextInput {
                id: passwordInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                color: "#f8f8f2"
                selectionColor: "#9580ff"
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
            color: "#9580ff"

            Text {
                anchors.centerIn: parent
                text: "Connect"
                color: "#21222c"
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
        color: advancedMouse.containsMouse ? "#73414558" : "#4d414558"

        Text {
            anchors.centerIn: parent
            text: root.errorMessage || "Advanced network settings"
            color: root.errorMessage ? "#ff9580" : "#d4ccff"
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
                Quickshell.execDetached(["ghostty", "-e", "nmtui"]);
            }
        }
    }
}
