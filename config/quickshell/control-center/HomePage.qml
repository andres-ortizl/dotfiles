import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Widgets

Item {
    id: root

    required property var host

    Column {
        width: parent.width
        spacing: Ui.gap

        Row {
            width: parent.width
            height: 200
            spacing: Ui.gap

            WeatherCard {
                width: 250
                weather: root.host.weather
            }

            CalendarCard {
                width: parent.width - 262
                events: root.host.calendarEvents
                onOpenRequested: root.host.showCalendar = true
            }
        }

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
                    Quickshell.execDetached(["blueman-manager"]);
                }
                onToggleClicked: root.host.bluetoothAdapter.enabled = !root.host.bluetoothAdapter.enabled
            }
        }

        Rectangle {
            width: parent.width
            height: 80
            radius: 14
            color: "#4d414558"

            Item {
                x: 15
                width: parent.width / 2 - 20
                height: parent.height

                Text {
                    y: 16
                    text: root.host.activeDevice?.type === DeviceType.Wired ? "󰈀  Ethernet" : root.host.connectedWifi ? `󰖩  ${root.host.connectedWifi.name}` : "󰤭  Offline"
                    color: "#f8f8f2"
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.title
                    font.bold: true
                }

                Text {
                    y: 51
                    text: root.host.activeDevice ? `RX ${root.host.formatRate(root.host.downloadRate)}` : "No connection"
                    color: "#a7abbe"
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.caption
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 48
                color: "#414558"
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
                    color: "#f8f8f2"
                    elide: Text.ElideRight
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.body
                    font.bold: true
                }

                Text {
                    x: 36
                    y: 51
                    text: root.host.bluetoothDevices.length > 0 ? "Connected" : "Bluetooth idle"
                    color: "#a7abbe"
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.caption
                }
            }
        }
    }
}
