import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell
import Quickshell.Networking
import Quickshell.Widgets

Item {
    id: root

    required property var host
    implicitHeight: homeContent.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        id: homeContent

        width: parent.width
        spacing: Ui.gap

        Row {
            width: parent.width
            height: 104
            spacing: Ui.gap

            QuickToggle {
                width: (parent.width - parent.spacing) / 2
                icon: root.host.networking.wifiEnabled ? "󰖩" : "󰖪"
                title: root.host.connectedWifi?.name ?? "Wi-Fi"
                subtitle: root.host.networking.wifiEnabled ? "ON" : "OFF"
                active: root.host.networking.wifiEnabled
                available: root.host.networking.wifiHardwareEnabled && root.host.wifiDevice !== null
                hasDetails: true
                onClicked: root.host.showWifi = true
                onToggleClicked: root.host.networking.wifiEnabled = !root.host.networking.wifiEnabled
            }

            QuickToggle {
                width: (parent.width - parent.spacing) / 2
                icon: root.host.bluetoothAdapter?.enabled ? "󰂯" : "󰂲"
                title: "Bluetooth"
                subtitle: root.host.bluetoothAdapter?.enabled ? "ON" : "OFF"
                active: root.host.bluetoothAdapter?.enabled ?? false
                available: root.host.bluetoothAdapter !== null
                hasDetails: true
                onClicked: {
                    root.host.open = false;
                    Ui.launch(["blueman-manager"]);
                }
                onToggleClicked: root.host.bluetoothAdapter.enabled = !root.host.bluetoothAdapter.enabled
            }
        }

        Rectangle {
            width: parent.width
            height: 80
            radius: 14
            color: Theme.alpha(Theme.surface, 0.30)

            Item {
                x: 15
                width: parent.width / 2 - 20
                height: parent.height

                Text {
                    y: 16
                    text: root.host.activeDevice?.type === DeviceType.Wired ? "󰈀  Ethernet" : root.host.connectedWifi ? `󰖩  ${root.host.connectedWifi.name}` : "󰤭  Offline"
                    color: Theme.primaryText
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.title
                    font.bold: true
                }

                Text {
                    y: 51
                    text: root.host.activeDevice ? `RX ${root.host.formatRate(root.host.downloadRate)}` : "No connection"
                    color: Theme.mutedText
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.caption
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 48
                color: Theme.surface
            }

            Item {
                x: parent.width / 2 + 12
                width: parent.width / 2 - 27
                height: parent.height

                IconImage {
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 26
                    source: root.host.bluetoothDevices.length > 0 && root.host.bluetoothDevices[0].icon ? Quickshell.iconPath(root.host.bluetoothDevices[0].icon) : ""
                }

                Text {
                    x: 36
                    y: 16
                    width: parent.width - 36
                    text: root.host.bluetoothDevices.length > 0 ? root.host.bluetoothDevices[0].name : "No BT device"
                    color: Theme.primaryText
                    elide: Text.ElideRight
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.body
                    font.bold: true
                }

                Text {
                    x: 36
                    y: 51
                    text: root.host.bluetoothDevices.length > 0 ? "Connected" : "Bluetooth idle"
                    color: Theme.mutedText
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.caption
                }
            }
        }

        Row {
            id: contextRow

            width: parent.width
            height: Math.max(weatherCard.implicitHeight, calendarButton.implicitHeight) + topPadding
            topPadding: Ui.gap
            spacing: Ui.gap

            WeatherCard {
                id: weatherCard

                width: (contextRow.width - contextRow.spacing) / 2
                height: contextRow.height - contextRow.topPadding
                weather: root.host.weather
            }

            Controls.Button {
                id: calendarButton

                width: (contextRow.width - contextRow.spacing) / 2
                height: contextRow.height - contextRow.topPadding
                implicitHeight: Math.max(88, dateDetails.implicitHeight + 24)
                padding: 0
                text: "Open calendar"
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                Accessible.description: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                Keys.onReturnPressed: calendarButton.clicked()
                Keys.onEnterPressed: calendarButton.clicked()
                onClicked: root.host.showCalendar = true

                background: Rectangle {
                    radius: 16
                    color: calendarButton.down ? Theme.alpha(Theme.hoverSurface, 0.55) : calendarButton.hovered ? Theme.alpha(Theme.hoverSurface, 0.40) : Theme.alpha(Theme.surface, 0.30)
                    border.width: calendarButton.visualFocus ? 2 : 1
                    border.color: calendarButton.visualFocus ? Theme.accent : Theme.alpha(Theme.surface, 0.20)

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                contentItem: Item {
                    Text {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰃭"
                        color: calendarButton.hovered ? Theme.accentText : Theme.mutedText
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.icon
                    }

                    Column {
                        id: dateDetails

                        x: 64
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 104
                        spacing: 4

                        Text {
                            text: "TODAY"
                            color: Theme.mutedText
                            font.family: Ui.fontFamily
                            font.pixelSize: Ui.caption
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        Text {
                            width: parent.width
                            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                            elide: Text.ElideRight
                            color: Theme.primaryText
                            font.family: Ui.fontFamily
                            font.pixelSize: Ui.title
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            text: calendarButton.text
                            elide: Text.ElideRight
                            color: calendarButton.hovered ? Theme.accentText : Theme.mutedText
                            font.family: Ui.fontFamily
                            font.pixelSize: Ui.caption
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: calendarButton.hovered ? Theme.accentText : Theme.quietText
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.title
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
